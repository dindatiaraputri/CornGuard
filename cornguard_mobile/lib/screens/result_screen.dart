import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_services.dart';

class ResultScreen extends StatefulWidget {
  final XFile image;

  const ResultScreen({
    super.key,
    required this.image,
  });

  static const Color cream = Color(0xFFF7F3E9);
  static const Color green = Color(0xFF6B8E5A);
  static const Color darkGreen = Color(0xFF36543A);
  static const Color brown = Color(0xFF5A4635);

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  Map<String, dynamic>? result;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _runDiagnosis();
  }

  Future<void> _runDiagnosis() async {
    if (mounted) {
      setState(() {
        isLoading = true;
        errorMessage = null;
        result = null;
      });
    }

    try {
      final response = await ApiServices.diagnoseImage(widget.image);

      if (!mounted) return;

      setState(() {
        result = response;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        errorMessage = e.toString().replaceFirst('Exception: ', '');
        isLoading = false;
      });
    }
  }

  double? _confidence() {
    final value = result?['kepercayaan'];
    if (value is! num) return null;

    double confidence = value.toDouble();
    if (confidence <= 1) {
      confidence *= 100;
    }

    return confidence.clamp(0, 100).toDouble();
  }

  // Mengambil teks rekomendasi utuh tanpa memotongnya jadi "Rekomendasi 1-4"
  String _recommendationText() {
    final value = result?['rekomendasi'];
    if (value is String && value.trim().isNotEmpty) {
      return value.trim();
    }
    return 'Belum ada rekomendasi penanganan khusus untuk hasil ini.';
  }

  @override
  Widget build(BuildContext context) {
    final penyakit = result?['penyakit']?.toString();
    final confidence = _confidence();
    final recommendationText = _recommendationText();
    final hasResult = result != null && penyakit != null;

    return Scaffold(
      backgroundColor: ResultScreen.cream,
      appBar: AppBar(
        backgroundColor: ResultScreen.cream,
        foregroundColor: ResultScreen.brown,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Row(
          children: [
            Text('🌽 ', style: TextStyle(fontSize: 24)),
            Text(
              'CornGuard',
              style: TextStyle(
                color: ResultScreen.darkGreen,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
          children: [
            const Text(
              'HASIL PEMERIKSAAN',
              style: TextStyle(
                color: ResultScreen.green,
                fontSize: 11,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Hasil Deteksi',
              style: TextStyle(
                color: ResultScreen.darkGreen,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),

            // CARD FOTO SAMPEL (SUDAH DIPERBAIKI SUPAYA TIDAK GEPENG)
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('FOTO SAMPEL'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: double.infinity,
                      color: const Color(0xFFE7EBDD),
                      child: FutureBuilder<Uint8List>(
                        future: widget.image.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Padding(
                              padding: EdgeInsets.all(40.0),
                              child: Center(
                                child: CircularProgressIndicator(
                                  color: ResultScreen.green,
                                ),
                              ),
                            );
                          }

                          if (snapshot.hasError || !snapshot.hasData) {
                            return const Padding(
                              padding: EdgeInsets.all(20.0),
                              child: Center(
                                child: Text('Foto tidak dapat ditampilkan.'),
                              ),
                            );
                          }

                          // FIT CONTAIN AGAR GAMBAR PROPORSIONAL LENGKAP
                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.contain,
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle,
                        color: ResultScreen.green,
                        size: 17,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Foto berhasil dianalisis',
                        style: TextStyle(
                          color: ResultScreen.green,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 15),

            // CARD HASIL IDENTIFIKASI
            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('HASIL IDENTIFIKASI'),
                  const SizedBox(height: 14),
                  if (isLoading) ...[
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 22),
                        child: Column(
                          children: [
                            CircularProgressIndicator(
                              color: ResultScreen.green,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Sedang menganalisis daun jagung...',
                              style: TextStyle(
                                color: ResultScreen.brown,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else if (errorMessage != null) ...[
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 42,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Deteksi Belum Berhasil',
                      style: TextStyle(
                        color: ResultScreen.darkGreen,
                        fontSize: 19,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        color: ResultScreen.brown,
                        fontSize: 12,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _runDiagnosis,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Coba Deteksi Lagi'),
                    ),
                  ] else if (hasResult) ...[
                    Text(
                      penyakit,
                      style: const TextStyle(
                        color: ResultScreen.darkGreen,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tingkat keyakinan model',
                      style: TextStyle(
                        color: ResultScreen.brown,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: LinearProgressIndicator(
                              value: confidence == null ? 0 : confidence / 100,
                              minHeight: 10,
                              backgroundColor: const Color(0xFFE5E9DE),
                              color: ResultScreen.green,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          confidence == null
                              ? 'Tidak tersedia'
                              : '${confidence.toStringAsFixed(1)}%',
                          style: const TextStyle(
                            color: ResultScreen.green,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            const _SectionTitle(
              eyebrow: 'LANGKAH BERIKUTNYA',
              title: 'Rekomendasi Penanganan',
              icon: Icons.task_alt,
            ),
            const SizedBox(height: 12),

            // CARD REKOMENDASI UTUH (TIDAK DIPISAH 'REKOMENDASI 1-4')
            _card(
              child: Text(
                isLoading
                    ? 'Menunggu hasil diagnosis...'
                    : errorMessage != null
                        ? 'Rekomendasi belum tersedia.'
                        : recommendationText,
                style: const TextStyle(
                  color: ResultScreen.brown,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),

            const SizedBox(height: 22),

            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.refresh),
              label: const Text('Ganti Foto / Deteksi Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: ResultScreen.green,
                side: const BorderSide(color: ResultScreen.green),
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _card({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE9E4D8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A514638),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _Label extends StatelessWidget {
  final String text;
  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: ResultScreen.green,
        fontSize: 10,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.3,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String eyebrow;
  final String title;
  final IconData icon;

  const _SectionTitle({
    required this.eyebrow,
    required this.title,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                eyebrow,
                style: const TextStyle(
                  color: ResultScreen.green,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                title,
                style: const TextStyle(
                  color: ResultScreen.darkGreen,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFE8EDDB),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: ResultScreen.green),
        ),
      ],
    );
  }
}