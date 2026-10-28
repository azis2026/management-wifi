import '../database/database_helper.dart';
import '../models/package_model.dart';

class PackageRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<PackageModel>> getPackages({bool activeOnly = false}) async {
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
    return await db.insert(DatabaseHelper.tablePackages, pkg.toMap());
  }

  Future<void> updatePackage(PackageModel pkg) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePackages,
      pkg.toMap(),
      where: 'id = ?',
      whereArgs: [pkg.id],
    );
  }

  Future<void> togglePackageStatus(int id, bool isActive) async {
    final db = await _dbHelper.database;
    await db.update(
      DatabaseHelper.tablePackages,
      {'is_active': isActive ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> deletePackage(int id) async {
    final db = await _dbHelper.database;
    return await db.delete(
      DatabaseHelper.tablePackages,
      where: 'id = ?',
      whereArgs: [id],
    );
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
