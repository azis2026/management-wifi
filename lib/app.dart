import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'utils/app_theme.dart';
import 'services/session_service.dart';
import 'screens/main_navigation_screen.dart';
import 'screens/auth/admin_login_screen.dart';

class WiFiManagerApp extends StatelessWidget {
  const WiFiManagerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Wifi Management',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('id', 'ID'),
        Locale('en', 'US'),
      ],
      locale: const Locale('id', 'ID'),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: SessionService.instance,
      builder: (context, _) {
        if (SessionService.instance.isLoggedIn) {
          return const MainNavigationScreen();
        }
        return const AdminLoginScreen(isInitialGate: true);
      },
    );
  }
}
