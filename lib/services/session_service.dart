import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/admin_model.dart';
import 'api_service.dart';
import 'auth_service.dart';

class SessionService extends ChangeNotifier {
  static final SessionService instance = SessionService._internal();
  SessionService._internal();

  AdminModel? _currentAdmin;
  bool _isLoggedIn = false;
  bool _isInitialized = false;

  AdminModel? get currentAdmin => _currentAdmin;
  bool get isLoggedIn => _isLoggedIn;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('jwt_token');
      final adminJsonStr = prefs.getString('active_admin_data');

      if (token != null && token.isNotEmpty) {
        ApiService.instance.setToken(token);
        _isLoggedIn = true;

        if (adminJsonStr != null && adminJsonStr.isNotEmpty) {
          try {
            final Map<String, dynamic> map = jsonDecode(adminJsonStr);
            _currentAdmin = AdminModel(
              id: map['id']?.toString() ?? '',
              name: map['name']?.toString() ?? 'Admin',
              email: map['email']?.toString() ?? '',
              role: map['role']?.toString() ?? 'Admin',
              phone: map['phone']?.toString() ?? '',
              createdAt: map['created_at']?.toString() ?? '',
            );
          } catch (_) {}
        }
      } else {
        _isLoggedIn = false;
        _currentAdmin = null;
      }
    } catch (e) {
      debugPrint('SessionService init error: $e');
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> setSession({
    required String token,
    required AdminModel admin,
    bool remember = true,
  }) async {
    _currentAdmin = admin;
    _isLoggedIn = true;
    ApiService.instance.setToken(token);

    if (remember) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('jwt_token', token);
      final adminMap = {
        'id': admin.id,
        'name': admin.name,
        'email': admin.email,
        'role': admin.role,
        'phone': admin.phone,
        'created_at': admin.createdAt,
      };
      await prefs.setString('active_admin_data', jsonEncode(adminMap));
    }
    notifyListeners();
  }

  Future<void> logout() async {
    _isLoggedIn = false;
    _currentAdmin = null;
    await AuthService.instance.logout();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('active_admin_data');
    notifyListeners();
  }
}

