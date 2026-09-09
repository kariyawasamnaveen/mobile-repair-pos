import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/inventory/domain/item.dart';
import 'package:pos_system/features/inventory/presentation/inventory_controller.dart';
import 'package:pos_system/core/database/tables.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  final Item item;

  const StockAdjustmentScreen({super.key, required this.item});

  @override
  ConsumerState<StockAdjustmentScreen> createState() => _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  MovementReason _reason = MovementReason.restock;
  
  // For phones, adjusting stock means adding or removing IMEIs
  final List<String> _imeisToAdd = [];
  final List<String> _imeisToRemove = [];
  final _imeiController = TextEditingController();

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    final isPhone = widget.item.category == ItemCategory.phone;
    
    final amount = isPhone 
        ? _imeisToAdd.length - _imeisToRemove.length 
        : int.parse(_amountController.text);
        
    final error = await ref.read(inventoryControllerProvider.notifier).adjustStock(
      widget.item.id,
      amount,
      _reason,
      imeisToAdd: _imeisToAdd,
      imeisToRemove: _imeisToRemove,
    );

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
    final isPhone = widget.item.category == ItemCategory.phone;

    return Scaffold(
      appBar: AppBar(title: Text('Adjust Stock: ${widget.item.name}')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Current Stock: ${widget.item.quantity}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<MovementReason>(
              initialValue: _reason,
              items: MovementReason.values.map((r) {
                return DropdownMenuItem(value: r, child: Text(r.name.toUpperCase()));
              }).toList(),
              onChanged: (val) {
                if (val != null) setState(() => _reason = val);
              },
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
            
            if (!isPhone)
              TextFormField(
                controller: _amountController,
                decoration: const InputDecoration(labelText: 'Adjustment Amount (+/-)'),
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                validator: (val) => val == null || int.tryParse(val) == null ? 'Invalid number' : null,
              ),

            if (isPhone) ...[
              const SizedBox(height: 16),
              const Text('Add New IMEIs:'),
              ..._imeisToAdd.map((imei) => ListTile(
                title: Text(imei),
                trailing: IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () => setState(() => _imeisToAdd.remove(imei)),
                ),
              )),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _imeiController,
                      decoration: const InputDecoration(labelText: 'Type IMEI to ADD'),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add),
                    onPressed: () {
                      if (_imeiController.text.isNotEmpty) {
                        setState(() {
                          _imeisToAdd.add(_imeiController.text);
                          _imeiController.clear();
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Available IMEIs (Select to mark as Sold/Removed):'),
              ...widget.item.imeis.map((imei) {
                final isSelectedToRemove = _imeisToRemove.contains(imei);
                return CheckboxListTile(
                  title: Text(imei),
                  value: isSelectedToRemove,
                  onChanged: (val) {
                    setState(() {
                      if (val == true) {
                        _imeisToRemove.add(imei);
                      } else {
                        _imeisToRemove.remove(imei);
                      }
                    });
                  },
                );
              }),
            ],

            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _submit,
              child: const Text('Save Adjustment'),
            ),
          ],
        ),
      ),
    );
  }
}
