import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';
import 'secure_storage_service.dart';

class SharedPrefsService {
  static const String keyLmStudioUrl = 'lm_studio_url';
  static const String keySearxngUrl = 'searxng_url';
  static const String keyIsDarkMode = 'is_dark_mode';
  static const String keySelectedModelId = 'selected_model_id';
  static const String keyUseWebSearch = 'use_web_search';
  static const String keyThemeColor = 'theme_color';
  static const String keyModelAliases = 'model_aliases';
  static const String keyApiProvider = 'api_provider';
  static const String keyOpenRouterApiKey = 'openrouter_api_key';
  static const String keyOpenRouterApiKeyHistory = 'openrouter_api_key_history';
  
  // Search Provider Keys
  static const String keySearchProvider = 'search_provider';
  static const String keyBraveApiKey = 'brave_api_key';
  static const String keyBingApiKey = 'bing_api_key';
  static const String keyGoogleApiKey = 'google_api_key';
  static const String keyGoogleCx = 'google_cx';
  static const String keyPerplexityApiKey = 'perplexity_api_key';
  
  // ComfyUI Keys
  static const String keyComfyuiUrl = 'comfyui_url';

  // Local Model Keys (On-Device Inference)
  static const String keySelectedLocalModelId = 'selected_local_model_id';
  static const String keyLocalModelGpuLayers = 'local_model_gpu_layers';
  static const String keyLocalModelContextSize = 'local_model_context_size';

  // First Run Key
  static const String keyIsFirstRun = 'is_first_run';

  final _secureStorage = SecureStorageService();

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    Map<String, String> aliases = {};
    if (prefs.containsKey(keyModelAliases)) {
        try {
            final jsonStr = prefs.getString(keyModelAliases);
            if (jsonStr != null) {
                aliases = Map<String, String>.from(json.decode(jsonStr));
            }
        } catch (_) {}
    }

    // Parse Search Provider
    SearchProvider searchProvider = SearchProvider.searxng;
    // Parse API provider
    ApiProvider apiProvider = ApiProvider.lmStudio;
    if (prefs.containsKey(keyApiProvider)) {
      final providerStr = prefs.getString(keyApiProvider);
      if (providerStr == 'openRouter') {
        apiProvider = ApiProvider.openRouter;
      } else if (providerStr == 'localModel') {
        apiProvider = ApiProvider.localModel;
      }
    }

    // Parse Search Provider
    if (prefs.containsKey(keySearchProvider)) {
      final searchStr = prefs.getString(keySearchProvider);
      searchProvider = SearchProvider.values.firstWhere(
        (e) => e.toString().split('.').last == searchStr,
        orElse: () => SearchProvider.searxng,
      );
    }

    return AppSettings(
      lmStudioUrl: prefs.getString(keyLmStudioUrl) ?? AppConstants.defaultLmStudioUrl,
      searxngUrl: prefs.getString(keySearxngUrl) ?? AppConstants.defaultSearxngUrl,
      isDarkMode: prefs.getBool(keyIsDarkMode) ?? true,
      selectedModelId: prefs.getString(keySelectedModelId),
      useWebSearch: prefs.getBool(keyUseWebSearch) ?? false,
      themeColor: prefs.getInt(keyThemeColor),
      modelAliases: aliases,
      apiProvider: apiProvider,
      openRouterApiKey: await _getSecureKey(prefs, keyOpenRouterApiKey),
      openRouterApiKeys: await _getSecureList(keyOpenRouterApiKeyHistory),
      searchProvider: searchProvider,
      braveApiKey: await _getSecureKey(prefs, keyBraveApiKey),
      bingApiKey: await _getSecureKey(prefs, keyBingApiKey),
      googleApiKey: await _getSecureKey(prefs, keyGoogleApiKey),
      googleCx: prefs.getString(keyGoogleCx),
      perplexityApiKey: await _getSecureKey(prefs, keyPerplexityApiKey),
      comfyuiUrl: prefs.getString(keyComfyuiUrl),
      selectedLocalModelId: prefs.getString(keySelectedLocalModelId),
      localModelGpuLayers: prefs.getInt(keyLocalModelGpuLayers) ?? 0,
      localModelContextSize: prefs.getInt(keyLocalModelContextSize) ?? 2048,
    );
  }

  // Helper to migrate or read secure key
  Future<String?> _getSecureKey(SharedPreferences prefs, String key) async {
    // 1. Try Secure Storage
    final secureVal = await _secureStorage.readProtected(key);
    if (secureVal != null) return secureVal;

    // 2. Fallback to SharedPrefs (Migration)
    if (prefs.containsKey(key)) {
      final oldVal = prefs.getString(key);
      if (oldVal != null && oldVal.isNotEmpty) {
        await _secureStorage.writeProtected(key, oldVal);
        await prefs.remove(key); // Remove from insecure storage
        return oldVal;
      }
    }
    return null;
  }

  Future<List<String>> _getSecureList(String key) async {
    final jsonStr = await _secureStorage.readProtected(key);
    if (jsonStr != null && jsonStr.isNotEmpty) {
      try {
        return List<String>.from(json.decode(jsonStr));
      } catch (_) {}
    }
    return [];
  }

  Future<void> _saveSecureList(String key, List<String> list) async {
    await _secureStorage.writeProtected(key, json.encode(list));
  }

  Future<void> saveSettings(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    
    await prefs.setString(keyLmStudioUrl, settings.lmStudioUrl);
    await prefs.setString(keySearxngUrl, settings.searxngUrl);
    await prefs.setBool(keyIsDarkMode, settings.isDarkMode);
    await prefs.setBool(keyUseWebSearch, settings.useWebSearch);
    
    if (settings.selectedModelId != null) {
      await prefs.setString(keySelectedModelId, settings.selectedModelId!);
    } else {
      await prefs.remove(keySelectedModelId);
    }

    if (settings.themeColor != null) {
        await prefs.setInt(keyThemeColor, settings.themeColor!);
    } else {
        await prefs.remove(keyThemeColor);
    }

    await prefs.setString(keyModelAliases, json.encode(settings.modelAliases));

    // Save API provider
    String providerStr = 'lmStudio';
    if (settings.apiProvider == ApiProvider.openRouter) {
      providerStr = 'openRouter';
    } else if (settings.apiProvider == ApiProvider.localModel) {
      providerStr = 'localModel';
    }
    await prefs.setString(keyApiProvider, providerStr);
    
    // Save OpenRouter API key (SECURE)
    await _secureStorage.writeProtected(keyOpenRouterApiKey, settings.openRouterApiKey);
    await _saveSecureList(keyOpenRouterApiKeyHistory, settings.openRouterApiKeys);

    // Save Search Settings
    await prefs.setString(keySearchProvider, settings.searchProvider.toString().split('.').last);

    // Secure Keys
    await _secureStorage.writeProtected(keyBraveApiKey, settings.braveApiKey);
    await _secureStorage.writeProtected(keyBingApiKey, settings.bingApiKey);
    await _secureStorage.writeProtected(keyGoogleApiKey, settings.googleApiKey);
    await prefs.setString(keyGoogleCx, settings.googleCx ?? ''); // CX is not secret
    await _secureStorage.writeProtected(keyPerplexityApiKey, settings.perplexityApiKey);

    // ComfyUI
    if (settings.comfyuiUrl != null && settings.comfyuiUrl!.isNotEmpty) {
      await prefs.setString(keyComfyuiUrl, settings.comfyuiUrl!);
    } else {
      await prefs.remove(keyComfyuiUrl);
    }

    // Local Model Settings
    if (settings.selectedLocalModelId != null && settings.selectedLocalModelId!.isNotEmpty) {
      await prefs.setString(keySelectedLocalModelId, settings.selectedLocalModelId!);
    } else {
      await prefs.remove(keySelectedLocalModelId);
    }
    await prefs.setInt(keyLocalModelGpuLayers, settings.localModelGpuLayers);
    await prefs.setInt(keyLocalModelContextSize, settings.localModelContextSize);
  }


  Future<bool> getIsFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.containsKey(keyIsFirstRun)) {
      return prefs.getBool(keyIsFirstRun)!;
    }
    // Migration: If we have existing settings, it's not a first run
    if (prefs.containsKey(keyLmStudioUrl) || prefs.containsKey(keyOpenRouterApiKey)) {
        await prefs.setBool(keyIsFirstRun, false);
        return false;
    }
    return true;
  }

  Future<void> setFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keyIsFirstRun, false);
  }
}

