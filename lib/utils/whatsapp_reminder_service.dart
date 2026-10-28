import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../models/bill_model.dart';
import '../models/business_profile_model.dart';
import 'currency_formatter.dart';
import 'date_formatter.dart';

class WhatsAppReminderService {
  /// Format nomor HP ke standar internasional WhatsApp (misal 0812 -> 62812)
  static String formatPhoneForWhatsApp(String phone) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleaned.startsWith('0')) {
      cleaned = '62${cleaned.substring(1)}';
    } else if (cleaned.startsWith('8')) {
      cleaned = '62$cleaned';
    }
    return cleaned;
  }

  /// Membuat template pesan tagihan untuk WhatsApp
  static String generateBillMessage({
    required BillModel bill,
    required BusinessProfileModel business,
  }) {
    final period = DateFormatter.formatPeriod(bill.periodMonth, bill.periodYear);
    final totalTagihan = CurrencyFormatter.format(bill.amount);
    final sisaTagihan = CurrencyFormatter.format(bill.remainingAmount);
    final sudahBayar = CurrencyFormatter.format(bill.paidAmount);

    return '''
*TAGIHAN PEMBAYARAN WIFI ${business.businessName.toUpperCase()}*
--------------------------------------------------
Halo Bapak/Ibu *${bill.customerName}*,

Berikut informasi tagihan internet WiFi Anda:
• *No. Pelanggan:* ${bill.customerCode}
• *No. Tagihan:* ${bill.billNumber}
• *Paket WiFi:* ${bill.packageName}
• *Periode:* $period
• *Total Tagihan:* $totalTagihan
${bill.paidAmount > 0 ? '• *Sudah Dibayar:* $sudahBayar\n' : ''}• *Sisa yang Harus Dibayar:* *$sisaTagihan*
• *Jatuh Tempo:* *${bill.dueDate}*
• *Status:* ${bill.status.toUpperCase()}

Mohon lakukan pembayaran sebelum tanggal jatuh tempo agar kenyamanan koneksi internet Anda tetap terjaga.

Pembayaran dapat dilakukan melalui admin atau transfer ke kontak resmi kami.
📞 Kontak / WA: ${business.contactPhone}

_Terima kasih atas kepercayaannya menggunakan layanan kami._
'''.trim();
  }

  /// Membuat template pesan tagihan masal / rekap beberapa pelanggan
  static String generateBatchSummaryMessage({
    required List<BillModel> bills,
    required BusinessProfileModel business,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('*REKAP INFORMASI TAGIHAN WIFI ${business.businessName.toUpperCase()}*');
    buffer.writeln('Tanggal: ${DateFormatter.formatDate(DateTime.now())}');
    buffer.writeln('--------------------------------------------------');

    int totalNominal = 0;
    for (int i = 0; i < bills.length; i++) {
      final b = bills[i];
      totalNominal += b.remainingAmount;
      buffer.writeln('${i + 1}. *${b.customerName}* (${b.customerCode})');
      buffer.writeln('   Paket: ${b.packageName}');
      buffer.writeln('   Sisa: ${CurrencyFormatter.format(b.remainingAmount)} | Tempo: ${b.dueDate}');
      if (b.customerPhone.isNotEmpty) {
        buffer.writeln('   No HP: ${b.customerPhone}');
      }
      buffer.writeln();
    }

    buffer.writeln('--------------------------------------------------');
    buffer.writeln('*Total Tagihan (${bills.length} Pelanggan): ${CurrencyFormatter.format(totalNominal)}*');
    buffer.writeln('Kontak / WA: ${business.contactPhone}');

    return buffer.toString().trim();
  }

  /// Bagikan pesan tagihan via Share Sheet (bisa pilih WhatsApp langsung)
  static Future<void> shareToWhatsApp({
    required String message,
    String? phone,
    String? subject,
  }) async {
    await Share.share(
      message,
      subject: subject ?? 'Informasi Tagihan WiFi',
    );
  }

  /// Salin pesan ke clipboard
  static Future<void> copyToClipboard(String message) async {
    await Clipboard.setData(ClipboardData(text: message));
  }
}
