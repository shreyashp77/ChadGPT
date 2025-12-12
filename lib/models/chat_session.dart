import 'message.dart';

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<Message> messages;
  final bool isTemp;
  String? systemPrompt;
  bool isPinned;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<Message>? messages,
    this.isTemp = false,
    this.systemPrompt,
    this.isPinned = false,
  }) : messages = messages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'system_prompt': systemPrompt,
      'is_pinned': isPinned ? 1 : 0,
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      messages: [], // Messages loaded separately
      isTemp: false,
      systemPrompt: map['system_prompt'],
      isPinned: map['is_pinned'] == 1,
    );
  }
}
