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
  final _storeAddressController = TextEditingController();
  final _storePhoneController = TextEditingController();
  String _defaultReceiptDelivery = 'ask';

  @override
  void dispose() {
    _storeNameController.dispose();
    _storeAddressController.dispose();
    _storePhoneController.dispose();
    super.dispose();
  }

  Future<void> _saveStoreSettings() async {
    final error = await ref.read(storeSettingsProvider.notifier).saveStoreSettings(
      name: _storeNameController.text,
      address: _storeAddressController.text,
      phone: _storePhoneController.text,
      defaultReceiptDelivery: _defaultReceiptDelivery,
    );
    if (!mounted) return;
    
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Store settings saved successfully!')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(storeSettingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: settingsState.when(
        data: (settings) {
          if (_storeNameController.text.isEmpty && settings.name != null) {
            _storeNameController.text = settings.name!;
          }
          if (_storeAddressController.text.isEmpty && settings.address != null) {
            _storeAddressController.text = settings.address!;
          }
          if (_storePhoneController.text.isEmpty && settings.phone != null) {
            _storePhoneController.text = settings.phone!;
          }
          if (settings.defaultReceiptDelivery != null) {
            _defaultReceiptDelivery = settings.defaultReceiptDelivery!;
          }
          
          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              TextField(
                controller: _storeNameController,
                decoration: const InputDecoration(
                  labelText: 'Store Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _storeAddressController,
                decoration: const InputDecoration(
                  labelText: 'Store Address',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _storePhoneController,
                decoration: const InputDecoration(
                  labelText: 'Store Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _defaultReceiptDelivery,
                decoration: const InputDecoration(
                  labelText: 'Default Receipt Delivery',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'ask', child: Text('Ask each time')),
                  DropdownMenuItem(value: 'print', child: Text('Print by default')),
                  DropdownMenuItem(value: 'sms', child: Text('SMS by default')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _defaultReceiptDelivery = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveStoreSettings,
                child: const Text('Save'),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error: $error')),
      ),
    );
  }
}
