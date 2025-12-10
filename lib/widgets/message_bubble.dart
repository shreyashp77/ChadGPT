import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/message.dart';
import '../utils/theme.dart';

class MessageBubble extends StatelessWidget {
  final Message message;

  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == MessageRole.user;
    final isSystem = message.role == MessageRole.system;
    
    // System messages (errors, info)
    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
          ),
          child: Text(
            message.content,
            style: TextStyle(color: Colors.red[300], fontSize: 12),
          ),
        ),
      ).animate().fade().scale();
    }

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          gradient: isUser ? AppTheme.getPrimaryGradient(colorScheme.primary) : null,
          color: isUser ? null : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (message.attachmentPath != null) ...[
                  Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                              const Icon(Icons.attachment, size: 16, color: Colors.white70),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message.attachmentPath!.split('/').last, 
                                  maxLines:1, 
                                  overflow:TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                                )
                              )
                          ]
                      )
                  ),
              ],
              
              MarkdownBody(
                data: message.content,
                styleSheet: MarkdownStyleSheet(
                  p: TextStyle(
                    color: isUser ? Colors.white : colorScheme.onSurface,
                    fontSize: 16,
                    height: 1.5,
                  ),
                  code: TextStyle(
                    color: isUser ? Colors.white70 : colorScheme.onSurfaceVariant,
                    backgroundColor: isUser ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
                    fontFamily: 'monospace',
                    fontSize: 13,
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: isUser ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.3), // Darker background for code blocks
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                  ),
                  blockquoteDecoration: BoxDecoration(
                    color: isUser ? Colors.black.withValues(alpha: 0.1) : Colors.blueGrey.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border(left: BorderSide(color: isUser ? Colors.white70 : AppTheme.accent, width: 4)),
                  ),
                  blockquote: TextStyle(
                     color: isUser ? Colors.white70 : colorScheme.onSurface.withValues(alpha: 0.9),
                  ),
                  listBullet: TextStyle(
                    color: isUser ? Colors.white70 : colorScheme.primary,
                  ),
                  tableHead: const TextStyle(fontWeight: FontWeight.bold),
                  tableBorder: TableBorder.all(color: Colors.grey.withValues(alpha: 0.5), width: 0.5),
                  tableBody: TextStyle(
                     color: isUser ? Colors.white : colorScheme.onSurface,
                  ),
                  checkbox: TextStyle(
                      color: isUser ? Colors.white : AppTheme.accent, // Fix checkbox color
                  ),
                ),
                selectable: true,
              ),
            ],
          ),
        ),
      ),
    ).animate().slideY(begin: 0.3, end: 0, duration: 400.ms, curve: Curves.easeOutBack).fadeIn();
  }
}
