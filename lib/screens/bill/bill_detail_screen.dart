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
import '../payment/payment_record_screen.dart';
import '../receipt/receipt_preview_screen.dart';

class BillDetailScreen extends StatefulWidget {
  final int billId;

  const BillDetailScreen({super.key, required this.billId});

  @override
  State<BillDetailScreen> createState() => _BillDetailScreenState();
}

class _BillDetailScreenState extends State<BillDetailScreen> {
  final BillRepository _billRepo = BillRepository();
  final CustomerRepository _customerRepo = CustomerRepository();
  final PaymentRepository _paymentRepo = PaymentRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();

  BillModel? _bill;
  CustomerModel? _customer;
  List<PaymentModel> _payments = [];
  BusinessProfileModel? _business;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final b = await _billRepo.getBillById(widget.billId);
    if (b != null) {
      final c = await _customerRepo.getCustomerById(b.customerId);
      final p = await _paymentRepo.getPayments(billId: b.id!, onlyActive: false);
      final biz = await _settingsRepo.getBusinessProfile();
      if (mounted) {
        setState(() {
          _bill = b;
          _customer = c;
          _payments = p;
          _business = biz;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _sendWhatsApp() async {
    if (_bill == null || _business == null) return;
    final message = WhatsAppReminderService.generateBillMessage(
      bill: _bill!,
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
                Text('Kirim Invoice ke WhatsApp', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
                        subject: 'Tagihan WiFi ${_bill!.customerName}',
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

  Future<void> _cancelBill() async {
    if (_bill == null) return;
    final reasonCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Batalkan Tagihan'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Apakah Anda yakin ingin membatalkan tagihan "${_bill!.billNumber}"?'),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan Pembatalan',
                hintText: 'Misal: Salah input nominal, paket ganti, dll.',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Batalkan Tagihan'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _billRepo.cancelBill(_bill!.id!, reasonCtrl.text.trim().isNotEmpty ? reasonCtrl.text.trim() : 'Dibatalkan oleh admin');
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tagihan berhasil dibatalkan'), backgroundColor: Colors.orange),
        );
      }
    }
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
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rincian Tagihan')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_bill == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Rincian Tagihan')),
        body: const Center(child: Text('Tagihan tidak ditemukan')),
      );
    }

    final b = _bill!;
    final canPay = b.remainingAmount > 0 && !b.isCancelled;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(b.billNumber),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Kirim ke WhatsApp',
            onPressed: _sendWhatsApp,
          ),
          if (!b.isCancelled && b.paidAmount == 0)
            IconButton(
              icon: const Icon(Icons.cancel_outlined, color: Colors.amberAccent),
              tooltip: 'Batalkan Tagihan',
              onPressed: _cancelBill,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Header Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2)),
                ],
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
                            DateFormatter.formatPeriod(b.periodMonth, b.periodYear),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text('Invoice: ${b.billNumber}', style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: _statusColor(b.status).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _statusColor(b.status), width: 1.2),
                        ),
                        child: Text(
                          b.status.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _statusColor(b.status),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Total Tagihan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(b.amount),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Text('Telah Dibayar', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(b.paidAmount),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.statusSuccess),
                          ),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text('Sisa Tagihan', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          const SizedBox(height: 2),
                          Text(
                            CurrencyFormatter.format(b.remainingAmount),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: b.remainingAmount > 0 ? AppTheme.statusDanger : AppTheme.statusSuccess,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  if (b.isCancelled) ...[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Text(
                        'Tagihan Dibatalkan: ${b.cancelReason}',
                        style: TextStyle(color: Colors.red.shade900, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Customer Info Card
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
                    children: const [
                      Icon(Icons.person, color: AppTheme.navyPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Informasi Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const Divider(height: 16),
                  _infoRow('Kode Pelanggan', b.customerCode),
                  _infoRow('Nama Pelanggan', b.customerName),
                  _infoRow('Nomor Telepon', b.customerPhone),
                  if (_customer != null) _infoRow('Alamat Pemasangan', _customer!.address),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Package & Billing Cycle Card
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
                    children: const [
                      Icon(Icons.wifi, color: AppTheme.navyPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Paket & Siklus Penagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const Divider(height: 16),
                  _infoRow('Paket Internet', b.packageName),
                  _infoRow(
                    'Periode Penagihan',
                    b.periodStart.isNotEmpty && b.periodEnd.isNotEmpty
                        ? '${b.periodStart} s/d ${b.periodEnd}'
                        : '${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)} (30 Hari)',
                  ),
                  _infoRow('Tanggal Jatuh Tempo', DateFormatter.formatReadable(DateFormatter.parseDate(b.dueDate))),
                  if (_customer != null)
                    _infoRow('Biaya per Hari (÷ 30)', BillingCalculator.formatDailyFee(_customer!.monthlyFee)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Cost Breakdown Card (Biaya Pemasangan, Langganan, Tambahan, Diskon)
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
                    children: const [
                      Icon(Icons.receipt, color: AppTheme.navyPrimary, size: 20),
                      SizedBox(width: 8),
                      Text('Rincian Komponen Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    ],
                  ),
                  const Divider(height: 16),
                  _breakdownRow(
                    'Biaya Langganan Internet (30 Hari)',
                    CurrencyFormatter.format(b.subscriptionFee > 0 ? b.subscriptionFee : b.amount - b.installationFee),
                  ),
                  if (b.installationFee > 0)
                    _breakdownRow('Biaya Pemasangan Awal (Custom)', CurrencyFormatter.format(b.installationFee)),
                  if (b.additionalFee > 0)
                    _breakdownRow('Biaya Tambahan Lainnya', CurrencyFormatter.format(b.additionalFee)),
                  if (b.discount > 0)
                    _breakdownRow('Diskon / Potongan Harga', '- ${CurrencyFormatter.format(b.discount)}', isDiscount: true),
                  const Divider(height: 16),
                  _breakdownRow(
                    'Total Tagihan',
                    CurrencyFormatter.format(b.amount),
                    isBold: true,
                    highlightColor: AppTheme.navyPrimary,
                  ),
                  _breakdownRow(
                    'Jumlah Terbayar',
                    CurrencyFormatter.format(b.paidAmount),
                    highlightColor: AppTheme.statusSuccess,
                  ),
                  _breakdownRow(
                    'Sisa Tagihan (Tunggakan)',
                    CurrencyFormatter.format(b.remainingAmount),
                    isBold: true,
                    highlightColor: b.remainingAmount > 0 ? AppTheme.statusDanger : AppTheme.statusSuccess,
                  ),
                  if (b.notes.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Catatan Admin: ${b.notes}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontStyle: FontStyle.italic)),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Payments History on this Bill
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
                      Row(
                        children: const [
                          Icon(Icons.history, color: AppTheme.navyPrimary, size: 20),
                          SizedBox(width: 8),
                          Text('Riwayat Pembayaran Tagihan Ini', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        ],
                      ),
                      Text('${_payments.length} Kuitansi', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    ],
                  ),
                  const Divider(height: 16),
                  if (_payments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Center(
                        child: Text('Belum ada pembayaran yang tercatat untuk tagihan ini.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                      ),
                    )
                  else
                    ..._payments.map((p) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.receiptNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                const SizedBox(height: 2),
                                Text(
                                  '${DateFormatter.formatWithTime(DateFormatter.parseDate(p.paymentDate))} • ${p.paymentMethod}',
                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  CurrencyFormatter.format(p.amountPaid),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.statusSuccess),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.print, size: 18, color: AppTheme.navyPrimary),
                                  tooltip: 'Lihat Kuitansi',
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => ReceiptPreviewScreen(payment: p, bill: b)),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bottom Action Button
            if (canPay) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.toskaAccent,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.payments, color: Colors.white),
                label: Text(
                  'Catat Pembayaran (${CurrencyFormatter.format(b.remainingAmount)})',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                onPressed: () async {
                  final res = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PaymentRecordScreen(
                        preselectedCustomer: _customer,
                        preselectedBill: b,
                      ),
                    ),
                  );
                  if (res == true) _loadData();
                },
              ),
              const SizedBox(height: 10),
            ],
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
              label: const Text('Kirim Pengingat Invoice ke WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: _sendWhatsApp,
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
          Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        ],
      ),
    );
  }

  Widget _breakdownRow(
    String label,
    String value, {
    bool isBold = false,
    bool isDiscount = false,
    Color? highlightColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: isDiscount ? Colors.green.shade700 : AppTheme.textSecondary,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isBold ? 15 : 13,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: highlightColor ?? (isDiscount ? Colors.green.shade700 : AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}
