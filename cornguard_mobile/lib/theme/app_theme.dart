import 'package:flutter/material.dart';

/// Warna & tema global CornGuard.
/// Prinsip: kontras tinggi, huruf besar & tebal, tombol besar (mudah ditekan petani).
class AppColors {
  static const green = Color(0xFF0F7A4D);
  static const greenDark = Color(0xFF064E3B);
  static const greenSoft = Color(0xFFE6F4EA);
  static const gold = Color(0xFFFACC15);
  static const background = Color(0xFFF6F7F1);
  static const ink = Color(0xFF14201A); // teks utama (hampir hitam)
  static const inkSoft = Color(0xFF4B5563); // teks sekunder, tetap kontras
  static const line = Color(0xFFE3E7DC);
}

class AppTheme {
  static const TextTheme _text = TextTheme(
    headlineMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700, height: 1.2),
    titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
    titleMedium: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
    bodyLarge: TextStyle(fontSize: 18, fontWeight: FontWeight.w500, height: 1.5),
    bodyMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, height: 1.5),
    bodySmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4),
    labelLarge: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: Colors.white,
    );
    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: _text.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(58),
          shape: shape,
          elevation: 0,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: const Size.fromHeight(58),
          side: const BorderSide(color: AppColors.green, width: 1.6),
          shape: shape,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.green,
          minimumSize: const Size(48, 48),
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.greenSoft,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? AppColors.green : AppColors.inkSoft,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(size: 28, color: selected ? AppColors.green : AppColors.inkSoft);
        }),
      ),
    );
  }
}
