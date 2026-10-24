import 'package:flutter/material.dart';

/// Tampilan tiap kelas penyakit. Kunci = label dari model/API (field `penyakit`).
class DiseaseInfo {
  final String label;
  final String name;
  final Color color;
  final IconData icon;
  const DiseaseInfo(this.label, this.name, this.color, this.icon);

  static const healthy = DiseaseInfo('Healthy', 'Daun Sehat', Color(0xFF2E7D32), Icons.check_circle);
  static const rust = DiseaseInfo('Common_Rust', 'Karat Daun', Color(0xFFE65100), Icons.warning_amber_rounded);
  static const blight = DiseaseInfo('Blight', 'Hawar Daun', Color(0xFFB71C1C), Icons.warning_amber_rounded);
  static const grayLeafSpot = DiseaseInfo('Gray_Leaf_Spot', 'Bercak Daun Abu-abu', Color(0xFF546E7A), Icons.warning_amber_rounded);
  static const bulai = DiseaseInfo('Bulai', 'Bulai', Color(0xFF6A1B9A), Icons.warning_amber_rounded);

  /// Urutan tampil pada filter.
  static const all = [healthy, rust, blight, grayLeafSpot, bulai];

  static DiseaseInfo of(String label) {
    for (final d in all) {
      if (d.label.toLowerCase() == label.toLowerCase()) return d;
    }
    return DiseaseInfo(label, label, const Color(0xFF64748B), Icons.help_outline);
  }
}

const _bulan = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _dua(int n) => n.toString().padLeft(2, '0');

/// Contoh: 23 Okt 2026
String formatTanggal(DateTime d) => '${d.day} ${_bulan[d.month - 1]} ${d.year}';

/// Contoh: 23 Okt 2026 · 09.38 (sama dengan gaya di Beranda)
String formatTanggalJam(DateTime d) => '${formatTanggal(d)} · ${_dua(d.hour)}.${_dua(d.minute)}';

/// Contoh: 92,4%
String formatPersen(double v) => '${(v * 100).toStringAsFixed(1).replaceAll('.', ',')}%';
