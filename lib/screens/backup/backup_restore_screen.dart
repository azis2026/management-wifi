import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../database/database_helper.dart';
import '../../utils/app_theme.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _isProcessing = false;
  String? _statusMessage;
  bool _isSuccess = true;

  Future<void> _exportBackup() async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Menyiapkan cadangan data...';
      _isSuccess = true;
    });

    try {
      final jsonString = await _dbHelper.exportBackupJson();

      final dir = await getApplicationDocumentsDirectory();
      final now = DateTime.now();
      final timestamp = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
      final fileName = 'wifi_manager_backup_$timestamp.json';
      final file = File('${dir.path}/$fileName');
      await file.writeAsString(jsonString);

      setState(() {
        _isProcessing = false;
        _statusMessage = 'Cadangan berhasil dibuat: $fileName';
      });

      // Share or save backup file
      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'Cadangan Database WiFi Manager ($fileName)',
        text: 'File cadangan resmi WiFi Manager. Simpan di Google Drive, memori HP, atau kirim ke WhatsApp.',
      );
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = 'Gagal membuat cadangan: $e';
      });
    }
  }

  Future<void> _restoreBackup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.statusWarning),
            SizedBox(width: 8),
            Text('Konfirmasi Pemulihan'),
          ],
        ),
        content: const Text(
          'PERINGATAN PENTING:\n\n'
          'Memulihkan data akan MENGGANTIKAN seluruh data pelanggan, tagihan, dan pembayaran yang ada saat ini dengan data dari file cadangan.\n\n'
          'Pastikan Anda telah mencadangkan data terbaru sebelum melanjutkan. Apakah Anda yakin?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.statusDanger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Ya, Pilih File & Pulihkan'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json', 'wfbkp'],
      );

      if (files.isEmpty || files.first.path == null) {
        return; // User canceled picking
      }

      setState(() {
        _isProcessing = true;
        _statusMessage = 'Membaca dan memvalidasi file cadangan...';
        _isSuccess = true;
      });

      final pickedFile = File(files.first.path!);
      final content = await pickedFile.readAsString();

      await _dbHelper.restoreFromBackupJson(content);

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = 'Data berhasil dipulihkan secara utuh!';
      });

      if (mounted) {
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.statusSuccess),
                SizedBox(width: 8),
                Text('Pemulihan Sukses'),
              ],
            ),
            content: const Text(
              'Database WiFi Manager berhasil dipulihkan dari file cadangan. Semua data pelanggan, paket, tagihan, dan pembayaran telah dimuat ulang.',
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = 'Gagal memulihkan: ${e.toString().replaceAll('Exception: ', '')}';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & Restore'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Internal Storage Notice Card
            Card(
              margin: EdgeInsets.zero,
              color: AppTheme.navyPrimary.withOpacity(0.04),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.security, color: AppTheme.navyPrimary),
                        SizedBox(width: 8),
                        Text(
                          'Penyimpanan Offline & Keamanan Data',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppTheme.navyPrimary,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Semua data Anda tersimpan 100% di dalam memori internal HP Anda tanpa server cloud. '
                      'Data ini aman dari akses internet luar, namun DAPAT HILANG jika aplikasi dicopot (uninstall) atau Anda membersihkan penyimpanan aplikasi.\n\n'
                      'Sangat disarankan untuk melakukan Cadangkan Data secara berkala dan menyimpannya di tempat aman seperti Flashdisk, Komputer, atau WhatsApp pribadi.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Backup Section
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Cadangkan Data (Backup)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ekspor seluruh database (pelanggan, paket, tagihan, transaksi, kuitansi) ke file JSON yang dapat disimpan atau dibagikan.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.navyPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _exportBackup,
                      icon: const Icon(Icons.cloud_upload_outlined),
                      label: const Text('Cadangkan Data Sekarang'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Restore Section
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pulihkan Data (Restore)',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.navyPrimary),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Impor file cadangan resmi (.json) untuk memulihkan seluruh data pada HP baru atau setelah reset aplikasi.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.statusDanger,
                        side: const BorderSide(color: AppTheme.statusDanger),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isProcessing ? null : _restoreBackup,
                      icon: const Icon(Icons.settings_backup_restore),
                      label: const Text('Pilih File & Pulihkan Data'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Progress / Status indicator
            if (_isProcessing)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              ),

            if (_statusMessage != null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isSuccess
                      ? AppTheme.statusSuccess.withOpacity(0.12)
                      : AppTheme.statusDanger.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: _isSuccess ? AppTheme.statusSuccess : AppTheme.statusDanger,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _isSuccess ? Icons.check_circle : Icons.error_outline,
                      color: _isSuccess ? AppTheme.statusSuccess : AppTheme.statusDanger,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _statusMessage!,
                        style: TextStyle(
                          color: _isSuccess ? Colors.green.shade900 : Colors.red.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
