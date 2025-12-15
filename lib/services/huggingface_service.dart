import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/local_model.dart';

/// Service for interacting with the Hugging Face Hub API
/// to discover and fetch small GGUF models suitable for mobile inference
class HuggingFaceService {
  static const String _baseUrl = 'https://huggingface.co/api';
  static const String _downloadBaseUrl = 'https://huggingface.co';
  
  // Maximum file size for mobile models (1GB)
  static const int maxFileSizeBytes = 1024 * 1024 * 1024;
  
  // Curated list of mobile-friendly models (shown first)
  static final List<Map<String, dynamic>> _curatedModels = [
    {
      'repo_id': 'Qwen/Qwen2.5-0.5B-Instruct-GGUF',
      'name': 'Qwen 2.5 0.5B Instruct',
      'filename': 'qwen2.5-0.5b-instruct-q4_k_m.gguf',
      'size_bytes': 397000000,
      'parameters': 500000000,
      'quantization': 'Q4_K_M',
      'description': 'Very fast, good for basic tasks. 0.5B parameters.',
    },
    {
      'repo_id': 'TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF',
      'name': 'TinyLlama 1.1B Chat',
      'filename': 'tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf',
      'size_bytes': 669000000,
      'parameters': 1100000000,
      'quantization': 'Q4_K_M',
      'description': 'Fast and efficient for basic chat. 1.1B parameters.',
    },
    {
      'repo_id': 'HuggingFaceTB/SmolLM2-1.7B-Instruct-GGUF',
      'name': 'SmolLM2 1.7B Instruct',
      'filename': 'smollm2-1.7b-instruct-q4_k_m.gguf',
      'size_bytes': 1020000000,
      'parameters': 1700000000,
      'quantization': 'Q4_K_M',
      'description': 'HuggingFace\'s mobile-optimized model. 1.7B parameters.',
    },
    {
      'repo_id': 'Qwen/Qwen2.5-1.5B-Instruct-GGUF',
      'name': 'Qwen 2.5 1.5B Instruct',
      'filename': 'qwen2.5-1.5b-instruct-q4_k_m.gguf',
      'size_bytes': 986000000,
      'parameters': 1500000000,
      'quantization': 'Q4_K_M',
      'description': 'Strong reasoning for its size. 1.5B parameters.',
    },
    {
      'repo_id': 'microsoft/Phi-3-mini-4k-instruct-gguf',
      'name': 'Phi-3 Mini 4K',
      'filename': 'Phi-3-mini-4k-instruct-q4.gguf',
      'size_bytes': 2200000000,
      'parameters': 3800000000,
      'quantization': 'Q4',
      'description': 'Microsoft\'s capable small model. 3.8B parameters.',
    },
  ];

  /// Get curated list of mobile-friendly GGUF models
  List<LocalModel> getCuratedModels() {
    return _curatedModels.map((m) => LocalModel(
      id: '${m['repo_id']}/${m['filename']}',
      repoId: m['repo_id'] as String,
      name: m['name'] as String,
      filename: m['filename'] as String,
      sizeBytes: m['size_bytes'] as int,
      downloadUrl: '$_downloadBaseUrl/${m['repo_id']}/resolve/main/${m['filename']}',
      parameters: m['parameters'] as int?,
      quantization: m['quantization'] as String?,
      description: m['description'] as String?,
    )).toList();
  }

  /// Search for GGUF models on Hugging Face Hub
  /// Only returns models under the size limit
  Future<List<LocalModel>> searchModels(String query, {int limit = 20}) async {
    try {
      final uri = Uri.parse('$_baseUrl/models').replace(queryParameters: {
        'search': query,
        'library': 'gguf',
        'sort': 'downloads',
        'direction': '-1',
        'limit': limit.toString(),
      });

      final response = await http.get(uri);
      
      if (response.statusCode != 200) {
        throw Exception('Failed to search models: ${response.statusCode}');
      }

      final List<dynamic> data = json.decode(response.body);
      final models = <LocalModel>[];

      for (final model in data) {
        final repoId = model['id'] as String?;
        if (repoId == null) continue;

        // Fetch model files to find GGUF files
        final files = await _getModelFiles(repoId);
        for (final file in files) {
          if (file['size'] != null && file['size'] < maxFileSizeBytes) {
            models.add(LocalModel(
              id: '$repoId/${file['filename']}',
              repoId: repoId,
              name: _extractModelName(repoId),
              filename: file['filename'] as String,
              sizeBytes: file['size'] as int,
              downloadUrl: '$_downloadBaseUrl/$repoId/resolve/main/${file['filename']}',
              quantization: _extractQuantization(file['filename'] as String),
            ));
          }
        }
      }

      return models;
    } catch (e) {
      print('Error searching models: $e');
      return [];
    }
  }

  /// Fetch files for a specific model repository
  Future<List<Map<String, dynamic>>> _getModelFiles(String repoId) async {
    try {
      final uri = Uri.parse('$_baseUrl/models/$repoId');
      final response = await http.get(uri);
      
      if (response.statusCode != 200) {
        return [];
      }

      final data = json.decode(response.body);
      final siblings = data['siblings'] as List<dynamic>?;
      
      if (siblings == null) return [];

      return siblings
          .where((f) => (f['rfilename'] as String?)?.endsWith('.gguf') ?? false)
          .map((f) => {
            'filename': f['rfilename'] as String,
            'size': f['size'] as int?,
          })
          .where((f) => f['size'] != null)
          .toList();
    } catch (e) {
      print('Error fetching model files for $repoId: $e');
      return [];
    }
  }

  /// Extract a clean model name from the repo ID
  String _extractModelName(String repoId) {
    final parts = repoId.split('/');
    if (parts.length > 1) {
      return parts[1]
          .replaceAll('-GGUF', '')
          .replaceAll('-gguf', '')
          .replaceAll('_', ' ')
          .replaceAll('-', ' ');
    }
    return repoId;
  }

  /// Extract quantization type from filename
  String? _extractQuantization(String filename) {
    final patterns = [
      RegExp(r'[._-](Q[0-9]_K_[A-Z])', caseSensitive: false),
      RegExp(r'[._-](Q[0-9]_K)', caseSensitive: false),
      RegExp(r'[._-](Q[0-9])', caseSensitive: false),
      RegExp(r'[._-](q[0-9]_k_[a-z])', caseSensitive: false),
      RegExp(r'[._-](q[0-9]_k)', caseSensitive: false),
      RegExp(r'[._-](q[0-9])', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(filename);
      if (match != null) {
        return match.group(1)?.toUpperCase();
      }
    }
    return null;
  }

  /// Get direct download URL for a model file
  String getDownloadUrl(String repoId, String filename) {
    return '$_downloadBaseUrl/$repoId/resolve/main/$filename';
  }

  /// Check if a model file exists and get its size
  Future<int?> getFileSize(String repoId, String filename) async {
    try {
      final url = getDownloadUrl(repoId, filename);
      final response = await http.head(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final contentLength = response.headers['content-length'];
        if (contentLength != null) {
          return int.tryParse(contentLength);
        }
      }
      return null;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }
}
