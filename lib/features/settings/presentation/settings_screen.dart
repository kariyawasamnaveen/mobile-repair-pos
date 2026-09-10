import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:pos_system/features/settings/presentation/settings_controller.dart';
import 'package:pos_system/features/reports/presentation/reports_dashboard_screen.dart';

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

  Future<void> _pickQrImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    
    if (pickedFile != null) {
      final docDir = await getApplicationDocumentsDirectory();
      final fileName = 'qr_payment_${DateTime.now().millisecondsSinceEpoch}${p.extension(pickedFile.path)}';
      final savedImage = await File(pickedFile.path).copy(p.join(docDir.path, fileName));
      
      if (!mounted) return;
      await ref.read(storeSettingsProvider.notifier).updateQrImagePath(savedImage.path);
    }
  }

  Future<void> _removeQrImage() async {
    await ref.read(storeSettingsProvider.notifier).updateQrImagePath(null);
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
              Card(
                elevation: 0,
                color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.5),
                child: ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Reports & Analytics', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('View sales, repairs, and inventory performance'),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ReportsDashboardScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const Text('Store Profile', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
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
              const Text('Payment QR Code', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              if (settings.qrPaymentImagePath != null && settings.qrPaymentImagePath!.isNotEmpty) ...[
                Center(
                  child: Image.file(
                    File(settings.qrPaymentImagePath!),
                    height: 200,
                    cacheHeight: 400,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => const Text('Error loading image'),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.edit),
                      label: const Text('Change'),
                      onPressed: _pickQrImage,
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.delete, color: Colors.red),
                      label: const Text('Remove', style: TextStyle(color: Colors.red)),
                      onPressed: _removeQrImage,
                    ),
                  ],
                ),
              ] else ...[
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  leading: const Icon(Icons.qr_code),
                  title: const Text('No QR Code configured'),
                  subtitle: const Text('Upload a static payment QR for customers to scan.'),
                  trailing: ElevatedButton(
                    onPressed: _pickQrImage,
                    child: const Text('Upload'),
                  ),
                ),
              ],
              
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
