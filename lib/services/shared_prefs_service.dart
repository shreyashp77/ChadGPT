import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';

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
  
  // Search Provider Keys
  static const String keySearchProvider = 'search_provider';
  static const String keyBraveApiKey = 'brave_api_key';
  static const String keyBingApiKey = 'bing_api_key';
  static const String keyGoogleApiKey = 'google_api_key';
  static const String keyGoogleCx = 'google_cx';
  static const String keyPerplexityApiKey = 'perplexity_api_key';
  
  // ComfyUI Keys
  static const String keyComfyuiUrl = 'comfyui_url';

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
      openRouterApiKey: prefs.getString(keyOpenRouterApiKey),
      searchProvider: searchProvider,
      braveApiKey: prefs.getString(keyBraveApiKey),
      bingApiKey: prefs.getString(keyBingApiKey),
      googleApiKey: prefs.getString(keyGoogleApiKey),
      googleCx: prefs.getString(keyGoogleCx),
      perplexityApiKey: prefs.getString(keyPerplexityApiKey),
      comfyuiUrl: prefs.getString(keyComfyuiUrl),
    );
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
    await prefs.setString(keyApiProvider, settings.apiProvider == ApiProvider.openRouter ? 'openRouter' : 'lmStudio');
    
    // Save OpenRouter API key
    if (settings.openRouterApiKey != null && settings.openRouterApiKey!.isNotEmpty) {
      await prefs.setString(keyOpenRouterApiKey, settings.openRouterApiKey!);
    } else {
      await prefs.remove(keyOpenRouterApiKey);
    }

    // Save Search Settings
    await prefs.setString(keySearchProvider, settings.searchProvider.toString().split('.').last);

    if (settings.braveApiKey != null && settings.braveApiKey!.isNotEmpty) {
      await prefs.setString(keyBraveApiKey, settings.braveApiKey!);
    } else {
      await prefs.remove(keyBraveApiKey);
    }

    if (settings.bingApiKey != null && settings.bingApiKey!.isNotEmpty) {
      await prefs.setString(keyBingApiKey, settings.bingApiKey!);
    } else {
      await prefs.remove(keyBingApiKey);
    }

    if (settings.googleApiKey != null && settings.googleApiKey!.isNotEmpty) {
      await prefs.setString(keyGoogleApiKey, settings.googleApiKey!);
    } else {
      await prefs.remove(keyGoogleApiKey);
    }

    if (settings.googleCx != null && settings.googleCx!.isNotEmpty) {
      await prefs.setString(keyGoogleCx, settings.googleCx!);
    } else {
      await prefs.remove(keyGoogleCx);
    }

    if (settings.perplexityApiKey != null && settings.perplexityApiKey!.isNotEmpty) {
      await prefs.setString(keyPerplexityApiKey, settings.perplexityApiKey!);
    } else {
      await prefs.remove(keyPerplexityApiKey);
    }

    // ComfyUI
    if (settings.comfyuiUrl != null && settings.comfyuiUrl!.isNotEmpty) {
      await prefs.setString(keyComfyuiUrl, settings.comfyuiUrl!);
    } else {
      await prefs.remove(keyComfyuiUrl);
    }
  }
}

