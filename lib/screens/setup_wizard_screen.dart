import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../models/app_settings.dart';
import '../utils/constants.dart';

import '../services/api_service.dart';
import '../services/comfyui_service.dart';

class SetupWizardScreen extends StatefulWidget {
  const SetupWizardScreen({super.key});

  @override
  State<SetupWizardScreen> createState() => _SetupWizardScreenState();
}

class _SetupWizardScreenState extends State<SetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  
  // State
  ApiProvider _selectedApiProvider = ApiProvider.lmStudio;
  final TextEditingController _lmStudioUrlController = TextEditingController(text: AppConstants.defaultLmStudioUrl);
  final TextEditingController _openRouterKeyController = TextEditingController();
  final TextEditingController _comfyUiUrlController = TextEditingController();
  
  // Search State
  SearchProvider _selectedSearchProvider = SearchProvider.searxng;
  final TextEditingController _searxngUrlController = TextEditingController(text: AppConstants.defaultSearxngUrl);
  final TextEditingController _googleApiKeyController = TextEditingController();
  final TextEditingController _googleCxController = TextEditingController();
  final TextEditingController _bingApiKeyController = TextEditingController();
  final TextEditingController _braveApiKeyController = TextEditingController();
  final TextEditingController _perplexityApiKeyController = TextEditingController();

  @override
  void dispose() {
    _pageController.dispose();
    _lmStudioUrlController.dispose();
    _openRouterKeyController.dispose();
    _comfyUiUrlController.dispose();
    _searxngUrlController.dispose();
    _googleApiKeyController.dispose();
    _googleCxController.dispose();
    _bingApiKeyController.dispose();
    _braveApiKeyController.dispose();
    _perplexityApiKeyController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _finishSetup();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _finishSetup() async {
    final settingsProvider = context.read<SettingsProvider>();
    
    // Sanitize LM Studio URL
    String lmStudioUrl = _lmStudioUrlController.text.trim();
    if (lmStudioUrl.endsWith('/')) {
        lmStudioUrl = lmStudioUrl.substring(0, lmStudioUrl.length - 1);
    }
    if (lmStudioUrl.endsWith('/v1')) {
        lmStudioUrl = lmStudioUrl.substring(0, lmStudioUrl.length - 3);
    }

    // Construct settings update
    await settingsProvider.updateSettings(
      apiProvider: _selectedApiProvider,
      lmStudioUrl: lmStudioUrl,
      openRouterApiKey: _openRouterKeyController.text.trim(),
      comfyuiUrl: _comfyUiUrlController.text.trim().isEmpty ? null : _comfyUiUrlController.text.trim(),
      searchProvider: _selectedSearchProvider,
      searxngUrl: _searxngUrlController.text.trim(),
      googleApiKey: _googleApiKeyController.text.trim(),
      googleCx: _googleCxController.text.trim(),
      bingApiKey: _bingApiKeyController.text.trim(),
      braveApiKey: _braveApiKeyController.text.trim(),
      perplexityApiKey: _perplexityApiKeyController.text.trim(),
    );

    await settingsProvider.completeSetup();
    
    // No explicit navigation needed as the root Consumer will rebuild 
    // and switch the home widget to ChatScreen when isFirstRun becomes false.
  }

  bool _canProceed() {
    if (_currentPage == 0) return true; // Selection is always valid (enum)
    if (_currentPage == 1) {
      if (_selectedApiProvider == ApiProvider.lmStudio) {
        return _lmStudioUrlController.text.isNotEmpty;
      } else {
        return _openRouterKeyController.text.isNotEmpty;
      }
    }
    // ComfyUI (Page 2) and Search (Page 3) are optional/have defaults
    return true; 
  }

    void _scanAndSelect(
    String title,
    Future<List<String>> Function({void Function(String) onProgress, void Function(String) onServerFound}) scanMethod,
    TextEditingController controller,
  ) {
    String statusText = 'Starting scan...';
    List<String> foundServers = [];
    bool isScanning = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          if (isScanning && foundServers.isEmpty && statusText == 'Starting scan...') {
            scanMethod(
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
                  statusText = foundServers.isEmpty ? 'No servers found' : 'Found ${foundServers.length} server(s)';
                });
              }
            });
          }
          
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.search, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                const Text('Scanning...'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isScanning)
                  const LinearProgressIndicator(),
                const SizedBox(height: 12),
                Text(statusText),
                if (foundServers.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text('Found servers:', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...foundServers.map((url) => InkWell(
                    onTap: () {
                      controller.text = url;
                      setState(() {});
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Connected', textAlign: TextAlign.center),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          width: 120,
                          backgroundColor: Colors.green,
                        ),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swipe
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildProviderSelectionPage(), // Step 1
                  _buildProviderConfigPage(),    // Step 2
                  _buildComfyUiPage(),           // Step 3
                  _buildSearchPage(),            // Step 4
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentPage > 0)
            TextButton(
              onPressed: _previousPage,
              child: const Text('Back'),
            )
          else
            const SizedBox.shrink(),
          
          ElevatedButton(
            onPressed: _canProceed() ? _nextPage : null,
            child: Text(_currentPage == 3 ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderSelectionPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to ChadGPT', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text('Choose your AI Logic Provider to get started.'),
          const SizedBox(height: 32),
          
          _buildSelectionCard(
            title: 'LM Studio',
            description: 'Connect to a local LM Studio server running on this machine or network.',
            isSelected: _selectedApiProvider == ApiProvider.lmStudio,
            onTap: () => setState(() => _selectedApiProvider = ApiProvider.lmStudio),
            icon: Icons.computer,
          ),
          const SizedBox(height: 16),
          _buildSelectionCard(
            title: 'OpenRouter',
            description: 'Use OpenRouter API to access various models in the cloud.',
            isSelected: _selectedApiProvider == ApiProvider.openRouter,
            onTap: () => setState(() => _selectedApiProvider = ApiProvider.openRouter),
            icon: Icons.cloud,
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionCard({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected ? BorderSide(color: colorScheme.primary, width: 2) : BorderSide.none,
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 32, color: isSelected ? colorScheme.primary : colorScheme.onSurfaceVariant),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected ? colorScheme.primary : null,
                    )),
                    const SizedBox(height: 4),
                    Text(description, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProviderConfigPage() {
    final isLmStudio = _selectedApiProvider == ApiProvider.lmStudio;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isLmStudio ? 'Configure LM Studio' : 'Configure OpenRouter', 
               style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 24),
          
          if (isLmStudio) ...[
            TextField(
              controller: _lmStudioUrlController,
              decoration: const InputDecoration(
                labelText: 'LM Studio Server URL',
                hintText: 'http://localhost:1234',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
             const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scanAndSelect('LM Studio', ApiService.scanLmStudioNetwork, _lmStudioUrlController),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Auto-detect LM Studio'),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Make sure your LM Studio server is running and accessible.', 
                       style: TextStyle(fontSize: 12, color: Colors.grey)),
          ] else ...[
            TextField(
              controller: _openRouterKeyController,
              decoration: const InputDecoration(
                labelText: 'OpenRouter API Key',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),
             const SizedBox(height: 8),
            const Text('Enter your OpenRouter API key to access models.', 
                       style: TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Widget _buildComfyUiPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Image Generation', style: Theme.of(context).textTheme.headlineSmall),
           const SizedBox(height: 8),
          const Text('Configure ComfyUI for local image generation. This step cannot be skipped, but you can leave it empty if you don\'t have a server.',),
          const SizedBox(height: 24),
          
          TextField(
            controller: _comfyUiUrlController,
            decoration: const InputDecoration(
              labelText: 'ComfyUI Server URL (Optional)',
              hintText: 'http://127.0.0.1:8188',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _scanAndSelect('ComfyUI', ComfyuiService.scanNetwork, _comfyUiUrlController),
              icon: const Icon(Icons.search, size: 18),
              label: const Text('Auto-detect ComfyUI'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchPage() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Search Provider', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            
            DropdownButtonFormField<SearchProvider>(
              value: _selectedSearchProvider,
              decoration: const InputDecoration(
                labelText: 'Select Search Provider',
                border: OutlineInputBorder(),
              ),
              items: const [
                 DropdownMenuItem(value: SearchProvider.searxng, child: Text('SearXNG (Self-hosted)')),
                 DropdownMenuItem(value: SearchProvider.brave, child: Text('Brave Search')),
                 DropdownMenuItem(value: SearchProvider.bing, child: Text('Bing Search')),
                 DropdownMenuItem(value: SearchProvider.google, child: Text('Google Search')),
                 DropdownMenuItem(value: SearchProvider.perplexity, child: Text('Perplexity AI')),
                 DropdownMenuItem(value: SearchProvider.none, child: Text('None')),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() => _selectedSearchProvider = value);
                }
              },
            ),
            const SizedBox(height: 16),
            _buildSearchConfigFields(),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchConfigFields() {
    switch (_selectedSearchProvider) {
      case SearchProvider.searxng:
        return Column(
          children: [
            TextField(
              controller: _searxngUrlController,
              decoration: const InputDecoration(
                labelText: 'SearXNG URL',
                hintText: 'https://searx.be',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _scanAndSelect('SearXNG', ApiService.scanSearxngNetwork, _searxngUrlController),
                icon: const Icon(Icons.search, size: 18),
                label: const Text('Auto-detect SearXNG'),
              ),
            ),
          ],
        );
      case SearchProvider.google:
        return Column(
          children: [
            TextField(
              controller: _googleApiKeyController,
              decoration: const InputDecoration(
                labelText: 'Google API Key',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _googleCxController,
              decoration: const InputDecoration(
                labelText: 'Google Custom Search Engine ID (CX)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        );
      case SearchProvider.bing:
        return TextField(
          controller: _bingApiKeyController,
          decoration: const InputDecoration(
            labelText: 'Bing Search API Key',
            border: OutlineInputBorder(),
          ),
        );
      case SearchProvider.brave:
        return TextField(
            controller: _braveApiKeyController,
            decoration: const InputDecoration(
                labelText: 'Brave Search API Key',
                border: OutlineInputBorder(),
            ),
        );
      case SearchProvider.perplexity:
        return TextField(
            controller: _perplexityApiKeyController,
            decoration: const InputDecoration(
                labelText: 'Perplexity API Key',
                border: OutlineInputBorder(),
            ),
        );
      case SearchProvider.none:
        return const SizedBox.shrink();
    }
  }
}
