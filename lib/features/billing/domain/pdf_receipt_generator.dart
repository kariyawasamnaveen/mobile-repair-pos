import 'dart:typed_data';
import 'package:fpdart/fpdart.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pos_system/core/error/failure.dart';
import 'package:pos_system/features/billing/domain/sale.dart';
import 'package:pos_system/features/settings/presentation/settings_controller.dart';
import 'package:pos_system/core/database/tables.dart';

class PdfReceiptGenerator {
  static const String receiptFooterPolicy = "Items eligible for exchange within 7 days with this receipt";
  static const String receiptFooterGreeting = "Thank you, visit again!";

  Future<Either<Failure, Uint8List>> generateReceipt(Sale sale, StoreSettings? settings) async {
    try {
      final pdf = pw.Document();

      final titleFont = await PdfGoogleFonts.robotoBold();
      final bodyFont = await PdfGoogleFonts.robotoRegular();
      final italicFont = await PdfGoogleFonts.robotoItalic();

      // Roll80 format is typical for 80mm thermal receipts
      final format = PdfPageFormat.roll80.copyWith(
        marginBottom: 10 * PdfPageFormat.mm,
        marginLeft: 5 * PdfPageFormat.mm,
        marginRight: 5 * PdfPageFormat.mm,
        marginTop: 10 * PdfPageFormat.mm,
      );

      pdf.addPage(
        pw.Page(
          pageFormat: format,
          theme: pw.ThemeData(
            defaultTextStyle: pw.TextStyle(font: bodyFont, fontSize: 10),
          ),
          build: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.stretch,
              mainAxisSize: pw.MainAxisSize.min,
              children: [
                pw.Text(settings?.name ?? 'STORE NAME', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: titleFont, fontSize: 18)),
                if (settings?.address != null && settings!.address!.isNotEmpty)
                  pw.Text(settings.address!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                if (settings?.phone != null && settings!.phone!.isNotEmpty)
                  pw.Text(settings.phone!, textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                
                pw.SizedBox(height: 10),
                pw.Text('Receipt #: ${sale.id.substring(0, 8).toUpperCase()}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                pw.Text('Date: ${sale.createdAt.toString().split('.')[0]}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                if (sale.cashierName != null) 
                  pw.Text('Served by: ${sale.cashierName}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                if (sale.customerName != null) 
                  pw.Text('Customer: ${sale.customerName}', textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 10)),
                
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),
                
                // Items
                ...sale.items.map((item) {
                  return pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 4),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Expanded(child: pw.Text(item.itemName, style: const pw.TextStyle(fontSize: 10))),
                            pw.SizedBox(width: 4),
                            pw.Text('${item.quantitySold} x ${item.unitPriceAtSale.toStringAsFixed(2)}', style: const pw.TextStyle(fontSize: 10)),
                          ],
                        ),
                        if (item.imeiSold != null)
                          pw.Text('IMEI: ${item.imeiSold}', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                      ],
                    ),
                  );
                }),
                
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),
                
                // Totals
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal'), pw.Text(sale.subtotal.toStringAsFixed(2))]),
                if (sale.discount > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Discount'), pw.Text('-${sale.discount.toStringAsFixed(2)}')]),
                if (sale.taxAmount != null && sale.taxAmount! > 0)
                  pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Tax (${sale.taxRateApplied}%)'), pw.Text(sale.taxAmount!.toStringAsFixed(2))]),
                
                pw.SizedBox(height: 4),
                pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
                  pw.Text('TOTAL', style: pw.TextStyle(font: titleFont, fontSize: 14)), 
                  pw.Text(sale.total.toStringAsFixed(2), style: pw.TextStyle(font: titleFont, fontSize: 14))
                ]),
                
                pw.SizedBox(height: 8),
                pw.Text('Payment: ${sale.paymentMethod.name.toUpperCase()}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
                if (sale.paymentMethod == PaymentMethod.cash && sale.amountTendered != null) ...[
                  pw.Text('Tendered: ${sale.amountTendered!.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Change: ${sale.changeDue!.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: titleFont, fontSize: 10)),
                ],
                if (sale.isCreditSale) ...[
                  pw.Text('Paid: ${sale.amountPaid.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: const pw.TextStyle(fontSize: 10)),
                  pw.Text('Balance Due: ${sale.balanceDue.toStringAsFixed(2)}', textAlign: pw.TextAlign.right, style: pw.TextStyle(font: titleFont, fontSize: 10)),
                ],
                
                pw.SizedBox(height: 8),
                pw.Divider(thickness: 1, borderStyle: pw.BorderStyle.dashed),
                pw.SizedBox(height: 8),
                
                pw.Text(receiptFooterPolicy, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: italicFont, fontSize: 8)),
                pw.SizedBox(height: 4),
                pw.Text(receiptFooterGreeting, textAlign: pw.TextAlign.center, style: pw.TextStyle(font: titleFont, fontSize: 10)),
              ],
            );
          },
        ),
      );

      final bytes = await pdf.save();
      return Right(bytes);
    } catch (e, st) {
      return Left(Failure('Failed to generate receipt PDF: $e', error: e, stackTrace: st));
    }
  }
}
