import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';
import '../providers/chat_provider.dart';
import '../models/app_settings.dart';
import '../services/comfyui_service.dart';
import '../services/local_model_service.dart';
import '../utils/theme.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lmStudioController = TextEditingController();
  final _searxngController = TextEditingController();
  final _openRouterApiKeyController = TextEditingController();
  final _braveController = TextEditingController();
  final _bingController = TextEditingController();
  final _googleApiKeyController = TextEditingController();
  final _googleCxController = TextEditingController();
  final _perplexityController = TextEditingController();
  final _comfyuiController = TextEditingController();
  String _version = '';
  int _versionTapCount = 0;
  bool _showDevSettings = false;

  @override
  void initState() {
    super.initState();
    _loadVersion();
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    final settings = settingsProvider.settings;
    _lmStudioController.text = settings.lmStudioUrl;
    _searxngController.text = settings.searxngUrl;
    _openRouterApiKeyController.text = settings.openRouterApiKey ?? '';
    _braveController.text = settings.braveApiKey ?? '';
    _bingController.text = settings.bingApiKey ?? '';
    _googleApiKeyController.text = settings.googleApiKey ?? '';
    _googleCxController.text = settings.googleCx ?? '';
    _perplexityController.text = settings.perplexityApiKey ?? '';
    _comfyuiController.text = settings.comfyuiUrl ?? '';
  }

  @override
  void dispose() {
    _lmStudioController.dispose();
    _searxngController.dispose();
    _openRouterApiKeyController.dispose();
    _braveController.dispose();
    _bingController.dispose();
    _googleApiKeyController.dispose();
    _googleCxController.dispose();
    _perplexityController.dispose();
    _comfyuiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildSectionHeader('API Provider'),
                const SizedBox(height: 8),
                _buildProviderCard(context, settingsProvider),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader('Connectivity'),
                const SizedBox(height: 8),
                _buildConnectionCard(context, settingsProvider),
                
                const SizedBox(height: 24),
                
                _buildSectionHeader('Appearance'),
                const SizedBox(height: 8),
                _buildAppearanceCard(context, settings, settingsProvider),
                
                const SizedBox(height: 24),
                
                 _buildSectionHeader('Privacy & Security'),
                const SizedBox(height: 8),
                _buildPrivacyCard(context, settings, settingsProvider),
                
                if (_showDevSettings) ...[
                  const SizedBox(height: 24),
                  _buildSectionHeader('Developer Settings'),
                  const SizedBox(height: 8),
                  _buildDevSettingsCard(context, settingsProvider),
                ],

                const SizedBox(height: 24),

                 _buildSectionHeader('About'),
                 const SizedBox(height: 8),
                 _buildAboutCard(context),
              ].animate(interval: 50.ms).slideY(begin: 0.1, end: 0).fadeIn()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildCard({required Widget child, required BuildContext context}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: child,
      ),
    );
  }

  Widget _buildProviderCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    final colorScheme = Theme.of(context).colorScheme;
    
    return _buildCard(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Provider options as selectable cards
            _buildProviderOption(
              context: context,
              title: 'LM Studio',
              subtitle: 'Connect to local LM Studio server',
              icon: Icons.computer,
              isSelected: settings.apiProvider == ApiProvider.lmStudio,
              onTap: () => _selectProvider(settingsProvider, settings, ApiProvider.lmStudio),
            ),
            const SizedBox(height: 12),
            _buildProviderOption(
              context: context,
              title: 'OpenRouter',
              subtitle: 'Access 100+ AI models via cloud API',
              icon: Icons.cloud_outlined,
              isSelected: settings.apiProvider == ApiProvider.openRouter,
              onTap: () => _selectProvider(settingsProvider, settings, ApiProvider.openRouter),
            ),
            const SizedBox(height: 12),
            _buildProviderOption(
              context: context,
              title: 'On-Device',
              subtitle: 'Run models locally • No internet required',
              icon: Icons.smartphone,
              isSelected: settings.apiProvider == ApiProvider.localModel,
              onTap: () => _selectProvider(settingsProvider, settings, ApiProvider.localModel),
              badge: 'Private',
            ),
            
            // Show manage models button when On-Device is selected
            if (settings.apiProvider == ApiProvider.localModel) ...[
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pushNamed(context, '/local-models'),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Manage Local Models'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colorScheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
  
  void _selectProvider(SettingsProvider settingsProvider, AppSettings settings, ApiProvider newProvider) {
    // Unload local model when switching away from On-Device provider
    if (settings.apiProvider == ApiProvider.localModel && newProvider != ApiProvider.localModel) {
      LocalModelService().unloadModel();
    }
    settingsProvider.updateSettings(apiProvider: newProvider);
  }
  
  Widget _buildProviderOption({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    String? badge,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected 
                ? colorScheme.primary.withValues(alpha: 0.15)
                : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? colorScheme.primary 
                  : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08)),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected 
                      ? colorScheme.primary.withValues(alpha: 0.2)
                      : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: isSelected ? colorScheme.primary : (isDark ? Colors.white60 : Colors.black45),
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              // Text content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? colorScheme.primary : (isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                  ],
                ),
              ),
              // Selection indicator
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? colorScheme.primary : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? colorScheme.primary : (isDark ? Colors.white30 : Colors.black26),
                    width: 2,
                  ),
                ),
                child: isSelected 
                    ? const Icon(Icons.check, size: 14, color: Colors.white)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildConnectionCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    final isLocalModel = settings.apiProvider == ApiProvider.localModel;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // LM Studio Status
    final isLmConnected = settings.apiProvider == ApiProvider.lmStudio && settingsProvider.error == null && settingsProvider.availableModels.isNotEmpty;
    final lmStatusDot = _buildStatusDot(isLmConnected);

    // OpenRouter Status
    final isOpenRouterConnected = settingsProvider.isOpenRouterConnected;
    final openRouterStatusDot = _buildStatusDot(isOpenRouterConnected);

    // SearXNG Status
    final isSearxngConnected = settingsProvider.isSearxngConnected;
    final searxngStatusDot = _buildStatusDot(isSearxngConnected);

    // ComfyUI Status
    final isComfyUiConnected = settingsProvider.isComfyUiConnected;
    final comfyUiStatusDot = _buildStatusDot(isComfyUiConnected);

    return _buildCard(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Only show API provider-specific options when NOT using On-Device
            if (!isLocalModel) ...[
              if (settings.apiProvider == ApiProvider.lmStudio) ...[
                _buildInputField(
                    context, 
                    'LM Studio URL', 
                    _lmStudioController, 
                    Icons.computer, 
                    (val) => settingsProvider.updateSettings(lmStudioUrl: val),
                    labelTrailing: lmStatusDot
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _scanForLMStudio(context, settingsProvider),
                    icon: const Icon(Icons.search, size: 18),
                    label: const Text('Auto-detect LM Studio'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.primary,
                      side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ] else ...[
                _buildInputField(
                    context, 
                    'OpenRouter API Key', 
                    _openRouterApiKeyController, 
                    Icons.vpn_key, 
                    (val) => settingsProvider.updateSettings(openRouterApiKey: val),
                    labelTrailing: openRouterStatusDot,
                    obscureText: true,
                    hintText: 'sk-or-...',
                    suffixIcon: IconButton(
                        icon: const Icon(Icons.history, size: 20),
                        onPressed: () => _showApiKeyHistory(context, settingsProvider),
                        tooltip: 'API Key History',
                    ),
                ),
                 const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: settingsProvider.isLoadingModels ? null : () async {
                          final scaffoldMessenger = ScaffoldMessenger.of(context);
                          await settingsProvider.fetchModels();
                          if (mounted) {
                              String message;
                              if (settingsProvider.error == null) {
                                  message = 'Connected! Found ${settingsProvider.availableModels.length} models.';
                              } else {
                                final cleanError = settingsProvider.error!.replaceAll('Exception: ', '');
                                message = 'Error: $cleanError';
                              }
                              scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                      content: Text(message),
                                      behavior: SnackBarBehavior.floating,
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  )
                              );
                          }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      child: settingsProvider.isLoadingModels 
                          ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                          : const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.link),
                                SizedBox(width: 8),
                                Text('Test Connection', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                              ],
                            ),
                    ),
                  ),

                  if (settingsProvider.isOpenRouterConnected && settings.openRouterApiKey != null && !settings.openRouterApiKeys.contains(settings.openRouterApiKey))
                    Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: SizedBox(
                            width: double.infinity,
                            child: TextButton.icon(
                                onPressed: () {
                                    settingsProvider.addOpenRouterApiKeyToHistory(settings.openRouterApiKey!);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(content: Text('API Key saved to history'))
                                    );
                                },
                                icon: const Icon(Icons.save, size: 18),
                                label: const Text('Save this key to history'),
                                style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                ),
                            ),
                        ),
                    ),
              ],
              
              const SizedBox(height: 24),
            ],
            _buildInputField(
              context,
              'ComfyUI Server URL',
              _comfyuiController,
              Icons.image,
              (val) => settingsProvider.updateSettings(comfyuiUrl: val),
              hintText: 'http://192.168.1.100:8188',
              labelTrailing: comfyUiStatusDot,
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scanForComfyUI(context, settingsProvider),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Auto-detect ComfyUI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            Text(
              'Search Provider',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                 color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05),
                 borderRadius: BorderRadius.circular(12),
              ),
              child: DropdownButtonHideUnderline(
                child: ButtonTheme(
                  alignedDropdown: true,
                  child: DropdownButton<SearchProvider>(
                    value: settings.searchProvider,
                    isExpanded: true,
                    borderRadius: BorderRadius.circular(12),
                    dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                    style: TextStyle(color: isDark ? Colors.white : Colors.black87),
                    items: const [
                       DropdownMenuItem(value: SearchProvider.searxng, child: Text('SearXNG (Self-hosted)')),
                       DropdownMenuItem(value: SearchProvider.brave, child: Text('Brave Search')),
                       DropdownMenuItem(value: SearchProvider.bing, child: Text('Bing Search')),
                       DropdownMenuItem(value: SearchProvider.google, child: Text('Google Search')),
                       DropdownMenuItem(value: SearchProvider.perplexity, child: Text('Perplexity AI')),
                       DropdownMenuItem(value: SearchProvider.none, child: Text('None')),
                    ],
                    onChanged: (SearchProvider? newValue) {
                      if (newValue != null) {
                         settingsProvider.updateSettings(searchProvider: newValue);
                      }
                    },
                  ),
                ),
              ),
            ),

            if (settings.searchProvider != SearchProvider.none) ...[
                const SizedBox(height: 16),
                
                if (settings.searchProvider == SearchProvider.searxng) ...[
                   _buildInputField(
                      context, 
                      'SearXNG URL', 
                      _searxngController, 
                      Icons.search, 
                      (val) => settingsProvider.updateSettings(searxngUrl: val),
                      labelTrailing: searxngStatusDot
                   ),
                   const SizedBox(height: 12),
                   SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _scanForSearXNG(context, settingsProvider),
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text('Auto-detect SearXNG'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Theme.of(context).colorScheme.primary,
                          side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                   ),
                ] else if (settings.searchProvider == SearchProvider.brave) ...[
                   _buildInputField(
                      context, 
                      'Brave Search API Key', 
                      _braveController, 
                      Icons.key, 
                      (val) => settingsProvider.updateSettings(braveApiKey: val),
                      obscureText: true,
                   ),
                ] else if (settings.searchProvider == SearchProvider.bing) ...[
                   _buildInputField(
                      context, 
                      'Bing Search API Key', 
                      _bingController, 
                      Icons.key, 
                      (val) => settingsProvider.updateSettings(bingApiKey: val),
                      obscureText: true,
                   ),
                ] else if (settings.searchProvider == SearchProvider.google) ...[
                   _buildInputField(
                      context, 
                      'Google Search API Key', 
                      _googleApiKeyController, 
                      Icons.key, 
                      (val) => settingsProvider.updateSettings(googleApiKey: val),
                      obscureText: true,
                   ),
                   const SizedBox(height: 16),
                   _buildInputField(
                      context, 
                      'Google Search Engine ID (CX)', 
                      _googleCxController, 
                      Icons.numbers, 
                      (val) => settingsProvider.updateSettings(googleCx: val),
                   ),
                ] else if (settings.searchProvider == SearchProvider.perplexity) ...[
                   _buildInputField(
                      context, 
                      'Perplexity API Key', 
                      _perplexityController, 
                      Icons.key, 
                      (val) => settingsProvider.updateSettings(perplexityApiKey: val),
                      obscureText: true,
                   ),
                ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
    BuildContext context, 
    String label, 
    TextEditingController controller, 
    IconData icon, 
    Function(String) onChanged, 
    {Widget? labelTrailing, bool obscureText = false, String? hintText, Widget? suffixIcon}
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final hintColor = isDark ? Colors.white24 : Colors.black26;
    final fillColor = isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.05);
    final labelColor = isDark ? Colors.white70 : Colors.black54;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
            children: [
                Text(label, style: TextStyle(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500)),
                if (labelTrailing != null) ...[
                    const SizedBox(width: 8),
                    labelTrailing,
                ]
            ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: textColor),
          onChanged: onChanged,
          obscureText: obscureText,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: isDark ? Colors.white54 : Colors.black45, size: 20),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: fillColor,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5))),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            hintText: hintText ?? 'http://...',
            hintStyle: TextStyle(color: hintColor),
          ),
        ),
      ],
    );
  }

  Widget _buildAppearanceCard(BuildContext context, dynamic settings, SettingsProvider settingsProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    return _buildCard(
      context: context,
      child: Column(
        children: [
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            activeColor: Theme.of(context).colorScheme.primary,
            title: Text('Dark Mode', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            subtitle: Text('Easy on the eyes', style: TextStyle(color: subtitleColor, fontSize: 13)),
            value: settings.isDarkMode,
            onChanged: (val) => settingsProvider.updateSettings(isDarkMode: val),
          ),
          Divider(height: 1, color: dividerColor),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Accent Color', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 16),
                SizedBox(
                    height: 50,
                    child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: AppTheme.presetColors.length,
                        itemBuilder: (context, index) {
                            final color = AppTheme.presetColors[index];
                            final isSelected = (settings.themeColor != null && settings.themeColor == color.value) || (settings.themeColor == null && index == 0);
                            
                            return GestureDetector(
                                onTap: () => settingsProvider.updateSettings(themeColor: color.value),
                                child: AnimatedContainer(
                                    duration: 300.ms,
                                    width: 44,
                                    height: 44,
                                    margin: const EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                        color: color,
                                        shape: BoxShape.circle,
                                        border: isSelected ? Border.all(color: isDark ? Colors.white : Colors.black87, width: 3) : null,
                                        boxShadow: [
                                            if (isSelected) BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 4, spreadRadius: 1)
                                        ]
                                    ),
                                    child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 22) : null,
                                ),
                            );
                        },
                    ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrivacyCard(BuildContext context, AppSettings settings, SettingsProvider settingsProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;
    final dividerColor = isDark ? Colors.white10 : Colors.black12;

    return _buildCard(
      context: context,
      child: Column(
        children: [
           ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text('Clear Chat History', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            subtitle: Text('Delete all messages and chats', style: TextStyle(color: subtitleColor, fontSize: 13)),
            trailing: const Icon(Icons.delete_outline, color: Colors.red),
            onTap: () => _showClearConfirmation(context, settingsProvider, false),
          ),
          Divider(height: 1, color: dividerColor),
          ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
               title: Text('Wipe All Data', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
               subtitle: Text('Delete logs, settings, and models', style: TextStyle(color: subtitleColor, fontSize: 13)),
               trailing: const Icon(Icons.delete_forever, color: Colors.red),
               onTap: () => _showClearConfirmation(context, settingsProvider, true),
          ),
        ],
      ),
    );
  }

  Widget _buildDevSettingsCard(BuildContext context, SettingsProvider settingsProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white54 : Colors.black54;

    return _buildCard(
      context: context,
      child: Column(
        children: [
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text('Export JSON', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            subtitle: Text('Download all settings as a JSON file', style: TextStyle(color: subtitleColor, fontSize: 13)),
            trailing: Icon(Icons.file_download, color: Theme.of(context).colorScheme.primary),
            onTap: () => _handleJsonExport(context, settingsProvider),
          ),
          const Divider(height: 1, color: Colors.white10),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            title: Text('Import JSON', style: TextStyle(color: textColor, fontWeight: FontWeight.w500)),
            subtitle: Text('Restore settings from a JSON file', style: TextStyle(color: subtitleColor, fontSize: 13)),
            trailing: Icon(Icons.file_upload, color: Theme.of(context).colorScheme.primary),
            onTap: () => _handleJsonImport(context, settingsProvider),
          ),
        ],
      ),
    );
  }

  Future<void> _handleJsonExport(BuildContext context, SettingsProvider provider) async {
    final jsonStr = provider.exportSettingsJson();
    final bytes = Uint8List.fromList(utf8.encode(jsonStr));
    
    // Use share_plus to "download" or share the file
    final xFile = XFile.fromData(
      bytes,
      name: 'chadgpt_settings.json',
      mimeType: 'application/json',
    );
    
    await Share.shareXFiles([xFile], text: 'ChadGPT Settings Export');
  }

  Future<void> _handleJsonImport(BuildContext context, SettingsProvider provider) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final content = await file.readAsString();
        
        final success = await provider.importSettingsJson(content);
        if (success && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Settings imported successfully!'), backgroundColor: Colors.green),
          );
          // Refresh controllers if needed (though notifyListeners should help)
          final settings = provider.settings;
          _lmStudioController.text = settings.lmStudioUrl;
          _searxngController.text = settings.searxngUrl;
          _openRouterApiKeyController.text = settings.openRouterApiKey ?? '';
        } else if (context.mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to import settings. Invalid JSON format.'), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing file: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
  

  void _showClearConfirmation(BuildContext context, SettingsProvider provider, bool isFullWipe) {
      showDialog(
          context: context, 
          builder: (ctx) => AlertDialog(
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
              title: Text(isFullWipe ? 'Wipe All Data?' : 'Clear History?', style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black, fontWeight: FontWeight.bold)),
              content: Text(
                  isFullWipe 
                    ? 'This will permanently delete ALL app data, including settings, API keys, downloaded models meta-data, and chat history. This action cannot be undone.' 
                    : 'This will permanently delete all your chat history. This action cannot be undone.',
                  style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
              ),
              actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancel'),
                  ),
                  TextButton(
                      onPressed: () async {
                          Navigator.pop(ctx);
                          if (isFullWipe) {
                              await provider.clearAllData();
                              if (context.mounted) {
                                  context.read<ChatProvider>().clearAllChats();
                              }
                          } else {
                              // Use ChatProvider to clear history and update UI state
                              context.read<ChatProvider>().clearAllChats();
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(isFullWipe ? 'All data wiped' : 'Chat history cleared')),
                          );
                      },
                      child: Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                  ),
              ],
          )
      );
  }

  void _showApiKeyHistory(BuildContext context, SettingsProvider provider) {
      final isDark = Theme.of(context).brightness == Brightness.dark;
      final history = provider.settings.openRouterApiKeys;

      showModalBottomSheet(
          context: context,
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          builder: (ctx) {
              return SafeArea(
                  child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                          Padding(
                              padding: const EdgeInsets.all(20),
                              child: Row(
                                  children: [
                                      const Icon(Icons.history, color: Colors.grey),
                                      const SizedBox(width: 12),
                                      const Text(
                                          'API Key History',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                      ),
                                      const Spacer(),
                                      IconButton(
                                          onPressed: () => Navigator.pop(ctx),
                                          icon: const Icon(Icons.close),
                                      ),
                                  ],
                              ),
                          ),
                          if (history.isEmpty)
                              const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 40),
                                  child: Center(
                                      child: Text('No saved API keys yet', style: TextStyle(color: Colors.grey)),
                                  ),
                              )
                          else
                              Flexible(
                                  child: ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: history.length,
                                      itemBuilder: (context, index) {
                                          final key = history[index];
                                          final maskedKey = key.length > 12 
                                              ? '${key.substring(0, 8)}...${key.substring(key.length - 4)}'
                                              : key;
                                          final isSelected = provider.settings.openRouterApiKey == key;

                                          return ListTile(
                                              leading: Icon(
                                                  Icons.vpn_key, 
                                                  color: isSelected ? Theme.of(context).colorScheme.primary : Colors.grey,
                                                  size: 20,
                                              ),
                                              title: Text(
                                                  provider.settings.openRouterApiKeyAliases[key] ?? maskedKey,
                                                  style: TextStyle(
                                                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                                      color: isSelected ? Theme.of(context).colorScheme.primary : null,
                                                  ),
                                              ),
                                              subtitle: provider.settings.openRouterApiKeyAliases.containsKey(key) 
                                                  ? Text(maskedKey, style: const TextStyle(fontSize: 11, color: Colors.grey))
                                                  : null,
                                              trailing: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                      IconButton(
                                                          icon: const Icon(Icons.edit_outlined, size: 18, color: Colors.grey),
                                                          onPressed: () => _showRenameApiKeyDialog(context, provider, key),
                                                          tooltip: 'Rename',
                                                      ),
                                                      IconButton(
                                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                                          onPressed: () {
                                                              provider.removeOpenRouterApiKeyFromHistory(key);
                                                              if (history.length <= 1) Navigator.pop(ctx);
                                                          },
                                                      ),
                                                  ],
                                              ),
                                              onTap: () {
                                                  _openRouterApiKeyController.text = key;
                                                  provider.updateSettings(openRouterApiKey: key);
                                                  Navigator.pop(ctx);
                                              },
                                          );
                                      },
                                  ),
                              ),
                          const SizedBox(height: 20),
                      ],
                  ),
              );
          },
      );
  }

  void _showRenameApiKeyDialog(BuildContext context, SettingsProvider provider, String key) {
    final controller = TextEditingController(text: provider.settings.openRouterApiKeyAliases[key] ?? '');
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
        title: const Text('Rename API Key', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Nickname',
            labelStyle: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
            hintText: 'Work, Personal, etc.',
            hintStyle: TextStyle(color: isDark ? Colors.white24 : Colors.black26),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
          ),
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              provider.updateOpenRouterApiKeyAlias(key, controller.text);
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDot(bool isConnected) {
    return Container(
       width: 8, 
       height: 8,
       decoration: BoxDecoration(
           color: isConnected ? Colors.green : Colors.red,
           shape: BoxShape.circle,
           boxShadow: [
               BoxShadow(
                   color: (isConnected ? Colors.green : Colors.red).withValues(alpha: 0.5), 
                   blurRadius: 5, 
                   spreadRadius: 1
               )
           ]
       ),
    );
  }

   Widget _buildImageGenerationCard(BuildContext context, SettingsProvider settingsProvider) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return _buildCard(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.auto_awesome,
                  color: Theme.of(context).colorScheme.primary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'ComfyUI Integration',
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use /create <prompt> in chat to generate images',
              style: TextStyle(
                color: isDark ? Colors.white54 : Colors.black54,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 16),
            _buildInputField(
              context,
              'ComfyUI Server URL',
              _comfyuiController,
              Icons.image,
              (val) => settingsProvider.updateSettings(comfyuiUrl: val),
              hintText: 'http://192.168.1.100:8188',
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scanForComfyUI(context, settingsProvider),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Auto-detect ComfyUI'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.primary,
                  side: BorderSide(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  void _scanForComfyUI(BuildContext context, SettingsProvider settingsProvider) {
    String statusText = 'Starting scan...';
    List<String> foundServers = [];
    bool isScanning = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Start scan on first build
          if (isScanning && foundServers.isEmpty && statusText == 'Starting scan...') {
            ComfyuiService.scanNetwork(
              onProgress: (status) {
                if (context.mounted) {
                  setDialogState(() => statusText = status);
                }
              },
              onServerFound: (url) {
                if (context.mounted) {
                  setDialogState(() => foundServers.add(url));
                }
              },
            ).then((_) {
              if (context.mounted) {
                setDialogState(() {
                  isScanning = false;
                  statusText = foundServers.isEmpty ? 'No ComfyUI servers found' : 'Found ${foundServers.length} server(s)';
                });
              }
            });
          }
          
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
            title: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Scanning Network'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isScanning)
                  const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(statusText, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                if (foundServers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Found servers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...foundServers.map((url) => InkWell(
                    onTap: () {
                      _comfyuiController.text = url;
                      settingsProvider.updateSettings(comfyuiUrl: url);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('ComfyUI server set to $url'), backgroundColor: Colors.green),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.computer, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(url, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isScanning ? 'Cancel' : 'Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _scanForLMStudio(BuildContext context, SettingsProvider settingsProvider) {
    String statusText = 'Starting scan...';
    List<String> foundServers = [];
    bool isScanning = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Start scan on first build
          if (isScanning && foundServers.isEmpty && statusText == 'Starting scan...') {
            _scanNetworkForLMStudio(
              onProgress: (status) {
                if (context.mounted) {
                  setDialogState(() => statusText = status);
                }
              },
              onServerFound: (url) {
                if (context.mounted) {
                  setDialogState(() => foundServers.add(url));
                }
              },
            ).then((_) {
              if (context.mounted) {
                setDialogState(() {
                  isScanning = false;
                  statusText = foundServers.isEmpty ? 'No LM Studio servers found' : 'Found ${foundServers.length} server(s)';
                });
              }
            });
          }
          
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
            title: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Scanning Network'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isScanning)
                  const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(statusText, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                if (foundServers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Found servers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...foundServers.map((url) => InkWell(
                    onTap: () {
                      _lmStudioController.text = url;
                      settingsProvider.updateSettings(lmStudioUrl: url);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('LM Studio server set to $url'), backgroundColor: Colors.green),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.computer, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(url, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isScanning ? 'Cancel' : 'Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<String>> _scanNetworkForLMStudio({
    void Function(String status)? onProgress,
    void Function(String url)? onServerFound,
  }) async {
    final foundServers = <String>[];
    const port = 1234; // LM Studio default port
    const timeout = Duration(milliseconds: 800);
    
    final patterns = [
      '192.168.1.',
      '192.168.0.',
      '10.0.0.',
      '172.16.0.',
    ];
    
    final localUrls = [
      'http://localhost:$port',
      'http://127.0.0.1:$port',
    ];
    
    onProgress?.call('Checking localhost...');
    for (var url in localUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/v1/models'),
        ).timeout(timeout);
        if (response.statusCode == 200) {
          foundServers.add(url);
          onServerFound?.call(url);
        }
      } catch (_) {}
    }
    
    for (var pattern in patterns) {
      onProgress?.call('Scanning $pattern*...');
      
      final futures = <Future<void>>[];
      
      for (var i = 1; i <= 254; i++) {
        final ip = '$pattern$i';
        final url = 'http://$ip:$port';
        
        futures.add((() async {
          try {
            final response = await http.get(
              Uri.parse('$url/v1/models'),
            ).timeout(timeout);
            if (response.statusCode == 200) {
              foundServers.add(url);
              onServerFound?.call(url);
            }
          } catch (_) {}
        })());
      }
      
      final batchSize = 50;
      for (var i = 0; i < futures.length; i += batchSize) {
        final batch = futures.skip(i).take(batchSize).toList();
        await Future.wait(batch);
      }
    }
    
    onProgress?.call('Scan complete');
    return foundServers;
  }

  void _scanForSearXNG(BuildContext context, SettingsProvider settingsProvider) {
    String statusText = 'Starting scan...';
    List<String> foundServers = [];
    bool isScanning = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          // Start scan on first build
          if (isScanning && foundServers.isEmpty && statusText == 'Starting scan...') {
            _scanNetworkForSearXNG(
              onProgress: (status) {
                if (context.mounted) {
                  setDialogState(() => statusText = status);
                }
              },
              onServerFound: (url) {
                if (context.mounted) {
                  setDialogState(() => foundServers.add(url));
                }
              },
            ).then((_) {
              if (context.mounted) {
                setDialogState(() {
                  isScanning = false;
                  statusText = foundServers.isEmpty ? 'No SearXNG servers found' : 'Found ${foundServers.length} server(s)';
                });
              }
            });
          }
          
          return AlertDialog(
            backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2C) : Colors.white,
            title: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Scanning Network'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isScanning)
                  const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(statusText, style: TextStyle(color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black54)),
                if (foundServers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Found servers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...foundServers.map((url) => InkWell(
                    onTap: () {
                      _searxngController.text = url;
                      settingsProvider.updateSettings(searxngUrl: url);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('SearXNG server set to $url'), backgroundColor: Colors.green),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.search_outlined, color: Theme.of(context).colorScheme.primary, size: 20),
                          const SizedBox(width: 8),
                          Expanded(child: Text(url, style: const TextStyle(fontWeight: FontWeight.w500))),
                          Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.primary),
                        ],
                      ),
                    ),
                  )),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(isScanning ? 'Cancel' : 'Close'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<List<String>> _scanNetworkForSearXNG({
    void Function(String status)? onProgress,
    void Function(String url)? onServerFound,
  }) async {
    final foundServers = <String>[];
    const ports = [8080, 8081]; 
    const timeout = Duration(milliseconds: 2000); 
    
    // Get local subnets dynamically
    final subnets = <String>{};
    print("DEBUG: Starting SearXNG Network Scan");
    
    try {
      final interfaces = await NetworkInterface.list(
        type: InternetAddressType.IPv4, 
        includeLinkLocal: false,
      );
      for (var interface in interfaces) {
        print("DEBUG: Found interface: ${interface.name}");
        for (var addr in interface.addresses) {
            print("DEBUG: Address: ${addr.address}");
            if (!addr.isLoopback) {
                final parts = addr.address.split('.');
                if (parts.length == 4) {
                    final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
                    subnets.add(subnet);
                    print("DEBUG: Added subnet: $subnet");
                }
            }
        }
      }
    } catch (e) {
      print("DEBUG: Error getting network interfaces: $e");
    }

    // Fallback patterns if no interfaces found
    if (subnets.isEmpty) {
        print("DEBUG: No subnets detected, using fallbacks");
        subnets.addAll([
          '192.168.1.',
          '192.168.0.',
          '10.0.0.',
          '172.16.0.',
        ]);
    }
    
    final localUrls = [
      for (var port in ports) ...[
        'http://localhost:$port', 
        'http://127.0.0.1:$port',
        'http://10.0.2.2:$port', // Android Emulator -> Host
        'http://10.0.3.2:$port', // Genymotion -> Host
      ]
    ];
    
    onProgress?.call('Checking localhost...');
    for (var url in localUrls) {
      // print("DEBUG: Checking $url");
      try {
        final response = await http.get(
          Uri.parse('$url/search?q=test&format=json'),
        ).timeout(timeout);
        if (response.statusCode == 200) {
          print("DEBUG: Found SearXNG at $url");
          foundServers.add(url);
          onServerFound?.call(url);
        }
      } catch (_) {}
    }
    
    for (var subnet in subnets) {
      onProgress?.call('Scanning $subnet*...');
      print("DEBUG: Scanning subnet $subnet*");
      
      final futures = <Future<void>>[];
      
      for (var i = 1; i <= 254; i++) {
        final ip = '$subnet$i';
        
        for (var port in ports) {
             final url = 'http://$ip:$port';
             futures.add((() async {
              try {
                final response = await http.get(
                  Uri.parse('$url/search?q=test&format=json'),
                ).timeout(timeout);
                if (response.statusCode == 200) {
                  print("DEBUG: Found SearXNG at $url");
                  foundServers.add(url);
                  onServerFound?.call(url);
                }
              } catch (_) {}
            })());
        }
      }
      
      // Smaller batch size to prevent network congestion
      final batchSize = 25;
      for (var i = 0; i < futures.length; i += batchSize) {
        final batch = futures.skip(i).take(batchSize).toList();
        await Future.wait(batch);
      }
    }
    
    onProgress?.call('Scan complete');
    return foundServers;
  }

  Future<void> _loadVersion() async {
    final packageInfo = await PackageInfo.fromPlatform();
    if (mounted) {
      setState(() {
        _version = '${packageInfo.version}';
      });
    }
  }

  Widget _buildAboutCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        onTap: () {
          setState(() {
            _versionTapCount++;
            if (_versionTapCount == 7) {
              _showDevSettings = true;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Developer settings enabled!'), duration: Duration(seconds: 1)),
              );
            }
          });
        },
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.info_outline, color: isDark ? Colors.white : Colors.black87),
        ),
        title: Text('Version', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
        trailing: Text(_version, style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      ),
    );
  }
}

