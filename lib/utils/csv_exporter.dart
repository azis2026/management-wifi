import 'dart:io';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import '../models/payment_model.dart';
import '../models/bill_model.dart';
import '../models/customer_model.dart';
import '../utils/currency_formatter.dart';
import '../utils/date_formatter.dart';

class CsvExporter {
  /// Export payments report to CSV file
  static Future<File> exportPaymentsToCsv(List<PaymentModel> payments) async {
    final List<List<dynamic>> rows = [
      ['No. Kuitansi', 'No. Tagihan', 'ID Pelanggan', 'Nama Pelanggan', 'Tanggal Pembayaran', 'Nominal Bayar (Rp)', 'Metode Pembayaran', 'Status', 'Catatan']
    ];

    for (var p in payments) {
      final date = DateFormatter.parseDate(p.paymentDate);
      rows.add([
        p.receiptNumber,
        p.billNumber,
        p.customerCode,
        p.customerName,
        DateFormatter.formatWithTime(date),
        p.amountPaid,
        p.paymentMethod,
        p.isCancelled ? 'Dibatalkan (${p.cancelReason})' : 'Berhasil',
        p.notes,
      ]);
    }

    final csvString = '\uFEFF${csv.encode(rows)}';
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName = 'laporan_pembayaran_excel_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour}${now.minute}.csv';
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(csvString);
  }

  /// Export arrears / unpaid bills to CSV
  static Future<File> exportArrearsToCsv(List<BillModel> bills) async {
    final List<List<dynamic>> rows = [
      ['No. Tagihan', 'ID Pelanggan', 'Nama Pelanggan', 'No HP/WA', 'Paket WiFi', 'Periode', 'Jatuh Tempo', 'Total Tagihan (Rp)', 'Sudah Dibayar (Rp)', 'Sisa Tunggakan (Rp)', 'Status']
    ];

    for (var b in bills) {
      rows.add([
        b.billNumber,
        b.customerCode,
        b.customerName,
        b.customerPhone,
        b.packageName,
        DateFormatter.formatPeriod(b.periodMonth, b.periodYear),
        b.dueDate,
        b.amount,
        b.paidAmount,
        b.remainingAmount,
        b.status,
      ]);
    }

    final csvString = '\uFEFF${csv.encode(rows)}';
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName = 'laporan_tunggakan_excel_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(csvString);
  }

  /// Export customers list to CSV
  static Future<File> exportCustomersToCsv(List<CustomerModel> customers) async {
    final List<List<dynamic>> rows = [
      ['ID Pelanggan', 'Nama', 'No HP/WA', 'Alamat', 'Paket WiFi', 'Biaya Bulanan', 'Tgl Pasang', 'Tgl Jatuh Tempo', 'Status', 'Tunggakan']
    ];

    for (var c in customers) {
      rows.add([
        c.customerCode,
        c.name,
        c.phone,
        c.address,
        c.packageName,
        c.monthlyFee,
        c.installDate,
        'Tiap tgl ${c.dueDay}',
        c.isActive ? 'Aktif' : 'Nonaktif',
        CurrencyFormatter.format(c.totalArrears),
      ]);
    }

    final csvString = csv.encode(rows);
    final dir = await getApplicationDocumentsDirectory();
    final now = DateTime.now();
    final fileName = 'daftar_pelanggan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}.csv';
    final file = File('${dir.path}/$fileName');
    return await file.writeAsString(csvString);
  }
}
