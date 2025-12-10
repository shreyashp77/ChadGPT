import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import '../utils/theme.dart';
import '../screens/settings_screen.dart';

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
    return Drawer(
      width: MediaQuery.of(context).size.width, // Full screen
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
           // Main Content: History List
           Padding(
               padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 100), // Bottom padding for floating bar
               child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                       const Text('History', style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
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
                                                style: TextStyle(color: Colors.white.withValues(alpha: 0.3))
                                            ),
                                        );
                                    }

                                    return ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: filteredChats.length,
                                        itemBuilder: (context, index) {
                                            final chat = filteredChats[index];
                                            final isCurrent = chat.id == chatProvider.currentChat?.id;
                                            
                                            // Swipe Actions
                                            return Dismissible(
                                                key: Key(chat.id),
                                                direction: DismissDirection.horizontal,
                                                background: Container(
                                                    color: Colors.blueAccent,
                                                    alignment: Alignment.centerLeft,
                                                    padding: const EdgeInsets.only(left: 20),
                                                    child: const Icon(Icons.edit, color: Colors.white),
                                                ),
                                                secondaryBackground: Container(
                                                    color: Colors.redAccent,
                                                    alignment: Alignment.centerRight,
                                                    padding: const EdgeInsets.only(right: 20),
                                                    child: const Icon(Icons.delete, color: Colors.white),
                                                ),
                                                confirmDismiss: (direction) async {
                                                    if (direction == DismissDirection.startToEnd) {
                                                        // Swipe Right: Rename
                                                        _showRenameDialog(context, chat.id, chat.title);
                                                        return false; // Do not dismiss
                                                    } else {
                                                        // Swipe Left: Delete
                                                        return await _confirmDelete(context, chat.id);
                                                    }
                                                },
                                                child: ListTile(
                                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                                                    title: Text(
                                                        chat.title, 
                                                        maxLines: 1, 
                                                        overflow: TextOverflow.ellipsis,
                                                        style: TextStyle(
                                                            color: isCurrent ? Colors.white : Colors.white70,
                                                            fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                                                            fontSize: 16,
                                                        )
                                                    ),
                                                    subtitle: Text(
                                                        DateFormat.MMMd().format(chat.updatedAt),
                                                        style: const TextStyle(color: Colors.white30, fontSize: 12),
                                                    ),
                                                    onTap: () {
                                                        chatProvider.loadChat(chat.id);
                                                        Navigator.pop(context);
                                                    },
                                                    trailing: isCurrent ? const Icon(Icons.chevron_right, color: Colors.white54, size: 16) : null,
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
                                   color: const Color(0xFF1E1E1E),
                                   borderRadius: BorderRadius.circular(25),
                                   border: Border.all(color: Colors.white10),
                               ),
                               padding: const EdgeInsets.symmetric(horizontal: 16),
                               child: Row(
                                   children: [
                                       const Icon(Icons.search, color: Colors.grey),
                                       const SizedBox(width: 8),
                                       Expanded(
                                           child: TextField(
                                               controller: _searchController,
                                               decoration: const InputDecoration(
                                                   hintText: 'Search History', 
                                                   hintStyle: TextStyle(color: Colors.grey),
                                                   border: InputBorder.none,
                                                   isDense: true,
                                                   contentPadding: EdgeInsets.zero,
                                               ),
                                               style: const TextStyle(color: Colors.white),
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
                           decoration: const BoxDecoration(
                               shape: BoxShape.circle,
                               color: Color(0xFF1E1E1E),
                           ),
                           child: IconButton(
                               icon: const Icon(Icons.settings, color: Colors.white),
                               onPressed: () {
                                   Navigator.pop(context);
                                   Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsScreen()));
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
                               icon: const Icon(Icons.create, color: Colors.white, size: 22),
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
           
           // Close Button (Top Right) - Optional but good for full screen drawer
           Positioned(
               top: MediaQuery.of(context).padding.top + 8,
               right: 8,
               child: IconButton(
                   icon: const Icon(Icons.close, color: Colors.white54),
                   onPressed: () => Navigator.pop(context),
               ),
           ),
        ],
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
