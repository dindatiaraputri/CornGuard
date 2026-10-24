import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:cornguard_mobile/models/disease_info.dart';
import 'package:cornguard_mobile/models/history_entry.dart';
import 'package:cornguard_mobile/services/history_store.dart';

/// Halaman Riwayat & Pencarian (SubTask #68).
/// Dibuka dengan: Navigator.pushNamed(context, '/history');
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  // Warna mengikuti halaman Beranda.
  static const _primary = Color(0xFF0F7A4D);
  static const _bg = Color(0xFFF4F6F0);
  static const _line = Color(0xFFE2E8F0);
  static const _text = Color(0xFF1E293B);
  static const _text2 = Color(0xFF64748B);
  static const _soft = Color(0xFFE6F4EA);

  final _searchCtrl = TextEditingController();
  List<HistoryEntry> _all = [];
  bool _loading = true;
  String _query = '';
  final Set<String> _selected = {}; // label penyakit yang dipilih
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final items = await HistoryStore.instance.load();
    if (!mounted) return;
    setState(() {
      _all = items;
      _loading = false;
    });
  }

  bool get _hasFilter => _query.trim().isNotEmpty || _selected.isNotEmpty || _range != null;

  List<HistoryEntry> get _filtered {
    final q = _query.trim().toLowerCase();
    return _all.where((e) {
      if (_selected.isNotEmpty && !_selected.contains(e.disease)) return false;
      if (_range != null) {
        final start = DateTime(_range!.start.year, _range!.start.month, _range!.start.day);
        final end = DateTime(_range!.end.year, _range!.end.month, _range!.end.day, 23, 59, 59);
        if (e.createdAt.isBefore(start) || e.createdAt.isAfter(end)) return false;
      }
      if (q.isNotEmpty) {
        final info = DiseaseInfo.of(e.disease);
        final hay = '${info.name} ${e.disease} ${formatTanggalJam(e.createdAt)}'.toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  void _resetFilter() {
    setState(() {
      _searchCtrl.clear();
      _query = '';
      _selected.clear();
      _range = null;
    });
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _range,
      helpText: 'Pilih rentang tanggal',
      saveText: 'Terapkan',
    );
    if (picked != null) setState(() => _range = picked);
  }

  Future<void> _confirmDelete(HistoryEntry e) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus riwayat ini?'),
        content: Text('${DiseaseInfo.of(e.disease).name}, ${formatTanggalJam(e.createdAt)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus')),
        ],
      ),
    );
    if (ok == true) {
      await HistoryStore.instance.remove(e.id);
      await _load();
    }
  }

  Future<void> _confirmClearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus semua riwayat?'),
        content: const Text('Semua catatan pemeriksaan di perangkat ini akan dihapus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Hapus semua')),
        ],
      ),
    );
    if (ok == true) {
      await HistoryStore.instance.clear();
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    return Scaffold(
      backgroundColor: _bg,
      appBar: AppBar(
        backgroundColor: _bg,
        foregroundColor: _text,
        surfaceTintColor: _bg,
        elevation: 0,
        title: const Text('Riwayat', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
        actions: [
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'clear') await _confirmClearAll();
              if (v == 'seed') {
                await HistoryStore.instance.seedSamples();
                await _load();
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'clear', child: Text('Hapus semua riwayat')),
              if (kDebugMode) const PopupMenuItem(value: 'seed', child: Text('Isi data contoh (uji)')),
            ],
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : Column(children: [
              _buildSearch(),
              _buildFilters(),
              Expanded(child: _all.isEmpty ? _emptyAll() : items.isEmpty ? _emptyFilter() : _buildList(items)),
            ]),
    );
  }

  Widget _buildSearch() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: TextField(
        controller: _searchCtrl,
        onChanged: (v) => setState(() => _query = v),
        decoration: InputDecoration(
          hintText: 'Cari nama penyakit atau tanggal',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: 'Hapus pencarian',
                  onPressed: () => setState(() {
                    _searchCtrl.clear();
                    _query = '';
                  }),
                ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _line)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _line)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: const BorderSide(color: _primary, width: 1.5)),
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          ActionChip(
            avatar: const Icon(Icons.date_range, size: 18),
            label: Text(_range == null ? 'Tanggal' : '${formatTanggal(_range!.start)} - ${formatTanggal(_range!.end)}'),
            backgroundColor: _range == null ? Colors.white : _soft,
            onPressed: _pickRange,
          ),
          if (_range != null)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: IconButton(
                icon: const Icon(Icons.close, size: 18),
                tooltip: 'Hapus filter tanggal',
                onPressed: () => setState(() => _range = null),
              ),
            ),
          const SizedBox(width: 8),
          for (final d in DiseaseInfo.all)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(d.name),
                avatar: CircleAvatar(backgroundColor: d.color, radius: 5),
                selected: _selected.contains(d.label),
                selectedColor: _soft,
                backgroundColor: Colors.white,
                showCheckmark: false,
                onSelected: (v) => setState(() => v ? _selected.add(d.label) : _selected.remove(d.label)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildList(List<HistoryEntry> items) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (_, i) => _card(items[i]),
    );
  }

  Widget _thumb(HistoryEntry e, {double size = 80}) {
    final placeholder = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(12)),
      child: const Icon(Icons.image, color: Colors.white),
    );
    final t = e.thumbnail;
    if (t == null || t.isEmpty) return placeholder;
    try {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.memory(
          base64Decode(t),
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => placeholder,
        ),
      );
    } catch (_) {
      return placeholder;
    }
  }

  Widget _card(HistoryEntry e) {
    final info = DiseaseInfo.of(e.disease);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(e),
        onLongPress: () => _confirmDelete(e),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: Row(children: [
            _thumb(e),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(formatTanggalJam(e.createdAt), style: const TextStyle(fontSize: 11, color: Colors.grey)),
                const SizedBox(height: 4),
                Row(children: [
                  CircleAvatar(backgroundColor: info.color, radius: 5),
                  const SizedBox(width: 6),
                  Expanded(child: Text(info.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text))),
                ]),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: _soft, borderRadius: BorderRadius.circular(12)),
                  child: Text('Kepercayaan: ${formatPersen(e.confidence)}',
                      style: const TextStyle(color: _primary, fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ]),
            ),
            const Icon(Icons.chevron_right, color: _text2),
          ]),
        ),
      ),
    );
  }

  Widget _emptyAll() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.history, size: 64, color: Color(0xFF9AA598)),
          const SizedBox(height: 12),
          const Text('Belum ada pemeriksaan', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 4),
          const Text('Mulai dengan memeriksa satu daun jagung.', textAlign: TextAlign.center, style: TextStyle(color: _text2)),
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _primary),
            onPressed: () => Navigator.pushNamed(context, '/camera'),
            child: const Text('Periksa Daun'),
          ),
        ]),
      ),
    );
  }

  Widget _emptyFilter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.search_off, size: 64, color: Color(0xFF9AA598)),
          const SizedBox(height: 12),
          const Text('Tidak ada hasil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
          const SizedBox(height: 4),
          const Text('Coba ubah kata kunci atau filter.', textAlign: TextAlign.center, style: TextStyle(color: _text2)),
          if (_hasFilter) ...[
            const SizedBox(height: 16),
            OutlinedButton(onPressed: _resetFilter, child: const Text('Reset filter')),
          ],
        ]),
      ),
    );
  }

  void _showDetail(HistoryEntry e) {
    final info = DiseaseInfo.of(e.disease);
    final sorted = e.scores.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            if (e.thumbnail != null && e.thumbnail!.isNotEmpty) Center(child: _thumb(e, size: 160)),
            const SizedBox(height: 12),
            Row(children: [
              Icon(info.icon, color: info.color),
              const SizedBox(width: 8),
              Expanded(child: Text(info.name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: info.color))),
            ]),
            const SizedBox(height: 4),
            Text('${formatTanggalJam(e.createdAt)}  |  Kepercayaan ${formatPersen(e.confidence)}', style: const TextStyle(color: _text2)),
            if (sorted.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Skor semua kelas', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
              const SizedBox(height: 8),
              for (final s in sorted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    SizedBox(width: 130, child: Text(DiseaseInfo.of(s.key).name, style: const TextStyle(fontSize: 13, color: _text))),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: s.value.clamp(0.0, 1.0).toDouble(),
                          minHeight: 8,
                          backgroundColor: _line,
                          color: DiseaseInfo.of(s.key).color,
                        ),
                      ),
                    ),
                    SizedBox(width: 56, child: Text(formatPersen(s.value), textAlign: TextAlign.right, style: const TextStyle(fontSize: 12, color: _text2))),
                  ]),
                ),
            ],
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tutup'))),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    _confirmDelete(e);
                  },
                  child: const Text('Hapus'),
                ),
              ),
            ]),
          ]),
        ),
      ),
    );
  }
}
