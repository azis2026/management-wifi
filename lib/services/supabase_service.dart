import 'dart:async';
import 'dart:convert';
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
  static const String defaultAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZndHhvbXlzc2JyeWJnZW50ZmdzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTMxODY4MzcsImV4cCI6MjEwODc2MjgzN30.74tAMAfCpsUfsnVj8KlNl4PfIrdJ52vb4EjAi9OqDGw';

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
      } else {
        _isLoggedIn = false;
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
          initRealtimeSubscription();
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
      try {
        await Supabase.initialize(
          url: _supabaseUrl,
          anonKey: _supabaseAnonKey,
        );
        _client = Supabase.instance.client;
      } catch (_) {
        _client = SupabaseClient(_supabaseUrl, _supabaseAnonKey);
      }
      _isInitialized = true;
      _isOnline = true;

      await loadAdmins();
      initRealtimeSubscription();
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

  /// Memuat daftar 4 Admin dari Supabase atau lokal
  Future<void> loadAdmins() async {
    if (_client != null && _isOnline) {
      try {
        final List<dynamic> response = await _client!.from('admins').select().order('id');
        if (response.isNotEmpty) {
          _admins = response.map((data) => AdminModel.fromMap(data as Map<String, dynamic>)).toList();
          await _persistAdminsLocally();
          final foundCurrent = _admins.where((a) => a.id == _currentAdmin.id);
          if (foundCurrent.isNotEmpty) {
            _currentAdmin = foundCurrent.first;
          }
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint('Gagal load admins dari cloud: $e');
      }
    }

    // Fallback baca dari cache SQLite lokal
    try {
      final db = await DatabaseHelper.instance.database;
      final maps = await db.query(
        DatabaseHelper.tableSettings,
        where: "key = 'cached_admins_list'",
      );
      if (maps.isNotEmpty) {
        final val = maps.first['value'] as String?;
        if (val != null && val.isNotEmpty) {
          final List<dynamic> list = jsonDecode(val);
          _admins = list.map((item) => AdminModel.fromMap(item as Map<String, dynamic>)).toList();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  /// Simpan daftar admin ke SQLite settings lokal
  Future<void> _persistAdminsLocally() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final jsonList = _admins.map((a) => a.toMap()).toList();
      await db.insert(
        DatabaseHelper.tableSettings,
        {'key': 'cached_admins_list', 'value': jsonEncode(jsonList)},
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (_) {}
  }

  /// Tambah akun admin baru
  Future<bool> createAdmin({
    required String name,
    required String email,
    required String role,
    String phone = '',
    required String password,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    
    // Cek apakah email sudah terdaftar
    if (_admins.any((a) => a.email.toLowerCase() == cleanEmail)) {
      throw Exception('Email "$cleanEmail" sudah digunakan oleh admin lain.');
    }

    final newId = 'admin-${DateTime.now().millisecondsSinceEpoch}';
    final newAdmin = AdminModel(
      id: newId,
      name: name.trim(),
      email: cleanEmail,
      role: role.trim(),
      phone: phone.trim(),
      passwordHash: password,
      isActive: true,
      createdAt: DateTime.now().toIso8601String(),
    );

    // 1. Simpan ke Supabase jika online
    if (_client != null && _isOnline) {
      try {
        await _client!.from('admins').insert({
          'id': newId,
          'name': newAdmin.name,
          'email': newAdmin.email,
          'role': newAdmin.role,
          'phone': newAdmin.phone,
          'password_hash': password,
          'is_active': true,
        });
      } catch (e) {
        debugPrint('Gagal insert admin ke Supabase: $e');
        throw Exception('Gagal menyimpan admin ke database cloud: $e');
      }
    }

    // 2. Simpan di memori & SQLite lokal
    _admins.add(newAdmin);
    await _persistAdminsLocally();
    notifyListeners();
    return true;
  }

  /// Edit data username/nama, email, role, no HP, dan ganti password admin
  Future<bool> updateAdmin({
    required String id,
    required String name,
    required String email,
    required String role,
    String phone = '',
    String? newPassword,
  }) async {
    final cleanEmail = email.trim().toLowerCase();

    // 1. Update ke Supabase Cloud
    if (_client != null && _isOnline) {
      try {
        final updateData = <String, dynamic>{
          'name': name.trim(),
          'email': cleanEmail,
          'role': role.trim(),
          'phone': phone.trim(),
        };
        if (newPassword != null && newPassword.trim().isNotEmpty) {
          updateData['password_hash'] = newPassword.trim();
        }

        await _client!.from('admins').update(updateData).eq('id', id);
      } catch (e) {
        debugPrint('Gagal update admin di Supabase: $e');
        throw Exception('Gagal memperbarui admin di database cloud: $e');
      }
    }

    // 2. Update di daftar lokal
    final idx = _admins.indexWhere((a) => a.id == id);
    if (idx != -1) {
      final old = _admins[idx];
      final updated = old.copyWith(
        name: name.trim(),
        email: cleanEmail,
        role: role.trim(),
        phone: phone.trim(),
        passwordHash: (newPassword != null && newPassword.trim().isNotEmpty)
            ? newPassword.trim()
            : old.passwordHash,
      );
      _admins[idx] = updated;

      if (_currentAdmin.id == id) {
        _currentAdmin = updated;
        await setActiveAdmin(updated, rememberLogin: true);
      }
    }

    await _persistAdminsLocally();
    notifyListeners();
    return true;
  }

  /// Hapus akun admin
  Future<bool> deleteAdmin(String id) async {
    if (_admins.length <= 1) {
      throw Exception('Minimal harus ada 1 akun admin aktif. Tidak dapat menghapus.');
    }

    if (_currentAdmin.id == id) {
      throw Exception('Tidak dapat menghapus akun admin yang sedang Anda gunakan saat ini.');
    }

    // 1. Hapus dari Supabase Cloud
    if (_client != null && _isOnline) {
      try {
        await _client!.from('admins').delete().eq('id', id);
      } catch (e) {
        debugPrint('Gagal delete admin dari Supabase: $e');
        throw Exception('Gagal menghapus admin di database cloud: $e');
      }
    }

    // 2. Hapus dari lokal
    _admins.removeWhere((a) => a.id == id);
    await _persistAdminsLocally();
    notifyListeners();
    return true;
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
      await db.delete(
        DatabaseHelper.tableSettings,
        where: "key = 'active_admin_id'",
      );
    } catch (_) {}
    notifyListeners();
  }

  /// Login dengan email & password (Validasi Ketat & Aman)
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
          if (password == expectedPass) {
            await setActiveAdmin(cloudAdmin, rememberLogin: rememberLogin);
            return true;
          } else {
            // Password salah di database online -> Langsung tolak!
            return false;
          }
        } else {
          // Email tidak terdaftar di database online
          return false;
        }
      } catch (e) {
        debugPrint('Direct supabase login error: $e');
      }
    }

    // 2. Fallback offline: Cek di daftar admin memori / cache lokal
    final matched = _admins.where((a) => a.email.toLowerCase() == cleanEmail);
    if (matched.isNotEmpty) {
      final admin = matched.first;
      if (password == admin.passwordHash) {
        await setActiveAdmin(admin, rememberLogin: rememberLogin);
        return true;
      }
      return false; // Password salah
    }

    return false;
  }

  // ==============================================================================
  // DATA COUNTERS: HITUNG JUMLAH DATA LOKAL & CLOUD
  // ==============================================================================
  Future<Map<String, int>> getLocalDataCounts() async {
    final db = await DatabaseHelper.instance.database;
    final pkgCount = (await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseHelper.tablePackages}')).first['c'] as int? ?? 0;
    final custCount = (await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseHelper.tableCustomers}')).first['c'] as int? ?? 0;
    final billCount = (await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseHelper.tableBills}')).first['c'] as int? ?? 0;
    final payCount = (await db.rawQuery('SELECT COUNT(*) as c FROM ${DatabaseHelper.tablePayments}')).first['c'] as int? ?? 0;
    return {
      'packages': pkgCount,
      'customers': custCount,
      'bills': billCount,
      'payments': payCount,
    };
  }

  Future<Map<String, int>> getCloudDataCounts() async {
    if (_client == null || !_isOnline) {
      return {'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};
    }
    try {
      final pkgs = await _client!.from('packages').select('id');
      final custs = await _client!.from('customers').select('id');
      final bills = await _client!.from('bills').select('id');
      final pays = await _client!.from('payments').select('id');
      return {
        'packages': (pkgs as List).length,
        'customers': (custs as List).length,
        'bills': (bills as List).length,
        'payments': (pays as List).length,
      };
    } catch (_) {
      return {'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};
    }
  }

  // ==============================================================================
  // 1-CLICK DATA MIGRATION: UPLOAD DATA SQLITE LOKAL KE SUPABASE
  // ==============================================================================
  Future<Map<String, int>> uploadLocalDataToSupabase() async {
    if (_client == null || !_isOnline) {
      throw Exception('Supabase belum terhubung ke cloud. Pastikan internet aktif dan URL/Key valid.');
    }

    final db = await DatabaseHelper.instance.database;
    // Pastikan paket master selalu ada di SQLite
    try {
      await DatabaseHelper.ensureMasterPackages(db);
    } catch (_) {}

    final results = <String, int>{'packages': 0, 'customers': 0, 'bills': 0, 'payments': 0};
    final List<String> errors = [];

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
        errors.add('Paket ${pkg['name']}: $e');
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
        errors.add('Pelanggan ${cust['name']}: $e');
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
        errors.add('Tagihan ${bill['bill_number']}: $e');
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
        errors.add('Pembayaran ${pay['receipt_number']}: $e');
      }
    }

    if (errors.isNotEmpty && (results['packages']! + results['customers']! + results['bills']! + results['payments']!) == 0) {
      throw Exception('Gagal migrasi ke Supabase:\n${errors.take(3).join('\n')}');
    }

    return results;
  }

  // ==============================================================================
  // 1-CLICK PULL: UNDUH DATA TERBARU DARI SUPABASE KE SQLITE LOKAL
  // ==============================================================================
  Future<int> pullPackagesOnly() async {
    if (_client == null || !_isOnline) return 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final List<dynamic> packages = await _client!.from('packages').select();
      int count = 0;
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
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> pullCustomersOnly() async {
    if (_client == null || !_isOnline) return 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final List<dynamic> customers = await _client!.from('customers').select();
      int count = 0;
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
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> pullBillsOnly() async {
    if (_client == null || !_isOnline) return 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final List<dynamic> bills = await _client!.from('bills').select();
      int count = 0;
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
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<int> pullPaymentsOnly() async {
    if (_client == null || !_isOnline) return 0;
    try {
      final db = await DatabaseHelper.instance.database;
      final List<dynamic> payments = await _client!.from('payments').select();
      int count = 0;
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
        count++;
      }
      return count;
    } catch (_) {
      return 0;
    }
  }

  Future<Map<String, int>> pullDataFromSupabaseToLocal() async {
    if (_client == null || !_isOnline) {
      throw Exception('Supabase belum terhubung ke cloud.');
    }

    final pkgCount = await pullPackagesOnly();
    final custCount = await pullCustomersOnly();
    final billCount = await pullBillsOnly();
    final payCount = await pullPaymentsOnly();

    return {
      'packages': pkgCount,
      'customers': custCount,
      'bills': billCount,
      'payments': payCount,
    };
  }

  // ==============================================================================
  // REALTIME SYNCHRONIZATION: DENGARKAN PERUBAHAN DATA DARI 4 ADMIN SECARA LANGSUNG
  // ==============================================================================
  RealtimeChannel? _realtimeChannel;

  void initRealtimeSubscription() {
    if (_client == null || !_isOnline) return;

    try {
      if (_realtimeChannel != null) {
        try {
          _client!.removeChannel(_realtimeChannel!);
        } catch (_) {}
      }

      _realtimeChannel = _client!.channel('public:realtime_sync')
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'customers',
          callback: (payload) async {
            debugPrint('Realtime Supabase: Perubahan pada tabel customers (${payload.eventType})');
            await pullCustomersOnly();
            notifyListeners();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bills',
          callback: (payload) async {
            debugPrint('Realtime Supabase: Perubahan pada tabel bills (${payload.eventType})');
            await pullBillsOnly();
            notifyListeners();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'payments',
          callback: (payload) async {
            debugPrint('Realtime Supabase: Perubahan pada tabel payments (${payload.eventType})');
            await pullPaymentsOnly();
            notifyListeners();
          },
        )
        ..onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'packages',
          callback: (payload) async {
            debugPrint('Realtime Supabase: Perubahan pada tabel packages (${payload.eventType})');
            await pullPackagesOnly();
            notifyListeners();
          },
        )
        ..subscribe();

      debugPrint('Realtime Supabase Channel aktif: Menyimak data dari seluruh 4 admin.');
    } catch (e) {
      debugPrint('Realtime subscription notice: $e');
    }
  }

  // ==============================================================================
  // SINKRONISASI LENGKAP DUA ARAH (TWO-WAY SYNC)
  // ==============================================================================
  Future<Map<String, dynamic>> syncTwoWay() async {
    final pullResult = await pullDataFromSupabaseToLocal();
    final pushResult = await uploadLocalDataToSupabase();
    return {
      'pulled': pullResult,
      'pushed': pushResult,
    };
  }

  // ==============================================================================
  // SEED DEMO DATA (5 CONTOH PELANGGAN, TAGIHAN & PEMBAYARAN LENGKAP)
  // ==============================================================================
  Future<void> seedDemoData() async {
    final db = await DatabaseHelper.instance.database;
    await DatabaseHelper.ensureMasterPackages(db);

    final demoCustomers = [
      {
        'id': 1,
        'customer_code': 'CUST-0001',
        'name': 'Budi Santoso',
        'phone': '081234567801',
        'address': 'Jl. Merdeka Barat No. 12, RT 01/RW 02',
        'package_id': 1,
        'package_name': 'Paket Hemat',
        'package_speed': '6 Mbps',
        'monthly_fee': 60000,
        'install_date': '2026-10-01',
        'start_date': '2026-10-01',
        'installation_fee': 0,
        'due_day': 10,
        'is_active': 1,
        'notes': 'Pelanggan Rumah Tinggal',
        'bill_num': 'INV-202610-0001',
        'bill_status': 'Lunas',
        'paid_amount': 60000,
        'has_payment': true,
        'receipt_num': 'KW-20261001-0001',
      },
      {
        'id': 2,
        'customer_code': 'CUST-0002',
        'name': 'Siti Aminah',
        'phone': '081234567802',
        'address': 'Komplek Griya Indah Blok B3 No. 7',
        'package_id': 2,
        'package_name': 'Paket Hemat',
        'package_speed': '11 Mbps',
        'monthly_fee': 85000,
        'install_date': '2026-10-05',
        'start_date': '2026-10-05',
        'installation_fee': 0,
        'due_day': 15,
        'is_active': 1,
        'notes': 'Toko Kelontong',
        'bill_num': 'INV-202610-0002',
        'bill_status': 'Lunas',
        'paid_amount': 85000,
        'has_payment': true,
        'receipt_num': 'KW-20261005-0002',
      },
      {
        'id': 3,
        'customer_code': 'CUST-0003',
        'name': 'Agus Prasetyo',
        'phone': '081234567803',
        'address': 'Jl. Melati IV No. 8',
        'package_id': 3,
        'package_name': 'Paket Keluar',
        'package_speed': '20 Mbps',
        'monthly_fee': 111000,
        'install_date': '2026-10-10',
        'start_date': '2026-10-10',
        'installation_fee': 0,
        'due_day': 10,
        'is_active': 1,
        'notes': 'Kos-kosan Mahasiswa',
        'bill_num': 'INV-202610-0003',
        'bill_status': 'Belum Bayar',
        'paid_amount': 0,
        'has_payment': false,
        'receipt_num': '',
      },
      {
        'id': 4,
        'customer_code': 'CUST-0004',
        'name': 'Dewi Sartika',
        'phone': '081234567804',
        'address': 'Perumahan Asri Blok C No. 15',
        'package_id': 4,
        'package_name': 'Paket 30 Mbps',
        'package_speed': '30 Mbps',
        'monthly_fee': 150000,
        'install_date': '2026-10-12',
        'start_date': '2026-10-12',
        'installation_fee': 0,
        'due_day': 12,
        'is_active': 1,
        'notes': 'Studio Desain Online',
        'bill_num': 'INV-202610-0004',
        'bill_status': 'Sebagian',
        'paid_amount': 75000,
        'has_payment': true,
        'receipt_num': 'KW-20261012-0003',
      },
      {
        'id': 5,
        'customer_code': 'CUST-0005',
        'name': 'Hendra Wijaya',
        'phone': '081234567805',
        'address': 'Ruko Niaga Jaya No. 5B',
        'package_id': 5,
        'package_name': 'Paket 50 Mbps',
        'package_speed': '50 Mbps',
        'monthly_fee': 185000,
        'install_date': '2026-09-15',
        'start_date': '2026-09-15',
        'installation_fee': 0,
        'due_day': 5,
        'is_active': 1,
        'notes': 'Kantor Notaris',
        'bill_num': 'INV-202610-0005',
        'bill_status': 'Terlambat',
        'paid_amount': 0,
        'has_payment': false,
        'receipt_num': '',
      },
    ];

    final nowStr = DateTime.now().toIso8601String();

    for (final c in demoCustomers) {
      // 1. Insert customer lokal
      await db.insert(
        DatabaseHelper.tableCustomers,
        {
          'id': c['id'],
          'customer_code': c['customer_code'],
          'name': c['name'],
          'phone': c['phone'],
          'address': c['address'],
          'package_id': c['package_id'],
          'package_name': c['package_name'],
          'package_speed': c['package_speed'],
          'monthly_fee': c['monthly_fee'],
          'install_date': c['install_date'],
          'start_date': c['start_date'],
          'installation_fee': c['installation_fee'],
          'due_day': c['due_day'],
          'is_active': c['is_active'],
          'notes': c['notes'],
          'created_at': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 2. Insert bill lokal
      final int fee = c['monthly_fee'] as int;
      final int paid = c['paid_amount'] as int;
      final int remain = fee - paid;
      await db.insert(
        DatabaseHelper.tableBills,
        {
          'id': c['id'],
          'bill_number': c['bill_num'],
          'customer_id': c['id'],
          'customer_code': c['customer_code'],
          'customer_name': c['name'],
          'customer_phone': c['phone'],
          'package_id': c['package_id'],
          'package_name': c['package_name'],
          'period_month': 10,
          'period_year': 2026,
          'period_start': '2026-10-01',
          'period_end': '2026-10-31',
          'amount': fee,
          'paid_amount': paid,
          'remaining_amount': remain,
          'installation_fee': 0,
          'subscription_fee': fee,
          'additional_fee': 0,
          'discount': 0,
          'is_first_bill': 1,
          'due_date': '2026-10-${(c['due_day'] as int).toString().padLeft(2, '0')}',
          'status': c['bill_status'],
          'notes': 'Tagihan Bulan Oktober 2026',
          'created_at': nowStr,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // 3. Insert payment jika ada pembayaran
      if (c['has_payment'] == true) {
        await db.insert(
          DatabaseHelper.tablePayments,
          {
            'id': c['id'],
            'receipt_number': c['receipt_num'],
            'bill_id': c['id'],
            'bill_number': c['bill_num'],
            'customer_id': c['id'],
            'customer_code': c['customer_code'],
            'customer_name': c['name'],
            'payment_date': nowStr,
            'amount_paid': paid,
            'payment_method': 'Tunai',
            'notes': 'Pembayaran tagihan via admin',
            'is_cancelled': 0,
            'cancel_reason': '',
            'created_at': nowStr,
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    }

    // Segera unggah data demo ke Supabase Cloud jika terhubung
    if (_client != null && _isOnline) {
      await uploadLocalDataToSupabase();
    }
  }
}
