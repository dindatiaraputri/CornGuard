// main.dart sederhana
import 'package:flutter/material.dart';
import 'package:cornguard_mobile/screens/login_screen.dart';
import 'package:cornguard_mobile/screens/home_screen.dart';
import 'package:cornguard_mobile/screens/camera_screen.dart';
import 'package:cornguard_mobile/screens/history_screen.dart';
void main() {
  runApp(const CornGuardApp());
}

class CornGuardApp extends StatelessWidget {
  const CornGuardApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CornGuard',
      theme: ThemeData(primarySwatch: Colors.green),
      // Halaman pertama yang muncul saat aplikasi dibuka
      initialRoute: '/login',
      // Daftar alamat/pintu ke halaman lain
      routes: {
        '/login': (context) => const LoginScreen(),
        '/home': (context) => const HomeScreen(),
        '/camera': (context) => const CameraScreen(),
        '/history': (context) => const HistoryScreen(),
      },
    );
  }
}