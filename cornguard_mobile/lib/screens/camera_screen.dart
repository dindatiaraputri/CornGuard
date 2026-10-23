
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'result_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  final ImagePicker _imagePicker = ImagePicker();

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;
  bool _isPickingImage = false;

  Future<void> _pickImage(ImageSource source) async {
    if (_isPickingImage) return;

    setState(() {
      _isPickingImage = true;
    });

    try {
      final XFile? image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
      );

      if (!mounted) return;

      if (image != null) {
        final bytes = await image.readAsBytes();

        if (!mounted) return;

        setState(() {
          _selectedImage = image;
          _selectedImageBytes = bytes;
        });
      }
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tidak dapat mengambil foto: $error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  void _continueToResult() {
    if (_selectedImage == null ||
        _selectedImageBytes == null ||
        _isPickingImage) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ResultScreen(
          image: _selectedImage!,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F0),
      appBar: AppBar(
        title: const Text('Diagnosis tanaman'),
        backgroundColor: const Color(0xFFF4F6F0),
        foregroundColor: const Color(0xFF1E293B),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: _selectedImageBytes == null
                      ? Container(
                          color: Colors.white,
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.image_outlined,
                                size: 64,
                                color: Color(0xFF0F7A4D),
                              ),
                              SizedBox(height: 12),
                              Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 20,
                                ),
                                child: Text(
                                  'Ambil foto daun jagung atau pilih dari galeri',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: Color(0xFF64748B),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                      : Image.memory(
                          _selectedImageBytes!,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return const Center(
                              child: Text(
                                'Foto tidak dapat ditampilkan',
                              ),
                            );
                          },
                        ),
                ),
              ),

              const SizedBox(height: 16),

              OutlinedButton.icon(
                onPressed: _isPickingImage
                    ? null
                    : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Pilih dari galeri'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0F7A4D),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                  side: const BorderSide(
                    color: Color(0xFF0F7A4D),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F7A4D),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
                onPressed: _isPickingImage
                    ? null
                    : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt_outlined),
                label: Text(
                  _selectedImage == null
                      ? 'Ambil foto'
                      : 'Ambil ulang',
                ),
              ),

              if (_isPickingImage) ...[
                const SizedBox(height: 16),
                const Center(
                  child: CircularProgressIndicator(
                    color: Color(0xFF0F7A4D),
                  ),
                ),
              ],

              const SizedBox(height: 12),

              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF0F7A4D),
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                  ),
                ),
                onPressed: _selectedImage == null ||
                        _selectedImageBytes == null ||
                        _isPickingImage
                    ? null
                    : _continueToResult,
                icon: const Icon(Icons.arrow_forward),
                label: const Text('Lanjutkan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
