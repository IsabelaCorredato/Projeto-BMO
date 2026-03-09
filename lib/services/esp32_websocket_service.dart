import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

enum WsStatus { disconnected, connecting, connected }

class IncomingWsMessage {
  IncomingWsMessage({
    required this.text,
    required this.source,
    required this.createdAt,
  });

  final String text;
  final String source;
  final DateTime createdAt;
}

class Esp32WebSocketService {
  final _messagesController = StreamController<IncomingWsMessage>.broadcast();
  final _statusController = StreamController<WsStatus>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;

  WsStatus _status = WsStatus.disconnected;

  Stream<IncomingWsMessage> get messages => _messagesController.stream;
  Stream<WsStatus> get status => _statusController.stream;
  WsStatus get currentStatus => _status;
  bool get isConnected => _status == WsStatus.connected;

  Future<void> connect(String rawUrl) async {
    final url = rawUrl.trim();
    if (url.isEmpty) {
      throw ArgumentError('URL de WebSocket vazia');
    }

    final uri = Uri.parse(url);
    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw ArgumentError('Use ws:// ou wss:// na URL');
    }

    await disconnect();
    _setStatus(WsStatus.connecting);

    try {
      _channel = WebSocketChannel.connect(uri);
      await _channel!.ready;
      _subscription = _channel!.stream.listen(
        (event) {
          _setStatus(WsStatus.connected);
          final message = _parseIncoming(event.toString());
          if (message != null) {
            _messagesController.add(message);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          _setStatus(WsStatus.disconnected);
        },
        onDone: () {
          _setStatus(WsStatus.disconnected);
        },
        cancelOnError: true,
      );

      _setStatus(WsStatus.connected);
    } catch (error) {
      _setStatus(WsStatus.disconnected);
      rethrow;
    }
  }

  IncomingWsMessage? _parseIncoming(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    try {
      final parsed = jsonDecode(trimmed);
      if (parsed is Map<String, dynamic>) {
        if (parsed['type'] == 'message' &&
            parsed['data'] is Map<String, dynamic>) {
          final data = parsed['data'] as Map<String, dynamic>;
          final text = (data['text'] as String?)?.trim() ?? '';
          if (text.isEmpty) {
            return null;
          }

          return IncomingWsMessage(
            text: text,
            source: (data['source'] as String?) ?? 'esp32',
            createdAt:
                DateTime.tryParse((data['createdAt'] as String?) ?? '') ??
                DateTime.now(),
          );
        }

        final text = (parsed['text'] as String?)?.trim() ?? '';
        if (text.isNotEmpty) {
          return IncomingWsMessage(
            text: text,
            source: (parsed['source'] as String?) ?? 'esp32',
            createdAt: DateTime.now(),
          );
        }
      }
    } catch (_) {
      // Texto puro
    }

    return IncomingWsMessage(
      text: trimmed,
      source: 'esp32',
      createdAt: DateTime.now(),
    );
  }

  void sendText(String text, {String source = 'app'}) {
    if (!isConnected || _channel == null) {
      throw StateError('WebSocket não conectado');
    }

    final payload = {'text': text, 'source': source};

    _channel!.sink.add(jsonEncode(payload));
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;

    await _channel?.sink.close();
    _channel = null;

    _setStatus(WsStatus.disconnected);
  }

  void _setStatus(WsStatus status) {
    if (_status == status) {
      return;
    }

    _status = status;
    _statusController.add(status);
  }

  Future<void> dispose() async {
    await disconnect();
    await _messagesController.close();
    await _statusController.close();
  }
}
