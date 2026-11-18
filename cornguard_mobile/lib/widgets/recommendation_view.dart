import 'package:flutter/material.dart';
import 'package:cornguard_mobile/theme/app_theme.dart';

/// Menampilkan teks rekomendasi statis dari backend dengan susunan yang ramah dibaca:
/// langkah tindakan di atas (bernomor), keterangan tambahan dilipat di bawah.
/// Isi teks TIDAK diubah, hanya dipecah per label ("Penyebab:", "Ciri-ciri:", dst).
class RecommendationView extends StatelessWidget {
  final String text;
  final bool isHealthy;

  const RecommendationView({super.key, required this.text, this.isHealthy = false});

  @override
  Widget build(BuildContext context) {
    final sections = _parse(text);

    // Tanpa label yang dikenali -> tampilkan apa adanya, tetap besar & terbaca.
    if (sections.every((s) => s.label.isEmpty)) {
      return _box(
        child: SelectableText(
          text,
          style: const TextStyle(fontSize: 17, height: 1.6, color: AppColors.ink),
        ),
      );
    }

    final actions = sections.where((s) => _isAction(s.label)).toList();
    final infos = sections.where((s) => !_isAction(s.label)).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _banner(),
        const SizedBox(height: 14),
        for (final s in actions) ...[
          _actionCard(s),
          const SizedBox(height: 14),
        ],
        for (final s in infos) ...[
          _infoTile(s),
          const SizedBox(height: 10),
        ],
        const SizedBox(height: 4),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, size: 20, color: AppColors.inkSoft),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Ini panduan awal. Periksa juga kondisi tanaman langsung di lahan.',
                style: TextStyle(fontSize: 14, height: 1.45, color: AppColors.inkSoft),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ---------- bagian atas ----------
  Widget _banner() {
    final color = isHealthy ? AppColors.green : const Color(0xFF9A5B00);
    final bg = isHealthy ? AppColors.greenSoft : const Color(0xFFFEF3C7);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(isHealthy ? Icons.check_circle : Icons.priority_high_rounded, color: color, size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isHealthy ? 'Tanaman sehat. Cukup dirawat seperti biasa.' : 'Yang perlu segera dilakukan',
              style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: color, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionCard(_Section s) {
    final steps = _steps(s.body);
    final meta = _meta(s.label);
    return _box(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: const BoxDecoration(color: AppColors.greenSoft, shape: BoxShape.circle),
                child: Icon(meta.icon, color: AppColors.green, size: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(meta.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (var i = 0; i < steps.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: i == steps.length - 1 ? 0 : 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  steps.length > 1
                      ? Container(
                          width: 30,
                          height: 30,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(color: AppColors.green, shape: BoxShape.circle),
                          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        )
                      : const Icon(Icons.check_circle, color: AppColors.green, size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SelectableText(
                      steps[i],
                      style: const TextStyle(fontSize: 17, height: 1.55, fontWeight: FontWeight.w500, color: AppColors.ink),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------- bagian lipat ----------
  Widget _infoTile(_Section s) {
    final meta = _meta(s.label);
    final isSource = s.label.toLowerCase() == 'sumber';
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Theme(
          data: ThemeData(
            fontFamily: 'Inter',
            dividerColor: Colors.transparent,
            splashColor: AppColors.greenSoft,
          ),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: const Border(),
            collapsedShape: const Border(),
            leading: Icon(meta.icon, color: AppColors.green, size: 26),
            title: Text(meta.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppColors.ink)),
            expandedCrossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                s.body,
                style: TextStyle(fontSize: isSource ? 14 : 16, height: 1.6, color: isSource ? AppColors.inkSoft : AppColors.ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _box({required Widget child}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.line),
          boxShadow: const [BoxShadow(color: Color(0x0A14201A), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: child,
      );

  // ---------- parsing ----------
  static bool _isAction(String label) {
    final l = label.toLowerCase();
    return l.startsWith('penanganan') || l.startsWith('perawatan');
  }

  static _Meta _meta(String label) {
    final l = label.toLowerCase();
    if (l == 'penanganan kimia') return const _Meta('Obat dan semprot', Icons.science_outlined);
    if (l == 'penanganan') return const _Meta('Penanganan', Icons.check_circle_outline);
    if (l.startsWith('perawatan')) return const _Meta('Perawatan di lahan', Icons.agriculture);
    if (l == 'penyebab') return const _Meta('Penyebab penyakit', Icons.biotech);
    if (l.startsWith('ciri')) return const _Meta('Ciri-ciri di daun', Icons.visibility_outlined);
    if (l == 'sumber') return const _Meta('Sumber informasi', Icons.menu_book_outlined);
    return _Meta(label.isEmpty ? 'Keterangan' : label, Icons.notes);
  }

  static List<_Section> _parse(String text) {
    final out = <_Section>[];
    for (final block in text.split(RegExp(r'\n\s*\n'))) {
      final b = block.trim();
      if (b.isEmpty) continue;
      final i = b.indexOf(':');
      if (i > 0 && i <= 24 && !b.substring(0, i).contains('http')) {
        out.add(_Section(b.substring(0, i).trim(), b.substring(i + 1).trim()));
      } else {
        out.add(_Section('', b));
      }
    }
    return out;
  }

  /// Pecah paragraf jadi langkah per kalimat.
  static List<String> _steps(String body) {
    final parts = body.split(RegExp(r'\.\s+(?=[A-Z])'));
    return parts
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .map((p) => p.endsWith('.') ? p : '$p.')
        .toList();
  }
}

class _Section {
  final String label;
  final String body;
  const _Section(this.label, this.body);
}

class _Meta {
  final String title;
  final IconData icon;
  const _Meta(this.title, this.icon);
}
