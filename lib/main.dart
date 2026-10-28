import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi_web/sqflite_ffi_web.dart';
import 'services/session_service.dart';
import 'services/supabase_service.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Aktifkan SQLite FFI di Web Browser via IndexedDB / WebAssembly
  if (kIsWeb) {
    databaseFactory = databaseFactoryFfiWeb;
  }

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Inisialisasi Supabase Cloud
  try {
    await SupabaseService.instance.initialize();
  } catch (e) {
    debugPrint('Supabase init error: $e');
  }

  // Inisialisasi sesi login
  try {
    await SessionService.instance.initialize();
  } catch (e) {
    debugPrint('Session initialization notice: $e');
  }

  runApp(const WiFiManagerApp());
}
