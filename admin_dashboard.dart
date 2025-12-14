import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:file_saver/file_saver.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'firebase_role.dart';

const kColorOrganik = Color(0xFF22C55E);
const kColorNon = Color(0xFFFACC15);
const Color kLastWeekLineColor = Colors.amber;

const List<String> kDoneReportStatuses = [
  'resolved',
  'selesai',
  'done',
  'finish',
  'finished'
];

const List<String> kPendingReportStatuses = [
  'open',
  'pending',
  'in_progress',
  'process',
  'proses'
];

const String kColAdmins = 'admins';
const String kColReports = 'reports';
const String kColHistories = 'cleaner_histories';
const String kColUsers = 'users';
const String kColTps = 'tps';
const String kColSuggestions = 'suggestions';

class AdminDashboard extends StatefulWidget {
  final RoleFirebase rf;
  const AdminDashboard({super.key, required this.rf});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _idx = 0;
  RoleFirebase get rf => widget.rf;

  Widget? _page0;
  Widget? _page1;
  Widget? _page2;
  Widget? _page3;

  Widget _page(int i) {
    switch (i) {
      case 0:
        return _page0 ??= _AdminHome(rf: rf);
      case 1:
        return _page1 ??= _Requests(rf: rf);
      case 2:
        return _page2 ??= _Users(rf: rf);
      default:
        return _page3 ??= _AdminProfile(rf: rf);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _page(_idx)),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_customize_rounded),
            label: 'Gabungan TPS',
          ),
          NavigationDestination(
            icon: Icon(Icons.pending_actions_rounded),
            label: 'Permintaan',
          ),
          NavigationDestination(
            icon: Icon(Icons.group_rounded),
            label: 'Data Pengguna',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}

class _AdminHome extends StatefulWidget {
  final RoleFirebase rf;
  const _AdminHome({required this.rf});

  @override
  State<_AdminHome> createState() => _AdminHomeState();
}

class _AdminHomeState extends State<_AdminHome>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  RoleFirebase get rf => widget.rf;
  FirebaseAuth get _auth => rf.auth;
  FirebaseFirestore get _db => rf.db;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _historiesCache = [];
  List<QueryDocumentSnapshot<Map<String, dynamic>>> _reportsCache = [];

  final Map<String, String> _userNameCache = {};
  final Map<String, Uint8List?> _proofBytesCache = {};

  bool _exportingCsv = false;

  // ===== REVISI UTAMA: HAPUS LOKAL (UI saja, tidak delete Firestore) =====
  final Set<String> _hiddenReportIds = <String>{};
  final Set<String> _hiddenHistoryIds = <String>{};
  final Set<String> _hiddenSuggestionIds = <String>{};

  DateTime get _today => DateTime.now();
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeekMonday(DateTime d) {
    final day0 = _startOfDay(d);
    final offset = (day0.weekday + 6) % 7; // Senin=0
    return day0.subtract(Duration(days: offset));
  }

  String _monthNameID(int m) => const [
        'Januari',
        'Februari',
        'Maret',
        'April',
        'Mei',
        'Juni',
        'Juli',
        'Agustus',
        'September',
        'Oktober',
        'November',
        'Desember'
      ][m - 1];

  String _dow3ID(int wd) =>
      ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'][wd == 7 ? 0 : wd - 1];

  String _fmtHM(DateTime d) {
    final h = '${d.hour}'.padLeft(2, '0');
    final m = '${d.minute}'.padLeft(2, '0');
    return '$h:$m';
  }

  static String _fmtTimeFromDT(DateTime? dt) {
    if (dt == null) return '-';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }

  static String _fmtTime(dynamic v) {
    if (v == null) return '-';
    if (v is Timestamp) return _fmtTimeFromDT(v.toDate());
    if (v is DateTime) return _fmtTimeFromDT(v);
    if (v is int) return _fmtTimeFromDT(DateTime.fromMillisecondsSinceEpoch(v));
    if (v is String && v.trim().isNotEmpty) {
      final s = v.trim().replaceFirst(' ', 'T');
      final dt = DateTime.tryParse(s);
      return _fmtTimeFromDT(dt);
    }
    return '-';
  }

  DateTime _safeDT(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    if (v is String && v.trim().isNotEmpty) {
      final s = v.trim().replaceFirst(' ', 'T');
      final dt = DateTime.tryParse(s);
      if (dt != null) return dt;
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  bool _looksLikeUid(String s) {
    final t = s.trim();
    if (t.isEmpty) return false;
    final re = RegExp(r'^[A-Za-z0-9_-]{20,}$');
    return re.hasMatch(t) && !t.contains(' ');
  }

  String _pickString(Map<String, dynamic> x, List<String> keys) {
    for (final k in keys) {
      final v = x[k];
      if (v is String && v.trim().isNotEmpty) return v.trim();

      if (v is List) {
        for (final it in v) {
          if (it is String && it.trim().isNotEmpty) return it.trim();
          if (it is Map &&
              it['url'] is String &&
              (it['url'] as String).trim().isNotEmpty) {
            return (it['url'] as String).trim();
          }
        }
      }

      if (v is Map) {
        final url = v['url'] ?? v['downloadURL'] ?? v['downloadUrl'];
        if (url is String && url.trim().isNotEmpty) return url.trim();
      }
    }
    return '';
  }

  Timestamp? _pickTimestamp(Map<String, dynamic> x, List<String> keys) {
    for (final k in keys) {
      final v = x[k];
      if (v is Timestamp) return v;
      if (v is DateTime) return Timestamp.fromDate(v);
      if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
      if (v is String && v.trim().isNotEmpty) {
        final s = v.trim().replaceFirst(' ', 'T');
        final dt = DateTime.tryParse(s);
        if (dt != null) return Timestamp.fromDate(dt);
      }
    }
    return null;
  }

  DateTime? _historyDT(Map<String, dynamic> x) {
    final ts = _pickTimestamp(x, [
      'doneAt',
      'finishedAt',
      'completedAt',
      'createdAt',
      'timestamp',
      'waktu',
      'tanggal',
      'date',
    ]);
    return ts?.toDate();
  }

  String _historyJenis(Map<String, dynamic> x) {
    final v =
        _pickString(x, ['jenis', 'wasteType', 'type', 'category', 'kategori']);
    return v.isEmpty ? '-' : v;
  }

  String _historyTps(Map<String, dynamic> x) {
    final v = _pickString(x, [
      'tps',
      'tpsName',
      'tps_nama',
      'namaTps',
      'locationName',
      'lokasi'
    ]);
    return v.isEmpty ? '-' : v;
  }

  String _historyTpsId(Map<String, dynamic> x) {
    final v = _pickString(x, ['tpsId', 'tps_id', 'lokasiId', 'locationId']);
    return v.isEmpty ? '-' : v;
  }

  String _historyCleanerUid(Map<String, dynamic> x) {
    final uid = _pickString(
        x, ['cleanerUid', 'petugasUid', 'userId', 'uid', 'handledByUid']);
    if (uid.isNotEmpty) return uid;

    final cleanerId = _pickString(x, ['cleanerId', 'petugasId', 'idPetugas']);
    if (cleanerId.isNotEmpty && _looksLikeUid(cleanerId)) return cleanerId;

    return '';
  }

  String _historyCleanerId(Map<String, dynamic> x) {
    return _pickString(x, ['cleanerId', 'petugasId', 'idPetugas']);
  }

  String _historyCleanerNameFromDoc(Map<String, dynamic> x) {
    final uid = _historyCleanerUid(x);
    final cand = _pickString(x, [
      'cleanerName',
      'petugasName',
      'namaPetugas',
      'petugas',
      'namePetugas'
    ]);
    if (cand.isEmpty) return '';
    if (_looksLikeUid(cand) || (uid.isNotEmpty && cand.trim() == uid.trim())) {
      return '';
    }
    return cand;
  }

  String? _historyProofBase64Raw(Map<String, dynamic> x) {
    final v = _pickString(x, [
      'proofBase64',
      'buktiBase64',
      'buktiFotoBase64',
      'photoBase64',
      'imageBase64',
      'image64',
      'buktiFoto',
      'foto',
      'image',
    ]);
    return v.isEmpty ? null : v;
  }

  Uint8List? _decodeBase64Flexible(String raw) {
    try {
      final s = raw.trim();
      if (s.isEmpty) return null;

      final idx = s.indexOf('base64,');
      final b64 = (idx >= 0) ? s.substring(idx + 7) : s;

      final cleaned = b64.replaceAll(RegExp(r'\s+'), '');
      return base64Decode(cleaned);
    } catch (_) {
      return null;
    }
  }

  Uint8List? _resolveProofBytesFromHistoryDoc(Map<String, dynamic> x) {
    final raw = _historyProofBase64Raw(x);
    if (raw == null) return null;
    if (raw.startsWith('http://') || raw.startsWith('https://')) return null;
    return _decodeBase64Flexible(raw);
  }

  Future<Uint8List?> _resolveProofBytes(
    QueryDocumentSnapshot<Map<String, dynamic>> historyDoc,
  ) async {
    final id = historyDoc.id;
    if (_proofBytesCache.containsKey(id)) return _proofBytesCache[id];

    final x = historyDoc.data();
    Uint8List? bytes = _resolveProofBytesFromHistoryDoc(x);

    if (bytes == null) {
      final reportId = _pickString(x, ['reportId', 'laporanId', 'report_id']);
      if (reportId.trim().isNotEmpty) {
        try {
          final r =
              await _db.collection(kColReports).doc(reportId.trim()).get();
          final rx = r.data();
          if (rx != null) {
            final raw2 = _historyProofBase64Raw(rx);
            if (raw2 != null && raw2.trim().isNotEmpty) {
              bytes = _decodeBase64Flexible(raw2);
            }
          }
        } catch (_) {}
      }
    }

    _proofBytesCache[id] = bytes;
    return bytes;
  }

  Future<void> _openPhotoPreview(BuildContext context, Uint8List bytes) async {
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Container(
                color: Colors.black,
                alignment: Alignment.center,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                onPressed: () => Navigator.of(ctx).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _displayReportStatus(String raw) {
    final s = raw.trim().toLowerCase();
    if (kDoneReportStatuses.contains(s)) return 'selesai';
    if (kPendingReportStatuses.contains(s) || s.isEmpty) return 'pending';
    return 'pending';
  }

  Future<Map<String, String>> _fetchUserNames(Set<String> uids) async {
    if (uids.isEmpty) return {};
    final limited = uids.take(50).toList();
    final result = <String, String>{};

    final missing = <String>[];
    for (final uid in limited) {
      if (_userNameCache.containsKey(uid)) {
        result[uid] = _userNameCache[uid]!;
      } else {
        missing.add(uid);
      }
    }
    if (missing.isEmpty) return result;

    Future<String?> fetchOne(String uid) async {
      try {
        final ds = await _db.collection(kColUsers).doc(uid).get();
        final data = ds.data();
        if (data != null) {
          final name = (data['name'] ?? data['nama'] ?? '').toString().trim();
          final email = (data['email'] ?? '').toString().trim();
          final shown = name.isNotEmpty ? name : (email.isNotEmpty ? email : '');
          if (shown.isNotEmpty) return shown;
        }
      } catch (_) {}
      return null;
    }

    await Future.wait(missing.map((uid) async {
      final name = await fetchOne(uid);
      if (name != null && name.trim().isNotEmpty) {
        _userNameCache[uid] = name.trim();
        result[uid] = name.trim();
      }
    }));

    return result;
  }

  Future<String?> _findNameByCleanerId(String cleanerId) async {
    final id = cleanerId.trim();
    if (id.isEmpty) return null;
    try {
      final qs = await _db
          .collection(kColUsers)
          .where('cleanerId', isEqualTo: id)
          .limit(1)
          .get();
      if (qs.docs.isEmpty) return null;
      final data = qs.docs.first.data();
      return (data['name'] ?? data['nama'] ?? data['email'] ?? id).toString();
    } catch (_) {
      return null;
    }
  }

  Future<bool> _isAdminNow() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.trim().isEmpty) return false;

    try {
      final adminDoc = await _db.collection(kColAdmins).doc(uid).get();
      if (adminDoc.exists) return true;
    } catch (_) {}

    try {
      final userDoc = await _db.collection(kColUsers).doc(uid).get();
      final data = userDoc.data();
      if (data != null) {
        final role = (data['role'] ?? '').toString().toLowerCase();
        final isAdmin = (data['isAdmin'] == true);
        if (role == 'admin' || isAdmin) return true;
      }
    } catch (_) {}

    return false;
  }

  Future<bool> _guardAdmin(BuildContext context) async {
    final ok = await _isAdminNow();
    if (ok) return true;

    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
            'Akun ini belum terdaftar sebagai admin. Pastikan /admins/{UID} ada, lalu login ulang.'),
      ),
    );
    return false;
  }

  Future<void> _openAddTps() async {
    final pageContext = context;
    if (!await _guardAdmin(pageContext)) return;

    final input = await showDialog<_TpsInput>(
      context: pageContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const _AddTpsDialog(),
    );

    if (input == null) return;
    if (!pageContext.mounted) return;

    showDialog(
      context: pageContext,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await _db.collection(kColTps).add({
        'name': input.name,
        'address': input.address,
        'type': input.type,
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': _auth.currentUser?.uid,
      });

      if (!pageContext.mounted) return;

      Navigator.of(pageContext, rootNavigator: true).pop();
      ScaffoldMessenger.of(pageContext).showSnackBar(
        const SnackBar(content: Text('TPS berhasil ditambahkan')),
      );
    } catch (e) {
      if (!pageContext.mounted) return;
      try {
        Navigator.of(pageContext, rootNavigator: true).pop();
      } catch (_) {}
      ScaffoldMessenger.of(pageContext).showSnackBar(
        SnackBar(
          content: Text('Gagal menambah TPS: ${_prettyFsError(e)}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ====== KONFIRMASI & HAPUS LOKAL (UI only) ======
  Future<bool> _confirmHideLocal(
      BuildContext pageContext, String title, String subtitle) async {
    final res = await showDialog<bool>(
      context: pageContext,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(
          'Item ini hanya akan dihapus dari tampilan Admin Home ini.\n'
          'Data di Firestore dan halaman/dashboard lain tetap ada.\n\n$subtitle',
          style: const TextStyle(height: 1.3),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Batal')),
          FilledButton.tonal(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus di Dashboard'),
          ),
        ],
      ),
    );
    return res == true;
  }

  Future<void> _hideHistoryDocLocal(
    BuildContext pageContext,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final x = doc.data();
    final when = _fmtTimeFromDT(_historyDT(x));
    final tps = _historyTps(x);
    final jenis = _historyJenis(x);

    final ok = await _confirmHideLocal(
      pageContext,
      'Hapus Riwayat (Dashboard saja)?',
      'Tanggal: $when\nTPS: $tps\nJenis: $jenis',
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() {
      _hiddenHistoryIds.add(doc.id);
      _historiesCache.removeWhere((d) => d.id == doc.id);
      _proofBytesCache.remove(doc.id);
    });

    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Riwayat disembunyikan dari Admin Home')),
    );
  }

  Future<void> _hideSuggestionDocLocal(
    BuildContext pageContext,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final x = doc.data();
    final when = _safeDT(x['createdAt']);
    final email = (x['byEmail'] ?? '').toString().trim();
    final msg = (x['message'] ?? '-').toString();

    final subtitle =
        'Tanggal: ${_dow3ID(when.weekday)}, ${when.day} ${_monthNameID(when.month)} ${when.year} • ${_fmtHM(when)}'
        '${email.isEmpty ? '' : '\nEmail: $email'}'
        '\nPesan: $msg';

    final ok = await _confirmHideLocal(
      pageContext,
      'Hapus Saran (Dashboard saja)?',
      subtitle,
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() => _hiddenSuggestionIds.add(doc.id));

    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Saran disembunyikan dari Admin Home')),
    );
  }

  Future<void> _hideReportDocLocal(
    BuildContext pageContext,
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) async {
    final x = doc.data();
    final created = _fmtTime(x['createdAt']);
    final tps = (x['tps'] ?? x['tpsName'] ?? '-').toString();
    final rawStatus = (x['status'] ?? 'open').toString();
    final statusShown = _displayReportStatus(rawStatus);

    final ok = await _confirmHideLocal(
      pageContext,
      'Hapus Laporan (Dashboard saja)?',
      'Tanggal: $created\nTPS: $tps\nStatus: $statusShown',
    );
    if (!ok) return;

    if (!mounted) return;
    setState(() {
      _hiddenReportIds.add(doc.id);
      _reportsCache.removeWhere((d) => d.id == doc.id);
    });

    ScaffoldMessenger.of(pageContext).showSnackBar(
      const SnackBar(content: Text('Laporan disembunyikan dari Admin Home')),
    );
  }

  Future<void> _exportHistoriesCsv(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> sorted,
    Map<String, String> nameMap,
  ) async {
    final rows = <List<String>>[];
    rows.add([
      'docId',
      'tanggal',
      'tps',
      'tpsId',
      'jenis',
      'petugas',
      'cleanerUid',
      'cleanerId',
      'reportId',
      'adaBukti',
    ]);

    for (final d in sorted) {
      final x = d.data();
      final dt = _historyDT(x);
      final when = _fmtTimeFromDT(dt);

      final tps = _historyTps(x);
      final tpsId = _historyTpsId(x);
      final jenis = _historyJenis(x);

      final uid = _historyCleanerUid(x);
      final cleanerId = _historyCleanerId(x);

      final nameFromDoc = _historyCleanerNameFromDoc(x);
      String petugas = '';
      if (nameFromDoc.isNotEmpty) {
        petugas = nameFromDoc;
      } else if (uid.isNotEmpty) {
        final n = nameMap[uid] ?? _userNameCache[uid];
        petugas = (n != null && n.trim().isNotEmpty) ? n : '';
      }
      if (petugas.trim().isEmpty) petugas = 'Tidak diketahui';

      final reportId = _pickString(x, ['reportId', 'laporanId', 'report_id']);
      final hasProof = (_historyProofBase64Raw(x)?.trim().isNotEmpty ?? false);

      rows.add([
        d.id,
        when,
        tps,
        tpsId,
        jenis,
        petugas,
        uid.isEmpty ? '-' : uid,
        cleanerId.isEmpty ? '-' : cleanerId,
        reportId.isEmpty ? '-' : reportId,
        hasProof ? 'ya' : 'tidak',
      ]);
    }

    final csv = const ListToCsvConverter().convert(rows);
    final bytes = Uint8List.fromList(utf8.encode(csv));

    final now = DateTime.now();
    final fn =
        'riwayat_pengangkutan_${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';

    await FileSaver.instance.saveFile(
      name: fn,
      bytes: bytes,
      ext: 'csv',
      mimeType: MimeType.csv,
    );
  }

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _historiesStream =
      _db
          .collection(kColHistories)
          .orderBy('doneAt', descending: true)
          .limit(300)
          .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream = _db
      .collection(kColReports)
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots();

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pendingReportsStream =
      _db
          .collection(kColReports)
          .where('status', whereIn: kPendingReportStatuses)
          .snapshots();

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final thisWeekStart = _startOfWeekMonday(_today);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
    final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final historiesThisWeekStream = _db
        .collection(kColHistories)
        .where('doneAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(thisWeekStart))
        .where('doneAt', isLessThan: Timestamp.fromDate(nextWeekStart))
        .orderBy('doneAt', descending: true)
        .snapshots();

    final historiesLast2WeeksStream = _db
        .collection(kColHistories)
        .where('doneAt',
            isGreaterThanOrEqualTo: Timestamp.fromDate(prevWeekStart))
        .where('doneAt', isLessThan: Timestamp.fromDate(nextWeekStart))
        .orderBy('doneAt', descending: true)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'DASHBOARD GABUNGAN SEMUA TPS',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Tambah TPS'),
              onPressed: _openAddTps,
            ),
          ],
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _pendingReportsStream,
                builder: (context, s) {
                  if (s.hasError) {
                    return _StatCard(
                      title: 'Laporan Terbuka',
                      value: '-',
                      icon: Icons.error_outline,
                      subtitle: _prettyFsError(s.error),
                    );
                  }
                  final open = (s.data?.docs
                              .where((d) => !_hiddenReportIds.contains(d.id))
                              .length ??
                          0)
                      .toString();

                  return _StatCard(
                    title: 'Laporan Terbuka',
                    value: open,
                    icon: Icons.error_outline,
                  );
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: historiesThisWeekStream,
                builder: (context, s) {
                  if (s.hasError) {
                    return _StatCard(
                      title: 'Total Pengangkutan Minggu Ini',
                      value: '-',
                      icon: Icons.local_shipping_outlined,
                      subtitle: _prettyFsError(s.error),
                    );
                  }
                  if (!s.hasData) {
                    return const _StatCard(
                      title: 'Total Pengangkutan Minggu Ini',
                      value: '…',
                      icon: Icons.local_shipping_outlined,
                      subtitle: 'Memuat…',
                    );
                  }

                  final totalThisWeek = s.data!.docs
                      .where((d) => !_hiddenHistoryIds.contains(d.id))
                      .length;

                  return _StatCard(
                    title: 'Total Pengangkutan Minggu Ini',
                    value: '$totalThisWeek',
                    icon: Icons.local_shipping_outlined,
                  );
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        Text('Distribusi Jenis Sampah Yang Sudah Diangkut',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historiesStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat diagram.\n${_prettyFsError(snap.error)}'),
                  );
                }

                final live = snap.data?.docs;
                if (live != null) _historiesCache = live;

                final docs = (live ?? _historiesCache)
                    .where((d) => !_hiddenHistoryIds.contains(d.id))
                    .toList();

                if (docs.isEmpty &&
                    (snap.connectionState == ConnectionState.waiting ||
                        snap.connectionState == ConnectionState.none)) {
                  return const SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()));
                }

                int organik = 0, non = 0;
                for (final d in docs) {
                  final jenis = _historyJenis(d.data()).toLowerCase();
                  if (jenis.contains('organik') && !jenis.contains('non')) {
                    organik++;
                  } else if (jenis.contains('non') ||
                      jenis.contains('anorganik')) {
                    non++;
                  } else {
                    non++;
                  }
                }

                final total = organik + non;
                if (total == 0) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada riwayat pengangkutan.'));
                }

                final safeTotal = max(1, total);

                return SizedBox(
                  height: 200,
                  child: Row(
                    children: [
                      Expanded(
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: 2,
                            centerSpaceRadius: 32,
                            sections: [
                              PieChartSectionData(
                                value: organik.toDouble(),
                                title:
                                    '${(organik / safeTotal * 100).toStringAsFixed(0)}%',
                                radius: 60,
                                color: kColorOrganik,
                              ),
                              PieChartSectionData(
                                value: non.toDouble(),
                                title:
                                    '${(non / safeTotal * 100).toStringAsFixed(0)}%',
                                radius: 60,
                                color: kColorNon,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _LegendDot(color: kColorOrganik, label: 'Organik'),
                          SizedBox(height: 8),
                          _LegendDot(color: kColorNon, label: 'Non-organik'),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text('${_monthNameID(_today.month)} ${_today.year}',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        _WeekStrip(today: _today),

        const SizedBox(height: 16),

        Text('Perbandingan Mingguan (Minggu ini vs Minggu lalu)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                _WeeklyCompareChartAdmin(
                  historiesStream: historiesLast2WeeksStream,
                  hiddenHistoryIds: _hiddenHistoryIds,
                ),
                const SizedBox(height: 8),
                const _WeeklyLegend(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text('Laporan Masuk Terbaru',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _reportsStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat data.\n${_prettyFsError(snap.error)}'),
                  );
                }

                final live = snap.data?.docs;
                if (live != null) _reportsCache = live;
                final docs = live ?? _reportsCache;

                final visibleDocs = docs
                    .where((d) => !_hiddenReportIds.contains(d.id))
                    .toList();

                if (visibleDocs.isEmpty &&
                    (snap.connectionState == ConnectionState.waiting ||
                        snap.connectionState == ConnectionState.none)) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()));
                }

                if (visibleDocs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada laporan.'));
                }

                final rows = visibleDocs.take(30).map((d) {
                  final x = d.data();
                  final created = _fmtTime(x['createdAt']);
                  final tps = (x['tps'] ?? x['tpsName'] ?? '-').toString();
                  final rawStatus = (x['status'] ?? 'open').toString();

                  return DataRow(
                    cells: [
                      DataCell(Text(created)),
                      DataCell(Text(tps)),
                      DataCell(_StatusBadge(status: rawStatus)),
                      DataCell(
                        OutlinedButton(
                          onPressed: () => _showReportDetail(context, d),
                          child: const Text('Detail'),
                        ),
                      ),
                      DataCell(
                        Tooltip(
                          message: 'Hapus (Dashboard saja)',
                          child: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            color: Theme.of(context).colorScheme.error,
                            onPressed: () => _hideReportDocLocal(context, d),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList();

                return _DataTableWrap(
                  columns: const [
                    DataColumn(label: Text('Tanggal')),
                    DataColumn(label: Text('TPS')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Detail')),
                    DataColumn(label: Text('Hapus')),
                  ],
                  rows: rows,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text('Riwayat Pengangkutan (Petugas)',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _historiesStream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat riwayat.\n${_prettyFsError(snap.error)}'),
                  );
                }

                final live = snap.data?.docs;
                if (live != null) _historiesCache = live;
                final docs = live ?? _historiesCache;

                final visible = docs
                    .where((d) => !_hiddenHistoryIds.contains(d.id))
                    .toList();

                if (visible.isEmpty &&
                    (snap.connectionState == ConnectionState.waiting ||
                        snap.connectionState == ConnectionState.none)) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()));
                }

                final sorted = [...visible];
                sorted.sort((a, b) {
                  final da = _historyDT(a.data()) ?? DateTime(1970);
                  final db = _historyDT(b.data()) ?? DateTime(1970);
                  return db.compareTo(da);
                });

                if (sorted.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada data pengangkutan.'));
                }

                final uidSet = sorted
                    .map((d) => _historyCleanerUid(d.data()))
                    .where((s) => s.trim().isNotEmpty)
                    .toSet();

                return FutureBuilder<Map<String, String>>(
                  future: _fetchUserNames(uidSet),
                  builder: (context, nameSnap) {
                    final nameMap = nameSnap.data ?? {};

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text('Total data: ${sorted.length}',
                                  style:
                                      Theme.of(context).textTheme.bodyMedium),
                            ),
                            OutlinedButton.icon(
                              onPressed: _exportingCsv
                                  ? null
                                  : () async {
                                      setState(() => _exportingCsv = true);
                                      try {
                                        await _exportHistoriesCsv(sorted, nameMap);
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('CSV berhasil diekspor')),
                                        );
                                      } catch (e) {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Gagal export CSV: $e')),
                                        );
                                      } finally {
                                        if (mounted) {
                                          setState(() => _exportingCsv = false);
                                        }
                                      }
                                    },
                              icon: _exportingCsv
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2))
                                  : const Icon(Icons.download_rounded),
                              label: const Text('Export CSV'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        _DataTableWrap(
                          columns: const [
                            DataColumn(label: Text('Tanggal')),
                            DataColumn(label: Text('TPS')),
                            DataColumn(label: Text('Jenis')),
                            DataColumn(label: Text('Petugas')),
                            DataColumn(label: Text('Bukti Foto')),
                            DataColumn(label: Text('Detail')),
                            DataColumn(label: Text('Hapus')),
                          ],
                          rows: sorted.take(200).map((d) {
                            final x = d.data();
                            final dt = _historyDT(x);
                            final when = _fmtTimeFromDT(dt);
                            final tps = _historyTps(x);
                            final jenis = _historyJenis(x);

                            final uid = _historyCleanerUid(x);
                            final cleanerId = _historyCleanerId(x);

                            final nameFromDoc = _historyCleanerNameFromDoc(x);
                            String petugas = '';
                            if (nameFromDoc.isNotEmpty) {
                              petugas = nameFromDoc;
                            } else if (uid.isNotEmpty) {
                              final n = nameMap[uid] ?? _userNameCache[uid];
                              petugas =
                                  (n != null && n.trim().isNotEmpty) ? n : '';
                            }
                            if (petugas.trim().isEmpty && cleanerId.isNotEmpty) {
                              petugas = 'Tidak diketahui';
                            }
                            if (petugas.trim().isEmpty) petugas = 'Tidak diketahui';

                            return DataRow(
                              cells: [
                                DataCell(Text(when)),
                                DataCell(Text(tps)),
                                DataCell(Text(jenis)),
                                DataCell(Text(petugas)),
                                DataCell(
                                  IconButton(
                                    tooltip: 'Lihat bukti',
                                    icon: const Icon(Icons.image_outlined),
                                    onPressed: () async {
                                      final bytes = await _resolveProofBytes(d);
                                      if (!context.mounted) return;

                                      if (bytes == null) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                              content:
                                                  Text('Bukti foto tidak tersedia')),
                                        );
                                        return;
                                      }
                                      await _openPhotoPreview(context, bytes);
                                    },
                                  ),
                                ),
                                DataCell(
                                  OutlinedButton(
                                    onPressed: () => _showHistoryDetail(context, d),
                                    child: const Text('Detail'),
                                  ),
                                ),
                                DataCell(
                                  Tooltip(
                                    message: 'Hapus (Dashboard saja)',
                                    child: IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded),
                                      color: Theme.of(context).colorScheme.error,
                                      onPressed: () =>
                                          _hideHistoryDocLocal(context, d),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          }).toList(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text('Saran Masuk', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _db
                  .collection(kColSuggestions)
                  .orderBy('createdAt', descending: true)
                  .limit(50)
                  .snapshots(),
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat saran.\n${_prettyFsError(snap.error)}'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()));
                }

                final docs = snap.data!.docs
                    .where((d) => !_hiddenSuggestionIds.contains(d.id))
                    .toList();

                if (docs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada saran masuk.'));
                }

                final take = docs.take(20).toList();

                return Column(
                  children: take.map((d) {
                    final x = d.data();
                    final when = _safeDT(x['createdAt']);
                    final email = (x['byEmail'] ?? '').toString();

                    return ListTile(
                      leading: const Icon(Icons.chat_bubble_outline_rounded),
                      title: Text((x['message'] ?? '-').toString()),
                      subtitle: Text(
                        '${_dow3ID(when.weekday)}, ${when.day} ${_monthNameID(when.month)} ${when.year} • ${_fmtHM(when)}'
                        '${email.isEmpty ? '' : '  ·  $email'}',
                      ),
                      trailing: IconButton(
                        tooltip: 'Hapus (Dashboard saja)',
                        icon: Icon(Icons.delete_outline_rounded,
                            color: Theme.of(context).colorScheme.error),
                        onPressed: () => _hideSuggestionDocLocal(context, d),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showReportDetail(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) async {
    final x = d.data();

    final reporterUid =
        _pickString(x, ['by', 'byUid', 'reporterUid', 'pelaporUid']);
    final reporterNameFromDoc = _pickString(
        x, ['byName', 'pelaporName', 'pelaporNama', 'reporterName']);

    final resolvedByUid =
        _pickString(x, ['resolvedBy', 'petugasUid', 'cleanerUid', 'handledBy']);
    final petugasNameFromDoc = _pickString(x, [
      'resolvedByName',
      'petugasName',
      'petugasNama',
      'cleanerName',
      'namaPetugas'
    ]);
    final cleanerIdFallback =
        _pickString(x, ['cleanerId', 'petugasId', 'idPetugas']);

    final uids = <String>{};
    if (reporterUid.trim().isNotEmpty) uids.add(reporterUid.trim());
    if (resolvedByUid.trim().isNotEmpty) uids.add(resolvedByUid.trim());

    Map<String, String> nameMap = {};
    try {
      nameMap = await _fetchUserNames(uids);
    } catch (_) {
      nameMap = {};
    }

    final reporterName = reporterNameFromDoc.isNotEmpty
        ? reporterNameFromDoc
        : (reporterUid.isNotEmpty ? (nameMap[reporterUid] ?? '-') : '-');

    String petugasName = '-';
    if (petugasNameFromDoc.isNotEmpty && !_looksLikeUid(petugasNameFromDoc)) {
      petugasName = petugasNameFromDoc;
    } else if (resolvedByUid.isNotEmpty) {
      final n = nameMap[resolvedByUid] ?? _userNameCache[resolvedByUid];
      petugasName = (n != null && n.trim().isNotEmpty) ? n : '-';
    } else if (cleanerIdFallback.isNotEmpty) {
      final found = await _findNameByCleanerId(cleanerIdFallback);
      petugasName = found ?? '-';
    }

    final rawStatus = (x['status'] ?? 'open').toString();
    final statusShown = _displayReportStatus(rawStatus);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (ctx) {
        final bottomSafe = MediaQuery.of(ctx).padding.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafe + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detail Laporan',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _kv('Tanggal Laporan', _fmtTime(x['createdAt'])),
                _kv('TPS', (x['tps'] ?? x['tpsName'] ?? '-').toString()),
                _kv('Jenis', (x['jenis'] ?? '-').toString()),
                _kv('Status', statusShown),
                _kv('Pelapor', reporterName),
                if (petugasName.trim().isNotEmpty && petugasName != '-')
                  _kv('Petugas', petugasName),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showHistoryDetail(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d,
  ) async {
    final x = d.data();

    final dt = _historyDT(x);
    final when = _fmtTimeFromDT(dt);

    final tps = _historyTps(x);
    final jenis = _historyJenis(x);

    final uid = _historyCleanerUid(x);
    final cleanerId = _historyCleanerId(x);

    String petugas = _historyCleanerNameFromDoc(x);
    if (petugas.trim().isEmpty && uid.isNotEmpty) {
      final map = await _fetchUserNames({uid});
      final n = map[uid] ?? _userNameCache[uid];
      petugas = (n != null && n.trim().isNotEmpty) ? n : '';
    }
    if (petugas.trim().isEmpty && cleanerId.isNotEmpty) {
      final found = await _findNameByCleanerId(cleanerId);
      petugas = (found != null && found.trim().isNotEmpty) ? found : '';
    }
    if (petugas.trim().isEmpty) petugas = 'Tidak diketahui';

    final berat = _pickString(x, ['berat', 'weight', 'kg']);
    final catatan = _pickString(x, ['note', 'catatan', 'keterangan']);
    final relatedReportId = _pickString(x, ['reportId', 'laporanId', 'report_id']);

    final proofBytes = await _resolveProofBytes(d);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints:
          BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      builder: (ctx) {
        final bottomSafe = MediaQuery.of(ctx).padding.bottom;
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(16, 16, 16, bottomSafe + 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Detail Pengangkutan',
                    style: Theme.of(ctx)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                _kv('Tanggal', when),
                _kv('TPS', tps),
                _kv('Jenis', jenis),
                _kv('Petugas', petugas),
                if (berat.isNotEmpty) _kv('Berat', berat),
                if (catatan.isNotEmpty) _kv('Catatan', catatan),
                if (relatedReportId.isNotEmpty) _kv('Report ID', relatedReportId),
                if (proofBytes != null) ...[
                  const SizedBox(height: 12),
                  Text('Bukti Foto', style: Theme.of(ctx).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: InkWell(
                      onTap: () => _openPhotoPreview(context, proofBytes),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          width: 160,
                          height: 110,
                          child: Image.memory(proofBytes, fit: BoxFit.cover),
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Tutup')),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _kv(String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 140,
              child: Text(k,
                  style: const TextStyle(fontWeight: FontWeight.w600))),
          const SizedBox(width: 8),
          Expanded(
              child: SelectableText(v, style: const TextStyle(height: 1.25))),
        ],
      ),
    );
  }
}

// ===================== DIALOG TPS =====================
class _TpsInput {
  final String name;
  final String type;
  final String address;
  const _TpsInput({required this.name, required this.type, required this.address});
}

class _AddTpsDialog extends StatefulWidget {
  const _AddTpsDialog();

  @override
  State<_AddTpsDialog> createState() => _AddTpsDialogState();
}

class _AddTpsDialogState extends State<_AddTpsDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _address = TextEditingController();
  String _type = 'organik';
  bool _locked = false;

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    super.dispose();
  }

  void _submit() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _locked = true);

    final data = _TpsInput(
      name: _name.text.trim(),
      type: _type,
      address: _address.text.trim(),
    );

    Future.microtask(() {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop(data);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Tambah TPS'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Nama TPS / TPA'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Jenis'),
                  items: const [
                    DropdownMenuItem(value: 'organik', child: Text('Organik')),
                    DropdownMenuItem(value: 'non-organik', child: Text('Non-organik')),
                  ],
                  onChanged: _locked
                      ? null
                      : (v) => setState(() => _type = v ?? 'organik'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _address,
                  decoration:
                      const InputDecoration(labelText: 'Alamat (opsional)'),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _locked
              ? null
              : () {
                  FocusManager.instance.primaryFocus?.unfocus();
                  Navigator.of(context, rootNavigator: true).pop(null);
                },
          child: const Text('Batal'),
        ),
        FilledButton.icon(
          onPressed: _locked ? null : _submit,
          icon: _locked
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.save_rounded),
          label: const Text('Simpan'),
        ),
      ],
    );
  }
}

// ===================== REQUESTS (PENDING USERS) =====================
class _Requests extends StatelessWidget {
  final RoleFirebase rf;
  const _Requests({required this.rf});

  FirebaseAuth get _auth => rf.auth;
  FirebaseFirestore get _db => rf.db;

  Future<void> _approve(BuildContext context, String uid) async {
    try {
      await _db.collection(kColUsers).doc(uid).update({
        'status': 'approved',
        'approved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'approvedBy': _auth.currentUser?.uid,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pengguna berhasil disetujui')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui pengguna: $e')));
    }
  }

  Future<void> _reject(BuildContext context, String uid) async {
    try {
      await _db.collection(kColUsers).doc(uid).update({
        'status': 'rejected',
        'approved': false,
        'rejectedAt': FieldValue.serverTimestamp(),
        'rejectedBy': _auth.currentUser?.uid,
      });

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permintaan pendaftaran ditolak')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal menolak pengguna: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final stream = _db
        .collection(kColUsers)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'PERMINTAAN PENDAFTARAN',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Gagal memuat data:\n${_prettyFsError(snap.error)}'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()));
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Tidak ada permintaan pendaftaran.'));
                }

                final rows = docs.map((d) {
                  final x = d.data();
                  final name = (x['name'] ?? '-').toString();
                  final photo = _avatarUrlOf(x);

                  return DataRow(
                    cells: [
                      DataCell(_AvatarCell(name: name, photoUrl: photo)),
                      DataCell(Text(name)),
                      DataCell(Text((x['email'] ?? '-').toString())),
                      DataCell(Text((x['phone'] ?? '-').toString())),
                      DataCell(Text((x['role'] ?? '-').toString())),
                      DataCell(Text((x['cleanerId'] ?? '-').toString())),
                      DataCell(
                        Row(
                          children: [
                            FilledButton.tonal(
                              onPressed: () => _approve(context, d.id),
                              child: const Text('Approve'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.tonal(
                              onPressed: () => _reject(context, d.id),
                              child: const Text('Reject'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                }).toList();

                return _DataTableWrap(
                  columns: const [
                    DataColumn(label: Text('Foto')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('No HP')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('ID Petugas')),
                    DataColumn(label: Text('Aksi')),
                  ],
                  rows: rows,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== USERS =====================
class _Users extends StatelessWidget {
  final RoleFirebase rf;
  const _Users({required this.rf});

  FirebaseFirestore get _db => rf.db;

  @override
  Widget build(BuildContext context) {
    final stream = _db
        .collection(kColUsers)
        .orderBy('createdAt', descending: true)
        .limit(200)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'DATA PENGGUNA',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(12),
                    child:
                        Text('Gagal memuat data.\n${_prettyFsError(snap.error)}'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()));
                }

                final docs = snap.data!.docs;
                if (docs.isEmpty) {
                  return const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada pengguna terdaftar.'));
                }

                final rows = docs.map((d) {
                  final x = d.data();
                  final name = (x['name'] ?? '-').toString();
                  final photo = _avatarUrlOf(x);

                  return DataRow(
                    cells: [
                      DataCell(_AvatarCell(name: name, photoUrl: photo)),
                      DataCell(Text(name)),
                      DataCell(Text((x['email'] ?? '-').toString())),
                      DataCell(Text((x['phone'] ?? '-').toString())),
                      DataCell(Text((x['role'] ?? '-').toString())),
                      DataCell(_StatusBadge(status: (x['status'] ?? '-').toString())),
                    ],
                  );
                }).toList();

                return _DataTableWrap(
                  columns: const [
                    DataColumn(label: Text('Foto')),
                    DataColumn(label: Text('Nama')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('No HP')),
                    DataColumn(label: Text('Role')),
                    DataColumn(label: Text('Status')),
                  ],
                  rows: rows,
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ===================== PROFIL ADMIN =====================
class _AdminProfile extends StatelessWidget {
  final RoleFirebase rf;
  const _AdminProfile({required this.rf});

  @override
  Widget build(BuildContext context) {
    final u = rf.auth.currentUser;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'PROFIL ADMIN',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 48, child: Icon(Icons.person, size: 42)),
              const SizedBox(height: 12),
              Text(u?.email ?? '-', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              SelectableText('UID: ${u?.uid ?? '-'}',
                  style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () async {
                  await rf.auth.signOut();
                },
                child: const Text('LOGOUT'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ===================== UI COMPONENTS =====================
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    this.subtitle,
  });

  final String title;
  final String value;
  final IconData icon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: cs.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(value,
                      style: const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(subtitle!,
                        style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  String _displayLabel(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'resolved' || s == 'selesai') return 'selesai';
    if (s == 'open' || s == 'in_progress' || s == 'pending') return 'pending';
    if (s == 'approved') return 'approved';
    if (s == 'rejected') return 'rejected';
    return raw;
  }

  String _canonicalForColor(String raw) {
    final s = raw.trim().toLowerCase();
    if (s == 'resolved' || s == 'selesai') return 'resolved';
    if (s == 'approved') return 'approved';
    if (s == 'rejected') return 'rejected';
    if (s == 'open' || s == 'in_progress' || s == 'pending') return 'pending';
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final canonical = _canonicalForColor(status);

    Color bg;
    Color fg;

    switch (canonical) {
      case 'pending':
        bg = cs.tertiaryContainer;
        fg = cs.onTertiaryContainer;
        break;
      case 'resolved':
      case 'approved':
        bg = cs.secondaryContainer;
        fg = cs.onSecondaryContainer;
        break;
      case 'rejected':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      default:
        bg = cs.surfaceContainerLow;
        fg = cs.onSurfaceVariant;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        _displayLabel(status),
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w600,
          letterSpacing: .2,
        ),
      ),
    );
  }
}

class _DataTableWrap extends StatelessWidget {
  const _DataTableWrap({required this.columns, required this.rows});
  final List<DataColumn> columns;
  final List<DataRow> rows;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return LayoutBuilder(
      builder: (context, constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: cs.surface,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: constraints.maxWidth),
                child: DataTableTheme(
                  data: DataTableThemeData(
                    headingRowColor: MaterialStateProperty.all(cs.surface),
                    dataRowColor: MaterialStateProperty.all(cs.surface),
                    dividerThickness: 0.7,
                  ),
                  child: DataTable(
                    columns: columns,
                    rows: rows,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(label),
        ],
      );
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today});
  final DateTime today;

  String _dow3ID(int wd) =>
      ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'][wd == 7 ? 0 : wd - 1];

  @override
  Widget build(BuildContext context) {
    final days = List.generate(5, (i) => today.add(Duration(days: i - 2)));
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: days.map((d) {
        final isToday = d.year == today.year &&
            d.month == today.month &&
            d.day == today.day;
        return ChoiceChip(
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.day}',
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(_dow3ID(d.weekday), style: const TextStyle(fontSize: 12)),
            ],
          ),
          selected: isToday,
          onSelected: (_) {},
        );
      }).toList(),
    );
  }
}

class _WeeklyLegend extends StatelessWidget {
  const _WeeklyLegend();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Widget dot(Color c, String t) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: c, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(t),
          ],
        );

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        dot(kLastWeekLineColor, 'Minggu lalu'),
        const SizedBox(width: 16),
        dot(cs.primary, 'Minggu ini'),
      ],
    );
  }
}

class _WeeklyCompareChartAdmin extends StatefulWidget {
  const _WeeklyCompareChartAdmin({
    required this.historiesStream,
    required this.hiddenHistoryIds,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> historiesStream;
  final Set<String> hiddenHistoryIds;

  @override
  State<_WeeklyCompareChartAdmin> createState() =>
      _WeeklyCompareChartAdminState();
}

class _WeeklyCompareChartAdminState extends State<_WeeklyCompareChartAdmin>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _cache = [];

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeekMonday(DateTime d) {
    final day0 = _startOfDay(d);
    final offset = (day0.weekday + 6) % 7;
    return day0.subtract(Duration(days: offset));
  }

  String _dowShortID(int weekday) {
    const names = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    return names[(weekday + 6) % 7];
  }

  DateTime? _historyDT(Map<String, dynamic> x) {
    Timestamp? pick(List<String> keys) {
      for (final k in keys) {
        final v = x[k];
        if (v is Timestamp) return v;
        if (v is DateTime) return Timestamp.fromDate(v);
        if (v is int) return Timestamp.fromMillisecondsSinceEpoch(v);
        if (v is String && v.trim().isNotEmpty) {
          final s = v.trim().replaceFirst(' ', 'T');
          final dt = DateTime.tryParse(s);
          if (dt != null) return Timestamp.fromDate(dt);
        }
      }
      return null;
    }

    final ts = pick([
      'doneAt',
      'finishedAt',
      'completedAt',
      'createdAt',
      'timestamp',
      'waktu',
      'tanggal',
      'date'
    ]);
    return ts?.toDate();
  }

  List<int> _countPerDay7FromHistory(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      DateTime wStart) {
    final buckets = List<int>.filled(7, 0);
    for (final d in docs) {
      final dt = _historyDT(d.data());
      if (dt == null) continue;
      final t = _startOfDay(dt);
      final idx = t.difference(wStart).inDays;
      if (idx >= 0 && idx < 7) buckets[idx] += 1;
    }
    return buckets;
  }

  LineChartBarData _line(List<int> pts, Color color) {
    return LineChartBarData(
      isCurved: true,
      color: color,
      barWidth: 3,
      dotData: const FlDotData(show: false),
      spots: List.generate(7, (i) => FlSpot(i.toDouble(), pts[i].toDouble())),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();

    final thisWeekStart = _startOfWeekMonday(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
    final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.historiesStream,
      builder: (context, snap) {
        if (snap.hasError) {
          return SizedBox(
            height: 210,
            child: Center(
              child: Text('Gagal memuat grafik.\n${_prettyFsError(snap.error)}',
                  textAlign: TextAlign.center),
            ),
          );
        }

        final live = snap.data?.docs;
        if (live != null) _cache = live;

        final all = (live ?? _cache)
            .where((d) => !widget.hiddenHistoryIds.contains(d.id))
            .toList();

        if (all.isEmpty &&
            (snap.connectionState == ConnectionState.waiting ||
                snap.connectionState == ConnectionState.none)) {
          return const SizedBox(
              height: 210, child: Center(child: CircularProgressIndicator()));
        }

        final lastWeekDocs = all.where((d) {
          final t = _historyDT(d.data());
          return t != null &&
              !t.isBefore(prevWeekStart) &&
              t.isBefore(thisWeekStart);
        });

        final thisWeekDocs = all.where((d) {
          final t = _historyDT(d.data());
          return t != null &&
              !t.isBefore(thisWeekStart) &&
              t.isBefore(nextWeekStart);
        });

        final lastWeek = _countPerDay7FromHistory(lastWeekDocs, prevWeekStart);
        final thisWeek = _countPerDay7FromHistory(thisWeekDocs, thisWeekStart);

        final maxY =
            ([...lastWeek, ...thisWeek].fold<int>(0, (m, v) => v > m ? v : m) +
                    5)
                .toDouble();

        return SizedBox(
          height: 210,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              gridData: FlGridData(show: true, drawVerticalLine: true),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (v, _) => Text(v.toInt().toString(),
                        style: const TextStyle(fontSize: 11)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 24,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      final rounded = v.roundToDouble();
                      if ((v - rounded).abs() > 0.001) {
                        return const SizedBox.shrink();
                      }
                      final i = rounded.toInt().clamp(0, 6);
                      final day = thisWeekStart.add(Duration(days: i));
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(_dowShortID(day.weekday),
                            style: const TextStyle(fontSize: 11)),
                      );
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              lineBarsData: [
                _line(lastWeek, kLastWeekLineColor),
                _line(thisWeek, cs.primary),
              ],
            ),
          ),
        );
      },
    );
  }
}

String? _avatarUrlOf(Map<String, dynamic> x) {
  const keys = [
    'photoURL',
    'photoUrl',
    'avatarUrl',
    'avatar',
    'imageUrl',
    'image',
    'photo'
  ];
  for (final k in keys) {
    final v = x[k];
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return null;
}

class _AvatarCell extends StatelessWidget {
  const _AvatarCell({required this.name, required this.photoUrl});
  final String name;
  final String? photoUrl;

  String _initials(String s) {
    final t = s.trim();
    if (t.isEmpty) return 'U';
    final parts = t.split(RegExp(r'\s+'));
    final f = parts.isNotEmpty ? parts[0][0] : 'U';
    final l = parts.length > 1 ? parts[1][0] : '';
    return ('$f$l').toUpperCase();
  }

  bool get _hasPhoto {
    final s = photoUrl?.trim() ?? '';
    return s.startsWith('http');
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _hasPhoto;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: CircleAvatar(
        radius: 18,
        backgroundColor: Colors.grey.shade200,
        foregroundColor: Colors.grey.shade800,
        foregroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
        onForegroundImageError: hasPhoto ? (Object _, StackTrace? __) {} : null,
        child: Text(_initials(name),
            style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

String _prettyFsError(Object? e) {
  if (e == null) return '';
  final s = e.toString();
  if (s.contains('permission-denied')) {
    return 'Permission denied. Periksa Firestore Rules untuk admin.';
  }
  return s;
}
