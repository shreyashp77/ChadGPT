import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/message.dart';
import '../models/stream_chunk.dart';

class ApiService {
  final AppSettings settings;

  static const String openRouterBaseUrl = 'https://openrouter.ai/api/v1';

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
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('SocketException')) {
        throw Exception('Connection Refused: Ensure LM Studio is running and reachable at ${settings.lmStudioUrl}');
      }
      throw Exception('Failed to connect to LM Studio: $e');
    }
  }

  // OpenRouter - Get Free Models
  Future<List<Map<String, dynamic>>> getOpenRouterModels() async {
    try {
      final response = await http.get(
        Uri.parse('$openRouterBaseUrl/models'),
        headers: {
          'Authorization': 'Bearer ${settings.openRouterApiKey}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> models = data['data'];
        
        // Filter for free models (pricing.prompt == "0" and pricing.completion == "0")
        final freeModels = models.where((m) {
          final pricing = m['pricing'];
          if (pricing == null) return false;
          final promptPrice = pricing['prompt']?.toString() ?? '1';
          final completionPrice = pricing['completion']?.toString() ?? '1';
          return promptPrice == '0' && completionPrice == '0';
        }).map<Map<String, dynamic>>((m) {
          return {
            'id': m['id'] as String,
            'name': m['name'] as String? ?? m['id'],
            'context_length': m['context_length'] ?? 4096,
          };
        }).toList();
        
        return freeModels;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      } else {
        throw Exception('Failed to load models: ${response.statusCode}');
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('SocketException')) {
         throw Exception('Connection Failed: Could not reach OpenRouter. Check your internet connection.');
      }
      throw Exception('Failed to connect to OpenRouter: $e');
    }
  }

  // SearXNG - Check Connection (Head Request or Simple Search)
  Future<bool> checkSearxngConnection() async {
      try {
          // Normalize URL
          var url = settings.searxngUrl.trim();
          if (url.endsWith('/')) {
              url = url.substring(0, url.length - 1);
          }

          // Just fetching the base URL or a simple search to see if it responds
          // We use format=json because that's what the app relies on.
          final uri = Uri.parse('$url/search?q=test&format=json');
          
          print('DEBUG: Checking SearXNG at $uri');
          final response = await http.get(uri).timeout(const Duration(seconds: 5));
          print('DEBUG: SearXNG Check Status: ${response.statusCode}');
          
          return response.statusCode == 200;
      } catch (e) {
          print('DEBUG: SearXNG Check Failed: $e');
          return false;
      }
  }

  // Web Search - Routes to appropriate provider
  Future<List<String>> searchWeb(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      switch (settings.searchProvider) {
        case SearchProvider.brave:
          return _searchBrave(query);
        case SearchProvider.bing:
          return _searchBing(query);
        case SearchProvider.google:
          return _searchGoogle(query);
        case SearchProvider.perplexity:
          return _searchPerplexity(query);
        case SearchProvider.none:
          return [];
        case SearchProvider.searxng:
        default:
          return _searchSearxng(query);
      }
    } catch (e) {
      print('DEBUG: Search failed: $e');
      return ["Error performing search: $e"];
    }
  }

  // SearXNG Search
  Future<List<String>> _searchSearxng(String query) async {
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
      }
      return [];
    } catch (e) {
      print('SearXNG error: $e');
      return [];
    }
  }

  // Brave Search
  Future<List<String>> _searchBrave(String query) async {
    if (settings.braveApiKey == null || settings.braveApiKey!.isEmpty) {
      return ["Error: Brave API key not configured"];
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.search.brave.com/res/v1/web/search').replace(queryParameters: {
          'q': query,
          'count': '5',
        }),
        headers: {
          'X-Subscription-Token': settings.braveApiKey!,
          'Accept': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['web']['results'] ?? [];
        
        return results.map((r) => 
          "Title: ${r['title']}\nSnippet: ${r['description']}\nURL: ${r['url']}"
        ).toList();
      }
      return ["Error: Brave search failed (${response.statusCode})"];
    } catch (e) {
       return ["Error: $e"];
    }
  }

  // Bing Search
  Future<List<String>> _searchBing(String query) async {
    if (settings.bingApiKey == null || settings.bingApiKey!.isEmpty) {
      return ["Error: Bing API key not configured"];
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.bing.microsoft.com/v7.0/search').replace(queryParameters: {
          'q': query,
          'count': '5',
        }),
        headers: {
          'Ocp-Apim-Subscription-Key': settings.bingApiKey!,
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['webPages']['value'] ?? [];
        
        return results.map((r) => 
          "Title: ${r['name']}\nSnippet: ${r['snippet']}\nURL: ${r['url']}"
        ).toList();
      }
      return ["Error: Bing search failed (${response.statusCode})"];
    } catch (e) {
      return ["Error: $e"];
    }
  }

  // Google Search
  Future<List<String>> _searchGoogle(String query) async {
    if (settings.googleApiKey == null || settings.googleApiKey!.isEmpty || 
        settings.googleCx == null || settings.googleCx!.isEmpty) {
      return ["Error: Google API key or CX not configured"];
    }

    try {
      final response = await http.get(
        Uri.parse('https://www.googleapis.com/customsearch/v1').replace(queryParameters: {
          'key': settings.googleApiKey,
          'cx': settings.googleCx,
          'q': query,
          'num': '5',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> results = data['items'] ?? [];
        
        return results.map((r) => 
          "Title: ${r['title']}\nSnippet: ${r['snippet']}\nURL: ${r['link']}"
        ).toList();
      }
      return ["Error: Google search failed (${response.statusCode})"];
    } catch (e) {
      return ["Error: $e"];
    }
  }

  // Perplexity AI (Sonar)
  Future<List<String>> _searchPerplexity(String query) async {
    if (settings.perplexityApiKey == null || settings.perplexityApiKey!.isEmpty) {
      return ["Error: Perplexity API key not configured"];
    }

    try {
      final response = await http.post(
        Uri.parse('https://api.perplexity.ai/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.perplexityApiKey}',
        },
        body: jsonEncode({
          'model': 'sonar-pro', // Using a search-capable model
          'messages': [
             {'role': 'system', 'content': 'You are a search engine. Provide a concise summary of the latest information about the user query. Include key facts and sources.'},
             {'role': 'user', 'content': query}
          ],
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
         final data = jsonDecode(response.body);
         final content = data['choices'][0]['message']['content'];
         // Perplexity returns a synthesized answer. We wrap it as a "result".
         return ["Source: Perplexity AI\nContent: $content"];
      }
      return ["Error: Perplexity request failed (${response.statusCode})"];
    } catch (e) {
      return ["Error: $e"];
    }
  }

  // Chat Completion Stream - Routes to appropriate provider
  // Returns StreamChunk objects containing content and token usage
  Stream<StreamChunk> chatCompletionStream({
    required String modelId,
    required List<Message> messages,
    List<String>? searchResults,
    String? systemPrompt,
  }) async* {
    if (settings.apiProvider == ApiProvider.openRouter) {
      yield* _openRouterChatStream(
        modelId: modelId,
        messages: messages,
        searchResults: searchResults,
        systemPrompt: systemPrompt,
      );
    } else {
      yield* _lmStudioChatStream(
        modelId: modelId,
        messages: messages,
        searchResults: searchResults,
        systemPrompt: systemPrompt,
      );
    }
  }

  // LM Studio - Chat Completion Stream
  Stream<StreamChunk> _lmStudioChatStream({
    required String modelId,
    required List<Message> messages,
    List<String>? searchResults,
    String? systemPrompt,
  }) async* {
    
    // Construct messages payload.
    final List<Map<String, dynamic>> apiMessages = [];
    
    // System message
    String systemContent = systemPrompt ?? "You are a helpful AI assistant.";
    if (searchResults != null && searchResults.isNotEmpty) {
      systemContent += "\n\nUse the following search results to answer the user's question:\n${searchResults.join('\n\n')}";
    }
    
    apiMessages.add({'role': 'system', 'content': systemContent});

    // Chat history - Sliding Window
    var contextMessages = messages;
    if (messages.length > 20) {
      contextMessages = messages.sublist(messages.length - 20);
    }

    for (var msg in contextMessages) {
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
                
                msgMap['content'] = [
                  {'type': 'text', 'text': msg.content},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image'
                    }
                  }
                ];
              }
            } catch (e) {
               print("Error reading image: $e");
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
      'stream_options': {'include_usage': true}, // Request token usage
      'temperature': 0.7, 
      'seed': Random().nextInt(1000000),
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              yield StreamChunk(isDone: true);
              break;
            }
            
            try {
              final json = jsonDecode(data);
              
              // Check for content
              final content = json['choices']?[0]?['delta']?['content'];
              
              // Check for usage (comes in final chunk)
              final usage = json['usage'];
              
              if (content != null || usage != null) {
                yield StreamChunk(
                  content: content,
                  promptTokens: usage?['prompt_tokens'],
                  completionTokens: usage?['completion_tokens'],
                );
              }
            } catch (e) {
              // Ignore parse errors for partial chunks
            }
          }
        }
      }
    } catch (e) {
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('SocketException')) {
        yield StreamChunk(content: "Error: Connection Refused. Check if LM Studio is running at ${settings.lmStudioUrl}");
      } else {
        yield StreamChunk(content: "Error: $e");
      }
    } finally {
      client.close();
    }
  }

  // OpenRouter - Chat Completion Stream
  Stream<StreamChunk> _openRouterChatStream({
    required String modelId,
    required List<Message> messages,
    List<String>? searchResults,
    String? systemPrompt,
  }) async* {
    
    final List<Map<String, dynamic>> apiMessages = [];
    
    // System message
    String systemContent = systemPrompt ?? "You are a helpful AI assistant.";
    if (searchResults != null && searchResults.isNotEmpty) {
      systemContent += "\n\nUse the following search results to answer the user's question:\n${searchResults.join('\n\n')}";
    }
    
    apiMessages.add({'role': 'system', 'content': systemContent});

    // Chat history - Sliding Window
    var contextMessages = messages;
    if (messages.length > 20) {
      contextMessages = messages.sublist(messages.length - 20);
    }

    for (var msg in contextMessages) {
       if (msg.role != MessageRole.system) {
         Map<String, dynamic> msgMap = {
           'role': msg.role.toString().split('.').last,
           'content': msg.content,
         };
         
         // Handle Image Attachments for vision models
         if (msg.attachmentPath != null && msg.attachmentType == 'image') {
            try {
              final file = File(msg.attachmentPath!);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                final base64Image = base64Encode(bytes);
                
                msgMap['content'] = [
                  {'type': 'text', 'text': msg.content},
                  {
                    'type': 'image_url',
                    'image_url': {
                      'url': 'data:image/jpeg;base64,$base64Image'
                    }
                  }
                ];
              }
            } catch (e) {
               print("Error reading image: $e");
            }
         }
         
         apiMessages.add(msgMap);
       }
    }
    
    final request = http.Request('POST', Uri.parse('$openRouterBaseUrl/chat/completions'));
    request.headers['Content-Type'] = 'application/json';
    request.headers['Authorization'] = 'Bearer ${settings.openRouterApiKey}';
    request.headers['HTTP-Referer'] = 'https://chadgpt.app';
    request.headers['X-Title'] = 'ChadGPT';
    request.body = jsonEncode({
      'model': modelId,
      'messages': apiMessages,
      'stream': true,
      'include_usage': true, // OpenRouter supports this parameter
    });

    final client = http.Client();
    try {
      final streamedResponse = await client.send(request);
      
      print("DEBUG: OpenRouter response status: ${streamedResponse.statusCode}");

      if (streamedResponse.statusCode == 401) {
        yield StreamChunk(content: "Error: Invalid API key");
        return;
      }
      
      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        print("DEBUG: OpenRouter error body: $body");
        yield StreamChunk(content: "Error: API returned status ${streamedResponse.statusCode}");
        return;
      }

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.startsWith('data: ')) {
            final data = line.substring(6);
            if (data == '[DONE]') {
              yield StreamChunk(isDone: true);
              break;
            }
            
            try {
              final json = jsonDecode(data);
              
              // Check for content
              final content = json['choices']?[0]?['delta']?['content'];
              
              // Check for usage
              final usage = json['usage'];
              
              if (content != null || usage != null) {
                yield StreamChunk(
                  content: content,
                  promptTokens: usage?['prompt_tokens'],
                  completionTokens: usage?['completion_tokens'],
                );
              }
            } catch (e) {
              // Ignore parse errors for partial chunks
            }
          }
        }
      }
    } catch (e) {
      print("DEBUG: OpenRouter exception: $e");
      final errorStr = e.toString();
      if (errorStr.contains('Connection refused') || errorStr.contains('SocketException')) {
        yield StreamChunk(content: "Error: Connection Failed. Could not reach OpenRouter. Check your internet connection.");
      } else {
        yield StreamChunk(content: "Error: $e");
      }
    } finally {
      client.close();
    }
  }

  // Generate Chat Title - Routes to appropriate provider
  Future<String> generateTitle(String content, String modelId) async {
    if (settings.apiProvider == ApiProvider.openRouter) {
      return _generateTitleOpenRouter(content, modelId);
    } else {
      return _generateTitleLmStudio(content, modelId);
    }
  }

  // LM Studio - Generate Title
  Future<String> _generateTitleLmStudio(String content, String modelId) async {
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

  // OpenRouter - Generate Title
  Future<String> _generateTitleOpenRouter(String content, String modelId) async {
    try {
      final response = await http.post(
        Uri.parse('$openRouterBaseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.openRouterApiKey}',
          'HTTP-Referer': 'https://chadgpt.app',
          'X-Title': 'ChadGPT',
        },
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
        return title.replaceAll('"', '').replaceAll("'", '').replaceAll('.', ''); 
      }
    } catch (e) {
      // Fallback
    }
    return content.length > 30 ? '${content.substring(0, 30)}...' : content;
  }

  // Enhance System Prompt - Routes to appropriate provider
  Future<String> enhancePrompt(String name, String description, String currentPrompt, String modelId) async {
    if (settings.apiProvider == ApiProvider.openRouter) {
      return _enhancePromptOpenRouter(name, description, currentPrompt, modelId);
    } else {
      return _enhancePromptLmStudio(name, description, currentPrompt, modelId);
    }
  }

  // LM Studio - Enhance Prompt
  Future<String> _enhancePromptLmStudio(String name, String description, String currentPrompt, String modelId) async {
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

  // OpenRouter - Enhance Prompt
  Future<String> _enhancePromptOpenRouter(String name, String description, String currentPrompt, String modelId) async {
    try {
      final prompt = '''
You are an expert prompt engineer. Your goal is to rewrite the system prompt for an AI persona to make it more effective, detailed, and robust.

Persona Name: $name
Description: $description
Draft Prompt: $currentPrompt

Return ONLY the improved system prompt. Do not add any conversational filler, explanations, or quotes. Just the raw prompt text.
''';

      final response = await http.post(
        Uri.parse('$openRouterBaseUrl/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${settings.openRouterApiKey}',
          'HTTP-Referer': 'https://chadgpt.app',
          'X-Title': 'ChadGPT',
        },
        body: jsonEncode({
          'model': modelId,
          'messages': [
            {'role': 'system', 'content': 'You are a helpful assistant.'},
            {'role': 'user', 'content': prompt}
          ],
          'stream': false,
          'max_tokens': 500,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final enhanced = data['choices'][0]['message']['content'].toString().trim();
        return enhanced;
      } else {
        throw Exception('Failed to enhance prompt: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      throw Exception('Failed to enhance prompt: $e');
    }
  }
}

