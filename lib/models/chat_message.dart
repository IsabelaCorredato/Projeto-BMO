enum MessageSource { user, esp32, bmo, system }

class ChatMessage {
  ChatMessage({
    this.id,
    required this.source,
    required this.text,
    required this.createdAt,
  });

  final int? id;
  final MessageSource source;
  final String text;
  final DateTime createdAt;

  String get sourceLabel {
    switch (source) {
      case MessageSource.user:
        return 'Você';
      case MessageSource.esp32:
        return 'ESP32';
      case MessageSource.bmo:
        return 'BMO';
      case MessageSource.system:
        return 'Sistema';
    }
  }

  Map<String, Object?> toMap() {
    return {
      'id': id,
      'source': source.name,
      'text': text,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  ChatMessage copyWith({
    int? id,
    MessageSource? source,
    String? text,
    DateTime? createdAt,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      source: source ?? this.source,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  static ChatMessage fromMap(Map<String, Object?> map) {
    final rawSource = (map['source'] as String?) ?? MessageSource.system.name;
    final parsedSource = MessageSource.values.firstWhere(
      (source) => source.name == rawSource,
      orElse: () => MessageSource.system,
    );

    return ChatMessage(
      id: map['id'] as int?,
      source: parsedSource,
      text: (map['text'] as String?) ?? '',
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as int?) ?? 0,
      ),
    );
  }
}
