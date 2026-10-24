import 'package:flutter/material.dart';
import 'package:cornguard_mobile/models/disease_info.dart';
import 'package:cornguard_mobile/services/api_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _latestDiagnosis;
  bool _loadingDiagnosis = true;

  @override
  void initState() {
    super.initState();
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

void _showProfileDialog(BuildContext context) async {
  // Ambil username yang sedang login
  final currentUsername = await ApiServices.getSavedUsername();
  if (!context.mounted) return;

  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Row(
        children: [
          Icon(Icons.account_circle, color: Color(0xFF0F7A4D), size: 28),
          SizedBox(width: 10),
          Text('Profil Pengguna', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Nama Pengguna', style: TextStyle(fontSize: 11, color: Colors.grey)),
          Text(
            currentUsername, // <-- SUDAH DINAMIS SESUAI USER YANG LOGIN!
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          const Text('Peran / Role', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const Text('Pengguna Terverifikasi', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 12),
          const Text('Status Akses', style: TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4EA),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text('JWT Authenticated', style: TextStyle(color: Color(0xFF0F7A4D), fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Tutup', style: TextStyle(color: Color(0xFF0F7A4D))),
        ),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
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
                              await ApiServices.logout();
                              if (!context.mounted) return;
                              Navigator.pushNamedAndRemoveUntil(
                                context,
                                '/login',
                                (route) => false,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem<String>(
                              enabled: false,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: const [
                                  Text(
                                    'Petani Jagung',
                                    style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                                  ),
                                  Text(
                                    'petani1@cornguard.id',
                                    style: TextStyle(fontSize: 11, color: Colors.grey),
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
                          child: const CircleAvatar(
                            backgroundColor: Color(0xFFE2E8F0),
                            child: Text('BP', style: TextStyle(color: Color(0xFF0F7A4D), fontWeight: FontWeight.bold)),
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

    final String label = _latestDiagnosis!['label']?.toString() ?? 'Unknown';
    final info = DiseaseInfo.of(label);
    
    double confidence = 0.0;
    if (_latestDiagnosis!['confidence'] is num) {
      confidence = (_latestDiagnosis!['confidence'] as num).toDouble();
      if (confidence <= 1) confidence *= 100;
    }

    final String dateStr = _latestDiagnosis!['created_at']?.toString() ?? '-';

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