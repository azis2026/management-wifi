import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/payment_model.dart';
import '../../models/customer_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/app_theme.dart';
import '../../utils/whatsapp_reminder_service.dart';
import 'customer/customer_form_screen.dart';
import 'customer/customer_detail_screen.dart';
import 'payment/payment_record_screen.dart';
import 'payment/payment_history_screen.dart';

import 'bill/bill_list_screen.dart';
import 'due_reminders/due_reminder_screen.dart';
import 'receipt/receipt_preview_screen.dart';
import '../services/session_service.dart';
import '../app.dart';

class HomeScreen extends StatefulWidget {
  final Function(int)? onNavigateTab;

  const HomeScreen({super.key, this.onNavigateTab});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final BillRepository _billRepo = BillRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  Map<String, dynamic> _stats = {};
  List<PaymentModel> _recentPayments = [];
  List<CustomerModel> _recentCustomers = [];
  BusinessProfileModel? _businessProfile;
  String _businessName = 'WiFi Net Mandiri';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);

    // Auto-generate recurring bills for active customers every 30 days
    await _billRepo.autoGenerateRecurringBills();

    final profile = await _settingsRepo.getBusinessProfile();
    final stats = await _billRepo.getDashboardStats();
    final recent = await _paymentRepo.getRecentPayments(limit: 5);
    final recentCusts = (stats['recent_customers'] as List<CustomerModel>?) ?? [];

    if (mounted) {
      setState(() {
        _businessProfile = profile;
        _businessName = profile.businessName;
        _stats = stats;
        _recentPayments = recent;
        _recentCustomers = recentCusts;
        _isLoading = false;
      });
    }
  }

  Future<void> _triggerManualAutoBilling() async {
    setState(() => _isLoading = true);
    final res = await _billRepo.autoGenerateRecurringBills();
    await _loadDashboardData();

    if (mounted) {
      final generated = res['generated'] ?? 0;
      final totalActive = res['total_active'] ?? 0;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.autorenew, color: AppTheme.navyPrimary),
              SizedBox(width: 8),
              Text('Penagihan Otomatis'),
            ],
          ),
          content: Text(
            generated > 0
                ? 'Berhasil menerbitkan $generated tagihan rutin baru untuk periode 30 hari berikutnya dari $totalActive pelanggan aktif.'
                : 'Semua $totalActive pelanggan aktif sudah memiliki tagihan untuk periode berjalannya. Tidak ada tagihan duplikat yang dibuat.',
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 11) return 'Selamat Pagi';
    if (hour < 15) return 'Selamat Siang';
    if (hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _sendWhatsAppReminder(BillModel bill) async {
    if (_businessProfile == null) return;
    final message = WhatsAppReminderService.generateBillMessage(
      bill: bill,
      business: _businessProfile!,
    );

    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.chat, color: Color(0xFF25D366), size: 24),
                SizedBox(width: 8),
                Text('Kirim Tagihan ke WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Text(
                message,
                maxLines: 7,
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
                        const SnackBar(content: Text('Pesan tagihan disalin!'), backgroundColor: AppTheme.statusSuccess),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
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
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      WhatsAppReminderService.shareToWhatsApp(
                        phone: bill.customerPhone,
                        message: message,
                        subject: 'Tagihan WiFi ${bill.customerName}',
                      );
                    },
                    icon: const Icon(Icons.send, size: 18),
                    label: const Text('Buka WhatsApp'),
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('WiFi Manager')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final totalCustomers = _stats['total_customers'] ?? 0;
    final activeCustomers = _stats['active_customers'] ?? 0;
    final inactiveCustomers = _stats['inactive_customers'] ?? 0;

    final incomeThisMonth = _stats['income_this_month'] ?? 0;
    final monthBillsCount = _stats['month_bills_count'] ?? 0;

    final paidBillsMonth = _stats['paid_bills_month'] ?? 0;
    final unpaidBillsCount = _stats['unpaid_bills_count'] ?? 0;
    final overdueBillsCount = _stats['overdue_bills_count'] ?? 0;
    final totalArrears = _stats['total_arrears'] ?? 0;
    final List<BillModel> approachingBills =
        (_stats['approaching_bills'] as List<BillModel>?) ?? [];

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${_getGreeting()} 👋',
              style: const TextStyle(fontSize: 13, color: Colors.white70, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 2),
            Text(
              _businessName,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 0.2),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: InkWell(
              onTap: () async {
                final adminName = SessionService.instance.currentAdmin?.name ?? 'Admin';
                final action = await showModalBottomSheet<String>(
                  context: context,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (ctx) => Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: AppTheme.navyPrimary,
                              child: Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    adminName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Text(
                                    SessionService.instance.currentAdmin?.email ?? 'Terhubung ke REST API',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 28),
                        ListTile(
                          leading: const Icon(Icons.logout, color: Colors.red),
                          title: const Text('Keluar (Logout)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          onTap: () => Navigator.pop(ctx, 'logout'),
                        ),
                      ],
                    ),
                  ),
                );

                if (action == 'logout') {
                  await SessionService.instance.logout();
                  if (context.mounted) {
                    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const AuthGate()),
                      (route) => false,
                    );
                  }
                }
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Colors.greenAccent,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_done,
                      size: 14,
                      color: Colors.greenAccent,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      (SessionService.instance.currentAdmin?.name ?? 'Admin').split(' ').first,
                      style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.autorenew),
            tooltip: 'Cek Tagihan Rutin Otomatis',
            onPressed: _triggerManualAutoBilling,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan Data',
            onPressed: _loadDashboardData,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Main Banner: Pemasukan Bulan Ini & Tunggakan
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E3A8A), Color(0xFF1E1B4B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E3A8A).withOpacity(0.28),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.account_balance_wallet, color: Colors.white70, size: 16),
                            SizedBox(width: 6),
                            Text(
                              'Pemasukan Bulan Ini',
                              style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            DateFormatter.formatPeriod(DateTime.now().month, DateTime.now().year),
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      CurrencyFormatter.format(incomeThisMonth),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Total Tunggakan Pelanggan',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(totalArrears),
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: totalArrears > 0 ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            height: 32,
                            width: 1,
                            color: Colors.white24,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Tagihan Bulan Berjalan',
                                  style: TextStyle(color: Colors.white70, fontSize: 11),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '$monthBillsCount ($paidBillsMonth Lunas)',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Customer Summary Pill Bar (Total, Aktif, Tidak Aktif)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _customerStatItem('Total Pelanggan', totalCustomers.toString(), AppTheme.navyPrimary),
                    Container(width: 1, height: 28, color: Colors.grey.shade200),
                    _customerStatItem('Pelanggan Aktif', activeCustomers.toString(), const Color(0xFF16A34A)),
                    Container(width: 1, height: 28, color: Colors.grey.shade200),
                    _customerStatItem('Tidak Aktif', inactiveCustomers.toString(), Colors.grey.shade600),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Summary Stats 3-Column Grid (Lunas, Belum Bayar, Terlambat)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _buildMiniStat(
                        label: 'Lunas Bulan Ini',
                        count: paidBillsMonth,
                        color: AppTheme.statusSuccess,
                        icon: Icons.check_circle_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BillListScreen(initialStatusFilter: BillStatus.paid),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStat(
                        label: 'Belum Bayar',
                        count: unpaidBillsCount,
                        color: AppTheme.amberWarning,
                        icon: Icons.schedule,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BillListScreen(initialStatusFilter: BillStatus.unpaid),
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildMiniStat(
                        label: 'Terlambat',
                        count: overdueBillsCount,
                        color: AppTheme.statusDanger,
                        icon: Icons.error_outline,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const BillListScreen(initialStatusFilter: BillStatus.overdue),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Quick Actions
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Aksi Cepat & Pelayanan',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Tambah Pelanggan',
                            subtitle: 'ID, Biaya Pasang & Paket',
                            icon: Icons.person_add_alt_1_rounded,
                            color: AppTheme.navyPrimary,
                            onTap: () async {
                              final res = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const CustomerFormScreen(),
                                ),
                              );
                              if (res == true) _loadDashboardData();
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Catat Pembayaran',
                            subtitle: 'Kuitansi & Resi Resmi',
                            icon: Icons.payments_rounded,
                            color: AppTheme.toskaAccent,
                            onTap: () async {
                              final res = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const PaymentRecordScreen(),
                                ),
                              );
                              if (res == true) _loadDashboardData();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Tagihan Rutin 30 Hari',
                            subtitle: 'Generate Otomatis',
                            icon: Icons.autorenew_rounded,
                            color: const Color(0xFF6366F1),
                            onTap: _triggerManualAutoBilling,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionCard(
                            title: 'Jatuh Tempo & WA',
                            subtitle: 'Kirim Pengingat',
                            icon: Icons.notifications_active_rounded,
                            color: const Color(0xFFEA580C),
                            onTap: () async {
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const DueReminderScreen(),
                                ),
                              );
                              _loadDashboardData();
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Approaching Due Date Section
              if (approachingBills.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.statusDanger),
                          const SizedBox(width: 6),
                          const Text(
                            'Tindakan Admin: Tagihan Jatuh Tempo',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.statusDanger.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${approachingBills.length}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.statusDanger),
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const DueReminderScreen()),
                        ),
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: approachingBills.take(4).length,
                  itemBuilder: (context, index) {
                    final b = approachingBills[index];
                    final isOverdue = b.status == BillStatus.overdue;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 20,
                              backgroundColor: isOverdue ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
                              child: Icon(
                                isOverdue ? Icons.error_outline : Icons.schedule,
                                color: isOverdue ? AppTheme.statusDanger : AppTheme.amberWarning,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    b.customerName,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Tempo: ${b.dueDate} • Sisa: ${CurrencyFormatter.format(b.remainingAmount)}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: isOverdue ? AppTheme.statusDanger : AppTheme.textSecondary,
                                      fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 22),
                              tooltip: 'Kirim WhatsApp',
                              onPressed: () => _sendWhatsAppReminder(b),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.toskaAccent,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                minimumSize: Size.zero,
                              ),
                              onPressed: () async {
                                final res = await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => PaymentRecordScreen(preselectedBill: b),
                                  ),
                                );
                                if (res == true) _loadDashboardData();
                              },
                              child: const Text('Bayar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Recent Customers Section
              if (_recentCustomers.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.people_alt_outlined, size: 20, color: AppTheme.navyPrimary),
                          SizedBox(width: 6),
                          Text(
                            'Pelanggan Terbaru',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => widget.onNavigateTab?.call(1),
                        child: const Text('Lihat Semua'),
                      ),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentCustomers.take(3).length,
                  itemBuilder: (context, index) {
                    final c = _recentCustomers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.navyPrimary.withOpacity(0.1),
                          child: Text(
                            c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                          ),
                        ),
                        title: Text(c.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text('${c.customerCode} • ${c.packageName} (${CurrencyFormatter.format(c.monthlyFee)}/bln)', style: const TextStyle(fontSize: 11)),
                        trailing: Icon(
                          c.isActive ? Icons.check_circle : Icons.cancel,
                          color: c.isActive ? const Color(0xFF16A34A) : Colors.grey,
                          size: 18,
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CustomerDetailScreen(customerId: c.id!),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),
              ],

              // Recent Transactions Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.history_rounded, size: 20, color: AppTheme.navyPrimary),
                        SizedBox(width: 6),
                        Text(
                          'Transaksi Pembayaran Terbaru',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PaymentHistoryScreen()),
                      ),
                      child: const Text('Semua'),
                    ),
                  ],
                ),
              ),
              _recentPayments.isEmpty
                  ? Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Center(
                        child: Column(
                          children: const [
                            Icon(Icons.receipt_long_outlined, size: 40, color: AppTheme.textMuted),
                            SizedBox(height: 8),
                            Text(
                              'Belum ada transaksi pembayaran bulan ini',
                              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _recentPayments.length,
                      itemBuilder: (context, index) {
                        final p = _recentPayments[index];
                        final date = DateFormatter.parseDate(p.paymentDate);

                        return Card(
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: p.isCancelled
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFD1FAE5),
                              child: Icon(
                                p.isCancelled ? Icons.close : Icons.receipt_long_rounded,
                                color: p.isCancelled ? AppTheme.statusDanger : AppTheme.statusSuccess,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              p.customerName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                              ),
                            ),
                            subtitle: Text(
                              '${p.receiptNumber} • ${DateFormatter.formatWithTime(date)}',
                              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  CurrencyFormatter.format(p.amountPaid),
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: p.isCancelled ? Colors.grey : AppTheme.statusSuccess,
                                    decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    p.paymentMethod,
                                    style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ReceiptPreviewScreen(payment: p),
                                ),
                              );
                            },
                          ),
                        );
                      },
                    ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _customerStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
      ],
    );
  }

  Widget _buildMiniStat({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              count.toString(),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 10,
                      color: AppTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
