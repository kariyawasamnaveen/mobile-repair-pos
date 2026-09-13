import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/discount/domain/discount_rule.dart';
import 'package:pos_system/features/discount/presentation/discount_controller.dart';
import 'package:pos_system/core/theme/app_theme.dart';

class DiscountRulesScreen extends ConsumerWidget {
  const DiscountRulesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rulesAsync = ref.watch(allDiscountRulesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discount & Promotions'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddRuleDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Rule'),
      ),
      body: rulesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (rules) {
          if (rules.isEmpty) {
            return const Center(child: Text('No discount rules configured.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: rules.length,
            itemBuilder: (context, index) {
              final rule = rules[index];
              return _buildRuleCard(context, ref, rule);
            },
          );
        },
      ),
    );
  }

  Widget _buildRuleCard(BuildContext context, WidgetRef ref, DiscountRule rule) {
    final dateFormat = DateFormat('MMM d, yyyy');
    final isExpired = rule.endDate != null && rule.endDate!.isBefore(DateTime.now());
    final statusColor = !rule.isActive || isExpired ? Colors.grey : AppTheme.successColor;
    final statusText = !rule.isActive ? 'Inactive' : (isExpired ? 'Expired' : 'Active');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Row(
          children: [
            Expanded(
              child: Text(
                rule.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusColor.withValues(alpha: 0.5)),
              ),
              child: Text(
                statusText,
                style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Discount: ${rule.type == DiscountType.percentage ? '${rule.value.toStringAsFixed(0)}%' : 'LKR ${rule.value.toStringAsFixed(2)}'}',
                style: const TextStyle(color: Colors.white70),
              ),
              Text(
                'Scope: ${rule.scope.name}${rule.scopeReference != null ? ' (${rule.scopeReference})' : ''}',
                style: const TextStyle(color: Colors.white70),
              ),
              if (rule.minPurchaseAmount != null)
                Text(
                  'Min. Purchase: LKR ${rule.minPurchaseAmount!.toStringAsFixed(2)}',
                  style: const TextStyle(color: Colors.white70),
                ),
              if (rule.startDate != null || rule.endDate != null)
                Text(
                  'Valid: ${rule.startDate != null ? dateFormat.format(rule.startDate!) : 'Always'} - ${rule.endDate != null ? dateFormat.format(rule.endDate!) : 'Forever'}',
                  style: const TextStyle(color: Colors.white70),
                ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) async {
            if (value == 'deactivate') {
              final error = await ref.read(discountRulesControllerProvider.notifier).deactivateRule(rule.id);
              if (error != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
              }
            }
          },
          itemBuilder: (context) => [
            if (rule.isActive)
              const PopupMenuItem(
                value: 'deactivate',
                child: Text('Deactivate'),
              ),
          ],
        ),
      ),
    );
  }

  void _showAddRuleDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => const _AddDiscountRuleDialog(),
    );
  }
}

class _AddDiscountRuleDialog extends ConsumerStatefulWidget {
  const _AddDiscountRuleDialog();

  @override
  ConsumerState<_AddDiscountRuleDialog> createState() => _AddDiscountRuleDialogState();
}

class _AddDiscountRuleDialogState extends ConsumerState<_AddDiscountRuleDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _valueController = TextEditingController();
  final _scopeRefController = TextEditingController();
  final _minPurchaseController = TextEditingController();

  DiscountType _type = DiscountType.percentage;
  DiscountScope _scope = DiscountScope.entireSale;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void dispose() {
    _nameController.dispose();
    _valueController.dispose();
    _scopeRefController.dispose();
    _minPurchaseController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context, bool isStart) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = ref.watch(discountRulesControllerProvider).isLoading;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return AlertDialog(
      title: const Text('New Discount Rule'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Rule Name'),
                validator: (val) => val == null || val.isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DiscountType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'Discount Type'),
                items: DiscountType.values.map((t) {
                  return DropdownMenuItem(value: t, child: Text(t.name));
                }).toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _valueController,
                decoration: InputDecoration(labelText: _type == DiscountType.percentage ? 'Percentage (0-100)' : 'Amount (LKR)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Required';
                  final numVal = double.tryParse(val);
                  if (numVal == null || numVal < 0) return 'Invalid amount';
                  if (_type == DiscountType.percentage && numVal > 100) return 'Max 100%';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<DiscountScope>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'Scope'),
                items: DiscountScope.values.map((s) {
                  return DropdownMenuItem(value: s, child: Text(s.name));
                }).toList(),
                onChanged: (val) => setState(() => _scope = val!),
              ),
              if (_scope != DiscountScope.entireSale) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _scopeRefController,
                  decoration: InputDecoration(labelText: _scope == DiscountScope.specificCategory ? 'Category Name' : 'Item ID'),
                  validator: (val) => val == null || val.isEmpty ? 'Required' : null,
                ),
              ],
              const SizedBox(height: 16),
              TextFormField(
                controller: _minPurchaseController,
                decoration: const InputDecoration(labelText: 'Min Purchase Amount (Optional)'),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                validator: (val) {
                  if (val != null && val.isNotEmpty && double.tryParse(val) == null) {
                    return 'Invalid amount';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectDate(context, true),
                      child: Text(_startDate == null ? 'Start Date' : dateFormat.format(_startDate!)),
                    ),
                  ),
                  if (_startDate != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _startDate = null)),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _selectDate(context, false),
                      child: Text(_endDate == null ? 'End Date' : dateFormat.format(_endDate!)),
                    ),
                  ),
                  if (_endDate != null)
                    IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _endDate = null)),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: isLoading
              ? null
              : () async {
                  if (_formKey.currentState!.validate()) {
                    if (_startDate != null && _endDate != null && _endDate!.isBefore(_startDate!)) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('End date must be after start date')));
                      return;
                    }
                    
                    final error = await ref.read(discountRulesControllerProvider.notifier).createRule(
                      name: _nameController.text,
                      type: _type,
                      value: double.parse(_valueController.text),
                      scope: _scope,
                      scopeReference: _scope == DiscountScope.entireSale ? null : _scopeRefController.text,
                      minPurchaseAmount: double.tryParse(_minPurchaseController.text),
                      startDate: _startDate,
                      endDate: _endDate,
                    );
                    
                    if (context.mounted) {
                      if (error != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
                      } else {
                        Navigator.pop(context);
                      }
                    }
                  }
                },
          child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Save'),
        ),
      ],
    );
  }
}
