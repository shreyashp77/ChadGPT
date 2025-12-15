import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/local_model.dart';
import '../services/huggingface_service.dart';
import '../services/local_model_service.dart';
import '../services/database_service.dart';
import '../utils/theme.dart';

/// Screen for browsing, downloading, and managing local GGUF models
class LocalModelsScreen extends StatefulWidget {
  const LocalModelsScreen({super.key});

  @override
  State<LocalModelsScreen> createState() => _LocalModelsScreenState();
}

class _LocalModelsScreenState extends State<LocalModelsScreen> {
  final HuggingFaceService _hfService = HuggingFaceService();
  final LocalModelService _localModelService = LocalModelService();
  final DatabaseService _dbService = DatabaseService();
  
  List<LocalModel> _downloadedModels = [];
  List<LocalModel> _availableModels = [];
  bool _isLoading = true;
  String? _error;
  String? _processingModelId;
  
  // Stream subscriptions for active downloads
  final Map<String, dynamic> _downloadSubscriptions = {};
  
  // Local UI state for progress (synced from service)
  final Map<String, double> _downloadProgress = {};

  @override
  void initState() {
    super.initState();
    _loadModels();
  }

  Future<void> _loadModels() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load downloaded models from database
      final downloaded = await _dbService.getLocalModels();
      
      // Verify each model's actual download status
      for (var model in downloaded) {
        final isActuallyDownloaded = await _localModelService.isModelDownloaded(model);
        if (isActuallyDownloaded && model.status != LocalModelStatus.downloaded) {
          model = model.copyWith(status: LocalModelStatus.downloaded);
          await _dbService.updateLocalModel(model);
        }
      }
      
      // Get curated available models
      final available = _hfService.getCuratedModels();
      
      // Filter out models that are in the database (any status) from available list
      final downloadedIds = downloaded.map((m) => m.id).toSet();
      final filteredAvailable = available.where((m) => !downloadedIds.contains(m.id)).toList();
      
      // Separate models by status - include downloading models
      final downloadedOrLoaded = downloaded.where((m) => 
        m.status == LocalModelStatus.downloaded || 
        m.status == LocalModelStatus.loaded
      ).toList();
      
      final downloadingModels = downloaded.where((m) => 
        m.status == LocalModelStatus.downloading
      ).toList();
      
      // Subscribe to active downloads from service
      for (var model in downloadingModels) {
        // Sync progress from service
        _downloadProgress[model.id] = _localModelService.getProgress(model.id);
        
        // Subscribe to ongoing download if active
        final stream = _localModelService.getProgressStream(model.id);
        if (stream != null && !_downloadSubscriptions.containsKey(model.id)) {
          _subscribeToDownload(model, stream);
        }
      }
      
      setState(() {
        _downloadedModels = [...downloadedOrLoaded, ...downloadingModels];
        _availableModels = filteredAvailable;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load models: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _downloadModel(LocalModel model) async {
    // Save model to database with downloading status
    final downloadingModel = model.copyWith(
      status: LocalModelStatus.downloading,
      createdAt: DateTime.now(),
    );
    await _dbService.insertLocalModel(downloadingModel);
    
    // Start background download via service
    final stream = _localModelService.downloadModel(model);
    
    // Subscribe to progress updates
    _subscribeToDownload(model, stream);
    
    // Refresh UI to show downloading state
    await _loadModels();
  }
  
  void _subscribeToDownload(LocalModel model, Stream<double> stream) {
    // Cancel any existing subscription
    _downloadSubscriptions[model.id]?.cancel();
    
    final subscription = stream.listen(
      (progress) {
        if (mounted) {
          setState(() {
            _downloadProgress[model.id] = progress;
          });
        }
      },
      onDone: () async {
        // Download completed
        final path = await _localModelService.getModelPath(model);
        final completedModel = model.copyWith(
          status: LocalModelStatus.downloaded,
          localPath: path,
          createdAt: DateTime.now(),
        );
        await _dbService.updateLocalModel(completedModel);
        
        _downloadSubscriptions.remove(model.id);
        _downloadProgress.remove(model.id);
        
        if (mounted) {
          await _loadModels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${model.name} downloaded successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      onError: (e) async {
        // Download failed
        final errorModel = model.copyWith(status: LocalModelStatus.error);
        await _dbService.updateLocalModel(errorModel);
        
        _downloadSubscriptions.remove(model.id);
        _downloadProgress.remove(model.id);
        
        if (mounted) {
          await _loadModels();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to download: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      },
    );
    
    _downloadSubscriptions[model.id] = subscription;
  }

  Future<void> _cancelDownload(LocalModel model) async {
    // Cancel the download in service
    _localModelService.cancelDownload(model.id);
    
    // Cancel subscription
    _downloadSubscriptions[model.id]?.cancel();
    _downloadSubscriptions.remove(model.id);
    _downloadProgress.remove(model.id);
    
    // Remove from database
    await _dbService.deleteLocalModel(model.id);
    
    // Delete partial file if exists
    await _localModelService.deleteModel(model);
    
    // Refresh the model lists
    await _loadModels();
  }

  Future<void> _unloadModel(LocalModel model) async {
    setState(() {
      _processingModelId = model.id;
    });

    try {
      await _localModelService.unloadModel();
      if (mounted) {
        setState(() {});  // Refresh UI to show model as no longer active
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingModelId = null;
        });
      }
    }
  }

  Future<void> _deleteModel(LocalModel model) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Model'),
        content: Text('Are you sure you want to delete ${model.name}?\n\nThis will free up ${model.sizeString} of storage.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _localModelService.deleteModel(model);
      await _dbService.deleteLocalModel(model.id);
      await _loadModels();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${model.name} deleted'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadAndUseModel(LocalModel model) async {
    setState(() {
      _processingModelId = model.id;
    });

    try {
      final success = await _localModelService.loadModel(model);
      
      if (success) {
        // Update status in database
        final loadedModel = model.copyWith(status: LocalModelStatus.loaded);
        await _dbService.updateLocalModel(loadedModel);
        await _loadModels();

        if (mounted) {
          // Previously showed snackbar and navigated back
          // Now just strictly updating state (already handled by _loadModels)
        }
      } else {
        if (mounted) {
          // Keep error snackbar? User said "these pills", implying success ones.
          // But usually we want to see errors.
          // The prompt says "these pills still show up, remove them". The context is the big green/orange ones.
          // I'll keep errors for now as they are critical feedback, but maybe style them less intrusively?
          // Actually, "remove them" probably refers to the ones we just styled.
          // I will remove the success ones.
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to load model'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingModelId = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Local Models'),
        backgroundColor: theme.colorScheme.surface,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                      const SizedBox(height: 16),
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _loadModels,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadModels,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // Info banner
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.blue.withValues(alpha: 0.2)
                              : Colors.blue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.blue.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blue[300]),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'Models run entirely on your device. Smaller models are faster but may be less capable.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(duration: 300.ms),
                      
                      const SizedBox(height: 24),
                      
                      // Downloaded models section
                      if (_downloadedModels.isNotEmpty) ...[
                        _buildSectionHeader(
                          'Downloaded Models',
                          Icons.download_done,
                          theme,
                        ),
                        const SizedBox(height: 12),
                        ..._downloadedModels.map((model) => _buildModelCard(
                          model,
                          isDownloaded: true,
                          theme: theme,
                          isDark: isDark,
                        )),
                        const SizedBox(height: 24),
                      ],
                      
                      // Available models section
                      _buildSectionHeader(
                        'Available Models',
                        Icons.cloud_download_outlined,
                        theme,
                      ),
                      const SizedBox(height: 12),
                      ..._availableModels.map((model) => _buildModelCard(
                        model,
                        isDownloaded: false,
                        theme: theme,
                        isDark: isDark,
                      )),
                      
                      if (_availableModels.isEmpty && _downloadedModels.isEmpty)
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.download_for_offline_outlined,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No models available',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      
                      const SizedBox(height: 80), // Bottom padding
                    ],
                  ),
                ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, ThemeData theme) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
      ],
    );
  }

  Widget _buildModelCard(
    LocalModel model, {
    required bool isDownloaded,
    required ThemeData theme,
    required bool isDark,
  }) {
    final isCurrentlyDownloading = _localModelService.isDownloading(model.id) || 
                                   _downloadProgress.containsKey(model.id);
    final progress = _downloadProgress[model.id] ?? _localModelService.getProgress(model.id);
    final isLoaded = _localModelService.loadedModel?.id == model.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: isLoaded 
            ? Border.all(color: Colors.green, width: 2)
            : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                // Model icon
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isDownloaded
                        ? Colors.green.withValues(alpha: 0.2)
                        : Colors.blue.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    isDownloaded ? Icons.smart_toy : Icons.cloud_download,
                    color: isDownloaded ? Colors.green : Colors.blue,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                
                // Model name and info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              model.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (isLoaded)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.green,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          _buildInfoChip(
                            model.quantization ?? 'GGUF',
                            Colors.purple,
                          ),
                          const SizedBox(width: 6),
                          _buildInfoChip(
                            model.sizeString,
                            Colors.orange,
                          ),
                          if (model.parameters != null) ...[
                            const SizedBox(width: 6),
                            _buildInfoChip(
                              model.parametersString,
                              Colors.teal,
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            // Description
            if (model.description != null) ...[
              const SizedBox(height: 12),
              Text(
                model.description!,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
            
            // Progress bar (when downloading)
            if (isCurrentlyDownloading) ...[
              const SizedBox(height: 16),
              Column(
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Downloading... ${(progress * 100).toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                        ),
                      ),
                      TextButton(
                        onPressed: () => _cancelDownload(model),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red[400],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            
            // Action buttons
            if (!isCurrentlyDownloading) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (isDownloaded) ...[
                    // Delete button
                    TextButton.icon(
                      onPressed: () => _deleteModel(model),
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Delete'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red[400],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Use/Unload button - toggles based on load state
                    ElevatedButton.icon(
                      onPressed: isCurrentlyDownloading || _processingModelId != null 
                          ? null // Disable while processing
                          : (isLoaded 
                              ? () => _unloadModel(model) 
                              : () => _loadAndUseModel(model)),
                      icon: _processingModelId == model.id 
                          ? const SizedBox(
                              width: 18, 
                              height: 18, 
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Icon(
                              isLoaded ? Icons.eject : Icons.play_arrow,
                              size: 18,
                            ),
                      label: Text(
                        _processingModelId == model.id 
                            ? (isLoaded ? 'Unloading...' : 'Loading...') 
                            : (isLoaded ? 'Unload' : 'Use'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isLoaded 
                            ? Colors.orange 
                            : Colors.green,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ] else ...[
                    // Download button
                    ElevatedButton.icon(
                      onPressed: () => _downloadModel(model),
                      icon: const Icon(Icons.download, size: 18),
                      label: const Text('Download'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn(duration: 200.ms).slideX(begin: 0.05, end: 0);
  }

  Widget _buildInfoChip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: color,
        ),
      ),
    );
  }
}
