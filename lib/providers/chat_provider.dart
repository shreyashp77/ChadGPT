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
import '../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class ChatProvider with ChangeNotifier {
  final DatabaseService _dbService = DatabaseService();
  final SettingsProvider _settingsProvider;
  final TtsService _ttsService = TtsService();
  
  // STT
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  
  // ... other imports

  List<ChatSession> _chats = [];
  ChatSession? _currentChat;

  bool _isTempMode = false;
  Persona? _currentPersona;
  List<Persona> _customPersonas = [];
  
  List<ChatSession> get chats => _chats;
  ChatSession? get currentChat => _currentChat;
  bool get isTyping => _activeGenerations.isNotEmpty;
  final Set<String> _activeGenerations = {};
  bool get isTempMode => _isTempMode;
  Persona get currentPersona => _currentPersona ?? Persona.presets.first;
  List<Persona> get allPersonas => [...Persona.presets, ..._customPersonas];
  
  // Voice getters
  bool get isListening => _isListening;
  bool get isTtsPlaying => _ttsService.isPlaying;
  TtsService get ttsService => _ttsService;

  bool _isContinuousVoiceMode = false;
  bool get isContinuousVoiceMode => _isContinuousVoiceMode;

  String? _currentVoiceSubtitle;
  String? get currentVoiceSubtitle => _currentVoiceSubtitle;

  // Generation timing for typing indicator
  DateTime? _generationStartTime;
  DateTime? get generationStartTime => _generationStartTime;

  ChatProvider(this._settingsProvider) {
    _loadChats();
    _loadCustomPersonas();
    
    // Listen to TTS state changes
    _ttsService.onStateChanged = (isPlaying) {
        notifyListeners();
    };

    // Listen to TTS subtitle changes
    _ttsService.onCurrentSentenceChanged = (text) {
        _currentVoiceSubtitle = text;
        notifyListeners();
    };

    // Auto-restart listening after TTS finishes in Continuous Mode
    _ttsService.onCompletion = () {
       if (_isContinuousVoiceMode && !_isListening && !isTyping) {
           // Small delay to ensure natural pause
           Future.delayed(const Duration(milliseconds: 500), () {
               if (_isContinuousVoiceMode && !_isListening && !isTyping) {
                   startListening(
                       (text) {
                           if (text.trim().isNotEmpty) {
                               sendMessage(text); // Auto-send in continuous mode
                           }
                       },
                       waitForFinal: true
                   );
               }
           });
       }
    };
  }

  // Voice Methods
  Future<bool> initializeStt() async {
      return await _speech.initialize(
        onStatus: (status) {
             if (status == 'done' || status == 'notListening') {
                 _isListening = false;
                 notifyListeners();
             }
        },
        onError: (error) {
             _isListening = false;
             notifyListeners();
             print('STT Error: $error');
             // If error in continuous mode (e.g. no speech), maybe we should just stop mode or retry?
             // For now, let's stop mode to avoid infinite error loops.
             // Handle transient errors without stopping the mode
             if (['error_speech_timeout', 'error_no_match', 'error_client'].contains(error.errorMsg)) {
                  // If we are in continuous mode, we might want to just restart listening or ignore.
                  // For client error, it signifies busy state, so we retry after small delay.
                  if (_isContinuousVoiceMode) {
                      Future.delayed(const Duration(milliseconds: 500), () {
                          if (_isContinuousVoiceMode && !_isListening && !isTyping) {
                               startListening(
                                   (text) {
                                       if (text.trim().isNotEmpty) sendMessage(text);
                                   },
                                   waitForFinal: true
                               );
                          }
                      });
                      return;
                  }
             }

             if (_isContinuousVoiceMode) {
                 stopContinuousVoiceMode();
             }
        },
      );
  }

  void toggleContinuousVoiceMode() {
      if (_isContinuousVoiceMode) {
          stopContinuousVoiceMode();
      } else {
          _isContinuousVoiceMode = true;
          // Start the loop
          startListening(
              (text) {
                  if (text.trim().isNotEmpty) {
                      sendMessage(text);
                  }
              },
              waitForFinal: true
          );
          notifyListeners();
      }
  }

  void stopContinuousVoiceMode() {
      _isContinuousVoiceMode = false;
      stopListening();
      // stopSpeaking calls ttsService.stop() which clears the queue
      stopSpeaking(); 
      notifyListeners();
  }

  Future<void> startListening(Function(String) onResult, {bool waitForFinal = false}) async { // Updated signature
       if (!_speech.isAvailable) {
           bool available = await initializeStt();
           if (!available) return;
       }
       
       if (_isListening) {
           await stopListening();
       }

       _isListening = true;
       notifyListeners();

       _speech.listen(
           onResult: (result) {
               // If expecting final result, ignore partials
               if (waitForFinal && !result.finalResult) return;
               
               onResult(result.recognizedWords);
           },
           listenFor: const Duration(seconds: 30),
           pauseFor: const Duration(seconds: 5),
           partialResults: true,
           localeId: "en_US",
           cancelOnError: true,
           listenMode: stt.ListenMode.dictation,
       );
  }

  Future<void> stopListening() async {
      _isListening = false;
      await _speech.stop();
      notifyListeners();
  }

  Future<void> speakMessage(String text) async {
      if (_ttsService.isPlaying) {
          await _ttsService.stop();
      } else {
          await _ttsService.speak(text);
      }
  }

  Future<void> stopSpeaking() async {
      await _ttsService.stop();
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
      
      // Mark as read if it has unread messages
      if (_currentChat!.hasUnreadMessages) {
          _currentChat!.hasUnreadMessages = false;
          await _dbService.markChatRead(chatId);
          // Don't need to notify listeners here as we'll do it below
      }

      // Load messages
      _currentChat!.messages = await _dbService.getMessages(chatId);
      notifyListeners();
    }
  }

 // ... (rest of file)



  Future<void> deleteChat(String chatId) async {
    await _dbService.deleteChat(chatId);
    _loadChats();
    if (_currentChat?.id == chatId) {
        startNewChat();
    }
  }

  Future<void> renameChat(String chatId, String newTitle) async {
    await _dbService.renameChat(chatId, newTitle);
    
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex != -1) {
        _chats[chatIndex].title = newTitle;
    }
    
    if (_currentChat?.id == chatId) {
        _currentChat!.title = newTitle;
    }
    
    notifyListeners();
  }

  Future<void> togglePinChat(String chatId) async {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;
    
    final chat = _chats[chatIndex];
    final newPinState = !chat.isPinned;
    
    await _dbService.togglePinChat(chatId, newPinState);
    
    chat.isPinned = newPinState;
    
    _chats.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    
    notifyListeners();
  }

  bool _abortGeneration = false;

  void stopGeneration() {
    _abortGeneration = true;
    _activeGenerations.clear();
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

    _currentChat!.messages.add(userMsg);
    notifyListeners();

    if (!_isTempMode) {
      if (_currentChat!.messages.length == 1) {
         final userContent = content;
         final modelId = _settingsProvider.settings.selectedModelId!;
         final chatId = _currentChat!.id;
         
         _settingsProvider.apiService.generateTitle(userContent, modelId).then((title) {
             _dbService.renameChat(chatId, title);

             final chatInListIndex = _chats.indexWhere((c) => c.id == chatId);
             if (chatInListIndex != -1) {
                 _chats[chatInListIndex].title = title;
             }

             if (_currentChat != null && _currentChat!.id == chatId) {
                 _currentChat!.title = title;
             }
             
             notifyListeners();
         });

         _currentChat!.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
         await _dbService.insertChat(_currentChat!);
         await _loadChats();

         final newChatIndex = _chats.indexWhere((c) => c.id == chatId);
         if (newChatIndex != -1) {
             final messages = _currentChat!.messages;
             _currentChat = _chats[newChatIndex];
             _currentChat!.messages = messages;
         }
      }
      await _dbService.insertMessage(userMsg, false);
    }

    await _generateAssistantResponse(content, useWebSearch: useWebSearch);
  }

  Future<void> regenerateLastResponse() async {
      if (_currentChat == null || _currentChat!.messages.isEmpty) return;
      
      final lastMsg = _currentChat!.messages.last;
      if (lastMsg.role != MessageRole.assistant) return;
      
      try {
          _currentChat!.messages.removeLast();
          if (!_isTempMode) {
              await _dbService.deleteMessage(lastMsg.id);
          }
          notifyListeners();
          
          if (_currentChat!.messages.isEmpty) return;
          final userMsg = _currentChat!.messages.last;
          
          final useWebSearch = _settingsProvider.settings.useWebSearch;
          
          await _generateAssistantResponse(userMsg.content, useWebSearch: useWebSearch);
      } catch (e) {
          print("Error regenerating: $e");
      }
  }

  Future<void> editMessage(String messageId, String newContent) async {
    if (_currentChat == null) return;
    
    final msgIndex = _currentChat!.messages.indexWhere((m) => m.id == messageId);
    if (msgIndex == -1) return;
    
    final originalMsg = _currentChat!.messages[msgIndex];
    if (originalMsg.role != MessageRole.user) return;
    
    final updatedMsg = originalMsg.copyWith(
      content: newContent,
      isEdited: true,
    );
    
    final messagesToDelete = _currentChat!.messages.skip(msgIndex + 1).toList();
    
    if (!_isTempMode) {
      for (final msg in messagesToDelete) {
        await _dbService.deleteMessage(msg.id);
      }
      await _dbService.updateMessage(updatedMsg);
    }
    
    _currentChat!.messages[msgIndex] = updatedMsg;
    _currentChat!.messages.removeRange(msgIndex + 1, _currentChat!.messages.length);
    notifyListeners();
    
    final useWebSearch = _settingsProvider.settings.useWebSearch;
    await _generateAssistantResponse(newContent, useWebSearch: useWebSearch);
  }

  int get totalTokensInCurrentChat {
    if (_currentChat == null) return 0;
    return _currentChat!.messages.fold(0, (sum, msg) => sum + msg.totalTokens);
  }
  
  // Active generation tracking

  
  Map<String, int> getTokenUsageForMessage(String messageId) {
    if (_currentChat == null) return {};
    final msg = _currentChat!.messages.where((m) => m.id == messageId).firstOrNull;
    if (msg == null) return {};
    return {
      'prompt': msg.promptTokens ?? 0,
      'completion': msg.completionTokens ?? 0,
      'total': msg.totalTokens,
    };
  }


  Future<void> _generateAssistantResponse(String userPrompt, {bool useWebSearch = false}) async {
    final targetChat = _currentChat;
    if (targetChat == null) return;

    _abortGeneration = false;
    _activeGenerations.add(targetChat.id); // Add to active set
    _generationStartTime = DateTime.now();
    notifyListeners();

    // Prepare for response
    final assistantMsgId = const Uuid().v4();
    
    // Track token usage
    int? promptTokens;
    int? completionTokens;
    
    // Flag to track if we've started receiving content and added the message
    bool hasAddedMessage = false;

    try {
      // Check for web search
      List<String>? searchResults;
      if (useWebSearch) {
          searchResults = await _settingsProvider.apiService.searchWeb(userPrompt);
      }
      
      if (_abortGeneration) return;

      final stream = _settingsProvider.apiService.chatCompletionStream(
        modelId: _settingsProvider.settings.selectedModelId!,
        // Pass all current messages from the TARGET chat
        messages: targetChat.messages, 
        searchResults: searchResults,
        systemPrompt: targetChat.systemPrompt,
      );

      String fullResponse = "";
      
      // Streaming TTS Buffer
      String sentenceBuffer = "";
      final sentenceTerminator = RegExp(r'(?:[.?!]\s+|\n+)'); 

      int lastHapticTime = 0; // Timestamp for throttling

      await for (final chunk in stream) {
        if (_abortGeneration) break;
        
        // Handle content
        if (chunk.content != null) {
          // ON FIRST CHUNK: Add the message to the list
          if (!hasAddedMessage) {
              final assistantMsg = Message(
                id: assistantMsgId,
                chatId: targetChat.id,
                role: MessageRole.assistant,
                content: '', // Start empty
                timestamp: DateTime.now(),
              );
              targetChat.messages.add(assistantMsg);
              hasAddedMessage = true;
              
              // Insert into DB immediately so it's visible if we reload the chat
              if (!targetChat.isTemp) {
                 await _dbService.insertMessage(assistantMsg, false);
              }
          }

          fullResponse += chunk.content!;
          
          // CHECK IF USER HAS SWITCHED CHATS
          // If the chat currently receiving the stream is NOT the active chat displayed in UI
          if (_currentChat?.id != targetChat.id) {
              // Mark as unread if not already marked
              if (!targetChat.hasUnreadMessages) {
                  targetChat.hasUnreadMessages = true;
                  // We update the DB for this property
                  // Since we are streaming, we probably don't want to hit DB on every chunk.
                  // But we only do this ONCE when the transition from read -> unread happens.
                  if (!targetChat.isTemp) {
                      // We can just update the chat object completely or use a specific update
                       _dbService.updateChat(targetChat);
                  }
              }
          }

          // Voice Mode: Streaming TTS
          // Note: Voice mode logic might still rely on "isListening" or global state, 
          // but sticking to targetChat for message data is key.
          if (_isContinuousVoiceMode) {
               sentenceBuffer += chunk.content!;
               
               while (true) {
                   final match = sentenceTerminator.firstMatch(sentenceBuffer);
                   if (match == null) break;
                   
                   final sentence = sentenceBuffer.substring(0, match.end);
                   
                   if (sentence.trim().isNotEmpty) {
                       _ttsService.speakQueued(sentence.trim());
                   }
                   
                   sentenceBuffer = sentenceBuffer.substring(match.end);
               }
          }
          
          // Update the message in the list
          if (targetChat.messages.isNotEmpty && targetChat.messages.last.id == assistantMsgId) {
             targetChat.messages.last = Message(
                id: assistantMsgId,
                chatId: targetChat.id,
                role: MessageRole.assistant,
                content: fullResponse,
                timestamp: DateTime.now(),
              );
          }

          // Throttled Haptic Feedback
          if (!_isContinuousVoiceMode && _currentChat?.id == targetChat.id) { // Only vibrate if viewing the chat
              final now = DateTime.now().millisecondsSinceEpoch;
              if (now - lastHapticTime > 80) {
                  HapticFeedback.selectionClick();
                  lastHapticTime = now;
              }
          }
          
          notifyListeners();
        }
        
        // Handle token usage (comes in final chunk)
        if (chunk.hasUsage) {
          promptTokens = chunk.promptTokens;
          completionTokens = chunk.completionTokens;
        }
      }
      
      if (hasAddedMessage) {
          // Update final message with token counts
           if (targetChat.messages.isNotEmpty && targetChat.messages.last.id == assistantMsgId) {
              targetChat.messages.last = targetChat.messages.last.copyWith(
                promptTokens: promptTokens,
                completionTokens: completionTokens,
              );
              
              // Update final message in DB
              if (!targetChat.isTemp) {
                 await _dbService.updateMessage(targetChat.messages.last);
              }
           }
      }

      // Voice Mode: Speak remaining buffer (if any)
      if (_isContinuousVoiceMode && sentenceBuffer.trim().isNotEmpty) {
          _ttsService.speakQueued(sentenceBuffer.trim());
      }

    } catch (e) {
      targetChat.messages.add(Message(
        id: const Uuid().v4(),
        chatId: targetChat.id,
        role: MessageRole.system,
        content: "Error: $e",
        timestamp: DateTime.now(),
      ));
    } finally {
      _activeGenerations.remove(targetChat.id);
      _generationStartTime = null;
      notifyListeners();
    }
  }
}
