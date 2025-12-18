import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:html/parser.dart' as html_parser;
import 'package:http/http.dart' as http;
import '../models/app_settings.dart';
import '../models/message.dart';
import '../models/stream_chunk.dart';
import 'local_model_service.dart';

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

  // OpenRouter - Get All Models
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
        
        return models.map<Map<String, dynamic>>((m) {
          final pricing = m['pricing'];
          final promptPrice = double.tryParse(pricing?['prompt']?.toString() ?? '1') ?? 1.0;
          final completionPrice = double.tryParse(pricing?['completion']?.toString() ?? '1') ?? 1.0;
          final isFree = promptPrice == 0 && completionPrice == 0;

          return {
            'id': m['id'] as String,
            'name': m['name'] as String? ?? m['id'],
            'context_length': m['context_length'] ?? 4096,
            'is_free': isFree,
            'prompt_price': promptPrice,
            'completion_price': completionPrice,
            'description': m['description'] ?? '',
          };
        }).toList();
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

  // OpenRouter - Get API Key Info (usage, limits, tier)
  Future<Map<String, dynamic>> getOpenRouterKeyInfo() async {
    try {
      final response = await http.get(
        Uri.parse('$openRouterBaseUrl/key'),
        headers: {
          'Authorization': 'Bearer ${settings.openRouterApiKey}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] as Map<String, dynamic>;
      } else if (response.statusCode == 401) {
        throw Exception('Invalid API key');
      } else {
        throw Exception('Failed to load key info: ${response.statusCode}');
      }
    } catch (e) {
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
    } else if (settings.apiProvider == ApiProvider.localModel) {
      yield* _localModelChatStream(
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

  // Local Model (On-Device) - Chat Completion Stream using flutter_llama
  Stream<StreamChunk> _localModelChatStream({
    required List<Message> messages,
    List<String>? searchResults,
    String? systemPrompt,
  }) async* {
    final localModelService = LocalModelService();
    
    if (!localModelService.isModelLoaded) {
      yield StreamChunk(content: "Error: No local model loaded. Go to Settings > On-Device > Manage Local Models to download and load a model.");
      yield StreamChunk(isDone: true);
      return;
    }
    
    try {
      // Build system prompt
      String systemContent = systemPrompt ?? "You are a helpful AI assistant.";
      if (searchResults != null && searchResults.isNotEmpty) {
        systemContent += "\n\nUse the following search results to answer the user's question:\n${searchResults.join('\n\n')}";
      }
      
      // Convert messages to simple format for prompt building
      final messageList = <Map<String, String>>[];
      
      // Use last 10 messages for context (local models have limited context)
      var contextMessages = messages;
      if (messages.length > 10) {
        contextMessages = messages.sublist(messages.length - 10);
      }
      
      for (var msg in contextMessages) {
        if (msg.role != MessageRole.system) {
          messageList.add({
            'role': msg.role.toString().split('.').last,
            'content': msg.content,
          });
        }
      }
      
      // Build the prompt using ChatML format
      final prompt = localModelService.buildChatPrompt(
        messageList,
        systemPrompt: systemContent,
      );
      
      // Stream tokens from local model
      await for (final token in localModelService.generateStream(
        prompt,
        maxTokens: settings.localModelContextSize ~/ 2, // Leave room for context
      )) {
        yield StreamChunk(content: token);
      }
      
      yield StreamChunk(isDone: true);
    } catch (e) {
      yield StreamChunk(content: "Error: $e");
      yield StreamChunk(isDone: true);
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
    // For local models, use simple fallback (generating titles would be slow)
    if (settings.apiProvider == ApiProvider.localModel) {
      return content.length > 30 ? '${content.substring(0, 30)}...' : content;
    } else if (settings.apiProvider == ApiProvider.openRouter) {
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
    // For local models, just return the current prompt (enhancement would be too slow)
    if (settings.apiProvider == ApiProvider.localModel) {
      return currentPrompt;
    } else if (settings.apiProvider == ApiProvider.openRouter) {
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
  // Scan for LM Studio
  static Future<List<String>> scanLmStudioNetwork({
    void Function(String status)? onProgress,
    void Function(String url)? onServerFound,
  }) async {
    final foundServers = <String>[];
    const port = 1234; // LM Studio default port
    const timeout = Duration(milliseconds: 800);
    
    final patterns = [
      '192.168.1.',
      '192.168.0.',
      '10.0.0.',
      '172.16.0.',
    ];
    
    final localUrls = [
      'http://localhost:$port',
      'http://127.0.0.1:$port',
      'http://10.0.2.2:$port', // Android Emulator
    ];
    
    onProgress?.call('Checking localhost...');
    for (var url in localUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/v1/models'),
        ).timeout(timeout);
        if (response.statusCode == 200) {
          foundServers.add(url);
          onServerFound?.call(url);
        }
      } catch (_) {}
    }
    
    // Scan network ranges
    for (var pattern in patterns) {
      onProgress?.call('Scanning $pattern*...');
      
      final futures = <Future<void>>[];
      
      for (var i = 1; i <= 254; i++) {
        final ip = '$pattern$i';
        final url = 'http://$ip:$port';
        
        futures.add((() async {
          try {
            final response = await http.get(
              Uri.parse('$url/v1/models'),
            ).timeout(timeout);
            if (response.statusCode == 200) {
              foundServers.add(url);
              onServerFound?.call(url);
            }
          } catch (_) {}
        })());
      }
      
      final batchSize = 50;
      for (var i = 0; i < futures.length; i += batchSize) {
        final batch = futures.skip(i).take(batchSize).toList();
        await Future.wait(batch);
      }
    }
    
    onProgress?.call('Scan complete');
    return foundServers;
  }

  // Scan for SearXNG
  static Future<List<String>> scanSearxngNetwork({
    void Function(String status)? onProgress,
    void Function(String url)? onServerFound,
  }) async {
    final foundServers = <String>[];
    const ports = [8080, 8081]; 
    const timeout = Duration(milliseconds: 2000); 
    
    // Get local subnets dynamically
    final subnets = <String>{};
    
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, 
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        for (var addr in interface.addresses) {
            if (!addr.isLoopback) {
                final parts = addr.address.split('.');
                if (parts.length == 4) {
                    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
                    subnets.add(subnet);
                }
            }
        }
      }
    } catch (e) {
      print("DEBUG: Error getting network interfaces: $e");
    }

    if (subnets.isEmpty) {
        subnets.addAll([
          '192.168.1.',
          '192.168.0.',
          '10.0.0.',
          '172.16.0.',
        ]);
    }
    
    final localUrls = [
      for (var port in ports) ...[
        'http://localhost:$port', 
        'http://127.0.0.1:$port',
        'http://10.0.2.2:$port',
        'http://10.0.3.2:$port',
      ]
    ];
    
    onProgress?.call('Checking localhost...');
    for (var url in localUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/search?q=test&format=json'),
        ).timeout(timeout);
        if (response.statusCode == 200) {
          foundServers.add(url);
          onServerFound?.call(url);
        }
      } catch (_) {}
    }
    
    for (var subnet in subnets) {
      onProgress?.call('Scanning $subnet*...');
      
      final futures = <Future<void>>[];
      
      for (var i = 1; i <= 254; i++) {
        final ip = '$subnet$i';
        
        for (var port in ports) {
             final url = 'http://$ip:$port';
             futures.add((() async {
              try {
                final response = await http.get(
                  Uri.parse('$url/search?q=test&format=json'),
                ).timeout(timeout);
                if (response.statusCode == 200) {
                  foundServers.add(url);
                  onServerFound?.call(url);
                }
              } catch (_) {}
            })());
        }
      }
      
      final batchSize = 25;
      for (var i = 0; i < futures.length; i += batchSize) {
        final batch = futures.skip(i).take(batchSize).toList();
        await Future.wait(batch);
      }
    }
    
    onProgress?.call('Scan complete');
    return foundServers;
  }

  Future<String> scrapeUrl(String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final document = html_parser.parse(response.body);
        
        // Remove scripts, styles, and other non-text elements
        document.querySelectorAll('script, style, noscript, iframe, head, footer, nav, aside').forEach((e) => e.remove());
        
        // Extract text from paragraphs and significant tags
        final elements = document.querySelectorAll('p, h1, h2, h3, h4, li, article');
        final textParts = elements.map((e) => e.text.trim()).where((t) => t.isNotEmpty).toList();
        
        final combinedText = textParts.join('\n\n');
        
        // Limit text length to avoid context overflow (approx 12k tokens max)
        if (combinedText.length > 30000) {
          return '${combinedText.substring(0, 30000)}... [Content Truncated]';
        }
        return combinedText;
      }
      return "Failed to load page: ${response.statusCode}";
    } catch (e) {
      print('DEBUG: Scraping failed for $url: $e');
      return "Error scraping URL: $e";
    }
  }
}

