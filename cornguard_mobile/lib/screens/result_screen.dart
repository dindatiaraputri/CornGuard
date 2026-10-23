
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class ResultScreen extends StatelessWidget {
  final XFile image;

  const ResultScreen({
    super.key,
    required this.image,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F0),
      appBar: AppBar(
        title: const Text('Konfirmasi Foto'),
        backgroundColor: const Color(0xFFF4F6F0),
        foregroundColor: const Color(0xFF1E293B),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Foto siap untuk diagnosis',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Pastikan foto daun jagung terlihat jelas.',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: FutureBuilder<Uint8List>(
                    future: image.readAsBytes(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF0F7A4D),
                          ),
                        );
                      }

                      if (snapshot.hasError || !snapshot.hasData) {
                        return const Center(
                          child: Text(
                            'Foto tidak dapat ditampilkan.',
                          ),
                        );
                      }

                      return Image.memory(
                        snapshot.data!,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return const Center(
                            child: Text(
                              'Foto tidak dapat ditampilkan.',
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Ganti foto'),
              ),
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: null,
                icon: const Icon(Icons.hourglass_empty),
                label: const Text(
                  'Diagnosis belum terhubung ke API',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
