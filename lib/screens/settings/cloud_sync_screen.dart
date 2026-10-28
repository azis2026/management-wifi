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
  bool _isMigrating = false;
  bool _isPulling = false;
  String? _statusMessage;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    _urlController.text = SupabaseService.instance.supabaseUrl;
    _keyController.text = SupabaseService.instance.supabaseAnonKey;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _keyController.dispose();
    super.dispose();
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

    if (mounted) {
      setState(() {
        _isTesting = false;
        if (success) {
          _isSuccess = true;
          _statusMessage = 'Berhasil terhubung ke Supabase Cloud! Database online siap digunakan.';
        } else {
          _isSuccess = false;
          _statusMessage = 'Gagal terhubung. Pastikan URL dan Anon Key sudah benar serta skrip SQL sudah dijalankan.';
        }
      });
    }
  }

  Future<void> _handleUploadToCloud() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Upload Data ke Cloud?'),
        content: const Text(
          'Semua data paket, pelanggan, tagihan, dan pembayaran dari SQLite lokal perangkat ini akan disalin ke Supabase Cloud.\n\nLanjutkan?',
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
      _isMigrating = true;
      _statusMessage = null;
    });

    try {
      final results = await SupabaseService.instance.uploadLocalDataToSupabase();
      if (mounted) {
        setState(() {
          _isMigrating = false;
          _isSuccess = true;
          _statusMessage = 'Migrasi berhasil!\n'
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
          _isMigrating = false;
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
          'Data terbaru dari Supabase Cloud akan diunduh dan disimpan ke penyimpanan lokal perangkat ini agar tetap bisa diakses saat offline.\n\nLanjutkan?',
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
      _isPulling = true;
      _statusMessage = null;
    });

    try {
      final results = await SupabaseService.instance.pullDataFromSupabaseToLocal();
      if (mounted) {
        setState(() {
          _isPulling = false;
          _isSuccess = true;
          _statusMessage = 'Data berhasil diunduh ke lokal!\n'
              '• Paket: ${results['packages']} data\n'
              '• Pelanggan: ${results['customers']} data\n'
              '• Tagihan: ${results['bills']} data\n'
              '• Pembayaran: ${results['payments']} data';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isPulling = false;
          _isSuccess = false;
          _statusMessage = 'Gagal mengunduh: $e';
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
                const SizedBox(height: 12),
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

          // Fitur Migrasi Data (Upload / Download)
          const Text(
            'SINKRONISASI DATA (MIGRASI)',
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
                      'Migrasi SQLite Offline ke Cloud',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Salin seluruh data lokal di perangkat ke Supabase agar bisa diakses 4 admin.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: ElevatedButton(
                      onPressed: (_isMigrating || !isOnline) ? null : _handleUploadToCloud,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF6366F1),
                        foregroundColor: Colors.white,
                      ),
                      child: Text(_isMigrating ? 'Mengunggah...' : 'Upload'),
                    ),
                  ),
                  const Divider(height: 24, color: AppTheme.borderLight),
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
                      'Tarik Data dari Cloud ke Lokal',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Simpan salinan data online ke memori internal perangkat ini.',
                      style: TextStyle(fontSize: 12),
                    ),
                    trailing: OutlinedButton(
                      onPressed: (_isPulling || !isOnline) ? null : _handlePullFromCloud,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF059669),
                        side: const BorderSide(color: Color(0xFF059669)),
                      ),
                      child: Text(_isPulling ? 'Mengunduh...' : 'Tarik'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Langkah Cepat Pengaturan Supabase
          const Text(
            'CARA MENGHUBUNGKAN SUPABASE GRATIS',
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
                children: const [
                  Text('1. Buka https://supabase.com dan klik "Start your project" (Gratis).',
                      style: TextStyle(fontSize: 13, height: 1.4)),
                  SizedBox(height: 6),
                  Text('2. Masuk ke Project Settings > API, copy URL dan anon key.',
                      style: TextStyle(fontSize: 13, height: 1.4)),
                  SizedBox(height: 6),
                  Text('3. Buka menu SQL Editor di Supabase, jalankan skrip supabase_schema.sql.',
                      style: TextStyle(fontSize: 13, height: 1.4)),
                  SizedBox(height: 6),
                  Text('4. Masukkan URL dan Key ke formulir di atas, lalu tekan Simpan.',
                      style: TextStyle(fontSize: 13, height: 1.4)),
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
