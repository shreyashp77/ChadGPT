import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';

class SharedPrefsService {
  static const String keyLmStudioUrl = 'lm_studio_url';
  static const String keySearxngUrl = 'searxng_url';
  static const String keyIsDarkMode = 'is_dark_mode';
  static const String keySelectedModelId = 'selected_model_id';
  static const String keyUseWebSearch = 'use_web_search';

  Future<AppSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    
    return AppSettings(
      lmStudioUrl: prefs.getString(keyLmStudioUrl) ?? AppConstants.defaultLmStudioUrl,
      searxngUrl: prefs.getString(keySearxngUrl) ?? AppConstants.defaultSearxngUrl,
      isDarkMode: prefs.getBool(keyIsDarkMode) ?? true,
      selectedModelId: prefs.getString(keySelectedModelId),
      useWebSearch: prefs.getBool(keyUseWebSearch) ?? false,
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
  }
}
