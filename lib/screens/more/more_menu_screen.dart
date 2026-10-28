import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';
import '../package/package_list_screen.dart';
import '../payment/payment_history_screen.dart';
import '../due_reminders/due_reminder_screen.dart';
import '../reports/reports_screen.dart';
import '../backup/backup_restore_screen.dart';
import '../settings/settings_screen.dart';
import '../settings/cloud_sync_screen.dart';
import '../admin/admin_management_screen.dart';
import '../../services/supabase_service.dart';

class MoreMenuScreen extends StatelessWidget {
  const MoreMenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Menu Lainnya'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        children: [
          // Section 1: Operasional
          _buildSectionHeader('OPERASIONAL & LAYANAN'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildMenuRow(
                  context: context,
                  icon: Icons.wifi_rounded,
                  title: 'Paket WiFi',
                  subtitle: 'Kecepatan, harga bulanan, dan paket hajatan',
                  color: AppTheme.toskaAccent,
                  destination: const PackageListScreen(),
                  showDivider: true,
                ),
                _buildMenuRow(
                  context: context,
                  icon: Icons.notifications_active_rounded,
                  title: 'Pengingat Jatuh Tempo',
                  subtitle: 'Pantau tagihan jatuh tempo & kirim WhatsApp',
                  color: const Color(0xFFEA580C),
                  destination: const DueReminderScreen(),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 2: Keuangan & Laporan
          _buildSectionHeader('KEUANGAN & DOKUMEN'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildMenuRow(
                  context: context,
                  icon: Icons.receipt_long_rounded,
                  title: 'Riwayat Transaksi',
                  subtitle: 'Daftar semua pembayaran dan cetak ulang kuitansi',
                  color: AppTheme.navyPrimary,
                  destination: const PaymentHistoryScreen(),
                  showDivider: true,
                ),
                _buildMenuRow(
                  context: context,
                  icon: Icons.table_chart_rounded,
                  title: 'Laporan Keuangan',
                  subtitle: 'Ringkasan omset & ekspor ke Excel / Spreadsheet',
                  color: AppTheme.statusSuccess,
                  destination: const ReportsScreen(),
                  showDivider: false,
                ),
              ],
            ),
          ),
          // Section 3: Cloud & Multi Admin
          _buildSectionHeader('ONLINE CLOUD & MULTI ADMIN'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildMenuRow(
                  context: context,
                  icon: Icons.cloud_sync_rounded,
                  title: 'Supabase Cloud & Sinkronisasi',
                  subtitle: 'Koneksi online, 1-klik migrasi data offline ke cloud',
                  color: const Color(0xFF059669),
                  destination: const CloudSyncScreen(),
                  showDivider: true,
                ),
                _buildMenuRow(
                  context: context,
                  icon: Icons.admin_panel_settings_rounded,
                  title: 'Kelola 4 Akun Admin',
                  subtitle: 'Hak akses, pembagian wewenang, dan ganti admin',
                  color: const Color(0xFF6366F1),
                  destination: const AdminManagementScreen(),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section 4: Sistem & Keamanan
          _buildSectionHeader('PENGATURAN & SISTEM'),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                _buildMenuRow(
                  context: context,
                  icon: Icons.business_center_rounded,
                  title: 'Profil Usaha & Kuitansi',
                  subtitle: 'Nama usaha, kontak, upload Logo dan Tanda Tangan',
                  color: const Color(0xFF6366F1),
                  destination: const SettingsScreen(),
                  showDivider: true,
                ),
                _buildMenuRow(
                  context: context,
                  icon: Icons.settings_backup_restore_rounded,
                  title: 'Backup & Restore Database',
                  subtitle: 'Amankan data aplikasi atau cadangkan ke file',
                  color: const Color(0xFF0284C7),
                  destination: const BackupRestoreScreen(),
                  showDivider: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Logout Button
          OutlinedButton.icon(
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Keluar Akun Admin?'),
                  content: Text(
                    'Anda saat ini masuk sebagai ${SupabaseService.instance.currentAdmin.name}.\nApakah Anda yakin ingin keluar?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                await SupabaseService.instance.logout();
              }
            },
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            label: const Text(
              'Keluar Akun Admin (Logout)',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: const BorderSide(color: Colors.redAccent),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 32),

          // App Info Footer
          Center(
            child: Column(
              children: const [
                Icon(Icons.shield_outlined, size: 28, color: AppTheme.textMuted),
                SizedBox(height: 6),
                Text(
                  'WiFi Manager Mandiri • v2.0.0',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textSecondary),
                ),
                SizedBox(height: 2),
                Text(
                  '100% Offline Standalone • Data tersimpan aman di HP/PC',
                  style: TextStyle(fontSize: 11, color: AppTheme.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppTheme.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  Widget _buildMenuRow({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required Widget destination,
    required bool showDivider,
  }) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          trailing: const Icon(Icons.chevron_right, color: AppTheme.textMuted, size: 20),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => destination),
            );
          },
        ),
        if (showDivider)
          const Divider(height: 1, indent: 64, endIndent: 16, color: AppTheme.borderLight),
      ],
    );
  }
}
