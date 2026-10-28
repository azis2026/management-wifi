import 'package:intl/intl.dart';
import 'currency_formatter.dart';

/// Utilitas perhitungan hari, bulan, dan biaya berlangganan internet/ISP.
class BillingCalculator {
  /// Biaya per hari = Harga paket bulanan ÷ 30
  static double calculateDailyFee(int monthlyPrice) {
    if (monthlyPrice <= 0) return 0.0;
    return monthlyPrice / 30.0;
  }

  /// Total biaya berdasarkan periode penggunaan:
  /// Total biaya = Biaya per hari × Jumlah hari yang ditagihkan.
  /// Untuk tagihan bulanan normal (30 hari), gunakan harga paket tetap,
  /// bukan hasil pembulatan biaya harian.
  static int calculatePeriodFee(int monthlyPrice, int days) {
    if (monthlyPrice <= 0 || days <= 0) return 0;
    if (days == 30) return monthlyPrice;
    final daily = calculateDailyFee(monthlyPrice);
    return (daily * days).round();
  }

  /// Total hari berlangganan:
  /// Dihitung dari tanggal mulai berlangganan sampai hari ini (inklusif).
  static int calculateTotalSubscriptionDays(DateTime startDate, [DateTime? asOfDate]) {
    final now = asOfDate ?? DateTime.now();
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final current = DateTime(now.year, now.month, now.day);
    if (current.isBefore(start)) return 0;
    return current.difference(start).inDays + 1;
  }

  /// Tanggal berakhir periode paket (standar 30 hari)
  static DateTime calculatePeriodEnd(DateTime startDate, {int days = 30}) {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    // Periode 30 hari berakhir pada start + 30 hari
    return start.add(Duration(days: days));
  }

  /// Sisa hari berlangganan dari hari ini sampai tanggal berakhir
  static int calculateRemainingDays(DateTime periodEnd, [DateTime? asOfDate]) {
    final now = asOfDate ?? DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(periodEnd.year, periodEnd.month, periodEnd.day);
    final diff = end.difference(today).inDays;
    return diff < 0 ? 0 : diff;
  }

  /// Hitung total tagihan pertama:
  /// Total tagihan pertama = Biaya pemasangan + Biaya langganan pertama + Biaya tambahan − Diskon.
  static int calculateFirstBillTotal({
    required int installationFee,
    required int subscriptionFee,
    int additionalFee = 0,
    int discount = 0,
  }) {
    final total = installationFee + subscriptionFee + additionalFee - discount;
    return total < 0 ? 0 : total;
  }

  /// Format rupiah harian contoh: "Rp2.833 / hari"
  static String formatDailyFee(int monthlyPrice) {
    final daily = calculateDailyFee(monthlyPrice);
    final rounded = daily.round();
    return '${CurrencyFormatter.format(rounded)} / hari';
  }

  /// Format tanggal standar Indonesia (DD/MM/YYYY)
  static String formatDateShort(DateTime date) {
    return DateFormat('dd/MM/yyyy').format(date);
  }
}
