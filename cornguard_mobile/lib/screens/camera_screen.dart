
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

  // Aturan foto yang diterima aplikasi.
  static const List<String> _allowedExtensions = ['jpg', 'jpeg', 'png'];
  static const int _maxFileBytes = 10 * 1024 * 1024; // 10 MB, sama dengan backend
  static const String _formatHint = 'Format JPG, JPEG, atau PNG • Maks. 10 MB';

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
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (!mounted) return;

      if (image != null) {
        final bytes = await image.readAsBytes();

        if (!mounted) return;

        if (!_isAllowedFormat(image)) {
          _showMessage('Format foto tidak didukung. Gunakan JPG, JPEG, atau PNG.');
          return;
        }

        if (bytes.length > _maxFileBytes) {
          _showMessage(
            'Ukuran foto ${_formatSize(bytes.length)} melebihi batas 10 MB. '
            'Pilih foto yang lebih kecil.',
          );
          return;
        }

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

  bool _isAllowedFormat(XFile file) {
    final name = file.name.toLowerCase();
    final mime = (file.mimeType ?? '').toLowerCase();
    final byExtension = _allowedExtensions.any((e) => name.endsWith('.$e'));
    final byMime = mime == 'image/jpeg' || mime == 'image/png';
    return byExtension || byMime;
  }

  String _formatSize(int bytes) {
    if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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
                          child: Column(
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
                              Padding(
                                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE8F3EC),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.info_outline,
                                        size: 18,
                                        color: Color(0xFF0F7A4D),
                                      ),
                                      SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          _formatHint,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F7A4D),
                                          ),
                                        ),
                                      ),
                                    ],
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

              if (_selectedImage != null && _selectedImageBytes != null) ...[
                const SizedBox(height: 8),
                Text(
                  '${_selectedImage!.name} • ${_formatSize(_selectedImageBytes!.length)}',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],

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
