import 'message.dart';

class ChatSession {
  final String id;
  String title;
  final DateTime createdAt;
  DateTime updatedAt;
  List<Message> messages;
  final bool isTemp;

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<Message>? messages,
    this.isTemp = false,
  }) : messages = messages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // isTemp is likely not stored in DB if we never save temp chats, 
      // but if we want to support converting temp to saved later, we might not need to store it initially.
      // However, for code consistency we might want to know if a persisted chat is flagged.
    };
  }

  factory ChatSession.fromMap(Map<String, dynamic> map) {
    return ChatSession(
      id: map['id'],
      title: map['title'],
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      messages: [], // Messages loaded separately
      isTemp: false, // By default loaded from DB means not temp in the RAM-only sense
    );
  }
}
