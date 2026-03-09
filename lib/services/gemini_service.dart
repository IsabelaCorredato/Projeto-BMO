import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/chat_message.dart';

class GeminiService {
  GeminiService({required this.apiKey, this.model = 'gemini-2.5-flash'});

  final String apiKey;
  final String model;

  bool get isConfigured => apiKey.trim().isNotEmpty;

  Future<String> generateBmoReply({
    required List<ChatMessage> context,
    required String latestInput,
  }) async {
    if (!isConfigured) {
      throw StateError('GEMINI_API_KEY não configurada');
    }

    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey',
    );

    final startIndex = context.length > 20 ? context.length - 20 : 0;
    final contextMessages = context.sublist(startIndex);
    final contents = contextMessages.map((message) {
      final isModel = message.source == MessageSource.bmo;
      return {
        'role': isModel ? 'model' : 'user',
        'parts': [
          {'text': '${message.sourceLabel}: ${message.text}'},
        ],
      };
    }).toList();

    contents.add({
      'role': 'user',
      'parts': [
        {'text': 'Entrada atual: $latestInput'},
      ],
    });

    final body = {
      'systemInstruction': {
        'parts': [
          {
            'text':
                'Você é o BMO (Hora de Aventura), amigável, curioso e objetivo. '
                'Responda em português do Brasil, com frases curtas, úteis para interação por ESP32. '
                'Evite respostas longas.',
          },
        ],
      },
      'contents': contents,
      'generationConfig': {
        'temperature': 0.8,
        'topP': 0.95,
        'maxOutputTokens': 220,
      },
    };

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Gemini retornou ${response.statusCode}: ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final candidates = data['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) {
      throw StateError('Gemini retornou resposta vazia');
    }

    final content = candidates.first['content'] as Map<String, dynamic>?;
    final parts = content?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) {
      throw StateError('Gemini sem partes de texto');
    }

    final buffer = StringBuffer();
    for (final part in parts) {
      final text = (part as Map<String, dynamic>)['text'] as String?;
      if (text != null && text.trim().isNotEmpty) {
        if (buffer.isNotEmpty) {
          buffer.writeln();
        }
        buffer.write(text.trim());
      }
    }

    final output = buffer.toString().trim();
    if (output.isEmpty) {
      throw StateError('Gemini sem texto útil na resposta');
    }

    return output;
  }
}
