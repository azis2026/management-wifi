import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../auth/admin_login_screen.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _urlController = TextEditingController();
  final _keyController = TextEditingController();
  bool _isTesting = false;
  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = false;

  Map<String, int> _localCounts = {'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};
  Map<String, int> _cloudCounts = {'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};
  bool _isLoadingCounts = true;

  @override
  void initState() {
    super.initState();
    _urlController.text = SupabaseService.instance.supabaseUrl;
    _keyController.text = SupabaseService.instance.supabaseAnonKey;
    _refreshCounts();
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _refreshCounts() async {
    setState(() => _isLoadingCounts = true);
    try {
      final local = await SupabaseService.instance.getLocalDataCounts();
      final cloud = await SupabaseService.instance.getCloudDataCounts();
      if (mounted) {
        setState(() {
          _localCounts = local;
          _cloudCounts = cloud;
          _isLoadingCounts = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingCounts = false);
    }
  }

  Future<void> _saveAndTest() async {
    final url = _urlController.text.trim();
    final key = _keyController.text.trim();

    if (url.isEmpty || key.isEmpty) {
      setState(() {
        _statusMessage = 'Harap isi URL Project dan Anon Key Supabase.';
        _isSuccess = false;
      });
      return;
    }

    setState(() {
      _isTesting = true;
      _statusMessage = null;
    });

    final success = await SupabaseService.instance.configure(url: url, anonKey: key);
    await _refreshCounts();

    if (mounted) {
      setState(() {
        _isTesting = false;
        if (success) {
          _isSuccess = true;
          _statusMessage = 'Berhasil terhubung ke Supabase Cloud! Database online aktif & sinkron.';
        } else {
          _isSuccess = false;
          _statusMessage = 'Gagal terhubung. Pastikan URL dan Anon Key sudah benar.';
        }
      });
    }
  }

  Future<void> _handleSyncTwoWay() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Sinkronisasi Lengkap Dua Arah?'),
        content: const Text(
          'Aplikasi akan mengunduh data terbaru dari Supabase ke HP, lalu mengunggah data lokal yang belum ada di server.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyPrimary, foregroundColor: Colors.white),
            child: const Text('Ya, Sinkronkan'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final res = await SupabaseService.instance.syncTwoWay();
      await _refreshCounts();
      final pulled = res['pulled'] as Map<String, int>? ?? {};
      final pushed = res['pushed'] as Map<String, int>? ?? {};

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Sinkronisasi Dua Arah Selesai!\n'
              '• Diunduh dari Cloud: ${pulled['customers'] ?? 0} pelanggan, ${pulled['packages'] ?? 0} paket\n'
              '• Diunggah ke Cloud: ${pushed['customers'] ?? 0} pelanggan, ${pushed['bills'] ?? 0} tagihan\n'
              'Data HP dan Supabase kini seragam dan sinkron.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Gagal sinkronisasi: $e';
        });
      }
    }
  }

  Future<void> _handleUploadToCloud() async {
    final localCust = _localCounts['customers'] ?? 0;
    final localPkg = _localCounts['packages'] ?? 0;

    if (localCust == 0 && localPkg == 0) {
      final fillDemo = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Data Lokal Masih Kosong'),
          content: const Text(
            'Saat ini di HP Anda belum ada data pelanggan atau paket lokal (0 data).\n\n'
            'Apakah Anda ingin:\n'
            '1. "Isi Data Contoh" (5 pelanggan demo langsung masuk ke HP & Cloud), atau\n'
            '2. "Tarik dari Cloud" jika data sudah ada di Supabase?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Tutup')),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF6366F1), foregroundColor: Colors.white),
              child: const Text('Isi 5 Data Demo'),
            ),
          ],
        ),
      );

      if (fillDemo == true) {
        await _handleSeedDemo();
      }
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Data HP ke Supabase?'),
        content: Text(
          'Data lokal (${_localCounts['packages']} paket, ${_localCounts['customers']} pelanggan, '
          '${_localCounts['bills']} tagihan, ${_localCounts['payments']} pembayaran) akan diunggah ke Supabase Cloud.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyPrimary, foregroundColor: Colors.white),
            child: const Text('Ya, Upload Sekarang'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final results = await SupabaseService.instance.uploadLocalDataToSupabase();
      await _refreshCounts();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Upload Berhasil Terupdate di Supabase!\n'
              '• Paket: ${results['packages']} data\n'
              '• Pelanggan: ${results['customers']} data\n'
              '• Tagihan: ${results['bills']} data\n'
              '• Pembayaran: ${results['payments']} data\n'
              'Semua 4 admin kini dapat mengakses data ini secara online.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Gagal upload: $e';
        });
      }
    }
  }

  Future<void> _handlePullFromCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tarik Data dari Cloud?'),
        content: const Text(
          'Data paket, pelanggan, dan tagihan dari Supabase Cloud akan diunduh ke memori HP ini.\n\nLanjutkan?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.navyPrimary, foregroundColor: Colors.white),
            child: const Text('Tarik Data'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      final results = await SupabaseService.instance.pullDataFromSupabaseToLocal();
      await _refreshCounts();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Data berhasil ditarik dari Cloud ke HP!\n'
              '• Paket: ${results['packages']} data\n'
              '• Pelanggan: ${results['customers']} data\n'
              '• Tagihan: ${results['bills']} data\n'
              '• Pembayaran: ${results['payments']} data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Gagal mengunduh: $e';
        });
      }
    }
  }

  Future<void> _handleSeedDemo() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });

    try {
      await SupabaseService.instance.seedDemoData();
      await _refreshCounts();
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = true;
          _statusMessage = 'Berhasil Menambahkan 5 Data Demo!\n'
              '• 5 Pelanggan baru (Budi, Siti, Agus, Dewi, Hendra)\n'
              '• 5 Tagihan (Lunas, Belum Bayar, Sebagian, Terlambat)\n'
              '• Bukti Pembayaran Kuitansi\n'
              'Data langsung tersimpan di HP dan disinkronkan ke Supabase Cloud.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _isSuccess = false;
          _statusMessage = 'Gagal membuat data demo: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOnline = SupabaseService.instance.isOnline;
    final currentAdmin = SupabaseService.instance.currentAdmin;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Supabase Cloud & Online'),
        actions: [
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _isLoadingCounts ? null : _refreshCounts,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Card Status Koneksi
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isOnline
                    ? [const Color(0xFF059669), const Color(0xFF047857)]
                    : [const Color(0xFF374151), const Color(0xFF1F2937)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: (isOnline ? Colors.green : Colors.grey).withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
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
                      children: [
                        Icon(
                          isOnline ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                          color: Colors.white,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          isOnline ? 'Terhubung ke Cloud' : 'Mode Offline / Standalone',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isOnline ? 'ONLINE' : 'OFFLINE',
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  isOnline
                      ? 'Database PostgreSQL Supabase aktif. Perubahan data disinkronkan secara realtime ke seluruh 4 admin.'
                      : 'Aplikasi saat ini beroperasi dengan database lokal SQLite. Hubungkan ke Supabase di bawah untuk mengaktifkan sinkronisasi online.',
                  style: TextStyle(color: Colors.white.withOpacity(0.9), fontSize: 13),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person_pin_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Admin Aktif: ${currentAdmin.name} (${currentAdmin.role})',
                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                          ).then((_) => setState(() {}));
                        },
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        ),
                        child: const Text('Ganti', style: TextStyle(decoration: TextDecoration.underline)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Card Komparasi Jumlah Data (HP vs Supabase)
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'STATUS DATA (HP vs CLOUD)',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                      ),
                      if (_isLoadingCounts)
                        const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                      else
                        Text(
                          'Tersinkron',
                          style: TextStyle(fontSize: 11, color: isOnline ? Colors.green[700] : Colors.grey, fontWeight: FontWeight.bold),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.phone_android_rounded, size: 16, color: Colors.blueGrey),
                                  SizedBox(width: 4),
                                  Text('Data di HP (Lokal)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('• Paket: ${_localCounts['packages']}'),
                              Text('• Pelanggan: ${_localCounts['customers']}'),
                              Text('• Tagihan: ${_localCounts['bills']}'),
                              Text('• Pembayaran: ${_localCounts['payments']}'),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.green.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.cloud_done_rounded, size: 16, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  const Text('Data di Supabase', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text('• Paket: ${_cloudCounts['packages']}'),
                              Text('• Pelanggan: ${_cloudCounts['customers']}'),
                              Text('• Tagihan: ${_cloudCounts['bills']}'),
                              Text('• Pembayaran: ${_cloudCounts['payments']}'),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Pesan Status Jika Ada
          if (_statusMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _isSuccess ? Colors.green[50] : Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _isSuccess ? Colors.green : Colors.red),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _isSuccess ? Icons.check_circle_rounded : Icons.error_outline_rounded,
                    color: _isSuccess ? Colors.green[700] : Colors.red[700],
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        color: _isSuccess ? Colors.green[900] : Colors.red[900],
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],

          // Tombol Tindakan Sinkronisasi
          const Text(
            'AKSI SINKRONISASI & DATA',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // 1. Tombol Utama: Sinkronisasi 2 Arah
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: (_isProcessing || !isOnline) ? null : _handleSyncTwoWay,
                      icon: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.sync_rounded),
                      label: Text(_isProcessing ? 'Sedang Memproses...' : '⚡ Sinkronisasi Dua Arah (Cloud & HP)'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF047857),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppTheme.borderLight),
                  const SizedBox(height: 14),

                  // 2. Upload SQLite ke Cloud
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_upload_rounded, color: Color(0xFF6366F1)),
                    ),
                    title: const Text(
                      'Unggah Data HP ke Cloud (Upload)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Salin data di HP ke Supabase agar bisa diakses admin lain.',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: ElevatedButton(
                      onPressed: (_isProcessing || !isOnline) ? null : _handleUploadToCloud,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Upload'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 3. Tarik Cloud ke Lokal
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.cloud_download_rounded, color: Color(0xFF059669)),
                    ),
                    title: const Text(
                      'Tarik Data dari Cloud ke HP (Pull)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Unduh data paket dan pelanggan dari Supabase ke HP ini.',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: OutlinedButton(
                      onPressed: (_isProcessing || !isOnline) ? null : _handlePullFromCloud,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                      ),
                      child: const Text('Tarik'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // 4. Isi Data Demo
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.amber.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: Colors.orange),
                    ),
                    title: const Text(
                      'Isi Data Contoh (Demo 5 Pelanggan)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    subtitle: const Text(
                      'Buat 5 pelanggan WiFi + tagihan dan otomatis upload ke Supabase.',
                      style: TextStyle(fontSize: 11),
                    ),
                    trailing: OutlinedButton(
                      onPressed: _isProcessing ? null : _handleSeedDemo,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.orange[800],
                        side: BorderSide(color: Colors.orange[800]!),
                      ),
                      child: const Text('Isi Demo'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Formulir Kredensial Supabase
          const Text(
            'KREDENSIAL PROYEK SUPABASE',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: const BorderSide(color: AppTheme.borderLight),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Supabase Project URL',
                      hintText: 'https://xxxxxxxx.supabase.co',
                      prefixIcon: Icon(Icons.link_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Supabase Anon Public API Key',
                      hintText: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...',
                      prefixIcon: Icon(Icons.vpn_key_rounded),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: _isTesting ? null : _saveAndTest,
                      icon: _isTesting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.cloud_sync_rounded),
                      label: Text(_isTesting ? 'Menghubungkan...' : 'Simpan & Uji Koneksi'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyPrimary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
