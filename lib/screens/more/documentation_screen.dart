import 'package:flutter/material.dart';
import '../../utils/app_theme.dart';

class DocumentationScreen extends StatelessWidget {
  const DocumentationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Buku Panduan & Dokumentasi'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header Card
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppTheme.navyPrimary, Color(0xFF1E3A8A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.navyPrimary.withOpacity(0.2),
                  blurRadius: 8,
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
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 30),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Pusat Bantuan & Panduan',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Petunjuk lengkap operasional, alur transaksi, dan arsitektur sistem.',
                        style: TextStyle(color: Colors.white70, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Bab 1: Akun Admin & Login
          _buildDocSection(
            icon: Icons.admin_panel_settings_rounded,
            title: '1. Akses Akun & Autentikasi API',
            color: const Color(0xFF6366F1),
            items: [
              'Login menggunakan kredensial email & password resmi ke Backend API.',
              'Tersedia 4 wewenang admin: Super Admin, Keuangan, Teknisi, dan Layanan CS.',
              'Token JWT disimpan otomatis di perangkat untuk menjaga sesi aktif.',
              'Tombol Logout tersedia di menu Lainnya dan profile bar atas.',
            ],
          ),

          // Bab 2: Paket & Pelanggan
          _buildDocSection(
            icon: Icons.people_alt_rounded,
            title: '2. Manajemen Paket & Pelanggan',
            color: AppTheme.toskaAccent,
            items: [
              'Paket WiFi dapat diatur kecepatan, harga bulanan, serta biaya pasang.',
              'Pendaftaran pelanggan baru menyertakan nomor HP, tanggal pasang, dan foto KTP.',
              'Status pelanggan (Aktif / Nonaktif) dapat diubah kapan saja.',
            ],
          ),

          // Bab 3: Tagihan & WhatsApp
          _buildDocSection(
            icon: Icons.receipt_long_rounded,
            title: '3. Penagihan & Notifikasi WhatsApp',
            color: const Color(0xFFEA580C),
            items: [
              'Tagihan dapat diterbitkan manual atau otomatis setiap 30 hari.',
              'Fitur Pengingat Jatuh Tempo memfilter tagihan yang mendekati/lewat tempo.',
              'Tombol WhatsApp sekali klik langsung membuka chat ke nomor pelanggan.',
            ],
          ),

          // Bab 4: Pembayaran & Kuitansi
          _buildDocSection(
            icon: Icons.payments_rounded,
            title: '4. Pembayaran & Cetak Kuitansi',
            color: AppTheme.statusSuccess,
            items: [
              'Mendukung metode Tunai, Transfer Bank, dan E-Wallet.',
              'Mendukung pembayaran lunas maupun cicilan/bertahap.',
              'Kuitansi digital dilengkapi logo usaha, tanda tangan, dan nomor seri unik.',
              'Dapat dibagikan sebagai gambar / PDF kuitansi resmi.',
            ],
          ),

          // Bab 5: Deploy & Online Cloud
          _buildDocSection(
            icon: Icons.cloud_done_rounded,
            title: '5. Sinkronisasi Online & Suga App',
            color: const Color(0xFF0284C7),
            items: [
              'Aplikasi siap di-deploy versi Web menggunakan Suga App (suga.app).',
              'Seluruh data terpusat ke cloud database Supabase / backend API.',
              'Multi admin dapat membuka aplikasi bersamaan via HP atau Web Laptop.',
            ],
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildDocSection({
    required IconData icon,
    required String title,
    required Color color,
    required List<String> items,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
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
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withOpacity(0.12),
                  child: Icon(icon, color: color, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: AppTheme.borderLight),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

