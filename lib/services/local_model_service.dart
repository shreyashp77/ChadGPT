import 'dart:async';
import 'dart:io';
import 'package:llama_flutter_android/llama_flutter_android.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import '../models/local_model.dart';

/// Service for downloading GGUF models and running on-device inference
/// using llama_flutter_android (llama.cpp wrapper optimized for Android)
class LocalModelService {
  static final LocalModelService _instance = LocalModelService._internal();
  factory LocalModelService() => _instance;
  LocalModelService._internal();

  LlamaController? _llamaController;
  LocalModel? _loadedModel;
  bool _isGenerating = false;
  
  // Background download tracking - persists across screen navigations
  final Map<String, StreamController<double>> _downloadControllers = {};
  final Map<String, double> _downloadProgress = {};
  final Map<String, bool> _activeDownloads = {};
  
  /// Currently loaded model
  LocalModel? get loadedModel => _loadedModel;
  
  /// Whether a generation is in progress
  bool get isGenerating => _isGenerating;
  
  /// Get active downloads map (model id -> is downloading)
  Map<String, bool> get activeDownloads => Map.unmodifiable(_activeDownloads);
  
  /// Get download progress map (model id -> progress 0.0 to 1.0)
  Map<String, double> get downloadProgressMap => Map.unmodifiable(_downloadProgress);
  
  /// Check if a specific model is currently downloading
  bool isDownloading(String modelId) => _activeDownloads[modelId] ?? false;
  
  /// Get current progress for a model (0.0 to 1.0)
  double getProgress(String modelId) => _downloadProgress[modelId] ?? 0.0;
  
  /// Subscribe to download progress updates for a model
  /// Returns null if no download is active for this model
  Stream<double>? getProgressStream(String modelId) {
    return _downloadControllers[modelId]?.stream;
  }

  /// Get the directory where models are stored
  Future<Directory> get modelsDirectory async {
    final appDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDir.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir;
  }

  /// Start downloading a model in the background
  /// Returns a stream of download progress (0.0 to 1.0)
  /// The download continues even if the stream is not listened to
  Stream<double> downloadModel(LocalModel model) {
    // If already downloading, return existing stream
    if (_activeDownloads[model.id] == true && _downloadControllers[model.id] != null) {
      return _downloadControllers[model.id]!.stream;
    }
    
    // Create new controller for this download
    final controller = StreamController<double>.broadcast();
    _downloadControllers[model.id] = controller;
    _activeDownloads[model.id] = true;
    _downloadProgress[model.id] = 0.0;
    
    // Start download in background (fire and forget)
    _performDownload(model, controller);
    
    return controller.stream;
  }
  
  /// Internal method to perform the actual download
  Future<void> _performDownload(LocalModel model, StreamController<double> controller) async {
    try {
      final dir = await modelsDirectory;
      final filePath = '${dir.path}/${model.filename}';
      final file = File(filePath);

      // If file already exists and is complete, skip download
      if (await file.exists()) {
        final existingSize = await file.length();
        if (existingSize >= model.sizeBytes * 0.99) {
          // File exists and is ~complete
          _downloadProgress[model.id] = 1.0;
          controller.add(1.0);
          _cleanupDownload(model.id);
          return;
        }
        // Incomplete file, delete and re-download
        await file.delete();
      }

      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(model.downloadUrl));
        final response = await client.send(request);

        if (response.statusCode != 200) {
          throw Exception('Failed to download: HTTP ${response.statusCode}');
        }

        final contentLength = response.contentLength ?? model.sizeBytes;
        int receivedBytes = 0;
        
        final sink = file.openWrite();
        
        await for (final chunk in response.stream) {
          // Check if download was cancelled
          if (_activeDownloads[model.id] != true) {
            await sink.close();
            return;
          }
          
          sink.add(chunk);
          receivedBytes += chunk.length;
          final progress = receivedBytes / contentLength;
          _downloadProgress[model.id] = progress;
          controller.add(progress);
        }
        
        await sink.close();
        _downloadProgress[model.id] = 1.0;
        controller.add(1.0);
      } finally {
        client.close();
      }
    } catch (e) {
      print('Error downloading model: $e');
      controller.addError(e);
    } finally {
      _cleanupDownload(model.id);
    }
  }
  
  /// Clean up download tracking after completion or error
  void _cleanupDownload(String modelId) {
    _activeDownloads.remove(modelId);
    _downloadProgress.remove(modelId);
    _downloadControllers[modelId]?.close();
    _downloadControllers.remove(modelId);
  }
  
  /// Cancel an in-progress download
  void cancelDownload(String modelId) {
    _activeDownloads[modelId] = false;
    _cleanupDownload(modelId);
  }

  /// Get the local path for a downloaded model
  Future<String?> getModelPath(LocalModel model) async {
    final dir = await modelsDirectory;
    final filePath = '${dir.path}/${model.filename}';
    final file = File(filePath);
    
    if (await file.exists()) {
      return filePath;
    }
    return null;
  }

  /// Check if a model is downloaded
  Future<bool> isModelDownloaded(LocalModel model) async {
    final path = await getModelPath(model);
    if (path == null) return false;
    
    final file = File(path);
    if (!await file.exists()) return false;
    
    // Check file size is approximately correct (within 1%)
    final fileSize = await file.length();
    return fileSize >= model.sizeBytes * 0.99;
  }

  /// Load a model for inference
  Future<bool> loadModel(
    LocalModel model, {
    int gpuLayers = 0,
    int contextSize = 2048,
    int nThreads = 4,
  }) async {
    try {
      final path = await getModelPath(model);
      if (path == null) {
        throw Exception('Model not downloaded: ${model.filename}');
      }

      // Unload any existing model first
      if (_loadedModel != null) {
        await unloadModel();
      }

      // Create a new controller for this session
      _llamaController = LlamaController();
      
      await _llamaController!.loadModel(
        modelPath: path,
        threads: nThreads,
        contextSize: contextSize,
        gpuLayers: gpuLayers > 0 ? gpuLayers : null,
      );
      
      _loadedModel = model.copyWith(status: LocalModelStatus.loaded);
      print('Model loaded successfully: ${model.name}');
      return true;
    } catch (e) {
      print('Error loading model: $e');
      _llamaController = null;
      return false;
    }
  }

  /// Unload the currently loaded model
  Future<void> unloadModel() async {
    try {
      if (_llamaController != null) {
        await _llamaController!.dispose();
        _llamaController = null;
      }
      _loadedModel = null;
      print('Model unloaded');
    } catch (e) {
      print('Error unloading model: $e');
    }
  }

  /// Delete a downloaded model file
  Future<bool> deleteModel(LocalModel model) async {
    try {
      // Unload if this model is currently loaded
      if (_loadedModel?.id == model.id) {
        await unloadModel();
      }

      final path = await getModelPath(model);
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          print('Deleted model file: ${model.filename}');
          return true;
        }
      }
      return false;
    } catch (e) {
      print('Error deleting model: $e');
      return false;
    }
  }

  /// Check if a model is currently loaded
  bool get isModelLoaded => _loadedModel != null && _llamaController != null;

  /// Get info about the currently loaded model
  Future<Map<String, dynamic>?> getModelInfo() async {
    if (_loadedModel == null) return null;
    return {
      'name': _loadedModel!.name,
      'id': _loadedModel!.id,
      'parameters': _loadedModel!.parameters,
      'quantization': _loadedModel!.quantization,
    };
  }

  /// Generate text response (streaming)
  /// Yields tokens as they are generated
  Stream<String> generateStream(
    String prompt, {
    double temperature = 0.7,
    int maxTokens = 512,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!isModelLoaded || _llamaController == null) {
      throw Exception('No model loaded');
    }

    _isGenerating = true;
    try {
      await for (final token in _llamaController!.generate(
        prompt: prompt,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      )) {
        yield token;
      }
    } finally {
      _isGenerating = false;
    }
  }

  /// Generate chat response (streaming)
  /// Uses the model's built-in chat template
  Stream<String> generateChatStream(
    List<Map<String, String>> messages, {
    String? systemPrompt,
    double temperature = 0.7,
    int maxTokens = 512,
    double topP = 0.95,
    int topK = 40,
    double repeatPenalty = 1.1,
  }) async* {
    if (!isModelLoaded || _llamaController == null) {
      throw Exception('No model loaded');
    }

    _isGenerating = true;
    try {
      // Convert to ChatMessage format
      final chatMessages = <ChatMessage>[];
      
      // Add system prompt if provided
      if (systemPrompt != null && systemPrompt.isNotEmpty) {
        chatMessages.add(ChatMessage(role: 'system', content: systemPrompt));
      }
      
      // Add user/assistant messages
      for (final msg in messages) {
        chatMessages.add(ChatMessage(
          role: msg['role'] ?? 'user',
          content: msg['content'] ?? '',
        ));
      }

      await for (final token in _llamaController!.generateChat(
        messages: chatMessages,
        maxTokens: maxTokens,
        temperature: temperature,
        topP: topP,
        topK: topK,
        repeatPenalty: repeatPenalty,
      )) {
        yield token;
      }
    } finally {
      _isGenerating = false;
    }
  }

  /// Stop ongoing generation
  Future<void> stopGeneration() async {
    if (_llamaController != null && _isGenerating) {
      await _llamaController!.stop();
    }
    _isGenerating = false;
  }

  /// Build a chat prompt from messages using ChatML format
  /// Compatible with most instruction-tuned models
  String buildChatPrompt(List<Map<String, String>> messages, {String? systemPrompt}) {
    final buffer = StringBuffer();
    
    // Add system prompt if provided
    if (systemPrompt != null && systemPrompt.isNotEmpty) {
      buffer.write('<|im_start|>system\n');
      buffer.write(systemPrompt);
      buffer.write('<|im_end|>\n');
    }
    
    // Add messages using ChatML format
    for (final message in messages) {
      final role = message['role'] ?? 'user';
      final content = message['content'] ?? '';
      
      buffer.write('<|im_start|>$role\n');
      buffer.write(content);
      buffer.write('<|im_end|>\n');
    }
    
    // Add assistant prefix to prompt response
    buffer.write('<|im_start|>assistant\n');
    
    return buffer.toString();
  }

  /// Get total size of all downloaded models
  Future<int> getTotalDownloadedSize() async {
    try {
      final dir = await modelsDirectory;
      int totalSize = 0;
      
      await for (final entity in dir.list()) {
        if (entity is File && entity.path.endsWith('.gguf')) {
          totalSize += await entity.length();
        }
      }
      
      return totalSize;
    } catch (e) {
      print('Error calculating total size: $e');
      return 0;
    }
  }

  /// Format bytes to human-readable string
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(0)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
