import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

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
          Card(
            child: SwitchListTile(
              title: const Text('Dark Mode'),
              subtitle: const Text('Enable dark theme'),
              value: settings.isDarkMode,
              onChanged: (val) {
                settingsProvider.updateSettings(isDarkMode: val);
              },
            ),
          ),
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
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   const Text('AI Model', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const SizedBox(height: 8),
                   if (settingsProvider.availableModels.isEmpty)
                      const Text('No models found. Check connection.', style: TextStyle(color: Colors.red))
                   else
                      DropdownButtonFormField<String>(
                        value: settings.selectedModelId,
                        isExpanded: true,
                        decoration: const InputDecoration(border: OutlineInputBorder()),
                        items: settingsProvider.availableModels.map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(m.split('/').last, overflow: TextOverflow.ellipsis),
                        )).toList(),
                        onChanged: (val) {
                            if (val != null) {
                                settingsProvider.updateSettings(selectedModelId: val);
                            }
                        },
                      ),
                   const SizedBox(height: 8),
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
                      icon: settingsProvider.isLoadingModels ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.refresh),
                      label: const Text('Refresh Models / Test Connection'),
                   ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Configuration Cards
        ],
      ),
    );
  }
}
