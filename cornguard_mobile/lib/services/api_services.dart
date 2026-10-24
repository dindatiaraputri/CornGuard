
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
      final bytes = await imageFile.readAsBytes();
      final request = http.MultipartRequest('POST', uri);

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
      final decoded = jsonDecode(response.body);

      if (decoded is! Map<String, dynamic>) {
        throw Exception('Respons backend tidak valid.');
      }

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          decoded['success'] == true) {
        return decoded;
      }

      throw Exception(
        decoded['message']?.toString() ??
            'Diagnosis gagal (${response.statusCode}).',
      );
    } catch (e) {
      if (e is Exception) rethrow;
      throw Exception('Gagal mengirim foto: $e');
    }
  }
}
