enum ApiProvider { lmStudio, openRouter }
enum SearchProvider { searxng, brave, bing, google, perplexity }

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
  
  // Search Provider Settings
  SearchProvider searchProvider;
  String? braveApiKey;
  String? bingApiKey;
  String? googleApiKey;
  String? googleCx;
  String? perplexityApiKey;

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
    this.searchProvider = SearchProvider.searxng,
    this.braveApiKey,
    this.bingApiKey,
    this.googleApiKey,
    this.googleCx,
    this.perplexityApiKey,
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
    SearchProvider? searchProvider,
    String? braveApiKey,
    String? bingApiKey,
    String? googleApiKey,
    String? googleCx,
    String? perplexityApiKey,
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
      searchProvider: searchProvider ?? this.searchProvider,
      braveApiKey: braveApiKey ?? this.braveApiKey,
      bingApiKey: bingApiKey ?? this.bingApiKey,
      googleApiKey: googleApiKey ?? this.googleApiKey,
      googleCx: googleCx ?? this.googleCx,
      perplexityApiKey: perplexityApiKey ?? this.perplexityApiKey,
    );
  }
}
