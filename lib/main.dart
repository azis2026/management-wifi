import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'services/session_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inisialisasi sesi login API murni (tanpa SQLite)
  try {
    await SessionService.instance.initialize();
  } catch (e) {
    debugPrint('Session initialization notice: $e');
  }

  runApp(const WiFiManagerApp());
}
