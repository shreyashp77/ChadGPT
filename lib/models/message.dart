enum MessageRole { user, assistant, system }

class Message {
  final String id;
  final String chatId;
  final MessageRole role;
  final String content;
  final DateTime timestamp;
  final String? attachmentPath; // Path to local file if any
  final String? attachmentType; // 'image', 'file', etc.
  bool isDateSeparator; // For UI purposes

  Message({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType,
    this.isDateSeparator = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'attachment_path': attachmentPath,
      'attachment_type': attachmentType,
    };
  }

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'],
      chatId: map['chat_id'],
      role: MessageRole.values.firstWhere(
          (e) => e.toString().split('.').last == map['role'],
          orElse: () => MessageRole.user),
      content: map['content'],
      timestamp: DateTime.parse(map['timestamp']),
      attachmentPath: map['attachment_path'],
      attachmentType: map['attachment_type'],
    );
  }
}
