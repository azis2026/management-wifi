import 'package:flutter/material.dart';
import '../../models/bill_model.dart';
import '../../models/customer_model.dart';
import '../../repositories/payment_repository.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../receipt/receipt_preview_screen.dart';

class PaymentRecordScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;
  final BillModel? preselectedBill;

  const PaymentRecordScreen({super.key, this.preselectedCustomer, this.preselectedBill});

  @override
  State<PaymentRecordScreen> createState() => _PaymentRecordScreenState();
}

class _PaymentRecordScreenState extends State<PaymentRecordScreen> {
  final _paymentRepo = PaymentRepository();
  final _billRepo = BillRepository();
  final _customerRepo = CustomerRepository();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  List<CustomerModel> _customers = [];
  List<BillModel> _unpaidBills = [];
  CustomerModel? _selectedCustomer;
  BillModel? _selectedBill;
  String _paymentMethod = 'Tunai';
  bool _isLoading = false;

  final List<String> _methods = ['Tunai', 'Transfer Bank', 'QRIS', 'E-Wallet', 'Lainnya'];

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await _customerRepo.getCustomers(activeOnly: true);
    setState(() {
      _customers = list;
      if (widget.preselectedCustomer != null) {
        _selectedCustomer = list.firstWhere(
          (c) => c.id == widget.preselectedCustomer!.id,
          orElse: () => list.first,
        );
      } else if (list.isNotEmpty) {
        _selectedCustomer = list.first;
      }
    });
    if (_selectedCustomer != null) await _loadUnpaidBills();
  }

  Future<void> _loadUnpaidBills() async {
    if (_selectedCustomer?.id == null) return;
    final bills = await _billRepo.getUnpaidBillsForCustomer(_selectedCustomer!.id!);
    setState(() {
      _unpaidBills = bills;
      if (widget.preselectedBill != null) {
        _selectedBill = bills.firstWhere(
          (b) => b.id == widget.preselectedBill!.id,
          orElse: () => bills.isNotEmpty ? bills.first : bills.first,
        );
      } else {
        _selectedBill = bills.isNotEmpty ? bills.first : null;
      }
      _setDefaultAmount();
    });
  }

  void _setDefaultAmount() {
    if (_selectedBill != null) {
      _amountCtrl.text = _selectedBill!.remainingAmount.toString();
    }
  }

  Future<void> _record() async {
    if (_selectedCustomer == null || _selectedBill == null) return;
    final amount = int.tryParse(_amountCtrl.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan jumlah pembayaran yang valid')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final payment = await _paymentRepo.recordPayment(
        bill: _selectedBill!,
        amountPaid: amount,
        paymentMethod: _paymentMethod,
        notes: _notesCtrl.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context, true);
        // Show receipt preview option
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Pembayaran berhasil dicatat'),
          backgroundColor: AppTheme.statusSuccess,
          action: SnackBarAction(
            label: 'Lihat Kuitansi',
            textColor: Colors.white,
            onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => ReceiptPreviewScreen(payment: payment),
            )),
          ),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Gagal: $e'),
          backgroundColor: AppTheme.statusDanger,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(title: const Text('Catat Pembayaran')),
      body: _customers.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.person_pin, color: AppTheme.navyPrimary, size: 20),
                            SizedBox(width: 8),
                            Text('Pilih Pelanggan & Tagihan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary)),
                          ],
                        ),
                        const SizedBox(height: 14),
                        // Customer selector
                        DropdownButtonFormField<CustomerModel>(
                          value: _selectedCustomer,
                          decoration: const InputDecoration(
                            labelText: 'Pelanggan *',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          items: _customers.map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(
                              '${c.name} (${c.customerCode})',
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 14),
                            ),
                          )).toList(),
                          onChanged: (c) {
                            setState(() { _selectedCustomer = c; _selectedBill = null; _unpaidBills = []; });
                            _loadUnpaidBills();
                          },
                        ),
                        const SizedBox(height: 14),
                        // Bill selector
                        if (_unpaidBills.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFD1FAE5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFA7F3D0)),
                            ),
                            child: Row(
                              children: const [
                                Icon(Icons.check_circle_rounded, color: AppTheme.statusSuccess, size: 22),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Pelanggan ini tidak memiliki tagihan tertunggak (Lunas).',
                                    style: TextStyle(color: Color(0xFF065F46), fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          )
                        else ...[
                          DropdownButtonFormField<BillModel>(
                            value: _selectedBill,
                            decoration: const InputDecoration(
                              labelText: 'Pilih Tagihan yang Dibayar *',
                              prefixIcon: Icon(Icons.receipt_outlined),
                            ),
                            items: _unpaidBills.map((b) => DropdownMenuItem(
                              value: b,
                              child: Text(
                                '${DateFormatter.formatPeriod(b.periodMonth, b.periodYear)} • Sisa ${CurrencyFormatter.format(b.remainingAmount)}',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13),
                              ),
                            )).toList(),
                            onChanged: (b) { setState(() => _selectedBill = b); _setDefaultAmount(); },
                          ),
                          if (_selectedBill != null) ...[
                            const SizedBox(height: 12),
                            // Quick Amount chips
                            Row(
                              children: [
                                ActionChip(
                                  avatar: const Icon(Icons.check, size: 16, color: AppTheme.statusSuccess),
                                  label: Text('Bayar Lunas: ${CurrencyFormatter.format(_selectedBill!.remainingAmount)}'),
                                  onPressed: () {
                                    setState(() {
                                      _amountCtrl.text = _selectedBill!.remainingAmount.toString();
                                    });
                                  },
                                ),
                                if (_selectedBill!.remainingAmount > 50000) ...[
                                  const SizedBox(width: 8),
                                  ActionChip(
                                    label: Text('Cicil 50%: ${CurrencyFormatter.format((_selectedBill!.remainingAmount / 2).round())}'),
                                    onPressed: () {
                                      setState(() {
                                        _amountCtrl.text = (_selectedBill!.remainingAmount ~/ 2).toString();
                                      });
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ],
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _amountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Jumlah yang Dibayarkan (Rp) *',
                              prefixText: 'Rp ',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          const Text('Metode Pembayaran', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _methods.map((m) {
                              final isSelected = _paymentMethod == m;
                              return ChoiceChip(
                                label: Text(m),
                                selected: isSelected,
                                selectedColor: AppTheme.navyPrimary,
                                labelStyle: TextStyle(
                                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                ),
                                onSelected: (sel) {
                                  if (sel) setState(() => _paymentMethod = m);
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 14),
                          TextFormField(
                            controller: _notesCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Catatan Transaksi (opsional)',
                              prefixIcon: Icon(Icons.note_alt_outlined),
                            ),
                          ),
                          if (_selectedBill != null) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppTheme.borderLight),
                              ),
                              child: Column(
                                children: [
                                  _infoRow('Total Tagihan', CurrencyFormatter.format(_selectedBill!.amount)),
                                  _infoRow('Sudah Dibayar Sebelumnya', CurrencyFormatter.format(_selectedBill!.paidAmount)),
                                  const Divider(height: 16),
                                  _infoRow('Sisa Tagihan Sekarang', CurrencyFormatter.format(_selectedBill!.remainingAmount), bold: true),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: (_isLoading || _selectedBill == null) ? null : _record,
                    icon: _isLoading
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.receipt_long),
                    label: const Text('Simpan Pembayaran & Buat Kuitansi', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: AppTheme.toskaAccent,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(fontWeight: bold ? FontWeight.bold : FontWeight.normal, fontSize: bold ? 15 : 13)),
        ],
      ),
    );
  }
}
