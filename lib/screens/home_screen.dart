import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'dart:ui' as ui;
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import 'chat_screen.dart';
import '../utils/theme.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  bool _isMenuOpen = false;

  void _toggleMenu() {
    setState(() {
      _isMenuOpen = !_isMenuOpen;
    });
  }

  void _handleNewChat(BuildContext context, {bool isTemp = false}) {
     final chatProvider = context.read<ChatProvider>();
     if (isTemp) {
         if (!chatProvider.isTempMode) chatProvider.toggleTempMode();
     } else {
         if (chatProvider.isTempMode) chatProvider.toggleTempMode();
     }
     chatProvider.startNewChat();
     Navigator.pushReplacement(
       context,
       MaterialPageRoute(builder: (_) => const ChatScreen()),
     );
  }

  void _showChatContextMenu(BuildContext context, chat, Offset position) {
    final chatProvider = context.read<ChatProvider>();
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromLTWH(position.dx, position.dy, 0, 0),
        Offset.zero & overlay.size,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        PopupMenuItem(
          onTap: () {
            chatProvider.togglePinChat(chat.id);
          },
          child: Row(
            children: [
              Icon(
                chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Text(chat.isPinned ? 'Unpin' : 'Pin to top'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () {
            _showRenameDialog(context, chat, chatProvider);
          },
          child: Row(
            children: [
              Icon(Icons.edit_outlined, size: 20, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 12),
              const Text('Rename'),
            ],
          ),
        ),
        PopupMenuItem(
          onTap: () async {
            final confirm = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Delete Chat?'),
                content: const Text('This action cannot be undone.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                  TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                ],
              ),
            );
            if (confirm == true) {
              chatProvider.deleteChat(chat.id);
            }
          },
          child: const Row(
            children: [
              Icon(Icons.delete_outline, size: 20, color: Colors.red),
              SizedBox(width: 12),
              Text('Delete', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ],
    );
  }

  void _showRenameDialog(BuildContext context, chat, ChatProvider chatProvider) {
    final controller = TextEditingController(text: chat.title);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Rename Chat'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter new name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                chatProvider.renameChat(chat.id, controller.text.trim());
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('History'),
        centerTitle: true,
        flexibleSpace: ClipRRect(
             child: BackdropFilter(
                 filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                 child: Container(color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.5)),
             )
        ),
      ),
      body: Stack(
        children: [
            // List
            Consumer<ChatProvider>(
                builder: (context, chatProvider, _) {
                  if (chatProvider.chats.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history, size: 64, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                          const SizedBox(height: 16),
                          Text('No history yet', style: Theme.of(context).textTheme.titleLarge),
                        ],
                      ).animate().fadeIn().scale(),
                    );
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + kToolbarHeight + 16, 16, 100),
                    itemCount: chatProvider.chats.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final chat = chatProvider.chats[index];
                      return Dismissible(
                        key: Key(chat.id),
                        background: Container(
                          decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.8),
                              borderRadius: BorderRadius.circular(16),
                          ),
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          child: const Icon(Icons.delete, color: Colors.white),
                        ),
                        direction: DismissDirection.endToStart,
                        onDismissed: (_) {
                          chatProvider.deleteChat(chat.id);
                        },
                        confirmDismiss: (_) async {
                          return await showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Chat?'),
                              content: const Text('This action cannot be undone.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                              ],
                            ),
                          );
                        },
                        child: GestureDetector(
                            onLongPressStart: (details) {
                              _showChatContextMenu(context, chat, details.globalPosition);
                            },
                            child: Container(
                                decoration: BoxDecoration(
                                    color: Theme.of(context).cardTheme.color ?? Theme.of(context).colorScheme.surfaceContainer,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: chat.isPinned 
                                        ? AppTheme.primaryLight.withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.05)),
                                    boxShadow: [
                                        BoxShadow(
                                            color: Colors.black.withValues(alpha: 0.05),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                        )
                                    ]
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  leading: CircleAvatar(
                                    backgroundColor: AppTheme.primaryLight.withValues(alpha: 0.2),
                                    child: const Icon(Icons.chat_bubble_outline, color: AppTheme.primaryLight),
                                  ),
                                  title: Row(
                                    children: [
                                      if (chat.isPinned) ...[
                                        Icon(Icons.push_pin, size: 14, color: AppTheme.primaryLight.withValues(alpha: 0.8)),
                                        const SizedBox(width: 6),
                                      ],
                                      Expanded(
                                        child: Text(
                                          chat.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                                        ),
                                      ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    DateFormat.yMMMd().add_jm().format(chat.updatedAt),
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
                                  ),
                                  onTap: () {
                                    chatProvider.loadChat(chat.id);
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const ChatScreen()),
                                    );
                                  },
                                ),
                            ),
                        ).animate().fadeIn(delay: (30 * index).ms).slideX(begin: 0.1, end: 0),
                      );
                    },
                  );
                },
            ),
            
            // Expandable FAB Menu Overlay (Modal barrier when open)
            if (_isMenuOpen)
                 Positioned.fill(
                    child: GestureDetector(
                        onTap: _toggleMenu,
                        child: Container(color: Colors.black.withValues(alpha: 0.5)).animate().fadeIn(duration: 200.ms),
                    ),
                 ),

            // FABs
            Positioned(
                bottom: 32,
                right: 24,
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                        if (_isMenuOpen) ...[
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.7), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('Temporary Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ).animate().fadeIn().moveX(begin: 10, end: 0),
                                    const SizedBox(width: 16),
                                    FloatingActionButton.small(
                                        heroTag: 'temp_chat',
                                        backgroundColor: const Color(0xFF202124), // Chrome Incognito Dark
                                        onPressed: () { _toggleMenu(); _handleNewChat(context, isTemp: true); },
                                        child: FaIcon(FontAwesomeIcons.userSecret, color: Colors.white, size: 18),
                                    ).animate().scale().fade(),
                                ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: Colors.black.withValues(alpha:0.7), borderRadius: BorderRadius.circular(8)),
                                        child: const Text('New Chat', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    ).animate().fadeIn().moveX(begin: 10, end: 0),
                                    const SizedBox(width: 16),
                                    FloatingActionButton.small(
                                        heroTag: 'new_chat',
                                        backgroundColor: AppTheme.accent,
                                        onPressed: () { _toggleMenu(); _handleNewChat(context, isTemp: false); },
                                        child: const Icon(Icons.edit_square, color: Colors.white),
                                    ).animate().scale().fade(),
                                ],
                            ),
                            const SizedBox(height: 24),
                        ],
                        
                        FloatingActionButton(
                            heroTag: 'menu_fab',
                            backgroundColor: _isMenuOpen ? Colors.grey : AppTheme.primaryLight,
                            onPressed: _toggleMenu,
                            child: Icon(_isMenuOpen ? Icons.close : Icons.add, color: Colors.white, size: 28),
                        ).animate().rotate(begin: 0, end: _isMenuOpen ? 0.25 : 0), // Quarter turn animation
                    ],
                ),
            ),
        ],
      )
    );
  }
}
