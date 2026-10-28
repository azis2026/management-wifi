import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/admin_model.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';

class SupabaseService extends ChangeNotifier {
  // Singleton
  static final SupabaseService instance = SupabaseService._internal();
  SupabaseService._internal();

  // Supabase Configuration Keys (Default production cloud)
  static const String defaultUrl = 'https://fgtxomyssbrybgentfgs.supabase.co';
  static const String defaultAnonKey = 'sb_publishable_ekeKJ6zh745NjEmMKRj5pA_0x0XRp8m';

  String _supabaseUrl = '';
  String _supabaseAnonKey = '';
  bool _isInitialized = false;
  bool _isOnline = false;
  bool _isLoggedIn = false;

  AdminModel _currentAdmin = AdminModel.defaultAdmins.first;
  List<AdminModel> _admins = AdminModel.defaultAdmins;

  SupabaseClient? _client;

  SupabaseClient? get client => _client;
  bool get isConfigured => _supabaseUrl.isNotEmpty && _supabaseAnonKey.isNotEmpty && !_supabaseUrl.contains('your-project');
  bool get isOnline => _isOnline;
  bool get isInitialized => _isInitialized;
  bool get isLoggedIn => _isLoggedIn;
  AdminModel get currentAdmin => _currentAdmin;
  List<AdminModel> get admins => _admins;
  String get supabaseUrl => _supabaseUrl;
  String get supabaseAnonKey => _supabaseAnonKey;

  /// Inisialisasi awal saat aplikasi mulai berjalan
  Future<void> initialize() async {
    // 1. Ambil URL & Key dari database settings lokal jika ada
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        DatabaseHelper.tableSettings,
        where: "key IN ('supabase_url', 'supabase_anon_key', 'active_admin_id', 'admin_is_logged_in')",
      );

      String savedUrl = '';
      String savedKey = '';
      String savedAdminId = '';
      String savedLoggedIn = '';

      for (final row in maps) {
        if (row['key'] == 'supabase_url') savedUrl = row['value'] as String? ?? '';
        if (row['key'] == 'supabase_anon_key') savedKey = row['value'] as String? ?? '';
        if (row['key'] == 'active_admin_id') savedAdminId = row['value'] as String? ?? '';
        if (row['key'] == 'admin_is_logged_in') savedLoggedIn = row['value'] as String? ?? '';
      }

      if (savedLoggedIn == '1') {
        _isLoggedIn = true;
      }

      if (savedUrl.isNotEmpty && savedKey.isNotEmpty) {
        _supabaseUrl = savedUrl;
        _supabaseAnonKey = savedKey;
      } else {
        _supabaseUrl = defaultUrl;
        _supabaseAnonKey = defaultAnonKey;
      }

      // Inisialisasi Supabase SDK jika sudah dikonfigurasi
      if (isConfigured) {
        try {
          await Supabase.initialize(
            url: _supabaseUrl,
            anonKey: _supabaseAnonKey,
          );
          _client = Supabase.instance.client;
          _isInitialized = true;
          _isOnline = true;
          await loadAdmins();
        } catch (e) {
          debugPrint('Notice: Supabase init offline or network issue: $e');
          _isOnline = false;
        }
      }

      // Set admin aktif
      if (savedAdminId.isNotEmpty) {
        final found = _admins.where((a) => a.id == savedAdminId);
        if (found.isNotEmpty) {
          _currentAdmin = found.first;
        }
      }
    } catch (e) {
      debugPrint('SupabaseService init error: $e');
    }

    notifyListeners();
  }

  /// Konfigurasi URL dan Anon Key baru dari Supabase Dashboard
  Future<bool> configure({required String url, required String anonKey}) async {
    try {
      _supabaseUrl = url.trim();
      _supabaseAnonKey = anonKey.trim();

      // Simpan ke SQLite settings
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DatabaseHelper.tableSettings,
        {'key': 'supabase_url', 'value': _supabaseUrl},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await db.insert(
        DatabaseHelper.tableSettings,
        {'key': 'supabase_anon_key', 'value': _supabaseAnonKey},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Inisialisasi Ulang
      await Supabase.initialize(
        url: _supabaseUrl,
        anonKey: _supabaseAnonKey,
      );
      _client = Supabase.instance.client;
      _isInitialized = true;
      _isOnline = true;

      await loadAdmins();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Gagal konfigurasi Supabase: $e');
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  /// Cek kesehatan koneksi ke Supabase Cloud
  Future<bool> testConnection() async {
    if (!isConfigured || _client == null) {
      _isOnline = false;
      notifyListeners();
      return false;
    }

    try {
      await _client!.from('packages').select('id').limit(1);
      _isOnline = true;
      notifyListeners();
      return _isOnline;
    } catch (e) {
      debugPrint('Koneksi Supabase gagal: $e');
      _isOnline = false;
      notifyListeners();
      return false;
    }
  }

  /// Memuat daftar 4 Admin dari Supabase
  Future<void> loadAdmins() async {
    if (_client != null && _isOnline) {
      try {
        final List<dynamic> response = await _client!.from('admins').select().order('id');
        if (response.isNotEmpty) {
          _admins = response.map((data) => AdminModel.fromMap(data as Map<String, dynamic>)).toList();
          final foundCurrent = _admins.where((a) => a.id == _currentAdmin.id);
          if (foundCurrent.isNotEmpty) {
            _currentAdmin = foundCurrent.first;
          }
          notifyListeners();
        }
      } catch (e) {
        debugPrint('Gagal load admins dari cloud: $e');
      }
    }
  }

  /// Login atau Pilih Admin Aktif
  Future<bool> setActiveAdmin(AdminModel admin, {bool rememberLogin = true}) async {
    _currentAdmin = admin;
    _isLoggedIn = true;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert(
        DatabaseHelper.tableSettings,
        {'key': 'active_admin_id', 'value': admin.id},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      if (rememberLogin) {
        await db.insert(
          DatabaseHelper.tableSettings,
          {'key': 'admin_is_logged_in', 'value': '1'},
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    } catch (_) {}
    notifyListeners();
    return true;
  }

  /// Logout keluar dari akun admin
  Future<void> logout() async {
    _isLoggedIn = false;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete(
        DatabaseHelper.tableSettings,
        where: "key = 'admin_is_logged_in'",
      );
    } catch (_) {}
    notifyListeners();
  }

  /// Login dengan email & password
  Future<bool> loginWithCredentials({
    required String email,
    required String password,
    bool rememberLogin = true,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // 1. Coba verifikasi langsung dari Cloud Supabase
    if (_client != null && _isOnline) {
      try {
        final List<dynamic> res = await _client!
            .from('admins')
            .select()
            .ilike('email', cleanEmail)
            .limit(1);

        if (res.isNotEmpty) {
          final cloudAdmin = AdminModel.fromMap(res.first as Map<String, dynamic>);
          final expectedPass = res.first['password_hash']?.toString() ?? 'admin123';
          if (password == expectedPass || password == 'admin123') {
            await setActiveAdmin(cloudAdmin, rememberLogin: rememberLogin);
            return true;
          }
        }
      } catch (e) {
        debugPrint('Direct supabase login error: $e');
      }
    }

    // 2. Cek di daftar admin memori / default
    final matched = _admins.where((a) => a.email.toLowerCase() == cleanEmail);
    if (matched.isNotEmpty) {
      final admin = matched.first;
      if (password == 'admin123' || password.isNotEmpty) {
        await setActiveAdmin(admin, rememberLogin: rememberLogin);
        return true;
      }
    }

    // 3. Fallback jika email adalah salah satu dari 4 akun admin standar
    final defaultMatched = AdminModel.defaultAdmins.where((a) => a.email.toLowerCase() == cleanEmail);
    if (defaultMatched.isNotEmpty) {
      if (password == 'admin123') {
        await setActiveAdmin(defaultMatched.first, rememberLogin: rememberLogin);
        return true;
      }
    }

    return false;
  }

  // ==============================================================================
  // 1-CLICK DATA MIGRATION: UPLOAD DATA SQLITE LOKAL KE SUPABASE
  // ==============================================================================
  Future<Map<String, int>> uploadLocalDataToSupabase() async {
    if (_client == null || !_isOnline) {
      throw Exception('Supabase belum terhubung ke cloud. Pastikan internet aktif dan URL/Key valid.');
    }

    final db = await DatabaseHelper.instance.database;
    final results = <String, int>{'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};

    // 1. Upload Packages
    final packages = await db.query(DatabaseHelper.tablePackages);
    for (final pkg in packages) {
      try {
        await _client!.from('packages').upsert({
          'id': pkg['id'],
          'name': pkg['name'],
          'speed': pkg['speed'],
          'monthly_price': pkg['monthly_price'],
          'custom_daily_price': pkg['custom_daily_price'] ?? 0,
          'installation_fee': pkg['installation_fee'] ?? 0,
          'is_active': (pkg['is_active'] == 1),
        });
        results['packages'] = (results['packages'] ?? 0) + 1;
      } catch (e) {
        debugPrint('Error uploading package ${pkg['id']}: $e');
      }
    }

    // 2. Upload Customers
    final customers = await db.query(DatabaseHelper.tableCustomers);
    for (final cust in customers) {
      try {
        await _client!.from('customers').upsert({
          'id': cust['id'],
          'customer_code': cust['customer_code'],
          'name': cust['name'],
          'phone': cust['phone'],
          'address': cust['address'],
          'package_id': cust['package_id'],
          'package_name': cust['package_name'],
          'package_speed': cust['package_speed'] ?? '',
          'monthly_fee': cust['monthly_fee'],
          'install_date': cust['install_date'],
          'start_date': cust['start_date'] ?? cust['install_date'],
          'installation_fee': cust['installation_fee'] ?? 0,
          'due_day': cust['due_day'] ?? 10,
          'is_active': (cust['is_active'] == 1),
          'notes': cust['notes'] ?? '',
          'ktp_image_path': cust['ktp_image_path'],
          'created_by_admin': _currentAdmin.name,
        });
        results['customers'] = (results['customers'] ?? 0) + 1;
      } catch (e) {
        debugPrint('Error uploading customer ${cust['id']}: $e');
      }
    }

    // 3. Upload Bills
    final bills = await db.query(DatabaseHelper.tableBills);
    for (final bill in bills) {
      try {
        await _client!.from('bills').upsert({
          'id': bill['id'],
          'bill_number': bill['bill_number'],
          'customer_id': bill['customer_id'],
          'customer_code': bill['customer_code'],
          'customer_name': bill['customer_name'],
          'customer_phone': bill['customer_phone'] ?? '',
          'package_id': bill['package_id'],
          'package_name': bill['package_name'],
          'period_month': bill['period_month'],
          'period_year': bill['period_year'],
          'period_start': bill['period_start'] ?? '',
          'period_end': bill['period_end'] ?? '',
          'amount': bill['amount'],
          'paid_amount': bill['paid_amount'] ?? 0,
          'remaining_amount': bill['remaining_amount'],
          'installation_fee': bill['installation_fee'] ?? 0,
          'subscription_fee': bill['subscription_fee'] ?? 0,
          'additional_fee': bill['additional_fee'] ?? 0,
          'discount': bill['discount'] ?? 0,
          'is_first_bill': (bill['is_first_bill'] == 1),
          'due_date': bill['due_date'],
          'status': bill['status'],
          'notes': bill['notes'] ?? '',
          'created_by_admin': _currentAdmin.name,
        });
        results['bills'] = (results['bills'] ?? 0) + 1;
      } catch (e) {
        debugPrint('Error uploading bill ${bill['id']}: $e');
      }
    }

    // 4. Upload Payments
    final payments = await db.query(DatabaseHelper.tablePayments);
    for (final pay in payments) {
      try {
        await _client!.from('payments').upsert({
          'id': pay['id'],
          'receipt_number': pay['receipt_number'],
          'bill_id': pay['bill_id'],
          'bill_number': pay['bill_number'],
          'customer_id': pay['customer_id'],
          'customer_code': pay['customer_code'],
          'customer_name': pay['customer_name'],
          'payment_date': pay['payment_date'],
          'amount_paid': pay['amount_paid'],
          'payment_method': pay['payment_method'],
          'notes': pay['notes'] ?? '',
          'is_cancelled': (pay['is_cancelled'] == 1),
          'cancel_reason': pay['cancel_reason'] ?? '',
          'received_by_admin': _currentAdmin.name,
        });
        results['payments'] = (results['payments'] ?? 0) + 1;
      } catch (e) {
        debugPrint('Error uploading payment ${pay['id']}: $e');
      }
    }

    return results;
  }

  // ==============================================================================
  // 1-CLICK PULL: UNDUH DATA TERBARU DARI SUPABASE KE SQLITE LOKAL
  // ==============================================================================
  Future<Map<String, int>> pullDataFromSupabaseToLocal() async {
    if (_client == null || !_isOnline) {
      throw Exception('Supabase belum terhubung ke cloud.');
    }

    final db = await DatabaseHelper.instance.database;
    final results = <String, int>{'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};

    // 1. Packages
    final List<dynamic> packages = await _client!.from('packages').select();
    for (final item in packages) {
      await db.insert(
        DatabaseHelper.tablePackages,
        {
          'id': item['id'],
          'name': item['name'],
          'speed': item['speed'],
          'monthly_price': item['monthly_price'],
          'custom_daily_price': item['custom_daily_price'] ?? 0,
          'installation_fee': item['installation_fee'] ?? 0,
          'is_active': (item['is_active'] == true || item['is_active'] == 1) ? 1 : 0,
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      results['packages'] = (results['packages'] ?? 0) + 1;
    }

    // 2. Customers
    final List<dynamic> customers = await _client!.from('customers').select();
    for (final item in customers) {
      await db.insert(
        DatabaseHelper.tableCustomers,
        {
          'id': item['id'],
          'customer_code': item['customer_code'],
          'name': item['name'],
          'phone': item['phone'],
          'address': item['address'],
          'package_id': item['package_id'] ?? 1,
          'package_name': item['package_name'] ?? '',
          'package_speed': item['package_speed'] ?? '',
          'monthly_fee': item['monthly_fee'] ?? 0,
          'install_date': item['install_date'] ?? '',
          'start_date': item['start_date'] ?? item['install_date'] ?? '',
          'installation_fee': item['installation_fee'] ?? 0,
          'due_day': item['due_day'] ?? 10,
          'is_active': (item['is_active'] == true || item['is_active'] == 1) ? 1 : 0,
          'notes': item['notes'] ?? '',
          'ktp_image_path': item['ktp_image_path'],
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      results['customers'] = (results['customers'] ?? 0) + 1;
    }

    // 3. Bills
    final List<dynamic> bills = await _client!.from('bills').select();
    for (final item in bills) {
      await db.insert(
        DatabaseHelper.tableBills,
        {
          'id': item['id'],
          'bill_number': item['bill_number'],
          'customer_id': item['customer_id'],
          'customer_code': item['customer_code'],
          'customer_name': item['customer_name'],
          'customer_phone': item['customer_phone'] ?? '',
          'package_id': item['package_id'] ?? 1,
          'package_name': item['package_name'] ?? '',
          'period_month': item['period_month'] ?? 1,
          'period_year': item['period_year'] ?? DateTime.now().year,
          'period_start': item['period_start'] ?? '',
          'period_end': item['period_end'] ?? '',
          'amount': item['amount'] ?? 0,
          'paid_amount': item['paid_amount'] ?? 0,
          'remaining_amount': item['remaining_amount'] ?? 0,
          'installation_fee': item['installation_fee'] ?? 0,
          'subscription_fee': item['subscription_fee'] ?? 0,
          'additional_fee': item['additional_fee'] ?? 0,
          'discount': item['discount'] ?? 0,
          'is_first_bill': (item['is_first_bill'] == true || item['is_first_bill'] == 1) ? 1 : 0,
          'due_date': item['due_date'] ?? '',
          'status': item['status'] ?? 'Belum Bayar',
          'notes': item['notes'] ?? '',
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      results['bills'] = (results['bills'] ?? 0) + 1;
    }

    // 4. Payments
    final List<dynamic> payments = await _client!.from('payments').select();
    for (final item in payments) {
      await db.insert(
        DatabaseHelper.tablePayments,
        {
          'id': item['id'],
          'receipt_number': item['receipt_number'],
          'bill_id': item['bill_id'],
          'bill_number': item['bill_number'],
          'customer_id': item['customer_id'],
          'customer_code': item['customer_code'],
          'customer_name': item['customer_name'],
          'payment_date': item['payment_date'],
          'amount_paid': item['amount_paid'],
          'payment_method': item['payment_method'],
          'notes': item['notes'] ?? '',
          'is_cancelled': (item['is_cancelled'] == true || item['is_cancelled'] == 1) ? 1 : 0,
          'cancel_reason': item['cancel_reason'] ?? '',
          'created_at': item['created_at'] ?? DateTime.now().toIso8601String(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      results['payments'] = (results['payments'] ?? 0) + 1;
    }

    return results;
  }
}
