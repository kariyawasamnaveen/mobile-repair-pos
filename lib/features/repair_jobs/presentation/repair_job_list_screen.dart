import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/database/tables.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_jobs_controller.dart';
import 'package:pos_system/features/repair_jobs/presentation/new_repair_job_screen.dart';
import 'package:pos_system/features/repair_jobs/presentation/repair_job_detail_screen.dart';

class RepairJobListScreen extends ConsumerStatefulWidget {
  const RepairJobListScreen({super.key});

  @override
  ConsumerState<RepairJobListScreen> createState() => _RepairJobListScreenState();
}

class _RepairJobListScreenState extends ConsumerState<RepairJobListScreen> {
  String _filter = 'All';

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(repairJobsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Repair Jobs'),
        actions: [
          DropdownButton<String>(
            value: _filter,
            icon: const Icon(Icons.filter_list, color: Colors.white),
            dropdownColor: Colors.blueGrey,
            style: const TextStyle(color: Colors.white),
            underline: const SizedBox(),
            items: ['All', 'In Progress', 'Ready', 'Delivered']
                .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                .toList(),
            onChanged: (val) {
              if (val != null) setState(() => _filter = val);
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: jobsAsync.when(
        data: (jobs) {
          final filteredJobs = jobs.where((job) {
            if (_filter == 'All') return true;
            if (_filter == 'In Progress' && (job.status == RepairJobStatus.diagnosing || job.status == RepairJobStatus.inProgress || job.status == RepairJobStatus.awaitingCustomerApproval)) return true;
            if (_filter == 'Ready' && job.status == RepairJobStatus.readyForPickup) return true;
            if (_filter == 'Delivered' && job.status == RepairJobStatus.delivered) return true;
            return false;
          }).toList();

          if (filteredJobs.isEmpty) {
            return const Center(child: Text('No repair jobs found.'));
          }

          return ListView.builder(
            itemCount: filteredJobs.length,
            itemBuilder: (context, index) {
              final job = filteredJobs[index];
              final days = DateTime.now().difference(job.createdAt).inDays;
              
              return ListTile(
                title: Text('${job.jobNumber} - ${job.customerName}'),
                subtitle: Text('${job.deviceModel ?? 'Unknown Device'} • ${job.status.name} • ${days}d ago'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RepairJobDetailScreen(jobId: job.id)));
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const NewRepairJobScreen()));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
