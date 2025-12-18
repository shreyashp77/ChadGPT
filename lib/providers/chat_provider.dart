import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:uuid/uuid.dart';
import '../models/chat_session.dart';
import '../models/message.dart';
import 'dart:convert';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../services/comfyui_service.dart';
import '../services/notification_service.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'dart:isolate'; // details: SendPort
import 'settings_provider.dart';
import '../models/persona.dart';
import '../services/tts_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../services/local_model_service.dart';
import '../models/app_settings.dart';  // For ApiProvider enum
class ChatProvider with ChangeNotifier, WidgetsBindingObserver {
  final DatabaseService _dbService = DatabaseService();
  final SettingsProvider _settingsProvider;
  final TtsService _ttsService = TtsService();
  final NotificationService _notificationService = NotificationService();
  
  // App lifecycle state
  bool _isAppInBackground = false;
  
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
  bool get isTyping => _currentChat != null && (_activeGenerations.contains(_currentChat!.id) || _activeImageGenerations.contains(_currentChat!.id));
  final Set<String> _activeGenerations = {};
  bool get isTempMode => _isTempMode;
  Persona get currentPersona => _currentPersona ?? Persona.presets.first;
  List<Persona> get allPersonas => [...Persona.presets, ..._customPersonas];
  
  // Folders support
  Set<String> _extraFolders = {};
  List<String> get allFolders {
      final folders = <String>{..._extraFolders};
      for (var chat in _chats) {
        if (chat.folder != null) folders.add(chat.folder!);
      }
      return folders.toList()..sort((a, b) => a.compareTo(b));
  }
  
  // Voice getters
  bool get isListening => _isListening;
  bool get isTtsPlaying => _ttsService.isPlaying;
  TtsService get ttsService => _ttsService;

  bool _isContinuousVoiceMode = false;
  bool get isContinuousVoiceMode => _isContinuousVoiceMode;

  String? _currentVoiceSubtitle;
  String? get currentVoiceSubtitle => _currentVoiceSubtitle;
  
  // Live transcription for real-time STT preview
  String? _liveTranscription;
  String? get liveTranscription => _liveTranscription;

  // Generation timing for typing indicator
  DateTime? _generationStartTime;
  DateTime? get generationStartTime => _generationStartTime;
  
  // Model loading indicator (shows model name while waiting for first chunk)
  String? _loadingModelName;
  String? get loadingModelName => _loadingModelName;
  
  // Image generation tracking
  final Set<String> _activeImageGenerations = {};
  bool get isGeneratingImage => _currentChat != null && _activeImageGenerations.contains(_currentChat!.id);

  // Deep Research tracking
  bool _isDeepResearching = false;
  bool get isDeepResearching => _isDeepResearching;
  String? _deepResearchStatus;
  String? get deepResearchStatus => _deepResearchStatus;
  
  // Generated images for current chat session (for media history)
  List<String> get generatedImages {
    if (_currentChat == null) return [];
    return _currentChat!.messages
        .where((m) => m.comfyuiFilename != null)
        .map((m) => m.comfyuiFilename!)
        .toList();
  }

  ChatProvider(this._settingsProvider) {
    _loadChats();
    _loadCustomPersonas();
    _loadExtraFolders();
    
    // Register for app lifecycle events
    WidgetsBinding.instance.addObserver(this);
    
    // Initialize foreground service
    _initForegroundTask();
    
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppInBackground = state == AppLifecycleState.paused || 
                          state == AppLifecycleState.inactive ||
                          state == AppLifecycleState.hidden;
  }

  // Initialize Foreground Task
  void _initForegroundTask() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'chadgpt_bg_service',
        channelName: 'Background Service',
        channelDescription: 'Keeps app alive during response generation',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<void> _startForegroundService() async {
    if (!await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.startService(
        notificationTitle: 'ChadGPT Generating',
        notificationText: 'Generating response in background...',
        callback: startCallback,
      );
    }
  }

  Future<void> _stopForegroundService() async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.stopService();
    }
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
                   if (_isContinuousVoiceMode) {
                        // ignore
                   } else {
                       _isContinuousVoiceMode = false;
                   }
             } else {
                 _isContinuousVoiceMode = false;
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
               // Update live transcription for voice overlay
               _liveTranscription = result.recognizedWords;
               notifyListeners();
               
               // If expecting final result, only call callback on final
               if (waitForFinal && !result.finalResult) return;
               
               // On final result, clear live transcription
               if (result.finalResult) {
                   _liveTranscription = null;
               }
               
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
      _liveTranscription = null;  // Clear live transcription
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

  Future<void> _loadExtraFolders() async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final List<String>? stored = prefs.getStringList('extra_folders');
        if (stored != null) {
            _extraFolders = stored.toSet();
            notifyListeners();
        }
      } catch (e) {
        print('Error loading extra folders: $e');
      }
  }
  
  Future<void> _saveExtraFolders() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('extra_folders', _extraFolders.toList());
  }

  Future<void> createFolder(String name) async {
      if (!_extraFolders.contains(name)) {
        _extraFolders.add(name);
        await _saveExtraFolders();
        notifyListeners();
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
  
  /// Load messages for a specific chat (for export or other purposes)
  Future<void> loadChatMessages(String chatId) async {
    final chat = _chats.firstWhere((c) => c.id == chatId, orElse: () => throw Exception('Chat not found'));
    if (chat.messages.isEmpty) {
      chat.messages = await _dbService.getMessages(chatId);
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

  Future<void> moveToFolder(String chatId, String? folder) async {
    final chatIndex = _chats.indexWhere((c) => c.id == chatId);
    if (chatIndex == -1) return;
    
    await _dbService.updateChatFolder(chatId, folder);
    _chats[chatIndex].folder = folder;
    notifyListeners();
  }

  Future<List<String>> getFolders() async {
    return await _dbService.getFolders();
  }

  bool _abortGeneration = false;

  void stopGeneration() {
    _abortGeneration = true;
    _activeGenerations.clear();
    
    // Also stop local model generation if using on-device provider
    if (_settingsProvider.settings.apiProvider == ApiProvider.localModel) {
      LocalModelService().stopGeneration();
    }
    
    notifyListeners();
  }

  Future<void> sendMessage(String content, {String? attachmentPath, String? attachmentType, bool useWebSearch = false}) async {
    if (_currentChat == null) startNewChat();
    
    // Check for /create command for image generation
    if (content.trim().toLowerCase().startsWith('/create ')) {
      final imagePrompt = content.substring(8).trim(); // Remove '/create ' prefix
      if (imagePrompt.isNotEmpty) {
        await _generateImage(imagePrompt);
        return;
      }
    }

    // Check for /research command
    if (content.trim().toLowerCase().startsWith('/research ')) {
      final topic = content.substring(10).trim();
      if (topic.isNotEmpty) {
        await startDeepResearch(topic);
        return;
      }
    }
    
    // 1. Add User Message IMMEDIATELY (Optimistic UI)
    _abortGeneration = false;
    
    final isOpenRouter = _settingsProvider.settings.apiProvider == ApiProvider.openRouter;
    final modelId = _settingsProvider.settings.selectedModelId;
    final isFree = isOpenRouter && modelId != null && modelId.contains(':free');
    
    String? apiKeyLabel;
    if (isOpenRouter) {
      apiKeyLabel = _settingsProvider.openRouterKeyInfo?['label'] as String?;
    }

    final userMsg = Message(
      id: const Uuid().v4(),
      chatId: _currentChat!.id,
      role: MessageRole.user,
      content: content,
      timestamp: DateTime.now(),
      attachmentPath: attachmentPath,
      attachmentType: attachmentType,
      modelId: modelId,
      isFree: isFree,
      apiKeyLabel: apiKeyLabel,
    );

    _currentChat!.messages.add(userMsg);
    notifyListeners();

    // 2. Persist User Message
    if (!_isTempMode) {
      if (_currentChat!.messages.length == 1) {
         _currentChat!.title = content.length > 30 ? '${content.substring(0, 30)}...' : content;
         await _dbService.insertChat(_currentChat!);
         
         // Reload to get properly synced object from DB, but keep our optimistically added message
         final oldMessages = _currentChat!.messages;
         await _loadChats();

         final newChatIndex = _chats.indexWhere((c) => c.id == _currentChat!.id);
         if (newChatIndex != -1) {
             _currentChat = _chats[newChatIndex];
             _currentChat!.messages = oldMessages; // Restore messages including the new one
         }

          // Generate Title in background if model is selected
         if (_settingsProvider.settings.selectedModelId != null) {
            final modelId = _settingsProvider.settings.selectedModelId!;
            final chatId = _currentChat!.id;
             _settingsProvider.apiService.generateTitle(content, modelId).then((title) {
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
         }
      }
      await _dbService.insertMessage(userMsg, false);
    }


    // 3. Validation - For local models, check LocalModelService instead of selectedModelId
    final isLocalModel = _settingsProvider.settings.apiProvider == ApiProvider.localModel;
    final hasLocalModelLoaded = isLocalModel && LocalModelService().isModelLoaded;
    
    if (!hasLocalModelLoaded && _settingsProvider.settings.selectedModelId == null) {
         // Add error system message instead of throwing
         final errorMsg = Message(
            id: const Uuid().v4(),
            chatId: _currentChat!.id,
            role: MessageRole.system,
            content: isLocalModel 
                ? "Error: No local model loaded. Go to Settings > On-Device > Manage Local Models to download and load a model."
                : "Error: No model selected. Please check your settings and connection.",
            timestamp: DateTime.now(),
         );
         _currentChat!.messages.add(errorMsg);
         notifyListeners();
         if (!_isTempMode) await _dbService.insertMessage(errorMsg, false);
         return;
    }

    // 4. Trigger Response (NON-BLOCKING)
    _generateAssistantResponse(content, useWebSearch: useWebSearch);
  }
  
  /// Generate an image using ComfyUI
  Future<void> _generateImage(String prompt) async {
    if (_currentChat == null) startNewChat();
    
    _abortGeneration = false; // Reset abort flag for new generation
    
    final comfyuiUrl = _settingsProvider.settings.comfyuiUrl;
    if (comfyuiUrl == null || comfyuiUrl.isEmpty) {
      throw Exception('ComfyUI server URL not configured. Please set it in Settings.');
    }
    
    final targetChat = _currentChat!;
    final chatId = targetChat.id;
    
    // Add user message with the /create command
    final userMsg = Message(
      id: const Uuid().v4(),
      chatId: chatId,
      role: MessageRole.user,
      content: '/create $prompt',
      timestamp: DateTime.now(),
    );
    targetChat.messages.add(userMsg);
    
    // Save chat if first message
    if (!_isTempMode && targetChat.messages.length == 1) {
      targetChat.title = 'Image: ${prompt.length > 20 ? '${prompt.substring(0, 20)}...' : prompt}';
      await _dbService.insertChat(targetChat);
      await _loadChats();
      
      final newChatIndex = _chats.indexWhere((c) => c.id == chatId);
      if (newChatIndex != -1) {
        _currentChat = _chats[newChatIndex];
        _currentChat!.messages = targetChat.messages;
      }
    }
    if (!_isTempMode) {
      await _dbService.insertMessage(userMsg, false);
    }
    
    // Create assistant message with generating state
    final assistantMsgId = const Uuid().v4();
    var assistantMsg = Message(
      id: assistantMsgId,
      chatId: chatId,
      role: MessageRole.assistant,
      content: 'Generating image...',
      timestamp: DateTime.now(),
      isImageGenerating: true,
      imageProgress: 0.0,
    );
    targetChat.messages.add(assistantMsg);
    _activeImageGenerations.add(chatId);
    notifyListeners();
    
    if (!_isTempMode) {
      await _dbService.insertMessage(assistantMsg, false);
    }
    
    try {
      final comfyui = ComfyuiService(comfyuiUrl);
      
      // Queue the prompt
      final promptId = await comfyui.queuePrompt(prompt);
      
      // Poll for progress
      String status = 'pending';
      Map<String, dynamic>? images;
      
      while (status != 'completed' && status != 'error' && !_abortGeneration) {
        await Future.delayed(const Duration(milliseconds: 500));
        
        final progress = await comfyui.getProgress(promptId);
        status = progress['status'] as String;
        final progressValue = (progress['progress'] as num?)?.toDouble() ?? 0.0;
        
        // Update progress in message
        final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
        if (msgIndex != -1) {
          targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
            imageProgress: progressValue,
            content: status == 'running' 
                ? 'Generating... ${(progressValue * 100).toInt()}%' 
                : 'Waiting in queue...',
          );
          notifyListeners();
        }
        
        if (status == 'completed') {
          images = progress;
        }
      }
      
      if (_abortGeneration) {
        // User cancelled
        final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
        if (msgIndex != -1) {
          targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
            content: 'Generation cancelled',
            isImageGenerating: false,
          );
          if (!_isTempMode) {
            await _dbService.updateMessage(targetChat.messages[msgIndex]);
          }
        }
        return;
      }
      
      // Get image data
      if (images != null && images['images'] != null) {
        final imageList = images['images'] as List<dynamic>;
        if (imageList.isNotEmpty) {
          final imageData = imageList[0] as Map<String, dynamic>;
          final filename = imageData['filename'] as String;
          final subfolder = imageData['subfolder'] as String? ?? '';
          final type = imageData['type'] as String? ?? 'output';
          
          final imageUrl = comfyui.getImageUrl(filename, subfolder, type);
          
          // Update message with image
          final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
          if (msgIndex != -1) {
            targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
              content: prompt,
              isImageGenerating: false,
              imageProgress: 1.0,
              generatedImageUrl: imageUrl,
              comfyuiFilename: filename,
            );
            
            if (!_isTempMode) {
              await _dbService.updateMessage(targetChat.messages[msgIndex]);
            }
          }
        }
      } else {
        throw Exception('No image generated');
      }
      
    } catch (e) {
      // Update message with error
      final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIndex != -1) {
        targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
          content: 'Error: ${e.toString().replaceAll('Exception: ', '')}',
          isImageGenerating: false,
        );
        if (!_isTempMode) {
          await _dbService.updateMessage(targetChat.messages[msgIndex]);
        }
      }
    } finally {
      _activeImageGenerations.remove(chatId);
      notifyListeners();
    }
  }
  
  /// Clear all generated image references from this chat
  /// Note: This only removes references in the app. Images remain in ComfyUI output folder.
  Future<void> clearGeneratedImages() async {
    if (_currentChat == null) return;
    
    final filenames = generatedImages;
    if (filenames.isEmpty) return;
    
    // Clear Flutter's image cache to prevent old images from showing
    PaintingBinding.instance.imageCache.clear();
    PaintingBinding.instance.imageCache.clearLiveImages();
    
    // Update messages to remove image references
    for (var i = 0; i < _currentChat!.messages.length; i++) {
      final msg = _currentChat!.messages[i];
      if (msg.comfyuiFilename != null) {
        _currentChat!.messages[i] = msg.copyWith(
          generatedImageUrl: null,
          comfyuiFilename: null,
          content: 'Image cleared from chat',
        );
        if (!_isTempMode) {
          await _dbService.updateMessage(_currentChat!.messages[i]);
        }
      }
    }
    notifyListeners();
  }

  Future<void> regenerateLastResponse() async {
      if (_currentChat == null || _currentChat!.messages.isEmpty) return;
      
      final lastMsg = _currentChat!.messages.last;
      if (lastMsg.role != MessageRole.assistant) return;
      
      // Check if this is an image response - delegate to regenerateLastImage
      if (lastMsg.generatedImageUrl != null || lastMsg.comfyuiFilename != null) {
        await regenerateLastImage();
        return;
      }
      
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
  
  /// Regenerate the last image with the same prompt
  Future<void> regenerateLastImage() async {
    if (_currentChat == null || _currentChat!.messages.isEmpty) return;
    
    // Find the last image response
    final lastMsg = _currentChat!.messages.last;
    if (lastMsg.role != MessageRole.assistant) return;
    
    // Find the user message before this response to get the prompt
    String? imagePrompt;
    for (int i = _currentChat!.messages.length - 2; i >= 0; i--) {
      final msg = _currentChat!.messages[i];
      if (msg.role == MessageRole.user && msg.content.toLowerCase().startsWith('/create ')) {
        imagePrompt = msg.content.substring(8).trim();
        break;
      }
    }
    
    if (imagePrompt == null) return;
    
    _abortGeneration = false; // Reset abort flag for regeneration
    
    final comfyuiUrl = _settingsProvider.settings.comfyuiUrl;
    if (comfyuiUrl == null || comfyuiUrl.isEmpty) return;
    
    final targetChat = _currentChat!;
    final chatId = targetChat.id;
    
    try {
      // Remove the last image response
      _currentChat!.messages.removeLast();
      if (!_isTempMode) {
        await _dbService.deleteMessage(lastMsg.id);
      }
      
      // Create new assistant message with generating state (no new user message)
      final assistantMsgId = const Uuid().v4();
      var assistantMsg = Message(
        id: assistantMsgId,
        chatId: chatId,
        role: MessageRole.assistant,
        content: 'Regenerating image...',
        timestamp: DateTime.now(),
        isImageGenerating: true,
        imageProgress: 0.0,
      );
      targetChat.messages.add(assistantMsg);
      _activeImageGenerations.add(chatId);
      notifyListeners();
      
      if (!_isTempMode) {
        await _dbService.insertMessage(assistantMsg, false);
      }
      
      // Queue prompt and poll for completion
      final comfyui = ComfyuiService(comfyuiUrl);
      final promptId = await comfyui.queuePrompt(imagePrompt);
      
      String status = 'pending';
      Map<String, dynamic>? images;
      
      while (status != 'completed' && status != 'error' && !_abortGeneration) {
        await Future.delayed(const Duration(milliseconds: 500));
        final progress = await comfyui.getProgress(promptId);
        status = progress['status'] as String;
        
        if (status == 'completed') {
          images = progress;
        }
      }
      
      if (_abortGeneration) {
        final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
        if (msgIndex != -1) {
          targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
            content: 'Regeneration cancelled',
            isImageGenerating: false,
          );
          if (!_isTempMode) {
            await _dbService.updateMessage(targetChat.messages[msgIndex]);
          }
        }
        return;
      }
      
      // Get image data
      if (images != null && images['images'] != null) {
        final imageList = images['images'] as List<dynamic>;
        if (imageList.isNotEmpty) {
          final imageData = imageList[0] as Map<String, dynamic>;
          final filename = imageData['filename'] as String;
          final subfolder = imageData['subfolder'] as String? ?? '';
          final type = imageData['type'] as String? ?? 'output';
          
          final imageUrl = comfyui.getImageUrl(filename, subfolder, type);
          
          final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
          if (msgIndex != -1) {
            targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
              content: imagePrompt,
              isImageGenerating: false,
              imageProgress: 1.0,
              generatedImageUrl: imageUrl,
              comfyuiFilename: filename,
            );
            
            if (!_isTempMode) {
              await _dbService.updateMessage(targetChat.messages[msgIndex]);
            }
          }
        }
      }
      
    } catch (e) {
      print("Error regenerating image: $e");
    } finally {
      _activeImageGenerations.remove(chatId);
      notifyListeners();
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
  
  /// Estimate current tokens based on message content (~4 chars = 1 token heuristic)
  int get estimatedCurrentTokens {
    if (_currentChat == null) return 0;
    int estimated = 0;
    for (final msg in _currentChat!.messages) {
      // Use actual tokens if available, otherwise estimate
      if (msg.totalTokens > 0) {
        estimated += msg.totalTokens;
      } else {
        // Estimate: ~4 characters per token
        estimated += (msg.content.length / 4).ceil();
      }
    }
    return estimated;
  }
  
  /// Default context window size (can be overridden per model in the future)
  static const int defaultContextWindow = 8192;
  
  /// Get context window usage as a percentage (0.0 to 1.0)
  double get contextWindowUsagePercent {
    if (_currentChat == null) return 0.0;
    final used = estimatedCurrentTokens;
    final limit = defaultContextWindow;
    return (used / limit).clamp(0.0, 1.0);
  }
  
  /// Returns true if approaching context limit (> 80%)
  bool get isNearContextLimit => contextWindowUsagePercent > 0.8;
  
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
    
    // Enable wake lock to keep generating in background
    WakelockPlus.enable();
    
    // Start foreground service to keep process alive
    _startForegroundService();
    
    // Set loading model name for indicator (use display name, not raw ID)
    if (_settingsProvider.settings.apiProvider == ApiProvider.localModel) {
      _loadingModelName = LocalModelService().loadedModel?.name ?? 'Local Model';
    } else {
      final modelId = _settingsProvider.settings.selectedModelId;
      _loadingModelName = modelId != null ? _settingsProvider.getModelDisplayName(modelId) : null;
    }
    
    final isOpenRouter = _settingsProvider.settings.apiProvider == ApiProvider.openRouter;
    final activeModelId = _settingsProvider.settings.selectedModelId;
    final isFreeModel = isOpenRouter && activeModelId != null && activeModelId.contains(':free');
    String? apiKeyLabel;
    if (isOpenRouter) {
      apiKeyLabel = _settingsProvider.openRouterKeyInfo?['label'] as String?;
    }

    notifyListeners();

    // Prepare for response
    final assistantMsgId = const Uuid().v4();
    
    // Track token usage
    int? promptTokens;
    int? completionTokens;
    
    // Flag to track if we've started receiving content and added the message
    bool hasAddedMessage = false;
    
    // Response content (declared here so it's accessible in catch block)
    String fullResponse = "";

    try {
      // Check if using local model provider
      final isLocalModel = _settingsProvider.settings.apiProvider == ApiProvider.localModel;
      
      // Check for web search
      List<String>? searchResults;
      if (useWebSearch) {
          searchResults = await _settingsProvider.apiService.searchWeb(userPrompt);
      }
      
      if (_abortGeneration) return;

      // For local models, modelId is not used (model is managed by LocalModelService)
      final effectiveModelId = isLocalModel 
          ? 'local' 
          : _settingsProvider.settings.selectedModelId!;
      
      final stream = _settingsProvider.apiService.chatCompletionStream(
        modelId: effectiveModelId,
        // Pass all current messages from the TARGET chat
        messages: targetChat.messages, 
        searchResults: searchResults,
        systemPrompt: targetChat.systemPrompt,
      );
      
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
              // Clear model loading indicator - we've received content
              _loadingModelName = null;
              
              final assistantMsg = Message(
                id: assistantMsgId,
                chatId: targetChat.id,
                role: MessageRole.assistant,
                content: '', // Start empty
                timestamp: DateTime.now(),
                modelId: activeModelId,
                isFree: isFreeModel,
                apiKeyLabel: apiKeyLabel,
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
                modelId: activeModelId,
                isFree: isFreeModel,
                apiKeyLabel: apiKeyLabel,
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
          // Check if generation was aborted with partial content
          final wasTruncated = _abortGeneration && fullResponse.isNotEmpty;
          
          // Update final message with token counts and truncation flag
           if (targetChat.messages.isNotEmpty && targetChat.messages.last.id == assistantMsgId) {
              targetChat.messages.last = targetChat.messages.last.copyWith(
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                isTruncated: wasTruncated,
              );
              
              // Update final message in DB
               if (!targetChat.isTemp) {
                  await _dbService.updateMessage(targetChat.messages.last);
               }
               
               // Send notification if app is in background
               if (_isAppInBackground && fullResponse.isNotEmpty) {
                 _notificationService.showMessageNotification(
                   title: targetChat.title,
                   body: fullResponse,
                   chatId: targetChat.id,
                 );
               }
           }
      }

      // Voice Mode: Speak remaining buffer (if any)
      if (_isContinuousVoiceMode && sentenceBuffer.trim().isNotEmpty) {
          _ttsService.speakQueued(sentenceBuffer.trim());
      }

    } catch (e) {
      // If app is in background and we have partial content, treat as truncation not error
      final isConnectionError = e.toString().contains('Connection closed') || 
                                 e.toString().contains('ClientException');
      
      if (_isAppInBackground && hasAddedMessage && fullResponse.isNotEmpty && isConnectionError) {
        // Update message as truncated, not errored (rare case if wake lock fails)
        final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
        if (msgIndex != -1) {
          targetChat.messages[msgIndex] = targetChat.messages[msgIndex].copyWith(
            isTruncated: true,
            promptTokens: promptTokens,
            completionTokens: completionTokens,
          );
          if (!targetChat.isTemp) {
            await _dbService.updateMessage(targetChat.messages[msgIndex]);
          }
        }
      } else {
        // Normal error handling
        final errorMsgId = hasAddedMessage ? assistantMsgId : const Uuid().v4();
        final errorMsg = Message(
          id: errorMsgId,
          chatId: targetChat.id,
          role: MessageRole.assistant,
          content: "Error: ${e.toString().replaceAll('Exception: ', '')}",
          timestamp: DateTime.now(),
          hasError: true,
        );
        
        if (hasAddedMessage) {
          // Update existing message
          final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
          if (msgIndex != -1) {
            targetChat.messages[msgIndex] = errorMsg;
            if (!targetChat.isTemp) {
              await _dbService.updateMessage(errorMsg);
            }
          }
        } else {
          // Add new error message
          targetChat.messages.add(errorMsg);
          if (!targetChat.isTemp) {
            await _dbService.insertMessage(errorMsg, false);
          }
        }
      }
    } finally {
      _activeGenerations.remove(targetChat.id);
      _generationStartTime = null;
      _loadingModelName = null;  // Clear model loading indicator
      
      // Disable wake lock when generation ends
      WakelockPlus.disable();
      
      // Stop foreground service
      _stopForegroundService();
      
      notifyListeners();
    }
  }
  
  /// Retry the last failed message
  Future<void> retryLastMessage() async {
    if (_currentChat == null || _currentChat!.messages.isEmpty) return;
    
    // Find the last assistant message with error
    final lastMsg = _currentChat!.messages.last;
    if (lastMsg.role != MessageRole.assistant || !lastMsg.hasError) return;
    
    // Remove the error message
    _currentChat!.messages.removeLast();
    if (!_isTempMode) {
      await _dbService.deleteMessage(lastMsg.id);
    }
    notifyListeners();
    
    if (_currentChat!.messages.isEmpty) return;
    
    // Find the last user message
    final userMsg = _currentChat!.messages.last;
    if (userMsg.role != MessageRole.user) return;
    
    final useWebSearch = _settingsProvider.settings.useWebSearch;
    await _generateAssistantResponse(userMsg.content, useWebSearch: useWebSearch);
  }
  Future<void> clearAllChats() async {
      await _dbService.clearChatHistory();
      _chats.clear();
      // Reset current chat
      startNewChat();
      notifyListeners();
  }
  Future<void> startDeepResearch(String topic) async {
    if (_currentChat == null) startNewChat();
    final targetChat = _currentChat!;
    
    _isDeepResearching = true;
    _deepResearchStatus = "Planning Research Strategy...";
    _activeGenerations.add(targetChat.id);
    notifyListeners();

    // 1. Add User Message
    final userMsg = Message(
      id: const Uuid().v4(),
      chatId: targetChat.id,
      role: MessageRole.user,
      content: "/research $topic",
      timestamp: DateTime.now(),
    );
    targetChat.messages.add(userMsg);
    if (!_isTempMode) await _dbService.insertMessage(userMsg, false);

    // 2. Add Assistant Message (Placeholder for status)
    final assistantMsgId = const Uuid().v4();
    var assistantMsg = Message(
      id: assistantMsgId,
      chatId: targetChat.id,
      role: MessageRole.assistant,
      content: "🔎 **Deep Research Initiative: $topic**\n\nStarting research process...",
      timestamp: DateTime.now(),
    );
    targetChat.messages.add(assistantMsg);
    if (!_isTempMode) await _dbService.insertMessage(assistantMsg, false);
    notifyListeners();

    try {
      final modelId = _settingsProvider.settings.selectedModelId ?? 'openai/gpt-3.5-turbo';
      
      // PHASE 1: Planning Queries
      _deepResearchStatus = "Generating search queries...";
      notifyListeners();
      
      final planningPrompt = "You are a research coordinator. Based on the topic '$topic', generate 3 distinct and targeted web search queries that will provide a comprehensive understanding. Return ONLY a JSON list of strings. Example: [\"query 1\", \"query 2\", \"query 3\"]";
      
      final planningResult = await _settingsProvider.apiService.chatCompletionStream(
        modelId: modelId,
        messages: [Message(id: 'plan', chatId: 'research', role: MessageRole.user, content: planningPrompt, timestamp: DateTime.now())],
      ).fold<String>("", (prev, chunk) => prev + (chunk.content ?? ""));
      
      List<String> queries = [];
      try {
        final startBracket = planningResult.indexOf('[');
        final endBracket = planningResult.lastIndexOf(']');
        if (startBracket != -1 && endBracket != -1) {
          final cleanedJson = planningResult.substring(startBracket, endBracket + 1);
          queries = List<String>.from(jsonDecode(cleanedJson));
        } else {
          throw Exception("Could not find JSON in response");
        }
      } catch (e) {
        queries = [topic, "$topic latest developments", "$topic detailed overview"];
      }

      String strategyContent = "🔎 **Deep Research Initiative: $topic**\n\n"
          "**Research Strategy:**\n" + queries.map((q) => "- $q").join("\n") + "\n\n"
          "**Status:** Executing searches...";
      
      final msgIndex = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIndex != -1) {
        assistantMsg = assistantMsg.copyWith(content: strategyContent);
        targetChat.messages[msgIndex] = assistantMsg;
      }
      notifyListeners();

      // PHASE 2: Searching and Scraping
      final List<String> scrapedContents = [];
      for (var query in queries) {
        _deepResearchStatus = "Searching: $query";
        notifyListeners();
        
        final results = await _settingsProvider.apiService.searchWeb(query);
        // Take top 2 unique URLs
        final urls = results
            .where((r) => r.contains("URL: "))
            .map((r) => r.split("URL: ").last.trim())
            .take(2)
            .toList();

        for (var url in urls) {
          _deepResearchStatus = "Reading content: $url";
          notifyListeners();
          final content = await _settingsProvider.apiService.scrapeUrl(url);
          scrapedContents.add("SOURCE: $url\nCONTENT:\n$content");
        }
      }

      // PHASE 3: Synthesis
      _deepResearchStatus = "Synthesizing Final Report...";
      String synthesisInfo = "🔎 **Deep Research Initiative: $topic**\n\n"
          "**Sources Analyzed:** ${scrapedContents.length}\n\n"
          "---\n\n";
          
      final msgIndex2 = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIndex2 != -1) {
        assistantMsg = assistantMsg.copyWith(content: synthesisInfo);
        targetChat.messages[msgIndex2] = assistantMsg;
      }
      notifyListeners();

      final synthesisPrompt = "You are an expert researcher. I have gathered the following information on '$topic' from various sources:\n\n" + 
          scrapedContents.join("\n\n---\n\n") + 
          "\n\nBased on these findings, write a comprehensive, professional research report in Markdown. "
          "Include sections for Overview, Key Findings, Technical Details, and Conclusion. "
          "Cite the source URLs provided where appropriate. Be thorough but concise. Markdown only.";

      String fullSynthesis = synthesisInfo;
      final stream = _settingsProvider.apiService.chatCompletionStream(
        modelId: modelId,
        messages: [Message(id: 'synth', chatId: 'research', role: MessageRole.user, content: synthesisPrompt, timestamp: DateTime.now())],
      );

      await for (final chunk in stream) {
        if (chunk.content != null) {
          fullSynthesis += chunk.content!;
          final msgIndex3 = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
          if (msgIndex3 != -1) {
            assistantMsg = assistantMsg.copyWith(content: fullSynthesis);
            targetChat.messages[msgIndex3] = assistantMsg;
          }
          notifyListeners();
        }
      }

      if (!_isTempMode) await _dbService.updateMessage(assistantMsg);

    } catch (e) {
      final msgIndexErr = targetChat.messages.indexWhere((m) => m.id == assistantMsgId);
      if (msgIndexErr != -1) {
        assistantMsg = assistantMsg.copyWith(content: assistantMsg.content + "\n\n❌ **Research Interrupted:** $e");
        targetChat.messages[msgIndexErr] = assistantMsg;
      }
      notifyListeners();
    } finally {
      _isDeepResearching = false;
      _deepResearchStatus = null;
      _activeGenerations.remove(targetChat.id);
      notifyListeners();
    }
  }
}

@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(FirstTaskHandler());
}

class FirstTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Background task started
  }

  @override
  Future<void> onEvent(DateTime timestamp, SendPort? sendPort) async {
    // Background event
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Background task destroyed
  }

  @override
  void onButtonPressed(String id) {}

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp("/");
  }


  @override
  void onRepeatEvent(DateTime timestamp) {
    // Optional
  }
}
