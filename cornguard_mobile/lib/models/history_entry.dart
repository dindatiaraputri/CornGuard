/// Ubah nilai kepercayaan ke skala 0..1 (terima 0..1 atau 0..100).
double normalizeConfidence(dynamic v) {
  if (v is! num) return 0;
  final d = v.toDouble();
  return d > 1 ? d / 100 : d;
}

const _bulanEn = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
const _bulanId = ['jan', 'feb', 'mar', 'apr', 'mei', 'jun', 'jul', 'agu', 'sep', 'okt', 'nov', 'des'];

/// Terima ISO 8601 atau format seperti "24 Oct 2026, 23:54" / "24 Okt 2026 · 23.54".
DateTime parseTanggal(dynamic v) {
  final raw = v?.toString().trim() ?? '';
  final iso = DateTime.tryParse(raw);
  if (iso != null) return iso.toLocal();
  final m = RegExp(r'^(\d{1,2})\s+([A-Za-z]{3})[A-Za-z]*\s+(\d{4})(?:\D+(\d{1,2})[.:](\d{2}))?').firstMatch(raw);
  if (m != null) {
    final nama = m.group(2)!.toLowerCase();
    var bln = _bulanEn.indexOf(nama);
    if (bln < 0) bln = _bulanId.indexOf(nama);
    if (bln >= 0) {
      return DateTime(int.parse(m.group(3)!), bln + 1, int.parse(m.group(1)!),
          int.tryParse(m.group(4) ?? '') ?? 0, int.tryParse(m.group(5) ?? '') ?? 0);
    }
  }
  return DateTime.now();
}

/// Satu catatan hasil pemeriksaan.
class HistoryEntry {
  final String id;
  final String? thumbnail; // gambar kecil dalam base64 (PNG), boleh kosong
  final String disease; // label dari model, mis. Common_Rust
  final double confidence; // 0..1
  final Map<String, double> scores; // skor tiap kelas
  final DateTime createdAt;

  const HistoryEntry({
    required this.id,
    required this.disease,
    required this.confidence,
    required this.createdAt,
    this.thumbnail,
    this.scores = const {},
  });

  /// Bentuk dari respons `/api/history/` (kunci: id, label, confidence, created_at).
  /// Juga menerima kunci bergaya diagnose (penyakit, kepercayaan, skor_kelas) agar tahan perubahan backend.
  factory HistoryEntry.fromHistory(Map<String, dynamic> json) {
    final scores = <String, double>{};
    final raw = json['scores'] ?? json['skor_kelas'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) scores[k.toString()] = normalizeConfidence(v);
      });
    }
    return HistoryEntry(
      id: (json['id'] ?? DateTime.now().microsecondsSinceEpoch).toString(),
      disease: (json['label'] ?? json['penyakit'] ?? 'Unknown').toString(),
      confidence: normalizeConfidence(json['confidence'] ?? json['kepercayaan']),
      scores: scores,
      createdAt: parseTanggal(json['created_at'] ?? json['createdAt']),
    );
  }

  /// Bentuk dari respons `/api/diagnose/` (kolom: penyakit, kepercayaan, skor_kelas).
  factory HistoryEntry.fromDiagnose(Map<String, dynamic> json, {String? thumbnail}) {
    final scores = <String, double>{};
    final raw = json['skor_kelas'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) scores[k.toString()] = v.toDouble();
      });
    }
    final conf = json['kepercayaan'] ?? json['confidence'];
    return HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      thumbnail: thumbnail,
      disease: (json['penyakit'] ?? json['label'] ?? 'Unknown').toString(),
      confidence: normalizeConfidence(conf),
      scores: scores,
      createdAt: DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'thumbnail': thumbnail,
        'disease': disease,
        'confidence': confidence,
        'scores': scores,
        'createdAt': createdAt.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> j) {
    final scores = <String, double>{};
    final raw = j['scores'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) scores[k.toString()] = v.toDouble();
      });
    }
    return HistoryEntry(
      id: j['id'].toString(),
      thumbnail: j['thumbnail'] as String?,
      disease: (j['disease'] ?? 'Unknown').toString(),
      confidence: (j['confidence'] as num?)?.toDouble() ?? 0,
      scores: scores,
      createdAt: DateTime.tryParse(j['createdAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
