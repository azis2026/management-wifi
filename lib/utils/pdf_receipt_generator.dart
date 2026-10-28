import 'dart:io';
import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/payment_model.dart';
import '../models/bill_model.dart';
import '../models/business_profile_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class PdfReceiptGenerator {
  /// Generates receipt PDF bytes completely offline
  static Future<Uint8List> generateReceiptPdf({
    required PaymentModel payment,
    required BillModel bill,
    required BusinessProfileModel business,
  }) async {
    final pdf = pw.Document();

    final isPaidOff = bill.remainingAmount <= 0;
    final paymentDateTime = DateFormatter.parseDate(payment.paymentDate);

    // Muat gambar logo jika ada
    pw.MemoryImage? logoImage;
    if (business.logoPath != null && business.logoPath!.isNotEmpty) {
      final file = File(business.logoPath!);
      if (file.existsSync()) {
        try {
          logoImage = pw.MemoryImage(await file.readAsBytes());
        } catch (_) {}
      }
    }

    // Muat gambar tanda tangan jika ada
    pw.MemoryImage? signatureImage;
    if (business.signaturePath != null && business.signaturePath!.isNotEmpty) {
      final file = File(business.signaturePath!);
      if (file.existsSync()) {
        try {
          signatureImage = pw.MemoryImage(await file.readAsBytes());
        } catch (_) {}
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a5,
        margin: const pw.EdgeInsets.all(24),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 12),
                decoration: pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(color: PdfColors.blueGrey800, width: 2),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        if (logoImage != null) ...[
                          pw.Container(
                            width: 44,
                            height: 44,
                            margin: const pw.EdgeInsets.only(right: 10),
                            child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                          ),
                        ],
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                              business.businessName.toUpperCase(),
                              style: pw.TextStyle(
                                fontSize: 15,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blueGrey900,
                              ),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              business.address,
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                            pw.Text(
                              'Kontak / WA: ${business.contactPhone}',
                              style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                            ),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Container(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: pw.BoxDecoration(
                            color: isPaidOff ? PdfColors.green700 : PdfColors.amber700,
                            borderRadius: pw.BorderRadius.circular(4),
                          ),
                          child: pw.Text(
                            isPaidOff ? 'LUNAS' : 'SEBAGIAN',
                            style: pw.TextStyle(
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'KUITANSI PEMBAYARAN',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blueGrey700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 14),

              // Transaction & Customer Info Grid
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildRow('No. Kuitansi', payment.receiptNumber),
                        pw.SizedBox(height: 3),
                        _buildRow('No. Tagihan', bill.billNumber),
                        pw.SizedBox(height: 3),
                        _buildRow('Tgl. Bayar', DateFormatter.formatWithTime(paymentDateTime)),
                        pw.SizedBox(height: 3),
                        _buildRow('Metode', payment.paymentMethod),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        _buildRow('ID Pelanggan', payment.customerCode),
                        pw.SizedBox(height: 3),
                        _buildRow('Nama', payment.customerName),
                        pw.SizedBox(height: 3),
                        _buildRow('Paket', bill.packageName),
                        pw.SizedBox(height: 3),
                        _buildRow(
                          'Periode',
                          DateFormatter.formatPeriod(bill.periodMonth, bill.periodYear),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 16),

              // Payment Details Table
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey800),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Deskripsi Pembayaran',
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Jumlah',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 9,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Iuran WiFi Periode ${DateFormatter.formatPeriod(bill.periodMonth, bill.periodYear)} (${bill.packageName})',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          CurrencyFormatter.format(bill.amount),
                          textAlign: pw.TextAlign.right,
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.grey50),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Total Dibayarkan Pada Transaksi Ini',
                          style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          CurrencyFormatter.format(payment.amountPaid),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.green800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          'Sisa Tagihan Periode Ini',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(
                          CurrencyFormatter.format(bill.remainingAmount),
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                            fontSize: 9,
                            fontWeight: pw.FontWeight.bold,
                            color: bill.remainingAmount > 0 ? PdfColors.red700 : PdfColors.grey700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              if (payment.notes.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text(
                  'Catatan: ${payment.notes}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700, fontStyle: pw.FontStyle.italic),
                ),
              ],

              pw.Spacer(),

              // Signatures & Footer Note
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Pelanggan,', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 28),
                      pw.Text(
                        payment.customerName,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('Admin / Pengelola WiFi,', style: const pw.TextStyle(fontSize: 8)),
                      pw.SizedBox(height: 4),
                      if (signatureImage != null) ...[
                        pw.Container(
                          height: 36,
                          width: 80,
                          alignment: pw.Alignment.centerRight,
                          child: pw.Image(signatureImage, fit: pw.BoxFit.contain),
                        ),
                      ] else ...[
                        pw.SizedBox(height: 28),
                      ],
                      pw.Text(
                        business.businessName,
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                ],
              ),

              pw.SizedBox(height: 12),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(
                  border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300)),
                ),
                child: pw.Text(
                  business.receiptFooter,
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                ),
              ),
            ],
          );
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildRow(String label, String value) {
    return pw.Row(
      children: [
        pw.SizedBox(
          width: 70,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
          ),
        ),
        pw.Text(
          ': ',
          style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold),
        ),
      ],
    );
  }
}
