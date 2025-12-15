import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../services/comfyui_service.dart';
import '../utils/theme.dart';
import 'package:http/http.dart' as http;

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

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settings = settingsProvider.settings;
    final isLocalModel = settings.apiProvider == ApiProvider.localModel;
    
    return _buildCard(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choose your AI backend',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<ApiProvider>(
              segments: const [
                ButtonSegment<ApiProvider>(
                  value: ApiProvider.lmStudio,
                  label: Text('LM Studio'),
                  icon: Icon(Icons.computer),
                ),
                ButtonSegment<ApiProvider>(
                  value: ApiProvider.openRouter,
                  label: Text('OpenRouter'),
                  icon: Icon(Icons.cloud),
                ),
                ButtonSegment<ApiProvider>(
                  value: ApiProvider.localModel,
                  label: Text('On-Device'),
                  icon: Icon(Icons.phone_android),
                ),
              ],
              selected: {settings.apiProvider},
              onSelectionChanged: (Set<ApiProvider> newSelection) {
                settingsProvider.updateSettings(apiProvider: newSelection.first);
              },
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Theme.of(context).colorScheme.primary;
                  }
                  return isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1);
                }),
                foregroundColor: WidgetStateProperty.resolveWith<Color?>((states) {
                  if (states.contains(WidgetState.selected)) {
                    return Colors.white;
                  }
                  return isDark ? Colors.white70 : Colors.black54;
                }),
              ),
            ),
            // Show manage models button when On-Device is selected
            if (isLocalModel) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Models run entirely on your phone. No internet required!',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pushNamed(context, '/local-models');
                        },
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text('Manage Local Models'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    final isOpenRouter = settings.apiProvider == ApiProvider.openRouter;
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
                                message = 'Connected! Found ${settingsProvider.availableModels.length} free models.';
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
            ],
            
            const SizedBox(height: 24),
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
    {Widget? labelTrailing, bool obscureText = false, String? hintText}
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

   Widget _buildAboutCard(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _buildCard(
      context: context,
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Icon(Icons.info_outline, color: isDark ? Colors.white : Colors.black87),
        ),
        title: Text('Version', style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontWeight: FontWeight.w500)),
        trailing: Text('1.0.1.1', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      ),
    );
  }
}

