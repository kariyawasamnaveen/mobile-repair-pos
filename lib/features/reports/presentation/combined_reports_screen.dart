import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pos_system/core/backup/backup_models.dart';
import 'package:pos_system/core/backup/backup_service.dart';
import 'package:pos_system/core/theme/app_theme.dart';
import 'package:pos_system/core/widgets/empty_state_widget.dart';

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
  
  String _getBranchDisplayName(String name, String installId) {
    final shortId = installId.length > 6 ? installId.substring(installId.length - 6) : installId;
    return '$name ($shortId)';
  }

  @override
  Widget build(BuildContext context) {
    final registryAsync = ref.watch(branchRegistryProvider);
    final selectedBranches = ref.watch(selectedBranchesProvider);
    final summariesAsync = ref.watch(combinedSummariesProvider(_currentMonthStr));
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Combined Branch Report'),
      ),
      body: registryAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Failed to load branches: $err')),
        data: (registry) {
          if (registry.isEmpty) {
            return const EmptyStateWidget(
              icon: Icons.cloud_off_outlined,
              title: 'No branch backups found',
              subtitle: 'Ensure your branches are backing up to Supabase.',
            );
          }

          return CustomScrollView(
            slivers: [
              // 1. Compact Warning Banner
              SliverToBoxAdapter(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  color: Colors.orange.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Showing $_currentMonthStr totals from last automatic backup (not real-time).',
                          style: TextStyle(color: Colors.orange.shade900, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // 2. Collapsible Branch Selection
              SliverToBoxAdapter(
                child: Theme(
                  data: theme.copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    title: Text(
                      '${selectedBranches.length} of ${registry.length} branches included',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text('Tap to change', style: TextStyle(fontSize: 12)),
                    children: registry.map((branch) {
                      final isSelected = selectedBranches.contains(branch.installId);
                      return CheckboxListTile(
                        title: Text(_getBranchDisplayName(branch.branchName, branch.installId)),
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
                    }).toList(),
                  ),
                ),
              ),
              
              const SliverToBoxAdapter(child: Divider(height: 1)),

              // 3. Summaries & Chart
              summariesAsync.when(
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32.0),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Center(child: Text('Error loading summaries: $err')),
                  ),
                ),
                data: (summaries) {
                  if (selectedBranches.isEmpty) {
                    return const SliverToBoxAdapter(
                      child: EmptyStateWidget(
                        icon: Icons.check_box_outline_blank,
                        title: 'No branches selected',
                        subtitle: 'Select at least one branch above to view combined reports.',
                      ),
                    );
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

                  // Find max sales for chart
                  double maxSales = 0;
                  for (final s in summaries) {
                    if (s.totalSalesRevenue > maxSales) {
                      maxSales = s.totalSalesRevenue;
                    }
                  }

                  return SliverList(
                    delegate: SliverChildListDelegate([
                      const SizedBox(height: AppThemeConstants.spacing24),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Combined Totals', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Row(
                          children: [
                            Expanded(child: _buildProminentSummaryCard('Sales', 'LKR ${totalSales.toStringAsFixed(2)}', theme.colorScheme.primary)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildProminentSummaryCard('Tax', 'LKR ${totalTax.toStringAsFixed(2)}', theme.colorScheme.tertiary)),
                            const SizedBox(width: 16),
                            Expanded(child: _buildProminentSummaryCard('Transactions', totalTransactions.toString(), theme.colorScheme.secondary)),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing32),
                      
                      // Chart
                      if (maxSales > 0) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Text('Sales Comparison', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: AppThemeConstants.spacing16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Card(
                            elevation: 0,
                            color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: theme.colorScheme.outlineVariant)),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                children: selectedBranches.map((id) {
                                  final summaryOpt = summaries.where((s) => s.installId == id).toList();
                                  if (summaryOpt.isEmpty) return const SizedBox.shrink();
                                  
                                  final summary = summaryOpt.first;
                                  final fraction = maxSales > 0 ? summary.totalSalesRevenue / maxSales : 0.0;
                                  
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 12.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                _getBranchDisplayName(summary.branchName, summary.installId),
                                                style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Text(
                                              'LKR ${summary.totalSalesRevenue.toStringAsFixed(2)}',
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        LayoutBuilder(
                                          builder: (context, constraints) {
                                            return Container(
                                              height: 12,
                                              width: constraints.maxWidth,
                                              decoration: BoxDecoration(
                                                color: theme.colorScheme.surfaceContainerHighest,
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: AnimatedContainer(
                                                  duration: const Duration(milliseconds: 500),
                                                  curve: Curves.easeOutCubic,
                                                  height: 12,
                                                  width: constraints.maxWidth * fraction,
                                                  decoration: BoxDecoration(
                                                    color: theme.colorScheme.primary,
                                                    borderRadius: BorderRadius.circular(6),
                                                  ),
                                                ),
                                              ),
                                            );
                                          }
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: AppThemeConstants.spacing32),
                      ],

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text('Detailed Breakdown', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing16),
                      
                      // Breakdown table
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text('Branch', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Sales', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Tax', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('Transactions', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: selectedBranches.map((id) {
                            final branchReg = registry.firstWhere((r) => r.installId == id, orElse: () => BranchRegistryEntry(installId: id, branchName: 'Unknown', lastBackupTimestamp: DateTime.now()));
                            final summaryOpt = summaries.where((s) => s.installId == id).toList();
                            
                            final displayName = _getBranchDisplayName(branchReg.branchName, id);
                            
                            if (summaryOpt.isEmpty) {
                              return DataRow(cells: [
                                DataCell(Text(displayName)),
                                const DataCell(Text('No data available', style: TextStyle(color: Colors.grey))),
                                const DataCell(Text('')),
                                const DataCell(Text('')),
                              ]);
                            }
                            
                            final summary = summaryOpt.first;
                            return DataRow(cells: [
                              DataCell(Text(_getBranchDisplayName(summary.branchName, summary.installId))),
                              DataCell(Text('LKR ${summary.totalSalesRevenue.toStringAsFixed(2)}')),
                              DataCell(Text('LKR ${summary.totalTaxCollected.toStringAsFixed(2)}')),
                              DataCell(Text(summary.totalTransactions.toString())),
                            ]);
                          }).toList(),
                        ),
                      ),
                      const SizedBox(height: AppThemeConstants.spacing32),
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

  Widget _buildProminentSummaryCard(String title, String value, Color color) {
    return Card(
      elevation: 3,
      shadowColor: color.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0, horizontal: 12.0),
        child: Column(
          children: [
            Text(
              title, 
              style: TextStyle(
                fontSize: 12, 
                fontWeight: FontWeight.w600, 
                color: Colors.grey.shade600,
                letterSpacing: 0.5,
              )
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value, 
                style: TextStyle(
                  fontSize: 22, 
                  fontWeight: FontWeight.w900,
                  color: color,
                )
              ),
            ),
          ],
        ),
      ),
    );
  }
}
