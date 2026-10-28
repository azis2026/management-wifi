class AppConfig {
  /// Base URL backend API.
  /// 1. Jika HP Fisik terhubung ke Wi-Fi yang sama dengan laptop:
  ///    Gunakan IP lokal Wi-Fi laptop: http://192.168.1.13:4000/api
  static const String lanBaseUrl = 'http://192.168.1.13:4000/api';

  /// 2. Jika HP Fisik terhubung kabel USB via adb reverse tcp:4000 tcp:4000:
  static const String usbBaseUrl = 'http://127.0.0.1:4000/api';

  /// 3. Jika di Android Emulator:
  static const String emulatorBaseUrl = 'http://10.0.2.2:4000/api';

  /// 4. Domain cloud jika sudah live (Suga App):
  static const String productionBaseUrl = 'https://4f0e205pa8p8-production-uxq725n6.us-central1.suga.run/api';

  /// Default untuk HP (Otomatis gunakan IP LAN laptop agar bisa diakses HP tanpa kabel)
  static String baseUrl = lanBaseUrl;
}
