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
  bool _isSearxngConnected = false;

  AppSettings get settings => _settings;
  List<String> get availableModels => _availableModels;
  bool get isLoadingModels => _isLoadingModels;
  String? get error => _error;
  bool get isSearxngConnected => _isSearxngConnected;
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
  }) async {
    _settings = _settings.copyWith(
      lmStudioUrl: lmStudioUrl,
      searxngUrl: searxngUrl,
      isDarkMode: isDarkMode,
      selectedModelId: selectedModelId,
      useWebSearch: useWebSearch,
      themeColor: themeColor,
      modelAliases: modelAliases,
    );
    
    // Update API service with new settings if URLs changed
    if (lmStudioUrl != null || searxngUrl != null) {
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
      return _settings.modelAliases[modelId] ?? modelId.split('/').last;
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
