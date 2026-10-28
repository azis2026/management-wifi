import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/customer_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/package_repository.dart';
import '../../models/package_model.dart';
import '../../models/payment_model.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/billing_calculator.dart';

class CustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer; // null = tambah baru

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _customerCodeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  // Biaya Pemasangan & Tagihan Pertama
  final _installFeeCtrl = TextEditingController(text: '0');
  final _additionalFeeCtrl = TextEditingController(text: '0');
  final _discountCtrl = TextEditingController(text: '0');
  final _prorataDaysCtrl = TextEditingController(text: '30');
  final _customFirstBillCtrl = TextEditingController();
  final _paidAmountCtrl = TextEditingController(text: '0');

  final CustomerRepository _customerRepo = CustomerRepository();
  final PackageRepository _packageRepo = PackageRepository();

  List<PackageModel> _packages = [];
  PackageModel? _selectedPackage;
  int _dueDay = 10;
  DateTime _installDate = DateTime.now();
  DateTime _startDate = DateTime.now();
  DateTime _firstBillDueDate = DateTime.now().add(const Duration(days: 10));
  String? _ktpImagePath;

  bool _isProrata = false;
  bool _isManualCustomFirstBill = false;
  String _paymentOption = 'unpaid'; // 'unpaid', 'paid', 'partial'
  String _paymentMethod = PaymentMethod.cash;

  bool _isLoading = false;

  bool get isEditing => widget.customer != null;

  @override
  void initState() {
    super.initState();
    _loadPackages();

    if (isEditing) {
      final c = widget.customer!;
      _customerCodeCtrl.text = c.customerCode;
      _nameCtrl.text = c.name;
      _phoneCtrl.text = c.phone;
      _addressCtrl.text = c.address;
      _notesCtrl.text = c.notes;
      _dueDay = c.dueDay;
      _installDate = DateFormatter.parseDate(c.installDate);
      _startDate = DateFormatter.parseDate(c.startDate);
      _ktpImagePath = c.ktpImagePath;
      _installFeeCtrl.text = c.installationFee.toString();
    }

    _installFeeCtrl.addListener(_onBillCalculationChanged);
    _additionalFeeCtrl.addListener(_onBillCalculationChanged);
    _discountCtrl.addListener(_onBillCalculationChanged);
    _prorataDaysCtrl.addListener(_onBillCalculationChanged);
  }

  @override
  void dispose() {
    _customerCodeCtrl.dispose();
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _installFeeCtrl.dispose();
    _additionalFeeCtrl.dispose();
    _discountCtrl.dispose();
    _prorataDaysCtrl.dispose();
    _customFirstBillCtrl.dispose();
    _paidAmountCtrl.dispose();
    super.dispose();
  }

  void _onBillCalculationChanged() {
    if (mounted && !_isManualCustomFirstBill) {
      setState(() {});
    }
  }

  Future<void> _pickKtpImage() async {
    try {
      final files = await FilePicker.pickFiles(type: FileType.image);
      if (files.isNotEmpty && files.first.path != null) {
        setState(() => _ktpImagePath = files.first.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal memilih foto KTP: $e')),
        );
      }
    }
  }

  Future<void> _loadPackages() async {
    final pkgs = await _packageRepo.getPackages(activeOnly: true);
    setState(() {
      _packages = pkgs;
      if (isEditing) {
        _selectedPackage = pkgs.firstWhere(
          (p) => p.id == widget.customer!.packageId,
          orElse: () => pkgs.isNotEmpty ? pkgs.first : pkgs.first,
        );
      } else if (pkgs.isNotEmpty) {
        _selectedPackage = pkgs.first;
      }
    });
  }

  Future<void> _pickInstallDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _installDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _installDate = picked;
        if (!isEditing) {
          _startDate = picked;
          _firstBillDueDate = picked.add(const Duration(days: 10));
        }
      });
    }
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() {
        _startDate = picked;
        _firstBillDueDate = picked.add(const Duration(days: 10));
      });
    }
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstBillDueDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _firstBillDueDate = picked);
  }

  int get _installFee => int.tryParse(_installFeeCtrl.text.replaceAll('.', '').trim()) ?? 0;
  int get _additionalFee => int.tryParse(_additionalFeeCtrl.text.replaceAll('.', '').trim()) ?? 0;
  int get _discount => int.tryParse(_discountCtrl.text.replaceAll('.', '').trim()) ?? 0;
  int get _prorataDays => int.tryParse(_prorataDaysCtrl.text.trim()) ?? 30;

  int get _firstSubscriptionFee {
    if (_selectedPackage == null) return 0;
    if (_isProrata) {
      if (_selectedPackage!.hasCustomDailyPrice) {
        return (_selectedPackage!.dailyPrice * _prorataDays).round();
      }
      return BillingCalculator.calculatePeriodFee(_selectedPackage!.monthlyPrice, _prorataDays);
    }
    return _selectedPackage!.monthlyPrice;
  }

  int get _calculatedFirstBillTotal {
    if (_isManualCustomFirstBill) {
      final manual = int.tryParse(_customFirstBillCtrl.text.replaceAll('.', '').trim());
      if (manual != null) return manual;
    }
    return BillingCalculator.calculateFirstBillTotal(
      installationFee: _installFee,
      subscriptionFee: _firstSubscriptionFee,
      additionalFee: _additionalFee,
      discount: _discount,
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedPackage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih paket internet terlebih dahulu')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      if (isEditing) {
        final existing = widget.customer!;
        final updated = existing.copyWith(
          customerCode: _customerCodeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          packageId: _selectedPackage!.id!,
          packageName: _selectedPackage!.name,
          packageSpeed: _selectedPackage!.speed,
          monthlyFee: _selectedPackage!.monthlyPrice,
          installDate: DateFormatter.toIsoDateOnly(_installDate),
          startDate: DateFormatter.toIsoDateOnly(_startDate),
          installationFee: _installFee,
          dueDay: _dueDay,
          notes: _notesCtrl.text.trim(),
          ktpImagePath: _ktpImagePath,
        );

        await _customerRepo.updateCustomer(updated);

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Data pelanggan berhasil diperbarui'),
              backgroundColor: AppTheme.statusSuccess,
            ),
          );
        }
      } else {
        // Pelanggan Baru dengan Tagihan Pertama
        final newCustomer = CustomerModel(
          customerCode: _customerCodeCtrl.text.trim(),
          name: _nameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim(),
          address: _addressCtrl.text.trim(),
          packageId: _selectedPackage!.id!,
          packageName: _selectedPackage!.name,
          packageSpeed: _selectedPackage!.speed,
          monthlyFee: _selectedPackage!.monthlyPrice,
          installDate: DateFormatter.toIsoDateOnly(_installDate),
          startDate: DateFormatter.toIsoDateOnly(_startDate),
          installationFee: _installFee,
          dueDay: _dueDay,
          notes: _notesCtrl.text.trim(),
          ktpImagePath: _ktpImagePath,
        );

        final firstBillTotal = _calculatedFirstBillTotal;
        final periodDays = _isProrata ? _prorataDays : 30;
        final periodEnd = _startDate.add(Duration(days: periodDays));

        int initialPaid = 0;
        if (_paymentOption == 'paid') {
          initialPaid = firstBillTotal;
        } else if (_paymentOption == 'partial') {
          initialPaid = int.tryParse(_paidAmountCtrl.text.replaceAll('.', '').trim()) ?? 0;
          if (initialPaid > firstBillTotal) {
            initialPaid = firstBillTotal;
          }
        }

        await _customerRepo.createCustomerWithFirstBill(
          customer: newCustomer,
          firstBillTotal: firstBillTotal,
          installationFee: _installFee,
          subscriptionFee: _firstSubscriptionFee,
          additionalFee: _additionalFee,
          discount: _discount,
          periodStart: _startDate,
          periodEnd: periodEnd,
          dueDate: _firstBillDueDate,
          initialPaidAmount: initialPaid,
          paymentMethod: _paymentMethod,
          adminNotes: _notesCtrl.text.trim(),
        );

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Pelanggan baru & tagihan pertama berhasil disimpan'),
              backgroundColor: AppTheme.statusSuccess,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dailyFee = _selectedPackage != null
        ? _selectedPackage!.dailyPrice
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(isEditing ? 'Ubah Data Pelanggan' : 'Pendaftaran Pelanggan Baru'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _save,
            child: const Text('SIMPAN', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _packages.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // 1. Data Diri Pelanggan
                  _section('1. Informasi Pelanggan', [
                    TextFormField(
                      controller: _customerCodeCtrl,
                      decoration: const InputDecoration(
                        labelText: 'ID / Kode Pelanggan (Otomatis / Kustom)',
                        hintText: 'Biarkan kosong untuk otomatis (CUST-xxxx)',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nama Lengkap Pelanggan *',
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Nama wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _phoneCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nomor Telepon / WhatsApp *',
                        prefixIcon: Icon(Icons.phone),
                        hintText: '0812-xxxx-xxxx',
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'No. Telepon wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Alamat Pemasangan *',
                        prefixIcon: Icon(Icons.location_on),
                      ),
                      maxLines: 2,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Alamat wajib diisi' : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _notesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Catatan Admin (opsional)',
                        prefixIcon: Icon(Icons.note_alt_outlined),
                      ),
                    ),
                  ]),

                  const SizedBox(height: 16),

                  // 2. Paket Internet Master
                  _section('2. Master Paket Internet', [
                    DropdownButtonFormField<PackageModel>(
                      value: _selectedPackage,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Pilih Paket Internet *',
                        prefixIcon: Icon(Icons.wifi),
                      ),
                      items: _packages.map((pkg) {
                        return DropdownMenuItem(
                          value: pkg,
                          child: Text(
                            '${pkg.name} - ${pkg.speed} (${CurrencyFormatter.format(pkg.monthlyPrice)}/bln)',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        );
                      }).toList(),
                      onChanged: (pkg) {
                        setState(() {
                          _selectedPackage = pkg;
                          if (_isManualCustomFirstBill) {
                            _customFirstBillCtrl.text = _calculatedFirstBillTotal.toString();
                          }
                        });
                      },
                      validator: (v) => v == null ? 'Pilih paket internet' : null,
                    ),
                    if (_selectedPackage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBFDBFE)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: AppTheme.navyPrimary, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Kecepatan: ${_selectedPackage!.speed} | Harga: ${CurrencyFormatter.format(_selectedPackage!.monthlyPrice)} / 30 Hari',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.navyPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedPackage!.hasCustomDailyPrice
                                        ? 'Biaya per hari: ${CurrencyFormatter.format(dailyFee.round())} / hari (Tarif Kustom Master Paket)'
                                        : 'Biaya per hari: ${CurrencyFormatter.format(dailyFee.round())} / hari (dasar: tarif bulanan ÷ 30)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: _selectedPackage!.hasCustomDailyPrice ? FontWeight.w600 : FontWeight.normal,
                                      color: _selectedPackage!.hasCustomDailyPrice ? const Color(0xFF0369A1) : Colors.blue.shade900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _pickInstallDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Tanggal Pasang',
                                prefixIcon: Icon(Icons.build_circle_outlined),
                              ),
                              child: Text(DateFormatter.formatDate(_installDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: InkWell(
                            onTap: _pickStartDate,
                            borderRadius: BorderRadius.circular(8),
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Mulai Berlangganan',
                                prefixIcon: Icon(Icons.play_circle_outline),
                              ),
                              child: Text(DateFormatter.formatDate(_startDate)),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InputDecorator(
                      decoration: const InputDecoration(
                        labelText: 'Siklus Jatuh Tempo Bulanan',
                        prefixIcon: Icon(Icons.event_repeat),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _dueDay,
                          isDense: true,
                          items: List.generate(28, (i) => i + 1).map((d) {
                            return DropdownMenuItem(value: d, child: Text('Tiap tanggal $d setiap bulan'));
                          }).toList(),
                          onChanged: (v) => setState(() => _dueDay = v!),
                        ),
                      ),
                    ),
                  ]),

                  // Jika mode tambah pelanggan baru, tampilkan konfigurasi Biaya Pemasangan & Tagihan Pertama
                  if (!isEditing) ...[
                    const SizedBox(height: 16),
                    _section('3. Biaya Pemasangan Awal & Tagihan Pertama', [
                      TextFormField(
                        controller: _installFeeCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Biaya Pemasangan Awal (Custom / Kesepakatan) *',
                          prefixText: 'Rp ',
                          prefixIcon: Icon(Icons.handyman_outlined),
                          helperText: 'Biaya ini HANYA dibebankan pada tagihan pertama, tidak ikut di tagihan berikutnya',
                        ),
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _additionalFeeCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Biaya Tambahan',
                                prefixText: 'Rp ',
                                prefixIcon: Icon(Icons.add_circle_outline),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextFormField(
                              controller: _discountCtrl,
                              decoration: const InputDecoration(
                                labelText: 'Diskon',
                                prefixText: 'Rp ',
                                prefixIcon: Icon(Icons.remove_circle_outline),
                              ),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Pilihan Prorata
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Hitung Prorata Hari untuk Langganan Pertama', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                        subtitle: Text(
                          _isProrata
                              ? 'Biaya langganan dihitung berdasarkan $_prorataDays hari penggunaan'
                              : 'Biaya langganan dihitung 1 bulan penuh standar (30 hari)',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _isProrata,
                        onChanged: (v) {
                          setState(() {
                            _isProrata = v;
                          });
                        },
                      ),
                      if (_isProrata) ...[
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _prorataDaysCtrl,
                          decoration: InputDecoration(
                            labelText: 'Jumlah Hari Ditagihkan',
                            suffixText: 'Hari',
                            prefixIcon: const Icon(Icons.calendar_view_day),
                            helperText: 'Biaya: ${CurrencyFormatter.format(dailyFee.round())} × $_prorataDays hari = ${CurrencyFormatter.format(_firstSubscriptionFee)}',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Mode Manual Custom First Bill Total
                      CheckboxListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Input Manual Nominal Tagihan Pertama', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        subtitle: const Text('Gunakan jika nominal tagihan pertama telah disepakati khusus dengan pelanggan', style: TextStyle(fontSize: 11)),
                        value: _isManualCustomFirstBill,
                        onChanged: (v) {
                          setState(() {
                            _isManualCustomFirstBill = v ?? false;
                            if (_isManualCustomFirstBill) {
                              _customFirstBillCtrl.text = _calculatedFirstBillTotal.toString();
                            }
                          });
                        },
                      ),
                      if (_isManualCustomFirstBill) ...[
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: _customFirstBillCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Nominal Total Tagihan Pertama Disepakati *',
                            prefixText: 'Rp ',
                            prefixIcon: Icon(Icons.edit_note),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setState(() {}),
                        ),
                      ],
                      const SizedBox(height: 16),
                      // Rincian Tagihan Pertama
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Rincian Tagihan Pertama:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            const SizedBox(height: 8),
                            _rowDetail('Biaya Pemasangan Awal', CurrencyFormatter.format(_installFee)),
                            _rowDetail('Biaya Langganan Pertama', CurrencyFormatter.format(_firstSubscriptionFee)),
                            if (_additionalFee > 0)
                              _rowDetail('Biaya Tambahan', '+ ${CurrencyFormatter.format(_additionalFee)}'),
                            if (_discount > 0)
                              _rowDetail('Diskon', '- ${CurrencyFormatter.format(_discount)}', isNegative: true),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('TOTAL TAGIHAN PERTAMA', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                Text(
                                  CurrencyFormatter.format(_calculatedFirstBillTotal),
                                  style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: AppTheme.navyPrimary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Tanggal Jatuh Tempo Tagihan Pertama
                      InkWell(
                        onTap: _pickDueDate,
                        borderRadius: BorderRadius.circular(8),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Tanggal Jatuh Tempo Tagihan Pertama',
                            prefixIcon: Icon(Icons.timer_outlined),
                          ),
                          child: Text(DateFormatter.formatDate(_firstBillDueDate)),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Opsi Pembayaran Tagihan Pertama
                      const Text('Status Pembayaran Tagihan Pertama:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        value: _paymentOption,
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.payment),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'unpaid', child: Text('Belum Bayar (Terbitkan Tagihan)')),
                          DropdownMenuItem(value: 'paid', child: Text('Langsung Bayar Lunas Sekarang')),
                          DropdownMenuItem(value: 'partial', child: Text('Bayar Sebagian (DP / Cicilan Awal)')),
                        ],
                        onChanged: (v) => setState(() => _paymentOption = v!),
                      ),
                      if (_paymentOption != 'unpaid') ...[
                        const SizedBox(height: 12),
                        if (_paymentOption == 'partial') ...[
                          TextFormField(
                            controller: _paidAmountCtrl,
                            decoration: const InputDecoration(
                              labelText: 'Nominal Pembayaran Diterima *',
                              prefixText: 'Rp ',
                              prefixIcon: Icon(Icons.attach_money),
                            ),
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 12),
                        ],
                        DropdownButtonFormField<String>(
                          value: _paymentMethod,
                          decoration: const InputDecoration(
                            labelText: 'Metode Pembayaran',
                            prefixIcon: Icon(Icons.account_balance_wallet_outlined),
                          ),
                          items: PaymentMethod.all.map((m) {
                            return DropdownMenuItem(value: m, child: Text(m));
                          }).toList(),
                          onChanged: (v) => setState(() => _paymentMethod = v!),
                        ),
                      ],
                    ]),
                  ],

                  const SizedBox(height: 16),

                  // 4. Foto KTP
                  _section('4. Dokumen KTP (Opsional)', [
                    if (_ktpImagePath != null && _ktpImagePath!.isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: File(_ktpImagePath!).existsSync()
                            ? Image.file(
                                File(_ktpImagePath!),
                                height: 180,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 100,
                                color: Colors.grey.shade200,
                                alignment: Alignment.center,
                                child: Text('File foto KTP: $_ktpImagePath'),
                              ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _pickKtpImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Ganti Foto KTP'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            tooltip: 'Hapus Foto KTP',
                            onPressed: () => setState(() => _ktpImagePath = null),
                          ),
                        ],
                      ),
                    ] else ...[
                      InkWell(
                        onTap: _pickKtpImage,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade400),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade50,
                          ),
                          child: Column(
                            children: const [
                              Icon(Icons.add_a_photo, size: 36, color: AppTheme.navyPrimary),
                              SizedBox(height: 6),
                              Text('Pilih Foto KTP Pelanggan', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ]),

                  const SizedBox(height: 24),

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _save,
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.save),
                      label: Text(
                        isEditing ? 'Simpan Perubahan' : 'Konfirmasi & Tambah Pelanggan',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _rowDetail(String title, String value, {bool isNegative = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isNegative ? Colors.red : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title, List<Widget> children) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.borderLight),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary)),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
