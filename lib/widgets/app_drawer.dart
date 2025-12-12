import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import '../utils/theme.dart';
import '../screens/settings_screen.dart';
import '../screens/analytics_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final searchBarColor = isDark ? const Color(0xFF1E1E1E) : Colors.grey.withValues(alpha: 0.1);
    final iconColor = isDark ? Colors.white : Colors.black87;

    return Drawer(
      width: MediaQuery.of(context).size.width, // Full screen
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
            // Swipe Left to Close Drawer
            if (details.primaryVelocity != null && details.primaryVelocity! < -300) {
                Navigator.pop(context);
            }
        },
        child: Stack(
        children: [
           // Main Content: History List
           Padding(
               padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 100), // Bottom padding for floating bar
               child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       Text('History', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                       const SizedBox(height: 24),
                       Expanded(
                           child: Consumer<ChatProvider>(
                                builder: (context, chatProvider, _) {
                                    final chats = chatProvider.chats;
                                    
                                    // Filter chats based on search query
                                    final filteredChats = _searchQuery.isEmpty 
                                        ? chats 
                                        : chats.where((chat) => chat.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

                                    if (filteredChats.isEmpty) {
                                        return Center(
                                            child: Text(
                                                _searchQuery.isEmpty ? 'No history' : 'No matches found', 
                                                style: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.3))
                                            ),
                                        );
                                    }

                                    return ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredChats.length,
                                        itemBuilder: (context, index) {
                                            final chat = filteredChats[index];
                                            final isCurrent = chat.id == chatProvider.currentChat?.id;
                                            
                                            // Long Press for Options
                                            return GestureDetector(
                                                onLongPress: () {
                                                    _showSwipeOptions(context, chat.id, chat.title);
                                                },
                                                child: Container(
                                                    margin: const EdgeInsets.symmetric(vertical: 2),
                                                    decoration: isCurrent ? BoxDecoration(
                                                        borderRadius: BorderRadius.circular(12),
                                                        border: Border.all(
                                                            color: Theme.of(context).colorScheme.primary,
                                                            width: 1.5,
                                                        ),
                                                    ) : null,
                                                    child: ListTile(
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                                        leading: chat.isPinned 
                                                            ? Icon(Icons.push_pin, size: 16, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8))
                                                            : null,
                                                        title: Text(
                                                            chat.title, 
                                                            maxLines: 1, 
                                                            overflow: TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                                color: isCurrent 
                                                                    ? (isDark ? Colors.white : Theme.of(context).colorScheme.primary)
                                                                    : secondaryTextColor,
                                                                fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                                fontSize: 16,
                                                            )
                                                        ),
                                                        subtitle: Text(
                                                            DateFormat.MMMd().format(chat.updatedAt),
                                                            style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 12),
                                                        ),
                                                        onTap: () {
                                                            chatProvider.loadChat(chat.id);
                                                            Navigator.pop(context);
                                                        },
                                                        trailing: isCurrent ? Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black45, size: 16) : null,
                                                    ),
                                                ),
                                            );
                                        },
                                    );
                                },
                           ),
                       ),
                   ],
               ),
           ),

           // Floating Bottom Bar
           Positioned(
               left: 16,
               right: 16,
               bottom: (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom : MediaQuery.of(context).padding.bottom) + 16,
               child: Row(
                   children: [
                       // Search Bar
                       Expanded(
                           child: Container(
                               height: 50,
                               decoration: BoxDecoration(
                                   color: searchBarColor,
                                   borderRadius: BorderRadius.circular(25),
                                   border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                               ),
                               padding: const EdgeInsets.symmetric(horizontal: 16),
                               child: Row(
                                   children: [
                                       Icon(Icons.search, color: isDark ? Colors.grey : Colors.grey[600]),
                                       const SizedBox(width: 8),
                                       Expanded(
                                           child: TextField(
                                               controller: _searchController,
                                               decoration: InputDecoration(
                                                   hintText: 'Search', 
                                                   hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.grey[600]),
                                                   border: InputBorder.none,
                                                   isDense: true,
                                                   contentPadding: EdgeInsets.zero,
                                               ),
                                               style: TextStyle(color: textColor),
                                               onChanged: (value) {
                                                   setState(() {
                                                       _searchQuery = value;
                                                   });
                                               },
                                           ),
                                       ),
                                   ],
                               ),
                           ),
                       ),
                       const SizedBox(width: 12),
                       
                       // Settings Button
                       Container(
                           height: 50,
                           width: 50,
                           decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: searchBarColor,
                               border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                           ),
                           child: IconButton(
                               icon: Icon(Icons.settings, color: iconColor),
                               onPressed: () {
                                   Navigator.pop(context);
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
                               },
                           ),
                       ),
                       const SizedBox(width: 12),

                       // Analytics Button
                       Container(
                           height: 50,
                           width: 50,
                           decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               color: searchBarColor,
                               border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                           ),
                           child: IconButton(
                               icon: Icon(Icons.analytics_outlined, color: iconColor),
                               tooltip: 'Analytics',
                               onPressed: () {
                                   Navigator.pop(context);
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const AnalyticsScreen()));
                               },
                           ),
                       ),
                       const SizedBox(width: 12),

                       // New Chat Button
                       Container(
                           height: 50,
                           width: 50,
                           decoration: BoxDecoration(
                               shape: BoxShape.circle,
                               gradient: AppTheme.getPrimaryGradient(Theme.of(context).colorScheme.primary),
                               boxShadow: [
                                   BoxShadow(
                                       color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                       blurRadius: 10,
                                       offset: const Offset(0, 4),
                                   )
                               ],
                           ),
                           child: IconButton(
                               icon: const Icon(Icons.edit_square, color: Colors.white, size: 22),
                               onPressed: () {
                                   Navigator.pop(context);
                                   final chatProvider = context.read<ChatProvider>();
                                   if (chatProvider.isTempMode) chatProvider.toggleTempMode(); // Ensure saved mode
                                   chatProvider.startNewChat();
                               },
                           ),
                       ),
                   ],
               ),
           ),
           
           // Close Button (Top Right)
           Positioned(
               top: MediaQuery.of(context).padding.top + 8,
               right: 8,
               child: IconButton(
                   icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black45),
                   onPressed: () => Navigator.pop(context),
               ),
           ),
        ],
      ),
      ),
    );
  }

  void _showSwipeOptions(BuildContext context, String chatId, String currentTitle) {
      final chatProvider = context.read<ChatProvider>();
      final chat = chatProvider.chats.firstWhere((c) => c.id == chatId);
      
      showModalBottomSheet(
          context: context,
          backgroundColor: const Color(0xFF1E1E1E),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
          builder: (ctx) => SafeArea(
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Container(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(color: Colors.grey[700], borderRadius: BorderRadius.circular(2)),
                      ),
                      ListTile(
                          leading: Icon(
                              chat.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                              color: Colors.amber,
                          ),
                          title: Text(
                              chat.isPinned ? 'Unpin Chat' : 'Pin to Top',
                              style: const TextStyle(color: Colors.white),
                          ),
                          onTap: () {
                              Navigator.pop(ctx);
                              chatProvider.togglePinChat(chatId);
                          },
                      ),
                      ListTile(
                          leading: const Icon(Icons.edit, color: Colors.blueAccent),
                          title: const Text('Rename Chat', style: TextStyle(color: Colors.white)),
                          onTap: () {
                              Navigator.pop(ctx);
                              _showRenameDialog(context, chatId, currentTitle);
                          },
                      ),
                      ListTile(
                          leading: const Icon(Icons.delete, color: Colors.redAccent),
                          title: const Text('Delete Chat', style: TextStyle(color: Colors.redAccent)),
                          onTap: () {
                              Navigator.pop(ctx);
                              _confirmDelete(context, chatId);
                          },
                      ),
                      const SizedBox(height: 16),
                  ],
              ),
          ),
      );
  }

  void _showRenameDialog(BuildContext context, String chatId, String currentTitle) {
    final textController = TextEditingController(text: currentTitle);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Rename Chat', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new chat name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.blueAccent)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                context.read<ChatProvider>().renameChat(chatId, textController.text.trim());
                Navigator.pop(ctx);
              }
            },
            child: const Text('Rename', style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, String chatId) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('Delete Chat?', style: TextStyle(color: Colors.white)),
        content: const Text('This action cannot be undone.', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              context.read<ChatProvider>().deleteChat(chatId);
              Navigator.pop(ctx, true);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
