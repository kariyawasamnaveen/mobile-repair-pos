import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_jobs_controller.dart';

class NewRepairJobScreen extends ConsumerStatefulWidget {
  const NewRepairJobScreen({super.key});

  @override
  ConsumerState<NewRepairJobScreen> createState() => _NewRepairJobScreenState();
}

class _NewRepairJobScreenState extends ConsumerState<NewRepairJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _deviceModelController = TextEditingController();
  final _deviceImeiController = TextEditingController();
  final _reportedIssueController = TextEditingController();
  final _deviceConditionController = TextEditingController();
  final _estimatedCostController = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _deviceModelController.dispose();
    _deviceImeiController.dispose();
    _reportedIssueController.dispose();
    _deviceConditionController.dispose();
    _estimatedCostController.dispose();
    super.dispose();
  }

  void _saveJob() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    final controller = ref.read(repairJobsControllerProvider);
    final res = await controller.createRepairJob(
      customerName: _customerNameController.text.trim(),
      customerPhone: _customerPhoneController.text.trim(),
      deviceModel: _deviceModelController.text.isEmpty ? null : _deviceModelController.text.trim(),
      deviceImei: _deviceImeiController.text.isEmpty ? null : _deviceImeiController.text.trim(),
      reportedIssue: _reportedIssueController.text.trim(),
      deviceConditionNotes: _deviceConditionController.text.trim(),
      estimatedCost: double.tryParse(_estimatedCostController.text),
    );

    if (!mounted) return;
    setState(() => _isSaving = false);

    res.match(
      (l) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l.message))),
      (r) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Repair Job created successfully')));
        Navigator.pop(context);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Repair Job')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _customerNameController,
              decoration: const InputDecoration(labelText: 'Customer Name *', border: OutlineInputBorder()),
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _customerPhoneController,
              decoration: const InputDecoration(labelText: 'Customer Phone *', border: OutlineInputBorder()),
              keyboardType: TextInputType.phone,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _deviceModelController,
              decoration: const InputDecoration(labelText: 'Device Model (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deviceImeiController,
              decoration: const InputDecoration(labelText: 'Device IMEI (Optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _reportedIssueController,
              decoration: const InputDecoration(labelText: 'Reported Issue *', border: OutlineInputBorder()),
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _deviceConditionController,
              decoration: const InputDecoration(labelText: 'Device Condition Notes *', border: OutlineInputBorder(), hintText: 'Scratches, powers on, missing parts...'),
              maxLines: 2,
              validator: (v) => v == null || v.isEmpty ? 'Required' : null,
            ),
            const Divider(height: 32),
            TextFormField(
              controller: _estimatedCostController,
              decoration: const InputDecoration(labelText: 'Estimated Cost (Optional)', border: OutlineInputBorder()),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),
            _isSaving
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
                    onPressed: _saveJob,
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('CREATE JOB', style: TextStyle(fontSize: 18)),
                  ),
          ],
        ),
      ),
    );
  }
}
