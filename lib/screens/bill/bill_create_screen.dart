import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../repositories/bill_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';

class BillCreateScreen extends StatefulWidget {
  final CustomerModel? preselectedCustomer;

  const BillCreateScreen({super.key, this.preselectedCustomer});

  @override
  State<BillCreateScreen> createState() => _BillCreateScreenState();
}

class _BillCreateScreenState extends State<BillCreateScreen> {
  final _billRepo = BillRepository();
  final _customerRepo = CustomerRepository();
  final _notesCtrl = TextEditingController();

  List<CustomerModel> _customers = [];
  CustomerModel? _selectedCustomer;
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 10));
  bool _isLoading = false;
  bool _isBulkMode = false;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    if (widget.preselectedCustomer != null) {
      _selectedCustomer = widget.preselectedCustomer;
      _setDueDateFromCustomer();
    }
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCustomers() async {
    final list = await _customerRepo.getCustomers(activeOnly: true);
    setState(() {
      _customers = list;
      if (_selectedCustomer == null && list.isNotEmpty) {
        _selectedCustomer = list.first;
        _setDueDateFromCustomer();
      }
    });
  }

  void _setDueDateFromCustomer() {
    if (_selectedCustomer == null) return;
    final safeDay = _selectedCustomer!.dueDay.clamp(1, 28);
    setState(() {
      _dueDate = DateTime(_selectedYear, _selectedMonth, safeDay);
    });
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate,
      firstDate: DateTime(_selectedYear, _selectedMonth, 1),
      lastDate: DateTime(_selectedYear + 1, 12, 31),
    );
    if (picked != null) setState(() => _dueDate = picked);
  }

  Future<void> _createBill() async {
    if (_selectedCustomer == null) return;
    setState(() => _isLoading = true);
    try {
      if (_isBulkMode) {
        final result = await _billRepo.batchCreateMonthlyBills(
          month: _selectedMonth,
          year: _selectedYear,
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Tagihan dibuat: ${result['created']}, dilewati: ${result['skipped']}'),
            backgroundColor: AppTheme.statusSuccess,
          ));
        }
      } else {
        final periodStart = DateTime(_selectedYear, _selectedMonth, _selectedCustomer!.dueDay.clamp(1, 28));
        final periodEnd = periodStart.add(const Duration(days: 30));

        await _billRepo.createBill(
          customer: _selectedCustomer!,
          month: _selectedMonth,
          year: _selectedYear,
          dueDate: _dueDate,
          periodStart: periodStart,
          periodEnd: periodEnd,
          subscriptionFee: _selectedCustomer!.monthlyFee,
          installationFee: 0,
          notes: _notesCtrl.text.trim(),
        );
        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Tagihan berhasil dibuat'),
            backgroundColor: AppTheme.statusSuccess,
          ));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('$e'),
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
      appBar: AppBar(title: const Text('Buat Tagihan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Mode toggle
          Card(
            child: SwitchListTile(
              title: const Text('Buat Tagihan Massal', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Buat tagihan untuk semua pelanggan aktif sekaligus'),
              value: _isBulkMode,
              onChanged: (v) => setState(() => _isBulkMode = v),
              secondary: Icon(_isBulkMode ? Icons.group : Icons.person, color: AppTheme.navyPrimary),
            ),
          ),
          const SizedBox(height: 12),
          // Period selection
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Periode Tagihan', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyPrimary)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedMonth,
                          decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                          items: List.generate(12, (i) => i + 1).map((m) => DropdownMenuItem(
                            value: m,
                            child: Text(DateFormatter.monthName(m)),
                          )).toList(),
                          onChanged: (v) {
                            setState(() => _selectedMonth = v!);
                            _setDueDateFromCustomer();
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: _selectedYear,
                          decoration: const InputDecoration(labelText: 'Tahun', border: OutlineInputBorder()),
                          items: List.generate(3, (i) => DateTime.now().year - 1 + i).map((y) => DropdownMenuItem(
                            value: y, child: Text('$y'),
                          )).toList(),
                          onChanged: (v) {
                            setState(() => _selectedYear = v!);
                            _setDueDateFromCustomer();
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (!_isBulkMode) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Detail Tagihan', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.navyPrimary)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<CustomerModel>(
                      value: _selectedCustomer,
                      decoration: const InputDecoration(labelText: 'Pelanggan *', border: OutlineInputBorder()),
                      items: _customers.map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.name} — ${CurrencyFormatter.format(c.monthlyFee)}'),
                      )).toList(),
                      onChanged: (c) {
                        setState(() => _selectedCustomer = c);
                        _setDueDateFromCustomer();
                      },
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _pickDueDate,
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'Tanggal Jatuh Tempo', border: OutlineInputBorder()),
                        child: Text(DateFormatter.formatDate(_dueDate)),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(labelText: 'Catatan (opsional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
            ),
            if (_selectedCustomer != null) ...[
              const SizedBox(height: 12),
              Card(
                color: AppTheme.navyPrimary.withOpacity(0.06),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Jumlah Tagihan:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        CurrencyFormatter.format(_selectedCustomer!.monthlyFee),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isLoading ? null : _createBill,
              icon: _isLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Icon(_isBulkMode ? Icons.receipt_long : Icons.add_card),
              label: Text(_isBulkMode ? 'Buat Tagihan Massal' : 'Buat Tagihan'),
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
          ),
        ],
      ),
    );
  }
}
