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
  bool hasUnreadMessages;

  /// Returns true if the chat contains any generated media (images)
  bool get hasGeneratedMedia => messages.any((m) => m.generatedImageUrl != null);
  
  /// Returns true if the chat contains any user attachments (files/images)
  bool get hasAttachments => messages.any((m) => m.attachmentPath != null);

  ChatSession({
    required this.id,
    required this.title,
    required this.createdAt,
    required this.updatedAt,
    List<Message>? messages,
    this.isTemp = false,
    this.systemPrompt,
    this.isPinned = false,
    this.hasUnreadMessages = false,
  }) : messages = messages ?? [];

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'system_prompt': systemPrompt,
      'is_pinned': isPinned ? 1 : 0,
      'has_unread_messages': hasUnreadMessages ? 1 : 0,
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
      hasUnreadMessages: map['has_unread_messages'] == 1,
    );
  }
}
