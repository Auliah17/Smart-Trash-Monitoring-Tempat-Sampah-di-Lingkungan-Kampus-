// lib/campus_dashboard.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'firebase_role.dart';

class CampusDashboard extends StatefulWidget {
  final RoleFirebase rf;
  const CampusDashboard({super.key, required this.rf});

  @override
  State<CampusDashboard> createState() => _CampusDashboardState();
}

class _CampusDashboardState extends State<CampusDashboard> {
  int idx = 0;

  @override
  Widget build(BuildContext context) {
    final rf = widget.rf;

    final pages = [
      _ReportAndSuggestionPage(rf: rf),
      _MyHistoryPage(rf: rf),
      _Profile(rf: rf),
    ];

    final labels = ['Beranda', 'Riwayat', 'Profil'];
    final icons = [
      Icons.home_rounded,
      Icons.history_rounded,
      Icons.person_rounded,
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: idx, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: idx,
        onDestinationSelected: (i) => setState(() => idx = i),
        destinations: List.generate(
          3,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}

/// ===================================================================
/// BERANDA: LAPOR TPS + KIRIM SARAN
/// ===================================================================
class _TpsItem {
  final String id;
  final String name;
  final String type;
  const _TpsItem({required this.id, required this.name, required this.type});
}

class _ReportAndSuggestionPage extends StatefulWidget {
  final RoleFirebase rf;
  const _ReportAndSuggestionPage({required this.rf});

  @override
  State<_ReportAndSuggestionPage> createState() =>
      _ReportAndSuggestionPageState();
}

class _ReportAndSuggestionPageState extends State<_ReportAndSuggestionPage> {
  final _formLapor = GlobalKey<FormState>();

  String? _selectedTpsId;
  String _selectedJenis = 'organik';

  bool _sendingLaporan = false;

  final _saranCtrl = TextEditingController();
  bool _sendingSaran = false;

  RoleFirebase get rf => widget.rf;

  @override
  void dispose() {
    _saranCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>?> _getMyUserDoc() async {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return null;
    try {
      final ds = await rf.db.collection('users').doc(uid).get();
      if (!ds.exists) return null;
      return ds.data();
    } catch (_) {
      return null;
    }
  }

  Future<void> _kirimLaporan(_TpsItem tps) async {
    if (!_formLapor.currentState!.validate()) return;

    final u = rf.auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda belum login.')),
      );
      return;
    }

    setState(() => _sendingLaporan = true);
    try {
      final uid = u.uid;
      final email = (u.email ?? '').trim();

      final me = await _getMyUserDoc();
      final byName = (me?['name'] ?? me?['nama'] ?? '').toString().trim();

      await rf.db.collection('reports').add({
        'tpsId': tps.id,
        'tps': tps.name,
        'tpsType': tps.type,
        'jenis': _selectedJenis,
        'status': 'open',
        'by': uid,
        if (email.isNotEmpty) 'byEmail': email,
        if (byName.isNotEmpty) 'byName': byName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      setState(() => _selectedTpsId = null);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Laporan terkirim')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim laporan: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingLaporan = false);
    }
  }

  Future<void> _kirimSaran() async {
    final msg = _saranCtrl.text.trim();
    if (msg.isEmpty) return;

    final u = rf.auth.currentUser;
    if (u == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anda belum login.')),
      );
      return;
    }

    setState(() => _sendingSaran = true);
    try {
      final uid = u.uid;
      final email = (u.email ?? '').trim();

      final me = await _getMyUserDoc();
      final byName = (me?['name'] ?? me?['nama'] ?? '').toString().trim();

      await rf.db.collection('suggestions').add({
        'message': msg,
        'by': uid,
        if (email.isNotEmpty) 'byEmail': email,
        if (byName.isNotEmpty) 'byName': byName,
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _saranCtrl.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saran dikirim')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal kirim saran: $e')),
      );
    } finally {
      if (mounted) setState(() => _sendingSaran = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tpsStream = rf.db.collection('tps').orderBy('name').snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'LAPOR TPS PENUH',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formLapor,
              child: Column(
                children: [
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: tpsStream,
                    builder: (context, snap) {
                      if (snap.hasError) {
                        return const Text('Gagal memuat daftar TPS.');
                      }
                      if (!snap.hasData) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      final docs = snap.data?.docs ?? [];
                      final items = docs.map((d) {
                        final x = d.data();
                        final name = (x['name'] ?? d.id).toString().trim();
                        final type = (x['type'] ?? '').toString().trim();
                        return _TpsItem(
                          id: d.id,
                          name: name.isEmpty ? d.id : name,
                          type: type.isEmpty ? '-' : type,
                        );
                      }).toList();

                      if (items.isEmpty) {
                        return const Text('Belum ada TPS terdaftar. Hubungi admin.');
                      }

                      // ✅ REVISI: dropdown Pilih TPS hanya tampilkan nama TPS (tanpa jenis)
                      return DropdownButtonFormField<String>(
                        value: _selectedTpsId,
                        isExpanded: true,
                        items: items
                            .map((it) => DropdownMenuItem(
                                  value: it.id,
                                  child: Text(it.name),
                                ))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedTpsId = v),
                        decoration: const InputDecoration(
                          labelText: 'Pilih TPS',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.isEmpty) ? 'Pilih TPS' : null,
                        onSaved: (v) => _selectedTpsId = v,
                      );
                    },
                  ),

                  const SizedBox(height: 12),

                  DropdownButtonFormField<String>(
                    value: _selectedJenis,
                    isExpanded: true,
                    items: const [
                      DropdownMenuItem(value: 'organik', child: Text('Organik')),
                      DropdownMenuItem(value: 'non-organik', child: Text('Non-Organik')),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedJenis = v);
                    },
                    decoration: const InputDecoration(
                      labelText: 'Jenis',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  SizedBox(
                    width: double.infinity,
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: tpsStream,
                      builder: (context, snap) {
                        final docs = snap.data?.docs ?? [];
                        final items = docs.map((d) {
                          final x = d.data();
                          return _TpsItem(
                            id: d.id,
                            name: (x['name'] ?? d.id).toString(),
                            type: (x['type'] ?? '').toString(),
                          );
                        }).toList();

                        final byId = {for (final it in items) it.id: it};
                        final chosen = _selectedTpsId == null ? null : byId[_selectedTpsId!];

                        final cs = Theme.of(context).colorScheme;
                        final btnStyle = FilledButton.styleFrom(
                          backgroundColor: cs.primary,
                          foregroundColor: cs.onPrimary,
                          disabledBackgroundColor: cs.primary.withOpacity(.55),
                          disabledForegroundColor: cs.onPrimary.withOpacity(.85),
                          minimumSize: const Size.fromHeight(52),
                        );

                        return FilledButton(
                          style: btnStyle,
                          onPressed: _sendingLaporan
                              ? null
                              : () {
                                  final ok = _formLapor.currentState?.validate() ?? false;
                                  if (!ok) return;
                                  if (chosen == null) return;
                                  _kirimLaporan(chosen);
                                },
                          child: _sendingLaporan
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('KIRIM LAPORAN'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          'KIRIM SARAN',
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _saranCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Tulis saran...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _sendingSaran ? null : _kirimSaran,
                    child: _sendingSaran
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('KIRIM SARAN'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// ===================================================================
/// RIWAYAT
/// ===================================================================
class _MyHistoryPage extends StatelessWidget {
  final RoleFirebase rf;
  const _MyHistoryPage({required this.rf});

  String _prettyStatus(String? s) {
    switch ((s ?? '').toLowerCase().trim()) {
      case 'in_progress':
        return 'Proses';
      case 'resolved':
      case 'selesai':
        return 'Selesai';
      case 'open':
      default:
        return 'Open';
    }
  }

  Color _statusColor(String? s) {
    switch ((s ?? '').toLowerCase().trim()) {
      case 'in_progress':
        return Colors.amber;
      case 'resolved':
      case 'selesai':
        return Colors.green;
      case 'open':
      default:
        return Colors.blueGrey;
    }
  }

  String _fmtDT(DateTime dt) {
    String p2(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${p2(dt.month)}-${p2(dt.day)} ${p2(dt.hour)}:${p2(dt.minute)}';
  }

  Widget _statusChip(String? raw) {
    final text = _prettyStatus(raw);
    final color = _statusColor(raw);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        border: Border.all(color: color.withOpacity(.6)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _h(String title, double w) => SizedBox(
        width: w,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text('', style: TextStyle(fontWeight: FontWeight.w600)),
        ),
      );

  DataCell _cell(Widget child, double w) =>
      DataCell(SizedBox(width: w, child: Align(alignment: Alignment.centerLeft, child: child)));

  @override
  Widget build(BuildContext context) {
    const wTanggal = 220.0;
    const wTps = 240.0;
    const wStatus = 140.0;

    const columnSpacing = 32.0;
    const horizontalMargin = 18.0;

    final uid = rf.auth.currentUser?.uid;
    if (uid == null) {
      return const Center(child: Text('Pengguna belum login.'));
    }

    final stream = rf.db
        .collection('reports')
        .where('by', isEqualTo: uid)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots();

    Widget head(String title, double w) => SizedBox(
          width: w,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'RIWAYAT LAPORAN SAYA',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text('Gagal memuat data.\n${snap.error}'),
                  );
                }
                if (!snap.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('Belum ada laporan.')),
                  );
                }

                final rows = <DataRow>[];
                for (var i = 0; i < docs.length; i++) {
                  final x = docs[i].data();

                  final ts = x['createdAt'];
                  final created = (ts is Timestamp) ? _fmtDT(ts.toDate()) : '-';

                  final tps = (x['tps'] ?? x['tpsName'] ?? '-').toString();
                  final status = (x['status'] ?? 'open').toString();

                  rows.add(
                    DataRow(
                      color: WidgetStatePropertyAll(
                        i.isOdd ? Colors.black.withOpacity(.02) : Colors.transparent,
                      ),
                      cells: [
                        _cell(Text(created), wTanggal),
                        _cell(Text(tps), wTps),
                        _cell(_statusChip(status), wStatus),
                      ],
                    ),
                  );
                }

                return LayoutBuilder(
                  builder: (context, c) {
                    final minWidth =
                        wTanggal + wTps + wStatus + (columnSpacing * 2) + (horizontalMargin * 2);
                    final width = c.maxWidth < minWidth ? minWidth : c.maxWidth;

                    return ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: width,
                          child: DataTableTheme(
                            data: const DataTableThemeData(
                              dataRowMinHeight: 56,
                              dataRowMaxHeight: 64,
                            ),
                            child: DataTable(
                              columnSpacing: columnSpacing,
                              horizontalMargin: horizontalMargin,
                              dividerThickness: .8,
                              columns: [
                                DataColumn(label: head('Tanggal', wTanggal)),
                                DataColumn(label: head('TPS', wTps)),
                                DataColumn(label: head('Status', wStatus)),
                              ],
                              rows: rows,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

/// ===================================================================
/// PROFIL
/// ===================================================================
class _Profile extends StatelessWidget {
  final RoleFirebase rf;
  const _Profile({required this.rf});

  @override
  Widget build(BuildContext context) {
    final u = rf.auth.currentUser;
    if (u == null) return const Center(child: Text('Pengguna belum login.'));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'PROFIL',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Center(
          child: Column(
            children: [
              const CircleAvatar(radius: 44, child: Icon(Icons.person, size: 40)),
              const SizedBox(height: 12),
              Text(u.email ?? '-', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              FilledButton.tonal(
                onPressed: () async {
                  await rf.auth.signOut();
                  if (context.mounted) {
                    Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
                  }
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
