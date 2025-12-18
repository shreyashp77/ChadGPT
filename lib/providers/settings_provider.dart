import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/shared_prefs_service.dart';
import '../services/api_service.dart';
import '../services/comfyui_service.dart';
import '../services/database_service.dart';
import '../services/secure_storage_service.dart';
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  final SharedPrefsService _prefsService = SharedPrefsService();
  late ApiService _apiService;
  AppSettings _settings = AppSettings(
    lmStudioUrl: AppConstants.defaultLmStudioUrl,
    searxngUrl: AppConstants.defaultSearxngUrl,
  );

  List<String> _availableModels = [];
  List<Map<String, dynamic>> _openRouterModels = []; // Store rich model data
  bool _isLoadingModels = false;
  
  // Model list caching
  DateTime? _lastModelFetch;
  static const _modelCacheTtl = Duration(minutes: 5);
  String? _error;
  bool _isSearxngConnected = false;
  bool _isOpenRouterConnected = false;
  bool _isComfyUiConnected = false;
  
  bool _isInitialized = false;
  bool _isFirstRun = true;
  Map<String, dynamic>? _openRouterKeyInfo;

  AppSettings get settings => _settings;
  List<String> get availableModels => _availableModels;
  List<Map<String, dynamic>> get openRouterModels => _openRouterModels;
  bool get isLoadingModels => _isLoadingModels;
  String? get error => _error;
  bool get isSearxngConnected => _isSearxngConnected;
  bool get isOpenRouterConnected => _isOpenRouterConnected;
  bool get isComfyUiConnected => _isComfyUiConnected;
  ApiService get apiService => _apiService;
  
  bool get isInitialized => _isInitialized;
  bool get isFirstRun => _isFirstRun;
  Map<String, dynamic>? get openRouterKeyInfo => _openRouterKeyInfo;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await _prefsService.getSettings();
    _isFirstRun = await _prefsService.getIsFirstRun();
    _apiService = ApiService(_settings);
    _isInitialized = true;
    notifyListeners();
    if (!_isFirstRun) {
      fetchModels();
    }
  }

  Future<void> completeSetup() async {
    await _prefsService.setFirstRunCompleted();
    _isFirstRun = false;
    notifyListeners();
    fetchModels();
  }

  Future<void> updateSettings({
    String? lmStudioUrl,
    String? searxngUrl,
    bool? isDarkMode,
    String? selectedModelId,
    bool? useWebSearch,
    int? themeColor,
    Map<String, String>? modelAliases,
    ApiProvider? apiProvider,
    String? openRouterApiKey,
    List<String>? openRouterApiKeys,
    Map<String, String>? openRouterApiKeyAliases,
    SearchProvider? searchProvider,
    String? braveApiKey,
    String? bingApiKey,
    String? googleApiKey,
    String? googleCx,
    String? perplexityApiKey,
    String? comfyuiUrl,
  }) async {
    _settings = _settings.copyWith(
      lmStudioUrl: lmStudioUrl,
      searxngUrl: searxngUrl,
      isDarkMode: isDarkMode,
      selectedModelId: selectedModelId,
      useWebSearch: useWebSearch,
      themeColor: themeColor,
      modelAliases: modelAliases,
      apiProvider: apiProvider,
      openRouterApiKey: openRouterApiKey,
      openRouterApiKeys: openRouterApiKeys,
      openRouterApiKeyAliases: openRouterApiKeyAliases,
      searchProvider: searchProvider,
      braveApiKey: braveApiKey,
      bingApiKey: bingApiKey,
      googleApiKey: googleApiKey,
      googleCx: googleCx,
      perplexityApiKey: perplexityApiKey,
      comfyuiUrl: comfyuiUrl,
    );
    
    // Update API service with new settings if URLs or provider changed
    if (lmStudioUrl != null || searxngUrl != null || apiProvider != null || openRouterApiKey != null) {
      _apiService = ApiService(_settings);
    }
    
    notifyListeners();
    await _prefsService.saveSettings(_settings);

    // If SearXNG URL changed, re-check connection immediately
    if (searxngUrl != null) {
         _apiService.checkSearxngConnection().then((value) {
            _isSearxngConnected = value;
            notifyListeners();
        });
    }

    // If ComfyUI URL changed, re-check connection
    if (comfyuiUrl != null) {
      checkComfyUiConnection();
    }

    // If LM Studio URL changed, refetch models
    if (lmStudioUrl != null && _settings.apiProvider == ApiProvider.lmStudio) {
      fetchModels();
    }

    // If switching provider, clear current model selection and refetch
    if (apiProvider != null) {
      _settings = _settings.copyWith(selectedModelId: null);
      await _prefsService.saveSettings(_settings);
      fetchModels();
    }
  }

  Future<void> updateModelAlias(String modelId, String alias) async {
      final newAliases = Map<String, String>.from(_settings.modelAliases);
      if (alias.trim().isEmpty) {
          newAliases.remove(modelId);
      } else {
          newAliases[modelId] = alias.trim();
      }
      await updateSettings(modelAliases: newAliases);
  }

  Future<void> addOpenRouterApiKeyToHistory(String key) async {
    if (key.trim().isEmpty) return;
    final cleanKey = key.trim();
    if (_settings.openRouterApiKeys.contains(cleanKey)) return;
    
    final newHistory = List<String>.from(_settings.openRouterApiKeys);
    newHistory.add(cleanKey);
    await updateSettings(openRouterApiKeys: newHistory);
  }

  Future<void> removeOpenRouterApiKeyFromHistory(String key) async {
    final newHistory = List<String>.from(_settings.openRouterApiKeys);
    newHistory.remove(key);
    final newAliases = Map<String, String>.from(_settings.openRouterApiKeyAliases);
    newAliases.remove(key);
    await updateSettings(openRouterApiKeys: newHistory, openRouterApiKeyAliases: newAliases);
  }

  Future<void> updateOpenRouterApiKeyAlias(String key, String alias) async {
    final newAliases = Map<String, String>.from(_settings.openRouterApiKeyAliases);
    if (alias.trim().isEmpty) {
      newAliases.remove(key);
    } else {
      newAliases[key] = alias.trim();
    }
    await updateSettings(openRouterApiKeyAliases: newAliases);
  }

  String getModelDisplayName(String modelId) {
      // Check aliases first
      if (_settings.modelAliases.containsKey(modelId)) {
        return _settings.modelAliases[modelId]!;
      }
      // For OpenRouter, try to get the name from our cached model data
      if (_settings.apiProvider == ApiProvider.openRouter) {
        final model = _openRouterModels.firstWhere(
          (m) => m['id'] == modelId,
          orElse: () => <String, dynamic>{},
        );
        if (model.isNotEmpty && model['name'] != null) {
          return model['name'] as String;
        }
      }
      return modelId.split('/').last;
  }

  Future<void> fetchModels({bool forceRefresh = false}) async {
    // Skip fetch if within TTL and not forced
    if (!forceRefresh && _lastModelFetch != null && _availableModels.isNotEmpty) {
      final elapsed = DateTime.now().difference(_lastModelFetch!);
      if (elapsed < _modelCacheTtl) {
        return; // Use cached models
      }
    }
    
    _isLoadingModels = true;
    _error = null;
    notifyListeners();

    // Check SearXNG in parallel
    _apiService.checkSearxngConnection().then((value) {
        _isSearxngConnected = value;
        notifyListeners();
    });
    
    // Check ComfyUI in parallel
    checkComfyUiConnection();

    try {
      if (_settings.apiProvider == ApiProvider.openRouter) {
        // Fetch OpenRouter models
        if (_settings.openRouterApiKey == null || _settings.openRouterApiKey!.isEmpty) {
          throw Exception('Please enter your OpenRouter API key');
        }
        _openRouterModels = await _apiService.getOpenRouterModels();
        _availableModels = _openRouterModels.map((m) => m['id'] as String).toList();
        _isOpenRouterConnected = true;
      } else {
        // Fetch LM Studio models
        _availableModels = await _apiService.getModels();
        _openRouterModels = [];
        _isOpenRouterConnected = false;
      }
      
      _lastModelFetch = DateTime.now(); // Update cache timestamp
      
      if (_settings.selectedModelId == null && _availableModels.isNotEmpty) {
        _settings = _settings.copyWith(selectedModelId: _availableModels.first);
        await _prefsService.saveSettings(_settings);
      }
    } catch (e) {
      _error = e.toString();
      if (_settings.apiProvider == ApiProvider.openRouter) {
        _isOpenRouterConnected = false;
      }
    } finally {
      _isLoadingModels = false;
      notifyListeners();
    }
  }


  Future<void> checkComfyUiConnection() async {
    if (_settings.comfyuiUrl == null || _settings.comfyuiUrl!.isEmpty) {
      _isComfyUiConnected = false;
      notifyListeners();
      return;
    }
    final service = ComfyuiService(_settings.comfyuiUrl!);
    _isComfyUiConnected = await service.checkConnection();
    notifyListeners();
  }

  Future<void> fetchOpenRouterKeyInfo() async {
    if (_settings.apiProvider != ApiProvider.openRouter || _settings.openRouterApiKey == null || _settings.openRouterApiKey!.isEmpty) {
      _openRouterKeyInfo = null;
      notifyListeners();
      return;
    }

    try {
      _openRouterKeyInfo = await _apiService.getOpenRouterKeyInfo();
      notifyListeners();
    } catch (e) {
      print('DEBUG: Failed to fetch OpenRouter key info: $e');
      _openRouterKeyInfo = null;
      notifyListeners();
    }
  }



  String exportSettingsJson() {
    final Map<String, dynamic> data = {
      'version': '1.0',
      'generatedAt': DateTime.now().toIso8601String(),
      'openRouterApiKey': _settings.openRouterApiKey,
      'openRouterApiKeys': _settings.openRouterApiKeys,
      'openRouterApiKeyAliases': _settings.openRouterApiKeyAliases,
      'braveApiKey': _settings.braveApiKey,
      'bingApiKey': _settings.bingApiKey,
      'googleApiKey': _settings.googleApiKey,
      'googleCx': _settings.googleCx,
      'perplexityApiKey': _settings.perplexityApiKey,
      'lmStudioUrl': _settings.lmStudioUrl,
      'searxngUrl': _settings.searxngUrl,
      'comfyuiUrl': _settings.comfyuiUrl,
      'apiProvider': _settings.apiProvider.toString().split('.').last,
      'searchProvider': _settings.searchProvider.toString().split('.').last,
      'isDarkMode': _settings.isDarkMode,
      'themeColor': _settings.themeColor,
      'useWebSearch': _settings.useWebSearch,
      'modelAliases': _settings.modelAliases,
      'selectedModelId': _settings.selectedModelId,
      'selectedLocalModelId': _settings.selectedLocalModelId,
      'localModelGpuLayers': _settings.localModelGpuLayers,
      'localModelContextSize': _settings.localModelContextSize,
    };
    return jsonEncode(data);
  }

  Future<bool> importSettingsJson(String jsonStr) async {
    try {
      final Map<String, dynamic> data = jsonDecode(jsonStr);
      
      // Basic validation
      if (!data.containsKey('openRouterApiKeys') && !data.containsKey('openRouterApiKey')) {
        return false;
      }

      // Parse Provider Enums
      ApiProvider? importedApiProvider;
      if (data.containsKey('apiProvider')) {
        importedApiProvider = ApiProvider.values.firstWhere(
          (e) => e.toString().split('.').last == data['apiProvider'],
          orElse: () => _settings.apiProvider,
        );
      }

      SearchProvider? importedSearchProvider;
      if (data.containsKey('searchProvider')) {
        importedSearchProvider = SearchProvider.values.firstWhere(
          (e) => e.toString().split('.').last == data['searchProvider'],
          orElse: () => _settings.searchProvider,
        );
      }

      _settings = _settings.copyWith(
        openRouterApiKey: data['openRouterApiKey'] as String?,
        openRouterApiKeys: data['openRouterApiKeys'] != null ? List<String>.from(data['openRouterApiKeys']) : null,
        openRouterApiKeyAliases: data['openRouterApiKeyAliases'] != null ? Map<String, String>.from(data['openRouterApiKeyAliases']) : null,
        braveApiKey: data['braveApiKey'] as String?,
        bingApiKey: data['bingApiKey'] as String?,
        googleApiKey: data['googleApiKey'] as String?,
        googleCx: data['googleCx'] as String?,
        perplexityApiKey: data['perplexityApiKey'] as String?,
        lmStudioUrl: data['lmStudioUrl'] as String?,
        searxngUrl: data['searxngUrl'] as String?,
        comfyuiUrl: data['comfyuiUrl'] as String?,
        apiProvider: importedApiProvider,
        searchProvider: importedSearchProvider,
        isDarkMode: data['isDarkMode'] as bool?,
        themeColor: data['themeColor'] as int?,
        useWebSearch: data['useWebSearch'] as bool?,
        modelAliases: data['modelAliases'] != null ? Map<String, String>.from(data['modelAliases']) : null,
        selectedModelId: data['selectedModelId'] as String?,
        selectedLocalModelId: data['selectedLocalModelId'] as String?,
        localModelGpuLayers: data['localModelGpuLayers'] as int?,
        localModelContextSize: data['localModelContextSize'] as int?,
      );

      // Re-initialize API service
      _apiService = ApiService(_settings);
      
      // Save everything
      await _prefsService.saveSettings(_settings);
      
      notifyListeners();
      fetchModels(forceRefresh: true);
      return true;
    } catch (e) {
      print('DEBUG: Failed to import settings: $e');
      return false;
    }
  }

  Future<void> clearAllData() async {
    await DatabaseService().clearAllData();
    await SecureStorageService().deleteAll();
    await _prefsService.setFirstRunCompleted(); // Technically resets everything but let's keep it safe
    // Ideally we should restart the app or reset internal state
    _settings = await _prefsService.getSettings(); // Reload defaults
    notifyListeners();
  }
}

