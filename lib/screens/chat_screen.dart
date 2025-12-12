import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../models/message.dart';
import '../utils/theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/app_drawer.dart';
import '../widgets/create_persona_dialog.dart';
import '../widgets/voice_mode_overlay.dart';
import '../widgets/typing_indicator.dart';

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

  bool _useWebSearch = false; // Local state for search

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
        if (mounted) setState(() {});
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

    // Auto-scroll to bottom if generating
    if (chatProvider.isTyping) {
       _scrollToBottom(isImmediate: true);
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
                    itemCount: currentChat.messages.length + (chatProvider.isTyping && currentChat.messages.last.role != MessageRole.assistant ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= currentChat.messages.length) {
                          // Show typing indicator instead of spinner
                          return const Align(
                            alignment: Alignment.centerLeft,
                            child: TypingIndicator(),
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
                           // Top: Feature Chips (Web Search, Attachments)
                           if (_useWebSearch || _pendingAttachmentPath != null)
                             Padding(
                               padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                               child: SingleChildScrollView(
                                 scrollDirection: Axis.horizontal,
                                 child: Row(
                                   children: [
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



  void _showAttachmentOptions() async {
      final settingsProvider = context.read<SettingsProvider>();
      
      // Dismiss keyboard first
      FocusScope.of(context).unfocus();
      await Future.delayed(const Duration(milliseconds: 300));
      
      if (!mounted) return;

      // Get position for the plus button (left side)
      final screenHeight = MediaQuery.of(context).size.height;
      // Add extra space if pills are visible
      final pillsVisible = _useWebSearch || _pendingAttachmentPath != null;
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
                                           label: settingsProvider.getModelDisplayName(settingsProvider.settings.selectedModelId ?? ''),
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
                                               final result = await ImagePicker().pickImage(source: ImageSource.gallery);
                                               if (result != null) {
                                                   setState(() {
                                                       _pendingAttachmentPath = result.path;
                                                       _pendingAttachmentType = 'image';
                                                   });
                                               }
                                           },
                                           alignLeft: true,
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 100.ms).fadeIn(),
                                       
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
                                               final result = await ImagePicker().pickImage(source: ImageSource.camera);
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
                                       ).animate().slideY(begin: 0.5, end: 0, duration: 200.ms, delay: 200.ms).fadeIn(),
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
      
      showModalBottomSheet(
          context: this.context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1)),
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
                                Row(
                                    children: [
                                        Icon(Icons.auto_awesome, color: Theme.of(ctx).colorScheme.onSurface, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Select Model', style: TextStyle(color: Theme.of(ctx).colorScheme.onSurface, fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                ),
                                IconButton(icon: Icon(Icons.refresh, color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.7)), onPressed: () {
                                    settings.fetchModels();
                                    Navigator.pop(ctx);
                                    _showGrokModelSelector(this.context); 
                                }),
                            ],
                        ),
                      ),
                      Divider(color: Theme.of(ctx).colorScheme.onSurface.withValues(alpha: 0.1), height: 1),
                      ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.4),
                          child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: settings.availableModels.length,
                              itemBuilder: (listCtx, index) {
                                  final modelId = settings.availableModels[index];
                                  final isSelected = modelId == currentModel;
                                  final displayName = settings.getModelDisplayName(modelId);
                                  
                                  return ListTile(
                                      title: Text(displayName, style: TextStyle(color: isSelected ? Theme.of(listCtx).colorScheme.primary : Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.7), fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                      subtitle: displayName != modelId.split('/').last ? Text(modelId.split('/').last, style: TextStyle(color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.3), fontSize: 10)) : null,
                                      leading: isSelected ? Icon(Icons.check_circle, color: Theme.of(listCtx).colorScheme.primary) : Icon(Icons.circle_outlined, color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.3)),
                                      trailing: IconButton(
                                          icon: Icon(Icons.edit, size: 16, color: Theme.of(listCtx).colorScheme.onSurface.withValues(alpha: 0.3)),
                                          onPressed: () => _showRenameDialog(this.context, modelId, displayName),
                                      ),
                                      onTap: () {
                                          settings.updateSettings(selectedModelId: modelId);
                                          Navigator.pop(ctx);
                                      },
                                  );
                              },
                          ),
                      ),
                      const SizedBox(height: 8),
                  ],
              ),
          ),
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

  Widget _buildFeatureChip(BuildContext context, {required IconData icon, required String label, required VoidCallback onRemove}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
          const SizedBox(width: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 120),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
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
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendMessage() async {
    final chatProvider = context.read<ChatProvider>();
    final text = _textController.text;
    final path = _pendingAttachmentPath;
    final type = _pendingAttachmentType;
    final useSearch = _useWebSearch;
    
    _textController.clear();
    setState(() {
        _pendingAttachmentPath = null;
        _pendingAttachmentType = null; 
        _useWebSearch = false; 
    });

    try {
      await chatProvider.sendMessage(
        text, 
        attachmentPath: path, 
        attachmentType: type,
        useWebSearch: useSearch
      );
      _scrollToBottom();
    } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
          );
       }
    }
  }
}
