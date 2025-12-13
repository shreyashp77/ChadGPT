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
  
  // Token tracking
  final int? promptTokens;
  final int? completionTokens;
  
  // Edit tracking
  final bool isEdited;
  
  // ComfyUI Image Generation
  final String? generatedImageUrl;    // URL to fetch from ComfyUI
  final String? comfyuiFilename;       // Filename in ComfyUI output folder
  final bool isImageGenerating;        // Whether image is being generated
  final double imageProgress;          // Progress 0.0-1.0

  Message({
    required this.id,
    required this.chatId,
    required this.role,
    required this.content,
    required this.timestamp,
    this.attachmentPath,
    this.attachmentType,
    this.isDateSeparator = false,
    this.promptTokens,
    this.completionTokens,
    this.isEdited = false,
    this.generatedImageUrl,
    this.comfyuiFilename,
    this.isImageGenerating = false,
    this.imageProgress = 0.0,
  });

  // Helper to get total tokens for this message
  int get totalTokens => (promptTokens ?? 0) + (completionTokens ?? 0);

  // Sentinel value for explicitly setting nullable fields to null
  static const _unset = Object();
  
  // Create a copy with updated fields
  // For nullable fields (generatedImageUrl, comfyuiFilename), pass the sentinel _unset
  // to keep existing value, or pass null explicitly to clear them
  Message copyWith({
    String? id,
    String? chatId,
    MessageRole? role,
    String? content,
    DateTime? timestamp,
    String? attachmentPath,
    String? attachmentType,
    bool? isDateSeparator,
    int? promptTokens,
    int? completionTokens,
    bool? isEdited,
    Object? generatedImageUrl = _unset,
    Object? comfyuiFilename = _unset,
    bool? isImageGenerating,
    double? imageProgress,
  }) {
    return Message(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      role: role ?? this.role,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      attachmentPath: attachmentPath ?? this.attachmentPath,
      attachmentType: attachmentType ?? this.attachmentType,
      isDateSeparator: isDateSeparator ?? this.isDateSeparator,
      promptTokens: promptTokens ?? this.promptTokens,
      completionTokens: completionTokens ?? this.completionTokens,
      isEdited: isEdited ?? this.isEdited,
      generatedImageUrl: generatedImageUrl == _unset 
          ? this.generatedImageUrl 
          : generatedImageUrl as String?,
      comfyuiFilename: comfyuiFilename == _unset 
          ? this.comfyuiFilename 
          : comfyuiFilename as String?,
      isImageGenerating: isImageGenerating ?? this.isImageGenerating,
      imageProgress: imageProgress ?? this.imageProgress,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chat_id': chatId,
      'role': role.toString().split('.').last,
      'content': content,
      'timestamp': timestamp.toIso8601String(),
      'attachment_path': attachmentPath,
      'attachment_type': attachmentType,
      'prompt_tokens': promptTokens,
      'completion_tokens': completionTokens,
      'is_edited': isEdited ? 1 : 0,
      'generated_image_url': generatedImageUrl,
      'comfyui_filename': comfyuiFilename,
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
      promptTokens: map['prompt_tokens'],
      completionTokens: map['completion_tokens'],
      isEdited: map['is_edited'] == 1,
      generatedImageUrl: map['generated_image_url'],
      comfyuiFilename: map['comfyui_filename'],
    );
  }
}
