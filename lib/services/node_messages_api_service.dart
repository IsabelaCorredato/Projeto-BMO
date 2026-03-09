import 'dart:convert';

import 'package:http/http.dart' as http;

class NodeApiMessage {
  NodeApiMessage({
    required this.id,
    required this.source,
    required this.text,
    required this.createdAt,
  });

  final int id;
  final String source;
  final String text;
  final DateTime createdAt;

  factory NodeApiMessage.fromMap(Map<String, dynamic> map) {
    return NodeApiMessage(
      id: (map['id'] as num?)?.toInt() ?? 0,
      source: (map['source'] as String?) ?? 'unknown',
      text: (map['text'] as String?) ?? '',
      createdAt:
          DateTime.tryParse((map['createdAt'] as String?) ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class NodeMessagesApiService {
  String? _baseUrl;
  String _token = '';

  bool get isConfigured => _baseUrl != null && _baseUrl!.trim().isNotEmpty;
  String? get baseUrl => _baseUrl;
  String get token => _token;

  void configure({required String baseUrl, required String token}) {
    _baseUrl = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    _token = token.trim();
  }

  Future<List<NodeApiMessage>> fetchMessages({int limit = 50}) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('Base URL da API não configurada');
    }

    final uri = Uri.parse('$baseUrl/messages?limit=$limit');
    final response = await http.get(uri, headers: _headers());

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API GET /messages falhou: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final items = (data['data'] as List<dynamic>? ?? const [])
        .cast<Map<String, dynamic>>();

    return items.map(NodeApiMessage.fromMap).toList();
  }

  Future<NodeApiMessage> postMessage({
    required String text,
    required String source,
  }) async {
    final baseUrl = _baseUrl;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw StateError('Base URL da API não configurada');
    }

    final uri = Uri.parse('$baseUrl/messages');
    final response = await http.post(
      uri,
      headers: _headers(),
      body: jsonEncode({'text': text, 'source': source}),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('API POST /messages falhou: ${response.statusCode}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final raw = data['data'] as Map<String, dynamic>?;
    if (raw == null) {
      throw StateError('API POST /messages sem payload de retorno');
    }

    return NodeApiMessage.fromMap(raw);
  }

  Map<String, String> _headers() {
    return {
      'Content-Type': 'application/json',
      if (_token.isNotEmpty) 'Authorization': 'Bearer $_token',
    };
  }
}
