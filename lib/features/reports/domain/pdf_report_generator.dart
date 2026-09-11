import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fpdart/fpdart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/reports/data/reports_repository.dart';
import 'package:pos_system/features/settings/data/settings_repository.dart';
import 'package:pos_system/features/reports/domain/reports_models.dart';
import 'package:intl/intl.dart';

final pdfReportGeneratorProvider = Provider<PdfReportGenerator>((ref) {
  return PdfReportGenerator(
    ref.watch(reportsRepositoryProvider),
    ref.watch(settingsRepositoryProvider),
  );
});

class PdfReportGenerator {
  final ReportsRepository _reportsRepository;
  final SettingsRepository _settingsRepository;

  PdfReportGenerator(this._reportsRepository, this._settingsRepository);

  Future<Either<Failure, Uint8List>> generateMonthlyReport(DateTime month) async {
    try {
      final start = DateTime(month.year, month.month, 1);
      final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
      final range = DateRange(start, end);

      // Fetch data
      final dashboardRes = await _reportsRepository.getDashboardSummary(range);
      final salesRes = await _reportsRepository.getSalesBreakdown(range);
      final repairsRes = await _reportsRepository.getRepairJobsBreakdown(range);
      final healthRes = await _reportsRepository.getInventoryHealth();

      if (dashboardRes.isLeft() || salesRes.isLeft() || repairsRes.isLeft() || healthRes.isLeft()) {
        return Left(Failure('Failed to gather report data'));
      }

      final dashboard = dashboardRes.getRight().toNullable()!;
      final sales = salesRes.getRight().toNullable()!;
      final repairs = repairsRes.getRight().toNullable()!;
      final health = healthRes.getRight().toNullable()!;

      // Fetch store settings for header
      String storeName = 'POS System';
      String storeAddress = '';
      String storePhone = '';
      
      final nameRes = await _settingsRepository.getSetting('store_name');
      final addrRes = await _settingsRepository.getSetting('store_address');
      final phoneRes = await _settingsRepository.getSetting('store_phone');
      
      nameRes.match((_) {}, (val) { if (val != null && val.isNotEmpty) storeName = val; });
      addrRes.match((_) {}, (val) { if (val != null && val.isNotEmpty) storeAddress = val; });
      phoneRes.match((_) {}, (val) { if (val != null && val.isNotEmpty) storePhone = val; });

      // Build PDF
      final pdf = pw.Document();
      
      final titleFont = await PdfGoogleFonts.robotoBold();
      final bodyFont = await PdfGoogleFonts.robotoRegular();

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: bodyFont, fontSize: 10),
          ),
          header: (context) => _buildHeader(storeName, storeAddress, storePhone, month, titleFont),
          footer: (context) => _buildFooter(context),
          build: (context) => [
            _buildSectionTitle('Executive Summary', titleFont),
            _buildExecutiveSummary(dashboard, health),
            pw.SizedBox(height: 20),
            
            _buildSectionTitle('Revenue Breakdown (Payment Methods)', titleFont),
            pw.SizedBox(height: 10),
            _buildPaymentMethodChart(sales.revenueByMethod),
            pw.SizedBox(height: 20),
            
            _buildSectionTitle('Top Selling Items (By Quantity)', titleFont),
            _buildTopItemsTable(sales.topSellingByQuantity, titleFont),
            pw.SizedBox(height: 20),
            
            _buildSectionTitle('Repair Jobs Summary', titleFont),
            _buildRepairSummary(repairs),
          ],
        ),
      );

      final bytes = await pdf.save();
      return Right(bytes);
    } catch (e, st) {
      return Left(Failure('Failed to generate PDF report: $e', error: e, stackTrace: st));
    }
  }

  pw.Widget _buildHeader(String name, String address, String phone, DateTime month, pw.Font titleFont) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(name, style: pw.TextStyle(font: titleFont, fontSize: 24, color: PdfColors.blue900)),
                if (address.isNotEmpty) pw.Text(address, style: const pw.TextStyle(color: PdfColors.grey700)),
                if (phone.isNotEmpty) pw.Text(phone, style: const pw.TextStyle(color: PdfColors.grey700)),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Text('MONTHLY REPORT', style: pw.TextStyle(font: titleFont, fontSize: 16, color: PdfColors.grey600)),
                pw.Text(DateFormat('MMMM yyyy').format(month), style: pw.TextStyle(font: titleFont, fontSize: 14)),
                pw.Text('Generated: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildFooter(pw.Context context) {
    return pw.Container(
      alignment: pw.Alignment.centerRight,
      margin: const pw.EdgeInsets.only(top: 10),
      child: pw.Text(
        'Page ${context.pageNumber} of ${context.pagesCount}',
        style: const pw.TextStyle(color: PdfColors.grey, fontSize: 10),
      ),
    );
  }

  pw.Widget _buildSectionTitle(String title, pw.Font titleFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 10),
      child: pw.Text(
        title,
        style: pw.TextStyle(font: titleFont, fontSize: 14, color: PdfColors.blue800),
      ),
    );
  }

  pw.Widget _buildExecutiveSummary(DashboardSummary dashboard, InventoryHealth health) {
    final currency = NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2);
    
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey100,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryItem('Total Revenue', currency.format(dashboard.totalSalesRevenue + dashboard.totalRepairRevenue)),
          _buildSummaryItem('Transactions', dashboard.totalTransactions.toString()),
          _buildSummaryItem('Total Tax', currency.format(dashboard.totalTaxCollected)),
          _buildSummaryItem('Out. Credit', currency.format(dashboard.outstandingCredit)),
          _buildSummaryItem('Low Stock', dashboard.lowStockItemsCount.toString()),
        ],
      ),
    );
  }

  pw.Widget _buildSummaryItem(String label, String value) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(color: PdfColors.grey600, fontSize: 10)),
        pw.SizedBox(height: 4),
        pw.Text(value, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12)),
      ],
    );
  }

  pw.Widget _buildPaymentMethodChart(Map<String, double> revenueByMethod) {
    if (revenueByMethod.isEmpty) {
      return pw.Text('No sales data available for this period.', style: const pw.TextStyle(color: PdfColors.grey500));
    }

    final total = revenueByMethod.values.fold(0.0, (a, b) => a + b);
    
    // Simple bar chart implementation using pw.Container
    return pw.Column(
      children: revenueByMethod.entries.map((e) {
        final percentage = total > 0 ? (e.value / total) : 0.0;
        return pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 4),
          child: pw.Row(
            children: [
              pw.SizedBox(
                width: 80,
                child: pw.Text(e.key.toUpperCase(), style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Expanded(
                child: pw.Row(
                  children: [
                    pw.Container(
                      height: 12,
                      width: 300 * percentage,
                      color: PdfColors.blue400,
                    ),
                    pw.SizedBox(width: 8),
                    pw.Text(NumberFormat.currency(symbol: 'Rs ', decimalDigits: 0).format(e.value), style: const pw.TextStyle(fontSize: 9)),
                    pw.SizedBox(width: 4),
                    pw.Text('(${(percentage * 100).toStringAsFixed(1)}%)', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  pw.Widget _buildTopItemsTable(List<ItemSales> items, pw.Font titleFont) {
    if (items.isEmpty) {
      return pw.Text('No item sales data available.', style: const pw.TextStyle(color: PdfColors.grey500));
    }

    return pw.TableHelper.fromTextArray(
      headers: ['Item Name', 'Qty Sold', 'Revenue generated'],
      headerStyle: pw.TextStyle(font: titleFont, fontSize: 10, color: PdfColors.white),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
      cellStyle: const pw.TextStyle(fontSize: 10),
      cellAlignment: pw.Alignment.centerLeft,
      data: items.map((item) {
        return [
          item.itemName,
          item.totalQuantity.toString(),
          NumberFormat.currency(symbol: 'Rs ', decimalDigits: 2).format(item.totalRevenue),
        ];
      }).toList(),
    );
  }

  pw.Widget _buildRepairSummary(RepairJobsBreakdown repairs) {
    if (repairs.jobsByStatus.isEmpty) {
      return pw.Text('No repair jobs found.', style: const pw.TextStyle(color: PdfColors.grey500));
    }

    final List<pw.Widget> statusWidgets = repairs.jobsByStatus.entries.map((e) {
      return pw.Row(
        mainAxisSize: pw.MainAxisSize.min,
        children: [
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: pw.BoxDecoration(
              color: PdfColors.grey200,
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            child: pw.Text('${e.key.toUpperCase()}: ${e.value}', style: const pw.TextStyle(fontSize: 10)),
          ),
          pw.SizedBox(width: 10),
        ],
      );
    }).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Wrap(
          spacing: 8,
          runSpacing: 8,
          children: statusWidgets,
        ),
        pw.SizedBox(height: 12),
        if (repairs.averageTurnaroundTime != null)
          pw.Text(
            'Average Turnaround Time: ${repairs.averageTurnaroundTime!.inDays} days, ${repairs.averageTurnaroundTime!.inHours % 24} hours',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
      ],
    );
  }
}
