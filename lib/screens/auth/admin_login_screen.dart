import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../services/session_service.dart';
import '../../services/supabase_service.dart';
import '../../services/api_config.dart';
import '../../utils/app_theme.dart';
import '../main_navigation_screen.dart';

class AdminLoginScreen extends StatefulWidget {
  final bool isInitialGate;

  const AdminLoginScreen({super.key, this.isInitialGate = false});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _serverUrlController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = true;
  bool _showServerConfig = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    final firstAdmin = SupabaseService.instance.admins.isNotEmpty
        ? SupabaseService.instance.admins.first
        : AdminModel.defaultAdmins.first;
    _emailController.text = firstAdmin.email;
    _passwordController.text = '';
    _serverUrlController.text = AppConfig.baseUrl;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _serverUrlController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
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

    // 1. Verifikasi Ketat Kredensial via Supabase Cloud / Database
    try {
      final supaSuccess = await SupabaseService.instance.loginWithCredentials(
        email: email,
        password: password,
        rememberLogin: _rememberMe,
      );

      if (supaSuccess) {
        final currentAdmin = SupabaseService.instance.currentAdmin;
        await SessionService.instance.setSession(
          token: 'supabase_session_${currentAdmin.id}',
          admin: currentAdmin,
          remember: _rememberMe,
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Selamat datang, ${currentAdmin.name}! (${currentAdmin.role})'),
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
        return;
      }
    } catch (e) {
      debugPrint('Supabase login error: $e');
    }

    // Jika sampai di sini, autentikasi gagal (email tidak ada atau password salah)
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = 'Email atau password salah. Periksa kembali email dan password yang Anda masukkan.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isInitialGate,
        title: const Text('Login Multi-Admin WiFi'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Server API',
            icon: Icon(_showServerConfig ? Icons.settings : Icons.settings_outlined),
            onPressed: () {
              setState(() => _showServerConfig = !_showServerConfig);
            },
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
                    child: const Icon(
                      Icons.cloud_done_rounded,
                      size: 40,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'WiFi Management System',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Autentikasi terpusat via REST API',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Opsi Konfigurasi Server Endpoint
            if (_showServerConfig) ...[
              Card(
                elevation: 0,
                color: Colors.blue[50],
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Colors.blue[200]!),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Konfigurasi Endpoint Backend API:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _serverUrlController,
                        decoration: const InputDecoration(
                          isDense: true,
                          labelText: 'Base URL',
                          hintText: 'http://10.0.2.2:4000/api',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _serverUrlController.text = 'http://10.0.2.2:4000/api';
                                AppConfig.baseUrl = 'http://10.0.2.2:4000/api';
                              });
                            },
                            child: const Text('Emulator (10.0.2.2)'),
                          ),
                          TextButton(
                            onPressed: () {
                              setState(() {
                                _serverUrlController.text = 'http://127.0.0.1:4000/api';
                                AppConfig.baseUrl = 'http://127.0.0.1:4000/api';
                              });
                            },
                            child: const Text('Localhost (USB)'),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              AppConfig.baseUrl = _serverUrlController.text.trim();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Base URL diubah ke: ${AppConfig.baseUrl}'),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            child: const Text('Terapkan'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],

            // Form Login
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppTheme.borderLight),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pilih Akun Admin untuk Masuk:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...SupabaseService.instance.admins.map((adm) {
                      final isSelected = _emailController.text.trim().toLowerCase() == adm.email.toLowerCase();
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                          side: BorderSide(
                            color: isSelected ? AppTheme.navyPrimary : AppTheme.borderLight,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        color: isSelected ? Colors.blue.withOpacity(0.06) : Colors.white,
                        child: ListTile(
                          dense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          leading: CircleAvatar(
                            radius: 16,
                            backgroundColor: isSelected ? AppTheme.navyPrimary : Colors.grey[200],
                            child: Icon(Icons.person, size: 18, color: isSelected ? Colors.white : Colors.grey[700]),
                          ),
                          title: Text(adm.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text('${adm.role} • ${adm.email}', style: const TextStyle(fontSize: 11)),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: AppTheme.navyPrimary, size: 20)
                              : const Icon(Icons.radio_button_unchecked, color: Colors.grey, size: 20),
                          onTap: () {
                            setState(() {
                              _emailController.text = adm.email;
                              _passwordController.text = '';
                              _errorMessage = null;
                            });
                          },
                        ),
                      );
                    }),
                    const SizedBox(height: 8),
                    const Divider(height: 1),
                    const SizedBox(height: 12),
                    const Text(
                      'Detail Login:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 10),
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
                      ),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red[200]!),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(color: Colors.red, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    CheckboxListTile(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? true),
                      title: const Text('Ingat sesi login', style: TextStyle(fontSize: 13)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton.icon(
                        onPressed: _isLoading ? null : _handleLogin,
                        icon: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                              )
                            : const Icon(Icons.login_rounded),
                        label: Text(_isLoading ? 'Memverifikasi...' : 'Masuk Sekarang'),
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
}
