import 'dart:typed_data';

import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';

/// Layar untuk mengatur posisi dan zoom foto profil.
/// Mengembalikan foto persegi hasil crop (Uint8List) lewat Navigator.pop,
/// atau null jika pengguna membatalkan.
class CropPhotoScreen extends StatefulWidget {
  final Uint8List image;

  const CropPhotoScreen({super.key, required this.image});

  @override
  State<CropPhotoScreen> createState() => _CropPhotoScreenState();
}

class _CropPhotoScreenState extends State<CropPhotoScreen> {
  final CropController _controller = CropController();
  bool _cropping = false;

  void _onCropped(CropResult result) {
    if (!mounted) return;
    switch (result) {
      case CropSuccess(:final croppedImage):
        Navigator.pop(context, croppedImage);
      case CropFailure():
        setState(() => _cropping = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gagal memotong foto. Coba pilih foto lain.'),
          ),
        );
    }
  }

  void _apply() {
    if (_cropping) return;
    setState(() => _cropping = true);
    _controller.crop();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF0F7A4D);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Atur foto profil'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Crop(
                image: widget.image,
                controller: _controller,
                onCropped: _onCropped,
                aspectRatio: 1,
                withCircleUi: true,
                // Lingkaran tetap di tengah, foto yang digeser dan di-zoom.
                interactive: true,
                fixCropRect: true,
                initialRectBuilder: InitialRectBuilder.withSizeAndRatio(
                  size: 0.85,
                  aspectRatio: 1,
                ),
                baseColor: Colors.black,
                maskColor: Colors.black.withAlpha(150),
                progressIndicator: const CircularProgressIndicator(
                  color: Colors.white,
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: Text(
                'Geser dan cubit (atau scroll di web) untuk mengatur posisi foto.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _cropping ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Batal'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: _cropping ? null : _apply,
                      style: FilledButton.styleFrom(
                        backgroundColor: green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _cropping
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Gunakan foto'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
