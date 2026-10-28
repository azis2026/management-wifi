import 'package:flutter/material.dart';
import '../../models/admin_model.dart';
import '../../services/auth_service.dart';
import '../../services/session_service.dart';
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
    _emailController.text = 'admin1@wifimanager.com';
    _passwordController.text = 'admin123';
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

    // Validasi murni ke Backend API (POST /api/auth/login)
    final authRes = await AuthService.instance.login(
      email: email,
      password: password,
    );

    if (!mounted) return;

    if (authRes.success && authRes.token != null) {
      final loggedAdmin = authRes.admin ??
          AdminModel(
            id: 'admin',
            name: email.split('@').first,
            email: email,
            role: 'Admin',
            createdAt: DateTime.now().toIso8601String(),
          );

      // Simpan session
      await SessionService.instance.setSession(
        token: authRes.token!,
        admin: loggedAdmin,
        remember: _rememberMe,
      );

      setState(() => _isLoading = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Selamat datang, ${loggedAdmin.name}!'),
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
    } else {
      // Login gagal: Kredensial salah / API menolak -> Tolak akses & tampilkan pesan backend
      setState(() {
        _isLoading = false;
        _errorMessage = authRes.message.isNotEmpty
            ? authRes.message
            : 'Email atau password salah. Akses ditolak oleh Backend API.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isInitialGate,
        title: const Text('Login Backend API'),
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
                      'Masuk Akun',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 14),
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
                        label: Text(_isLoading ? 'Menghubungi API...' : 'Masuk via API'),
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
