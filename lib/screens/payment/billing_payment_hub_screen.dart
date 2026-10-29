import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/customer_model.dart';
import '../../models/payment_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/billing_calculator.dart';
import '../../utils/whatsapp_reminder_service.dart';
import '../bill/bill_detail_screen.dart';
import '../receipt/receipt_preview_screen.dart';
import '../../services/supabase_service.dart';

class BillingPaymentHubScreen extends StatefulWidget {
  final CustomerModel? initialCustomer;
  final BillModel? initialBill;
  final int initialTabIndex;

  const BillingPaymentHubScreen({
    super.key,
    this.initialCustomer,
    this.initialBill,
    this.initialTabIndex = 0,
  });

  @override
  State<BillingPaymentHubScreen> createState() => _BillingPaymentHubScreenState();
}

class _BillingPaymentHubScreenState extends State<BillingPaymentHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final BillRepository _billRepo = BillRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  // Tab 1: Payment state
  final TextEditingController _customerSearchCtrl = TextEditingController();
  final TextEditingController _amountCtrl = TextEditingController();
  final TextEditingController _notesCtrl = TextEditingController();

  List<CustomerModel> _allCustomers = [];
  List<CustomerModel> _filteredCustomers = [];
  CustomerModel? _selectedCustomer;
  List<BillModel> _customerUnpaidBills = [];
  BillModel? _selectedBill;
  String _paymentMethod = 'Tunai';
  bool _isProcessingPayment = false;

  final List<String> _paymentMethods = [
    'Tunai',
    'Transfer Bank',
    'QRIS',
    'E-Wallet',
    'Lainnya',
  ];

  // Tab 2: Unpaid bills state
  final TextEditingController _billSearchCtrl = TextEditingController();
  List<BillModel> _allUnpaidBills = [];
  List<BillModel> _filteredUnpaidBills = [];
  String _unpaidStatusFilter = 'Semua';
  bool _isLoadingBills = false;

  // Tab 3: Payment History state
  final TextEditingController _historySearchCtrl = TextEditingController();
  List<PaymentModel> _allPayments = [];
  List<PaymentModel> _filteredPayments = [];
  bool _isLoadingPayments = false;
  int _todayTotalIncome = 0;
  int _monthTotalIncome = 0;

  BusinessProfileModel? _business;

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.addListener(_onSupabaseChange);
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
    _loadInitialData();
  }

  @override
  void dispose() {
    SupabaseService.instance.removeListener(_onSupabaseChange);
    _tabController.dispose();
    _customerSearchCtrl.dispose();
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    _billSearchCtrl.dispose();
    _historySearchCtrl.dispose();
    super.dispose();
  }

  void _onSupabaseChange() {
    if (mounted) {
      _loadInitialData();
    }
  }

  Future<void> _loadInitialData() async {
    final biz = await _settingsRepo.getBusinessProfile();
    final customers = await _customerRepo.getCustomers(activeOnly: true);
    setState(() {
      _business = biz;
      _allCustomers = customers;
      _filteredCustomers = customers;
    });

    if (widget.initialCustomer != null) {
      _selectCustomer(widget.initialCustomer!);
    } else if (widget.initialBill != null) {
      final cust = await _customerRepo.getCustomerById(widget.initialBill!.customerId);
      if (cust != null) {
        await _selectCustomer(cust);
        setState(() {
          _selectedBill = _customerUnpaidBills.firstWhere(
            (b) => b.id == widget.initialBill!.id,
            orElse: () => _customerUnpaidBills.first,
          );
          if (_selectedBill != null) {
            _amountCtrl.text = _selectedBill!.remainingAmount.toString();
          }
        });
      }
    }

    await _loadUnpaidBills();
    await _loadPaymentHistory();
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Logic Catat Pembayaran
  // ---------------------------------------------------------------------------
  void _onCustomerSearch(String query) {
    final q = query.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredCustomers = _allCustomers;
      } else {
        _filteredCustomers = _allCustomers.where((c) {
          final code = c.customerCode.toLowerCase();
          final name = c.name.toLowerCase();
          final phone = c.phone.toLowerCase();
          return code.contains(q) || name.contains(q) || phone.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _selectCustomer(CustomerModel cust) async {
    setState(() {
      _selectedCustomer = cust;
      _customerSearchCtrl.text = '${cust.customerCode} - ${cust.name}';
      _filteredCustomers = [];
    });

    final bills = await _billRepo.getUnpaidBillsForCustomer(cust.id!);
    setState(() {
      _customerUnpaidBills = bills;
      if (bills.isNotEmpty) {
        _selectedBill = bills.first;
        _amountCtrl.text = _selectedBill!.remainingAmount.toString();
      } else {
        _selectedBill = null;
        _amountCtrl.text = '';
      }
    });
  }

  void _selectBill(BillModel bill) {
    setState(() {
      _selectedBill = bill;
      _amountCtrl.text = bill.remainingAmount.toString();
    });
  }

  void _setPresetAmount(int amount) {
    setState(() {
      _amountCtrl.text = amount.toString();
    });
  }

  Future<void> _submitPayment() async {
    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih pelanggan terlebih dahulu')),
      );
      return;
    }

    if (_selectedBill == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada tagihan yang dipilih untuk dibayar')),
      );
      return;
    }

    final rawAmount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan nominal pembayaran yang valid')),
      );
      return;
    }

    if (rawAmount > _selectedBill!.remainingAmount) {
      final confirmOverpay = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Nominal Melebihi Tagihan'),
          content: Text(
            'Nominal ${CurrencyFormatter.format(rawAmount)} melebihi sisa tagihan ${CurrencyFormatter.format(_selectedBill!.remainingAmount)}.\n\nSistem akan mencatat lunas sebesar sisa tagihan.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Lanjutkan')),
          ],
        ),
      );
      if (confirmOverpay != true) return;
    }

    setState(() => _isProcessingPayment = true);

    try {
      final payment = await _paymentRepo.recordPayment(
        bill: _selectedBill!,
        amountPaid: rawAmount,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.trim(),
      );

      // Refresh data
      await _loadUnpaidBills();
      await _loadPaymentHistory();
      if (_selectedCustomer != null) {
        await _selectCustomer(_selectedCustomer!);
      }

      if (mounted) {
        setState(() => _isProcessingPayment = false);

        // Success Dialog with instant actions
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: const [
                Icon(Icons.check_circle, color: AppTheme.statusSuccess, size: 28),
                SizedBox(width: 10),
                Text('Pembayaran Berhasil!'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kuitansi: ${payment.receiptNumber}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('Pelanggan: ${payment.customerName}'),
                Text('Nominal: ${CurrencyFormatter.format(payment.amountPaid)}'),
                Text('Metode: ${payment.paymentMethod}'),
                const Divider(height: 16),
                const Text('Kuitansi resmi telah tersimpan di sistem.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Selesai'),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyPrimary),
                icon: const Icon(Icons.print, size: 18),
                label: const Text('Buka Kuitansi'),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptPreviewScreen(payment: payment),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessingPayment = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencatat pembayaran: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Tab 2: Logic Tagihan Tertunggak
  // ---------------------------------------------------------------------------
  Future<void> _loadUnpaidBills() async {
    setState(() => _isLoadingBills = true);
    final bills = await _billRepo.getBills();
    // Filter only bills with remaining amount > 0 and not cancelled
    final unpaid = bills.where((b) => b.remainingAmount > 0 && !b.isCancelled).toList();
    if (mounted) {
      setState(() {
        _allUnpaidBills = unpaid;
        _applyUnpaidBillsFilter();
        _isLoadingBills = false;
      });
    }
  }

  void _applyUnpaidBillsFilter() {
    final q = _billSearchCtrl.text.trim().toLowerCase();
    setState(() {
      _filteredUnpaidBills = _allUnpaidBills.where((b) {
        final matchesQuery = q.isEmpty ||
            b.customerCode.toLowerCase().contains(q) ||
            b.customerName.toLowerCase().contains(q) ||
            b.billNumber.toLowerCase().contains(q);

        if (!matchesQuery) return false;

        if (_unpaidStatusFilter == 'Semua') return true;
        if (_unpaidStatusFilter == 'Terlambat') return b.status == BillStatus.overdue;
        if (_unpaidStatusFilter == 'Belum Bayar') return b.status == BillStatus.unpaid;
        if (_unpaidStatusFilter == 'Sebagian') return b.status == BillStatus.partial;
        return true;
      }).toList();
    });
  }

  // ---------------------------------------------------------------------------
  // Tab 3: Logic Riwayat Pembayaran & Kas
  // ---------------------------------------------------------------------------
  Future<void> _loadPaymentHistory() async {
    setState(() => _isLoadingPayments = true);
    final payments = await _paymentRepo.getPayments();
    final now = DateTime.now();
    final todayStr = DateFormatter.toIsoDateOnly(now);
    final thisMonthStr = '${now.year}-${now.month.toString().padLeft(2, '0')}';

    int todayIncome = 0;
    int monthIncome = 0;

    for (final p in payments) {
      if (!p.isCancelled) {
        if (p.paymentDate.startsWith(todayStr)) {
          todayIncome += p.amountPaid;
        }
        if (p.paymentDate.startsWith(thisMonthStr)) {
          monthIncome += p.amountPaid;
        }
      }
    }

    if (mounted) {
      setState(() {
        _allPayments = payments;
        _todayTotalIncome = todayIncome;
        _monthTotalIncome = monthIncome;
        _applyPaymentHistoryFilter();
        _isLoadingPayments = false;
      });
    }
  }

  void _applyPaymentHistoryFilter() {
    final q = _historySearchCtrl.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredPayments = _allPayments;
      } else {
        _filteredPayments = _allPayments.where((p) {
          return p.receiptNumber.toLowerCase().contains(q) ||
              p.customerName.toLowerCase().contains(q) ||
              p.customerCode.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case BillStatus.paid:
        return AppTheme.statusSuccess;
      case BillStatus.partial:
        return AppTheme.statusWarning;
      case BillStatus.overdue:
        return AppTheme.statusDanger;
      case BillStatus.cancelled:
        return Colors.grey;
      default:
        return AppTheme.navyPrimary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Billing & Pembayaran'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.payment, size: 20), text: 'Catat Bayar'),
            Tab(icon: Icon(Icons.pending_actions, size: 20), text: 'Tagihan Tertunggak'),
            Tab(icon: Icon(Icons.history, size: 20), text: 'Riwayat & Kas'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildQuickPaymentTab(),
          _buildUnpaidBillsTab(),
          _buildPaymentHistoryTab(),
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET TAB 1: CATAT BAYAR CEPAT
  // ===========================================================================
  Widget _buildQuickPaymentTab() {
    final hasCustomer = _selectedCustomer != null;
    final hasUnpaid = _customerUnpaidBills.isNotEmpty;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section 1: Customer Picker
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '1. Pilih Pelanggan',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyPrimary),
                    ),
                    if (hasCustomer)
                      TextButton.icon(
                        icon: const Icon(Icons.swap_horiz, size: 16),
                        label: const Text('Ganti', style: TextStyle(fontSize: 12)),
                        onPressed: () {
                          setState(() {
                            _selectedCustomer = null;
                            _customerSearchCtrl.clear();
                            _filteredCustomers = _allCustomers;
                            _customerUnpaidBills = [];
                            _selectedBill = null;
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                if (!hasCustomer) ...[
                  TextField(
                    controller: _customerSearchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Ketik ID (CUST-xxxx), Nama, atau No. HP...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _customerSearchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _customerSearchCtrl.clear();
                                _onCustomerSearch('');
                              },
                            )
                          : null,
                    ),
                    onChanged: _onCustomerSearch,
                  ),
                  if (_filteredCustomers.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 180),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _filteredCustomers.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final c = _filteredCustomers[i];
                          return ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              backgroundColor: AppTheme.navyPrimary.withOpacity(0.1),
                              child: Text(
                                c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                              ),
                            ),
                            title: Text('${c.customerCode} - ${c.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('${c.packageName} • ${c.phone}'),
                            trailing: c.totalArrears > 0
                                ? Text(
                                    CurrencyFormatter.format(c.totalArrears),
                                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.statusDanger, fontSize: 12),
                                  )
                                : const Text('Lunas', style: TextStyle(color: AppTheme.statusSuccess, fontSize: 12)),
                            onTap: () => _selectCustomer(c),
                          );
                        },
                      ),
                    ),
                  ],
                ] else ...[
                  // Selected Customer Profile Card
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFBBF7D0)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _selectedCustomer!.name,
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${_selectedCustomer!.customerCode} • ${_selectedCustomer!.phone}',
                                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _selectedCustomer!.totalArrears > 0 ? Colors.red.shade100 : Colors.green.shade100,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _selectedCustomer!.totalArrears > 0
                                    ? 'Tunggakan: ${CurrencyFormatter.format(_selectedCustomer!.totalArrears)}'
                                    : 'Semua Lunas',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: _selectedCustomer!.totalArrears > 0 ? Colors.red.shade900 : Colors.green.shade900,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Paket: ${_selectedCustomer!.packageName}',
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                            Text(
                              'Tarif/Hari: ${BillingCalculator.formatDailyFee(_selectedCustomer!.monthlyFee)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF0284C7)),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Section 2: Choose Bill
          if (hasCustomer) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '2. Pilih Tagihan yang Akan Dibayar',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyPrimary),
                  ),
                  const SizedBox(height: 12),
                  if (!hasUnpaid)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: AppTheme.statusSuccess, size: 20),
                          SizedBox(width: 8),
                          Text('Pelanggan ini tidak memiliki tagihan tertunggak.'),
                        ],
                      ),
                    )
                  else
                    ..._customerUnpaidBills.map((b) {
                      final isSelected = _selectedBill?.id == b.id;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? AppTheme.navyPrimary : Colors.grey.shade300,
                            width: isSelected ? 2 : 1,
                          ),
                          color: isSelected ? AppTheme.navyPrimary.withOpacity(0.04) : Colors.white,
                        ),
                        child: RadioListTile<int>(
                          value: b.id!,
                          groupValue: _selectedBill?.id,
                          onChanged: (_) => _selectBill(b),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)} (${b.billNumber})',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(b.status).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  b.status,
                                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _statusColor(b.status)),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            'Sisa: ${CurrencyFormatter.format(b.remainingAmount)} | Jatuh Tempo: ${b.dueDate}',
                            style: TextStyle(fontSize: 12, color: isSelected ? AppTheme.navyPrimary : AppTheme.textSecondary),
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Section 3: Nominal & Presets
          if (hasCustomer && hasUnpaid && _selectedBill != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '3. Jumlah Pembayaran (Rupiah)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.navyPrimary),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _amountCtrl,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                    decoration: InputDecoration(
                      labelText: 'Nominal yang Diterima',
                      prefixText: 'Rp ',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _amountCtrl.clear(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Presets
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.check, size: 16, color: Colors.green),
                        label: Text('Bayar Pas (${CurrencyFormatter.format(_selectedBill!.remainingAmount)})'),
                        onPressed: () => _setPresetAmount(_selectedBill!.remainingAmount),
                      ),
                      if (_selectedBill!.remainingAmount > 50000)
                        ActionChip(
                          label: const Text('Rp 50.000'),
                          onPressed: () => _setPresetAmount(50000),
                        ),
                      ActionChip(
                        label: const Text('Rp 85.000'),
                        onPressed: () => _setPresetAmount(85000),
                      ),
                      ActionChip(
                        label: const Text('Rp 100.000'),
                        onPressed: () => _setPresetAmount(100000),
                      ),
                      ActionChip(
                        label: const Text('Rp 150.000'),
                        onPressed: () => _setPresetAmount(150000),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Metode Pembayaran
                  DropdownButtonFormField<String>(
                    value: _paymentMethod,
                    decoration: const InputDecoration(
                      labelText: 'Metode Pembayaran',
                      prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                    items: _paymentMethods.map((m) {
                      return DropdownMenuItem(value: m, child: Text(m));
                    }).toList(),
                    onChanged: (v) => setState(() => _paymentMethod = v ?? 'Tunai'),
                  ),
                  const SizedBox(height: 12),

                  // Catatan Admin
                  TextField(
                    controller: _notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan Admin (Opsional)',
                      hintText: 'Misal: Titipan tetangga, transfer BCA, dll.',
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.toskaAccent,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: _isProcessingPayment
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                    label: Text(
                      _isProcessingPayment ? 'Memproses...' : 'Konfirmasi Bayar & Terbitkan Kuitansi',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _isProcessingPayment ? null : _submitPayment,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ===========================================================================
  // WIDGET TAB 2: DAFTAR TAGIHAN TERTUNGGAK
  // ===========================================================================
  Widget _buildUnpaidBillsTab() {
    final totalRemaining = _filteredUnpaidBills.fold<int>(0, (sum, b) => sum + b.remainingAmount);

    return Column(
      children: [
        // Summary & Search header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total Piutang / Tunggakan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        CurrencyFormatter.format(totalRemaining),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.statusDanger),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.navyPrimary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_filteredUnpaidBills.length} Tagihan',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _billSearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari tagihan: ID, Nama, No. Invoice...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _billSearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _billSearchCtrl.clear();
                            _applyUnpaidBillsFilter();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _applyUnpaidBillsFilter(),
              ),
              const SizedBox(height: 8),
              // Status filters
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ['Semua', 'Terlambat', 'Belum Bayar', 'Sebagian'].map((st) {
                    final isSel = _unpaidStatusFilter == st;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip(
                        label: Text(st, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppTheme.textPrimary)),
                        selected: isSel,
                        selectedColor: AppTheme.navyPrimary,
                        showCheckmark: false,
                        onSelected: (_) {
                          setState(() => _unpaidStatusFilter = st);
                          _applyUnpaidBillsFilter();
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        // List
        Expanded(
          child: _isLoadingBills
              ? const Center(child: CircularProgressIndicator())
              : _filteredUnpaidBills.isEmpty
                  ? const Center(
                      child: Text('Tidak ada tagihan tertunggak pada filter ini.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  : RefreshIndicator(
                      onRefresh: _loadUnpaidBills,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredUnpaidBills.length,
                        itemBuilder: (ctx, i) {
                          final b = _filteredUnpaidBills[i];
                          final isOverdue = b.status == BillStatus.overdue;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => BillDetailScreen(billId: b.id!)),
                                ).then((_) => _loadUnpaidBills());
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${b.customerCode} - ${b.customerName}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: _statusColor(b.status).withOpacity(0.12),
                                            borderRadius: BorderRadius.circular(6),
                                            border: Border.all(color: _statusColor(b.status), width: 1),
                                          ),
                                          child: Text(
                                            b.status,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: _statusColor(b.status),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        const Icon(Icons.calendar_month, size: 14, color: AppTheme.textSecondary),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)} • Jatuh Tempo: ${b.dueDate}',
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Sisa: ${CurrencyFormatter.format(b.remainingAmount)}',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.bold,
                                            color: isOverdue ? AppTheme.statusDanger : AppTheme.navyPrimary,
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            IconButton(
                                              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
                                              tooltip: 'Kirim Pengingat ke WA',
                                              onPressed: () {
                                                if (_business != null) {
                                                  final msg = WhatsAppReminderService.generateBillMessage(bill: b, business: _business!);
                                                  WhatsAppReminderService.shareToWhatsApp(message: msg);
                                                }
                                              },
                                            ),
                                            ElevatedButton(
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor: AppTheme.toskaAccent,
                                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                              ),
                                              onPressed: () async {
                                                // Switch to Tab 1 with this customer & bill selected
                                                final cust = await _customerRepo.getCustomerById(b.customerId);
                                                if (cust != null) {
                                                  await _selectCustomer(cust);
                                                  _selectBill(b);
                                                  _tabController.animateTo(0);
                                                }
                                              },
                                              child: const Text('Bayar'),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }

  // ===========================================================================
  // WIDGET TAB 3: RIWAYAT PEMBAYARAN & KAS
  // ===========================================================================
  Widget _buildPaymentHistoryTab() {
    return Column(
      children: [
        // Income summary header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0FDF4),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBBF7D0)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kas Hari Ini', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(_todayTotalIncome),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF16A34A)),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F9FF),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: const Color(0xFFBAE6FD)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Kas Bulan Ini', style: TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(_monthTotalIncome),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _historySearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Cari kuitansi: No. Kuitansi, Nama...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _historySearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _historySearchCtrl.clear();
                            _applyPaymentHistoryFilter();
                          },
                        )
                      : null,
                ),
                onChanged: (_) => _applyPaymentHistoryFilter(),
              ),
            ],
          ),
        ),
        // History List
        Expanded(
          child: _isLoadingPayments
              ? const Center(child: CircularProgressIndicator())
              : _filteredPayments.isEmpty
                  ? const Center(child: Text('Belum ada riwayat transaksi.', style: TextStyle(color: AppTheme.textSecondary)))
                  : RefreshIndicator(
                      onRefresh: _loadPaymentHistory,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _filteredPayments.length,
                        itemBuilder: (ctx, i) {
                          final p = _filteredPayments[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: p.isCancelled
                                    ? Colors.red.shade100
                                    : AppTheme.statusSuccess.withOpacity(0.12),
                                child: Icon(
                                  p.isCancelled ? Icons.close : Icons.receipt_long,
                                  color: p.isCancelled ? Colors.red : AppTheme.statusSuccess,
                                ),
                              ),
                              title: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      p.customerName,
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Text(
                                    CurrencyFormatter.format(p.amountPaid),
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: p.isCancelled ? Colors.grey : AppTheme.statusSuccess,
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('${p.receiptNumber} • ${p.paymentMethod}'),
                                  Text(
                                    DateFormatter.formatWithTime(DateFormatter.parseDate(p.paymentDate)),
                                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                  ),
                                  if (p.isCancelled)
                                    Text(
                                      'Dibatalkan: ${p.cancelReason}',
                                      style: const TextStyle(fontSize: 11, color: AppTheme.statusDanger),
                                    ),
                                ],
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.print, color: AppTheme.navyPrimary),
                                tooltip: 'Lihat Kuitansi',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ReceiptPreviewScreen(payment: p),
                                    ),
                                  );
                                },
                              ),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ],
    );
  }
}
