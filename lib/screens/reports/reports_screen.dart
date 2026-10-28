import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/payment_model.dart';
import '../../models/bill_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/bill_repository.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/app_theme.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final PaymentRepository _paymentRepo = PaymentRepository();
  final BillRepository _billRepo = BillRepository();

  DateTime _startDate = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _endDate = DateTime.now();

  List<PaymentModel> _payments = [];
  List<BillModel> _unpaidBills = [];
  bool _isLoading = true;

  int _dailyIncome = 0;
  int _weeklyIncome = 0;
  int _monthlyIncome = 0;

  Map<String, int> _paymentMethodTotals = {};

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() => _isLoading = true);

    final allPayments = await _paymentRepo.getPayments(onlyActive: true);
    final rangePayments = await _paymentRepo.getPayments(
      onlyActive: true,
      startDate: _startDate,
      endDate: _endDate,
    );
    final bills = await _billRepo.getBills();

    final unpaid = bills.where((b) =>
        b.status == BillStatus.unpaid ||
        b.status == BillStatus.partial ||
        b.status == BillStatus.overdue).toList();

    // Calculate daily, weekly, monthly
    final now = DateTime.now();
    final todayStr = DateFormatter.toIsoDateOnly(now);
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    final firstDayThisMonth = DateTime(now.year, now.month, 1);

    int daily = 0;
    int weekly = 0;
    int monthly = 0;
    Map<String, int> methodMap = {
      PaymentMethod.cash: 0,
      PaymentMethod.bankTransfer: 0,
      PaymentMethod.eWallet: 0,
      PaymentMethod.other: 0,
    };

    for (var p in allPayments) {
      final pDate = DateFormatter.parseDate(p.paymentDate);

      if (DateFormatter.toIsoDateOnly(pDate) == todayStr) {
        daily += p.amountPaid;
      }
      if (pDate.isAfter(sevenDaysAgo)) {
        weekly += p.amountPaid;
      }
      if (pDate.isAfter(firstDayThisMonth.subtract(const Duration(seconds: 1)))) {
        monthly += p.amountPaid;
      }
    }

    for (var p in rangePayments) {
      final current = methodMap[p.paymentMethod] ?? 0;
      methodMap[p.paymentMethod] = current + p.amountPaid;
    }

    if (mounted) {
      setState(() {
        _payments = rangePayments;
        _unpaidBills = unpaid;
        _dailyIncome = daily;
        _weeklyIncome = weekly;
        _monthlyIncome = monthly;
        _paymentMethodTotals = methodMap;
        _isLoading = false;
      });
    }
  }

  Future<void> _selectDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppTheme.navyPrimary,
              onPrimary: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
      });
      _loadReportData();
    }
  }

  Future<void> _exportCsv() async {
    try {
      final file = await CsvExporter.exportPaymentsToCsv(_payments);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Pembayaran WiFi (${DateFormatter.toIsoDateOnly(_startDate)} s.d. ${DateFormatter.toIsoDateOnly(_endDate)})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    }
  }

  Future<void> _exportArrearsCsv() async {
    try {
      final file = await CsvExporter.exportArrearsToCsv(_unpaidBills);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Laporan Tunggakan Pelanggan WiFi',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mengekspor CSV: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    }
  }

  void _setPreset(String preset) {
    final now = DateTime.now();
    if (preset == 'month') {
      _startDate = DateTime(now.year, now.month, 1);
      _endDate = now;
    } else if (preset == 'last_month') {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final lastDayPrevMonth = DateTime(now.year, now.month, 0);
      _startDate = prevMonth;
      _endDate = lastDayPrevMonth;
    } else if (preset == '30days') {
      _startDate = now.subtract(const Duration(days: 30));
      _endDate = now;
    } else if (preset == 'year') {
      _startDate = DateTime(now.year, 1, 1);
      _endDate = now;
    }
    _loadReportData();
  }

  @override
  Widget build(BuildContext context) {
    int totalPeriodIncome = _payments.fold(0, (sum, p) => sum + p.amountPaid);
    int totalArrears = _unpaidBills.fold(0, (sum, b) => sum + b.remainingAmount);

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Laporan Keuangan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_chart_rounded, color: Colors.white),
            tooltip: 'Ekspor Excel / Spreadsheet',
            onPressed: _exportCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Excel / Spreadsheet Export Action Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F766E), Color(0xFF134E4A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF0F766E).withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.table_view_rounded, color: Colors.white, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Ekspor Excel / Spreadsheet',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Unduh data transaksi atau tunggakan dalam format .CSV Excel yang kompatibel langsung dengan Google Sheets dan Microsoft Excel.',
                          style: TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0F766E),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                icon: const Icon(Icons.download, size: 16),
                                label: const Text('Ekspor Pemasukan'),
                                onPressed: _exportCsv,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                                icon: const Icon(Icons.file_upload_outlined, size: 16),
                                label: const Text('Ekspor Tunggakan'),
                                onPressed: _exportArrearsCsv,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Income Summary Metric Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Hari Ini',
                          amount: _dailyIncome,
                          color: AppTheme.toskaAccent,
                          icon: Icons.today_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          title: '7 Hari Terakhir',
                          amount: _weeklyIncome,
                          color: AppTheme.navyLight,
                          icon: Icons.date_range_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Bulan Ini',
                          amount: _monthlyIncome,
                          color: AppTheme.navyPrimary,
                          icon: Icons.calendar_month_rounded,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          title: 'Total Tunggakan',
                          amount: totalArrears,
                          color: AppTheme.statusDanger,
                          icon: Icons.warning_amber_rounded,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Date Filter Section
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Periode Laporan:', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${DateFormatter.formatReadable(_startDate)} — ${DateFormatter.formatReadable(_endDate)}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                ),
                                onPressed: _selectDateRange,
                                icon: const Icon(Icons.date_range, size: 16),
                                label: const Text('Kustom', style: TextStyle(fontSize: 12)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  label: const Text('Bulan Ini', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _setPreset('month'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  label: const Text('30 Hari', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _setPreset('30days'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  label: const Text('Bulan Lalu', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _setPreset('last_month'),
                                ),
                                const SizedBox(width: 6),
                                ActionChip(
                                  label: const Text('Tahun Ini', style: TextStyle(fontSize: 11)),
                                  onPressed: () => _setPreset('year'),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Income in Date Range Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.navyPrimary, Color(0xFF1E1B4B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Pemasukan Periode Ini',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.format(totalPeriodIncome),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            '${_payments.length} Transaksi',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Payment Method Breakdown
                  const Text(
                    'Rincian Berdasarkan Metode Bayar',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: PaymentMethod.all.map((m) {
                          final amount = _paymentMethodTotals[m] ?? 0;
                          final double pct = totalPeriodIncome > 0 ? (amount / totalPeriodIncome) : 0.0;
                          final pctString = (pct * 100).toStringAsFixed(1);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Column(
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(_getMethodIcon(m), size: 18, color: AppTheme.navyPrimary),
                                        const SizedBox(width: 8),
                                        Text(m, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                                      ],
                                    ),
                                    Text(
                                      '${CurrencyFormatter.format(amount)} ($pctString%)',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: LinearProgressIndicator(
                                    value: pct,
                                    minHeight: 6,
                                    backgroundColor: const Color(0xFFE2E8F0),
                                    valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.toskaAccent),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),

                  // Arrears Actions
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Tagihan Belum Lunas (${_unpaidBills.length})',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                      ),
                      TextButton.icon(
                        onPressed: _exportArrearsCsv,
                        icon: const Icon(Icons.table_chart, size: 16, color: Colors.green),
                        label: const Text('Ekspor Excel', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _unpaidBills.isEmpty
                      ? Card(
                          child: const Padding(
                            padding: EdgeInsets.all(20),
                            child: Center(
                              child: Text('Tidak ada tagihan tertunggak saat ini.', style: TextStyle(color: AppTheme.textSecondary)),
                            ),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _unpaidBills.take(5).length,
                          itemBuilder: (context, index) {
                            final b = _unpaidBills[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 6),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: const Color(0xFFFEE2E2),
                                  radius: 18,
                                  child: const Icon(Icons.priority_high, color: AppTheme.statusDanger, size: 18),
                                ),
                                title: Text(b.customerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text('${b.billNumber} • Jatuh Tempo: ${b.dueDate}', style: const TextStyle(fontSize: 11)),
                                trailing: Text(
                                  CurrencyFormatter.format(b.remainingAmount),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: AppTheme.statusDanger,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }

  Widget _buildMetricCard({
    required String title,
    required int amount,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            CurrencyFormatter.format(amount),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getMethodIcon(String method) {
    switch (method) {
      case PaymentMethod.cash:
        return Icons.money;
      case PaymentMethod.bankTransfer:
        return Icons.account_balance;
      case PaymentMethod.eWallet:
        return Icons.phone_android;
      default:
        return Icons.payment;
    }
  }
}
