import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final _storeNameController = TextEditingController();

  @override
  void dispose() {
    _storeNameController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreName() async {
    final error = await ref.read(storeNameProvider.notifier).saveStoreName(_storeNameController.text);
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store name saved successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final storeNameState = ref.watch(storeNameProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: storeNameState.when(
        data: (storeName) {
          if (_storeNameController.text.isEmpty && storeName != null) {
            _storeNameController.text = storeName;
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _storeNameController,
                  decoration: const InputDecoration(
                    labelText: 'Store Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _saveStoreName,
                  child: const Text('Save'),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
