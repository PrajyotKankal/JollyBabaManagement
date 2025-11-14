// lib/services/invoice_service.dart
import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

class InvoiceService {
  /// Generate an invoice PDF from a ticket map.
  /// - [ticket]: Map containing ticket fields (see keys used below).
  /// - [logoBytes]: optional image bytes (PNG/JPG) to show in the header.
  /// Returns the generated File.
  static Future<File> generateInvoice(
    Map<String, dynamic> ticket, {
    Uint8List? logoBytes,
  }) async {
    final pdf = pw.Document();

    // Extract ticket values with safe fallbacks
    final String invoiceId = _buildInvoiceId(ticket);
    final DateTime now = DateTime.now();
    final String formattedDate = DateFormat('dd MMM yyyy, hh:mm a').format(now);

    final String companyName = (ticket['company_name'] ?? 'JollyBaba Mobile Repairing').toString();
    final String companyAddress = (ticket['company_address'] ?? 'Surat, India').toString();
    final String companyPhone = (ticket['company_phone'] ?? '+91 9876543210').toString();
    final String companyTagline = (ticket['company_tagline'] ?? 'Your Trusted Mobile Repair Service').toString();

    final String customerName = (ticket['customer_name'] ?? '-').toString();
    final String customerNumber = (ticket['mobile_number'] ?? '-').toString();
    final String deviceModel = (ticket['device_model'] ?? '-').toString();
    final String imei = (ticket['imei'] ?? '').toString();
    final String issue = (ticket['issue_description'] ?? '-').toString();
    final String technician = (ticket['assigned_technician'] ?? ticket['assigned_to'] ?? '-').toString();
    final num rawCost = _toNum(ticket['estimated_cost']);
    final String costFormatted = _formatCurrency(rawCost);

    // Build PDF page
    pdf.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
        ),
        build: (context) {
          return <pw.Widget>[
            // Header row: logo (optional) + company info
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                // left: logo (if provided) & company text
                pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    if (logoBytes != null) ...[
                      pw.Container(
                        width: 64,
                        height: 64,
                        decoration: pw.BoxDecoration(
                          borderRadius: pw.BorderRadius.circular(8),
                        ),
                        child: pw.Image(pw.MemoryImage(logoBytes), fit: pw.BoxFit.contain),
                      ),
                      pw.SizedBox(width: 12),
                    ],
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(companyName, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
                        pw.SizedBox(height: 4),
                        pw.Text(companyTagline, style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        pw.SizedBox(height: 6),
                        pw.Text("$companyAddress • $companyPhone", style: pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                  ],
                ),

                // right: invoice meta
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey200,
                        borderRadius: pw.BorderRadius.circular(6),
                      ),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text("Invoice", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                          pw.Text(invoiceId, style: pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text("Date: $formattedDate", style: pw.TextStyle(fontSize: 10)),
                    pw.Text("Technician: $technician", style: pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ],
            ),

            pw.SizedBox(height: 18),

            // Customer box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text("Customer Details", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 6),
                  pw.Text("Name: $customerName", style: pw.TextStyle(fontSize: 10)),
                  pw.Text("Phone: $customerNumber", style: pw.TextStyle(fontSize: 10)),
                  pw.Text("Device: $deviceModel", style: pw.TextStyle(fontSize: 10)),
                  if (imei.isNotEmpty) pw.Text("IMEI: $imei", style: pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),

            pw.SizedBox(height: 16),

            // Issue / description
            pw.Text("Repair Details", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text(issue, style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),

            // Charges summary
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text("Repair Charges", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                  pw.Text(costFormatted, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
                ],
              ),
            ),

            pw.SizedBox(height: 18),

            // Payment / footer notes
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text("Payment Mode: ${ticket['payment_mode'] ?? 'Pending'}", style: pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 12),
            pw.Text("Thank you for choosing $companyName!", style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
            pw.Text("We appreciate your trust and support.", style: pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
            pw.SizedBox(height: 20),
            pw.Align(
              alignment: pw.Alignment.center,
              child: pw.Text("This is a computer-generated invoice.", style: pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ),
          ];
        },
      ),
    );

    // Save file to documents/invoices/invoice_<id>.pdf
    final appDoc = await getApplicationDocumentsDirectory();
    final invoicesDir = Directory("${appDoc.path}/invoices");
    if (!await invoicesDir.exists()) {
      await invoicesDir.create(recursive: true);
    }

    final outFile = File("${invoicesDir.path}/invoice_$invoiceId.pdf");
    final bytes = await pdf.save();
    await outFile.writeAsBytes(bytes, flush: true);

    return outFile;
  }

  /// Share a generated PDF file using platform share (Share sheet).
  /// If you want to directly open WhatsApp you can open its chat after sharing.
  static Future<void> shareInvoice(File pdfFile, {String? text}) async {
    final XFile xfile = XFile(pdfFile.path);
    await Share.shareXFiles([xfile], text: text ?? 'Invoice from JollyBaba Mobile Repairing');
  }

  // -------------------- Helpers --------------------

  static String _buildInvoiceId(Map<String, dynamic> ticket) {
    // Prefer a numeric ticket id if available
    try {
      final id = ticket['id'] ?? ticket['ticket_id'] ?? ticket['invoice_id'];
      if (id != null) return "INV-${id.toString()}";
    } catch (_) {}
    // fallback to timestamp-based id
    final ts = DateTime.now().millisecondsSinceEpoch;
    return "INV-$ts";
  }

  static num _toNum(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v;
    final s = v.toString().replaceAll(RegExp(r'[^0-9\.\-]'), '');
    return num.tryParse(s) ?? 0;
  }

  static String _formatCurrency(num amount) {
    final f = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);
    return f.format(amount);
  }
}
