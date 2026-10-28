import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/customer_model.dart';
import '../models/bill_model.dart';
import '../models/payment_model.dart';
import '../repositories/customer_repository.dart';
import '../repositories/bill_repository.dart';
import '../repositories/payment_repository.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

/// Exports data as CSV that can be opened in Google Sheets, Microsoft Excel,
/// or any spreadsheet application. Designed for offline use — no internet needed.
class SheetsExporter {
  /// Export single customer with all bills & payments as CSV
  static Future<void> exportCustomerData({
    required CustomerModel customer,
    required List<BillModel> bills,
    required List<PaymentModel> payments,
    required BuildContext context,
  }) async {
    final buffer = StringBuffer();

    // Header info
    buffer.writeln('LAPORAN DATA PELANGGAN');
    buffer.writeln('Nama,${customer.name}');
    buffer.writeln('Kode,${customer.customerCode}');
    buffer.writeln('HP,${customer.phone}');
    buffer.writeln('Alamat,"${customer.address}"');
    buffer.writeln('Paket,${customer.packageName}');
    buffer.writeln('Iuran/Bulan,${CurrencyFormatter.format(customer.monthlyFee)}');
    buffer.writeln('Status,${customer.isActive ? 'Aktif' : 'Nonaktif'}');
    buffer.writeln('Total Tunggakan,${CurrencyFormatter.format(customer.totalArrears)}');
    buffer.writeln();

    // Bills section
    buffer.writeln('RIWAYAT TAGIHAN');
    buffer.writeln('No Tagihan,Periode,Jumlah Tagihan,Sudah Dibayar,Sisa,Jatuh Tempo,Status');
    for (final b in bills) {
      buffer.writeln(
        '${b.billNumber},'
        '${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)},'
        '${b.amount},'
        '${b.paidAmount},'
        '${b.remainingAmount},'
        '${b.dueDate},'
        '${b.status}',
      );
    }
    buffer.writeln();

    // Payments section
    buffer.writeln('RIWAYAT PEMBAYARAN');
    buffer.writeln('No Kuitansi,No Tagihan,Tanggal Bayar,Jumlah Dibayar,Metode,Status');
    for (final p in payments) {
      final status = p.isCancelled ? 'Dibatalkan' : 'Valid';
      buffer.writeln(
        '${p.receiptNumber},'
        '${p.billNumber},'
        '${p.paymentDate},'
        '${p.amountPaid},'
        '${p.paymentMethod},'
        '$status',
      );
    }

    final csvContent = buffer.toString();
    final fileName = 'WiFiManager_${customer.customerCode}_${DateFormatter.toIsoDateOnly(DateTime.now())}.csv';
    await _shareAsCsv(csvContent, fileName, context);
  }

  /// Export ALL customers with summary
  static Future<void> exportAllCustomers({required BuildContext context}) async {
    final customerRepo = CustomerRepository();
    final billRepo = BillRepository();

    final customers = await customerRepo.getCustomers();
    final stats = await billRepo.getDashboardStats();

    final buffer = StringBuffer();
    final now = DateFormatter.formatDate(DateTime.now());

    // Summary header
    buffer.writeln('LAPORAN WIFI MANAGER - $now');
    buffer.writeln('Total Pelanggan Aktif,${stats['active_customers']}');
    buffer.writeln('Pendapatan Bulan Ini,${stats['income_this_month']}');
    buffer.writeln('Tagihan Belum Lunas,${stats['unpaid_bills_count']}');
    buffer.writeln('Total Tunggakan,${stats['total_arrears']}');
    buffer.writeln();

    // Customer list
    buffer.writeln('DAFTAR PELANGGAN');
    buffer.writeln('Kode,Nama,HP,Alamat,Paket,Iuran/Bulan,Jatuh Tempo,Status,Total Tunggakan');
    for (final c in customers) {
      buffer.writeln(
        '${c.customerCode},'
        '"${c.name}",'
        '${c.phone},'
        '"${c.address}",'
        '${c.packageName},'
        '${c.monthlyFee},'
        'Tgl ${c.dueDay},'
        '${c.isActive ? 'Aktif' : 'Nonaktif'},'
        '${c.totalArrears}',
      );
    }

    final csvContent = buffer.toString();
    final fileName = 'WiFiManager_SemuaPelanggan_${DateFormatter.toIsoDateOnly(DateTime.now())}.csv';
    await _shareAsCsv(csvContent, fileName, context);
  }

  /// Export payment history for a month
  static Future<void> exportMonthlyPayments({
    required int month,
    required int year,
    required BuildContext context,
  }) async {
    final paymentRepo = PaymentRepository();
    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0);
    final payments = await paymentRepo.getPayments(startDate: start, endDate: end);

    final buffer = StringBuffer();
    buffer.writeln('LAPORAN PEMBAYARAN - ${DateFormatter.formatPeriod(month, year)}');
    buffer.writeln('Total Transaksi,${payments.length}');

    num totalIncome = 0;
    for (final p in payments) {
      if (!p.isCancelled) totalIncome += p.amountPaid;
    }
    buffer.writeln('Total Pendapatan,$totalIncome');
    buffer.writeln();

    buffer.writeln('DAFTAR PEMBAYARAN');
    buffer.writeln('No Kuitansi,Nama Pelanggan,Kode,No Tagihan,Tanggal,Jumlah,Metode,Status');
    for (final p in payments) {
      buffer.writeln(
        '${p.receiptNumber},'
        '"${p.customerName}",'
        '${p.customerCode},'
        '${p.billNumber},'
        '${p.paymentDate},'
        '${p.amountPaid},'
        '${p.paymentMethod},'
        '${p.isCancelled ? 'Dibatalkan' : 'Valid'}',
      );
    }

    final csvContent = buffer.toString();
    final fileName = 'WiFiManager_Pembayaran_${year}_${month.toString().padLeft(2, '0')}.csv';
    await _shareAsCsv(csvContent, fileName, context);
  }

  static Future<void> _shareAsCsv(String content, String fileName, BuildContext context) async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(content, encoding: const SystemEncoding());

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: fileName,
      text: 'Data WiFi Manager — dapat dibuka di Google Sheets atau Excel',
    );
  }
}
