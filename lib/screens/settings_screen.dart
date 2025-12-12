import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lmStudioController = TextEditingController();
  final _searxngController = TextEditingController();
  final _openRouterApiKeyController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _lmStudioController.text = settings.lmStudioUrl;
    _searxngController.text = settings.searxngUrl;
    _openRouterApiKeyController.text = settings.openRouterApiKey ?? '';
  }

  @override
  void dispose() {
    _lmStudioController.dispose();
    _searxngController.dispose();
    _openRouterApiKeyController.dispose();
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
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(BuildContext context, SettingsProvider settingsProvider) {
    final settings = settingsProvider.settings;
    final isOpenRouter = settings.apiProvider == ApiProvider.openRouter;
    
    // LM Studio Status
    final isLmConnected = !isOpenRouter && settingsProvider.error == null && settingsProvider.availableModels.isNotEmpty;
    final lmStatusDot = Container(
       width: 8, 
       height: 8,
       decoration: BoxDecoration(
           color: isLmConnected ? Colors.green : Colors.red,
           shape: BoxShape.circle,
           boxShadow: [
               BoxShadow(
                   color: (isLmConnected ? Colors.green : Colors.red).withValues(alpha: 0.5), 
                   blurRadius: 5, 
                   spreadRadius: 1
               )
           ]
       ),
    );

    // OpenRouter Status
    final isOpenRouterConnected = settingsProvider.isOpenRouterConnected;
    final openRouterStatusDot = Container(
       width: 8, 
       height: 8,
       decoration: BoxDecoration(
           color: isOpenRouterConnected ? Colors.green : Colors.red,
           shape: BoxShape.circle,
           boxShadow: [
               BoxShadow(
                   color: (isOpenRouterConnected ? Colors.green : Colors.red).withValues(alpha: 0.5), 
                   blurRadius: 5, 
                   spreadRadius: 1
               )
           ]
       ),
    );

    // SearXNG Status
    final isSearxngConnected = settingsProvider.isSearxngConnected;
    final searxngStatusDot = Container(
       width: 8, 
       height: 8,
       decoration: BoxDecoration(
           color: isSearxngConnected ? Colors.green : Colors.red,
           shape: BoxShape.circle,
           boxShadow: [
               BoxShadow(
                   color: (isSearxngConnected ? Colors.green : Colors.red).withValues(alpha: 0.5), 
                   blurRadius: 5, 
                   spreadRadius: 1
               )
           ]
       ),
    );

    return _buildCard(
      context: context,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            if (!isOpenRouter) ...[
              _buildInputField(
                  context, 
                  'LM Studio URL', 
                  _lmStudioController, 
                  Icons.computer, 
                  (val) => settingsProvider.updateSettings(lmStudioUrl: val),
                  labelTrailing: lmStatusDot
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
            ],
            const SizedBox(height: 16),
            _buildInputField(
                context, 
                'SearXNG URL', 
                _searxngController, 
                Icons.search, 
                (val) => settingsProvider.updateSettings(searxngUrl: val),
                labelTrailing: searxngStatusDot
            ),
            const SizedBox(height: 20),
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
                          if (isOpenRouter) {
                            message = 'Connected! Found ${settingsProvider.availableModels.length} free models.';
                          } else {
                            message = 'Connected! Found ${settingsProvider.availableModels.length} models.';
                          }
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
        trailing: Text('1.0.0', style: TextStyle(color: isDark ? Colors.white54 : Colors.black54)),
      ),
    );
  }
}

