import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/core/scanning/camera_scanner_sheet.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';

class AddItemScreen extends ConsumerStatefulWidget {
  const AddItemScreen({super.key});

  @override
  ConsumerState<AddItemScreen> createState() => _AddItemScreenState();
}

class _AddItemScreenState extends ConsumerState<AddItemScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _purchaseController = TextEditingController();
  final _sellingController = TextEditingController();
  final _qtyController = TextEditingController(text: '0');
  final _reorderController = TextEditingController(text: '5');
  final _barcodeController = TextEditingController();
  ItemCategory _category = ItemCategory.other;

  // Barcode scanner buffer
  final _focusNode = FocusNode();
  String _scanBuffer = '';

  // Phone specifics
  final List<String> _imeis = [];
  final _imeiController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (_scanBuffer.isNotEmpty) {
        setState(() {
          _barcodeController.text = _scanBuffer;
          _scanBuffer = '';
        });
      }
    } else {
      final char = event.character;
      if (char != null) _scanBuffer += char;
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final isPhone = _category == ItemCategory.phone;
    if (isPhone && _imeis.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please add at least one IMEI for phones')));
      return;
    }

    final item = Item(
      id: '', // Will be generated
      name: _nameController.text,
      internalCode: '', // Will be generated
      barcode: _barcodeController.text.isEmpty ? null : _barcodeController.text,
      category: _category,
      purchasePrice: double.parse(_purchaseController.text),
      sellingPrice: double.parse(_sellingController.text),
      quantity: isPhone ? _imeis.length : int.parse(_qtyController.text),
      reorderLevel: int.parse(_reorderController.text),
      imeis: _imeis,
    );

    final error = await ref.read(inventoryControllerProvider.notifier).addItem(item);
    
    if (mounted) {
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      } else {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPhone = _category == ItemCategory.phone;

    return KeyboardListener(
      focusNode: _focusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        appBar: AppBar(title: const Text('Add Item')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Item Name *'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _barcodeController,
                      decoration: const InputDecoration(labelText: 'Barcode (Scan or Type)'),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Scan with camera',
                    icon: const Icon(Icons.qr_code_scanner),
                    onPressed: () async {
                      final result = await showCameraScannerSheet(context);
                      if (result != null) {
                        setState(() => _barcodeController.text = result);
                      }
                    },
                  ),
                ],
              ),
              DropdownButtonFormField<ItemCategory>(
                initialValue: _category,
                items: ItemCategory.values.map((c) => DropdownMenuItem(value: c, child: Text(c.name.toUpperCase()))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _category = val);
                },
                decoration: const InputDecoration(labelText: 'Category *'),
              ),
              TextFormField(
                controller: _purchaseController,
                decoration: const InputDecoration(labelText: 'Purchase Price *'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid number' : null,
              ),
              TextFormField(
                controller: _sellingController,
                decoration: const InputDecoration(labelText: 'Selling Price *'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid number' : null,
              ),
              
              if (!isPhone) ...[
                TextFormField(
                  controller: _qtyController,
                  decoration: const InputDecoration(labelText: 'Initial Quantity *'),
                  keyboardType: TextInputType.number,
                  validator: (val) => val == null || int.tryParse(val) == null ? 'Invalid number' : null,
                ),
              ],
              
              TextFormField(
                controller: _reorderController,
                decoration: const InputDecoration(labelText: 'Reorder Level *'),
                keyboardType: TextInputType.number,
                validator: (val) => val == null || int.tryParse(val) == null ? 'Invalid number' : null,
              ),

              if (isPhone) ...[
                const SizedBox(height: 16),
                const Text('IMEIs', style: TextStyle(fontWeight: FontWeight.bold)),
                ..._imeis.map((imei) => ListTile(
                  title: Text(imei),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => setState(() => _imeis.remove(imei)),
                  ),
                )),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _imeiController,
                        decoration: const InputDecoration(labelText: 'Type or Scan IMEI'),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Scan IMEI with camera',
                      icon: const Icon(Icons.qr_code_scanner),
                      onPressed: () async {
                        final result = await showCameraScannerSheet(context);
                        if (result != null && mounted) {
                          setState(() {
                            _imeis.add(result);
                          });
                        }
                      },
                    ),
                    IconButton(
                      tooltip: 'Add typed IMEI',
                      icon: const Icon(Icons.add),
                      onPressed: () {
                        if (_imeiController.text.isNotEmpty) {
                          setState(() {
                            _imeis.add(_imeiController.text);
                            _imeiController.clear();
                          });
                        }
                      },
                    ),
                  ],
                ),
              ],
              
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _submit,
                child: const Text('Save Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
