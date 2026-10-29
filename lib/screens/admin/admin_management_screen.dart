import 'package:flutter/material.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../../models/admin_model.dart';
import '../../app.dart';

class AdminManagementScreen extends StatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  State<AdminManagementScreen> createState() => _AdminManagementScreenState();
}

class _AdminManagementScreenState extends State<AdminManagementScreen> {
  final List<String> _availableRoles = [
    'Super Admin',
    'Admin Keuangan',
    'Admin Teknisi',
    'Admin Layanan',
  ];

  @override
  void initState() {
    super.initState();
    SupabaseService.instance.addListener(_onSupabaseChange);
  }

  @override
  void dispose() {
    SupabaseService.instance.removeListener(_onSupabaseChange);
    super.dispose();
  }

  void _onSupabaseChange() {
    if (mounted) setState(() {});
  }

  Future<void> _showCreateAdminDialog() async {
    final nameCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final passCtrl = TextEditingController();
    String selectedRole = 'Admin Keuangan';
    bool obscurePass = true;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.person_add_alt_1_rounded, color: AppTheme.navyPrimary),
              SizedBox(width: 8),
              Text('Tambah Admin Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap / Username *',
                    hintText: 'Contoh: Ahmad Fauzi',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Admin *',
                    hintText: 'ahmad@wifimanager.com',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp / HP',
                    hintText: '08123456789',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Peran / Role *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: passCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password Akun *',
                    hintText: 'Minimal 6 karakter',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final pass = passCtrl.text;

                if (name.isEmpty) {
                  setDlgState(() => errorText = 'Nama admin wajib diisi.');
                  return;
                }
                if (email.isEmpty || !email.contains('@')) {
                  setDlgState(() => errorText = 'Format email tidak valid.');
                  return;
                }
                if (pass.isEmpty) {
                  setDlgState(() => errorText = 'Password tidak boleh kosong.');
                  return;
                }

                try {
                  await SupabaseService.instance.createAdmin(
                    name: name,
                    email: email,
                    role: selectedRole,
                    phone: phoneCtrl.text.trim(),
                    password: pass,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Akun admin "$name" berhasil dibuat & tersinkron online!'),
                        backgroundColor: AppTheme.statusSuccess,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  setDlgState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                }
              },
              child: const Text('Simpan Admin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showEditAdminDialog(AdminModel admin) async {
    final nameCtrl = TextEditingController(text: admin.name);
    final emailCtrl = TextEditingController(text: admin.email);
    final phoneCtrl = TextEditingController(text: admin.phone);
    final newPassCtrl = TextEditingController();
    String selectedRole = _availableRoles.contains(admin.role) ? admin.role : _availableRoles.first;
    bool obscurePass = true;
    String? errorText;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.edit_rounded, color: AppTheme.navyPrimary),
              SizedBox(width: 8),
              Text('Edit Profil & Password Admin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (errorText != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ],
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Lengkap / Username *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email Admin *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Nomor WhatsApp / HP',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Peran / Role *',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: _availableRoles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                  onChanged: (v) {
                    if (v != null) setDlgState(() => selectedRole = v);
                  },
                ),
                const SizedBox(height: 14),
                const Divider(height: 1),
                const SizedBox(height: 12),
                const Text(
                  'Ganti Password (Opsional):',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: newPassCtrl,
                  obscureText: obscurePass,
                  decoration: InputDecoration(
                    labelText: 'Password Baru',
                    hintText: 'Kosongkan jika tidak ingin diubah',
                    border: const OutlineInputBorder(),
                    isDense: true,
                    suffixIcon: IconButton(
                      icon: Icon(obscurePass ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setDlgState(() => obscurePass = !obscurePass),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.navyPrimary,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final email = emailCtrl.text.trim();
                final newPass = newPassCtrl.text;

                if (name.isEmpty) {
                  setDlgState(() => errorText = 'Nama admin wajib diisi.');
                  return;
                }
                if (email.isEmpty || !email.contains('@')) {
                  setDlgState(() => errorText = 'Format email tidak valid.');
                  return;
                }

                try {
                  await SupabaseService.instance.updateAdmin(
                    id: admin.id,
                    name: name,
                    email: email,
                    role: selectedRole,
                    phone: phoneCtrl.text.trim(),
                    newPassword: newPass.isNotEmpty ? newPass : null,
                  );

                  // Update juga SessionService jika admin yang diedit sedang login
                  if (SessionService.instance.currentAdmin?.id == admin.id) {
                    final updatedModel = admin.copyWith(
                      name: name,
                      email: email,
                      role: selectedRole,
                      phone: phoneCtrl.text.trim(),
                      passwordHash: newPass.isNotEmpty ? newPass : admin.passwordHash,
                    );
                    await SessionService.instance.setSession(
                      token: 'supabase_session_${admin.id}',
                      admin: updatedModel,
                      remember: true,
                    );
                  }

                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Perubahan data admin "$name" berhasil disimpan!'),
                        backgroundColor: AppTheme.statusSuccess,
                      ),
                    );
                    setState(() {});
                  }
                } catch (e) {
                  setDlgState(() => errorText = e.toString().replaceAll('Exception: ', ''));
                }
              },
              child: const Text('Simpan Perubahan'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAdmin(AdminModel admin) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Akun Admin?'),
        content: Text(
          'Anda yakin ingin menghapus akun admin "${admin.name}" (${admin.role})?\n\nTindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await SupabaseService.instance.deleteAdmin(admin.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Akun admin "${admin.name}" telah dihapus.'),
            backgroundColor: AppTheme.statusSuccess,
          ),
        );
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menghapus admin: $e'),
            backgroundColor: AppTheme.statusDanger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentAdmin = SessionService.instance.currentAdmin;
    final admins = SupabaseService.instance.admins;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: const Text('Kelola Akun Admin'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang dari Cloud',
            onPressed: () async {
              await SupabaseService.instance.loadAdmins();
              setState(() {});
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout_rounded, color: Colors.red),
            tooltip: 'Keluar (Logout)',
            onPressed: () async {
              await SessionService.instance.logout();
              await SupabaseService.instance.logout();
              if (context.mounted) {
                Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => const AuthGate()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppTheme.navyPrimary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Tambah Admin'),
        onPressed: _showCreateAdminDialog,
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
                  child: const Icon(Icons.shield_rounded, color: AppTheme.navyPrimary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        currentAdmin != null ? 'Sedang Masuk: ${currentAdmin.name}' : 'Multi-Admin Terhubung',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        currentAdmin != null
                            ? 'Wewenang: ${currentAdmin.role} • ${currentAdmin.email}'
                            : 'Database Supabase Cloud Aktif',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'DAFTAR AKUN ADMIN & WEWENANG',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                'Total: ${admins.length} Admin',
                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),

          ...admins.map((admin) {
            final isCurrent = currentAdmin != null && admin.id == currentAdmin.id;
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
                          radius: 22,
                          backgroundColor: color.withOpacity(0.15),
                          child: Icon(_getRoleIcon(admin.role), color: color, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      admin.name,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  if (isCurrent) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Aktif',
                                        style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${admin.email} ${admin.phone.isNotEmpty ? '• ${admin.phone}' : ''}',
                                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: AppTheme.borderLight),
                    const SizedBox(height: 10),

                    // Info Wewenang
                    const Text(
                      'Wewenang & Tugas:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
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

                    // Tombol Aksi: Edit, Hapus, Gunakan
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _showEditAdminDialog(admin),
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit / Ganti Pass', style: TextStyle(fontSize: 12)),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.navyPrimary,
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          ),
                        ),
                        if (!isCurrent) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                            tooltip: 'Hapus Admin',
                            onPressed: () => _confirmDeleteAdmin(admin),
                          ),
                        ],
                        const Spacer(),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.green.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                                SizedBox(width: 4),
                                Text('Sedang Digunakan', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                              ],
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            onPressed: () async {
                              await SessionService.instance.setSession(
                                token: 'supabase_session_${admin.id}',
                                admin: admin,
                                remember: true,
                              );
                              await SupabaseService.instance.setActiveAdmin(admin, rememberLogin: true);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Beralih ke: ${admin.name} (${admin.role})'),
                                  backgroundColor: AppTheme.statusSuccess,
                                ),
                              );
                              setState(() {});
                            },
                            icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                            label: const Text('Pilih Akun Ini', style: TextStyle(fontSize: 12)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 70),
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
          'Akses penuh ke seluruh modul & fitur sistem',
          'Kelola master paket & harga langganan',
          'Kelola hak akses & akun 4 admin',
          'Konfigurasi backup & sinkronisasi Supabase Cloud',
        ];
      case 'Admin Keuangan':
        return [
          'Mencatat & menerima pembayaran tagihan (Kasir)',
          'Cetak kuitansi pembayaran PDF / Bluetooth Thermal',
          'Melihat laporan keuangan, omset, dan sisa piutang',
          'Batalkan transaksi pembayaran jika terjadi kekeliruan',
        ];
      case 'Admin Teknisi':
        return [
          'Pendaftaran pelanggan baru & pemasangan WiFi',
          'Unggah & verifikasi foto KTP pelanggan ke Cloud',
          'Ubah paket internet pelanggan di lapangan',
          'Aktivasi / nonaktifkan status isolir pelanggan',
        ];
      case 'Admin Layanan':
        return [
          'Pantau daftar pelanggan jatuh tempo & menunggak',
          'Kirim pengingat tagihan massal via WhatsApp',
          'Layanan keluhan & bantuan pelanggan',
          'Lihat rincian riwayat tagihan pelanggan',
        ];
      default:
        return ['Akses operasional standar WiFi Management'];
    }
  }
}
