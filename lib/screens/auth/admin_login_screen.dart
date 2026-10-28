import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../services/supabase_service.dart';
import '../../utils/app_theme.dart';
import '../main_navigation_screen.dart';
import '../../services/auth_service.dart';

class AdminLoginScreen extends StatefulWidget {
  final bool isInitialGate;

  const AdminLoginScreen({super.key, this.isInitialGate = false});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final current = SupabaseService.instance.currentAdmin;
    _emailController.text = current.email.isNotEmpty ? current.email : 'admin1@wifimanager.com';
    _passwordController.text = '123456';
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleQuickSelect(AdminModel admin) async {
    setState(() {
      _emailController.text = admin.email;
      _errorMessage = null;
    });
    await _loginWithAdmin(admin);
  }

  Future<void> _loginWithAdmin(AdminModel admin) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    await Future.delayed(const Duration(milliseconds: 300));
    await SupabaseService.instance.setActiveAdmin(admin, rememberLogin: _rememberMe);

    if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Berhasil masuk sebagai ${admin.name} (${admin.role})'),
          backgroundColor: AppTheme.statusSuccess,
          behavior: SnackBarBehavior.floating,
        ),
      );

      if (widget.isInitialGate) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
        );
      } else {
        Navigator.pop(context, true);
      }
    }
  }

  Future<void> _handleCustomLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Email admin wajib diisi');
      return;
    }
    if (password.isEmpty) {
      setState(() => _errorMessage = 'Password wajib diisi');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // 1. Coba login melalui REST API Backend
    final authRes = await AuthService.instance.login(
      email: email,
      password: password,
    );

    if (authRes.success) {
      final loggedAdmin = authRes.admin ??
          SupabaseService.instance.admins.firstWhere(
            (a) => a.email.toLowerCase() == email.toLowerCase(),
            orElse: () => AdminModel(
              id: 'admin-api',
              name: 'Admin',
              email: email,
              role: 'Super Admin',
              createdAt: DateTime.now().toIso8601String(),
            ),
          );

      await SupabaseService.instance.setActiveAdmin(loggedAdmin, rememberLogin: _rememberMe);

      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang, ${loggedAdmin.name}! (API Token tersimpan)'),
            backgroundColor: AppTheme.statusSuccess,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.isInitialGate) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        } else {
          Navigator.pop(context, true);
        }
      }
      return;
    }

    // 2. Fallback: jika API tidak dapat dijangkau, cek kredensial offline lokal
    final fallbackSuccess = await SupabaseService.instance.loginWithCredentials(
      email: email,
      password: password,
      rememberLogin: _rememberMe,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (fallbackSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Masuk (Offline): ${SupabaseService.instance.currentAdmin.name}'),
            backgroundColor: AppTheme.navyPrimary,
            behavior: SnackBarBehavior.floating,
          ),
        );

        if (widget.isInitialGate) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => const MainNavigationScreen()),
          );
        } else {
          Navigator.pop(context, true);
        }
      } else {
        setState(() {
          _errorMessage = authRes.message.isNotEmpty
              ? authRes.message
              : 'Email atau password salah. Silakan periksa kembali.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final admins = SupabaseService.instance.admins;
    final currentAdmin = SupabaseService.instance.currentAdmin;
    final isOnline = SupabaseService.instance.isOnline;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isInitialGate,
        title: const Text('Login Multi Admin'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isOnline ? Colors.green.withOpacity(0.15) : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isOnline ? Colors.green : Colors.orange,
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: isOnline ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isOnline ? 'Online' : 'Offline Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isOnline ? Colors.green[800] : Colors.orange[800],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppTheme.navyPrimary, Color(0xFF1E3A8A)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.navyPrimary.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.admin_panel_settings_rounded, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Pilih Akun Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Aplikasi mendukung 4 akun admin dengan hak akses berbeda untuk operasional mandiri.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Quick Select 4 Admins Section
            const Text(
              '4 AKUN ADMIN TERSEDIA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            ...admins.map((admin) {
              final isSelected = admin.id == currentAdmin.id;
              final iconColor = _getRoleColor(admin.role);

              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => _handleQuickSelect(admin),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.navyPrimary : AppTheme.borderLight,
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppTheme.navyPrimary.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(_getRoleIcon(admin.role), color: iconColor, size: 22),
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      color: AppTheme.textPrimary,
                                    ),
                                  ),
                                  if (isSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AppTheme.navyPrimary,
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Aktif',
                                        style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${admin.role} • ${admin.email}',
                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected ? Icons.check_circle_rounded : Icons.radio_button_off_rounded,
                          color: isSelected ? AppTheme.navyPrimary : AppTheme.textMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),

            const SizedBox(height: 20),
            const Divider(color: AppTheme.borderLight),
            const SizedBox(height: 16),

            // Manual Login Section
            const Text(
              'LOGIN DENGAN EMAIL & PASSWORD',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppTheme.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email Admin',
                        hintText: 'admin1@wifimanager.com',
                        prefixIcon: Icon(Icons.email_outlined),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: Icon(Icons.lock_outline),
                        border: OutlineInputBorder(),
                        helperText: 'Password default API: 123456',
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    CheckboxListTile(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      title: const Text('Ingat saya (Tetap masuk di perangkat ini)', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleCustomLogin,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isLoading ? 'Memproses...' : 'Masuk Aplikasi'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.navyPrimary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
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
}
