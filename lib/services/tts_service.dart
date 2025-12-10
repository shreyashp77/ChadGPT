import 'dart:ui';
import 'package:flutter_tts/flutter_tts.dart';

class TtsService {
  final FlutterTts _flutterTts = FlutterTts();
  
  final List<String> _speechQueue = [];
  bool get isQueueEmpty => _speechQueue.isEmpty;

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
    await _flutterTts.setSpeechRate(0.5); 
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    
    // Key fix: Wait for each utterance to finish
    await _flutterTts.awaitSpeakCompletion(true);

    _flutterTts.setStartHandler(() {
       // Optional: UI update if needed, but we manage _isPlaying manually in loop mostly
       onStateChanged?.call(true);
    });

    // We don't rely on completion handler for queue logic anymore, 
    // as we await the speak call.
    // But we might keep it implementation-agnostic.
    
    _flutterTts.setCancelHandler(() {
      // If external cancel happens
      onStateChanged?.call(false);
    });
    
    _flutterTts.setErrorHandler((msg) {
       _isPlaying = false;
       _speechQueue.clear();
       onStateChanged?.call(false);
       print("TTS Error: $msg");
    });
  }

  Future<void> speak(String text) async {
    await stop(); // Stop current queue
    if (text.isNotEmpty) {
      _isPlaying = true;
      onStateChanged?.call(true);
      await _flutterTts.speak(text);
      _isPlaying = false;
      onStateChanged?.call(false);
      onCompletion?.call();
    }
  }

  Future<void> speakQueued(String text) async {
      if (text.trim().isEmpty) return;
      
      _speechQueue.add(text);
      
      // If not currently speaking, start processing queue
      if (!_isPlaying) {
          _processQueue();
      }
  }

  Future<void> _processQueue() async {
      if (_isPlaying) return;
      _isPlaying = true;
      onStateChanged?.call(true);

      try {
          while (_speechQueue.isNotEmpty) {
              // Double check to ensure we weren't stopped
              if (!_isPlaying) { 
                  _speechQueue.clear();
                  return;
              }
              
              final nextText = _speechQueue.removeAt(0);
              // This will now wait until speech is finished because of awaitSpeakCompletion(true)
              await _flutterTts.speak(nextText);
          }
      } catch (e) {
          print("TTS Queue Error: $e");
          _speechQueue.clear();
      } finally {
          _isPlaying = false;
          onStateChanged?.call(false);
          // Only fire completion if we drained the queue naturally (not stopped)
          // `speak` future throws/cancels on stop? Usually returns.
          // We can check if we should fire completion.
          // If queue is empty, we are done.
          if (_speechQueue.isEmpty) {
               onCompletion?.call();
          }
      }
  }

  Future<void> stop() async {
    _isPlaying = false; // Flag to stop processing loop
    _speechQueue.clear();
    await _flutterTts.stop();
    onStateChanged?.call(false);
  }
}
