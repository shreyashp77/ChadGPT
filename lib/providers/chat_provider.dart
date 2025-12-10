import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';

class ChatProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SettingsProvider _settingsProvider;

  List<ChatSession> _chats = [];
  ChatSession? _currentChat;
  bool _isTyping = false;
  bool _isTempMode = false;
  
  List<ChatSession> get chats => _chats;
  ChatSession? get currentChat => _currentChat;
  bool get isTyping => _isTyping;
  bool get isTempMode => _isTempMode;

  ChatProvider(this._settingsProvider) {
    _loadChats();
  }

  Future<void> _loadChats() async {
    _chats = await _dbService.getChats();
    notifyListeners();
  }

  void toggleTempMode() {
    _isTempMode = !_isTempMode;
    // If we switch modes, we might want to clear current chat or start a new one
    startNewChat();
    notifyListeners();
  }

  void startNewChat() {
    _currentChat = ChatSession(
      id: const Uuid().v4(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
      isTemp: _isTempMode,
    );
    notifyListeners();
  }

  Future<void> loadChat(String chatId) async {
    if (_isTempMode) {
        // Cannot load saved chats in temp mode (or maybe we force switch out of temp mode?)
        // Let's force switch out of temp mode if a user selects a saved chat.
        _isTempMode = false;
    }
    
    // Find chat metadata
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
      _currentChat = _chats[chatIndex];
      // Load messages
      _currentChat!.messages = await _dbService.getMessages(chatId);
      notifyListeners();
    }
  }
  
  Future<void> deleteChat(String chatId) async {
    await _dbService.deleteChat(chatId);
    _loadChats();
    if (_currentChat?.id == chatId) {
        startNewChat();
    }
  }

  Future<void> sendMessage(String content, {String? attachmentPath, String? attachmentType, bool useWebSearch = false}) async {
    if (_currentChat == null) startNewChat();
    
    if (_settingsProvider.settings.selectedModelId == null) {
        throw Exception("No model selected. Please check your settings and connection.");
    }
    
    final userMsg = Message(
      id: const Uuid().v4(),
      chatId: _currentChat!.id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      attachmentPath: attachmentPath,
      attachmentType: attachmentType,
    );

    // Optimistic update
    _currentChat!.messages.add(userMsg);
    notifyListeners();

    // Save user message to DB
    if (!_isTempMode) {
      // If it's the first message, save the chat first
      if (_currentChat!.messages.length == 1) {
         // Generate title asynchronously
         final userContent = content;
         final modelId = _settingsProvider.settings.selectedModelId!;
         _settingsProvider.apiService.generateTitle(userContent, modelId).then((title) {
             if (_currentChat != null && _currentChat!.id == _currentChat!.id) {
                 _currentChat!.title = title;
                 _dbService.updateChat(_currentChat!);
                 notifyListeners();
             }
         });

         // Set temporary title first
         _currentChat!.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
         await _dbService.insertChat(_currentChat!);
         // Refresh chat list to show new chat
         _loadChats();  
      }
      await _dbService.insertMessage(userMsg, false);
    }

    _isTyping = true;
    notifyListeners();

    // Prepare for response
    final assistantMsgId = const Uuid().v4();
    final assistantMsg = Message(
      id: assistantMsgId,
      chatId: _currentChat!.id,
      role: MessageRole.assistant,
      content: '', // Start empty
      timestamp: DateTime.now(),
    );
    
    _currentChat!.messages.add(assistantMsg);
    notifyListeners();

    try {
      // Check for web search
      List<String>? searchResults;
      if (useWebSearch) {
          // Notify parsing search... (Maybe add a system message or a state indicator?)
          // For now simple blocking wait
          searchResults = await _settingsProvider.apiService.searchWeb(content);
      }

      final stream = _settingsProvider.apiService.chatCompletionStream(
        modelId: _settingsProvider.settings.selectedModelId!,
        messages: _currentChat!.messages.where((m) => m.id != assistantMsgId).toList(), // Exclude the empty one we just added? API needs history. Valid.
        searchResults: searchResults,
      );

      String fullResponse = "";
      
      await for (final chunk in stream) {
        fullResponse += chunk;
        // Update the last message in the list directly
        _currentChat!.messages.last = Message(
             id: assistantMsgId,
             chatId: _currentChat!.id,
             role: MessageRole.assistant,
             content: fullResponse,
             timestamp: DateTime.now(),
        );
        notifyListeners();
      }
      
      // Save assistant message to DB
      if (!_isTempMode) {
         await _dbService.insertMessage(_currentChat!.messages.last, false);
      }

    } catch (e) {
      _currentChat!.messages.add(Message(
        id: const Uuid().v4(),
        chatId: _currentChat!.id,
        role: MessageRole.system,
        content: "Error: $e",
        timestamp: DateTime.now(),
      ));
    } finally {
      _isTyping = false;
      notifyListeners();
    }
  }
}
