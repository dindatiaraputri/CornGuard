import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cornguard_mobile/models/history_entry.dart';

/// Penyimpanan riwayat di perangkat/browser (backend belum menyimpan riwayat).
class HistoryStore {
  HistoryStore._();
  static final HistoryStore instance = HistoryStore._();

  static const _key = 'history_v1';
  static const _maxItems = 40; // dibatasi agar penyimpanan browser tidak penuh

  /// Semua catatan, terbaru di atas.
  Future<List<HistoryEntry>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List;
      final items = list
          .map((e) => HistoryEntry.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
      items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return items;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save(List<HistoryEntry> items) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(items.map((e) => e.toJson()).toList()));
  }

  Future<void> add(HistoryEntry entry) async {
    final items = await load();
    items.insert(0, entry);
    if (items.length > _maxItems) items.removeRange(_maxItems, items.length);
    await _save(items);
  }

  /// DIPANGGIL OLEH HALAMAN HASIL (#67) setelah /api/diagnose/ berhasil:
  ///   await HistoryStore.instance.saveDiagnosis(hasilJson, imageBytes: bytes);
  /// `hasilJson` = Map hasil decode respons API, `imageBytes` = isi foto (boleh null).
  Future<void> saveDiagnosis(Map<String, dynamic> hasilJson, {Uint8List? imageBytes}) async {
    String? thumb;
    if (imageBytes != null) thumb = await makeThumbnail(imageBytes);
    await add(HistoryEntry.fromDiagnose(hasilJson, thumbnail: thumb));
  }

  Future<void> remove(String id) async {
    final items = await load();
    items.removeWhere((e) => e.id == id);
    await _save(items);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  /// Mengecilkan foto menjadi gambar kecil (PNG, base64) agar hemat tempat.
  static Future<String?> makeThumbnail(Uint8List bytes, {int width = 120}) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes, targetWidth: width);
      final frame = await codec.getNextFrame();
      final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) return null;
      return base64Encode(data.buffer.asUint8List());
    } catch (_) {
      return null;
    }
  }

  /// Data contoh untuk mencoba tampilan tanpa backend.
  Future<void> seedSamples() async {
    final now = DateTime.now();
    HistoryEntry e(int daysAgo, String d, double c, Map<String, double> s) => HistoryEntry(
          id: '${now.microsecondsSinceEpoch}_$daysAgo$d',
          disease: d,
          confidence: c,
          scores: s,
          createdAt: now.subtract(Duration(days: daysAgo, hours: daysAgo * 2)),
        );
    final items = await load();
    items.addAll([
      e(0, 'Healthy', 0.981, {'Healthy': 0.981, 'Blight': 0.01, 'Common_Rust': 0.005, 'Gray_Leaf_Spot': 0.004}),
      e(1, 'Common_Rust', 0.924, {'Common_Rust': 0.924, 'Blight': 0.05, 'Gray_Leaf_Spot': 0.016, 'Healthy': 0.01}),
      e(2, 'Gray_Leaf_Spot', 0.876, {'Gray_Leaf_Spot': 0.876, 'Blight': 0.09, 'Common_Rust': 0.02, 'Healthy': 0.014}),
      e(4, 'Blight', 0.803, {'Blight': 0.803, 'Gray_Leaf_Spot': 0.11, 'Common_Rust': 0.05, 'Healthy': 0.037}),
      e(7, 'Healthy', 0.955, {'Healthy': 0.955, 'Blight': 0.03, 'Common_Rust': 0.01, 'Gray_Leaf_Spot': 0.005}),
      e(10, 'Common_Rust', 0.887, {'Common_Rust': 0.887, 'Blight': 0.07, 'Gray_Leaf_Spot': 0.03, 'Healthy': 0.013}),
    ]);
    await _save(items);
  }
}
