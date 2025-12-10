import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/chat_provider.dart';
import '../utils/theme.dart';

class VoiceModeOverlay extends StatefulWidget {
  const VoiceModeOverlay({super.key});

  @override
  State<VoiceModeOverlay> createState() => _VoiceModeOverlayState();
}

class _VoiceModeOverlayState extends State<VoiceModeOverlay> with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
       vsync: this,
       duration: const Duration(seconds: 2), 
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = context.watch<ChatProvider>();
    final isListening = chatProvider.isListening;
    final isSpeaking = chatProvider.isTtsPlaying;
    final isThinking = chatProvider.isTyping && !isSpeaking;

    String statusText = "Initializing...";
    if (isListening) statusText = "Listening...";
    else if (isThinking) statusText = "Thinking...";
    else if (isSpeaking) statusText = "Speaking...";
    else statusText = "Waiting...";

    return Scaffold(
        backgroundColor: Colors.black.withValues(alpha: 0.9),
        body: SafeArea(
            child: Stack(
                children: [
                    // Close Button
                    Positioned(
                        top: 16,
                        right: 16,
                        child: IconButton(
                            icon: const Icon(Icons.close, color: Colors.white, size: 30),
                            onPressed: () {
                                chatProvider.stopContinuousVoiceMode();
                                Navigator.of(context).pop();
                            },
                        ),
                    ),

                    // Main Visuals
                    Center(
                        child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                // Visualizer Circle
                                AnimatedBuilder(
                                    animation: _pulseController,
                                    builder: (context, child) {
                                       double scale = 1.0;
                                       double opacity = 0.3;
                                       Color color = Colors.white;

                                       if (isListening) {
                                           scale = 1.0 + (_pulseController.value * 0.5); // Pulse effect
                                           color = AppTheme.accent;
                                           opacity = 0.5;
                                       } else if (isSpeaking) {
                                            scale = 1.0 + (_pulseController.value * 0.2);
                                            color = Colors.greenAccent;
                                            opacity = 0.6;
                                       } else if (isThinking) {
                                           // Thinking handled by rotation below
                                           scale = 1.0;
                                           color = Colors.white; 
                                           opacity = 0.2;
                                       }

                                       return Container(
                                           width: 150,
                                           height: 150,
                                           decoration: BoxDecoration(
                                               shape: BoxShape.circle,
                                               color: color.withValues(alpha: opacity * 0.3),
                                               boxShadow: [
                                                   BoxShadow(
                                                       color: color.withValues(alpha: opacity),
                                                       blurRadius: 20 * scale,
                                                       spreadRadius: 5 * scale,
                                                   )
                                               ]
                                           ),
                                           child: isThinking 
                                               ? const CircularProgressIndicator(color: Colors.white70).p(40)
                                               : Icon(
                                                   isListening ? Icons.mic : (isSpeaking ? Icons.volume_up : Icons.more_horiz),
                                                   size: 60,
                                                   color: Colors.white,
                                               ),
                                       );
                                    },
                                ),
                                const SizedBox(height: 50),
                                
                                // Status Text
                                Text(
                                    statusText,
                                    style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w300,
                                        letterSpacing: 1.2
                                    ),
                                ).animate(key: ValueKey(statusText)).fadeIn(),
                            ],
                        ),
                    ),
                    
                    // Transcript / Subtitles (Optional - maybe show last user text?)
                    if (isThinking || isSpeaking)
                        Positioned(
                            bottom: 50,
                            left: 20,
                            right: 20,
                            child: Text(
                                chatProvider.currentChat?.messages.isNotEmpty == true 
                                   ? chatProvider.currentChat!.messages.last.content 
                                   : "",
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white54, fontSize: 16),
                            ).animate().fadeIn(),
                        ),
                ],
            ),
        ),
    );
  }
}

extension PaddingExt on Widget {
    Widget p(double padding) => Padding(padding: EdgeInsets.all(padding), child: this);
}
