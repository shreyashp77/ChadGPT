import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';

class CreatePersonaDialog extends StatefulWidget {
  final Function(String name, String description, String prompt) onCreate;

  const CreatePersonaDialog({super.key, required this.onCreate});

  @override
  State<CreatePersonaDialog> createState() => _CreatePersonaDialogState();
}

class _CreatePersonaDialogState extends State<CreatePersonaDialog> {
  final _nameController = TextEditingController();
  final _descController = TextEditingController();
  final _promptController = TextEditingController();
  bool _isEnhancing = false;

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _promptController.dispose();
    super.dispose();
  }

  Future<void> _enhancePrompt() async {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();
    final prompt = _promptController.text.trim();

    if (name.isEmpty && desc.isEmpty && prompt.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter name, description, or draft prompt first.')));
        return;
    }

    setState(() => _isEnhancing = true);

    try {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        final apiService = settingsProvider.apiService;
        final modelId = settingsProvider.settings.selectedModelId ?? 'local-model'; // Fallback
        
        final enhanced = await apiService.enhancePrompt(name, desc, prompt, modelId);
        if(mounted) {
          setState(() {
              _promptController.text = enhanced;
          });
        }
    } catch (e) {
        if(mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Enhance failed: $e')));
        }
    } finally {
        if(mounted) setState(() => _isEnhancing = false);
    }
  }

  void _submit() {
    if (_nameController.text.trim().isEmpty || _promptController.text.trim().isEmpty) {
       return;
    }
    
    widget.onCreate(
        _nameController.text.trim(),
        _descController.text.trim(),
        _promptController.text.trim(),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      title: Text('Create New Persona', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Name',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                hintText: 'e.g. Math Tutor',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _descController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              decoration: InputDecoration(
                labelText: 'Description',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                hintText: 'Short description of what it does',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              maxLines: 8,
              decoration: InputDecoration(
                labelText: 'System Prompt',
                labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7)),
                hintText: 'You are a helpful assistant who...',
                hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
                border: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3))),
                focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
                suffixIcon: IconButton(
                    icon: _isEnhancing 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                        : const Icon(Icons.auto_awesome, color: Colors.amber),
                    tooltip: 'Enhance with AI',
                    onPressed: _isEnhancing ? null : () {
                        HapticFeedback.mediumImpact(); // Haptic for magic
                        _enhancePrompt();
                    },
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
              HapticFeedback.lightImpact(); // Haptic
              Navigator.of(context).pop();
          },
          child: Text('Cancel', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.54))),
        ),
        ElevatedButton(
          onPressed: () {
              HapticFeedback.lightImpact(); // Haptic
              _submit();
          },
          style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.primary, foregroundColor: Theme.of(context).colorScheme.onPrimary),
          child: const Text('Create'),
        ),
      ],
    );
  }
}
