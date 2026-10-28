import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiService {
  static final ApiService instance = ApiService._internal();

  late final Dio dio;
  String? _jwtToken;

  ApiService._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          // Update base URL secara dinamis jika diubah saat runtime
          options.baseUrl = AppConfig.baseUrl;

          // Kirim Supabase apikey header jika URL mengarah ke supabase
          options.headers['apikey'] = 'sb_publishable_ekeKJ6zh745NjEmMKRj5pA_0x0XRp8m';

          // Tempel Authorization Header jika token tersedia
          final token = _jwtToken ?? await getStoredToken();
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          } else {
            options.headers['Authorization'] = 'Bearer sb_publishable_ekeKJ6zh745NjEmMKRj5pA_0x0XRp8m';
          }
          return handler.next(options);
        },
        onError: (DioException error, handler) {
          // Tangani log error
          return handler.next(error);
        },
      ),
    );
  }

  void setToken(String? token) {
    _jwtToken = token;
  }

  Future<String?> getStoredToken() async {
    final prefs = await SharedPreferences.getInstance();
    _jwtToken = prefs.getString('auth_jwt_token');
    return _jwtToken;
  }

  Future<void> saveToken(String token) async {
    _jwtToken = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_jwt_token', token);
  }

  Future<void> clearToken() async {
    _jwtToken = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_jwt_token');
  }
}
