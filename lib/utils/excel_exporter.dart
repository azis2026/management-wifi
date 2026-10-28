import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/customer_model.dart';
import '../repositories/customer_repository.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';
import 'billing_calculator.dart';

class ExcelExporter {
  /// Export customer list to genuine Excel (.xlsx) file
  static Future<File> generateCustomerExcelFile({
    required List<CustomerModel> customers,
    String? customFileName,
  }) async {
    final excel = Excel.createExcel();

    // Setup sheet
    final defaultSheet = excel.getDefaultSheet();
    const sheetName = 'Data Pelanggan';
    if (defaultSheet != null) {
      excel.rename(defaultSheet, sheetName);
    }
    final sheet = excel[sheetName];

    // Header Kolom sesuai Ketentuan Bagian 7 Prompt
    final headers = [
      'ID Pelanggan',
      'Nama Lengkap',
      'Nomor Telepon',
      'Alamat Lengkap',
      'Nama Paket',
      'Kecepatan Internet',
      'Harga Paket Bulanan',
      'Biaya per Hari',
      'Tanggal Pemasangan',
      'Tanggal Mulai Berlangganan',
      'Tanggal Berakhir Periode Aktif',
      'Total Hari Berlangganan',
      'Sisa Hari Aktif',
      'Biaya Pemasangan Awal',
      'Nominal Tagihan Pertama',
      'Total Pembayaran Pertama',
      'Total Tagihan',
      'Total Pembayaran Diterima',
      'Sisa Tunggakan',
      'Tanggal Pembayaran Terakhir',
      'Jatuh Tempo Berikutnya',
      'Status Pelanggan',
      'Status Pembayaran',
      'Catatan Admin',
    ];

    final headerRow = headers.map((h) => TextCellValue(h)).toList();
    sheet.appendRow(headerRow);

    // Apply header style: Navy header background with bold white text
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromHexString('#1E3A8A'),
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
    );

    for (int col = 0; col < headers.length; col++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 0));
      cell.cellStyle = headerStyle;
    }

    final repo = CustomerRepository();

    // Data rows
    for (int i = 0; i < customers.length; i++) {
      final c = customers[i];

      // Ambil detail riwayat keuangan untuk kolom 15-21
      final details = await repo.getCustomerComprehensiveDetails(c.id ?? 0);
      final firstBill = details['first_bill'];
      final int totalBills = details['total_bills'] as int? ?? 0;
      final int totalPaid = details['total_paid'] as int? ?? 0;
      final int totalRemaining = details['total_remaining'] as int? ?? c.totalArrears;
      final lastPayment = details['last_payment'];
      final latestBill = details['latest_bill'];

      // Tanggal & Hari
      final startDate = DateFormatter.parseDate(c.startDate);
      final totalDays = BillingCalculator.calculateTotalSubscriptionDays(startDate);
      final periodEnd = latestBill != null && latestBill.periodEnd.isNotEmpty
          ? DateFormatter.parseDate(latestBill.periodEnd)
          : c.activePeriodEndDate;
      final remainingDays = BillingCalculator.calculateRemainingDays(periodEnd);

      final dailyFee = BillingCalculator.calculateDailyFee(c.monthlyFee).round();

      final firstBillAmount = firstBill != null ? firstBill.amount : c.monthlyFee;
      final firstBillPaid = firstBill != null ? firstBill.paidAmount : 0;
      final lastPaymentDate = lastPayment != null
          ? DateFormatter.formatDate(DateFormatter.parseDate(lastPayment.paymentDate))
          : '-';
      final nextDueDate = latestBill != null && latestBill.dueDate.isNotEmpty
          ? DateFormatter.formatDate(DateFormatter.parseDate(latestBill.dueDate))
          : 'Tgl ${c.dueDay}';

      String paymentStatus = 'Lunas';
      if (totalRemaining > 0) {
        if (latestBill != null && latestBill.isOverdue) {
          paymentStatus = 'Terlambat';
        } else {
          paymentStatus = 'Belum Lunas / Menunggak';
        }
      }

      final row = <CellValue>[
        TextCellValue(c.customerCode),
        TextCellValue(c.name),
        TextCellValue(c.phone),
        TextCellValue(c.address),
        TextCellValue(c.packageName),
        TextCellValue(c.packageSpeed.isNotEmpty ? c.packageSpeed : '-'),
        TextCellValue(CurrencyFormatter.format(c.monthlyFee)),
        TextCellValue(CurrencyFormatter.format(dailyFee)),
        TextCellValue(DateFormatter.formatDate(DateFormatter.parseDate(c.installDate))),
        TextCellValue(DateFormatter.formatDate(startDate)),
        TextCellValue(DateFormatter.formatDate(periodEnd)),
        TextCellValue('$totalDays Hari'),
        TextCellValue('$remainingDays Hari'),
        TextCellValue(CurrencyFormatter.format(c.installationFee)),
        TextCellValue(CurrencyFormatter.format(firstBillAmount)),
        TextCellValue(CurrencyFormatter.format(firstBillPaid)),
        TextCellValue(CurrencyFormatter.format(totalBills)),
        TextCellValue(CurrencyFormatter.format(totalPaid)),
        TextCellValue(CurrencyFormatter.format(totalRemaining)),
        TextCellValue(lastPaymentDate),
        TextCellValue(nextDueDate),
        TextCellValue(c.isActive ? 'Aktif' : 'Tidak Aktif'),
        TextCellValue(paymentStatus),
        TextCellValue(c.notes.isNotEmpty ? c.notes : '-'),
      ];

      sheet.appendRow(row);
    }

    // Save Excel file
    final dir = await getApplicationDocumentsDirectory();
    final todayStr = DateFormatter.toIsoDateOnly(DateTime.now());
    final fileName = customFileName ?? 'Data_Pelanggan_$todayStr.xlsx';
    final file = File('${dir.path}/$fileName');

    final bytes = excel.save();
    if (bytes == null) {
      throw Exception('Gagal membuat file Excel.');
    }
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  /// Export & Share Excel file
  static Future<void> exportAndShareCustomers({
    required BuildContext context,
    required List<CustomerModel> customers,
    bool isFiltered = false,
  }) async {
    try {
      final todayStr = DateFormatter.toIsoDateOnly(DateTime.now());
      final suffix = isFiltered ? '_Filtered' : '';
      final fileName = 'Data_Pelanggan${suffix}_$todayStr.xlsx';

      final file = await generateCustomerExcelFile(
        customers: customers,
        customFileName: fileName,
      );

      await Share.shareXFiles(
        [
          XFile(
            file.path,
            mimeType: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
            name: fileName,
          ),
        ],
        subject: 'Ekspor Data Pelanggan WiFi - $todayStr',
        text: 'File data pelanggan internet/ISP dalam format Microsoft Excel (.xlsx)',
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor Excel: $e'),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }
}
