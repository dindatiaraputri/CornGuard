
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

class ApiServices {
  static const String baseUrl = 'http://127.0.0.1:8000';

  static Future<Map<String, dynamic>> diagnoseImage(
    XFile imageFile,
  ) async {
    final uri = Uri.parse('$baseUrl/api/diagnose/');

    try {
      // Membaca foto yang dipilih pengguna.
      final bytes = await imageFile.readAsBytes();

      if (bytes.isEmpty) {
        throw Exception('File foto kosong. Silakan pilih foto lain.');
      }

      final request = http.MultipartRequest('POST', uri);

      request.files.add(
        http.MultipartFile.fromBytes(
          'image',
          bytes,
          filename: imageFile.name,
        ),
      );

      // Mengirim foto ke backend dengan batas waktu 120 detik.
      final streamed = await request.send().timeout(
        const Duration(seconds: 120),
      );

      final response = await http.Response.fromStream(streamed);

      // Periksa respons JSON dari backend.
      dynamic decoded;

      try {
        decoded = jsonDecode(response.body);
      } on FormatException {
        if (response.statusCode < 200 ||
            response.statusCode >= 300) {
          throw Exception(
            'Server mengalami kesalahan '
            '(${response.statusCode}). Silakan coba lagi.',
          );
        }

        throw Exception(
          'Respons backend tidak valid. Silakan coba lagi.',
        );
      }

      if (decoded is! Map<String, dynamic>) {
        throw Exception(
          'Format respons backend tidak sesuai.',
        );
      }

      // Diagnosis berhasil.
      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        return decoded;
      }

      // Menampilkan pesan dari backend jika tersedia.
      final serverMessage = decoded['message']?.toString();

      if (response.statusCode == 400) {
        throw Exception(
          serverMessage ?? 'Foto atau permintaan tidak valid.',
        );
      }

      if (response.statusCode == 401 ||
          response.statusCode == 403) {
        throw Exception(
          serverMessage ??
              'Akses ditolak oleh server. Periksa autentikasi.',
        );
      }

      if (response.statusCode == 404) {
        throw Exception(
          'Endpoint diagnosis tidak ditemukan. '
          'Periksa konfigurasi backend.',
        );
      }

      if (response.statusCode >= 500) {
        throw Exception(
          'Server atau layanan AI sedang bermasalah. '
          'Silakan coba lagi nanti.',
        );
      }

      throw Exception(
        serverMessage?.isNotEmpty == true
            ? serverMessage
            : 'Diagnosis gagal (${response.statusCode}).',
      );
    } on TimeoutException {
      throw Exception(
        'Waktu koneksi habis. Backend terlalu lama merespons. '
        'Silakan coba lagi.',
      );
    } on http.ClientException {
      throw Exception(
        'Tidak dapat terhubung ke backend. '
        'Periksa koneksi dan pastikan server berjalan.',
      );
    } on FormatException {
      throw Exception(
        'Data dari backend tidak dapat dibaca.',
      );
    } catch (e) {
      if (e is Exception) rethrow;

      throw Exception(
        'Terjadi kesalahan saat mengirim foto. '
        'Silakan coba lagi.',
      );
    }
  }
}