import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../models/message.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/theme.dart';
import '../widgets/message_bubble.dart';
import 'home_screen.dart';

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
      appBar: AppBar(
        flexibleSpace: ClipRRect(
             child: BackdropFilter(
                 filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)),
             )
        ),
        leading: IconButton(
            icon: const Icon(Icons.history_rounded),
            tooltip: 'Chat History',
            onPressed: () {
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HomeScreen()));
            },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(currentChat?.title ?? 'New Chat'),
            if (chatProvider.isTempMode)
               Text('Temporary Chat', style: TextStyle(fontSize: 12, color: Colors.orangeAccent)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
               Navigator.of(context).pushNamed('/settings');
            },
          ),
          IconButton(
            icon: Icon(chatProvider.isTempMode ? Icons.history : Icons.history_toggle_off),
            tooltip: 'Toggle Temp Mode',
            onPressed: () {
                chatProvider.toggleTempMode();
                if (chatProvider.isTempMode) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Temporary Mode Enabled. Chats will not be saved.')));
                } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved Mode Enabled.')));
                }
            },
          ),
        ],
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
                         Icon(Icons.chat_bubble_outline, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                         const SizedBox(height: 16),
                         const Text('Start talking!', style: TextStyle(fontSize: 18, color: Colors.grey)),
                      ],
                    )
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: EdgeInsets.only(
                        top: MediaQuery.of(context).padding.top + kToolbarHeight + 16,
                        bottom: 120 // Space for input area
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
          Align(
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
                    child: SafeArea(
                      top: false,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                           // Attachments Preview within the glass pill
                           if (_pendingAttachmentPath != null)
                             Container(
                                 margin: const EdgeInsets.only(bottom: 8),
                                 padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                 decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(20),
                                 ),
                                 child: Row(
                                     children: [
                                         const Icon(Icons.attach_file, size: 16),
                                         const SizedBox(width: 8),
                                         Expanded(child: Text(_pendingAttachmentPath!.split('/').last, maxLines: 1)),
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

                           Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, color: AppTheme.primaryLight),
                                  onPressed: _showAttachmentOptions, 
                                ),
                                IconButton(
                                  icon: Icon(Icons.public, color: _useWebSearch ? AppTheme.accent : Colors.grey),
                                  tooltip: 'Search Web',
                                  onPressed: () {
                                     setState(() {
                                         _useWebSearch = !_useWebSearch;
                                     });
                                  }, 
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    controller: _textController,
                                    style: const TextStyle(fontSize: 16),
                                    decoration: InputDecoration(
                                      hintText: _useWebSearch ? 'Search & Chat...' : 'Type a message...',
                                      border: InputBorder.none,
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), // Vertically centered
                                      isDense: true,
                                    ),
                                    maxLines: null, // Allow multiline expansion
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization: TextCapitalization.sentences,
                                  ),
                                ),
                                Container(
                                    margin: const EdgeInsets.only(left: 4),
                                    decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        gradient: AppTheme.primaryGradient,
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
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ).animate().slideY(begin: 1.0, end: 0, curve: Curves.easeOutQuad, duration: 600.ms),
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
          ],
      ));
  }
}
