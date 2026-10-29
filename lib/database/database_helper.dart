import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'package:path/path.dart' as p;

class DatabaseHelper {
  static const String _databaseName = "wifi_manager.db";
  static const int _databaseVersion = 4;

  // Table names
  static const String tablePackages = "packages";
  static const String tableCustomers = "customers";
  static const String tableBills = "bills";
  static const String tablePayments = "payments";
  static const String tableSettings = "settings";

  // Singleton instance
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    if (kIsWeb) {
      databaseFactory = databaseFactoryFfiWeb;
      path = _databaseName;
    } else {
      final dbPath = await getDatabasesPath();
      path = p.join(dbPath, _databaseName);
    }

    final db = await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      onConfigure: _onConfigure,
    );

    // Self-healing migration: pastikan kolom custom_daily_price tersedia
    try {
      await db.execute('ALTER TABLE $tablePackages ADD COLUMN custom_daily_price INTEGER DEFAULT 0');
    } catch (_) {}

    // Pastikan paket master selalu ada di database SQLite lokal
    try {
      await ensureMasterPackages(db);
    } catch (_) {}

    return db;
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // 1. Add ktp_image_path to customers if not exists
      try {
        await db.execute('ALTER TABLE $tableCustomers ADD COLUMN ktp_image_path TEXT');
      } catch (_) {}

      try {
        await db.execute('DROP INDEX IF EXISTS idx_bill_cust_period');
      } catch (_) {}
    }

    if (oldVersion < 3) {
      // 1. Alter Customers Table
      try {
        await db.execute('ALTER TABLE $tableCustomers ADD COLUMN start_date TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableCustomers ADD COLUMN installation_fee INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableCustomers ADD COLUMN package_speed TEXT DEFAULT ""');
      } catch (_) {}

      // Backfill start_date = install_date for existing customers
      try {
        await db.execute('''
          UPDATE $tableCustomers 
          SET start_date = install_date 
          WHERE start_date IS NULL OR start_date = ''
        ''');
      } catch (_) {}

      // 2. Alter Bills Table
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN period_start TEXT DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN period_end TEXT DEFAULT ""');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN installation_fee INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN subscription_fee INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN additional_fee INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN discount INTEGER DEFAULT 0');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE $tableBills ADD COLUMN is_first_bill INTEGER DEFAULT 0');
      } catch (_) {}

      // 3. Ensure Master Packages exist as required by Section 2
      await ensureMasterPackages(db);
    }

    if (oldVersion < 4) {
      // 4. Alter Packages Table to add custom_daily_price
      try {
        await db.execute('ALTER TABLE $tablePackages ADD COLUMN custom_daily_price INTEGER DEFAULT 0');
      } catch (_) {}
    }
  }

  static Future<void> ensureMasterPackages(Database db) async {
    final now = DateTime.now().toIso8601String();
    final masterPackages = [
      {'name': 'Paket Hemat', 'speed': '6 Mbps', 'monthly_price': 60000, 'installation_fee': 0},
      {'name': 'Paket Hemat', 'speed': '11 Mbps', 'monthly_price': 85000, 'installation_fee': 0},
      {'name': 'Paket Keluar', 'speed': '20 Mbps', 'monthly_price': 111000, 'installation_fee': 0},
      {'name': 'Paket 30 Mbps', 'speed': '30 Mbps', 'monthly_price': 150000, 'installation_fee': 0},
      {'name': 'Paket 50 Mbps', 'speed': '50 Mbps', 'monthly_price': 185000, 'installation_fee': 0},
      {'name': 'Paket 100 Mbps', 'speed': '100 Mbps', 'monthly_price': 226000, 'installation_fee': 0},
    ];

    for (final p in masterPackages) {
      final existing = await db.rawQuery(
        'SELECT COUNT(*) as count FROM $tablePackages WHERE monthly_price = ? AND speed = ?',
        [p['monthly_price'], p['speed']],
      );
      final count = (existing.first['count'] as int?) ?? 0;
      if (count == 0) {
        await db.insert(tablePackages, {
          'name': p['name'],
          'speed': p['speed'],
          'monthly_price': p['monthly_price'],
          'installation_fee': p['installation_fee'],
          'is_active': 1,
          'created_at': now,
        });
      }
    }
  }

  Future<void> ensureMasterPackagesExist() async {
    final db = await database;
    await ensureMasterPackages(db);
  }

  Future<void> _onCreate(Database db, int version) async {
    // 1. Packages Table
    await db.execute('''
      CREATE TABLE $tablePackages (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        speed TEXT NOT NULL,
        monthly_price INTEGER NOT NULL,
        custom_daily_price INTEGER NOT NULL DEFAULT 0,
        installation_fee INTEGER NOT NULL DEFAULT 0,
        is_active INTEGER NOT NULL DEFAULT 1,
        created_at TEXT NOT NULL
      )
    ''');

    // 2. Customers Table
    await db.execute('''
      CREATE TABLE $tableCustomers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        customer_code TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        phone TEXT NOT NULL,
        address TEXT NOT NULL,
        package_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        package_speed TEXT DEFAULT '',
        monthly_fee INTEGER NOT NULL,
        install_date TEXT NOT NULL,
        start_date TEXT NOT NULL,
        installation_fee INTEGER NOT NULL DEFAULT 0,
        due_day INTEGER NOT NULL DEFAULT 10,
        is_active INTEGER NOT NULL DEFAULT 1,
        notes TEXT DEFAULT '',
        ktp_image_path TEXT,
        created_at TEXT NOT NULL
      )
    ''');

    // 3. Bills Table
    await db.execute('''
      CREATE TABLE $tableBills (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        bill_number TEXT NOT NULL UNIQUE,
        customer_id INTEGER NOT NULL,
        customer_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        customer_phone TEXT DEFAULT '',
        package_id INTEGER NOT NULL,
        package_name TEXT NOT NULL,
        period_month INTEGER NOT NULL,
        period_year INTEGER NOT NULL,
        period_start TEXT DEFAULT '',
        period_end TEXT DEFAULT '',
        amount INTEGER NOT NULL,
        paid_amount INTEGER NOT NULL DEFAULT 0,
        remaining_amount INTEGER NOT NULL,
        installation_fee INTEGER NOT NULL DEFAULT 0,
        subscription_fee INTEGER NOT NULL DEFAULT 0,
        additional_fee INTEGER NOT NULL DEFAULT 0,
        discount INTEGER NOT NULL DEFAULT 0,
        is_first_bill INTEGER NOT NULL DEFAULT 0,
        due_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'Belum Bayar',
        notes TEXT DEFAULT '',
        cancel_reason TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // 4. Payments Table
    await db.execute('''
      CREATE TABLE $tablePayments (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        receipt_number TEXT NOT NULL UNIQUE,
        bill_id INTEGER NOT NULL,
        bill_number TEXT NOT NULL,
        customer_id INTEGER NOT NULL,
        customer_code TEXT NOT NULL,
        customer_name TEXT NOT NULL,
        payment_date TEXT NOT NULL,
        amount_paid INTEGER NOT NULL,
        payment_method TEXT NOT NULL,
        notes TEXT DEFAULT '',
        is_cancelled INTEGER NOT NULL DEFAULT 0,
        cancel_reason TEXT DEFAULT '',
        created_at TEXT NOT NULL
      )
    ''');

    // 5. Settings Table
    await db.execute('''
      CREATE TABLE $tableSettings (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');

    // Seed default master packages (Section 2)
    await ensureMasterPackages(db);

    // Seed default settings
    await db.insert(tableSettings, {'key': 'business_name', 'value': 'WiFi Net Mandiri'});
    await db.insert(tableSettings, {'key': 'contact_phone', 'value': '0812-3456-7890'});
    await db.insert(tableSettings, {'key': 'address', 'value': 'Jl. Merdeka No. 10'});
    await db.insert(tableSettings, {
      'key': 'receipt_footer',
      'value': 'Terima kasih atas pembayaran Anda. Simpan bukti ini sebagai tanda lunas.'
    });
  }

  // Helper to generate customer code: CUST-0001, CUST-0002
  Future<String> generateCustomerCode() async {
    final db = await database;
    final result = await db.rawQuery('SELECT MAX(id) as max_id FROM $tableCustomers');
    final maxId = (result.first['max_id'] as int?) ?? 0;
    final nextId = maxId + 1;
    return 'CUST-${nextId.toString().padLeft(4, '0')}';
  }

  // Helper to generate bill number: INV-YYYYMM-0001
  Future<String> generateBillNumber(int month, int year) async {
    final db = await database;
    final prefix = 'INV-$year${month.toString().padLeft(2, '0')}';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tableBills WHERE bill_number LIKE ?',
      ['$prefix%'],
    );
    final count = (result.first['count'] as int?) ?? 0;
    final nextNum = count + 1;
    return '$prefix-${nextNum.toString().padLeft(4, '0')}';
  }

  // Helper to generate receipt number: KW-YYYYMMDD-0001
  Future<String> generateReceiptNumber() async {
    final db = await database;
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    final prefix = 'KW-$y$m$d';
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM $tablePayments WHERE receipt_number LIKE ?',
      ['$prefix%'],
    );
    final count = (result.first['count'] as int?) ?? 0;
    final nextNum = count + 1;
    return '$prefix-${nextNum.toString().padLeft(4, '0')}';
  }

  // ===================== EXPORT & IMPORT BACKUP =====================

  /// Exports entire database to a structured JSON string
  Future<String> exportBackupJson() async {
    final db = await database;

    final packagesData = await db.query(tablePackages);
    final customersData = await db.query(tableCustomers);
    final billsData = await db.query(tableBills);
    final paymentsData = await db.query(tablePayments);
    final settingsData = await db.query(tableSettings);

    final backupPayload = {
      'app': 'WiFi Manager',
      'version': _databaseVersion,
      'exported_at': DateTime.now().toIso8601String(),
      'data': {
        tablePackages: packagesData,
        tableCustomers: customersData,
        tableBills: billsData,
        tablePayments: paymentsData,
        tableSettings: settingsData,
      }
    };

    return const JsonEncoder.withIndent('  ').convert(backupPayload);
  }

  /// Validates and restores database from a JSON string atomically
  Future<bool> restoreFromBackupJson(String jsonString) async {
    Map<String, dynamic> decoded;
    try {
      decoded = json.decode(jsonString) as Map<String, dynamic>;
    } catch (_) {
      throw Exception('Format file tidak valid. Pastikan file merupakan cadangan resmi WiFi Manager.');
    }

    if (decoded['app'] != 'WiFi Manager') {
      throw Exception('File ini bukan file cadangan aplikasi WiFi Manager.');
    }

    final data = decoded['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw Exception('Data cadangan kosong atau rusak.');
    }

    final db = await database;

    await db.transaction((txn) async {
      await txn.delete(tablePayments);
      await txn.delete(tableBills);
      await txn.delete(tableCustomers);
      await txn.delete(tablePackages);
      await txn.delete(tableSettings);

      if (data[tablePackages] is List) {
        for (var row in data[tablePackages]) {
          await txn.insert(tablePackages, Map<String, dynamic>.from(row as Map));
        }
      }

      if (data[tableCustomers] is List) {
        for (var row in data[tableCustomers]) {
          await txn.insert(tableCustomers, Map<String, dynamic>.from(row as Map));
        }
      }

      if (data[tableBills] is List) {
        for (var row in data[tableBills]) {
          await txn.insert(tableBills, Map<String, dynamic>.from(row as Map));
        }
      }

      if (data[tablePayments] is List) {
        for (var row in data[tablePayments]) {
          await txn.insert(tablePayments, Map<String, dynamic>.from(row as Map));
        }
      }

      if (data[tableSettings] is List) {
        for (var row in data[tableSettings]) {
          await txn.insert(tableSettings, Map<String, dynamic>.from(row as Map));
        }
      }
    });

    return true;
  }

  /// Close database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
