class AppConfig {
  /// Base URL backend API.
  /// Jika HP fisik terhubung via USB kabel dan menjalankan:
  ///   adb reverse tcp:4000 tcp:4000
  /// maka HP dapat langsung mengakses http://localhost:4000/api
  /// 
  /// Untuk fallback jaringan Wi-Fi LAN lokal komputer Anda:
  ///   http://192.168.1.13:4000/api
  static const String defaultBaseUrl = 'http://127.0.0.1:4000/api';
  static const String lanBaseUrl = 'http://192.168.1.13:4000/api';

  static String baseUrl = defaultBaseUrl;
}
