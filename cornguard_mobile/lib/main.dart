import 'package:flutter/material.dart';
import 'package:cornguard_mobile/screens/login_screen.dart';
import 'package:cornguard_mobile/screens/register_screen.dart';
import 'package:cornguard_mobile/screens/home_screen.dart';
import 'package:cornguard_mobile/screens/camera_screen.dart';
import 'package:cornguard_mobile/screens/history_screen.dart';
import 'package:cornguard_mobile/services/api_services.dart';
import 'package:cornguard_mobile/theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Cek apakah token JWT tersimpan di SharedPreferences
  final bool loggedIn = await ApiServices.isLoggedIn();

  runApp(MyApp(isLoggedIn: loggedIn));
}

class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  const MyApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'CornGuard',
      // Tema global: font Inter, huruf besar & tebal, tombol besar
      theme: AppTheme.light,
      // Hormati ukuran font sistem, tapi batasi agar layout tidak pecah
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 1.0,
        maxScaleFactor: 1.3,
        child: child!,
      ),
      // Jika token ada langsung ke Home, jika tidak ada ke Login
      home: isLoggedIn ? const HomeScreen() : const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}