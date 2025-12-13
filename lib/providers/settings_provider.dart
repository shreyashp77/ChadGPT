import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/shared_prefs_service.dart';
import '../services/api_service.dart';
import '../services/comfyui_service.dart';
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
  String? _error;
  bool _isSearxngConnected = false;
  bool _isOpenRouterConnected = false;
  bool _isComfyUiConnected = false;

  AppSettings get settings => _settings;
  List<String> get availableModels => _availableModels;
  List<Map<String, dynamic>> get openRouterModels => _openRouterModels;
  bool get isLoadingModels => _isLoadingModels;
  String? get error => _error;
  bool get isSearxngConnected => _isSearxngConnected;
  bool get isOpenRouterConnected => _isOpenRouterConnected;
  bool get isComfyUiConnected => _isComfyUiConnected;
  ApiService get apiService => _apiService;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _settings = await _prefsService.getSettings();
    _apiService = ApiService(_settings);
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

  Future<void> fetchModels() async {
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
}

