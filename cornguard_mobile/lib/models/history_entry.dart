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

  /// Bentuk dari respons `/api/diagnose/` (kolom: penyakit, kepercayaan, skor_kelas).
  factory HistoryEntry.fromDiagnose(Map<String, dynamic> json, {String? thumbnail}) {
    final scores = <String, double>{};
    final raw = json['skor_kelas'];
    if (raw is Map) {
      raw.forEach((k, v) {
        if (v is num) scores[k.toString()] = v.toDouble();
      });
    }
    final conf = json['kepercayaan'];
    return HistoryEntry(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      thumbnail: thumbnail,
      disease: (json['penyakit'] ?? 'Unknown').toString(),
      confidence: conf is num ? conf.toDouble() : 0,
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
