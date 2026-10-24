
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
  static const Color gold = Color(0xFFC4A66A);

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
      final response =
          await ApiServices.diagnoseImage(widget.image);

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

    // Backend saat ini menggunakan ambang 0.70 = 70%.
    if (confidence <= 1) {
      confidence *= 100;
    }

    return confidence.clamp(0, 100).toDouble();
  }

  List<String> _recommendations() {
    final value = result?['rekomendasi'];

    if (value is List) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(RegExp(r'[\n\r]+'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }

    return [];
  }

  @override
  Widget build(BuildContext context) {
    final penyakit = result?['penyakit']?.toString();
    final confidence = _confidence();
    final recommendations = _recommendations();
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
            const SizedBox(height: 5),
            const Text(
              'Lihat hasil pemeriksaan daun jagung dan '
              'rekomendasi penanganannya.',
              style: TextStyle(
                color: ResultScreen.brown,
                fontSize: 13,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),

            _card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _Label('FOTO SAMPEL'),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      height: 220,
                      width: double.infinity,
                      color: const Color(0xFFE7EBDD),
                      child: FutureBuilder<Uint8List>(
                        future: widget.image.readAsBytes(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(
                              child: CircularProgressIndicator(
                                color: ResultScreen.green,
                              ),
                            );
                          }

                          if (snapshot.hasError ||
                              !snapshot.hasData) {
                            return const Center(
                              child: Text(
                                'Foto tidak dapat ditampilkan.',
                              ),
                            );
                          }

                          return Image.memory(
                            snapshot.data!,
                            fit: BoxFit.cover,
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
                        'Foto berhasil dipilih',
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
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ResultScreen.brown,
                                fontSize: 13,
                              ),
                            ),
                            SizedBox(height: 6),
                            Text(
                              'Mohon tunggu, proses dapat memerlukan waktu.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: ResultScreen.brown,
                                fontSize: 11,
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
                      'Deteksi belum berhasil',
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
                        fontSize: 23,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 9),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8EDDB),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Hasil dari backend CornGuard',
                        style: TextStyle(
                          color: ResultScreen.darkGreen,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 22),
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
                              value: confidence == null
                                  ? 0
                                  : confidence / 100,
                              minHeight: 8,
                              backgroundColor:
                                  const Color(0xFFE5E9DE),
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
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Hasil ini berasal dari model AI yang '
                      'dijalankan oleh backend. Periksa kondisi '
                      'tanaman secara langsung sebelum menentukan '
                      'tindakan penanganan.',
                      style: TextStyle(
                        color: ResultScreen.brown,
                        fontSize: 11,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 24),

            const _SectionTitle(
              eyebrow: 'INFORMASI',
              title: 'Tentang Hasil',
              icon: Icons.info_outline,
            ),
            const SizedBox(height: 10),
            _card(
              child: Text(
                isLoading
                    ? 'Informasi penyakit akan ditampilkan setelah '
                        'proses deteksi selesai.'
                    : errorMessage != null
                        ? 'Belum ada hasil diagnosis. Pastikan backend '
                            'dan model AI siap, kemudian coba kembali.'
                        : hasResult
                            ? 'Model mengidentifikasi sampel sebagai '
                                '$penyakit. Hasil model merupakan informasi '
                                'awal dan tidak menggantikan pemeriksaan '
                                'langsung oleh petugas pertanian.'
                            : 'Hasil diagnosis belum tersedia.',
                style: const TextStyle(
                  color: ResultScreen.brown,
                  fontSize: 13,
                  height: 1.7,
                ),
              ),
            ),

            const SizedBox(height: 24),

            const _SectionTitle(
              eyebrow: 'LANGKAH BERIKUTNYA',
              title: 'Rekomendasi Penanganan',
              icon: Icons.task_alt,
            ),
            const SizedBox(height: 12),

            if (isLoading)
              _card(
                child: const Text(
                  'Menunggu hasil diagnosis dari backend...',
                  style: TextStyle(
                    color: ResultScreen.brown,
                    fontSize: 12,
                  ),
                ),
              )
            else if (errorMessage != null)
              _card(
                child: const Text(
                  'Rekomendasi belum tersedia karena diagnosis '
                  'belum berhasil dilakukan.',
                  style: TextStyle(
                    color: ResultScreen.brown,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              )
            else if (recommendations.isEmpty)
              _card(
                child: const Text(
                  'Belum ada rekomendasi dari backend untuk hasil ini.',
                  style: TextStyle(
                    color: ResultScreen.brown,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
              )
            else
              ...recommendations.asMap().entries.map((entry) {
                return _Recommendation(
                  number: (entry.key + 1).toString().padLeft(2, '0'),
                  title: 'Rekomendasi ${entry.key + 1}',
                  description: entry.value,
                );
              }),

            const SizedBox(height: 8),
            const Text(
              'Gunakan hasil deteksi sebagai informasi awal. '
              'Pastikan diagnosis sebelum melakukan penanganan.',
              style: TextStyle(
                color: ResultScreen.brown,
                fontSize: 10,
                height: 1.5,
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

class _Recommendation extends StatelessWidget {
  final String number;
  final String title;
  final String description;

  const _Recommendation({
    required this.number,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE9E4D8)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EDDB),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Text(
              number,
              style: const TextStyle(
                color: ResultScreen.green,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: ResultScreen.darkGreen,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: const TextStyle(
                    color: ResultScreen.brown,
                    fontSize: 11,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
