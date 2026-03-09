import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/chat_message.dart';
import '../services/chat_database.dart';
import '../services/esp32_websocket_service.dart';
import '../services/gemini_service.dart';
import '../services/node_messages_api_service.dart';

class BmoController extends ChangeNotifier {
  BmoController({
    required ChatDatabase database,
    required GeminiService gemini,
    required Esp32WebSocketService websocket,
    required NodeMessagesApiService nodeApi,
  }) : _database = database,
       _gemini = gemini,
       _websocket = websocket,
       _nodeApi = nodeApi;

  final ChatDatabase _database;
  final GeminiService _gemini;
  final Esp32WebSocketService _websocket;
  final NodeMessagesApiService _nodeApi;

  final List<ChatMessage> _messages = [];

  StreamSubscription<IncomingWsMessage>? _messagesSubscription;
  StreamSubscription<WsStatus>? _statusSubscription;

  bool _isInitialized = false;
  bool _isGenerating = false;
  String _statusText = 'Desconectado';
  String? _errorText;

  String _wsUrl = '';
  String _apiBaseUrl = '';
  String _apiToken = 'bmo-local-123';

  Future<void> _pendingQueue = Future<void>.value();

  List<ChatMessage> get messages => List.unmodifiable(_messages);
  bool get isGenerating => _isGenerating;
  bool get isInitialized => _isInitialized;
  String get statusText => _statusText;
  String? get errorText => _errorText;
  bool get isConnected => _websocket.isConnected;

  String get wsUrl => _wsUrl;
  String get apiBaseUrl => _apiBaseUrl;
  String get apiToken => _apiToken;

  Future<void> initialize() async {
    await _database.init();
    _messages
      ..clear()
      ..addAll(await _database.loadMessages());

    _statusSubscription = _websocket.status.listen((status) {
      switch (status) {
        case WsStatus.disconnected:
          _statusText = 'Desconectado';
          break;
        case WsStatus.connecting:
          _statusText = 'Conectando...';
          break;
        case WsStatus.connected:
          _statusText = 'Conectado';
          break;
      }
      notifyListeners();
    });

    _messagesSubscription = _websocket.messages.listen((incoming) {
      _handleIncomingNodeMessage(incoming);
    });

    _isInitialized = true;
    notifyListeners();
  }

  Future<void> connectToNode({
    required String wsUrl,
    required String apiBaseUrl,
    required String apiToken,
  }) async {
    _errorText = null;
    _wsUrl = wsUrl.trim();
    _apiBaseUrl = apiBaseUrl.trim();
    _apiToken = apiToken.trim();

    if (_wsUrl.isEmpty && _apiBaseUrl.isNotEmpty) {
      try {
        _wsUrl = _deriveWsUrlFromApi(_apiBaseUrl);
      } catch (_) {
        _errorText = 'Node API base URL inválida.';
        notifyListeners();
        return;
      }
    }

    if (_wsUrl.isEmpty) {
      _errorText = 'Informe Node WS URL ou Node API base URL.';
      notifyListeners();
      return;
    }

    notifyListeners();

    if (_apiBaseUrl.isNotEmpty) {
      _nodeApi.configure(baseUrl: _apiBaseUrl, token: _apiToken);
    }

    try {
      await _websocket.connect(_wsUrl);
      await _addSystemMessage('Node WS conectado em $_wsUrl');
      if (_nodeApi.isConfigured) {
        await _addSystemMessage(
          'Node API configurada em $_apiBaseUrl/messages',
        );
      }
    } catch (error) {
      _errorText = 'Falha ao conectar no Node: $error';
      notifyListeners();
    }
  }

  String _deriveWsUrlFromApi(String apiBaseUrl) {
    final uri = Uri.parse(apiBaseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return Uri(
      scheme: wsScheme,
      host: uri.host,
      port: uri.hasPort ? uri.port : null,
      path: '/ws',
    ).toString();
  }

  Future<void> disconnectFromNode() async {
    await _websocket.disconnect();
    await _addSystemMessage('Node WS desconectado');
  }

  Future<void> syncMessagesFromApi({int limit = 50}) async {
    if (!_nodeApi.isConfigured) {
      _errorText = 'API não configurada';
      notifyListeners();
      return;
    }

    _errorText = null;

    try {
      final remoteMessages = await _nodeApi.fetchMessages(limit: limit);
      var imported = 0;

      for (final remote in remoteMessages) {
        final mapped = ChatMessage(
          source: _mapRemoteSource(remote.source),
          text: remote.text,
          createdAt: remote.createdAt,
        );

        if (_containsMessage(mapped)) {
          continue;
        }

        await _persistMessage(mapped);
        imported++;
      }

      await _addSystemMessage('Sincronização API concluída: $imported nova(s)');
    } catch (error) {
      _errorText = 'Falha ao sincronizar API: $error';
      notifyListeners();
    }
  }

  Future<void> sendUserMessage(String text) async {
    final created = await _createUserMessage(text);
    if (created == null) {
      return;
    }

    await _enqueueGeminiReply(triggerText: created.text);
  }

  Future<void> clearContext() async {
    await _database.clearAll();
    _messages.clear();
    _errorText = null;
    notifyListeners();
  }

  Future<void> _handleIncomingNodeMessage(IncomingWsMessage incoming) async {
    final text = incoming.text.trim();
    if (text.isEmpty) {
      return;
    }

    final mappedSource = _mapRemoteSource(incoming.source);
    final message = ChatMessage(
      source: mappedSource,
      text: text,
      createdAt: incoming.createdAt,
    );

    if (_containsMessage(message)) {
      return;
    }

    await _persistMessage(message);
    notifyListeners();

    if (mappedSource == MessageSource.esp32 && !text.startsWith('[BMO]')) {
      await _enqueueGeminiReply(triggerText: text);
    }
  }

  MessageSource _mapRemoteSource(String source) {
    final normalized = source.trim().toLowerCase();
    switch (normalized) {
      case 'bmo':
      case 'assistant':
        return MessageSource.bmo;
      case 'app':
      case 'user':
        return MessageSource.user;
      case 'system':
        return MessageSource.system;
      default:
        return MessageSource.esp32;
    }
  }

  Future<ChatMessage?> _createUserMessage(String rawText) async {
    final trimmed = rawText.trim();
    if (trimmed.isEmpty) {
      return null;
    }

    _errorText = null;
    final localMessage = ChatMessage(
      source: MessageSource.user,
      text: trimmed,
      createdAt: DateTime.now(),
    );

    final persisted = await _persistMessage(localMessage);

    try {
      if (_websocket.isConnected) {
        _websocket.sendText(trimmed, source: 'app');
      } else if (_nodeApi.isConfigured) {
        await _nodeApi.postMessage(text: trimmed, source: 'app');
      }
    } catch (error) {
      _errorText = 'Erro enviando ao Node: $error';
    }

    notifyListeners();
    return persisted;
  }

  Future<void> _enqueueGeminiReply({required String triggerText}) async {
    _pendingQueue = _pendingQueue.then((_) async {
      _isGenerating = true;
      notifyListeners();

      try {
        if (!_gemini.isConfigured) {
          await _addSystemMessage(
            'Defina GEMINI_API_KEY para habilitar respostas.',
          );
          return;
        }

        final reply = await _gemini.generateBmoReply(
          context: _messages,
          latestInput: triggerText,
        );

        final replyMessage = ChatMessage(
          source: MessageSource.bmo,
          text: reply,
          createdAt: DateTime.now(),
        );

        await _persistMessage(replyMessage);

        try {
          if (_websocket.isConnected) {
            _websocket.sendText('[BMO] $reply', source: 'bmo');
          } else if (_nodeApi.isConfigured) {
            await _nodeApi.postMessage(text: '[BMO] $reply', source: 'bmo');
          }
        } catch (error) {
          _errorText = 'Erro enviando resposta ao Node: $error';
        }
      } catch (error) {
        _errorText = 'Erro no Gemini: $error';
      } finally {
        _isGenerating = false;
        notifyListeners();
      }
    });

    await _pendingQueue;
  }

  bool _containsMessage(ChatMessage target) {
    final targetEpoch = target.createdAt.millisecondsSinceEpoch;

    return _messages.any((current) {
      return current.source == target.source &&
          current.text == target.text &&
          (current.createdAt.millisecondsSinceEpoch - targetEpoch).abs() < 10;
    });
  }

  Future<void> _addSystemMessage(String text) async {
    final message = ChatMessage(
      source: MessageSource.system,
      text: text,
      createdAt: DateTime.now(),
    );
    await _persistMessage(message);
    notifyListeners();
  }

  Future<ChatMessage> _persistMessage(ChatMessage message) async {
    final persisted = await _database.insertMessage(message);
    _messages.add(persisted);
    return persisted;
  }

  @override
  void dispose() {
    unawaited(_messagesSubscription?.cancel());
    unawaited(_statusSubscription?.cancel());
    unawaited(_websocket.dispose());
    unawaited(_database.close());
    super.dispose();
  }
}
