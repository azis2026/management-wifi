import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/business_profile_model.dart';

class SettingsRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<String> getSetting(String key, {String defaultValue = ''}) async {
    final db = await _dbHelper.database;
    final maps = await db.query(
      DatabaseHelper.tableSettings,
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (maps.isNotEmpty) {
      return maps.first['value'] as String? ?? defaultValue;
    }
    return defaultValue;
  }

  Future<void> setSetting(String key, String value) async {
    final db = await _dbHelper.database;
    await db.insert(
      DatabaseHelper.tableSettings,
      {'key': key, 'value': value},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<BusinessProfileModel> getBusinessProfile() async {
    return BusinessProfileModel(
      businessName: await getSetting('business_name', defaultValue: BusinessProfileModel.defaults.businessName),
      contactPhone: await getSetting('contact_phone', defaultValue: BusinessProfileModel.defaults.contactPhone),
      address: await getSetting('address', defaultValue: BusinessProfileModel.defaults.address),
      receiptFooter: await getSetting('receipt_footer', defaultValue: BusinessProfileModel.defaults.receiptFooter),
      logoPath: await getSetting('logo_path', defaultValue: ''),
      signaturePath: await getSetting('signature_path', defaultValue: ''),
    );
  }

  Future<void> saveBusinessProfile(BusinessProfileModel profile) async {
    await setSetting('business_name', profile.businessName);
    await setSetting('contact_phone', profile.contactPhone);
    await setSetting('address', profile.address);
    await setSetting('receipt_footer', profile.receiptFooter);
    await setSetting('logo_path', profile.logoPath ?? '');
    await setSetting('signature_path', profile.signaturePath ?? '');
  }
}
