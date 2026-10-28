import 'package:dio/dio.dart';
import '../models/admin_model.dart';
import 'api_service.dart';

class AuthResponse {
  final bool success;
  final String message;
  final String? token;
  final AdminModel? admin;

  AuthResponse({
    required this.success,
    required this.message,
    this.token,
    this.admin,
  });
}

class AuthService {
  static final AuthService instance = AuthService._internal();
  AuthService._internal();

  /// Login via REST API Backend (POST /api/auth/login)
  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    try {
      final response = await ApiService.instance.dio.post(
        '/auth/login',
        data: {
          'email': email.trim(),
          'password': password,
        },
      );

      final data = response.data as Map<String, dynamic>;
      final bool success = data['success'] == true;
      final String message = data['message']?.toString() ?? 'Login berhasil';

      if (success && data['token'] != null) {
        final token = data['token'].toString();
        await ApiService.instance.saveToken(token);

        AdminModel? admin;
        if (data['admin'] != null) {
          final adminJson = data['admin'] as Map<String, dynamic>;
          admin = AdminModel(
            id: adminJson['id']?.toString() ?? '',
            name: adminJson['name']?.toString() ?? 'Admin',
            email: adminJson['email']?.toString() ?? email,
            role: adminJson['role']?.toString() ?? 'Super Admin',
            phone: adminJson['phone']?.toString() ?? '',
            createdAt: adminJson['created_at']?.toString() ?? DateTime.now().toIso8601String(),
          );
        }

        return AuthResponse(
          success: true,
          message: message,
          token: token,
          admin: admin,
        );
      } else {
        return AuthResponse(
          success: false,
          message: message,
        );
      }
    } on DioException catch (e) {
      String errorMessage = 'Koneksi ke backend gagal';
      if (e.response?.data != null && e.response?.data is Map) {
        final resData = e.response!.data as Map;
        errorMessage = resData['message']?.toString() ?? errorMessage;
      } else if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage = 'Waktu koneksi habis. Pastikan backend aktif.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage = 'Tidak dapat menghubungi server backend di ${ApiService.instance.dio.options.baseUrl}.\nPastikan backend menyala & port forward / Wi-Fi terhubung.';
      }
      return AuthResponse(
        success: false,
        message: errorMessage,
      );
    } catch (e) {
      return AuthResponse(
        success: false,
        message: 'Terjadi kesalahan: $e',
      );
    }
  }

  /// Get Current Admin Profile via Backend API (GET /api/auth/me)
  Future<AdminModel?> getProfile() async {
    try {
      final response = await ApiService.instance.dio.get('/auth/me');
      if (response.data != null && response.data['success'] == true) {
        final adminJson = response.data['admin'] as Map<String, dynamic>;
        return AdminModel(
          id: adminJson['id']?.toString() ?? '',
          name: adminJson['name']?.toString() ?? 'Admin',
          email: adminJson['email']?.toString() ?? '',
          role: adminJson['role']?.toString() ?? 'Admin',
          phone: adminJson['phone']?.toString() ?? '',
          createdAt: adminJson['created_at']?.toString() ?? DateTime.now().toIso8601String(),
        );
      }
    } catch (_) {}
    return null;
  }

  /// Logout
  Future<void> logout() async {
    await ApiService.instance.clearToken();
  }
}
