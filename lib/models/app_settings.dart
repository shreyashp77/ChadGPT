class AppSettings {
  String lmStudioUrl;
  String searxngUrl;
  bool isDarkMode;
  String? selectedModelId;
  bool useWebSearch;
  int? themeColor;
  Map<String, String> modelAliases;

  AppSettings({
    required this.lmStudioUrl,
    required this.searxngUrl,
    this.isDarkMode = true,
    this.selectedModelId,
    this.useWebSearch = false,
    this.themeColor,
    this.modelAliases = const {},
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
  }) {
    return AppSettings(
      lmStudioUrl: lmStudioUrl ?? this.lmStudioUrl,
      searxngUrl: searxngUrl ?? this.searxngUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      useWebSearch: useWebSearch ?? this.useWebSearch,
      themeColor: themeColor ?? this.themeColor,
      modelAliases: modelAliases ?? this.modelAliases,
    );
  }
}
