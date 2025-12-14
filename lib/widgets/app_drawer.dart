import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../providers/chat_provider.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';
import '../screens/settings_screen.dart';
import '../screens/analytics_screen.dart';
import '../models/chat_session.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  List<Map<String, dynamic>> _messageSearchResults = [];
  bool _isSearchingMessages = false;
  final DatabaseService _dbService = DatabaseService();

  Future<void> _searchMessages(String query) async {
    if (query.length < 2) {
      setState(() => _messageSearchResults = []);
      return;
    }
    setState(() => _isSearchingMessages = true);
    final results = await _dbService.searchMessages(query);
    setState(() {
      _messageSearchResults = results;
      _isSearchingMessages = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  final Set<String> _expandedFolders = {};
  int _selectedTabIndex = 0; // 0: Messages, 1: Folders

  void _toggleFolder(String folder) {
    setState(() {
      if (_expandedFolders.contains(folder)) {
        _expandedFolders.remove(folder);
      } else {
        _expandedFolders.add(folder);
      }
    });
  }
  void _showCreateFolderDialog() {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF2C2C2C),
        title: const Text('New Folder', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: textController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Folder name',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white54)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orange)),
          ),
          autofocus: true,
          onSubmitted: (value) {
            if (value.trim().isNotEmpty) {
              final name = value.trim();
              Navigator.pop(ctx);
              context.read<ChatProvider>().createFolder(name);
              setState(() {
                _expandedFolders.add(name);
                _selectedTabIndex = 1; // Switch to Folders tab
              });
            }
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (textController.text.trim().isNotEmpty) {
                final name = textController.text.trim();
                Navigator.pop(ctx);
                context.read<ChatProvider>().createFolder(name);
                setState(() {
                  _expandedFolders.add(name);
                  _selectedTabIndex = 1; // Switch to Folders tab
                });
              }
            },
            child: const Text('Create', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
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
                       Row(
                         mainAxisAlignment: MainAxisAlignment.start,
                         children: [
                           Text('History', style: TextStyle(color: textColor, fontSize: 32, fontWeight: FontWeight.bold)),
                         ],
                       ),
                       const SizedBox(height: 16),
                       // Tabs
                       Container(
                         height: 36,
                         decoration: BoxDecoration(
                           color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
                           borderRadius: BorderRadius.circular(10),
                         ),
                         padding: const EdgeInsets.all(2),
                         child: Row(
                           children: [
                             Expanded(
                               child: InkWell(
                                 onTap: () => setState(() => _selectedTabIndex = 0),
                                 borderRadius: BorderRadius.circular(8),
                                 child: Container(
                                   alignment: Alignment.center,
                                   decoration: BoxDecoration(
                                     color: _selectedTabIndex == 0 ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                                     borderRadius: BorderRadius.circular(8),
                                     border: _selectedTabIndex == 0 ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)) : null,
                                   ),
                                   child: Text(
                                     'Chats',
                                     style: TextStyle(
                                       fontSize: 13,
                                       fontWeight: _selectedTabIndex == 0 ? FontWeight.bold : FontWeight.normal,
                                       color: _selectedTabIndex == 0 ? Theme.of(context).colorScheme.primary : secondaryTextColor,
                                     ),
                                   ),
                                 ),
                               ),
                             ),
                             Expanded(
                               child: InkWell(
                                 onTap: () => setState(() => _selectedTabIndex = 1),
                                 borderRadius: BorderRadius.circular(8),
                                 child: Container(
                                   alignment: Alignment.center,
                                   decoration: BoxDecoration(
                                     color: _selectedTabIndex == 1 ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.1) : Colors.transparent,
                                     borderRadius: BorderRadius.circular(8),
                                     border: _selectedTabIndex == 1 ? Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2)) : null,
                                   ),
                                   child: Text(
                                     'Folders',
                                     style: TextStyle(
                                       fontSize: 13,
                                       fontWeight: _selectedTabIndex == 1 ? FontWeight.bold : FontWeight.normal,
                                       color: _selectedTabIndex == 1 ? Theme.of(context).colorScheme.primary : secondaryTextColor,
                                     ),
                                   ),
                                 ),
                               ),
                             ),
                           ],
                         ),
                       ),
                       const SizedBox(height: 16),
                       Expanded(
                           child: Consumer<ChatProvider>(
                                builder: (context, chatProvider, _) {
                                    final chats = chatProvider.chats;
                                    
                                    // Filter chats based on search query
                                     final filteredChats = _searchQuery.isEmpty 
                                         ? chats 
                                         : chats.where((chat) => chat.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                                     
                                     // ... existing message search code ...
                                     if (_searchQuery.length >= 2 && (_messageSearchResults.isNotEmpty || _isSearchingMessages)) {
                                       // Only searching messages, same as before
                                       return Column(
                                         crossAxisAlignment: CrossAxisAlignment.start,
                                         children: [
                                           // Message search results header
                                           Row(
                                             children: [
                                               Icon(Icons.search, size: 16, color: Theme.of(context).colorScheme.primary),
                                               const SizedBox(width: 8),
                                               Text(
                                                 'Messages containing "${_searchQuery}"',
                                                 style: TextStyle(color: secondaryTextColor, fontSize: 12),
                                               ),
                                               if (_isSearchingMessages) ...[
                                                 const SizedBox(width: 8),
                                                 SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2)),
                                               ],
                                             ],
                                           ),
                                           const SizedBox(height: 12),
                                           // Message search results list
                                           Expanded(
                                             child: _messageSearchResults.isEmpty
                                               ? Center(child: Text('No messages found', style: TextStyle(color: isDark ? Colors.white30 : Colors.black38)))
                                               : ListView.builder(
                                                   padding: EdgeInsets.zero,
                                                   itemCount: _messageSearchResults.length,
                                                   itemBuilder: (context, index) {
                                                      final result = _messageSearchResults[index];
                                                      final content = result['content'] as String? ?? '';
                                                      final chatTitle = result['chat_title'] as String? ?? 'Untitled';
                                                      final chatId = result['chat_id'] as String;
                                                      final role = result['role'] as String? ?? 'user';
                                                      
                                                      // Truncate content for preview
                                                      final preview = content.length > 80 ? '${content.substring(0, 80)}...' : content;
                                                      
                                                      return ListTile(
                                                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                        leading: Icon(
                                                          role == 'user' ? Icons.person : Icons.smart_toy,
                                                          size: 20,
                                                          color: role == 'user' ? Colors.blue : Colors.purple,
                                                        ),
                                                        title: Text(chatTitle, style: TextStyle(color: textColor, fontSize: 14, fontWeight: FontWeight.w500)),
                                                        subtitle: Text(preview, maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(color: secondaryTextColor, fontSize: 12)),
                                                        onTap: () {
                                                          chatProvider.loadChat(chatId);
                                                          Navigator.pop(context);
                                                        },
                                                      );
                                                   },
                                                 ),
                                           ),
                                         ],
                                       );
                                     }

                                     if (filteredChats.isEmpty) {
                                         return Center(
                                             child: Text(
                                                 _searchQuery.isEmpty ? 'No history' : 'No matches found', 
                                                 style: TextStyle(color: isDark ? Colors.white.withOpacity(0.3) : Colors.black.withOpacity(0.3))
                                             ),
                                         );
                                     }
                                     
                                     // Build items based on selected tab
                                     final List<dynamic> items = [];
                                     
                                     if (_selectedTabIndex == 0) {
                                       // MESSAGES TAB: Show all chats (already sorted by keys)
                                       items.addAll(filteredChats);
                                     } else {
                                       // FOLDERS TAB
                                       final Map<String, List<dynamic>> folderChats = {};
                                       // Initialize with all known folders
                                       for (final folder in chatProvider.allFolders) {
                                         folderChats[folder] = [];
                                       }
                                       
                                       // Distribute chats
                                       for (final chat in filteredChats) {
                                         if (chat.folder != null) {
                                            folderChats.putIfAbsent(chat.folder!, () => []).add(chat);
                                         }
                                       }
                                       
                                       final sortedFolders = folderChats.keys.toList()..sort((a, b) => a.compareTo(b));
                                        
                                       for (final folder in sortedFolders) {
                                         final isExpanded = _expandedFolders.contains(folder);
                                         final chatsInFolder = folderChats[folder]!;
                                         items.add({'_folder': folder, '_count': chatsInFolder.length, '_isExpanded': isExpanded});
                                         if (isExpanded) {
                                             items.addAll(chatsInFolder);
                                         }
                                       }
                                     }
                                     
                                     return ListView.builder(
                                        padding: EdgeInsets.zero,
                                        itemCount: items.length,
                                        itemBuilder: (context, index) {
                                            final item = items[index];
                                            
                                            // Folder header
                                            if (item is Map && item.containsKey('_folder')) {
                                              final folderName = item['_folder'] as String;
                                              final count = item['_count'] as int;
                                              final isExpanded = item['_isExpanded'] as bool;
                                              
                                              return InkWell(
                                                onTap: () => _toggleFolder(folderName),
                                                borderRadius: BorderRadius.circular(12),
                                                child: Container(
                                                  margin: const EdgeInsets.only(top: 12, bottom: 4),
                                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                                  child: Row(
                                                    children: [
                                                      AnimatedRotation(
                                                          turns: isExpanded ? 0.25 : 0,
                                                          duration: const Duration(milliseconds: 200),
                                                          child: Icon(Icons.arrow_right_rounded, color: isDark ? Colors.white54 : Colors.black54),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Icon(Icons.folder_rounded, size: 18, color: Colors.orange.withOpacity(0.9)),
                                                      const SizedBox(width: 12),
                                                      Text(
                                                        folderName,
                                                        style: TextStyle(
                                                          color: isDark ? Colors.white70 : Colors.black87,
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w600,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                          '($count)', 
                                                          style: TextStyle(
                                                              color: isDark ? Colors.white30 : Colors.black38, 
                                                              fontSize: 12,
                                                          )
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            }
                                            
                                            // Chat item
                                            final chat = item;
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
                                                      dense: true,
                                                      contentPadding: (_selectedTabIndex == 1 && chat.folder != null)
                                                          ? const EdgeInsets.only(left: 44, right: 16)
                                                          : const EdgeInsets.symmetric(horizontal: 16),
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
                                                            fontSize: 15,
                                                        )
                                                      ),
                                                      subtitle: Text(
                                                          DateFormat.MMMd().format(chat.updatedAt),
                                                          style: TextStyle(color: isDark ? Colors.white30 : Colors.black38, fontSize: 11),
                                                      ),
                                                      onTap: () {
                                                          chatProvider.loadChat(chat.id);
                                                          Navigator.pop(context);
                                                      },
                                                      trailing: isCurrent 
                                                          ? Icon(Icons.chevron_right, color: isDark ? Colors.white54 : Colors.black45, size: 16) 
                                                          : (chat.hasUnreadMessages 
                                                              ? Container(
                                                                    width: 16,
                                                                    height: 16,
                                                                    alignment: Alignment.center,
                                                                    child: Container(
                                                                        width: 8,
                                                                        height: 8,
                                                                        decoration: BoxDecoration(
                                                                            color: Theme.of(context).colorScheme.primary,
                                                                            shape: BoxShape.circle,
                                                                            boxShadow: [
                                                                                BoxShadow(
                                                                                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                                                                                    blurRadius: 4,
                                                                                    spreadRadius: 1,
                                                                                )
                                                                            ]
                                                                        ),
                                                                    ),
                                                                )
                                                                : Row(
                                                                    mainAxisSize: MainAxisSize.min,
                                                                    children: [
                                                                      // Attachment indicator (📎)
                                                                      if (chat.hasAttachments)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(right: 6),
                                                                          child: Icon(Icons.attach_file, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), size: 14),
                                                                        ),
                                                                      // Generated media indicator (🖼️)
                                                                      if (chat.hasGeneratedMedia)
                                                                        Icon(Icons.brush, color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7), size: 14),
                                                                    ],
                                                                  )),
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
                                                   _searchMessages(value);  // Also search message content
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
                          leading: const Icon(Icons.share, color: Colors.green),
                          title: const Text('Export Chat', style: TextStyle(color: Colors.white)),
                          onTap: () async {
                              Navigator.pop(ctx);
                              await _exportChat(context, chat);
                          },
                      ),
                      ListTile(
                          leading: const Icon(Icons.folder_outlined, color: Colors.orange),
                          title: Text(
                            chat.folder != null ? 'Move to Different Folder' : 'Move to Folder',
                            style: const TextStyle(color: Colors.white),
                          ),
                          subtitle: chat.folder != null 
                            ? Text('Current: ${chat.folder}', style: TextStyle(color: Colors.white54, fontSize: 12))
                            : null,
                          onTap: () {
                              Navigator.pop(ctx);
                              _showFolderDialog(context, chatId, chat.folder);
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

  void _showFolderDialog(BuildContext context, String chatId, String? currentFolder) {
    final chatProvider = context.read<ChatProvider>();
    final folders = chatProvider.allFolders;
    final textController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF1E1E1E),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 10), // Less bottom padding since logic handles actions
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Move to Folder', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Current Folders
                      ...folders.map((f) => Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: f == currentFolder ? Border.all(color: Colors.orange.withOpacity(0.5)) : null,
                        ),
                        child: ListTile(
                          dense: true,
                          leading: Icon(Icons.folder_rounded, color: f == currentFolder ? Colors.orange : Colors.grey),
                          title: Text(f, style: const TextStyle(color: Colors.white)),
                          trailing: f == currentFolder ? const Icon(Icons.check, color: Colors.orange, size: 20) : null,
                          onTap: () {
                            chatProvider.moveToFolder(chatId, f);
                            Navigator.pop(ctx);
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )).toList(),
                      
                      const SizedBox(height: 8),
                      // Remove from folder option
                      if (currentFolder != null)
                        InkWell(
                            onTap: () {
                                chatProvider.moveToFolder(chatId, null);
                                Navigator.pop(ctx);
                            },
                            child: const Padding(
                                padding: EdgeInsets.all(12),
                                child: Text('Remove from folder', style: TextStyle(color: Colors.redAccent, fontSize: 14)),
                            ),
                        ),
                    ],
                  ),
                ),
              ),
              const Divider(color: Colors.white12, height: 30),
              // Create New Folder
              Row(
                  children: [
                    const Icon(Icons.create_new_folder_outlined, color: Colors.white54, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: textController,
                        style: const TextStyle(color: Colors.white),
                        decoration: const InputDecoration(
                          hintText: 'New folder name...',
                          hintStyle: TextStyle(color: Colors.white38, fontSize: 14),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle, color: Colors.orange),
                      tooltip: 'Create & Move',
                      onPressed: () {
                        final name = textController.text.trim();
                        if (name.isNotEmpty) {
                          chatProvider.createFolder(name);
                          chatProvider.moveToFolder(chatId, name);
                          Navigator.pop(ctx);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
            ],
          ),
        ),
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
  
  Future<void> _exportChat(BuildContext context, ChatSession chat) async {
    try {
      // Load messages for this chat
      final chatProvider = context.read<ChatProvider>();
      await chatProvider.loadChatMessages(chat.id);
      final loadedChat = chatProvider.chats.firstWhere((c) => c.id == chat.id);
      
      // Generate markdown content
      final buffer = StringBuffer();
      buffer.writeln('# ${loadedChat.title}');
      buffer.writeln('');
      buffer.writeln('Exported on: ${DateFormat.yMMMd().add_jm().format(DateTime.now())}');
      buffer.writeln('');
      buffer.writeln('---');
      buffer.writeln('');
      
      for (final msg in loadedChat.messages) {
        final role = msg.role.toString().split('.').last.toUpperCase();
        final timestamp = DateFormat.jm().format(msg.timestamp);
        buffer.writeln('**[$role]** _${timestamp}_');
        buffer.writeln('');
        buffer.writeln(msg.content);
        buffer.writeln('');
        buffer.writeln('---');
        buffer.writeln('');
      }
      
      // Save to temp file
      final tempDir = await getTemporaryDirectory();
      final sanitizedTitle = loadedChat.title.replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(' ', '_');
      final file = File('${tempDir.path}/${sanitizedTitle}.md');
      await file.writeAsString(buffer.toString());
      
      // Share
      await Share.shareXFiles([XFile(file.path)], text: 'Chat: ${loadedChat.title}');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Chat exported'), behavior: SnackBarBehavior.floating),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e'), behavior: SnackBarBehavior.floating),
        );
      }
    }
  }
}
