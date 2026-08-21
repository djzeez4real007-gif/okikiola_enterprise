import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/splash_screen.dart';
import 'services/auth_service.dart';
import 'widgets/app_shell.dart';

class OkikiolaApp extends StatefulWidget {
  const OkikiolaApp({super.key});

  @override
  State<OkikiolaApp> createState() => _OkikiolaAppState();
}

class _OkikiolaAppState extends State<OkikiolaApp> {
  /// false = still on cold-start splash
  bool splashDone = false;

  @override
  void initState() {
    super.initState();
    AuthService.authListenable.addListener(_onAuth);
  }

  @override
  void dispose() {
    AuthService.authListenable.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() => setState(() {});

  void _finishSplash() {
    if (!mounted) return;
    setState(() => splashDone = true);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Okikiola Enterprise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: ThemeMode.system,
      home: !splashDone
          ? SplashScreen(onFinished: _finishSplash)
          : (AuthService.isLoggedIn
              ? const AppShell()
              : const LoginScreen()),
    );
  }
}
