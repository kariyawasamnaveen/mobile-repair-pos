import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/backup/backup_models.dart';
import 'package:pos_system/core/backup/backup_service.dart';

final branchRegistryProvider = FutureProvider<List<BranchRegistryEntry>>((ref) async {
  final service = ref.watch(backupServiceProvider);
  final res = await service.fetchRegistry();
  return res.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

final selectedBranchesProvider = StateProvider<Set<String>>((ref) => {});

final combinedSummariesProvider = FutureProvider.family<List<BranchSummary>, String>((ref, month) async {
  final service = ref.watch(backupServiceProvider);
  final selectedIds = ref.watch(selectedBranchesProvider).toList();
  if (selectedIds.isEmpty) return [];
  
  final res = await service.fetchSummaries(month, selectedIds);
  return res.fold(
    (l) => throw Exception(l.message),
    (r) => r,
  );
});

class CombinedReportsScreen extends ConsumerStatefulWidget {
  const CombinedReportsScreen({super.key});

  @override
  ConsumerState<CombinedReportsScreen> createState() => _CombinedReportsScreenState();
}

class _CombinedReportsScreenState extends ConsumerState<CombinedReportsScreen> {
  late String _currentMonthStr;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _currentMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    
    // Automatically select all branches once registry loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(branchRegistryProvider.future).then((registry) {
        if (mounted) {
          ref.read(selectedBranchesProvider.notifier).state = 
              registry.map((e) => e.installId).toSet();
        }
      }).catchError((_) {}); // Handle silently, UI will show error
    });
  }

  @override
  Widget build(BuildContext context) {
    final registryAsync = ref.watch(branchRegistryProvider);
    final selectedBranches = ref.watch(selectedBranchesProvider);
    final summariesAsync = ref.watch(combinedSummariesProvider(_currentMonthStr));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combined Branch Report'),
      ),
      body: registryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load branches: $err')),
        data: (registry) {
          if (registry.isEmpty) {
            return const Center(child: Text('No branch backups found in Supabase.'));
          }

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange.shade800),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Combined report reflects each branch\'s last automatic backup (daily) — not real-time. '
                            'Only summary totals are combined for the current month ($_currentMonthStr).',
                            style: TextStyle(color: Colors.orange.shade900),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Branch Selection
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text('Include Branches', style: Theme.of(context).textTheme.titleLarge),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final branch = registry[index];
                    final isSelected = selectedBranches.contains(branch.installId);
                    
                    return CheckboxListTile(
                      title: Text(branch.branchName),
                      subtitle: Text('Last backup: ${branch.lastBackupTimestamp.toString().split('.')[0]}'),
                      value: isSelected,
                      onChanged: (val) {
                        final current = Set<String>.from(selectedBranches);
                        if (val == true) {
                          current.add(branch.installId);
                        } else {
                          current.remove(branch.installId);
                        }
                        ref.read(selectedBranchesProvider.notifier).state = current;
                      },
                    );
                  },
                  childCount: registry.length,
                ),
              ),
              
              const SliverToBoxAdapter(child: Divider(height: 32)),

              // Summaries
              summariesAsync.when(
                loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                error: (err, _) => SliverToBoxAdapter(child: Center(child: Text('Error loading summaries: $err'))),
                data: (summaries) {
                  if (selectedBranches.isEmpty) {
                    return const SliverToBoxAdapter(child: Center(child: Text('Select at least one branch')));
                  }

                  // Aggregate totals
                  double totalSales = 0;
                  double totalTax = 0;
                  int totalTransactions = 0;
                  
                  for (final s in summaries) {
                    totalSales += s.totalSalesRevenue;
                    totalTax += s.totalTaxCollected;
                    totalTransactions += s.totalTransactions;
                  }

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Combined Totals', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(child: _buildSummaryCard('Sales', 'LKR ${totalSales.toStringAsFixed(2)}')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryCard('Tax', 'LKR ${totalTax.toStringAsFixed(2)}')),
                            const SizedBox(width: 16),
                            Expanded(child: _buildSummaryCard('Transactions', totalTransactions.toString())),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Branch Breakdown', style: Theme.of(context).textTheme.titleLarge),
                      ),
                      const SizedBox(height: 16),
                      // Breakdown table
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Branch')),
                            DataColumn(label: Text('Sales')),
                            DataColumn(label: Text('Tax')),
                            DataColumn(label: Text('Transactions')),
                          ],
                          rows: selectedBranches.map((id) {
                            final branchReg = registry.firstWhere((r) => r.installId == id, orElse: () => BranchRegistryEntry(installId: id, branchName: 'Unknown', lastBackupTimestamp: DateTime.now()));
                            final summaryOpt = summaries.where((s) => s.installId == id).toList();
                            
                            if (summaryOpt.isEmpty) {
                              return DataRow(cells: [
                                DataCell(Text(branchReg.branchName)),
                                const DataCell(Text('No data available', style: TextStyle(color: Colors.grey))),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                              ]);
                            }
                            
                            final summary = summaryOpt.first;
                            return DataRow(cells: [
                              DataCell(Text(summary.branchName)),
                              DataCell(Text('LKR ${summary.totalSalesRevenue.toStringAsFixed(2)}')),
                              DataCell(Text('LKR ${summary.totalTaxCollected.toStringAsFixed(2)}')),
                              DataCell(Text(summary.totalTransactions.toString())),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: 40),
                    ]),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(title, style: const TextStyle(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
