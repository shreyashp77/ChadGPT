import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import 'settings_provider.dart';
import '../models/persona.dart';

class ChatProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SettingsProvider _settingsProvider;

  // ... other imports

  List<ChatSession> _chats = [];
  ChatSession? _currentChat;
  bool _isTyping = false;
  bool _isTempMode = false;
  Persona? _currentPersona;
  List<Persona> _customPersonas = [];
  
  List<ChatSession> get chats => _chats;
  ChatSession? get currentChat => _currentChat;
  bool get isTyping => _isTyping;
  bool get isTempMode => _isTempMode;
  Persona get currentPersona => _currentPersona ?? Persona.presets.first;
  List<Persona> get allPersonas => [...Persona.presets, ..._customPersonas];

  ChatProvider(this._settingsProvider) {
    _loadChats();
    _loadCustomPersonas();
  }

  Future<void> _loadChats() async {
    _chats = await _dbService.getChats();
    notifyListeners();
  }

  Future<void> _loadCustomPersonas() async {
    final prefs = await SharedPreferences.getInstance();
    final String? personasJson = prefs.getString('custom_personas');
    if (personasJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(personasJson);
        _customPersonas = decoded.map((p) => Persona.fromMap(p)).toList();
        notifyListeners();
      } catch (e) {
        print('Error loading custom personas: $e');
      }
    }
  }

  Future<void> _saveCustomPersonas() async {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(_customPersonas.map((p) => p.toMap()).toList());
      await prefs.setString('custom_personas', encoded);
  }

  Future<void> addCustomPersona(String name, String description, String systemPrompt) async {
      final newPersona = Persona(
          id: const Uuid().v4(),
          name: name,
          description: description,
          icon: Icons.person_outline,
          systemPrompt: systemPrompt,
          isCustom: true,
      );
      _customPersonas.add(newPersona);
      await _saveCustomPersonas();
      notifyListeners();
  }

  Future<void> deleteCustomPersona(String id) async {
      _customPersonas.removeWhere((p) => p.id == id);
      // If deleted persona was selected, revert to default
      if (_currentPersona?.id == id) {
          _currentPersona = Persona.presets.first;
      }
      await _saveCustomPersonas();
      notifyListeners();
  }

  void toggleTempMode() {
    _isTempMode = !_isTempMode;
    // If we switch modes, we might want to clear current chat or start a new one
    startNewChat();
    notifyListeners();
  }

  void setPersona(Persona persona) {
      _currentPersona = persona;
      if (_currentChat != null) {
          _currentChat!.systemPrompt = persona.systemPrompt;
          // Only update DB if the chat has actually been saved (has messages)
          if (_currentChat!.messages.isNotEmpty) {
             _dbService.updateChat(_currentChat!);
          }
      }
      notifyListeners();
  }

  void startNewChat({Persona? persona}) {
    _currentPersona = persona ?? Persona.presets.first;
    _currentChat = ChatSession(
      id: const Uuid().v4(),
      title: 'New Chat',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      messages: [],
      isTemp: _isTempMode,
      systemPrompt: _currentPersona!.systemPrompt,
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

  Future<void> renameChat(String chatId, String newTitle) async {
    await _dbService.renameChat(chatId, newTitle);
    
    // Update local list
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
        _chats[chatIndex].title = newTitle;
    }
    
    // Update current chat if it's the one being renamed
    if (_currentChat?.id == chatId) {
        _currentChat!.title = newTitle;
    }
    
    notifyListeners();
  }

  bool _abortGeneration = false;

  void stopGeneration() {
    _abortGeneration = true;
    _isTyping = false;
    notifyListeners();
  }

  Future<void> sendMessage(String content, {String? attachmentPath, String? attachmentType, bool useWebSearch = false}) async {
    if (_currentChat == null) startNewChat();
    
    if (_settingsProvider.settings.selectedModelId == null) {
        throw Exception("No model selected. Please check your settings and connection.");
    }

    _abortGeneration = false;
    
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
      
      if (_abortGeneration) return;

      final stream = _settingsProvider.apiService.chatCompletionStream(
        modelId: _settingsProvider.settings.selectedModelId!,
        messages: _currentChat!.messages.where((m) => m.id != assistantMsgId).toList(), 
        searchResults: searchResults,
        systemPrompt: _currentChat!.systemPrompt,
      );

      String fullResponse = "";
      
      int lastHapticTime = 0; // Timestamp for throttling

      await for (final chunk in stream) {
        if (_abortGeneration) break;
        
        fullResponse += chunk;
        
         // Update the message in the list
        _currentChat!.messages.last = Message(
          id: assistantMsgId,
          chatId: _currentChat!.id,
          role: MessageRole.assistant,
          content: fullResponse,
          timestamp: DateTime.now(),
        );

        // Throttled Haptic Feedback (every ~80ms)
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - lastHapticTime > 80) {
            HapticFeedback.selectionClick();
            lastHapticTime = now;
        }
        
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
