import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_highlighter/flutter_highlighter.dart';
import 'package:flutter_highlighter/themes/atom-one-dark.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../models/message.dart';
import '../utils/theme.dart';


class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    // 1. Determine roles
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;

    // 2. System Message
    if (isSystem) {
       // ... existing system message code ...
       return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
                Icon(Icons.info_outline, size: 16, color: Colors.red[300]),
                const SizedBox(width: 8),
                Text(
                    message.content,
                    style: TextStyle(color: Colors.red[300], fontSize: 13, fontWeight: FontWeight.w500),
                ),
            ],
          ),
        ),
      ).animate().fade().scale();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final chatProvider = context.watch<ChatProvider>();

    // 3. Main Bubble Layout
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
        child: Column(
            // Align column content (Bubble + Actions)
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
                Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                    decoration: BoxDecoration(
                        color: isUser 
                            ? colorScheme.primary 
                            : const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 4),
                            bottomRight: Radius.circular(isUser ? 4 : 20),
                        ),
                        boxShadow: [
                            BoxShadow(
                                color: Colors.black.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                            )
                        ]
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            // AI Header (Avatar + Name)
                            if (!isUser)
                                Padding(
                                    padding: const EdgeInsets.only(bottom: 8),
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                            _buildAvatar(context, isUser, chatProvider, size: 24, iconSize: 14),
                                            const SizedBox(width: 8),
                                            Text(
                                                chatProvider.currentPersona.name,
                                                style: TextStyle(
                                                    color: colorScheme.onSurface.withValues(alpha: 0.7),
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold
                                                ),
                                            ),
                                        ],
                                    ),
                                ),

                            // Attachments
                            if (message.attachmentPath != null) _buildAttachmentPreview(message.attachmentPath!),

                            // Text Content
                            MarkdownBody(
                                data: message.content,
                                styleSheet: MarkdownStyleSheet(
                                    p: TextStyle(
                                        color: isUser ? Colors.white : const Color(0xFFE0E0E0),
                                        fontSize: 15,
                                        height: 1.5,
                                    ),
                                    code: TextStyle(
                                        color: isUser ? Colors.white70 : const Color(0xFFE0E0E0),
                                        backgroundColor: Colors.black.withValues(alpha: 0.2),
                                        fontFamily: 'monospace',
                                        fontSize: 13,
                                    ),
                                    codeblockDecoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(8),
                                    ),
                                    blockquoteDecoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.05),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border(left: BorderSide(color: isUser ? Colors.white54 : AppTheme.accent, width: 3)),
                                    ),
                                ),
                                selectable: true,
                                builders: {
                                    'code': CodeElementBuilder(context),
                                },
                            ),
                        ],
                    ),
                ),

                // Action Buttons (Below bubble for AI)
                if (!isUser)
                    Padding(
                        padding: const EdgeInsets.only(top: 6, left: 4),
                        child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                _buildActionButton(
                                    context, 
                                    icon: Icons.volume_up_outlined, 
                                    onTap: () => chatProvider.speakMessage(message.content)
                                ),
                                const SizedBox(width: 12),
                                _buildActionButton(
                                    context, 
                                    icon: Icons.copy_outlined, 
                                    onTap: () {
                                            Clipboard.setData(ClipboardData(text: message.content));
                                            ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                    content: const Text('Copied'), 
                                                    behavior: SnackBarBehavior.floating, 
                                                    width: 100, 
                                                    backgroundColor: theme.primaryColor, 
                                                    duration: const Duration(milliseconds: 500)
                                                )
                                            );
                                    }
                                ),
                            ],
                        ),
                    ),
            ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0, duration: 400.ms, curve: Curves.easeOutQuad);
  }

  Widget _buildAvatar(BuildContext context, bool isUser, ChatProvider chatProvider, {double size = 36, double iconSize = 20}) {
      return Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isUser 
                 ? AppTheme.getPrimaryGradient(Theme.of(context).colorScheme.primary)
                 : null,
              color: isUser ? null : const Color(0xFF1E1E1E), // Dark background for AI icon
              border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
              boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2))
              ]
          ),
          child: Icon(
              isUser ? Icons.person : chatProvider.currentPersona.icon,
              size: iconSize,
              color: Colors.white,
          ),
      );
  }

  Widget _buildActionButton(BuildContext context, {required IconData icon, required VoidCallback onTap}) {
      return InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(icon, size: 16, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5)),
          ),
      );
  }

  Widget _buildAttachmentPreview(String path) {
      return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  const Icon(Icons.attachment, size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      path.split('/').last, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Colors.white70),
                    )
                  )
              ]
          )
      );
  }

  }


class CodeElementBuilder extends MarkdownElementBuilder {
  final BuildContext context;
  
  CodeElementBuilder(this.context);

  @override
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) {
    String content = element.textContent;
    
    // Check if it's likely a code block (multiline)
    if (!content.contains('\n')) {
      // Inline code
      final isUser = (context.findAncestorWidgetOfExactType<MessageBubble>()?.message.role == MessageRole.user);
      final colorScheme = Theme.of(context).colorScheme;
      return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
              color: isUser ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
          ),
          child: Text(content, style: TextStyle(
             fontFamily: 'monospace', 
             color: isUser ? Colors.white70 : colorScheme.onSurfaceVariant,
             fontSize: 13
          ))
      );
    }

    String language = '';
    if (element.attributes['class'] != null) {
      String lg = element.attributes['class'] as String;
      // class is usually "language-dart"
      if (lg.startsWith('language-')) {
          language = lg.substring(9);
      } else {
          language = lg;
      }
    }
    
    // If language is empty, try to guess or default
    if (language.isEmpty) language = 'plaintext';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Code Highlighting
            SizedBox(
                width: double.infinity,
                child: HighlightView(
                  content.trimRight(), // Trim trailing newline often added by parsers
                  language: language,
                  theme: atomOneDarkTheme, // premium dark theme
                  padding: const EdgeInsets.all(16).copyWith(top: 40), // Space for copy button
                  textStyle: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
            ),
            
            // Header with language and copy button
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                color: Colors.white.withValues(alpha: 0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      language.toUpperCase(), 
                      style: const TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)
                    ),
                    InkWell(
                      onTap: () {
                         HapticFeedback.selectionClick(); // Haptic
                         Clipboard.setData(ClipboardData(text: content.trim()));
                         ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(
                                 content: const Text('Code copied to clipboard'), 
                                 behavior: SnackBarBehavior.floating,
                                 width: 200,
                                 backgroundColor: Theme.of(context).colorScheme.primary,
                                 duration: const Duration(seconds: 1),
                             )
                         );
                      },
                      child: const Row(
                        children: [
                            Icon(Icons.copy, size: 14, color: Colors.white54),
                            SizedBox(width: 4),
                            Text('Copy', style: TextStyle(color: Colors.white54, fontSize: 10))
                        ],
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

