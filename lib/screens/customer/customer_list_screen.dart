import 'package:flutter/material.dart';
import '../../models/customer_model.dart';
import '../../models/package_model.dart';
import '../../models/business_profile_model.dart';
import '../../repositories/customer_repository.dart';
import '../../repositories/package_repository.dart';
import '../../repositories/settings_repository.dart';
import '../../utils/app_theme.dart';
import '../../utils/currency_formatter.dart';
import '../../utils/date_formatter.dart';
import '../../utils/billing_calculator.dart';
import '../../utils/excel_exporter.dart';
import '../../utils/whatsapp_reminder_service.dart';
import 'customer_detail_screen.dart';
import 'customer_form_screen.dart';

class CustomerListScreen extends StatefulWidget {
  const CustomerListScreen({super.key});

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  final CustomerRepository _repo = CustomerRepository();
  final PackageRepository _packageRepo = PackageRepository();
  final SettingsRepository _settingsRepo = SettingsRepository();
  final TextEditingController _searchCtrl = TextEditingController();

  List<CustomerModel> _customers = [];
  List<PackageModel> _packages = [];
  BusinessProfileModel? _businessProfile;

  bool _isLoading = true;
  String _searchType = 'all'; // 'all', 'id', 'name'
  String _searchQuery = '';

  // Filters
  int? _selectedPackageId;
  String _statusActiveFilter = 'all'; // 'all', 'active', 'inactive'
  String _paymentStatusFilter = 'Semua'; // 'Semua', 'Lunas', 'Menunggak', 'Terlambat'

  @override
  void initState() {
    super.initState();
    _loadPackages();
    _load();
    _searchCtrl.addListener(() {
      if (_searchQuery != _searchCtrl.text) {
        setState(() => _searchQuery = _searchCtrl.text);
        _load();
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPackages() async {
    final pkgs = await _packageRepo.getPackages();
    if (mounted) setState(() => _packages = pkgs);
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final profile = await _settingsRepo.getBusinessProfile();

    bool? activeOnly;
    if (_statusActiveFilter == 'active') activeOnly = true;
    if (_statusActiveFilter == 'inactive') activeOnly = false;

    final list = await _repo.getCustomers(
      activeOnly: activeOnly,
      searchQuery: _searchQuery.isEmpty ? null : _searchQuery,
      searchType: _searchType,
      packageId: _selectedPackageId,
      paymentStatusFilter: _paymentStatusFilter,
    );

    if (mounted) {
      setState(() {
        _businessProfile = profile;
        _customers = list;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Pelanggan'),
        content: Text(
          'Yakin ingin menghapus pelanggan "${customer.name}" (${customer.customerCode})?\n\n'
          '⚠️ Seluruh riwayat tagihan dan pembayarannya juga akan dihapus permanen!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Hapus'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _repo.deleteCustomer(customer.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Pelanggan "${customer.name}" berhasil dihapus'),
              backgroundColor: AppTheme.statusDanger,
            ),
          );
          _load();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Gagal menghapus: $e'),
              backgroundColor: AppTheme.statusDanger,
            ),
          );
        }
      }
    }
  }

  Future<void> _editCustomer(CustomerModel customer) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerFormScreen(customer: customer),
      ),
    );
    if (res == true) _load();
  }

  Future<void> _showExcelExportDialog() async {
    final bool hasFilter = _searchQuery.isNotEmpty ||
        _selectedPackageId != null ||
        _statusActiveFilter != 'all' ||
        _paymentStatusFilter != 'Semua';

    showModalBottomSheet(
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
                Icon(Icons.table_view_rounded, color: Color(0xFF107C41), size: 28), // Excel Green
                SizedBox(width: 10),
                Text('Export ke Excel (.xlsx)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Ekspor 24 kolom lengkap data pelanggan, rincian biaya harian, paket, tagihan, dan status pembayaran ke file spreadsheet Microsoft Excel asli.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            if (hasFilter) ...[
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: AppTheme.borderLight),
                ),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFE6F4EA),
                  child: Icon(Icons.filter_list, color: Color(0xFF137333)),
                ),
                title: Text('Ekspor Data Hasil Filter (${_customers.length} Pelanggan)'),
                subtitle: const Text('Hanya mengekspor pelanggan yang sesuai filter pencarian saat ini'),
                onTap: () {
                  Navigator.pop(ctx);
                  ExcelExporter.exportAndShareCustomers(
                    context: context,
                    customers: _customers,
                    isFiltered: true,
                  );
                },
              ),
              const SizedBox(height: 10),
            ],
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFEFF6FF),
                child: Icon(Icons.all_inclusive, color: AppTheme.navyPrimary),
              ),
              title: const Text('Ekspor Seluruh Data Pelanggan'),
              subtitle: const Text('Mengekspor semua pelanggan aktif dan tidak aktif tanpa filter'),
              onTap: () async {
                Navigator.pop(ctx);
                final allCustomers = await _repo.getCustomers();
                if (mounted) {
                  ExcelExporter.exportAndShareCustomers(
                    context: context,
                    customers: allCustomers,
                    isFiltered: false,
                  );
                }
              },
            ),
            const SizedBox(height: 10),
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
        title: const Text('Manajemen Pelanggan'),
        actions: [
          IconButton(
            icon: const Icon(Icons.table_view_rounded),
            tooltip: 'Export ke Excel (.xlsx)',
            onPressed: _showExcelExportDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Segarkan',
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Card & Mode Chips
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              children: [
                // Dual Search Mode Selector (ID vs Nama vs Semua)
                Row(
                  children: [
                    const Text('Metode Cari:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(width: 8),
                    _searchTypeChip('Semua', 'all'),
                    const SizedBox(width: 6),
                    _searchTypeChip('ID Pelanggan', 'id'),
                    const SizedBox(width: 6),
                    _searchTypeChip('Nama', 'name'),
                  ],
                ),
                const SizedBox(height: 8),
                // Real-time Search Input
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: _searchType == 'id'
                        ? 'Ketik ID / Kode Pelanggan (misal: CUST-0001)...'
                        : (_searchType == 'name'
                            ? 'Ketik nama lengkap atau sebagian nama...'
                            : 'Cari ID, nama lengkap, telepon, alamat...'),
                    prefixIcon: const Icon(Icons.search, color: AppTheme.navyPrimary),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              _load();
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppTheme.borderLight),
                    ),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  ),
                ),
              ],
            ),
          ),

          // Filters Row (Paket, Status Aktif, Status Pembayaran)
          Container(
            color: Colors.white,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // Filter Status Aktif
                  _filterButton(
                    label: _statusActiveFilter == 'all'
                        ? 'Status: Semua'
                        : (_statusActiveFilter == 'active' ? 'Status: Aktif' : 'Status: Nonaktif'),
                    isActive: _statusActiveFilter != 'all',
                    onTap: () {
                      setState(() {
                        if (_statusActiveFilter == 'all') {
                          _statusActiveFilter = 'active';
                        } else if (_statusActiveFilter == 'active') {
                          _statusActiveFilter = 'inactive';
                        } else {
                          _statusActiveFilter = 'all';
                        }
                      });
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Filter Status Pembayaran
                  _filterButton(
                    label: 'Bayar: $_paymentStatusFilter',
                    isActive: _paymentStatusFilter != 'Semua',
                    onTap: () {
                      final options = ['Semua', 'Lunas', 'Menunggak', 'Terlambat'];
                      final nextIndex = (options.indexOf(_paymentStatusFilter) + 1) % options.length;
                      setState(() {
                        _paymentStatusFilter = options[nextIndex];
                      });
                      _load();
                    },
                  ),
                  const SizedBox(width: 8),

                  // Filter Master Paket Dropdown
                  if (_packages.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _selectedPackageId != null ? AppTheme.navyPrimary.withOpacity(0.08) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _selectedPackageId != null ? AppTheme.navyPrimary : AppTheme.borderLight,
                        ),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int?>(
                          value: _selectedPackageId,
                          isDense: true,
                          hint: const Text('Filter Paket', style: TextStyle(fontSize: 12)),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _selectedPackageId != null ? FontWeight.bold : FontWeight.normal,
                            color: _selectedPackageId != null ? AppTheme.navyPrimary : AppTheme.textPrimary,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text('Semua Paket'),
                            ),
                            ..._packages.map((p) => DropdownMenuItem<int?>(
                                  value: p.id,
                                  child: Text('${p.name} (${p.speed})'),
                                )),
                          ],
                          onChanged: (v) {
                            setState(() => _selectedPackageId = v);
                            _load();
                          },
                        ),
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Tombol Reset Filter jika ada filter aktif
                  if (_searchQuery.isNotEmpty ||
                      _selectedPackageId != null ||
                      _statusActiveFilter != 'all' ||
                      _paymentStatusFilter != 'Semua')
                    TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _searchCtrl.clear();
                          _searchQuery = '';
                          _selectedPackageId = null;
                          _statusActiveFilter = 'all';
                          _paymentStatusFilter = 'Semua';
                        });
                        _load();
                      },
                      icon: const Icon(Icons.close, size: 14),
                      label: const Text('Reset', style: TextStyle(fontSize: 11)),
                    ),
                ],
              ),
            ),
          ),

          const Divider(height: 1),

          // Total Count Info Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFFF1F5F9),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Menampilkan ${_customers.length} Pelanggan',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                ),
                InkWell(
                  onTap: _showExcelExportDialog,
                  child: Row(
                    children: const [
                      Icon(Icons.download_rounded, size: 16, color: Color(0xFF107C41)),
                      SizedBox(width: 4),
                      Text('Export Excel (.xlsx)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF107C41))),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Customer Cards List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _customers.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.person_search_outlined, size: 64, color: AppTheme.textMuted),
                              const SizedBox(height: 12),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'Tidak ditemukan pelanggan dengan kata kunci "$_searchQuery".'
                                    : 'Tidak ada data pelanggan yang sesuai dengan filter.',
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
                                  );
                                  if (res == true) _load();
                                },
                                icon: const Icon(Icons.add),
                                label: const Text('Tambah Pelanggan Baru'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemCount: _customers.length,
                          itemBuilder: (ctx, i) {
                            final c = _customers[i];
                            final hasArrears = c.totalArrears > 0;
                            final dailyFee = BillingCalculator.calculateDailyFee(c.monthlyFee).round();
                            final startDate = DateFormatter.parseDate(c.startDate);
                            final totalDays = BillingCalculator.calculateTotalSubscriptionDays(startDate);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(
                                  color: hasArrears
                                      ? AppTheme.statusDanger.withOpacity(0.3)
                                      : AppTheme.borderLight,
                                ),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () async {
                                  final res = await Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => CustomerDetailScreen(customerId: c.id!),
                                    ),
                                  );
                                  if (res == true) _load();
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header: Name, ID Badge, Status Chip
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: c.isActive
                                                ? AppTheme.navyPrimary.withOpacity(0.1)
                                                : Colors.grey.shade200,
                                            child: Text(
                                              c.name.isNotEmpty ? c.name[0].toUpperCase() : '?',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: c.isActive ? AppTheme.navyPrimary : Colors.grey,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        c.name,
                                                        style: const TextStyle(
                                                          fontSize: 15,
                                                          fontWeight: FontWeight.bold,
                                                          color: AppTheme.textPrimary,
                                                        ),
                                                        overflow: TextOverflow.ellipsis,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: const Color(0xFFEFF6FF),
                                                        borderRadius: BorderRadius.circular(4),
                                                        border: Border.all(color: const Color(0xFFBFDBFE)),
                                                      ),
                                                      child: Text(
                                                        c.customerCode,
                                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Icon(Icons.phone_outlined, size: 13, color: Colors.grey.shade600),
                                                    const SizedBox(width: 3),
                                                    Text(c.phone, style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Status Aktif Badge
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: c.isActive ? const Color(0xFFDCFCE7) : Colors.grey.shade200,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              c.isActive ? 'Aktif' : 'Nonaktif',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: c.isActive ? const Color(0xFF15803D) : Colors.grey.shade700,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // Alamat Lengkap
                                      Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              c.address,
                                              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),
                                      const Divider(height: 1),
                                      const SizedBox(height: 8),

                                      // Paket & Biaya Info Grid
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  c.packageName,
                                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                                                ),
                                                const SizedBox(height: 1),
                                                Text(
                                                  '${CurrencyFormatter.format(c.monthlyFee)}/bln • ${CurrencyFormatter.format(dailyFee)}/hari',
                                                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Mulai: ${DateFormatter.formatDate(startDate)}',
                                                style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                                              ),
                                              Text(
                                                '$totalDays Hari Berlangganan',
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF0F766E)),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),

                                      const SizedBox(height: 8),

                                      // Status Pembayaran & Aksi
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: hasArrears ? const Color(0xFFFEE2E2) : const Color(0xFFD1FAE5),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              hasArrears
                                                  ? 'Menunggak: ${CurrencyFormatter.format(c.totalArrears)}'
                                                  : '✓ Pembayaran Lunas',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: hasArrears ? AppTheme.statusDanger : AppTheme.statusSuccess,
                                              ),
                                            ),
                                          ),
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              if (c.phone.isNotEmpty)
                                                InkWell(
                                                  onTap: () {
                                                    final biz = _businessProfile?.businessName ?? 'Admin WiFi';
                                                    WhatsAppReminderService.shareToWhatsApp(
                                                      phone: c.phone,
                                                      message: 'Halo Bapak/Ibu ${c.name},\nSalam dari $biz.',
                                                      subject: 'WiFi $biz',
                                                    );
                                                  },
                                                  child: Container(
                                                    padding: const EdgeInsets.all(6),
                                                    decoration: BoxDecoration(
                                                      color: const Color(0xFF25D366).withOpacity(0.12),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: const Icon(Icons.chat, size: 16, color: Color(0xFF25D366)),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              PopupMenuButton<String>(
                                                padding: EdgeInsets.zero,
                                                icon: const Icon(Icons.more_vert, size: 18, color: AppTheme.textMuted),
                                                onSelected: (val) {
                                                  if (val == 'detail') {
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (_) => CustomerDetailScreen(customerId: c.id!),
                                                      ),
                                                    ).then((res) {
                                                      if (res == true) _load();
                                                    });
                                                  } else if (val == 'edit') {
                                                    _editCustomer(c);
                                                  } else if (val == 'delete') {
                                                    _deleteCustomer(c);
                                                  }
                                                },
                                                itemBuilder: (_) => [
                                                  const PopupMenuItem(
                                                    value: 'detail',
                                                    child: ListTile(
                                                      leading: Icon(Icons.visibility_outlined, color: AppTheme.navyPrimary),
                                                      title: Text('Lihat Detail Lengkap'),
                                                      contentPadding: EdgeInsets.zero,
                                                      dense: true,
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: ListTile(
                                                      leading: Icon(Icons.edit, color: Colors.blue),
                                                      title: Text('Ubah Data Pelanggan'),
                                                      contentPadding: EdgeInsets.zero,
                                                      dense: true,
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: ListTile(
                                                      leading: Icon(Icons.delete_forever, color: Colors.red),
                                                      title: Text('Hapus Pelanggan', style: TextStyle(color: Colors.red)),
                                                      contentPadding: EdgeInsets.zero,
                                                      dense: true,
                                                    ),
                                                  ),
                                                ],
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CustomerFormScreen()),
          );
          if (res == true) _load();
        },
        icon: const Icon(Icons.person_add),
        label: const Text('Tambah Pelanggan'),
      ),
    );
  }

  Widget _searchTypeChip(String label, String value) {
    final isSelected = _searchType == value;
    return InkWell(
      onTap: () {
        setState(() => _searchType = value);
        _load();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.navyPrimary : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }

  Widget _filterButton({required String label, required bool isActive, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.navyPrimary.withOpacity(0.1) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.navyPrimary : AppTheme.borderLight,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            color: isActive ? AppTheme.navyPrimary : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}
