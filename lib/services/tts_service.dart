import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  // Callback for state changes
  Function(bool isPlaying)? onStateChanged;
  VoidCallback? onCompletion;

  TtsService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setSpeechRate(0.5); // 0.5 is usually a good natural speed baseline
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);

    _flutterTts.setStartHandler(() {
      _isPlaying = true;
      onStateChanged?.call(true);
    });

    _flutterTts.setCompletionHandler(() {
      _isPlaying = false;
      onStateChanged?.call(false);
      onCompletion?.call();
    });

    _flutterTts.setCancelHandler(() {
      _isPlaying = false;
      onStateChanged?.call(false);
    });
    
    _flutterTts.setErrorHandler((msg) {
       _isPlaying = false;
       onStateChanged?.call(false);
       print("TTS Error: $msg");
    });
  }

  Future<void> speak(String text) async {
    if (text.isNotEmpty) {
      await _flutterTts.speak(text);
    }
  }

  Future<void> stop() async {
    await _flutterTts.stop();
  }
}
