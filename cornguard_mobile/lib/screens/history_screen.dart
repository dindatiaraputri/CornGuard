import 'package:flutter/material.dart';
import 'package:cornguard_mobile/models/disease_info.dart';
import 'package:cornguard_mobile/models/history_entry.dart';
import 'package:cornguard_mobile/services/api_services.dart';

/// Halaman Riwayat & Pencarian (SubTask #72).
/// Mengambil data riwayat diagnosa langsung dari Django Backend via JWT.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  static const _primary = Color(0xFF0F7A4D);
  static const _bg = Color(0xFFF4F6F0);
  static const _line = Color(0xFFE2E8F0);
  static const _text = Color(0xFF1E293B);
  static const _text2 = Color(0xFF64748B);
  static const _soft = Color(0xFFE6F4EA);

  final _searchCtrl = TextEditingController();
  List<HistoryEntry> _all = [];
  bool _loading = true;
  String? _errorMessage;
  String _query = '';
  final Set<String> _selected = {};
  DateTimeRange? _range;

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  // MENGAMBIL DATA RIWAYAT LANGSUNG DARI BACKEND DJANGO
  Future<void> _loadFromBackend() async {
    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final rawList = await ApiServices.getHistory();
      if (!mounted) return;

      final items = rawList.map((item) {
        final map = item as Map<String, dynamic>;
        
        // Parse tanggal dari string "24 Oct 2026, 23:54" atau ISO format
        DateTime parsedDate = DateTime.now();
        if (map['created_at'] != null) {
          parsedDate = DateTime.tryParse(map['created_at'].toString()) ?? DateTime.now();
        }

        // Hitung confidence (0.0 - 1.0)
        double conf = 0.0;
        if (map['confidence'] is num) {
          conf = (map['confidence'] as num).toDouble();
          if (conf > 1) conf = conf / 100;
        }

        return HistoryEntry(
          id: map['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
          disease: map['label']?.toString() ?? 'Unknown',
          confidence: conf,
          scores: {}, // Skor kelas jika dikirim dari backend
          createdAt: parsedDate,
        );
      }).toList();

      setState(() {
        _all = items;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
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
        title: const Text('Riwayat Deteksi', style: TextStyle(fontWeight: FontWeight.bold, color: _text)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat ulang data',
            onPressed: _loadFromBackend,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _primary))
          : _errorMessage != null
              ? _buildErrorView()
              : Column(children: [
                  _buildSearch(),
                  _buildFilters(),
                  Expanded(
                    child: _all.isEmpty
                        ? _emptyAll()
                        : items.isEmpty
                            ? _emptyFilter()
                            : _buildList(items),
                  ),
                ]),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 60, color: Colors.redAccent),
            const SizedBox(height: 12),
            const Text(
              'Gagal Memuat Riwayat',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
            ),
            const SizedBox(height: 6),
            Text(
              _errorMessage ?? 'Terjadi kesalahan saat mengambil data dari server.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: _text2, fontSize: 13),
            ),
            const SizedBox(height: 18),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: _loadFromBackend,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
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
    return RefreshIndicator(
      onRefresh: _loadFromBackend,
      color: _primary,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) => _card(items[index]),
      ),
    );
  }

  Widget _card(HistoryEntry e) {
    final info = DiseaseInfo.of(e.disease);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _showDetail(e),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _soft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(info.icon, color: info.color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      formatTanggalJam(e.createdAt),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      info.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: _text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _soft,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Kepercayaan: ${formatPersen(e.confidence)}',
                        style: const TextStyle(
                          color: _primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: _text2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _emptyAll() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history, size: 64, color: Color(0xFF9AA598)),
            const SizedBox(height: 12),
            const Text(
              'Belum ada pemeriksaan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text),
            ),
            const SizedBox(height: 4),
            const Text(
              'Lakukan deteksi foto daun jagung terlebih dahulu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: _text2),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: _primary),
              onPressed: () => Navigator.pushNamed(context, '/camera'),
              child: const Text('Periksa Daun Baru'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyFilter() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64, color: Color(0xFF9AA598)),
            const SizedBox(height: 12),
            const Text('Tidak ada hasil', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: _text)),
            const SizedBox(height: 4),
            const Text('Coba ubah kata kunci atau filter.', textAlign: TextAlign.center, style: TextStyle(color: _text2)),
            if (_hasFilter) ...[
              const SizedBox(height: 16),
              OutlinedButton(onPressed: _resetFilter, child: const Text('Reset filter')),
            ],
          ],
        ),
      ),
    );
  }

  void _showDetail(HistoryEntry e) {
    final info = DiseaseInfo.of(e.disease);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(info.icon, color: info.color, size: 28),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      info.name,
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: info.color),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Waktu: ${formatTanggalJam(e.createdAt)}  |  Tingkat Keyakinan: ${formatPersen(e.confidence)}',
                style: const TextStyle(color: _text2, fontSize: 12),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: _primary),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Tutup'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}