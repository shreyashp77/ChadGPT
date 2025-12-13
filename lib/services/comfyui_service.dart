import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

/// Service for interacting with ComfyUI server for image generation
class ComfyuiService {
  final String baseUrl;
  
  ComfyuiService(this.baseUrl);
  
  /// The workflow template with placeholders for the prompt
  static const Map<String, dynamic> _workflowTemplate = {
    "3": {
      "inputs": {
        "seed": 0, // Will be randomized
        "steps": 8,
        "cfg": 1,
        "sampler_name": "euler",
        "scheduler": "simple",
        "denoise": 1,
        "model": ["16", 0],
        "positive": ["6", 0],
        "negative": ["7", 0],
        "latent_image": ["13", 0]
      },
      "class_type": "KSampler",
      "_meta": {"title": "KSampler"}
    },
    "6": {
      "inputs": {
        "text": "", // Positive prompt - will be replaced
        "clip": ["18", 0]
      },
      "class_type": "CLIPTextEncode",
      "_meta": {"title": "CLIP Text Encode (Positive Prompt)"}
    },
    "7": {
      "inputs": {
        "text": "blurry ugly bad",
        "clip": ["18", 0]
      },
      "class_type": "CLIPTextEncode",
      "_meta": {"title": "CLIP Text Encode (Negative Prompt)"}
    },
    "8": {
      "inputs": {
        "samples": ["3", 0],
        "vae": ["17", 0]
      },
      "class_type": "VAEDecode",
      "_meta": {"title": "VAE Decode"}
    },
    "9": {
      "inputs": {
        "filename_prefix": "ChadGPT",
        "images": ["8", 0]
      },
      "class_type": "SaveImage",
      "_meta": {"title": "Save Image"}
    },
    "13": {
      "inputs": {
        "width": 1024,
        "height": 1024,
        "batch_size": 1
      },
      "class_type": "EmptySD3LatentImage",
      "_meta": {"title": "EmptySD3LatentImage"}
    },
    "16": {
      "inputs": {
        "unet_name": "z_image_turbo_bf16.safetensors",
        "weight_dtype": "default"
      },
      "class_type": "UNETLoader",
      "_meta": {"title": "Load Diffusion Model"}
    },
    "17": {
      "inputs": {
        "vae_name": "ae.safetensors"
      },
      "class_type": "VAELoader",
      "_meta": {"title": "Load VAE"}
    },
    "18": {
      "inputs": {
        "clip_name": "qwen_3_4b.safetensors",
        "type": "qwen_image",
        "device": "cpu"
      },
      "class_type": "CLIPLoader",
      "_meta": {"title": "Load CLIP"}
    }
  };

  /// Check if ComfyUI server is reachable
  Future<bool> checkConnection() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/system_stats'),
      ).timeout(const Duration(seconds: 5));
      return response.statusCode == 200;
    } catch (e) {
      print('ComfyUI connection check failed: $e');
      return false;
    }
  }

  /// Queue a prompt for image generation
  /// Returns the prompt_id for tracking progress
  Future<String> queuePrompt(String prompt) async {
    // Create workflow with the user's prompt
    final workflow = Map<String, dynamic>.from(_workflowTemplate);
    
    // Deep copy and update prompt
    workflow["6"] = Map<String, dynamic>.from(_workflowTemplate["6"]!);
    workflow["6"]["inputs"] = Map<String, dynamic>.from(_workflowTemplate["6"]!["inputs"]);
    workflow["6"]["inputs"]["text"] = prompt;
    
    // Randomize seed
    workflow["3"] = Map<String, dynamic>.from(_workflowTemplate["3"]!);
    workflow["3"]["inputs"] = Map<String, dynamic>.from(_workflowTemplate["3"]!["inputs"]);
    workflow["3"]["inputs"]["seed"] = DateTime.now().millisecondsSinceEpoch % 10000000000;
    
    final response = await http.post(
      Uri.parse('$baseUrl/prompt'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"prompt": workflow}),
    );
    
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['prompt_id'] as String;
    } else {
      throw Exception('Failed to queue prompt: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get the progress of a prompt
  /// Returns a map with 'status' ('pending', 'running', 'completed', 'error') and 'progress' (0.0-1.0)
  Future<Map<String, dynamic>> getProgress(String promptId) async {
    try {
      // Check queue status
      final queueResponse = await http.get(Uri.parse('$baseUrl/queue'));
      
      if (queueResponse.statusCode == 200) {
        final queueData = jsonDecode(queueResponse.body);
        final runningQueue = queueData['queue_running'] as List<dynamic>? ?? [];
        final pendingQueue = queueData['queue_pending'] as List<dynamic>? ?? [];
        
        // Check if still pending
        for (var item in pendingQueue) {
          if (item[1] == promptId) {
            return {'status': 'pending', 'progress': 0.0};
          }
        }
        
        // Check if running
        for (var item in runningQueue) {
          if (item[1] == promptId) {
            // Get more detailed progress
            final progressResponse = await http.get(Uri.parse('$baseUrl/progress'));
            if (progressResponse.statusCode == 200) {
              final progressData = jsonDecode(progressResponse.body);
              final value = progressData['value'] ?? 0;
              final max = progressData['max'] ?? 1;
              return {
                'status': 'running',
                'progress': max > 0 ? value / max : 0.0,
              };
            }
            return {'status': 'running', 'progress': 0.5};
          }
        }
        
        // Not in queue - check history for completion
        final historyResponse = await http.get(Uri.parse('$baseUrl/history/$promptId'));
        if (historyResponse.statusCode == 200) {
          final historyData = jsonDecode(historyResponse.body);
          if (historyData.containsKey(promptId)) {
            final promptHistory = historyData[promptId];
            final outputs = promptHistory['outputs'];
            
            // Check if node 9 (SaveImage) has output
            if (outputs != null && outputs['9'] != null) {
              final images = outputs['9']['images'] as List<dynamic>?;
              if (images != null && images.isNotEmpty) {
                return {
                  'status': 'completed',
                  'progress': 1.0,
                  'images': images,
                };
              }
            }
          }
        }
        
        return {'status': 'pending', 'progress': 0.0};
      }
    } catch (e) {
      print('Error getting progress: $e');
      return {'status': 'error', 'progress': 0.0, 'error': e.toString()};
    }
    
    return {'status': 'pending', 'progress': 0.0};
  }

  /// Get the URL for an image from ComfyUI output folder
  String getImageUrl(String filename, String subfolder, String type) {
    return '$baseUrl/view?filename=$filename&subfolder=$subfolder&type=$type';
  }

  /// Fetch image bytes from ComfyUI (full resolution, no compression)
  Future<Uint8List> fetchImage(String filename, {String subfolder = '', String type = 'output'}) async {
    final url = getImageUrl(filename, subfolder, type);
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      return response.bodyBytes;
    } else {
      throw Exception('Failed to fetch image: ${response.statusCode}');
    }
  }

  /// Delete an image from ComfyUI output folder
  Future<bool> deleteImage(String filename, {String subfolder = ''}) async {
    try {
      // ComfyUI doesn't have a built-in delete endpoint, but we can use the /api/delete endpoint if available
      // For now, we'll just return true and handle cleanup differently
      // A more robust solution would be to add a custom endpoint to ComfyUI
      final response = await http.post(
        Uri.parse('$baseUrl/api/delete'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'filename': filename,
          'subfolder': subfolder,
          'type': 'output',
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      print('Error deleting image: $e');
      return false;
    }
  }

  /// Delete multiple images from ComfyUI output folder
  Future<int> deleteImages(List<String> filenames) async {
    int deleted = 0;
    for (var filename in filenames) {
      if (await deleteImage(filename)) {
        deleted++;
      }
    }
    return deleted;
  }
}
