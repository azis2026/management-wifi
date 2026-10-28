import 'package:flutter/material.dart';
import '../../models/package_model.dart';
import '../../repositories/package_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/billing_calculator.dart';

class PackageListScreen extends StatefulWidget {
  const PackageListScreen({super.key});

  @override
  State<PackageListScreen> createState() => _PackageListScreenState();
}

class _PackageListScreenState extends State<PackageListScreen> {
  final PackageRepository _repo = PackageRepository();
  List<PackageModel> _packages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final list = await _repo.getPackages();
    if (mounted) {
      setState(() {
        _packages = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleStatus(PackageModel pkg) async {
    await _repo.togglePackageStatus(pkg.id!, !pkg.isActive);
    _load();
  }

  Future<void> _confirmDelete(PackageModel pkg) async {
    final customerCount = await _repo.getCustomerCountByPackage(pkg.id!);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: const [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusDanger),
            SizedBox(width: 8),
            Text('Hapus Paket Internet', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Yakin ingin menghapus master paket "${pkg.name} - ${pkg.speed}"?'),
            if (customerCount > 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Perhatian: Ada $customerCount pelanggan yang saat ini terdaftar dengan paket ini. Jika dihapus, riwayat paket lama pelanggan tetap tersimpan.',
                        style: TextStyle(fontSize: 12, color: Colors.amber.shade900),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.statusDanger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus Paket'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      await _repo.deletePackage(pkg.id!);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Paket "${pkg.name}" berhasil dihapus'),
          backgroundColor: AppTheme.statusSuccess,
        ),
      );
      _load();
    }
  }

  void _showPackageFormModal({PackageModel? packageToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PackageFormModal(
        package: packageToEdit,
        onSaved: () {
          _load();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                packageToEdit == null
                    ? 'Master paket baru berhasil ditambahkan'
                    : 'Master paket berhasil diperbarui',
              ),
              backgroundColor: AppTheme.statusSuccess,
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeCount = _packages.where((p) => p.isActive).length;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Master Paket Internet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navyPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Paket', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _showPackageFormModal(),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 80),
                children: [
                  // Info Card Header
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.navyPrimary,
                          AppTheme.navyLight,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.navyPrimary.withOpacity(0.2),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.speed_rounded, color: Colors.white, size: 30),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Konfigurasi Master Paket',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Total: ${_packages.length} Paket ($activeCount Aktif) • Tarif harian kustom tersedia',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.85),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (_packages.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 20),
                      alignment: Alignment.center,
                      child: Column(
                        children: [
                          Icon(Icons.wifi_off_rounded, size: 64, color: Colors.grey.shade400),
                          const SizedBox(height: 16),
                          const Text(
                            'Belum Ada Paket Internet',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Klik tombol "Tambah Paket" di bawah untuk membuat master paket baru dengan nama dan tarif harian custom Anda sendiri.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.navyPrimary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: const Icon(Icons.add),
                            label: const Text('Buat Paket Sekarang'),
                            onPressed: () => _showPackageFormModal(),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._packages.map((p) {
                      final isHajatan = p.name.toLowerCase().contains('hajatan') ||
                          p.name.toLowerCase().contains('event');
                      final hasCustomDaily = p.hasCustomDailyPrice;
                      final dailyPrice = p.dailyPrice.round();

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isHajatan
                                ? AppTheme.amberWarning.withOpacity(0.5)
                                : (p.isActive ? AppTheme.borderLight : Colors.grey.shade300),
                            width: isHajatan ? 1.5 : 1,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Row: Icon, Title, Speed Badge, Switch
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: (isHajatan
                                              ? AppTheme.amberWarning
                                              : AppTheme.navyPrimary)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      isHajatan ? Icons.celebration_rounded : Icons.wifi_rounded,
                                      color: isHajatan
                                          ? AppTheme.amberWarning
                                          : AppTheme.navyPrimary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                p.name,
                                                style: TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                  color: p.isActive
                                                      ? AppTheme.textPrimary
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 3),
                                              decoration: BoxDecoration(
                                                color: isHajatan
                                                    ? AppTheme.amberWarning.withOpacity(0.15)
                                                    : AppTheme.navyPrimary.withOpacity(0.08),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                p.speed,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: isHajatan
                                                      ? AppTheme.amberWarning
                                                      : AppTheme.navyPrimary,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          p.isActive ? 'Status: Aktif' : 'Status: Nonaktif',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color: p.isActive
                                                ? AppTheme.statusSuccess
                                                : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Switch(
                                    value: p.isActive,
                                    activeColor: AppTheme.navyPrimary,
                                    onChanged: (_) => _toggleStatus(p),
                                  ),
                                ],
                              ),

                              const Divider(height: 20),

                              // Price Details
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    CurrencyFormatter.format(p.monthlyPrice),
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: p.isActive ? AppTheme.navyPrimary : Colors.grey,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '/ 30 Hari',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),

                              // Daily Fee Badge (Highlighting Custom vs Auto)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: hasCustomDaily
                                      ? const Color(0xFFF0FDF4)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: hasCustomDaily
                                        ? const Color(0xFF86EFAC)
                                        : Colors.grey.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      hasCustomDaily
                                          ? Icons.tune_rounded
                                          : Icons.calculate_outlined,
                                      size: 16,
                                      color: hasCustomDaily
                                          ? const Color(0xFF15803D)
                                          : const Color(0xFF0284C7),
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: RichText(
                                        text: TextSpan(
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textPrimary,
                                          ),
                                          children: [
                                            const TextSpan(text: 'Biaya Harian: '),
                                            TextSpan(
                                              text: '${CurrencyFormatter.format(dailyPrice)} / hari ',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: hasCustomDaily
                                                    ? const Color(0xFF15803D)
                                                    : const Color(0xFF0284C7),
                                              ),
                                            ),
                                            TextSpan(
                                              text: hasCustomDaily
                                                  ? '(Kustom Sendiri)'
                                                  : '(Otomatis: Bulanan ÷ 30)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontStyle: FontStyle.italic,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              if (p.installationFee > 0) ...[
                                const SizedBox(height: 6),
                                Text(
                                  'Biaya Pasang / Registrasi: ${CurrencyFormatter.format(p.installationFee)}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey.shade700,
                                  ),
                                ),
                              ],

                              const SizedBox(height: 12),

                              // Action Buttons (Ubah & Hapus)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.navyPrimary,
                                      side: const BorderSide(color: AppTheme.navyPrimary),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 14, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: const Text('Ubah'),
                                    onPressed: () =>
                                        _showPackageFormModal(packageToEdit: p),
                                  ),
                                  const SizedBox(width: 8),
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: AppTheme.statusDanger,
                                      side: BorderSide(color: Colors.red.shade200),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 12, vertical: 8),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: const Text('Hapus'),
                                    onPressed: () => _confirmDelete(p),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

/// Modal Form Tambah / Edit Master Paket dengan Fitur Custom Biaya Harian
class _PackageFormModal extends StatefulWidget {
  final PackageModel? package;
  final VoidCallback onSaved;

  const _PackageFormModal({
    this.package,
    required this.onSaved,
  });

  @override
  State<_PackageFormModal> createState() => _PackageFormModalState();
}

class _PackageFormModalState extends State<_PackageFormModal> {
  final _formKey = GlobalKey<FormState>();
  final PackageRepository _repo = PackageRepository();

  late TextEditingController _nameCtrl;
  late TextEditingController _speedCtrl;
  late TextEditingController _monthlyPriceCtrl;
  late TextEditingController _customDailyPriceCtrl;
  late TextEditingController _installFeeCtrl;

  bool _isCustomDailyPrice = false;
  bool _isActive = true;
  bool _isSaving = false;

  final List<String> _quickSpeeds = [
    '6 Mbps',
    '10 Mbps',
    '15 Mbps',
    '20 Mbps',
    '30 Mbps',
    '50 Mbps',
    '100 Mbps',
  ];

  @override
  void initState() {
    super.initState();
    final p = widget.package;

    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _speedCtrl = TextEditingController(text: p?.speed ?? '');
    _monthlyPriceCtrl = TextEditingController(
      text: p != null ? p.monthlyPrice.toString() : '',
    );
    _isCustomDailyPrice = p?.hasCustomDailyPrice ?? false;
    _customDailyPriceCtrl = TextEditingController(
      text: p?.customDailyPrice != null && p!.customDailyPrice! > 0
          ? p.customDailyPrice.toString()
          : '',
    );
    _installFeeCtrl = TextEditingController(
      text: p != null && p.installationFee > 0 ? p.installationFee.toString() : '0',
    );
    _isActive = p?.isActive ?? true;

    // Listener harga bulanan untuk auto update saran daily fee
    _monthlyPriceCtrl.addListener(() {
      if (!_isCustomDailyPrice) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose;
    _speedCtrl.dispose;
    _monthlyPriceCtrl.dispose;
    _customDailyPriceCtrl.dispose;
    _installFeeCtrl.dispose;
    super.dispose();
  }

  int get _parsedMonthlyPrice =>
      int.tryParse(_monthlyPriceCtrl.text.replaceAll('.', '').trim()) ?? 0;

  int get _autoCalculatedDailyFee =>
      BillingCalculator.calculateDailyFee(_parsedMonthlyPrice).round();

  void _fillAutoDailyFee() {
    _customDailyPriceCtrl.text = _autoCalculatedDailyFee.toString();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final name = _nameCtrl.text.trim();
    final speed = _speedCtrl.text.trim();
    final monthlyPrice = _parsedMonthlyPrice;
    final installFee =
        int.tryParse(_installFeeCtrl.text.replaceAll('.', '').trim()) ?? 0;

    int? customDaily;
    if (_isCustomDailyPrice) {
      customDaily = int.tryParse(
          _customDailyPriceCtrl.text.replaceAll('.', '').trim());
    }

    setState(() => _isSaving = true);
    try {
      if (widget.package == null) {
        // Create new
        final newPkg = PackageModel(
          name: name,
          speed: speed,
          monthlyPrice: monthlyPrice,
          customDailyPrice: customDaily,
          installationFee: installFee,
          isActive: _isActive,
        );
        await _repo.createPackage(newPkg);
      } else {
        // Update existing
        final updatedPkg = widget.package!.copyWith(
          name: name,
          speed: speed,
          monthlyPrice: monthlyPrice,
          customDailyPrice: customDaily,
          clearCustomDailyPrice: !_isCustomDailyPrice,
          installationFee: installFee,
          isActive: _isActive,
        );
        await _repo.updatePackage(updatedPkg);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan paket: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.package != null;
    final viewInsets = MediaQuery.of(context).viewInsets;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(20, 20, 20, viewInsets.bottom + 20),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Modal
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.navyPrimary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isEditing ? Icons.edit_note_rounded : Icons.add_circle_outline_rounded,
                      color: AppTheme.navyPrimary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    isEditing ? 'Ubah Master Paket' : 'Tambah Master Paket WiFi',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // 1. Nama Paket
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nama Paket Internet *',
                  hintText: 'Contoh: Paket Rumahan, Paket WFH, Paket Hajatan',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nama paket wajib diisi' : null,
              ),

              const SizedBox(height: 14),

              // 2. Kecepatan / Speed
              TextFormField(
                controller: _speedCtrl,
                decoration: const InputDecoration(
                  labelText: 'Kecepatan / Speed *',
                  hintText: 'Contoh: 20 Mbps, 50 Mbps',
                  prefixIcon: Icon(Icons.speed_rounded),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Kecepatan wajib diisi' : null,
              ),

              const SizedBox(height: 8),

              // Quick Speed Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _quickSpeeds.map((s) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(s, style: const TextStyle(fontSize: 11)),
                        backgroundColor: Colors.grey.shade100,
                        onPressed: () {
                          setState(() {
                            _speedCtrl.text = s;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 14),

              // 3. Harga Bulanan (Rp)
              TextFormField(
                controller: _monthlyPriceCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Tarif Bulanan (Rp) *',
                  hintText: 'Contoh: 150000',
                  prefixIcon: Icon(Icons.payments_outlined),
                  prefixText: 'Rp ',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Tarif bulanan wajib diisi';
                  final val = int.tryParse(v.replaceAll('.', '').trim());
                  if (val == null || val <= 0) return 'Masukkan nominal harga yang valid';
                  return null;
                },
              ),

              const SizedBox(height: 16),

              // 4. Kustom Biaya Harian (Fitur Utama yang diminta pengguna)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isCustomDailyPrice
                      ? const Color(0xFFF0FDF4)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _isCustomDailyPrice
                        ? const Color(0xFF86EFAC)
                        : Colors.grey.shade300,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isCustomDailyPrice
                              ? Icons.tune_rounded
                              : Icons.calculate_outlined,
                          color: _isCustomDailyPrice
                              ? const Color(0xFF15803D)
                              : AppTheme.navyPrimary,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Kustom Biaya per Hari',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Switch(
                          value: _isCustomDailyPrice,
                          activeColor: const Color(0xFF16A34A),
                          onChanged: (val) {
                            setState(() {
                              _isCustomDailyPrice = val;
                              if (val && _customDailyPriceCtrl.text.isEmpty) {
                                _fillAutoDailyFee();
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _isCustomDailyPrice
                          ? 'Aktif: Anda dapat menentukan sendiri nominal tarif harian untuk paket ini.'
                          : 'Nonaktif: Biaya harian dihitung otomatis dari tarif bulanan ÷ 30 hari (${CurrencyFormatter.format(_autoCalculatedDailyFee)} / hari).',
                      style: TextStyle(
                        fontSize: 12,
                        color: _isCustomDailyPrice
                            ? const Color(0xFF166534)
                            : Colors.grey.shade700,
                      ),
                    ),

                    if (_isCustomDailyPrice) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _customDailyPriceCtrl,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Biaya Harian Kustom (Rp/Hari) *',
                          hintText: 'Contoh: 5000',
                          prefixIcon: const Icon(Icons.attach_money_rounded),
                          prefixText: 'Rp ',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.sync_rounded),
                            tooltip: 'Gunakan hitungan standar (Bulanan ÷ 30)',
                            onPressed: _fillAutoDailyFee,
                          ),
                        ),
                        validator: (v) {
                          if (!_isCustomDailyPrice) return null;
                          if (v == null || v.trim().isEmpty) {
                            return 'Tentukan biaya harian kustom';
                          }
                          final val = int.tryParse(v.replaceAll('.', '').trim());
                          if (val == null || val <= 0) {
                            return 'Masukkan nominal biaya harian yang valid';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Tip: Biaya harian kustom ini akan menjadi dasar perhitungan tagihan prorata hari bagi pelanggan.',
                        style: TextStyle(fontSize: 11, color: Colors.green.shade800),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // 5. Biaya Instalasi / Pemasangan
              TextFormField(
                controller: _installFeeCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Biaya Pasang / Registrasi Awal (Rp)',
                  hintText: 'Isi 0 jika gratis pemasangan',
                  prefixIcon: Icon(Icons.build_outlined),
                  prefixText: 'Rp ',
                ),
              ),

              const SizedBox(height: 10),

              // 6. Switch Status Aktif
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Paket Aktif',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Paket yang aktif akan muncul di daftar pilihan saat pendaftaran pelanggan baru.',
                  style: TextStyle(fontSize: 12),
                ),
                value: _isActive,
                activeColor: AppTheme.navyPrimary,
                onChanged: (v) => setState(() => _isActive = v),
              ),

              const SizedBox(height: 20),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      icon: _isSaving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: Text(
                        _isSaving ? 'Menyimpan...' : (isEditing ? 'Simpan Perubahan' : 'Tambah Paket'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: _isSaving ? null : _save,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
