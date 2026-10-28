import 'package:flutter/material.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../auth/admin_login_screen.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  @override
  Widget build(BuildContext context) {
    final admins = SupabaseService.instance.admins;
    final currentAdmin = SupabaseService.instance.currentAdmin;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Kelola 4 Akun Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: 'Ganti Admin Aktif',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
              );
              if (result == true) {
                setState(() {});
              }
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Banner Status
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.navyPrimary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.people_alt_rounded, color: AppTheme.navyPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Struktur Multi Admin (4 Admin)',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Setiap admin memiliki tanggung jawab khusus dalam sistem.',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'DAFTAR 4 ADMIN & WEWENANG',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 12),

          ...admins.map((admin) {
            final isCurrent = admin.id == currentAdmin.id;
            final color = _getRoleColor(admin.role);
            final duties = _getRoleDuties(admin.role);

            return Card(
              margin: const EdgeInsets.only(bottom: 14),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: isCurrent ? AppTheme.navyPrimary : AppTheme.borderLight,
                  width: isCurrent ? 2 : 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(_getRoleIcon(admin.role), color: color, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    admin.name,
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Sedang Aktif',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                admin.email,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            admin.role,
                            style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    const SizedBox(height: 12),

                    // Info Wewenang
                    Text(
                      'Wewenang & Tugas:',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    ...duties.map(
                      (duty) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
                            Expanded(
                              child: Text(
                                duty,
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (!isCurrent)
                          OutlinedButton.icon(
                            onPressed: () async {
                              await SupabaseService.instance.setActiveAdmin(admin);
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Beralih ke ${admin.name}')),
                              );
                            },
                            icon: const Icon(Icons.login, size: 16),
                            label: const Text('Beralih ke Admin Ini'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppTheme.navyPrimary,
                              side: const BorderSide(color: AppTheme.navyPrimary),
                            ),
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
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Super Admin':
        return const Color(0xFF6366F1);
      case 'Admin Keuangan':
        return const Color(0xFF059669);
      case 'Admin Teknisi':
        return const Color(0xFFD97706);
      case 'Admin Layanan':
        return const Color(0xFF0284C7);
      default:
        return AppTheme.navyPrimary;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Super Admin':
        return Icons.verified_user_rounded;
      case 'Admin Keuangan':
        return Icons.payments_rounded;
      case 'Admin Teknisi':
        return Icons.build_circle_rounded;
      case 'Admin Layanan':
        return Icons.support_agent_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  List<String> _getRoleDuties(String role) {
    switch (role) {
      case 'Super Admin':
        return [
          'Akses penuh seluruh data pelanggan, tagihan, dan pembayaran.',
          'Mengatur paket WiFi, profil usaha, kuitansi, dan sinkronisasi cloud.',
          'Mengelola kredensial dan akun admin lainnya.',
        ];
      case 'Admin Keuangan':
        return [
          'Mencatat pembayaran pelanggan (Tunai, Transfer, E-Wallet).',
          'Mencetak kuitansi resmi (PDF & Bluetooth Thermal).',
          'Mengecek laporan omset harian & ekspor pembukuan ke Excel.',
        ];
      case 'Admin Teknisi':
        return [
          'Mendaftarkan pelanggan baru & melampirkan foto KTP di lapangan.',
          'Memperbarui status pemasangan WiFi & ganti paket pelanggan.',
          'Mengecek informasi teknis lokasi pelanggan.',
        ];
      case 'Admin Layanan':
        return [
          'Memantau daftar tagihan yang mendekati jatuh tempo.',
          'Mengirimkan pengingat tagihan massal atau personal via WhatsApp.',
          'Melayani pertanyaan pelanggan terkait tagihan & kuitansi.',
        ];
      default:
        return ['Operasional harian sistem manajemen WiFi.'];
    }
  }
}
