import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cornguard_mobile/models/disease_info.dart';
import 'package:cornguard_mobile/models/history_entry.dart';
import 'package:cornguard_mobile/services/api_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _latestDiagnosis;
  bool _loadingDiagnosis = true;

  String _username = 'Pengguna';
  String? _email;
  Uint8List? _photo;

  String get _initials {
    final n = _username.trim();
    if (n.isEmpty) return '?';
    return n.substring(0, n.length >= 2 ? 2 : 1).toUpperCase();
  }

  Future<void> _loadProfile() async {
    final name = await ApiServices.getSavedUsername();
    final email = await ApiServices.getSavedEmail();
    final photo = await ApiServices.getProfilePhoto(name);
    if (!mounted) return;
    setState(() {
      _username = name;
      _email = email;
      _photo = photo;
    });
  }

  Future<void> _pickPhoto(void Function(void Function()) setDialog) async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 400,
      maxHeight: 400,
      imageQuality: 80,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    await ApiServices.setProfilePhoto(_username, bytes);
    if (!mounted) return;
    setState(() => _photo = bytes);
    setDialog(() {});
  }

  Future<void> _removePhoto(void Function(void Function()) setDialog) async {
    await ApiServices.setProfilePhoto(_username, null);
    if (!mounted) return;
    setState(() => _photo = null);
    setDialog(() {});
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _fetchLatestDiagnosis();
  }

  // Mengambil diagnosa paling baru dari backend API
  Future<void> _fetchLatestDiagnosis() async {
    try {
      final historyList = await ApiServices.getHistory();
      if (!mounted) return;

      setState(() {
        if (historyList.isNotEmpty) {
          _latestDiagnosis = historyList.first as Map<String, dynamic>;
        }
        _loadingDiagnosis = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingDiagnosis = false);
    }
  }

  Future<void> _logout(BuildContext context) async {
    await ApiServices.logout();
    if (!context.mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Widget _statRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
          ),
        ],
      ),
    );
  }

  /// Ringkasan dari riwayat diagnosis akun yang sedang login.
  Widget _statsSection(Future<List<dynamic>> future) {
    return FutureBuilder<List<dynamic>>(
      future: future,
      builder: (context, snap) {
        const pad = EdgeInsets.only(top: 16);
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
            padding: pad,
            child: Center(
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            ),
          );
        }
        if (snap.hasError || snap.data == null) {
          return const Padding(
            padding: pad,
            child: Text('Ringkasan tidak dapat dimuat.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }
        final items = snap.data!
            .map((e) => HistoryEntry.fromHistory(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (items.isEmpty) {
          return const Padding(
            padding: pad,
            child: Text('Belum ada diagnosis.', style: TextStyle(fontSize: 12, color: Colors.grey)),
          );
        }

        final sehat = items.where((e) => e.disease.toLowerCase() == 'healthy').length;
        final counts = <String, int>{};
        for (final e in items) {
          if (e.disease.toLowerCase() == 'healthy') continue;
          counts[e.disease] = (counts[e.disease] ?? 0) + 1;
        }
        String? paling;
        if (counts.isNotEmpty) {
          paling = counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
        }
        final terakhir = items.map((e) => e.createdAt).reduce((a, b) => b.isAfter(a) ? b : a);

        return Padding(
          padding: pad,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Divider(height: 1),
              _statRow('Total diagnosis', '${items.length}'),
              _statRow('Daun sehat', '$sehat'),
              _statRow('Daun terindikasi penyakit', '${items.length - sehat}'),
              if (paling != null) _statRow('Penyakit tersering', DiseaseInfo.of(paling).name),
              _statRow('Pemeriksaan terakhir', formatTanggalJam(terakhir)),
            ],
          ),
        );
      },
    );
  }

  void _showProfileDialog(BuildContext context) {
    final statsFuture = ApiServices.getHistory();
    showDialog(
      context: context,
      builder: (ctx) => Theme(
        data: _fontTheme(context),
        child: StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Profil Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Stack(
                  children: [
                    CircleAvatar(
                      radius: 44,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: _photo != null ? MemoryImage(_photo!) : null,
                      child: _photo == null
                          ? Text(_initials, style: const TextStyle(fontSize: 28, color: Color(0xFF0F7A4D), fontWeight: FontWeight.bold))
                          : null,
                    ),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: InkWell(
                        onTap: () => _pickPhoto(setDialog),
                        child: const CircleAvatar(
                          radius: 15,
                          backgroundColor: Color(0xFF0F7A4D),
                          child: Icon(Icons.camera_alt, size: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (_photo != null)
                Center(
                  child: TextButton(
                    onPressed: () => _removePhoto(setDialog),
                    child: const Text('Hapus foto', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Nama Pengguna', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text(_username, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
              if (_email != null) ...[
                const SizedBox(height: 12),
                const Text('Email', style: TextStyle(fontSize: 11, color: Colors.grey)),
                Text(_email!, style: const TextStyle(fontSize: 14)),
              ],
              _statsSection(statsFuture),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Color(0xFF0F7A4D))),
            ),
          ],
        ),
        ),
      ),
    );
  }

  /// Tema dengan font bergaya Helvetica (Inter, dibundel di assets/fonts) khusus halaman Beranda.
  ThemeData _fontTheme(BuildContext context) {
    final base = Theme.of(context);
    return base.copyWith(
      textTheme: base.textTheme.apply(fontFamily: 'Inter'),
      primaryTextTheme: base.primaryTextTheme.apply(fontFamily: 'Inter'),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _fontTheme(context),
      child: Builder(builder: _buildBody),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F0),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header App Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F7A4D),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.eco, color: Colors.white, size: 28),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'CornGuard',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                Text(
                                  'AI Crop Disease Detection',
                                  style: TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        
                        // Avatar + Menu Profil & Logout
                        PopupMenuButton<String>(
                          tooltip: 'Menu akun',
                          onSelected: (value) async {
                            if (value == 'profile') {
                              _showProfileDialog(context);
                            } else if (value == 'logout') {
                              await _logout(context);
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _username,
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  if (_email != null)
                                    Text(
                                      _email!,
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  Divider(),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'profile',
                              child: Row(
                                children: [
                                  Icon(Icons.person_outline, color: Color(0xFF0F7A4D), size: 20),
                                  SizedBox(width: 8),
                                  Text('Profil Saya'),
                                ],
                              ),
                            ),
                            const PopupMenuItem<String>(
                              value: 'logout',
                              child: Row(
                                children: [
                                  Icon(Icons.logout, color: Colors.red, size: 20),
                                  SizedBox(width: 8),
                                  Text('Keluar', style: TextStyle(color: Colors.red)),
                                ],
                              ),
                            ),
                          ],
                          child: CircleAvatar(
                            backgroundColor: const Color(0xFFE2E8F0),
                            backgroundImage: _photo != null ? MemoryImage(_photo!) : null,
                            child: _photo == null
                                ? Text(_initials, style: const TextStyle(color: Color(0xFF0F7A4D), fontWeight: FontWeight.bold))
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Banner Card Hero
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(20),
                        image: const DecorationImage(
                          image: AssetImage('assets/images/banner_bg.jpeg'),
                          fit: BoxFit.cover,
                          opacity: 0.3,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'TUMBUH SEHAT, PANEN HEBAT',
                            style: TextStyle(color: Color(0xFFFACC15), fontWeight: FontWeight.bold, fontSize: 11),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Kenali gejalanya.\nJaga panennya.',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.2),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Deteksi dini penyakit daun jagung,\nlangsung dari foto.',
                            style: TextStyle(color: Colors.white70, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Section Diagnosis Terakhir
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Diagnosis terakhir',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                        ),
                        GestureDetector(
                          onTap: () => Navigator.pushNamed(context, '/history'),
                          child: const Text('Lihat semua', style: TextStyle(color: Color(0xFF0F7A4D), fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Card Diagnosa Terakhir dari Backend
                    _buildLatestDiagnosisCard(),

                    const SizedBox(height: 20),

                    // Box Tips Foto
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF9C3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: const [
                              Icon(Icons.lightbulb_outline, color: Color(0xFF854D0E)),
                              SizedBox(width: 8),
                              Text('Foto tepat, hasil lebih akurat', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF854D0E))),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: const [
                              _TipItem(icon: Icons.center_focus_strong, label: 'Jarak dekat'),
                              _TipItem(icon: Icons.wb_sunny_outlined, label: 'Cahaya cukup'),
                              _TipItem(icon: Icons.crop_free, label: 'Fokus gejala'),
                            ],
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol Utama Diagnosis
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0F7A4D),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        onPressed: () {
                          Navigator.pushNamed(context, '/camera').then((_) => _fetchLatestDiagnosis());
                        },
                        icon: const Icon(Icons.camera_alt_outlined, color: Colors.white),
                        label: const Text('Mulai Diagnosis', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Center(
                      child: Text('Ambil foto atau unggah dari galeri', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: (i) {
          if (i == 1) Navigator.pushNamed(context, '/camera').then((_) => _fetchLatestDiagnosis());
          if (i == 2) Navigator.pushNamed(context, '/history').then((_) => _fetchLatestDiagnosis());
        },
        selectedItemColor: const Color(0xFF0F7A4D),
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'Beranda'),
          BottomNavigationBarItem(icon: Icon(Icons.center_focus_weak), label: 'Diagnosis'),
          BottomNavigationBarItem(icon: Icon(Icons.history), label: 'Riwayat'),
        ],
      ),
    );
  }

  Widget _buildLatestDiagnosisCard() {
    if (_loadingDiagnosis) {
      return Container(
        height: 90,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Color(0xFF0F7A4D)),
        ),
      );
    }

    if (_latestDiagnosis == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Text(
          'Belum ada riwayat diagnosa.',
          style: TextStyle(color: Colors.grey, fontSize: 13),
        ),
      );
    }

    final entry = HistoryEntry.fromHistory(_latestDiagnosis!);
    final info = DiseaseInfo.of(entry.disease);
    final double confidence = entry.confidence * 100;
    final String dateStr = formatTanggalJam(entry.createdAt);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(info.icon, color: info.color, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(dateStr, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Text(info.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE6F4EA),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '✓ Kepercayaan: ${confidence.toStringAsFixed(1)}%',
                    style: const TextStyle(color: Color(0xFF0F7A4D), fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _TipItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TipItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: const Color(0xFF854D0E), size: 20),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF854D0E))),
      ],
    );
  }
}