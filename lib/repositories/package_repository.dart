import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/package_model.dart';
import '../services/supabase_service.dart';

class PackageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<PackageModel>> getPackages({bool activeOnly = false}) async {
    // 1. Jika terhubung ke Supabase, prioritaskan atau sinkronkan data cloud
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        final query = SupabaseService.instance.client!.from('packages').select();
        final List<dynamic> cloudMaps = activeOnly
            ? await query.eq('is_active', true).order('monthly_price', ascending: true)
            : await query.order('monthly_price', ascending: true);

        if (cloudMaps.isNotEmpty) {
          // Cache ke SQLite lokal
          final db = await _dbHelper.database;
          for (final item in cloudMaps) {
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
          }
          return cloudMaps.map((m) => PackageModel.fromMap(m as Map<String, dynamic>)).toList();
        }
      } catch (_) {}
    }

    final db = await _dbHelper.database;
    final where = activeOnly ? 'is_active = 1' : null;
    final maps = await db.query(
      DatabaseHelper.tablePackages,
      where: where,
      orderBy: 'monthly_price ASC',
    );
    return maps.map((m) => PackageModel.fromMap(m)).toList();
  }

  Future<PackageModel?> getPackageById(int id) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tablePackages,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (maps.isNotEmpty) return PackageModel.fromMap(maps.first);
    return null;
  }

  Future<int> createPackage(PackageModel pkg) async {
    final db = await _dbHelper.database;
    final id = await db.insert(DatabaseHelper.tablePackages, pkg.toMap());
    
    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('packages').upsert({
          'id': id,
          'name': pkg.name,
          'speed': pkg.speed,
          'monthly_price': pkg.monthlyPrice,
          'custom_daily_price': pkg.customDailyPrice,
          'installation_fee': pkg.installationFee,
          'is_active': pkg.isActive,
        });
      } catch (_) {}
    }

    return id;
  }

  Future<void> updatePackage(PackageModel pkg) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePackages,
      pkg.toMap(),
      where: 'id = ?',
      whereArgs: [pkg.id],
    );

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null && pkg.id != null) {
      try {
        await SupabaseService.instance.client!.from('packages').update({
          'name': pkg.name,
          'speed': pkg.speed,
          'monthly_price': pkg.monthlyPrice,
          'custom_daily_price': pkg.customDailyPrice,
          'installation_fee': pkg.installationFee,
          'is_active': pkg.isActive,
        }).eq('id', pkg.id!);
      } catch (_) {}
    }
  }

  Future<void> togglePackageStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePackages,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('packages').update({
          'is_active': isActive,
        }).eq('id', id);
      } catch (_) {}
    }
  }

  Future<int> deletePackage(int id) async {
    final db = await _dbHelper.database;
    final res = await db.delete(
      DatabaseHelper.tablePackages,
      where: 'id = ?',
      whereArgs: [id],
    );

    // Realtime Cloud Sync ke Supabase
    if (SupabaseService.instance.isOnline && SupabaseService.instance.client != null) {
      try {
        await SupabaseService.instance.client!.from('packages').delete().eq('id', id);
      } catch (_) {}
    }

    return res;
  }

  /// Cek berapa pelanggan yang masih terhubung dengan paket ini
  Future<int> getCustomerCountByPackage(int packageId) async {
    final db = await _dbHelper.database;
    final res = await db.rawQuery(
      'SELECT COUNT(*) as count FROM ${DatabaseHelper.tableCustomers} WHERE package_id = ?',
      [packageId],
    );
    if (res.isNotEmpty) {
      return (res.first['count'] as int?) ?? 0;
    }
    return 0;
  }

  /// Alias getPackages untuk kompatibilitas
  Future<List<PackageModel>> getAllPackages() => getPackages();
}
