import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../utils/theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _lmStudioController = TextEditingController();
  final _searxngController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>().settings;
    _lmStudioController.text = settings.lmStudioUrl;
    _searxngController.text = settings.searxngUrl;
  }

  @override
  void dispose() {
    _lmStudioController.dispose();
    _searxngController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Theme Settings

          const SizedBox(height: 16),
          
          // API Settings
          Text('Server Configuration', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _lmStudioController,
            decoration: const InputDecoration(
              labelText: 'LM Studio URL',
              hintText: 'http://localhost:1234',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => settingsProvider.updateSettings(lmStudioUrl: val),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _searxngController,
            decoration: const InputDecoration(
              labelText: 'SearXNG URL',
              hintText: 'http://localhost:8080',
              border: OutlineInputBorder(),
            ),
            onChanged: (val) => settingsProvider.updateSettings(searxngUrl: val),
          ),
          
          const SizedBox(height: 16),
          // Connection Test
          ElevatedButton.icon(
            onPressed: settingsProvider.isLoadingModels ? null : () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                await settingsProvider.fetchModels();
                if (mounted) {
                    scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text(
                            settingsProvider.error == null 
                            ? 'Connected! Found ${settingsProvider.availableModels.length} models.' 
                            : 'Error: ${settingsProvider.error}'
                        ))
                    );
                }
            },
            icon: settingsProvider.isLoadingModels 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Icon(Icons.refresh),
            label: const Text('Test Connection & Refresh Models'),
          ),
          const SizedBox(height: 16),
          // Appearance & Theme Color
          Text('Appearance', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Dark Mode'),
                        subtitle: const Text('Enable dark theme'),
                        value: settings.isDarkMode,
                        onChanged: (val) {
                            settingsProvider.updateSettings(isDarkMode: val);
                        },
                    ),
                    const Divider(),
                    const Text('Accent Color', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 12),
                    SizedBox(
                        height: 50,
                        child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: AppTheme.presetColors.length,
                            itemBuilder: (context, index) {
                                final color = AppTheme.presetColors[index];
                                final isSelected = (settings.themeColor != null && settings.themeColor == color.value) || (settings.themeColor == null && index == 0);
                                
                                return GestureDetector(
                                    onTap: () {
                                        settingsProvider.updateSettings(themeColor: color.value);
                                    },
                                    child: Container(
                                        width: 40,
                                        height: 40,
                                        margin: const EdgeInsets.only(right: 12),
                                        decoration: BoxDecoration(
                                            color: color,
                                            shape: BoxShape.circle,
                                            border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                                            boxShadow: [
                                                if (isSelected) BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8, spreadRadius: 2)
                                            ]
                                        ),
                                        child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 20) : null,
                                    ),
                                );
                            },
                        ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const SizedBox(height: 16),
          // Configuration Cards
        ],
      ),
    );
  }
}
