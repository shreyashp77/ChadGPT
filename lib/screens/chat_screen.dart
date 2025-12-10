import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../models/message.dart';
import '../utils/theme.dart';
import '../widgets/message_bubble.dart';
import '../widgets/app_drawer.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String? _pendingAttachmentPath;
  String? _pendingAttachmentType; // 'image' or 'file'

  bool _useWebSearch = false; // Local state for search

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void initState() {
    super.initState();
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
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final currentChat = chatProvider.currentChat;

    return Scaffold(
      extendBodyBehindAppBar: true,
      drawer: const AppDrawer(),
      appBar: AppBar(
        centerTitle: true,
        title: Text(currentChat?.title ?? 'Grok'),
        actions: [
            Consumer<ChatProvider>(
                builder: (context, chat, _) => IconButton(
                    icon: Icon(chat.isTempMode ? Icons.visibility_off : Icons.history, 
                        color: chat.isTempMode ? Colors.white : Colors.white70),
                    tooltip: chat.isTempMode ? 'Turn off Incognito' : 'Turn on Incognito',
                    onPressed: () {
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
                          return const Center(child: Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()));
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
              child: Container(
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
                           // Attachments Preview
                           if (_pendingAttachmentPath != null)
                             Container(
                                 margin: const EdgeInsets.only(bottom: 8, left: 16, right: 16),
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                 ),
                                 child: Row(
                                     mainAxisSize: MainAxisSize.min,
                                     children: [
                                         const Icon(Icons.attach_file, size: 16),
                                         const SizedBox(width: 8),
                                         Flexible(child: Text(_pendingAttachmentPath!.split('/').last, maxLines: 1, overflow: TextOverflow.ellipsis)),
                                         const SizedBox(width: 8),
                                         InkWell(
                                             onTap: () => setState(() {
                                                 _pendingAttachmentPath = null;
                                                 _pendingAttachmentType = null;
                                             }),
                                             child: const Icon(Icons.close, size: 16),
                                         )
                                     ]
                                 )
                             ),

                           // Top: TextField
                           Padding(
                             padding: const EdgeInsets.symmetric(horizontal: 16),
                             child: TextField(
                               controller: _textController,
                               style: const TextStyle(fontSize: 16),
                               decoration: const InputDecoration(
                                 hintText: 'Ask anything',
                                 border: InputBorder.none,
                                 isDense: true,
                                 contentPadding: EdgeInsets.zero,
                               ),
                               maxLines: null,
                               keyboardType: TextInputType.multiline,
                               textCapitalization: TextCapitalization.sentences,
                             ),
                           ),
                           
                           const SizedBox(height: 15),

                           // Bottom: Actions Row
                           Padding(
                             padding: const EdgeInsets.fromLTRB(0, 0, 8, 0),
                             child: Row(
                               children: [
                                 // Attachment / Menu Button
                                 IconButton(
                                   icon: Icon(Icons.add_circle_outline, color: Theme.of(context).colorScheme.primary),
                                   onPressed: _showAttachmentOptions, 
                                 ),
                                 
                                 const SizedBox(width: 0),
                                 
                                 // Grok-style Model Selector Pill
                                 GestureDetector(
                                     onTap: () => _showGrokModelSelector(context),
                                     child: Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                         decoration: BoxDecoration(
                                             color: Theme.of(context).brightness == Brightness.dark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                                             borderRadius: BorderRadius.circular(20),
                                         ),
                                         child: Row(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                                if (_useWebSearch) ...[
                                                    Icon(Icons.public, size: 14, color: Theme.of(context).colorScheme.primary),
                                                    const SizedBox(width: 6),
                                                ] else ...[
                                                    Icon(Icons.auto_awesome, size: 14, color: Theme.of(context).colorScheme.primary),
                                                    const SizedBox(width: 6),
                                                ],
                                                 
                                                 ConstrainedBox(
                                                     constraints: const BoxConstraints(maxWidth: 90),
                                                     child: Text(
                                                         settingsProvider.getModelDisplayName(settingsProvider.settings.selectedModelId ?? ''),
                                                         style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface),
                                                         maxLines: 1,
                                                         overflow: TextOverflow.ellipsis,
                                                     ),
                                                 ),
                                                 const SizedBox(width: 4),
                                                 Icon(Icons.keyboard_arrow_down, size: 14, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
                                             ],
                                         ),
                                     ),
                                 ),

                                 const Spacer(),

                                 // Send Button
                                 Container(
                                     decoration: BoxDecoration(
                                         shape: BoxShape.circle,
                                         gradient: AppTheme.getPrimaryGradient(Theme.of(context).colorScheme.primary),
                                     ),
                                     child: IconButton(
                                       color: Colors.white,
                                       icon: _pendingAttachmentPath == null && _textController.text.isEmpty && chatProvider.isTyping
                                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                            : const Icon(Icons.arrow_upward, size: 20),
                                       onPressed: chatProvider.isTyping ? null : () async {
                                           if (_textController.text.trim().isNotEmpty || _pendingAttachmentPath != null) {
                                               final text = _textController.text;
                                               final path = _pendingAttachmentPath;
                                               final type = _pendingAttachmentType;
                                               final useSearch = _useWebSearch;
                                               
                                               _textController.clear();
                                               setState(() {
                                                   _pendingAttachmentPath = null;
                                                   _pendingAttachmentType = null;
                                                   // Don't reset web search? Or reset it? Grok keeps context usually. 
                                                   // Let's keep it for now, or reset if desired. 
                                                   // Resetting for safety.
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
                                                  if (context.mounted) {
                                                     ScaffoldMessenger.of(context).showSnackBar(
                                                         SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: Colors.red),
                                                     );
                                                  }
                                               }
                                           }
                                       },
                                     ),
                                 ),
                               ],
                             ),
                           ),
                        ],
                      ),

                  ),
                ),
              ),
            ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutQuad, duration: 600.ms),
          ),
          ),
        ],
      ),
    );
  }



  void _showAttachmentOptions() {
      showModalBottomSheet(context: context, builder: (ctx) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
              ListTile(
                  leading: const Icon(Icons.image),
                  title: const Text('Image from Gallery'),
                  onTap: () async {
                      Navigator.pop(ctx);
                      final result = await ImagePicker().pickImage(source: ImageSource.gallery);
                      if (result != null) {
                          setState(() {
                              _pendingAttachmentPath = result.path;
                              _pendingAttachmentType = 'image';
                          });
                      }
                  },
              ),
              ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Take Photo'),
                  onTap: () async {
                      Navigator.pop(ctx);
                      final result = await ImagePicker().pickImage(source: ImageSource.camera);
                      if (result != null) {
                          setState(() {
                              _pendingAttachmentPath = result.path;
                              _pendingAttachmentType = 'image';
                          });
                      }
                  },
              ),
              ListTile(
                  leading: const Icon(Icons.file_present),
                  title: const Text('File'),
                  onTap: () async {
                      Navigator.pop(ctx);
                      final result = await FilePicker.platform.pickFiles();
                      if (result != null && result.files.single.path != null) {
                          setState(() {
                              _pendingAttachmentPath = result.files.single.path!;
                              _pendingAttachmentType = 'file';
                          });
                      }
                  },
              ),
              const Divider(),
              ListTile(
                  leading: Icon(Icons.public, color: _useWebSearch ? AppTheme.accent : null),
                  title: Text(_useWebSearch ? 'Disable Web Search' : 'Enable Web Search'),
                  trailing: Switch(
                      value: _useWebSearch, 
                      onChanged: (val) {
                          Navigator.pop(ctx);
                          setState(() {
                              _useWebSearch = val;
                          });
                      }
                  ),
                  onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                          _useWebSearch = !_useWebSearch;
                      });
                  },
              ),
              const SizedBox(height: 16),
          ],
      ));
  }

  void _showRenameDialog(BuildContext context, String modelId, String currentName) {
      final controller = TextEditingController(text: currentName);
      showDialog(
          context: context,
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
                          context.read<SettingsProvider>().updateModelAlias(modelId, controller.text);
                          Navigator.pop(ctx);
                          // Force rebuild/refresh of the selector if open? 
                          // The selector is a modal bottom sheet built with current context. 
                          // Since we update provider, it should rebuild if we watched it. 
                          // But we passed 'settings' (read) to the builder. 
                          // We might need to close and reopen the selector or make the selector a consumer.
                          Navigator.pop(context); // Close the selector too to see the update in the pill
                      },
                      child: const Text('Save', style: TextStyle(color: AppTheme.accent)),
                  ),
              ],
          ),
      );
  }
  void _showGrokModelSelector(BuildContext context) {
      final settings = context.read<SettingsProvider>();
      final currentModel = settings.settings.selectedModelId;
      
      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (ctx) => Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: const Color(0xFF1E1E1E), // Dark background like Grok
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, offset: const Offset(0, 10))
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
                                const Row(
                                    children: [
                                        Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                                        SizedBox(width: 8),
                                        Text('Select Model', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                    ],
                                ),
                                IconButton(icon: const Icon(Icons.refresh, color: Colors.white70), onPressed: () {
                                    settings.fetchModels();
                                    Navigator.pop(ctx);
                                    _showGrokModelSelector(context); // Reopen to refresh? Or just refresh in bg. Reopening might be jarring.
                                }),
                            ],
                        ),
                      ),
                      const Divider(color: Colors.white10, height: 1),
                      ConstrainedBox(
                          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.4),
                          child: ListView.builder(
                              shrinkWrap: true,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: settings.availableModels.length,
                              itemBuilder: (context, index) {
                                  final modelId = settings.availableModels[index];
                                  final isSelected = modelId == currentModel;
                                  final displayName = settings.getModelDisplayName(modelId);
                                  
                                  return ListTile(
                                      title: Text(displayName, style: TextStyle(color: isSelected ? AppTheme.accent : Colors.white70, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                                      subtitle: displayName != modelId.split('/').last ? Text(modelId.split('/').last, style: TextStyle(color: Colors.white30, fontSize: 10)) : null,
                                      leading: isSelected ? const Icon(Icons.check_circle, color: AppTheme.accent) : const Icon(Icons.circle_outlined, color: Colors.white30),
                                      trailing: IconButton(
                                          icon: const Icon(Icons.edit, size: 16, color: Colors.white30),
                                          onPressed: () => _showRenameDialog(context, modelId, displayName),
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
}
