
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/api_services.dart';

class DetectionRecommendationScreen extends StatefulWidget {
  final XFile image;

  const DetectionRecommendationScreen({
    super.key,
    required this.image,
  });

  @override
  State<DetectionRecommendationScreen> createState() =>
      _DetectionRecommendationScreenState();
}

class _DetectionRecommendationScreenState
    extends State<DetectionRecommendationScreen> {
  late Future<Map<String, dynamic>> _diagnosisFuture;

  static const Color backgroundColor = Color(0xFFF7F3E9);
  static const Color greenColor = Color(0xFF6B8E5A);
  static const Color brownColor = Color(0xFF5A4635);
  static const Color goldColor = Color(0xFFC4A66A);

  @override
  void initState() {
    super.initState();
    _diagnosisFuture = _loadDiagnosis();
  }

  Future<Map<String, dynamic>> _loadDiagnosis() {
    return ApiServices.diagnoseImage(widget.image);
  }

  void _retryDiagnosis() {
    setState(() {
      _diagnosisFuture = _loadDiagnosis();
    });
  }

  String _readText(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = 'Belum tersedia',
  }) {
    for (final key in keys) {
      final value = data[key];

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return fallback;
  }

  double? _readConfidence(Map<String, dynamic> data) {
    final value = data['confidence'] ??
        data['confidence_score'] ??
        data['akurasi'] ??
        data['tingkat_keyakinan'];

    if (value == null) return null;

    double? result;

    if (value is num) {
      result = value.toDouble();
    } else {
      result = double.tryParse(
        value.toString().replaceAll('%', '').trim(),
      );
    }

    if (result == null) return null;

    if (result > 1 && result <= 100) {
      result /= 100;
    }

    if (result < 0 || result > 1) return null;

    return result;
  }

  List<String> _readRecommendations(dynamic value) {
    if (value == null) return [];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is Map) {
      return value.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .toList();
    }

    final text = value.toString().trim();

    if (text.isEmpty) return [];

    return text
        .split(RegExp(r'\n|(?<=[.!?])\s+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
  }

  Widget _buildImagePreview() {
    return FutureBuilder<Uint8List>(
      future: widget.image.readAsBytes(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const SizedBox(
            height: 210,
            child: Center(
              child: Text('Gambar tidak dapat ditampilkan.'),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const SizedBox(
            height: 210,
            child: Center(
              child: CircularProgressIndicator(
                color: greenColor,
              ),
            ),
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.memory(
            snapshot.data!,
            height: 210,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: greenColor, size: 23),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: brownColor,
              fontSize: 17,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _infoCard({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: goldColor.withValues(alpha: 0.45),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitle(title, icon),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }

  Widget _buildRecommendations(List<String> recommendations) {
    if (recommendations.isEmpty) {
      return const Text(
        'Rekomendasi belum tersedia dari backend.',
        style: TextStyle(
          color: brownColor,
          height: 1.5,
        ),
      );
    }

    return Column(
      children: List.generate(
        recommendations.length,
        (index) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: backgroundColor,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(
                    color: greenColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  recommendations[index],
                  style: const TextStyle(
                    color: brownColor,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResult(Map<String, dynamic> data) {
    final disease = _readText(
      data,
      [
        'penyakit',
        'nama_penyakit',
        'disease',
        'class_name',
        'predicted_class',
        'prediksi',
        'label',
      ],
    );

    final information = _readText(
      data,
      [
        'informasi',
        'deskripsi',
        'description',
        'disease_info',
        'keterangan',
        'gejala',
      ],
    );

    final confidence = _readConfidence(data);

    final recommendations = _readRecommendations(
      data['rekomendasi'] ??
          data['recommendations'] ??
          data['saran'] ??
          data['tindakan'],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard(
          title: 'Hasil Deteksi',
          icon: Icons.biotech_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                disease,
                style: const TextStyle(
                  color: greenColor,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (confidence != null) ...[
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Tingkat keyakinan',
                      style: TextStyle(color: brownColor),
                    ),
                    Text(
                      '${(confidence * 100).toStringAsFixed(1)}%',
                      style: const TextStyle(
                        color: brownColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: LinearProgressIndicator(
                    value: confidence,
                    minHeight: 9,
                    backgroundColor: backgroundColor,
                    color: greenColor,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        _infoCard(
          title: 'Informasi Penyakit',
          icon: Icons.info_outline,
          child: Text(
            information,
            style: const TextStyle(
              color: brownColor,
              height: 1.6,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _infoCard(
          title: 'Rekomendasi Perawatan',
          icon: Icons.spa_outlined,
          child: _buildRecommendations(recommendations),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: goldColor.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.lightbulb_outline,
                color: brownColor,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Gunakan hasil deteksi sebagai panduan awal. '
                  'Periksa kondisi tanaman secara langsung '
                  'sebelum menentukan tindakan perawatan.',
                  style: TextStyle(
                    color: brownColor,
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Hasil Deteksi',
          style: TextStyle(
            color: brownColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: backgroundColor,
        foregroundColor: brownColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<Map<String, dynamic>>(
          future: _diagnosisFuture,
          builder: (context, snapshot) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Hasil Deteksi Penyakit Jagung',
                    style: TextStyle(
                      color: brownColor,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Berikut hasil analisis gambar daun jagung kamu.',
                    style: TextStyle(
                      color: brownColor,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _buildImagePreview(),
                  const SizedBox(height: 24),
                  if (snapshot.connectionState ==
                      ConnectionState.waiting) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(28),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: greenColor,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Sedang menganalisis gambar...',
                              style: TextStyle(color: brownColor),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (snapshot.hasError) ...[
                    _infoCard(
                      title: 'Deteksi Gagal',
                      icon: Icons.error_outline,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Gambar belum berhasil dianalisis. '
                            'Pastikan backend aktif dan alamat API '
                            'dapat dijangkau.\n\n'
                            '${snapshot.error}',
                            style: const TextStyle(
                              color: brownColor,
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _retryDiagnosis,
                              icon: const Icon(Icons.refresh),
                              label: const Text('Coba Lagi'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: greenColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(14),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else if (snapshot.hasData) ...[
                    _buildResult(snapshot.data!),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Kembali'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: brownColor,
                        side: const BorderSide(color: goldColor),
                        padding: const EdgeInsets.all(15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
