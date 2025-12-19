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
  String? folder;  // Folder for organization
  String? documentContext;  // Extracted text from uploaded document
  String? documentName;     // Filename of uploaded document

  /// Returns true if the chat contains any generated media (images)
  bool get hasGeneratedMedia => messages.any((m) => m.generatedImageUrl != null);
  
  /// Returns true if the chat contains any user attachments (files/images)
  bool get hasAttachments => messages.any((m) => m.attachmentPath != null);
  
  /// Returns true if the chat has a document loaded for context
  bool get hasDocument => documentContext != null && documentContext!.isNotEmpty;

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
    this.folder,
    this.documentContext,
    this.documentName,
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
      'folder': folder,
      'document_context': documentContext,
      'document_name': documentName,
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
      folder: map['folder'],
      documentContext: map['document_context'],
      documentName: map['document_name'],
    );
  }
}
