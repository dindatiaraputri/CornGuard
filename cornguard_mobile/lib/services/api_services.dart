import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServices {
  static String get baseUrl {
    if (kIsWeb) return 'http://127.0.0.1:8000';
    if (defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://127.0.0.1:8000';
  }

  static const String _accessKey = 'access_token';
  static const String _refreshKey = 'refresh_token';

  // TOKEN & USER SESSION
  static Future<String?> getAccessToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_accessKey);
  }

  static Future<String> getSavedUsername() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('logged_username') ?? 'Pengguna';
}

  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
  }

  // LOGIN (JWT)
  static Future<void> login(String username, String password) async {
    final uri = Uri.parse('$baseUrl/api/auth/token/');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': username, 'password': password}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_accessKey, data['access'] as String);
        await prefs.setString(_refreshKey, data['refresh'] as String);
//   Simpan username ke memori HP
        await prefs.setString('logged_username', username);
        return;
      }

      if (response.statusCode == 400 || response.statusCode == 401) {
        throw Exception('Username atau password salah.');
      }

      throw Exception('Login gagal (${response.statusCode}).');
    } on TimeoutException {
      throw Exception('Waktu koneksi habis. Pastikan server berjalan.');
    } on http.ClientException {
      throw Exception(
        'Tidak dapat terhubung ke backend. Periksa koneksi dan pastikan server berjalan.',
      );
    }
  }

  // DIAGNOSIS FOTO
  static Future<Map<String, dynamic>> diagnoseImage(
    XFile imageFile,
  ) async {
    final uri = Uri.parse('$baseUrl/api/diagnose/');

    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Kamu belum login. Silakan login dulu.');
      }

      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('File foto kosong. Silakan pilih foto lain.');
      }

      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer $token';

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.name,
        ),
      );

      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );

      final response = await http.Response.fromStream(streamed);

      if (response.statusCode == 401) {
        await logout();
        throw Exception('Sesi login habis. Silakan login ulang.');
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode < 200 || response.statusCode >= 300) {
          throw Exception(
            'Server mengalami kesalahan (${response.statusCode}). Silakan coba lagi.',
          );
        }

        throw Exception('Respons backend tidak valid. Silakan coba lagi.');
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Format respons backend tidak sesuai.');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        return decoded;
      }

      final serverMessage = decoded['message']?.toString();

      if (response.statusCode == 400) {
        throw Exception(serverMessage ?? 'Foto atau permintaan tidak valid.');
      }

      if (response.statusCode == 403) {
        throw Exception(serverMessage ?? 'Akses ditolak oleh server.');
      }

      if (response.statusCode == 404) {
        throw Exception(
          'Endpoint diagnosis tidak ditemukan. Periksa konfigurasi backend.',
        );
      }

      if (response.statusCode >= 500) {
        throw Exception(
          'Server atau layanan AI sedang bermasalah. Silakan coba lagi nanti.',
        );
      }

      throw Exception(
        serverMessage?.isNotEmpty == true
            ? serverMessage
            : 'Diagnosis gagal (${response.statusCode}).',
      );
    } on TimeoutException {
      throw Exception(
        'Waktu koneksi habis. Backend terlalu lama merespons. Silakan coba lagi.',
      );
    } on http.ClientException {
      throw Exception(
        'Tidak dapat terhubung ke backend. Periksa koneksi dan pastikan server berjalan.',
      );
    } on FormatException {
      throw Exception('Data dari backend tidak dapat dibaca.');
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception('Terjadi kesalahan saat mengirim foto. Silakan coba lagi.');
    }
  }

  // RIWAYAT DIAGNOSIS (SubTask #72)
  static Future<List<dynamic>> getHistory() async {
    final uri = Uri.parse('$baseUrl/api/history/');

    try {
      final token = await getAccessToken();
      if (token == null || token.isEmpty) {
        throw Exception('Kamu belum login. Silakan login dulu.');
      }

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      if (response.statusCode == 401) {
        await logout();
        throw Exception('Sesi login habis. Silakan login ulang.');
      }

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['success'] == true) {
          return decoded['history'] as List<dynamic>;
        }
      }

      throw Exception('Gagal mengambil data riwayat.');
    } on TimeoutException {
      throw Exception('Waktu koneksi habis. Backend terlalu lama merespons.');
    } on http.ClientException {
      throw Exception('Tidak dapat terhubung ke backend.');
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Terjadi kesalahan saat mengambil riwayat.');
    }
  }
}