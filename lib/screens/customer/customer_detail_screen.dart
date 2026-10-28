import 'dart:io';
import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/bill_model.dart';
import '../../models/payment_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/app_theme.dart';
import '../../utils/whatsapp_reminder_service.dart';
import '../customer/customer_form_screen.dart';
import '../bill/bill_create_screen.dart';
import '../payment/payment_record_screen.dart';
import '../receipt/receipt_preview_screen.dart';
import '../../utils/sheets_exporter.dart';
import '../../utils/excel_exporter.dart';
import '../../utils/billing_calculator.dart';

class CustomerDetailScreen extends StatefulWidget {
  final int customerId;

  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  State<CustomerDetailScreen> createState() => _CustomerDetailScreenState();
}

class _CustomerDetailScreenState extends State<CustomerDetailScreen> with SingleTickerProviderStateMixin {
  final CustomerRepository _customerRepo = CustomerRepository();
  final BillRepository _billRepo = BillRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  CustomerModel? _customer;
  List<BillModel> _bills = [];
  List<PaymentModel> _payments = [];
  bool _isLoading = true;
  late TabController _tabController;
  BusinessProfileModel? _business;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final cust = await _customerRepo.getCustomerById(widget.customerId);
    final bills = await _billRepo.getBills(customerId: widget.customerId);
    final payments = await _paymentRepo.getPayments(customerId: widget.customerId);
    final business = await _settingsRepo.getBusinessProfile();

    if (mounted) {
      setState(() {
        _customer = cust;
        _bills = bills;
        _payments = payments;
        _business = business;
        _isLoading = false;
      });
    }
  }

  Future<void> _sendWhatsAppBill(BillModel bill) async {
    if (_business == null) return;
    final message = WhatsAppReminderService.generateBillMessage(
      bill: bill,
      business: _business!,
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

  Future<void> _toggleActiveStatus() async {
    if (_customer == null) return;
    final willActive = !_customer!.isActive;
    final actionText = willActive ? 'mengaktifkan kembali' : 'menonaktifkan';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Konfirmasi ${willActive ? 'Aktifkan' : 'Nonaktifkan'}'),
        content: Text(
          'Apakah Anda yakin ingin $actionText pelanggan ${_customer!.name}? '
          '${!willActive ? 'Tagihan bulanan otomatis tidak akan dibuat untuk pelanggan ini.' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: willActive ? AppTheme.toskaAccent : AppTheme.statusDanger,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(willActive ? 'Ya, Aktifkan' : 'Ya, Nonaktifkan'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _customerRepo.toggleCustomerStatus(_customer!.id!, willActive);
      _loadData();
    }
  }

  Future<void> _deleteHistory() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Riwayat Pelanggan'),
        content: Text(
          'Semua tagihan dan riwayat pembayaran milik "${_customer!.name}" akan dihapus permanen.\n\nData pelanggan tetap ada. Lanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Riwayat'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _customerRepo.deleteCustomerHistory(_customer!.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Riwayat berhasil dihapus'), backgroundColor: Colors.orange),
          );
          _loadData();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.statusDanger),
          );
        }
      }
    }
  }

  Future<void> _deleteCustomer() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text(
          'Pelanggan "${_customer!.name}" beserta SELURUH riwayat tagihan dan pembayarannya akan dihapus permanen.\n\n⚠️ Tindakan ini tidak dapat dibatalkan!',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus Permanen'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _customerRepo.deleteCustomer(_customer!.id!);
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Pelanggan berhasil dihapus'), backgroundColor: AppTheme.statusDanger),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal: $e'), backgroundColor: AppTheme.statusDanger),
          );
        }
      }
    }
  }

  Future<void> _showKtpDialog() async {
    if (_customer == null || _customer!.ktpImagePath == null || _customer!.ktpImagePath!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pelanggan belum memiliki foto KTP')),
      );
      return;
    }
    final file = File(_customer!.ktpImagePath!);
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppBar(
              title: const Text('Foto KTP Pelanggan'),
              automaticallyImplyLeading: false,
              actions: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: file.existsSync()
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(file, fit: BoxFit.contain),
                    )
                  : const Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text('File foto KTP tidak ditemukan pada penyimpanan perangkat.', textAlign: TextAlign.center),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _orderHajatanPackage() async {
    if (_customer == null) return;

    // Pilihan paket hajatan
    final hajatanOptions = [
      {
        'title': 'Paket Hajatan 50 Mbps',
        'speed': '50 Mbps',
        'price': 50000,
        'duration': '3 Hari',
        'desc': 'Speed 50 Mbps — Aktif selama 3 hari',
      },
      {
        'title': 'Paket Hajatan 100 Mbps',
        'speed': '100 Mbps',
        'price': 75000,
        'duration': '3 Hari',
        'desc': 'Speed 100 Mbps — Aktif selama 3 hari',
      },
    ];

    Map<String, dynamic>? selectedHajatan = hajatanOptions.first;
    String paymentMethod = 'Tunai (Cash)';
    bool autoPay = true; // default langsung buat kuitansi / resi

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: const [
                          Icon(Icons.celebration, color: AppTheme.amberWarning, size: 24),
                          SizedBox(width: 8),
                          Text(
                            'Order Paket Hajatan (3 Hari)',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx, false),
                      ),
                    ],
                  ),
                  const Text(
                    'Pilih paket hajatan untuk pelanggan ini. Tagihan dan resi terpisah akan otomatis dibuat.',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),
                  ...hajatanOptions.map((opt) {
                    final isSelected = selectedHajatan?['title'] == opt['title'];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: isSelected ? AppTheme.navyPrimary : Colors.grey.shade300,
                          width: isSelected ? 2 : 1,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        color: isSelected ? AppTheme.navyPrimary.withOpacity(0.04) : Colors.white,
                      ),
                      child: RadioListTile<Map<String, dynamic>>(
                        value: opt,
                        groupValue: selectedHajatan,
                        title: Text(
                          '${opt['title']} (3 Hari)',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(opt['desc'] as String),
                        secondary: Text(
                          CurrencyFormatter.format(opt['price'] as int),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: AppTheme.toskaAccent,
                          ),
                        ),
                        onChanged: (v) => setModalState(() => selectedHajatan = v),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('Langsung Catat Lunas & Cetak Resi', style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text('Buat pembayaran lunas sekarang dan langsung tampilkan resi kuitansi'),
                    value: autoPay,
                    activeColor: AppTheme.toskaAccent,
                    onChanged: (v) => setModalState(() => autoPay = v),
                    contentPadding: EdgeInsets.zero,
                  ),
                  if (autoPay) ...[
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: paymentMethod,
                      decoration: const InputDecoration(
                        labelText: 'Metode Pembayaran',
                        prefixIcon: Icon(Icons.account_balance_wallet),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Tunai (Cash)', child: Text('Tunai (Cash)')),
                        DropdownMenuItem(value: 'Transfer Bank', child: Text('Transfer Bank')),
                        DropdownMenuItem(value: 'QRIS', child: Text('QRIS')),
                      ],
                      onChanged: (v) => setModalState(() => paymentMethod = v ?? 'Tunai (Cash)'),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: const Icon(Icons.receipt_long),
                      label: Text(
                        autoPay ? 'Bayar & Buat Resi Paket Hajatan' : 'Buat Tagihan Hajatan',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (confirmed == true && selectedHajatan != null && mounted) {
      setState(() => _isLoading = true);
      try {
        final now = DateTime.now();
        final dueDate = now.add(const Duration(days: 3));
        final pkgTitle = '${selectedHajatan!['title']} (3 Hari)';
        final price = selectedHajatan!['price'] as int;

        // 1. Buat tagihan hajatan (allowDuplicate: true agar tidak bentrok dengan tagihan bulanan)
        final billId = await _billRepo.createBill(
          customer: _customer!,
          month: now.month,
          year: now.year,
          dueDate: dueDate,
          customAmount: price,
          customPackageId: _customer!.packageId,
          customPackageName: pkgTitle,
          notes: 'Paket Hajatan 3 Hari — Aktif s/d ${DateFormatter.formatDate(dueDate)}',
          allowDuplicate: true,
        );

        final bill = await _billRepo.getBillById(billId);

        if (bill != null && autoPay) {
          // 2. Buat pembayaran otomatis dan cetak resi sendiri
          final payment = await _paymentRepo.recordPayment(
            bill: bill,
            amountPaid: price,
            paymentMethod: paymentMethod,
            notes: 'Pembayaran Paket Hajatan (3 Hari)',
          );

          await _loadData();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tagihan & Resi Paket Hajatan berhasil dibuat ($pkgTitle)'),
                backgroundColor: AppTheme.statusSuccess,
              ),
            );

            // Buka halaman Resi Pembayaran
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ReceiptPreviewScreen(
                  payment: payment,
                  bill: bill,
                ),
              ),
            );
          }
        } else {
          await _loadData();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Tagihan Paket Hajatan ($pkgTitle) berhasil ditambahkan'),
                backgroundColor: AppTheme.statusSuccess,
              ),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal memesan paket hajatan: $e'), backgroundColor: AppTheme.statusDanger),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _exportToSheets() async {
    if (_customer == null) return;
    try {
      await SheetsExporter.exportCustomerData(
        customer: _customer!,
        bills: _bills,
        payments: _payments,
        context: context,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  Future<void> _exportToExcel() async {
    if (_customer == null) return;
    try {
      await ExcelExporter.exportAndShareCustomers(
        context: context,
        customers: [_customer!],
        isFiltered: true,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal ekspor Excel: $e'), backgroundColor: AppTheme.statusDanger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pelanggan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_customer == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detail Pelanggan')),
        body: const Center(child: Text('Data pelanggan tidak ditemukan')),
      );
    }

    final c = _customer!;
    final hasArrears = c.totalArrears > 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(c.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded),
            tooltip: 'Export ke Excel (.xlsx)',
            onPressed: _exportToExcel,
          ),
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Ubah Data',
            onPressed: () async {
              final res = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CustomerFormScreen(customer: c),
                ),
              );
              if (res == true) _loadData();
            },
          ),
          IconButton(
            icon: Icon(
              c.isActive ? Icons.person_off_outlined : Icons.person_add_alt_1_outlined,
              color: c.isActive ? Colors.amber.shade200 : Colors.green.shade200,
            ),
            tooltip: c.isActive ? 'Nonaktifkan' : 'Aktifkan',
            onPressed: _toggleActiveStatus,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              if (value == 'delete_history') _deleteHistory();
              if (value == 'delete_customer') _deleteCustomer();
              if (value == 'export_excel') _exportToExcel();
              if (value == 'export_sheets') _exportToSheets();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'export_excel', child: ListTile(
                leading: Icon(Icons.table_view_rounded, color: Color(0xFF107C41)),
                title: Text('Ekspor ke Excel (.xlsx)'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              const PopupMenuItem(value: 'export_sheets', child: ListTile(
                leading: Icon(Icons.table_chart, color: Colors.green),
                title: Text('Ekspor ke CSV/Sheets'),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'delete_history', child: ListTile(
                leading: Icon(Icons.delete_sweep, color: Colors.orange),
                title: Text('Hapus Riwayat Pelanggan'),
                subtitle: Text('Hapus semua tagihan & pembayaran', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
              const PopupMenuItem(value: 'delete_customer', child: ListTile(
                leading: Icon(Icons.person_remove, color: Colors.red),
                title: Text('Hapus Pelanggan'),
                subtitle: Text('Hapus pelanggan + semua riwayat', style: TextStyle(fontSize: 11)),
                contentPadding: EdgeInsets.zero,
                dense: true,
              )),
            ],
          ),
        ],
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                children: [
                  // Main Info Card
                  Container(
                    width: double.infinity,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF1E3A8A), Color(0xFF1E1B4B)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
                    ),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.customerCode,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: c.isActive
                                    ? AppTheme.statusSuccess
                                    : AppTheme.statusDanger,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                c.isActive ? 'AKTIF' : 'NONAKTIF',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          c.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              c.phone,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                            const SizedBox(width: 16),
                            const Icon(Icons.wifi, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Text(
                              c.packageName,
                              style: const TextStyle(color: Colors.white70, fontSize: 13),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 14, color: Colors.white70),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                c.address,
                                style: const TextStyle(color: Colors.white70, fontSize: 13),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Arrears Banner
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: hasArrears
                                ? Colors.red.shade900.withOpacity(0.4)
                                : Colors.teal.shade900.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: hasArrears ? Colors.red.shade400 : Colors.teal.shade300,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hasArrears ? 'Total Tunggakan' : 'Status Tagihan',
                                    style: const TextStyle(color: Colors.white70, fontSize: 11),
                                  ),
                                  Text(
                                    hasArrears
                                        ? CurrencyFormatter.format(c.totalArrears)
                                        : 'Semua Tagihan Lunas',
                                    style: TextStyle(
                                      color: hasArrears ? Colors.amberAccent : Colors.greenAccent,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                'Iuran: ${CurrencyFormatter.format(c.monthlyFee)}/bln\nJatuh Tempo: Tgl ${c.dueDay}',
                                textAlign: TextAlign.right,
                                style: const TextStyle(color: Colors.white70, fontSize: 11),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Quick Actions Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.toskaAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => PaymentRecordScreen(preselectedCustomer: c),
                                    ),
                                  );
                                  if (res == true) _loadData();
                                },
                                icon: const Icon(Icons.payments, size: 18),
                                label: const Text('Catat Bayar'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => BillCreateScreen(preselectedCustomer: c),
                                    ),
                                  );
                                  if (res == true) _loadData();
                                },
                                icon: const Icon(Icons.add_card, size: 18),
                                label: const Text('Buat Tagihan'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.amberWarning,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 11),
                                ),
                                onPressed: _orderHajatanPackage,
                                icon: const Icon(Icons.celebration, size: 18),
                                label: const Text(
                                  'Paket Hajatan (Resi)',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),
                            if (c.ktpImagePath != null && c.ktpImagePath!.isNotEmpty) ...[
                              const SizedBox(width: 10),
                              OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                                ),
                                onPressed: _showKtpDialog,
                                icon: const Icon(Icons.badge, size: 18, color: AppTheme.navyPrimary),
                                label: const Text('Foto KTP'),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Perhitungan Periode & Biaya Berlangganan (Section 3)
                  Container(
                    margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.calculate_outlined, color: AppTheme.navyPrimary, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Periode Langganan & Perhitungan Biaya',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.navyPrimary),
                            ),
                          ],
                        ),
                        const Divider(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _calcMetric(
                                label: 'Biaya per Hari',
                                value: BillingCalculator.formatDailyFee(c.monthlyFee),
                                subtitle: 'Harga paket ÷ 30',
                                color: const Color(0xFF0284C7),
                              ),
                            ),
                            Container(width: 1, height: 42, color: Colors.grey.shade200),
                            Expanded(
                              child: _calcMetric(
                                label: 'Biaya per Bulan',
                                value: CurrencyFormatter.format(c.monthlyFee),
                                subtitle: 'Tarif normal 30 hari',
                                color: AppTheme.navyPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _calcMetric(
                                label: 'Total Hari Langganan',
                                value: '${c.totalSubscriptionDays} Hari',
                                subtitle: 'Sejak ${DateFormatter.formatDate(DateFormatter.parseDate(c.startDate))}',
                                color: const Color(0xFF0F766E),
                              ),
                            ),
                            Container(width: 1, height: 42, color: Colors.grey.shade200),
                            Expanded(
                              child: _calcMetric(
                                label: 'Sisa Masa Aktif',
                                value: '${c.remainingActiveDays} Hari',
                                subtitle: 'Hingga ${DateFormatter.formatDate(c.activePeriodEndDate)}',
                                color: c.remainingActiveDays <= 3 ? AppTheme.amberWarning : const Color(0xFF16A34A),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Biaya Pemasangan Awal:', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                              Text(
                                CurrencyFormatter.format(c.installationFee),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.navyPrimary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.navyPrimary,
                  indicatorWeight: 3,
                  tabs: [
                    Tab(text: 'Tagihan (${_bills.length})'),
                    Tab(text: 'Pembayaran (${_payments.length})'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Bills Tab
            _bills.isEmpty
                ? const Center(child: Text('Belum ada riwayat tagihan.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _bills.length,
                    itemBuilder: (context, index) {
                      final b = _bills[index];
                      final isOverdue = b.status == BillStatus.overdue;

                      return Card(
                        child: ListTile(
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                DateFormatter.formatPeriod(b.periodMonth, b.periodYear),
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              _buildStatusBadge(b.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('No: ${b.billNumber} • Jatuh Tempo: ${b.dueDate}'),
                              const SizedBox(height: 2),
                              Text(
                                'Tagihan: ${CurrencyFormatter.format(b.amount)} | Dibayar: ${CurrencyFormatter.format(b.paidAmount)}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (b.remainingAmount > 0)
                                Text(
                                  'Sisa Tunggakan: ${CurrencyFormatter.format(b.remainingAmount)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOverdue ? AppTheme.statusDanger : AppTheme.navyPrimary,
                                  ),
                                ),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.send, color: Color(0xFF25D366), size: 20),
                                tooltip: 'Kirim Tagihan ke WhatsApp',
                                onPressed: () => _sendWhatsAppBill(b),
                              ),
                              if (b.remainingAmount > 0 && b.status != BillStatus.cancelled) ...[
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.toskaAccent,
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () async {
                                    final res = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => PaymentRecordScreen(
                                          preselectedCustomer: c,
                                          preselectedBill: b,
                                        ),
                                      ),
                                    );
                                    if (res == true) _loadData();
                                  },
                                  child: const Text('Bayar'),
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),

            // Payments Tab
            _payments.isEmpty
                ? const Center(child: Text('Belum ada riwayat pembayaran.'))
                : ListView.builder(
                    padding: const EdgeInsets.all(8),
                    itemCount: _payments.length,
                    itemBuilder: (context, index) {
                      final p = _payments[index];
                      final date = DateFormatter.parseDate(p.paymentDate);

                      return Card(
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: p.isCancelled
                                ? Colors.red.shade100
                                : AppTheme.statusSuccess.withOpacity(0.15),
                            child: Icon(
                              p.isCancelled ? Icons.close : Icons.receipt_long,
                              color: p.isCancelled ? Colors.red : AppTheme.statusSuccess,
                            ),
                          ),
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                CurrencyFormatter.format(p.amountPaid),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: p.isCancelled ? Colors.grey : AppTheme.textPrimary,
                                  decoration: p.isCancelled ? TextDecoration.lineThrough : null,
                                ),
                              ),
                              Text(
                                p.paymentMethod,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('No. Kuitansi: ${p.receiptNumber}'),
                              Text(DateFormatter.formatWithTime(date), style: const TextStyle(fontSize: 11)),
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
          ],
        ),
      ),
    );
  }

  Widget _calcMetric({
    required String label,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 1),
          Text(subtitle, style: const TextStyle(fontSize: 10, color: AppTheme.textMuted)),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bg;
    Color fg = Colors.white;

    switch (status) {
      case BillStatus.paid:
        bg = AppTheme.statusSuccess;
        break;
      case BillStatus.partial:
        bg = AppTheme.statusWarning;
        break;
      case BillStatus.overdue:
        bg = AppTheme.statusDanger;
        break;
      case BillStatus.cancelled:
        bg = Colors.grey;
        break;
      default:
        bg = AppTheme.navyLight;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status,
        style: TextStyle(color: fg, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _SliverAppBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
