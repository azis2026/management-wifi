import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/app_theme.dart';
import '../../utils/whatsapp_reminder_service.dart';
import '../payment/payment_record_screen.dart';

class DueReminderScreen extends StatefulWidget {
  const DueReminderScreen({super.key});

  @override
  State<DueReminderScreen> createState() => _DueReminderScreenState();
}

class _DueReminderScreenState extends State<DueReminderScreen> with SingleTickerProviderStateMixin {
  final BillRepository _billRepo = BillRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  late TabController _tabController;
  List<BillModel> _allUnpaidBills = [];
  bool _isLoading = true;
  BusinessProfileModel _business = BusinessProfileModel(
    businessName: 'WiFi Net Mandiri',
    contactPhone: '0812-3456-7890',
    address: 'Jl. Merdeka No. 10',
    receiptFooter: 'Terima kasih atas pembayaran Anda.',
  );

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final profile = await _settingsRepo.getBusinessProfile();
    final bills = await _billRepo.getBills();

    final unpaid = bills.where((b) =>
        b.status == BillStatus.unpaid ||
        b.status == BillStatus.partial ||
        b.status == BillStatus.overdue).toList();

    if (mounted) {
      setState(() {
        _business = profile;
        _allUnpaidBills = unpaid;
        _isLoading = false;
      });
    }
  }

  List<BillModel> get _todayBills {
    final today = DateFormatter.toIsoDateOnly(DateTime.now());
    return _allUnpaidBills.where((b) => b.dueDate == today).toList();
  }

  List<BillModel> get _approachingBills {
    final now = DateTime.now();
    final tomorrow = DateFormatter.toIsoDateOnly(now.add(const Duration(days: 1)));
    final in3Days = DateFormatter.toIsoDateOnly(now.add(const Duration(days: 3)));
    return _allUnpaidBills.where((b) => b.dueDate.compareTo(tomorrow) >= 0 && b.dueDate.compareTo(in3Days) <= 0).toList();
  }

  List<BillModel> get _overdueBills {
    final today = DateFormatter.toIsoDateOnly(DateTime.now());
    return _allUnpaidBills.where((b) => b.dueDate.compareTo(today) < 0).toList();
  }

  List<BillModel> _currentActiveBills() {
    switch (_tabController.index) {
      case 0:
        return _todayBills;
      case 1:
        return _approachingBills;
      case 2:
        return _overdueBills;
      default:
        return _todayBills;
    }
  }

  Future<void> _sendWhatsAppSingle(BillModel bill) async {
    final message = WhatsAppReminderService.generateBillMessage(
      bill: bill,
      business: _business,
    );

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.chat, color: Colors.green, size: 24),
                SizedBox(width: 8),
                Text('Kirim Tagihan ke WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      WhatsAppReminderService.copyToClipboard(message);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Pesan berhasil disalin!'), backgroundColor: AppTheme.statusSuccess),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppReminderService.shareToWhatsApp(
                        message: message,
                        subject: 'Tagihan WiFi ${bill.customerName}',
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Kirim ke WA', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _sendWhatsAppBatch() async {
    final bills = _currentActiveBills();
    if (bills.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tagihan pada kategori ini')),
      );
      return;
    }

    final message = WhatsAppReminderService.generateBatchSummaryMessage(
      bills: bills,
      business: _business,
    );

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups, color: AppTheme.navyPrimary, size: 26),
                const SizedBox(width: 8),
                Text('Kirim Masal (${bills.length} Pelanggan)', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Rekap tagihan seluruh pelanggan yang belum lunas pada tab ini siap dibagikan ke WhatsApp pengurus/grup/kolektor.',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                message,
                maxLines: 8,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      WhatsAppReminderService.copyToClipboard(message);
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Rekap masal berhasil disalin!'), backgroundColor: AppTheme.statusSuccess),
                      );
                    },
                    icon: const Icon(Icons.copy),
                    label: const Text('Salin Rekap'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppReminderService.shareToWhatsApp(
                        message: message,
                        subject: 'Rekap Tagihan WiFi Masal',
                      );
                    },
                    icon: const Icon(Icons.send),
                    label: const Text('Bagikan ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Pengingat Jatuh Tempo'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            tooltip: 'Kirim Rekap Tagihan Masal ke WhatsApp',
            onPressed: _sendWhatsAppBatch,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _loadData,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: AppTheme.toskaAccent,
          indicatorWeight: 3,
          onTap: (_) => setState(() {}),
          tabs: [
            Tab(text: 'Hari Ini (${_todayBills.length})'),
            Tab(text: 'Mendekati (${_approachingBills.length})'),
            Tab(text: 'Terlambat (${_overdueBills.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBillList(_todayBills, 'Tidak ada tagihan yang jatuh tempo hari ini.', AppTheme.statusWarning),
                _buildBillList(_approachingBills, 'Tidak ada tagihan yang mendekati jatuh tempo (1-3 hari ke depan).', AppTheme.navyPrimary),
                _buildBillList(_overdueBills, 'Tidak ada tagihan yang terlambat. Luar biasa!', AppTheme.statusDanger),
              ],
            ),
    );
  }

  Widget _buildBillList(List<BillModel> bills, String emptyMessage, Color accentColor) {
    if (bills.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.verified_outlined, size: 64, color: AppTheme.statusSuccess),
              const SizedBox(height: 12),
              Text(
                emptyMessage,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: bills.length,
      itemBuilder: (context, index) {
        final b = bills[index];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      b.customerCode,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.navyPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Jatuh Tempo: ${b.dueDate}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: accentColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  b.customerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      b.customerPhone.isNotEmpty ? b.customerPhone : 'Tanpa nomor telepon',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 14),
                    const Icon(Icons.wifi, size: 13, color: AppTheme.toskaAccent),
                    const SizedBox(width: 4),
                    Text(
                      b.packageName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Periode: ${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)}',
                          style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                        ),
                        Text(
                          CurrencyFormatter.format(b.remainingAmount),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                          onPressed: () => _sendWhatsAppSingle(b),
                          icon: const Icon(Icons.send, size: 14),
                          label: const Text('Kirim WA'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.toskaAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            textStyle: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () async {
                            final res = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => PaymentRecordScreen(preselectedBill: b),
                              ),
                            );
                            if (res == true) _loadData();
                          },
                          icon: const Icon(Icons.payments, size: 14),
                          label: const Text('Bayar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
