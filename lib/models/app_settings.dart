class AppSettings {
  String lmStudioUrl;
  String searxngUrl;
  bool isDarkMode;
  String? selectedModelId;
  bool useWebSearch;

  AppSettings({
    required this.lmStudioUrl,
    required this.searxngUrl,
    this.isDarkMode = true,
    this.selectedModelId,
    this.useWebSearch = false,
  });

  // Create a copyWith method
  AppSettings copyWith({
    String? lmStudioUrl,
    String? searxngUrl,
    bool? isDarkMode,
    String? selectedModelId,
    bool? useWebSearch,
  }) {
    return AppSettings(
      lmStudioUrl: lmStudioUrl ?? this.lmStudioUrl,
      searxngUrl: searxngUrl ?? this.searxngUrl,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      selectedModelId: selectedModelId ?? this.selectedModelId,
      useWebSearch: useWebSearch ?? this.useWebSearch,
    );
  }
}
