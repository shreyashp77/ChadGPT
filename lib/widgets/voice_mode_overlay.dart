import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
        backgroundColor: Colors.black, // Fully opaque black as requested
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

                                       return GestureDetector(
                                           onTap: () async {
                                               HapticFeedback.mediumImpact();
                                               // Trigger stops immediately without awaiting first to ensure UI feels responsive
                                               chatProvider.stopGeneration();
                                               final stopSpeakingFuture = chatProvider.stopSpeaking();
                                               
                                               // Ensure we stop previous listening too if active
                                               if (chatProvider.isListening) {
                                                   await chatProvider.stopListening();
                                               }
                                               
                                               // Ensure speaking is fully stopped on platform side before listening
                                               await stopSpeakingFuture;

                                               // Force start listening immediately
                                               await chatProvider.startListening(
                                                   (text) {
                                                       if (text.trim().isNotEmpty) {
                                                           chatProvider.sendMessage(text);
                                                       }
                                                   },
                                                   waitForFinal: true
                                               );
                                           },
                                           child: Container(
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
                    
                    // Transcript / Subtitles
                    // Show live transcription when listening, or subtitle when speaking
                    Positioned(
                        bottom: 50,
                        left: 20,
                        right: 20,
                        child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                                // Live transcription while listening
                                if (isListening && chatProvider.liveTranscription != null && chatProvider.liveTranscription!.isNotEmpty)
                                    Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                        decoration: BoxDecoration(
                                            color: AppTheme.accent.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(16),
                                            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                                        ),
                                        child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                                Icon(Icons.mic, size: 16, color: AppTheme.accent),
                                                const SizedBox(width: 8),
                                                Flexible(
                                                    child: Text(
                                                        chatProvider.liveTranscription!,
                                                        textAlign: TextAlign.center,
                                                        style: TextStyle(
                                                            color: Colors.white.withValues(alpha: 0.9),
                                                            fontSize: 16,
                                                            fontWeight: FontWeight.w400,
                                                        ),
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ).animate().fadeIn(duration: 200.ms),
                                
                                // Voice subtitle (TTS current sentence)
                                if (chatProvider.currentVoiceSubtitle != null && !isListening)
                                    Text(
                                        chatProvider.currentVoiceSubtitle!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                            color: Colors.white, 
                                            fontSize: 18, 
                                            fontWeight: FontWeight.w500,
                                            shadows: [
                                                Shadow(blurRadius: 10, color: Colors.black, offset: Offset(0, 2))
                                            ]
                                        ),
                                    ).animate(key: ValueKey(chatProvider.currentVoiceSubtitle)).fadeIn(duration: 200.ms),
                            ],
                        ),
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
