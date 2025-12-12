enum ApiProvider { lmStudio, openRouter }

class AppSettings {
  String lmStudioUrl;
  String searxngUrl;
  bool isDarkMode;
  String? selectedModelId;
  bool useWebSearch;
  int? themeColor;
  Map<String, String> modelAliases;
  ApiProvider apiProvider;
  String? openRouterApiKey;

  AppSettings({
    required this.lmStudioUrl,
    required this.searxngUrl,
    this.isDarkMode = true,
    this.selectedModelId,
    this.useWebSearch = false,
    this.themeColor,
    this.modelAliases = const {},
    this.apiProvider = ApiProvider.lmStudio,
    this.openRouterApiKey,
  });

  // Create a copyWith method
  AppSettings copyWith({
    String? lmStudioUrl,
    String? searxngUrl,
    bool? isDarkMode,
    String? selectedModelId,
    bool? useWebSearch,
    int? themeColor,
    Map<String, String>? modelAliases,
    ApiProvider? apiProvider,
    String? openRouterApiKey,
  }) {
    return AppSettings(
      lmStudioUrl: lmStudioUrl ?? this.lmStudioUrl,
      searxngUrl: searxngUrl ?? this.searxngUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      useWebSearch: useWebSearch ?? this.useWebSearch,
      themeColor: themeColor ?? this.themeColor,
      modelAliases: modelAliases ?? this.modelAliases,
      apiProvider: apiProvider ?? this.apiProvider,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
    );
  }
}
