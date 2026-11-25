import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiServices {
  static String get baseUrl {
    return 'http://103.151.63.86:8001';
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

  /// Email hanya diketahui jika user mendaftar lewat aplikasi (login JWT tidak mengirim email).
  static Future<String?> getSavedEmail() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('logged_email');
  }

  // FOTO PROFIL (disimpan lokal di perangkat, satu foto per username)
  static Future<Uint8List?> getProfilePhoto(String username) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('profile_photo_$username');
    if (raw == null || raw.isEmpty) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setProfilePhoto(String username, Uint8List? bytes) async {
    final prefs = await SharedPreferences.getInstance();
    if (bytes == null) {
      await prefs.remove('profile_photo_$username');
    } else {
      await prefs.setString('profile_photo_$username', base64Encode(bytes));
    }
  }

  /// Dianggap login selama masih ada token tersimpan (access atau refresh).
  /// Sesi hanya berakhir lewat tombol Keluar, atau jika refresh token ditolak server.
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final access = prefs.getString(_accessKey);
    final refresh = prefs.getString(_refreshKey);
    return (access != null && access.isNotEmpty) ||
        (refresh != null && refresh.isNotEmpty);
  }

  // PERPANJANG SESI OTOMATIS (refresh token)
  static Future<bool?>? _refreshInFlight;

  /// Tukar refresh token dengan access token baru.
  /// true  = berhasil, token baru sudah tersimpan
  /// false = refresh token ditolak/kedaluwarsa (sesi benar-benar berakhir)
  /// null  = gagal karena jaringan/server (JANGAN logout, coba lagi nanti)
  static Future<bool?> refreshSession() {
    return _refreshInFlight ??=
        _doRefresh().whenComplete(() => _refreshInFlight = null);
  }

  static Future<bool?> _doRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_refreshKey);
    if (refresh == null || refresh.isEmpty) return false;

    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/auth/token/refresh/'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'refresh': refresh}),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await prefs.setString(_accessKey, data['access'] as String);
        // Server memutar refresh token (ROTATE_REFRESH_TOKENS), simpan yang baru.
        if (data['refresh'] is String) {
          await prefs.setString(_refreshKey, data['refresh'] as String);
        }
        return true;
      }
      if (response.statusCode == 400 || response.statusCode == 401) {
        return false;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Dipanggil saat server membalas 401. Mengembalikan access token baru,
  /// atau melempar Exception bila sesi berakhir / tidak ada koneksi.
  static Future<String> _renewAfter401() async {
    final ok = await refreshSession();
    if (ok == true) {
      final token = await getAccessToken();
      if (token != null && token.isNotEmpty) return token;
    }
    if (ok == null) {
      throw Exception(
        'Tidak dapat terhubung ke backend. Periksa koneksi lalu coba lagi.',
      );
    }
    await logout();
    throw Exception('Sesi login habis. Silakan login ulang.');
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_accessKey);
    await prefs.remove(_refreshKey);
    await prefs.remove('logged_username');
    await prefs.remove('logged_email');
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
        await prefs.remove('logged_email'); // email lama (user sebelumnya) dibuang
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

  // REGISTER
  // Asumsi endpoint: POST /api/auth/register/ (sesuaikan dengan backend).
  // Setelah berhasil, langsung login agar token & username tersimpan.
  static Future<void> register({
    required String username,
    required String email,
    required String password,
    required String passwordConfirm,
  }) async {
    final uri = Uri.parse('$baseUrl/api/auth/register/');

    try {
      final response = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
              'password2': passwordConfirm,
              'password_confirm': passwordConfirm,
            }),
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200 || response.statusCode == 201) {
        await login(username, password);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('logged_email', email);
        return;
      }

      String? message;
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          message = (decoded['message'] ?? decoded['detail'])?.toString();
          if (message == null && decoded.isNotEmpty) {
            final first = decoded.values.first;
            message = first is List && first.isNotEmpty ? first.first.toString() : first.toString();
          }
        }
      } catch (_) {}

      if (response.statusCode == 400) {
        throw Exception(message ?? 'Data pendaftaran tidak valid.');
      }
      throw Exception(message ?? 'Pendaftaran gagal (${response.statusCode}).');
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

      // Request multipart tidak bisa dikirim ulang, jadi dibuat baru tiap percobaan.
      Future<http.Response> send(String accessToken) async {
        final request = http.MultipartRequest('POST', uri);
        request.headers['Authorization'] = 'Bearer $accessToken';
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
        return http.Response.fromStream(streamed);
      }

      var response = await send(token);

      if (response.statusCode == 401) {
        // Access token habis: perpanjang diam-diam lalu coba sekali lagi.
        response = await send(await _renewAfter401());
        if (response.statusCode == 401) {
          await logout();
          throw Exception('Sesi login habis. Silakan login ulang.');
        }
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

      Future<http.Response> fetch(String accessToken) => http.get(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $accessToken',
            },
          ).timeout(const Duration(seconds: 20));

      var response = await fetch(token);

      if (response.statusCode == 401) {
        // Access token habis: perpanjang diam-diam lalu coba sekali lagi.
        response = await fetch(await _renewAfter401());
        if (response.statusCode == 401) {
          await logout();
          throw Exception('Sesi login habis. Silakan login ulang.');
        }
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