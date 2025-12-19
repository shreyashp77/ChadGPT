import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../models/message.dart';
import '../utils/theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_persona_dialog.dart';
import '../widgets/voice_mode_overlay.dart';
import '../widgets/typing_indicator.dart';
import '../widgets/media_history_sheet.dart';
import '../services/local_model_service.dart';
import '../services/database_service.dart';
import '../services/document_service.dart';
import '../models/local_model.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _actionButtonKey = GlobalKey(); // Key for the action button
  String? _pendingAttachmentPath;
  String? _pendingAttachmentType; // 'image' or 'file'
  bool _showScrollDownButton = false; // State to toggle visibility of scroll button
  bool _hasScrolledForGeneration = false; // Prevents continuous scrolling during generation

  bool _useWebSearch = false; // Local state for search
  bool _useImageCreate = false; // Local state for image creation mode
  bool _useDeepResearch = false; // Local state for deep research mode

  void _scrollToBottom({bool isImmediate = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (isImmediate) {
           _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        } else {
           _scrollController.animateTo(
             _scrollController.position.maxScrollExtent,
             duration: const Duration(milliseconds: 300),
             curve: Curves.easeOut,
           );
        }
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 100; // Threshold of 100
      setState(() {
        _showScrollDownButton = !isAtBottom;
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _textController.addListener(() {
        if (mounted) {
          // Auto-detect /create command and enable image mode
          final text = _textController.text;
          if (!_useImageCreate && text.toLowerCase().startsWith('/create ')) {
            // Enable image mode and remove /create from text - use post frame to avoid issues
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _textController.text.toLowerCase().startsWith('/create ')) {
                final newText = _textController.text.substring(8);
                _textController.text = newText;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: newText.length),
                );
                setState(() => _useImageCreate = true);
              }
            });
          } else if (!_useImageCreate && text.toLowerCase() == '/create') {
            // Just /create typed (without space) - wait for space or detect on blur
            // For now, just trigger setState for UI updates
            setState(() {});
          } else if (!_useDeepResearch && text.toLowerCase().startsWith('/research ')) {
            // Auto-detect /research command and enable research mode
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && _textController.text.toLowerCase().startsWith('/research ')) {
                final newText = _textController.text.substring(10);
                _textController.text = newText;
                _textController.selection = TextSelection.fromPosition(
                  TextPosition(offset: newText.length),
                );
                setState(() => _useDeepResearch = true);
              }
            });
          } else {
            setState(() {});
          }
        }
    });
    // Start a new chat immediately if none exists
    WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatProvider = context.read<ChatProvider>();
        // Sync local web search state
        setState(() {
            _useWebSearch = context.read<SettingsProvider>().settings.useWebSearch;
        });

        if (chatProvider.currentChat == null) {
            chatProvider.startNewChat();
        }
    });
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final currentChat = chatProvider.currentChat;

    // Auto-scroll to bottom once when generation starts (sticky scroll)
    // Only scroll if user hasn't manually scrolled up
    if (chatProvider.isTyping) {
      if (!_hasScrolledForGeneration && !_showScrollDownButton) {
        _scrollToBottom(isImmediate: true);
        _hasScrolledForGeneration = true;
      }
    } else {
      // Reset the flag when generation completes
      _hasScrolledForGeneration = false;
    }

    return Scaffold(
      backgroundColor: chatProvider.isTempMode ? const Color(0xFF202124) : null, // Darker background for Incognito
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: false,
        title: Consumer<ChatProvider>(
          builder: (context, chat, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                chat.currentChat?.title ?? 'New Chat',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
               if (chat.currentPersona.id != 'default')
                 Text(
                   chat.currentPersona.name,
                   style: const TextStyle(color: Colors.white54, fontSize: 12),
                 ),
            ],
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
         leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            onPressed: () {
               HapticFeedback.lightImpact(); // Haptic
               Scaffold.of(context).openDrawer();
            },
          ),
        ),
        actions: [
            // Media History Button (only show when images exist)
            Consumer<ChatProvider>(
                builder: (context, chat, _) {
                    final hasImages = chat.generatedImages.isNotEmpty;
                    if (!hasImages) return const SizedBox.shrink();
                    return IconButton(
                        icon: const Icon(Icons.photo_library, color: Colors.white70),
                        tooltip: 'Media History',
                        onPressed: () {
                            HapticFeedback.lightImpact();
                            showModalBottomSheet(
                                context: context,
                                backgroundColor: Colors.transparent,
                                isScrollControlled: true,
                                builder: (_) => const MediaHistorySheet(),
                            );
                        },
                    );
                },
            ),
            // Persona Selector
            Consumer<ChatProvider>(
                builder: (context, chat, _) => IconButton(
                    icon: Icon(chat.currentPersona.icon, color: Colors.white70),
                    tooltip: 'Change Persona',
                    onPressed: () {
                        HapticFeedback.lightImpact(); // Haptic
                        _showPersonaSelector(context);
                    },
                ),
            ),
            Consumer<ChatProvider>(
                builder: (context, chat, _) => IconButton(
                    icon: chat.isTempMode 
                      ? const Icon(Icons.edit_square, color: Colors.white)
                      : FaIcon(FontAwesomeIcons.userSecret, color: Colors.white70, size: 20),
                    tooltip: chat.isTempMode ? 'New Normal Chat' : 'Go Incognito',
                    onPressed: () {
                        HapticFeedback.lightImpact(); // Haptic
                        chat.toggleTempMode();
                    },
                ),
            ),

        ],
        flexibleSpace: ClipRRect(
             child: BackdropFilter(
                 filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)),
             )
        ),
      ),
      body: Stack(
        children: [
          // Message List
          Positioned.fill(
            child: currentChat == null || currentChat.messages.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                         Icon(
                             chatProvider.isTempMode ? Icons.visibility_off : Icons.chat_bubble_outline, 
                             size: 64, 
                             color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                         ),
                         const SizedBox(height: 16),
                         Text(
                             chatProvider.isTempMode ? 'Incognito Mode' : 'Start talking!', 
                             style: const TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold)
                         ),
                         if (chatProvider.isTempMode)
                             const Padding(
                                 padding: EdgeInsets.only(top: 8.0),
                                 child: Text('History is paused', style: TextStyle(fontSize: 14, color: Colors.grey)),
                             ),
                      ],
                    )
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                        bottom: 160 // Increased space for input area
                    ),
                    // Virtualization optimizations for long conversations
                    addAutomaticKeepAlives: false,  // Don't keep off-screen widgets alive
                    addRepaintBoundaries: true,     // Isolate repaints
                    cacheExtent: 500.0,             // Pre-render nearby items
                    itemCount: currentChat.messages.length + (chatProvider.isTyping && currentChat.messages.last.role != MessageRole.assistant ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= currentChat.messages.length) {
                          // Show typing indicator with model name if loading
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: TypingIndicator(
                              modelName: chatProvider.loadingModelName,
                              statusText: chatProvider.deepResearchStatus,
                            ),
                          );
                      }
                      return MessageBubble(message: currentChat.messages[index]);
                    },
                  ),
          ),
          
          // Floating Input Area
          SafeArea(
            left: false, 
            right: false,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                   if (_showScrollDownButton)
                     Container(
                       margin: const EdgeInsets.only(bottom: 8, right: 16),
                       child: FloatingActionButton.small(
                         onPressed: _scrollToBottom,
                         backgroundColor: Theme.of(context).colorScheme.surface,
                         child: Icon(Icons.arrow_downward, color: Theme.of(context).colorScheme.onSurface),
                       ),
                     ),
                   
                   // Context Window Usage Indicator - compact integrated design
                   if (chatProvider.currentChat != null && chatProvider.estimatedCurrentTokens > 500)
                     Container(
                       margin: const EdgeInsets.only(bottom: 6, left: 24, right: 24),
                       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                       decoration: BoxDecoration(
                         color: chatProvider.isNearContextLimit 
                           ? Colors.orange.withValues(alpha: 0.1)
                           : Theme.of(context).colorScheme.surface.withValues(alpha: 0.6),
                         borderRadius: BorderRadius.circular(20),
                         border: Border.all(
                           color: chatProvider.isNearContextLimit 
                             ? Colors.orange.withValues(alpha: 0.3)
                             : Colors.white.withValues(alpha: 0.05),
                         ),
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min,
                         children: [
                           // Progress circle
                           SizedBox(
                             width: 16,
                             height: 16,
                             child: CircularProgressIndicator(
                               value: chatProvider.contextWindowUsagePercent,
                               strokeWidth: 2,
                               backgroundColor: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1),
                               valueColor: AlwaysStoppedAnimation(
                                 chatProvider.isNearContextLimit 
                                   ? Colors.orange 
                                   : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7)
                               ),
                             ),
                           ),
                           const SizedBox(width: 8),
                           // Token count
                           Text(
                             '${chatProvider.estimatedCurrentTokens} / ${ChatProvider.defaultContextWindow}',
                             style: TextStyle(
                               color: chatProvider.isNearContextLimit 
                                 ? Colors.orange[300]
                                 : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                               fontSize: 11,
                               fontWeight: FontWeight.w500,
                             ),
                           ),
                           if (chatProvider.isNearContextLimit) ...[
                             const SizedBox(width: 6),
                             Icon(Icons.warning_amber_rounded, size: 12, color: Colors.orange[300]),
                           ],
                         ],
                       ),
                     ),
                   
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      boxShadow: [
                           BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 5),
                           )
                      ]
                    ),
                    child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                           // Top: Feature Chips (Web Search, Attachments, Image Mode, Research Mode, Document)
                           if (_useWebSearch || _pendingAttachmentPath != null || _useImageCreate || _useDeepResearch || chatProvider.currentChat?.hasDocument == true)
                             Padding(
                               padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                               child: SingleChildScrollView(
                                 scrollDirection: Axis.horizontal,
                                 child: Row(
                                   children: [
                                     // Image mode chip
                                     if (_useImageCreate)
                                       Padding(
                                         padding: const EdgeInsets.only(right: 6),
                                         child: _buildFeatureChip(
                                           context,
                                           icon: Icons.brush,
                                           label: 'Image',
                                           chipColor: Theme.of(context).colorScheme.primary,
                                           onRemove: () => setState(() => _useImageCreate = false),
                                         ),
                                       ),
                                     // Research mode chip
                                     if (_useDeepResearch)
                                       Padding(
                                         padding: const EdgeInsets.only(right: 6),
                                         child: _buildFeatureChip(
                                           context,
                                           icon: Icons.school,
                                           label: 'Research',
                                           onRemove: () => setState(() => _useDeepResearch = false),
                                           chipColor: Theme.of(context).colorScheme.primary,
                                         ),
                                       ),
                                     if (_useWebSearch)
                                       Padding(
                                         padding: const EdgeInsets.only(right: 6),
                                         child: _buildFeatureChip(
                                           context,
                                           icon: Icons.public,
                                           label: 'Search',
                                           onRemove: () => setState(() => _useWebSearch = false),
                                         ),
                                       ),
                                     if (_pendingAttachmentPath != null)
                                       Padding(
                                         padding: const EdgeInsets.only(right: 6),
                                         child: _buildFeatureChip(
                                           context,
                                           icon: _pendingAttachmentType == 'image' ? Icons.image : Icons.attach_file,
                                           label: _pendingAttachmentPath!.split('/').last,
                                           onRemove: () => setState(() {
                                             _pendingAttachmentPath = null;
                                             _pendingAttachmentType = null;
                                           }),
                                         ),
                                       ),
                                      // Document context chip
                                      if (chatProvider.currentChat?.hasDocument == true)
                                        Padding(
                                          padding: const EdgeInsets.only(right: 6),
                                          child: _buildFeatureChip(
                                            context,
                                            icon: Icons.description,
                                            label: chatProvider.currentChat!.documentName ?? 'Document',
                                            chipColor: Colors.orange,
                                            onRemove: () {
                                              chatProvider.clearDocument();
                                            },
                                          ),
                                        ),
                                   ],
                                 ),
                               ),
                             ),

                           // Main Row: [Plus Button] [Input Field] [Voice Button]
                           Row(
                             crossAxisAlignment: CrossAxisAlignment.end,
                             children: [
                               // Plus / Attachment Button
                               IconButton(
                                 icon: Icon(
                                   Icons.add_circle_outline, 
                                   color: Theme.of(context).colorScheme.primary
                                 ),
                                 onPressed: _showAttachmentOptions, 
                               ),

                               // Expanded TextField
                               Expanded(
                                 child: TextField(
                                   controller: _textController,
                                   style: const TextStyle(fontSize: 16),
                                   decoration: const InputDecoration(
                                     hintText: 'Ask anything',
                                     border: InputBorder.none,
                                     isDense: true,
                                     contentPadding: EdgeInsets.symmetric(vertical: 12),
                                   ),
                                   maxLines: null,
                                   keyboardType: TextInputType.multiline,
                                   textCapitalization: TextCapitalization.sentences,
                                 ),
                               ),

                               // Action Button: Handles Voice/STT (Default), Sending (HasContent), or Stopping (Generating/Listening)
                               Builder(
                                   builder: (context) {
                                       final hasContent = _textController.text.trim().isNotEmpty || _pendingAttachmentPath != null;
                                       final isGenerating = chatProvider.isTyping;
                                       final isListening = chatProvider.isListening;
                                       
                                       // Determine State
                                       // 1. Generating -> Stop Generation
                                       // 2. Listening -> Stop Listening
                                       // 3. Content -> Send Message
                                       // 4. Empty -> Show Voice Options
                                       
                                       IconData icon;
                                       String tooltip;
                                       VoidCallback onPressed;
                                       
                                       if (isGenerating) {
                                           icon = Icons.stop;
                                           tooltip = 'Stop Generating';
                                           onPressed = () {
                                               HapticFeedback.lightImpact();
                                               chatProvider.stopGeneration();
                                           };
                                       } else if (isListening) {
                                           icon = Icons.mic_off;
                                           tooltip = 'Stop Listening';
                                           onPressed = () {
                                               HapticFeedback.lightImpact();
                                               chatProvider.stopListening();
                                           };
                                       } else if (hasContent) {
                                           icon = Icons.arrow_upward;
                                           tooltip = 'Send Message';
                                           onPressed = () {
                                               HapticFeedback.lightImpact();
                                               FocusScope.of(context).unfocus();
                                               _sendMessage();
                                           };
                                       } else {
                                           icon = Icons.graphic_eq;
                                           tooltip = 'Voice Options';
                                           onPressed = () => _showVoiceOptions(context);
                                       }

                                       return Container(
                                           key: _actionButtonKey, // Attach Key Here
                                           decoration: BoxDecoration(
                                               shape: BoxShape.circle,
                                               color: Theme.of(context).colorScheme.primary, // Solid Primary Color
                                               boxShadow: [
                                                   BoxShadow(
                                                       color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5), 
                                                       blurRadius: 10, 
                                                       spreadRadius: 2
                                                   )
                                               ]
                                           ),
                                           child: IconButton(
                                               icon: isListening 
                                                  ? Icon(icon, color: Colors.white, size: 24).animate(onPlay: (controller) => controller.repeat(reverse: true)).fade(duration: 500.ms, begin: 0.5, end: 1.0)
                                                  : Icon(icon, color: Colors.white, size: 24),
                                               tooltip: tooltip,
                                               onPressed: onPressed,
                                           ),
                                       );
                                   }
                               ),
                             ],
                           ),
                        ],
                      ),

                  ),
                ),
              ),
                  ),
                ],
              ),
            ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutQuad, duration: 600.ms),
          ),
        ],
      ),
    );
  }


  /// Get the label for the model selector button
  /// Shows local model name when using on-device provider
  String _getModelSelectorLabel(SettingsProvider settingsProvider) {
    if (settingsProvider.settings.apiProvider == ApiProvider.localModel) {
      final localModelService = LocalModelService();
      if (localModelService.isModelLoaded && localModelService.loadedModel != null) {
        return localModelService.loadedModel!.name;
      } else {
        return 'No Local Model';
      }
    }
    return settingsProvider.getModelDisplayName(settingsProvider.settings.selectedModelId ?? '');
  }

  void _showAttachmentOptions() async {
      final settingsProvider = context.read<SettingsProvider>();
      final chatProvider = context.read<ChatProvider>();
      
      // Dismiss keyboard first
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;

      // Get position for the plus button (left side)
      final screenHeight = MediaQuery.of(context).size.height;
      // Add extra space if pills are visible
      final pillsVisible = _useWebSearch || _pendingAttachmentPath != null || _useDeepResearch || _useImageCreate || chatProvider.currentChat?.hasDocument == true;
      final bottomOffset = MediaQuery.of(context).padding.bottom + 16 + 56 + 16 + (pillsVisible ? 32 : 0);
      const leftOffset = 16.0 + 8.0;

      Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
               return Stack(
                   children: [
                       // Backdrop with semi-transparent dark overlay for readability
                       Positioned.fill(
                           child: GestureDetector(
                               onTap: () {
                                   Navigator.pop(context);
                                   // Unfocus after popup closes to prevent keyboard from reopening
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                       FocusManager.instance.primaryFocus?.unfocus();
                                   });
                               },
                               behavior: HitTestBehavior.opaque,
                               child: Container(color: Colors.black.withValues(alpha: 0.85)),
                           ),
                       ),
                       // Floating Options
                       Positioned(
                           left: leftOffset, 
                           bottom: bottomOffset, 
                           child: Material(
                               type: MaterialType.transparency,
                               child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                       // Model Selector
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.auto_awesome,
                                           label: _getModelSelectorLabel(settingsProvider),
                                           bgColor: Theme.of(context).colorScheme.primary,
                                           iconColor: Colors.white,
                                           onTap: () {
                                               Navigator.pop(context);
                                               HapticFeedback.lightImpact();
                                               _showGrokModelSelector(context);
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms).fadeIn(),
                                       
                                       const SizedBox(height: 10),

                                       // Web Search Toggle
                                       if (settingsProvider.settings.searchProvider != SearchProvider.none)
                                         _buildFloatingOption(
                                             context,
                                             icon: Icons.public,
                                             label: _useWebSearch ? 'Search On' : 'Web Search',
                                             bgColor: _useWebSearch ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                             iconColor: _useWebSearch ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                             onTap: () {
                                                 Navigator.pop(context);
                                                 HapticFeedback.lightImpact();
                                                 setState(() => _useWebSearch = !_useWebSearch);
                                             },
                                             alignLeft: true,
                                         ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 50.ms).fadeIn(),
                                         
                                         if (settingsProvider.settings.searchProvider != SearchProvider.none)
                                            const SizedBox(height: 10),

                                        // Deep Research
                                        _buildFloatingOption(
                                            context,
                                            icon: Icons.school,
                                            label: _useDeepResearch ? 'Research On' : 'Deep Research',
                                            bgColor: _useDeepResearch ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                            iconColor: _useDeepResearch ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                            onTap: () {
                                                Navigator.pop(context);
                                                HapticFeedback.lightImpact();
                                                setState(() => _useDeepResearch = !_useDeepResearch);
                                            },
                                            alignLeft: true,
                                        ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 100.ms).fadeIn(),

                                        const SizedBox(height: 10),

                                       // Image from Gallery
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.image,
                                           label: 'Gallery',
                                           bgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                           iconColor: Theme.of(context).colorScheme.onSurface,
                                           onTap: () async {
                                               Navigator.pop(context);
                                               HapticFeedback.lightImpact();
                                               // requestFullMetadata: false helps with HEIC conversion
                                               final result = await ImagePicker().pickImage(
                                                 source: ImageSource.gallery,
                                                 requestFullMetadata: false,
                                                 imageQuality: 90,  // Compress for faster processing
                                               );
                                               if (result != null) {
                                                   setState(() {
                                                       _pendingAttachmentPath = result.path;
                                                       _pendingAttachmentType = 'image';
                                                   });
                                               }
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 150.ms).fadeIn(),
                                       
                                       const SizedBox(height: 10),

                                       // Camera
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.camera_alt,
                                           label: 'Camera',
                                           bgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                           iconColor: Theme.of(context).colorScheme.onSurface,
                                           onTap: () async {
                                               Navigator.pop(context);
                                               HapticFeedback.lightImpact();
                                               final result = await ImagePicker().pickImage(
                                                 source: ImageSource.camera,
                                                 requestFullMetadata: false,
                                                 imageQuality: 90,
                                               );
                                               if (result != null) {
                                                   setState(() {
                                                       _pendingAttachmentPath = result.path;
                                                       _pendingAttachmentType = 'image';
                                                   });
                                               }
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 200.ms).fadeIn(),
                                       
                                       const SizedBox(height: 10),

                                       // File
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.attach_file,
                                           label: 'File',
                                           bgColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                           iconColor: Theme.of(context).colorScheme.onSurface,
                                           onTap: () async {
                                               Navigator.pop(context);
                                               HapticFeedback.lightImpact();
                                               final result = await FilePicker.platform.pickFiles();
                                               if (result != null && result.files.single.path != null) {
                                                   setState(() {
                                                       _pendingAttachmentPath = result.files.single.path!;
                                                       _pendingAttachmentType = 'file';
                                                   });
                                               }
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 250.ms).fadeIn(),
                                       
                                       const SizedBox(height: 10),

                                       // Create Image
                                       if (settingsProvider.isComfyUiConnected)
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.brush,
                                           label: _useImageCreate ? 'Image On' : 'Create Image',
                                           bgColor: _useImageCreate ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest,
                                           iconColor: _useImageCreate ? Colors.white : Theme.of(context).colorScheme.onSurface,
                                           onTap: () {
                                               Navigator.pop(context);
                                               HapticFeedback.lightImpact();
                                               setState(() => _useImageCreate = !_useImageCreate);
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 300.ms).fadeIn(),
                                       
                                       if (settingsProvider.isComfyUiConnected)
                                         const SizedBox(height: 10),

                                        // Document for RAG context
                                        _buildFloatingOption(
                                            context,
                                            icon: Icons.description,
                                            label: chatProvider.currentChat?.hasDocument == true 
                                                ? 'Doc: ${chatProvider.currentChat!.documentName ?? "Loaded"}'
                                                : 'Load Document',
                                            bgColor: chatProvider.currentChat?.hasDocument == true 
                                                ? Colors.orange 
                                                : Theme.of(context).colorScheme.surfaceContainerHighest,
                                            iconColor: chatProvider.currentChat?.hasDocument == true 
                                                ? Colors.white 
                                                : Theme.of(context).colorScheme.onSurface,
                                            onTap: () async {
                                                Navigator.pop(context);
                                                HapticFeedback.lightImpact();
                                                final result = await FilePicker.platform.pickFiles(
                                                  type: FileType.custom,
                                                  allowedExtensions: DocumentService.supportedExtensions,
                                                );
                                                if (result != null && result.files.single.path != null) {
                                                    final loaded = await chatProvider.loadDocument(result.files.single.path!);
                                                    if (!loaded && mounted) {
                                                        ScaffoldMessenger.of(this.context).showSnackBar(
                                                            const SnackBar(content: Text('Failed to load document')),
                                                        );
                                                    }
                                                }
                                            },
                                            alignLeft: true,
                                        ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 350.ms).fadeIn(),

                                   ],
                               ),
                           ),
                       ),
                   ],
               );
          },
      ));
  }

  void _showRenameDialog(BuildContext parentContext, String modelId, String currentName) {
      final controller = TextEditingController(text: currentName);
      // Use the state's context (this.context) which is always valid, not the passed context
      showDialog(
          context: this.context,
          builder: (ctx) => AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              title: const Text('Rename Model', style: TextStyle(color: Colors.white)),
              content: TextField(
                  controller: controller,
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                      hintText: 'Enter new name',
                      hintStyle: TextStyle(color: Colors.white30),
                      enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white30)),
                  ),
                  autofocus: true,
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
                  ),
                  TextButton(
                      onPressed: () {
                          this.context.read<SettingsProvider>().updateModelAlias(modelId, controller.text);
                          Navigator.pop(ctx); // Close dialog
                          Navigator.pop(this.context); // Close model selector
                      },
                      child: const Text('Save', style: TextStyle(color: AppTheme.accent)),
                  ),
              ],
          ),
      );
  }
  void _showGrokModelSelector(BuildContext outerContext) {
      final settings = this.context.read<SettingsProvider>();
      final currentModel = settings.settings.selectedModelId;
      final isLocalProvider = settings.settings.apiProvider == ApiProvider.localModel;
      final localModelService = LocalModelService();
      
      String searchQuery = '';
      String selectedFilter = 'All'; // 'All', 'Free', 'Paid'

      showModalBottomSheet(
          context: this.context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          barrierColor: Colors.black.withValues(alpha: 0.7),
          builder: (ctx) => StatefulBuilder(
            builder: (context, setState) {
              return Container(
                  height: MediaQuery.of(ctx).size.height * 0.75,
                  decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.surface.withValues(alpha: 0.9),
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: Column(
                          children: [
                              // Drag Handle
                              Center(
                                child: Container(
                                  margin: const EdgeInsets.symmetric(vertical: 12),
                                  width: 40,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(2),
                                  ),
                                ),
                              ),

                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                                child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Row(
                                            children: [
                                                Container(
                                                  padding: const EdgeInsets.all(8),
                                                  decoration: BoxDecoration(
                                                    color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.1),
                                                    borderRadius: BorderRadius.circular(12),
                                                  ),
                                                  child: Icon(
                                                    isLocalProvider ? Icons.smartphone : Icons.auto_awesome, 
                                                    color: Theme.of(ctx).colorScheme.primary, 
                                                    size: 20
                                                  ),
                                                ),
                                                const SizedBox(width: 12),
                                                Text(
                                                  isLocalProvider ? 'Local Models' : 'Select Model', 
                                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)
                                                ),
                                            ],
                                        ),
                                        if (!isLocalProvider)
                                          IconButton(
                                            icon: Icon(Icons.refresh, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)), 
                                            onPressed: () {
                                              HapticFeedback.mediumImpact();
                                              settings.fetchModels();
                                              Navigator.pop(ctx);
                                              _showGrokModelSelector(this.context); 
                                          }),
                                    ],
                                ),
                              ),
                              
                              // Premium Search Box
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                                  ),
                                  child: TextField(
                                    onChanged: (value) => setState(() => searchQuery = value),
                                    style: const TextStyle(fontSize: 15),
                                    decoration: InputDecoration(
                                      hintText: 'Search models...',
                                      hintStyle: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3)),
                                      prefixIcon: Icon(Icons.search, size: 20, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.5)),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      border: InputBorder.none,
                                    ),
                                  ),
                                ),
                              ),

                              // Animated Filter Tabs (Only for OpenRouter)
                              if (!isLocalProvider && settings.settings.apiProvider == ApiProvider.openRouter)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: ['All', 'Free', 'Paid'].map((filter) {
                                      final isSelected = selectedFilter == filter;
                                      return Expanded(
                                        child: GestureDetector(
                                          onTap: () {
                                            HapticFeedback.selectionClick();
                                            setState(() => selectedFilter = filter);
                                          },
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            curve: Curves.easeInOut,
                                            padding: const EdgeInsets.symmetric(vertical: 8),
                                            decoration: BoxDecoration(
                                              color: isSelected ? Theme.of(ctx).colorScheme.primary : Colors.transparent,
                                              borderRadius: BorderRadius.circular(12),
                                              boxShadow: isSelected ? [
                                                BoxShadow(
                                                  color: Theme.of(ctx).colorScheme.primary.withValues(alpha: 0.3),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 2),
                                                )
                                              ] : null,
                                            ),
                                            child: Center(
                                              child: Text(
                                                filter, 
                                                style: TextStyle(
                                                  fontSize: 13, 
                                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                  color: isSelected ? Colors.white : Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.6),
                                                )
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 12),
                              
                              // List Area
                              Expanded(
                                child: isLocalProvider
                                  ? _buildLocalModelsList(ctx, localModelService, searchQuery)
                                  : _buildCloudModelsList(ctx, settings, currentModel, searchQuery, selectedFilter),
                              ),
                          ],
                      ),
                    ),
                  ),
              );
            },
          ),
      );
  }
  
  Widget _buildLocalModelsList(BuildContext ctx, LocalModelService localModelService, String searchQuery) {
    return FutureBuilder<List<LocalModel>>(
      future: _getDownloadedLocalModels(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        
        var models = snapshot.data ?? [];
        if (searchQuery.isNotEmpty) {
          models = models.where((m) => m.name.toLowerCase().contains(searchQuery.toLowerCase())).toList();
        }

        final loadedModelId = localModelService.loadedModel?.id;
        
        if (models.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.cloud_off, size: 48, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1)),
                const SizedBox(height: 16),
                Text(
                  'No models downloaded',
                  style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3)),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushNamed(this.context, '/local-models');
                  },
                  child: const Text('Download Models'),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            itemCount: models.length,
            itemBuilder: (listCtx, index) {
              final model = models[index];
              final isLoaded = model.id == loadedModelId;
              
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: isLoaded ? Theme.of(listCtx).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isLoaded ? Theme.of(listCtx).colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
                  ),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  leading: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.03),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: _getModelIcon(model.id, size: 24)),
                  ),
                  title: Text(
                    model.name,
                    style: TextStyle(
                      fontSize: 15,
                      color: isLoaded ? Theme.of(listCtx).colorScheme.primary : Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.9),
                      fontWeight: isLoaded ? FontWeight.bold : FontWeight.w500,
                    ),
                    softWrap: true,
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${model.quantization ?? 'Unknown'} • ${model.sizeString}',
                      style: TextStyle(color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 11),
                    ),
                  ),
                  trailing: isLoaded
                    ? IconButton(
                        icon: const Icon(Icons.eject_rounded, size: 20, color: Colors.orange),
                        onPressed: () async {
                          HapticFeedback.heavyImpact();
                          await localModelService.unloadModel();
                          Navigator.pop(ctx);
                        },
                      )
                    : Icon(Icons.circle_outlined, color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.1), size: 20),
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    Navigator.pop(ctx);
                    if (!isLoaded) {
                      await localModelService.loadModel(model);
                    }
                  },
                ),
              ).animate(delay: (index * 30).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
            },
          );
      },
    );
  }
  
  Future<List<LocalModel>> _getDownloadedLocalModels() async {
    final dbService = DatabaseService();
    final models = await dbService.getLocalModels();
    // Return only downloaded models (not downloading or error)
    return models.where((m) => m.status == LocalModelStatus.downloaded || m.status == LocalModelStatus.loaded).toList();
  }
  
  Widget _buildCloudModelsList(BuildContext ctx, SettingsProvider settings, String? currentModel, String searchQuery, String selectedFilter) {
    var modelIds = settings.availableModels;
    final isOpenRouter = settings.settings.apiProvider == ApiProvider.openRouter;
    
    // Create a combined list of model info for easier filtering
    List<Map<String, dynamic>> modelInfos = modelIds.map((id) {
      if (isOpenRouter) {
        final orModel = settings.openRouterModels.firstWhere(
          (m) => m['id'] == id,
          orElse: () => {'id': id, 'name': id.split('/').last, 'is_free': false},
        );
        return Map<String, dynamic>.from(orModel);
      } else {
        return {'id': id, 'name': id.split('/').last, 'is_free': false};
      }
    }).toList();

    // 1. Search Filter
    if (searchQuery.isNotEmpty) {
      final query = searchQuery.toLowerCase();
      modelInfos = modelInfos.where((m) {
        final name = (m['name'] as String? ?? '').toLowerCase();
        final id = (m['id'] as String? ?? '').toLowerCase();
        return name.contains(query) || id.contains(query);
      }).toList();
    }

    // 2. Category Filter (OpenRouter only)
    if (isOpenRouter && selectedFilter != 'All') {
      final wantFree = selectedFilter == 'Free';
      modelInfos = modelInfos.where((m) => (m['is_free'] as bool? ?? false) == wantFree).toList();
    }

    if (modelInfos.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 48, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1)),
            const SizedBox(height: 16),
            Text('No models found', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.3))),
          ],
        ),
      );
    }

    return ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        itemCount: modelInfos.length,
        itemBuilder: (listCtx, index) {
          final model = modelInfos[index];
          final modelId = model['id'] as String;
          final isSelected = modelId == currentModel;
          final displayName = settings.getModelDisplayName(modelId);
          final isFree = isOpenRouter && (model['is_free'] as bool? ?? false);
          
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: isSelected ? Theme.of(listCtx).colorScheme.primary.withValues(alpha: 0.08) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? Theme.of(listCtx).colorScheme.primary.withValues(alpha: 0.2) : Colors.transparent,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(child: _getModelIcon(modelId, size: 24)),
              ),
              title: Row(
                children: [
                  Expanded(
                    child: Text(
                      displayName, 
                      style: TextStyle(
                        fontSize: 15,
                        color: isSelected ? Theme.of(listCtx).colorScheme.primary : Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.9), 
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500
                      ),
                    ),
                  ),
                  if (isFree)
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.green.shade400, Colors.green.shade600],
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(color: Colors.green.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
                        ],
                      ),
                      child: const Text(
                        'FREE', 
                        style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5)
                      ),
                    ),
                ],
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(
                  modelId.split('/').last, 
                  style: TextStyle(color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.4), fontSize: 11)
                ),
              ),
              trailing: isSelected 
                ? Icon(Icons.check_circle, color: Theme.of(listCtx).colorScheme.primary, size: 20)
                : IconButton(
                    icon: Icon(Icons.edit_note, size: 20, color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.3)),
                    onPressed: () => _showRenameDialog(this.context, modelId, displayName),
                  ),
              onTap: () {
                HapticFeedback.lightImpact();
                settings.updateSettings(selectedModelId: modelId);
                Navigator.pop(ctx);
              },
            ),
          ).animate(delay: (index * 30).ms).fadeIn(duration: 300.ms).slideX(begin: 0.1, end: 0, curve: Curves.easeOutCubic);
        },
      );
  }

  void _showPersonaSelector(BuildContext context) {
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainer, // Theme-aware background
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1)),
                  boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 10))
                  ]
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Choose Personality', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                            TextButton.icon(
                                onPressed: () {
                                    HapticFeedback.lightImpact(); // Haptic
                                    Navigator.pop(ctx);
                                    _showCreatePersonaDialog(context);
                                },
                                icon: Icon(Icons.add, color: Theme.of(context).colorScheme.primary),
                                label: Text('New', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                            )
                          ],
                        ),
                      ),
                      Divider(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                      Flexible(
                          child: Consumer<ChatProvider>(
                              builder: (context, chat, _) => ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: chat.allPersonas.length,
                              itemBuilder: (context, index) {
                                  final persona = chat.allPersonas[index];
                                  final isSelected = chat.currentPersona.id == persona.id;
                                  
                                  return ListTile(
                                      leading: Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                              color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                                              borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(persona.icon, color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                                      ),
                                      title: Text(persona.name, style: TextStyle(color: isSelected ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.onSurface, fontWeight: FontWeight.bold)),
                                      subtitle: Text(persona.description, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54), fontSize: 12)),
                                      trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              if (persona.isCustom)
                                                  IconButton(
                                                      icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3), size: 20),
                                                      onPressed: () {
                                                          chat.deleteCustomPersona(persona.id);
                                                      },
                                                  ),
                                              if (isSelected) Icon(Icons.check_circle, color: Theme.of(context).colorScheme.primary),
                                          ],
                                      ),
                                      onTap: () {
                                          chat.setPersona(persona);
                                          Navigator.pop(ctx);
                                      },
                                  );
                              },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                  ],
              ),
          ),
      );
  }

  void _showCreatePersonaDialog(BuildContext context) {
      showDialog(
          context: context,
          builder: (ctx) => CreatePersonaDialog(
              onCreate: (name, desc, prompt) {
                  Provider.of<ChatProvider>(context, listen: false).addCustomPersona(name, desc, prompt);
              },
          ),
      );
  }

  void _showVoiceOptions(BuildContext context) async {
      // Dismiss keyboard first to prevent layout glitch
      FocusScope.of(context).unfocus();
      
      // Wait for keyboard to fully dismiss and layout to settle
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;
      
      // Now get the button position AFTER keyboard is dismissed
      final renderBox = _actionButtonKey.currentContext?.findRenderObject() as RenderBox?;
      if (renderBox == null) return;
      
      final buttonPosition = renderBox.localToGlobal(Offset.zero);
      final size = renderBox.size;
      final screenWidth = MediaQuery.of(context).size.width;
      final screenHeight = MediaQuery.of(context).size.height;
      
      // Calculate position dynamically from button
      final rightOffset = screenWidth - (buttonPosition.dx + size.width);
      // Use same fixed offset calculation as plus menu for consistency
      // Add extra space if pills are visible
      final pillsVisible = _useWebSearch || _pendingAttachmentPath != null;
      final bottomOffset = MediaQuery.of(context).padding.bottom + 16 + 80 + 16 + (pillsVisible ? 32 : 0);

      Navigator.of(context).push(PageRouteBuilder(
          opaque: false,
          barrierDismissible: true,
          barrierColor: Colors.transparent,
          pageBuilder: (context, animation, secondaryAnimation) {
               return Stack(
                   children: [
                       // Backdrop with semi-transparent dark overlay for readability
                       Positioned.fill(
                           child: GestureDetector(
                               onTap: () {
                                   Navigator.pop(context);
                                   // Unfocus after popup closes to prevent keyboard from reopening
                                   WidgetsBinding.instance.addPostFrameCallback((_) {
                                       FocusManager.instance.primaryFocus?.unfocus();
                                   });
                               },
                               behavior: HitTestBehavior.opaque,
                               child: Container(color: Colors.black.withValues(alpha: 0.85)),
                           ),
                       ),
                       // Floating Options
                       Positioned(
                           right: rightOffset, 
                           bottom: bottomOffset, 
                           child: Material(
                               type: MaterialType.transparency,
                               child: Column(
                                   mainAxisSize: MainAxisSize.min,
                                   crossAxisAlignment: CrossAxisAlignment.end, 
                                   children: [
                                       // Voice Mode Option
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.headphones,
                                           label: 'Voice Mode',
                                           bgColor: Theme.of(context).colorScheme.primary, 
                                           iconColor: Colors.white,
                                           onTap: () {
                                               Navigator.pop(context);
                                               HapticFeedback.mediumImpact();
                                               context.read<ChatProvider>().toggleContinuousVoiceMode();
                                               Navigator.of(context).push(PageRouteBuilder(
                                                   opaque: false,
                                                   pageBuilder: (_, __, ___) => const VoiceModeOverlay(),
                                                   transitionsBuilder: (_, anim, __, child) {
                                                       return FadeTransition(opacity: anim, child: child);
                                                   }
                                               ));
                                           }
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms).fadeIn(),
                                       
                                       const SizedBox(height: 12),

                                       // Dictation Option
                                       _buildFloatingOption(
                                           context,
                                           icon: Icons.mic, // Standard Mic
                                           label: 'Dictation',
                                           bgColor: Theme.of(context).colorScheme.primary, // Theme Color (Blue)
                                           iconColor: Colors.white, // White Icon
                                           onTap: () {
                                                Navigator.pop(context);
                                                HapticFeedback.lightImpact();
                                                final chatProvider = context.read<ChatProvider>();
                                                final currentText = _textController.text;
                                                chatProvider.startListening((result) {
                                                    if (mounted) {
                                                        setState(() {
                                                            _textController.text = (currentText + (currentText.isNotEmpty && !currentText.endsWith(' ') ? ' ' : '') + result);
                                                            _textController.selection = TextSelection.fromPosition(TextPosition(offset: _textController.text.length));
                                                        });
                                                    }
                                                });
                                           }
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 50.ms).fadeIn(),
                                   ],
                               ),
                           ),
                       ),
                   ],
               );
          },
      ));
  }
  
  Widget _buildFloatingOption(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap, required Color bgColor, required Color iconColor, bool alignLeft = false}) {
       final labelWidget = Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: const Color(0xFF1E1E1E).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))
              ]
          ),
          child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
       );
       
       final buttonWidget = Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: bgColor, 
                  shape: BoxShape.circle,
                  boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))
                  ]
              ),
              child: Icon(icon, color: iconColor, size: 22),
       );
       
       // Wrap entire row in GestureDetector so both icon and label are tappable
       return GestureDetector(
           onTap: onTap,
           behavior: HitTestBehavior.opaque,
           child: Row(
               mainAxisAlignment: alignLeft ? MainAxisAlignment.start : MainAxisAlignment.end, 
               mainAxisSize: MainAxisSize.min, 
               children: alignLeft 
                   ? [buttonWidget, const SizedBox(width: 12), labelWidget]
                   : [labelWidget, const SizedBox(width: 12), buttonWidget],
           ),
       );
  }

  Widget _buildFeatureChip(BuildContext context, {required IconData icon, required String label, required VoidCallback onRemove, Color? chipColor}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasCustomColor = chipColor != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: hasCustomColor 
            ? chipColor.withValues(alpha: 0.2)
            : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(16),
        border: hasCustomColor ? Border.all(color: chipColor.withValues(alpha: 0.5), width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: hasCustomColor ? chipColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: hasCustomColor ? chipColor : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 12,
              color: hasCustomColor ? chipColor.withValues(alpha: 0.7) : Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final chatProvider = context.read<ChatProvider>();
    var text = _textController.text;
    final path = _pendingAttachmentPath;
    final type = _pendingAttachmentType;
    final useSearch = _useWebSearch;
    final useImageCreate = _useImageCreate;
    
    // Prepend /create if image mode is active
    if (useImageCreate && text.trim().isNotEmpty) {
      text = '/create $text';
    }
    
    final useDeepResearch = _useDeepResearch;
    
    _textController.clear();
    setState(() {
        _pendingAttachmentPath = null;
        _pendingAttachmentType = null; 
        _useWebSearch = false;
        _useImageCreate = false;
        _useDeepResearch = false;
    });

    try {
      if (useDeepResearch) {
        await chatProvider.startDeepResearch(text);
      } else {
        await chatProvider.sendMessage(
          text, 
          attachmentPath: path, 
          attachmentType: type,
          useWebSearch: useSearch
        );
      }
      _scrollToBottom();
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
          );
       }
    }
  }

  Widget _getModelIcon(String modelId, {double size = 20, Color? color}) {
    final id = modelId.toLowerCase();
    IconData iconData = Icons.auto_awesome;
    Color iconColor = color ?? Colors.grey;

    if (id.contains('google/') || id.contains('gemini')) {
      iconData = Icons.lens_blur; // Proxy for Google Gemini
      if (color == null) iconColor = Colors.blue;
    } else if (id.contains('mistral')) {
      iconData = Icons.cyclone; // Fixed capitalization
      if (color == null) iconColor = Colors.orange;
    } else if (id.contains('meta/') || id.contains('llama')) {
      iconData = Icons.all_inclusive;
      if (color == null) iconColor = Colors.blueAccent;
    } else if (id.contains('anthropic/') || id.contains('claude')) {
      iconData = Icons.spa;
      if (color == null) iconColor = const Color(0xFFD97757);
    } else if (id.contains('openai/') || id.contains('gpt')) {
      iconData = Icons.bolt;
      if (color == null) iconColor = const Color(0xFF10A37F);
    } else if (id.contains('deepseek')) {
      iconData = Icons.search;
      if (color == null) iconColor = Colors.purpleAccent;
    } else if (id.contains('nvidia')) {
      iconData = Icons.memory;
      if (color == null) iconColor = Colors.greenAccent;
    } else if (id.contains('microsoft') || id.contains('phi')) {
      iconData = Icons.window;
      if (color == null) iconColor = Colors.lightBlue;
    }

    return Icon(iconData, size: size, color: iconColor);
  }
}
