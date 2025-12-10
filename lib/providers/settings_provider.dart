import 'package:flutter/material.dart';
import '../models/app_settings.dart';
import '../services/shared_prefs_service.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class SettingsProvider with ChangeNotifier {
  final SharedPrefsService _prefsService = SharedPrefsService();
  late ApiService _apiService;
  AppSettings _settings = AppSettings(
    lmStudioUrl: AppConstants.defaultLmStudioUrl,
    searxngUrl: AppConstants.defaultSearxngUrl,
  );

  List<String> _availableModels = [];
  bool _isLoadingModels = false;
  String? _error;

  AppSettings get settings => _settings;
  List<String> get availableModels => _availableModels;
  bool get isLoadingModels => _isLoadingModels;
  String? get error => _error;
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
  }) async {
    _settings = _settings.copyWith(
      lmStudioUrl: lmStudioUrl,
      searxngUrl: searxngUrl,
      isDarkMode: isDarkMode,
      selectedModelId: selectedModelId,
      useWebSearch: useWebSearch,
    );
    
    // Update API service with new settings if URLs changed
    if (lmStudioUrl != null || searxngUrl != null) {
      _apiService = ApiService(_settings);
    }
    
    notifyListeners();
    await _prefsService.saveSettings(_settings);
  }

  Future<void> fetchModels() async {
    _isLoadingModels = true;
    _error = null;
    notifyListeners();

    try {
      _availableModels = await _apiService.getModels();
      if (_settings.selectedModelId == null && _availableModels.isNotEmpty) {
        updateSettings(selectedModelId: _availableModels.first);
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoadingModels = false;
      notifyListeners();
    }
  }
}
