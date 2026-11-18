import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cornguard_mobile/models/disease_info.dart';
import 'package:cornguard_mobile/models/history_entry.dart';
import 'package:cornguard_mobile/services/api_services.dart';
import 'package:cornguard_mobile/theme/app_theme.dart';

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
      // Sesi berakhir (refresh token ditolak) -> kembali ke halaman login.
      if (!await ApiServices.isLoggedIn()) {
        if (!mounted) return;
        Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
        return;
      }
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
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
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
            child: Text('Ringkasan tidak dapat dimuat.', style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
          );
        }
        final items = snap.data!
            .map((e) => HistoryEntry.fromHistory(Map<String, dynamic>.from(e as Map)))
            .toList();
        if (items.isEmpty) {
          return const Padding(
            padding: pad,
            child: Text('Belum ada diagnosis.', style: TextStyle(fontSize: 14, color: AppColors.inkSoft)),
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
          title: const Text('Profil Pengguna', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
                    child: const Text('Hapus foto', style: TextStyle(color: Colors.red, fontSize: 14)),
                  ),
                ),
              const SizedBox(height: 12),
              const Text('Nama Pengguna', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
              Text(_username, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
              if (_email != null) ...[
                const SizedBox(height: 12),
                const Text('Email', style: TextStyle(fontSize: 13, color: AppColors.inkSoft)),
                Text(_email!, style: const TextStyle(fontSize: 16)),
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

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 11) return 'Selamat pagi';
    if (h < 15) return 'Selamat siang';
    if (h < 18) return 'Selamat sore';
    return 'Selamat malam';
  }

  void _openCamera() =>
      Navigator.pushNamed(context, '/camera').then((_) => _fetchLatestDiagnosis());

  void _openHistory() =>
      Navigator.pushNamed(context, '/history').then((_) => _fetchLatestDiagnosis());

  /// Tema global sudah memakai font Inter (lihat AppTheme), jadi cukup pakai tema yang ada.
  ThemeData _fontTheme(BuildContext context) => Theme.of(context);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.green,
          onRefresh: _fetchLatestDiagnosis,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context),
                const SizedBox(height: 20),
                _buildHero(),
                const SizedBox(height: 28),
                const Text('Cara kerja', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _StepCard(icon: Icons.photo_camera_outlined, title: 'Foto daun', caption: 'Ambil dari dekat')),
                    SizedBox(width: 10),
                    Expanded(child: _StepCard(icon: Icons.auto_awesome, title: 'Analisis AI', caption: 'Hasil dalam detik')),
                    SizedBox(width: 10),
                    Expanded(child: _StepCard(icon: Icons.task_alt, title: 'Penanganan', caption: 'Saran perawatan')),
                  ],
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Diagnosis terakhir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    TextButton(onPressed: _openHistory, child: const Text('Lihat semua')),
                  ],
                ),
                const SizedBox(height: 8),
                _buildLatestDiagnosisCard(),
                const SizedBox(height: 28),
                const Text('Penyakit yang dikenali', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final d in DiseaseInfo.all)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: d.color.withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(color: d.color.withValues(alpha: 0.35)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(d.icon, size: 20, color: d.color),
                            const SizedBox(width: 6),
                            Text(d.name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: d.color)),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 28),
                _buildPhotoTips(),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: 0,
        onDestinationSelected: (i) {
          if (i == 1) _openCamera();
          if (i == 2) _openHistory();
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Beranda'),
          NavigationDestination(icon: Icon(Icons.photo_camera_outlined), selectedIcon: Icon(Icons.photo_camera_rounded), label: 'Diagnosis'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Riwayat'),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.green, borderRadius: BorderRadius.circular(16)),
          child: const Icon(Icons.eco, color: Colors.white, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_greeting, style: const TextStyle(fontSize: 15, color: AppColors.inkSoft)),
              Text(
                _username,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
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
            const PopupMenuItem<String>(
              value: 'profile',
              height: 52,
              child: Row(
                children: [
                  Icon(Icons.person_outline, color: AppColors.green, size: 24),
                  SizedBox(width: 10),
                  Text('Profil Saya'),
                ],
              ),
            ),
            const PopupMenuItem<String>(
              value: 'logout',
              height: 52,
              child: Row(
                children: [
                  Icon(Icons.logout, color: Colors.red, size: 24),
                  SizedBox(width: 10),
                  Text('Keluar', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
          child: CircleAvatar(
            radius: 26,
            backgroundColor: AppColors.greenSoft,
            backgroundImage: _photo != null ? MemoryImage(_photo!) : null,
            child: _photo == null
                ? Text(_initials, style: const TextStyle(fontSize: 18, color: AppColors.green, fontWeight: FontWeight.w800))
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.greenDark,
        borderRadius: BorderRadius.circular(28),
        image: const DecorationImage(
          image: AssetImage('assets/images/banner_bg.jpeg'),
          fit: BoxFit.cover,
          colorFilter: ColorFilter.mode(Color(0xD9064E3B), BlendMode.srcOver),
        ),
        boxShadow: const [BoxShadow(color: Color(0x330F7A4D), blurRadius: 24, offset: Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'TUMBUH SEHAT, PANEN HEBAT',
            style: TextStyle(color: AppColors.gold, fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.2),
          ),
          const SizedBox(height: 10),
          const Text(
            'Kenali gejalanya.\nJaga panennya.',
            style: TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.15),
          ),
          const SizedBox(height: 12),
          const Text(
            'Foto daun jagung, dapatkan hasil dan cara penanganannya dalam hitungan detik.',
            style: TextStyle(color: Color(0xE6FFFFFF), fontSize: 16, height: 1.45),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _openCamera,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: AppColors.greenDark,
              minimumSize: const Size.fromHeight(62),
              textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 19, fontWeight: FontWeight.w800),
            ),
            icon: const Icon(Icons.photo_camera_rounded, size: 28),
            label: const Text('Mulai Diagnosis'),
          ),
          const SizedBox(height: 10),
          const Center(
            child: Text('Bisa dari kamera atau galeri', style: TextStyle(color: Color(0xCCFFFFFF), fontSize: 14)),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotoTips() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF9C3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline, color: Color(0xFF854D0E), size: 26),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Foto tepat, hasil lebih akurat',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Color(0xFF854D0E)),
                ),
              ),
            ],
          ),
          SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _TipItem(icon: Icons.center_focus_strong, label: 'Jarak dekat'),
              _TipItem(icon: Icons.wb_sunny_outlined, label: 'Cahaya cukup'),
              _TipItem(icon: Icons.crop_free, label: 'Fokus gejala'),
            ],
          ),
        ],
      ),
    );
  }

  BoxDecoration get _cardDecoration => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
        boxShadow: const [BoxShadow(color: Color(0x0A14201A), blurRadius: 12, offset: Offset(0, 4))],
      );

  Widget _buildLatestDiagnosisCard() {
    if (_loadingDiagnosis) {
      return Container(
        height: 100,
        decoration: _cardDecoration,
        child: const Center(child: CircularProgressIndicator(color: AppColors.green)),
      );
    }

    if (_latestDiagnosis == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: _cardDecoration,
        child: const Row(
          children: [
            Icon(Icons.eco_outlined, size: 36, color: AppColors.green),
            SizedBox(width: 14),
            Expanded(
              child: Text(
                'Belum ada riwayat diagnosis.\nMulai dengan memotret daun jagung.',
                style: TextStyle(fontSize: 16, height: 1.45, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      );
    }

    final entry = HistoryEntry.fromHistory(_latestDiagnosis!);
    final info = DiseaseInfo.of(entry.disease);
    final double confidence = entry.confidence * 100;
    final String dateStr = formatTanggalJam(entry.createdAt);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: _openHistory,
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: _cardDecoration,
          child: Row(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: info.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(info.icon, color: info.color, size: 34),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dateStr, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft)),
                    const SizedBox(height: 2),
                    Text(info.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: info.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Keyakinan ${confidence.toStringAsFixed(1)}%',
                        style: TextStyle(color: info.color, fontSize: 14, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 30, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String caption;
  const _StepCard({required this.icon, required this.title, required this.caption});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
            child: Icon(icon, color: AppColors.green, size: 28),
          ),
          const SizedBox(height: 10),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text(caption, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14, color: AppColors.inkSoft, height: 1.3)),
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
        Icon(icon, color: const Color(0xFF854D0E), size: 32),
        const SizedBox(height: 6),
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Color(0xFF854D0E))),
      ],
    );
  }
}
