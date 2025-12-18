import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:async';

class TypingIndicator extends StatefulWidget {
  final bool showElapsedTime;
  final String? modelName;  // Optional model name to show while loading
  final String? statusText; // Optional specific status text (e.g., Deep Research status)
  
  const TypingIndicator({super.key, this.showElapsedTime = true, this.modelName, this.statusText});

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator> {
  late DateTime _startTime;
  Timer? _timer;
  String _elapsedText = '0s';

  @override
  void initState() {
    super.initState();
    _startTime = DateTime.now();
    
    if (widget.showElapsedTime) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) {
          final elapsed = DateTime.now().difference(_startTime);
          setState(() {
            if (elapsed.inMinutes > 0) {
              _elapsedText = '${elapsed.inMinutes}m ${elapsed.inSeconds % 60}s';
            } else {
              _elapsedText = '${elapsed.inSeconds}s';
            }
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Animated dots
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF2A2A2A),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDot(colorScheme, 0),
                const SizedBox(width: 4),
                _buildDot(colorScheme, 1),
                const SizedBox(width: 4),
                _buildDot(colorScheme, 2),
              ],
            ),
          ),
          
          // Model name loading indicator (display name passed in directly)
          if (widget.modelName != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Loading ${widget.modelName}...',
                style: TextStyle(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ] else if (widget.statusText != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.statusText!,
                style: TextStyle(
                  color: colorScheme.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ] else if (widget.showElapsedTime) ...[
            // Elapsed time (only show if no model name)
            const SizedBox(width: 8),
            Text(
              _elapsedText,
              style: TextStyle(
                color: colorScheme.onSurface.withValues(alpha: 0.5),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDot(ColorScheme colorScheme, int index) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: colorScheme.primary,
      ),
    )
        .animate(
          onPlay: (controller) => controller.repeat(),
        )
        .scale(
          begin: const Offset(1.0, 1.0),
          end: const Offset(1.4, 1.4),
          delay: Duration(milliseconds: index * 150),
          duration: 400.ms,
          curve: Curves.easeInOut,
        )
        .then()
        .scale(
          begin: const Offset(1.4, 1.4),
          end: const Offset(1.0, 1.0),
          duration: 400.ms,
          curve: Curves.easeInOut,
        );
  }
}
