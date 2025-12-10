import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/message.dart';

class ApiService {
  final AppSettings settings;

  ApiService(this.settings);

  // LM Studio - Get Models
  Future<List<String>> getModels() async {
    try {
      final response = await http.get(Uri.parse('${settings.lmStudioUrl}/v1/models'));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['data'];
        return models.map<String>((m) => m['id'] as String).toList();
      } else {
        throw Exception('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to connect to LM Studio: $e');
    }
  }

  // SearXNG - Search
  Future<List<String>> searchWeb(String query) async {
    try {
      final uri = Uri.parse('${settings.searxngUrl}/search').replace(queryParameters: {
        'q': query,
        'format': 'json',
        'count': '5', 
      });

      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['results'] ?? [];
        
        return results.map((r) => 
          "Title: ${r['title']}\nSnippet: ${r['content']}\nURL: ${r['url']}"
        ).toList();
      } else {
        // Return empty list instead of throwing to allow chat to continue without search
        return []; 
      }
    } catch (e) {
      return []; 
    }
  }

  // LM Studio - Chat Completion Stream
  Stream<String> chatCompletionStream({
    required String modelId,
    required List<Message> messages,
    List<String>? searchResults,
    String? systemPrompt,
  }) async* {
    
    // Construct messages payload.
    // If search results exist, inject them into the system prompt or as a context message.
    final List<Map<String, dynamic>> apiMessages = [];
    
    // System message
    String systemContent = systemPrompt ?? "You are a helpful AI assistant.";
    if (searchResults != null && searchResults.isNotEmpty) {
      systemContent += "\n\nUse the following search results to answer the user's question:\n${searchResults.join('\n\n')}";
    }
    
    apiMessages.add({'role': 'system', 'content': systemContent});
    print('DEBUG: Sending System Prompt: $systemContent'); // Debug logging

    // Chat history
    // Sliding Window: Keep only the last 20 messages to manage context
    var contextMessages = messages;
    if (messages.length > 20) {
      contextMessages = messages.sublist(messages.length - 20);
    }

    for (var msg in contextMessages) {
       // Handle attachments if present (assuming base64 handling is done in Message model or logic before here)
       // For simplicity, we just send text for now, but will expand for attachments later.
       if (msg.role != MessageRole.system) {
         Map<String, dynamic> msgMap = {
           'role': msg.role.toString().split('.').last,
           'content': msg.content,
         };
         
         // Handle Image Attachments
         if (msg.attachmentPath != null && msg.attachmentType == 'image') {
            try {
              final file = File(msg.attachmentPath!);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final base64Image = base64Encode(bytes);
                
                // OpenAI Vision format
                msgMap['content'] = [
                  {'type': 'text', 'text': msg.content},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image' // Assuming jpeg for simplicity, or we check extension
                    }
                  }
                ];
              }
            } catch (e) {
               print("Error reading image: $e");
               // Fallback to text only if image read fails
            }
         }
         
         apiMessages.add(msgMap);
       }
    }
    
    final request = http.Request('POST', Uri.parse('${settings.lmStudioUrl}/v1/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.body = jsonEncode({
      'model': modelId,
      'messages': apiMessages,
      'stream': true,
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        // Process chunk (could be multiple data: lines)
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') break;
            
            try {
              final json = jsonDecode(data);
              final content = json['choices'][0]['delta']['content'];
              if (content != null) {
                yield content;
              }
            } catch (e) {
              // Ignore parse errors for partial chunks
            }
          }
        }
      }
    } catch (e) {
      yield "Error: $e";
    } finally {
      client.close();
    }
  }

  // Generate Chat Title
  Future<String> generateTitle(String content, String modelId) async {
    try {
      final response = await http.post(
        Uri.parse('${settings.lmStudioUrl}/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': modelId,
          'messages': [
            {'role': 'system', 'content': 'Generate a short, concise, and catchy chat title (max 6 words) based on the following usage message. Return ONLY the title text, nothing else.'},
            {'role': 'user', 'content': content}
          ],
          'stream': false,
          'max_tokens': 20,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final title = data['choices'][0]['message']['content'].toString().trim();
        // Remove quotes if present
        return title.replaceAll('"', '').replaceAll("'", '').replaceAll('.', ''); 
      }
    } catch (e) {
      // Fallback
    }
    // Default fallback
    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }

  // Enhance System Prompt
  Future<String> enhancePrompt(String name, String description, String currentPrompt, String modelId) async {
    print('DEBUG: Enhancing prompt with Model: $modelId');
    print('DEBUG: URL: ${settings.lmStudioUrl}/v1/chat/completions');
    
    try {
      final prompt = '''
You are an expert prompt engineer. Your goal is to rewrite the system prompt for an AI persona to make it more effective, detailed, and robust.

Persona Name: $name
Description: $description
Draft Prompt: $currentPrompt

Return ONLY the improved system prompt. Do not add any conversational filler, explanations, or quotes. Just the raw prompt text.
''';

      final body = jsonEncode({
          'model': modelId,
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant.'},
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
          'max_tokens': 500,
      });
      // print('DEBUG: Request Body: $body');

      final response = await http.post(
        Uri.parse('${settings.lmStudioUrl}/v1/chat/completions'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      print('DEBUG: Response Status: ${response.statusCode}');
      print('DEBUG: Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final enhanced = data['choices'][0]['message']['content'].toString().trim();
        return enhanced;
      } else {
        throw Exception('Failed to enhance prompt: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('DEBUG: Exception: $e');
      throw Exception('Failed to enhance prompt: $e');
    }
  }
}
