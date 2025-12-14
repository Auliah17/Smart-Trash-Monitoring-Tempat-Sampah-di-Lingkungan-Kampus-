// lib/cleaner_dashboard.dart
// UI Petugas (Cleaner) — Dashboard + Monitoring + Riwayat + Profil
//
// REVISI FINAL (SOFT-HIDE):
// ✅ Tombol HAPUS di Cleaner Dashboard TIDAK menghapus data pusat
// ✅ Implementasi soft-hide:
//    - set merge field `hiddenByCleaners: arrayUnion([uid])` + `hiddenAt`
//    - CleanerDashboard mem-filter dokumen yang sudah di-hide oleh uid ini
// ✅ Laporan (reports) & Riwayat (cleaner_histories) di-hide per cleaner
//
// Tetap mempertahankan semua revisi sebelumnya:
// ✅ Mingguan (Senin–Minggu) untuk statistik & grafik
// ✅ Hapus titik merah chart, label hari rapi, interval Y rapi
// ✅ FIX simpan profil: pakai `photoUrl` + update() fallback set merge

import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart' show WidgetStatePropertyAll;
import 'package:image_picker/image_picker.dart';
import 'package:fl_chart/fl_chart.dart';

// Tambahan untuk UNDUH CSV riwayat
import 'package:file_saver/file_saver.dart';
import 'package:csv/csv.dart';

import 'firebase_role.dart';

class CleanerDashboard extends StatefulWidget {
  final RoleFirebase rf;
  const CleanerDashboard({super.key, required this.rf});

  @override
  State<CleanerDashboard> createState() => _CleanerDashboardState();
}

class _CleanerDashboardState extends State<CleanerDashboard> {
  int _idx = 0;

  @override
  Widget build(BuildContext context) {
    final rf = widget.rf;

    final pages = [
      _HomePage(rf: rf),
      _MonitoringPage(rf: rf),
      _HistoryPage(rf: rf),
      _ProfilePage(rf: rf),
    ];

    final labels = ['Beranda', 'Monitoring', 'Riwayat', 'Profil'];
    final icons = [
      Icons.home_rounded,
      Icons.analytics_rounded,
      Icons.receipt_long_rounded,
      Icons.person_rounded,
    ];

    return Scaffold(
      body: SafeArea(
        child: IndexedStack(index: _idx, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _idx,
        onDestinationSelected: (i) => setState(() => _idx = i),
        destinations: List.generate(
          4,
          (i) => NavigationDestination(icon: Icon(icons[i]), label: labels[i]),
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////////////////////////
// BERANDA (DASHBOARD)
//////////////////////////////////////////////////////////////////////////////
class _HomePage extends StatelessWidget {
  const _HomePage({required this.rf});
  final RoleFirebase rf;

  DateTime get _today => DateTime.now();

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
        'Desember',
      ][m - 1];

  @override
  Widget build(BuildContext context) {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Pengguna belum login.'));

    final qPie = rf.db
        .collection('cleaner_histories')
        .where('cleanerId', isEqualTo: uid)
        .snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'DASHBOARD',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),

        _PickupStatsFromHistory(rf: rf),
        const SizedBox(height: 16),

        Text(
          'Distribusi Jenis Sampah Yang Sudah Diangkut',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: qPie,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const SizedBox(
                    height: 210,
                    child: Center(child: Text('Gagal memuat data.')),
                  );
                }
                if (!snap.hasData) {
                  return const SizedBox(
                    height: 210,
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                // Filter: hanya yang tidak di-hide oleh cleaner ini
                final visibleDocs = snap.data!.docs.where((d) {
                  final data = d.data();
                  return !_isHiddenForCleaner(data, uid);
                }).toList();

                int organik = 0, non = 0;
                for (final d in visibleDocs) {
                  final j = (d.data()['type']?.toString() ?? '').toLowerCase();
                  if (j == 'organik') {
                    organik++;
                  } else if (j.contains('non') || j.contains('anorganik')) {
                    non++;
                  }
                }

                final total = organik + non;
                if (total == 0) {
                  return const SizedBox(
                    height: 210,
                    child: Center(child: Text('Belum ada riwayat pengangkutan.')),
                  );
                }

                final pctOrg = organik / total * 100;
                final pctNon = non / total * 100;

                return SizedBox(
                  height: 210,
                  child: LayoutBuilder(
                    builder: (context, c) {
                      final legendWidth = c.maxWidth < 640 ? 160.0 : 200.0;
                      return Row(
                        children: [
                          Expanded(
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                PieChart(
                                  PieChartData(
                                    sectionsSpace: 2,
                                    centerSpaceRadius: 44,
                                    sections: [
                                      PieChartSectionData(
                                        value: organik.toDouble(),
                                        color: Colors.green,
                                        radius: 60,
                                        title: '',
                                      ),
                                      PieChartSectionData(
                                        value: non.toDouble(),
                                        color: Colors.amber,
                                        radius: 60,
                                        title: '',
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${(organik / total * 100).toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 20,
                                      ),
                                    ),
                                    const Text(
                                      'Total Task',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: legendWidth,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _Legend(
                                  color: Colors.green,
                                  label: 'Organik',
                                  value: '${pctOrg.toStringAsFixed(0)}%',
                                ),
                                const SizedBox(height: 8),
                                _Legend(
                                  color: Colors.amber,
                                  label: 'Non-organik',
                                  value: '${pctNon.toStringAsFixed(0)}%',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),

        Text(
          '${_monthNameID(_today.month)} ${_today.year}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        _WeekStrip(today: _today),

        const SizedBox(height: 16),

        Text(
          'Perbandingan Mingguan (Minggu ini vs Minggu lalu)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                WeeklyCompareChart(rf: rf, cleanerId: uid),
                const SizedBox(height: 8),
                const _WeeklyLegend(),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WeeklyLegend extends StatelessWidget {
  const _WeeklyLegend();
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const _Legend(color: Colors.amber, label: 'Minggu lalu'),
        const SizedBox(width: 16),
        _Legend(color: cs.primary, label: 'Minggu ini'),
      ],
    );
  }
}

class WeeklyCompareChart extends StatelessWidget {
  const WeeklyCompareChart({super.key, required this.rf, required this.cleanerId});
  final RoleFirebase rf;
  final String cleanerId;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeekMonday(DateTime d) {
    final day0 = _startOfDay(d);
    final offset = (day0.weekday + 6) % 7; // Senin=0
    return day0.subtract(Duration(days: offset));
  }

  List<int> _countPerDay7(
    Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    DateTime wStart,
  ) {
    final buckets = List<int>.filled(7, 0);
    for (final d in docs) {
      // Filter soft-hide untuk cleaner ini
      if (_isHiddenForCleaner(d.data(), cleanerId)) continue;

      final ts = d.data()['doneAt'] as Timestamp?;
      if (ts == null) continue;
      final t = _startOfDay(ts.toDate());
      final idx = t.difference(wStart).inDays;
      if (idx >= 0 && idx < 7) buckets[idx] += 1;
    }
    return buckets;
  }

  bool _isIntTick(double v) => (v - v.roundToDouble()).abs() < 0.0001;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final now = DateTime.now();
    final thisWeekStart = _startOfWeekMonday(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));
    final prevWeekStart = thisWeekStart.subtract(const Duration(days: 7));

    final stream = rf.db
        .collection('cleaner_histories')
        .where('cleanerId', isEqualTo: cleanerId)
        .snapshots();

    const dow = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        if (snap.hasError) {
          return const SizedBox(
            height: 210,
            child: Center(child: Text('Gagal memuat grafik.')),
          );
        }
        if (!snap.hasData) {
          return const SizedBox(
            height: 210,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final allDocs = snap.data!.docs.where((d) {
          // Filter time window saja, soft-hide difilter saat counting
          final ts = d.data()['doneAt'] as Timestamp?;
          if (ts == null) return false;
          final t = _startOfDay(ts.toDate());
          return !t.isBefore(prevWeekStart) && t.isBefore(nextWeekStart);
        }).toList();

        final prev = _countPerDay7(
          allDocs.where((d) {
            final ts = d.data()['doneAt'] as Timestamp?;
            if (ts == null) return false;
            final t = _startOfDay(ts.toDate());
            return !t.isBefore(prevWeekStart) && t.isBefore(thisWeekStart);
          }),
          prevWeekStart,
        );

        final curr = _countPerDay7(
          allDocs.where((d) {
            final ts = d.data()['doneAt'] as Timestamp?;
            if (ts == null) return false;
            final t = _startOfDay(ts.toDate());
            return !t.isBefore(thisWeekStart) && t.isBefore(nextWeekStart);
          }),
          thisWeekStart,
        );

        final maxVal = [...prev, ...curr].fold<int>(0, (m, v) => v > m ? v : m);

        // Skala Y “pas”
        final double maxY = (maxVal <= 0) ? 4.0 : (maxVal + 2).toDouble();
        final double yInterval = (maxY <= 8) ? 1.0 : (maxY <= 16) ? 2.0 : 5.0;

        return SizedBox(
          height: 210,
          child: LineChart(
            LineChartData(
              minX: 0,
              maxX: 6,
              minY: 0,
              maxY: maxY,
              clipData: FlClipData.all(),

              // Hilangkan “titik merah” saat disentuh
              lineTouchData: const LineTouchData(
                enabled: false,
                handleBuiltInTouches: false,
              ),

              gridData: FlGridData(
                show: true,
                drawVerticalLine: true,
                verticalInterval: 1,
                horizontalInterval: yInterval,
              ),
              borderData: FlBorderData(
                show: true,
                border: Border.all(color: cs.outline.withOpacity(.35)),
              ),

              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 34,
                    interval: yInterval,
                    getTitlesWidget: (v, meta) {
                      if (!_isIntTick(v)) return const SizedBox.shrink();
                      return Text(
                        v.toInt().toString(),
                        style: const TextStyle(fontSize: 11),
                      );
                    },
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 26,
                    interval: 1,
                    getTitlesWidget: (v, meta) {
                      if (!_isIntTick(v)) return const SizedBox.shrink();
                      final i = v.toInt();
                      if (i < 0 || i > 6) return const SizedBox.shrink();
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          dow[i],
                          style: const TextStyle(fontSize: 11),
                        ),
                      );
                    },
                  ),
                ),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),

              lineBarsData: [
                _line(prev, Colors.amber),
                _line(curr, cs.primary),
              ],
            ),
          ),
        );
      },
    );
  }

  LineChartBarData _line(List<int> pts, Color color) => LineChartBarData(
        isCurved: true,
        curveSmoothness: 0.35,
        color: color,
        barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(
          show: true,
          color: color.withOpacity(.12),
        ),
        spots: List.generate(7, (i) => FlSpot(i.toDouble(), pts[i].toDouble())),
      );
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.value});
  final Color color;
  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final textStyle = Theme.of(context).textTheme.bodyMedium;

    return Row(
      mainAxisAlignment: value == null ? MainAxisAlignment.start : MainAxisAlignment.spaceBetween,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(label, style: textStyle),
          ],
        ),
        if (value != null)
          Text(
            value!,
            style: textStyle?.copyWith(fontWeight: FontWeight.w700),
          ),
      ],
    );
  }
}

class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.today});
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final t0 = DateTime(today.year, today.month, today.day);
    final items = List.generate(5, (i) => t0.add(Duration(days: i - 2)));
    const dow = ['SEN', 'SEL', 'RAB', 'KAM', 'JUM', 'SAB', 'MIN'];

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: items.map((d) {
        final isToday = d.year == today.year && d.month == today.month && d.day == today.day;
        return ChoiceChip(
          selected: isToday,
          onSelected: (_) {},
          label: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${d.day}', style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(
                dow[d.weekday - 1],
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

//////////////////////////////////////////////////////////////////////////////
// MONITORING
//////////////////////////////////////////////////////////////////////////////
class _MonitoringPage extends StatelessWidget {
  const _MonitoringPage({required this.rf});
  final RoleFirebase rf;

  String _dtShort(dynamic ts) {
    if (ts is Timestamp) {
      final d = ts.toDate();
      return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} '
          '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }
    return '-';
  }

  // ✅ Soft-hide (hapus hanya dari dashboard petugas)
  Future<void> _hideWithConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required Future<void> Function() onHide,
  }) async {
    final ok = await _confirmDialog(context, title: title, message: message);
    if (!ok) return;

    try {
      await onHide();
      if (!context.mounted) return;
      _ok(context, 'Berhasil dihapus dari dashboard petugas (data pusat tidak dihapus).');
    } catch (e) {
      if (!context.mounted) return;
      _err(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final tpsStream = rf.db.collection('tps').orderBy('name').snapshots();
    final reportsStream = rf.db
        .collection('reports')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();

    Widget tableWrapper({
      required List<DataColumn> columns,
      required List<DataRow> rows,
    }) {
      return LayoutBuilder(builder: (context, c) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Container(
            color: cs.surface,
            width: double.infinity,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: c.maxWidth),
                child: DataTableTheme(
                  data: DataTableThemeData(
                    headingRowColor: WidgetStatePropertyAll(cs.surface),
                    dataRowColor: WidgetStatePropertyAll(cs.surface),
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
      });
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'MONITORING',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),

        _PickupStatsFromHistory(rf: rf),
        const SizedBox(height: 16),

        Text('Daftar TPS', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: tpsStream,
              builder: (context, snap) {
                if (snap.hasError) return const Text('Gagal memuat TPS.');
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }
                final docs = snap.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada data TPS.'),
                  );
                }

                final rows = docs.map((d) {
                  final x = d.data();
                  final name = (x['name'] ?? '-').toString();
                  final type = (x['type'] ?? '').toString();
                  final aksi = (x['tpsStatus'] ?? 'diangkut').toString();

                  String? proofBase64 = (x['proofBase64'] as String?)?.trim();
                  final proofUrl = (x['proofUrl'] as String?)?.trim();
                  final proof = (proofBase64 != null && proofBase64.isNotEmpty)
                      ? proofBase64
                      : (proofUrl != null && proofUrl.isNotEmpty ? proofUrl : null);

                  return DataRow(cells: [
                    DataCell(Text(name)),
                    DataCell(_JenisDropdownStrict(
                      current: type,
                      onChanged: (val) async {
                        try {
                          await d.reference.update({'type': val});
                          if (!context.mounted) return;
                          _ok(context, 'Jenis TPS diperbarui');
                        } catch (e) {
                          if (!context.mounted) return;
                          _err(context, 'Gagal update jenis: $e');
                        }
                      },
                    )),
                    DataCell(_SelesaiButton(
                      status: aksi,
                      onPressed: () async {
                        try {
                          await d.reference.update({
                            'tpsStatus': 'selesai',
                            'actedAt': FieldValue.serverTimestamp(),
                          });
                          if (!context.mounted) return;
                          _ok(context, 'TPS ditandai selesai. Unggah bukti untuk finalisasi.');
                        } catch (e) {
                          if (!context.mounted) return;
                          _err(context, 'Gagal ubah aksi: $e');
                        }
                      },
                    )),
                    DataCell(_UploadBuktiCell(rf: rf, tpsDoc: d, currentProof: proof)),
                  ]);
                }).toList();

                return tableWrapper(
                  columns: const [
                    DataColumn(label: Text('TPS')),
                    DataColumn(label: Text('Jenis')),
                    DataColumn(label: Text('Aksi')),
                    DataColumn(label: Text('Bukti')),
                  ],
                  rows: rows,
                );
              },
            ),
          ),
        ),

        const SizedBox(height: 16),
        Text('Laporan Masuk Terbaru', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: reportsStream,
              builder: (context, snap) {
                if (snap.hasError) return const Text('Gagal memuat laporan.');
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }

                final uid = rf.auth.currentUser?.uid;
                final all = snap.data?.docs ?? [];

                // ✅ Filter soft-hide: hide hanya untuk cleaner ini
                final docs = (uid == null)
                    ? all
                    : all.where((d) => !_isHiddenForCleaner(d.data(), uid)).toList();

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada laporan.'),
                  );
                }

                final rows = docs.map((d) {
                  final x = d.data();
                  final created = _dtShort(x['createdAt']);
                  final tps = (x['tps'] ?? '-').toString();
                  final status = (x['status'] ?? 'open').toString();

                  return DataRow(cells: [
                    DataCell(Text(created)),
                    DataCell(Text(tps)),
                    DataCell(_StatusChip(status: status)),
                    DataCell(_AksiDropdown(
                      status: status,
                      onAction: (choice) async {
                        final next = choice == 'proses' ? 'in_progress' : 'resolved';
                        try {
                          await d.reference.update({'status': next});
                          if (!context.mounted) return;
                          _ok(context, 'Status diubah ke ${_statusLabel(next)}');
                        } catch (e) {
                          if (!context.mounted) return;
                          _err(context, 'Gagal ubah status: $e');
                        }
                      },
                    )),
                    DataCell(
                      IconButton(
                        tooltip: 'Hapus (khusus dashboard petugas)',
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () {
                          final uid = rf.auth.currentUser?.uid;
                          if (uid == null) return;

                          _hideWithConfirm(
                            context,
                            title: 'Hapus dari Dashboard Petugas?',
                            message:
                                'Laporan ini hanya akan disembunyikan dari dashboard Petugas.\n'
                                'Dashboard lain (Admin/Campus) tetap bisa melihat.\n\n'
                                'TPS: $tps\nTanggal: $created',
                            onHide: () => d.reference.set({
                              'hiddenByCleaners': FieldValue.arrayUnion([uid]),
                              'hiddenAt': FieldValue.serverTimestamp(),
                            }, SetOptions(merge: true)),
                          );
                        },
                      ),
                    ),
                  ]);
                }).toList();

                return tableWrapper(
                  columns: const [
                    DataColumn(label: Text('Tanggal')),
                    DataColumn(label: Text('TPS')),
                    DataColumn(label: Text('Status')),
                    DataColumn(label: Text('Aksi')),
                    DataColumn(label: Text('Hapus')),
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

//////////////////////////////////////////////////////////////////////////////
// RIWAYAT (table + UNDUH CSV)
//////////////////////////////////////////////////////////////////////////////
class _HistoryPage extends StatelessWidget {
  const _HistoryPage({required this.rf});
  final RoleFirebase rf;

  Future<void> _downloadCsv(BuildContext context) async {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return;

    try {
      final snap = await rf.db.collection('cleaner_histories').where('cleanerId', isEqualTo: uid).get();

      var docs = snap.docs.toList();

      // ✅ Filter soft-hide
      docs = docs.where((d) => !_isHiddenForCleaner(d.data(), uid)).toList();

      docs.sort((a, b) {
        final ta = a.data()['doneAt'] as Timestamp?;
        final tb = b.data()['doneAt'] as Timestamp?;
        if (ta == null && tb == null) return 0;
        if (ta == null) return 1;
        if (tb == null) return -1;
        return tb.compareTo(ta);
      });

      final rows = <List<dynamic>>[
        ['waktu', 'tpsName', 'type'],
      ];

      for (final d in docs) {
        final x = d.data();
        final ts = x['doneAt'] as Timestamp?;
        final waktu = ts?.toDate().toIso8601String() ?? '';
        final tps = (x['tpsName'] ?? '').toString();
        final jenis = (x['type'] ?? '').toString();
        rows.add([waktu, tps, jenis]);
      }

      final csvStr = const ListToCsvConverter().convert(rows);
      final bytes = Uint8List.fromList(utf8.encode(csvStr));
      final baseName = 'riwayat_cleaner_${DateTime.now().toIso8601String().replaceAll(":", "-")}';

      await FileSaver.instance.saveFile(
        name: baseName,
        bytes: bytes,
        ext: 'csv',
        mimeType: MimeType.text,
      );

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('CSV berhasil disimpan.')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh: $e'), backgroundColor: Colors.red),
      );
    }
  }

  // ✅ Soft-hide riwayat (hapus hanya dari dashboard petugas)
  Future<void> _hideHistoryRow(
    BuildContext context,
    QueryDocumentSnapshot<Map<String, dynamic>> d, {
    required String tps,
    required String when,
  }) async {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return;

    final ok = await _confirmDialog(
      context,
      title: 'Hapus dari Dashboard Petugas?',
      message:
          'Riwayat ini hanya akan disembunyikan dari dashboard Petugas.\n'
          'Dashboard lain tetap bisa melihat.\n\nTPS: $tps\nWaktu: $when',
    );
    if (!ok) return;

    try {
      await d.reference.set({
        'hiddenByCleaners': FieldValue.arrayUnion([uid]),
        'hiddenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!context.mounted) return;
      _ok(context, 'Riwayat disembunyikan dari dashboard petugas.');
    } catch (e) {
      if (!context.mounted) return;
      _err(context, 'Gagal: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return const Center(child: Text('Pengguna belum login.'));

    final stream = rf.db.collection('cleaner_histories').where('cleanerId', isEqualTo: uid).limit(100).snapshots();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'RIWAYAT',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: () => _downloadCsv(context),
              icon: const Icon(Icons.download_rounded),
              label: const Text('Unduh Riwayat (CSV)'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: stream,
              builder: (context, snap) {
                if (snap.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Gagal memuat riwayat.'),
                  );
                }
                if (snap.connectionState == ConnectionState.waiting) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: LinearProgressIndicator(),
                  );
                }

                var docs = snap.data?.docs.toList() ?? [];

                // ✅ Filter soft-hide
                docs = docs.where((d) => !_isHiddenForCleaner(d.data(), uid)).toList();

                docs.sort((a, b) {
                  final ta = a.data()['doneAt'] as Timestamp?;
                  final tb = b.data()['doneAt'] as Timestamp?;
                  if (ta == null && tb == null) return 0;
                  if (ta == null) return 1;
                  if (tb == null) return -1;
                  return tb.compareTo(ta);
                });

                if (docs.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(12),
                    child: Text('Belum ada riwayat.'),
                  );
                }

                final rows = docs.map((d) {
                  final x = d.data();
                  final doneAtStr = (x['doneAt'] as Timestamp?)?.toDate().toString().substring(0, 16) ?? '-';
                  final tps = (x['tpsName'] ?? '-').toString();
                  final jenis = (x['type'] ?? '-').toString();

                  String? proof;
                  final b64 = (x['proofBase64'] as String?)?.trim();
                  final url = (x['proofUrl'] as String?)?.trim();
                  if (b64 != null && b64.isNotEmpty) {
                    proof = b64;
                  } else if (url != null && url.isNotEmpty) {
                    proof = url;
                  }

                  return DataRow(cells: [
                    DataCell(Text(doneAtStr)),
                    DataCell(Text(tps)),
                    DataCell(Text(jenis)),
                    DataCell(_ProofThumb(value: proof)),
                    DataCell(
                      IconButton(
                        tooltip: 'Hapus (khusus dashboard petugas)',
                        icon: Icon(Icons.delete_outline, color: cs.error),
                        onPressed: () => _hideHistoryRow(context, d, tps: tps, when: doneAtStr),
                      ),
                    ),
                  ]);
                }).toList();

                return LayoutBuilder(builder: (context, c) {
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      color: cs.surface,
                      width: double.infinity,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(minWidth: c.maxWidth),
                          child: DataTableTheme(
                            data: DataTableThemeData(
                              headingRowColor: WidgetStatePropertyAll(cs.surface),
                              dataRowColor: WidgetStatePropertyAll(cs.surface),
                              dividerThickness: 0.7,
                            ),
                            child: DataTable(
                              columns: const [
                                DataColumn(label: Text('Waktu')),
                                DataColumn(label: Text('TPS')),
                                DataColumn(label: Text('Jenis')),
                                DataColumn(label: Text('Bukti')),
                                DataColumn(label: Text('Hapus')),
                              ],
                              rows: rows,
                              columnSpacing: 24,
                              horizontalMargin: 16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}

//////////////////////////////////////////////////////////////////////////////
// PROFIL  (FIX RULES: simpan foto ke `photoUrl` bukan `avatarBase64`)
//////////////////////////////////////////////////////////////////////////////
class _ProfilePage extends StatefulWidget {
  const _ProfilePage({required this.rf});
  final RoleFirebase rf;

  @override
  State<_ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<_ProfilePage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _phone = TextEditingController();

  // ✅ Field “aman” untuk rules: photoUrl (URL atau data:image;base64)
  String _photoUrl = '';

  // legacy
  String _legacyAvatarUrl = '';
  String _legacyAvatarBase64 = '';

  Uint8List? _picked;
  bool _busy = false;

  String _initialName = '';
  String _initialPhone = '';
  bool _dirty = false;

  RoleFirebase get rf => widget.rf;

  @override
  void initState() {
    super.initState();
    _loadMe();
    _name.addListener(_markDirtyIfChanged);
    _phone.addListener(_markDirtyIfChanged);
  }

  void _markDirtyIfChanged() {
    final changed = _name.text.trim() != _initialName || _phone.text.trim() != _initialPhone || (_picked != null);
    if (changed != _dirty) setState(() => _dirty = changed);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  bool _isCleanerOrPetugas(String role) {
    final r = role.toLowerCase().trim();
    return r == 'cleaner' || r == 'petugas';
  }

  Future<void> _loadMe() async {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return;

    final snap = await rf.db.collection('users').doc(uid).get();
    final d = snap.data() ?? {};

    final role = (d['role'] ?? '').toString().toLowerCase().trim();
    if (role.isNotEmpty && !_isCleanerOrPetugas(role)) {
      if (mounted) _err(context, 'Akun ini bukan petugas (role=$role).');
      return;
    }

    final name = (d['name'] ?? '').toString();
    final phone = (d['phone'] ?? '').toString();

    final photoUrl = (d['photoUrl'] ?? d['photoURL'] ?? '').toString();

    final avUrl = (d['avatarUrl'] ?? '').toString();
    final avB64 = (d['avatarBase64'] ?? '').toString();

    if (!mounted) return;
    setState(() {
      _name.text = _initialName = name;
      _phone.text = _initialPhone = phone;

      _photoUrl = photoUrl;
      _legacyAvatarUrl = avUrl;
      _legacyAvatarBase64 = avB64;

      _dirty = false;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final x = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 60,
      maxWidth: 512,
    );
    if (x == null) return;

    final bytes = await x.readAsBytes();
    if (!mounted) return;
    setState(() {
      _picked = bytes;
      _dirty = true;
    });
  }

  Uint8List? _decodeDataUrl(String raw) {
    try {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final idx = s.indexOf('base64,');
      final b64 = (idx >= 0) ? s.substring(idx + 7) : s;
      return base64Decode(b64.replaceAll(RegExp(r'\s+'), ''));
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);

    try {
      final uid = rf.auth.currentUser!.uid;

      final patch = <String, dynamic>{
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_picked != null) {
        patch['photoUrl'] = 'data:image/jpeg;base64,${base64Encode(_picked!)}';
      }

      try {
        await rf.db.collection('users').doc(uid).update(patch);
      } on FirebaseException catch (e) {
        if (e.code == 'not-found') {
          await rf.db.collection('users').doc(uid).set(patch, SetOptions(merge: true));
        } else {
          rethrow;
        }
      }

      if (!mounted) return;

      setState(() {
        if (patch.containsKey('photoUrl')) {
          _photoUrl = patch['photoUrl'] as String;
        }
        _picked = null;
        _initialName = _name.text.trim();
        _initialPhone = _phone.text.trim();
        _dirty = false;
      });

      _ok(context, 'Profil tersimpan.');
    } catch (e) {
      if (mounted) _err(context, 'Gagal menyimpan: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final u = rf.auth.currentUser;
    if (u == null) return const Center(child: Text('Pengguna belum login.'));

    ImageProvider? bg;

    if (_picked != null) {
      bg = MemoryImage(_picked!);
    } else if (_photoUrl.isNotEmpty) {
      if (_photoUrl.startsWith('data:image')) {
        final bytes = _decodeDataUrl(_photoUrl);
        if (bytes != null) bg = MemoryImage(bytes);
      } else {
        bg = NetworkImage(_photoUrl);
      }
    } else if (_legacyAvatarBase64.isNotEmpty) {
      final bytes = _decodeDataUrl(_legacyAvatarBase64);
      if (bytes != null) bg = MemoryImage(bytes);
    } else if (_legacyAvatarUrl.isNotEmpty) {
      bg = NetworkImage(_legacyAvatarUrl);
    }

    final avatar = CircleAvatar(
      radius: 48,
      backgroundImage: bg,
      child: (bg == null) ? const Icon(Icons.person, size: 42) : null,
    );

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
              avatar,
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _busy ? null : _pickImage,
                icon: const Icon(Icons.photo),
                label: const Text('Pilih Foto Profil'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _form,
          child: Column(
            children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Nama'),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: u.email ?? '-',
                enabled: false,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phone,
                decoration: const InputDecoration(labelText: 'No HP'),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              if (_dirty)
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: _busy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('SIMPAN'),
                ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: _busy
                    ? null
                    : () async {
                        await rf.auth.signOut();
                        if (!mounted) return;
                        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
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

//////////////////////////////////////////////////////////////////////////////
// SMALL WIDGETS / HELPERS
//////////////////////////////////////////////////////////////////////////////

/// ✅ Mingguan = minggu kalender (Senin–Minggu)
class _PickupStatsFromHistory extends StatelessWidget {
  const _PickupStatsFromHistory({required this.rf});
  final RoleFirebase rf;

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  DateTime _startOfWeekMonday(DateTime d) {
    final day0 = _startOfDay(d);
    final offset = (day0.weekday + 6) % 7; // Senin=0
    return day0.subtract(Duration(days: offset));
  }

  @override
  Widget build(BuildContext context) {
    final uid = rf.auth.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    final now = DateTime.now();

    final today0 = _startOfDay(now);
    final tomorrow0 = today0.add(const Duration(days: 1));

    final thisWeekStart = _startOfWeekMonday(now);
    final nextWeekStart = thisWeekStart.add(const Duration(days: 7));

    final stream = rf.db.collection('cleaner_histories').where('cleanerId', isEqualTo: uid).snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snap) {
        int todayCount = 0;
        int weekCount = 0;

        if (snap.hasData) {
          for (final d in snap.data!.docs) {
            final data = d.data();

            // ✅ Filter soft-hide
            if (_isHiddenForCleaner(data, uid)) continue;

            final ts = data['doneAt'] as Timestamp?;
            if (ts == null) continue;

            final day0 = _startOfDay(ts.toDate());

            if (!day0.isBefore(today0) && day0.isBefore(tomorrow0)) {
              todayCount++;
            }
            if (!day0.isBefore(thisWeekStart) && day0.isBefore(nextWeekStart)) {
              weekCount++;
            }
          }
        }

        return Row(
          children: [
            Expanded(
              child: _StatCard(
                title: 'Total Pengangkutan Hari Ini',
                value: '$todayCount',
                icon: Icons.local_shipping_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _StatCard(
                title: 'Total Pengangkutan Minggu Ini',
                value: '$weekCount',
                icon: Icons.calendar_month_rounded,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JenisDropdownStrict extends StatelessWidget {
  const _JenisDropdownStrict({
    required this.current,
    required this.onChanged,
  });

  final String current;
  final void Function(String) onChanged;

  @override
  Widget build(BuildContext context) {
    final allowed = {'organik', 'non-organik'};
    final val = allowed.contains(current.toLowerCase()) ? current.toLowerCase() : null;

    return DropdownButton<String>(
      value: val,
      hint: const Text('Pilih'),
      items: const [
        DropdownMenuItem(value: 'organik', child: Text('Organik')),
        DropdownMenuItem(value: 'non-organik', child: Text('Non-organik')),
      ],
      onChanged: (v) {
        if (v == null) return;
        onChanged(v);
      },
    );
  }
}

class _SelesaiButton extends StatelessWidget {
  const _SelesaiButton({required this.status, required this.onPressed});

  final String status;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = status.toLowerCase();
    final done = s == 'selesai';

    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(
        done ? Icons.check_circle : Icons.local_shipping_rounded,
        size: 18,
        color: done ? Colors.green : Colors.grey.shade700,
      ),
      label: Text(
        'Selesai',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: done ? Colors.green.shade800 : Colors.grey.shade700,
        ),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        shape: const StadiumBorder(),
        backgroundColor: done ? Colors.green.withOpacity(.15) : Colors.grey.withOpacity(.08),
        side: BorderSide(
          color: done ? Colors.green.withOpacity(.35) : Colors.grey.withOpacity(.35),
        ),
      ),
    );
  }
}

class _UploadBuktiCell extends StatefulWidget {
  const _UploadBuktiCell({
    required this.rf,
    required this.tpsDoc,
    this.currentProof,
  });

  final RoleFirebase rf;
  final QueryDocumentSnapshot<Map<String, dynamic>> tpsDoc;
  final String? currentProof;

  @override
  State<_UploadBuktiCell> createState() => _UploadBuktiCellState();
}

class _UploadBuktiCellState extends State<_UploadBuktiCell> {
  bool _busy = false;

  Future<void> _pickAndUpload() async {
    try {
      setState(() => _busy = true);

      final x = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 1280,
      );
      if (x == null) {
        if (mounted) setState(() => _busy = false);
        return;
      }

      final bytes = await x.readAsBytes();
      final dataUrl = 'data:image/jpeg;base64,${base64Encode(bytes)}';

      await widget.tpsDoc.reference.update({
        'proofBase64': dataUrl,
        'proofAt': FieldValue.serverTimestamp(),
      });

      final snap = await widget.tpsDoc.reference.get();
      final d = snap.data() ?? {};
      final uid = widget.rf.auth.currentUser?.uid;
      if (uid == null) throw Exception('User belum login');

      await widget.rf.db.collection('cleaner_histories').add({
        'tpsId': widget.tpsDoc.id,
        'tpsName': (d['name'] ?? '').toString(),
        'type': (d['type'] ?? '').toString(),
        'proofBase64': dataUrl,
        'doneAt': FieldValue.serverTimestamp(),
        'cleanerId': uid,

        // ✅ Default soft-hide list (jelas)
        'hiddenByCleaners': const [],
      });

      await widget.tpsDoc.reference.update({
        'tpsStatus': 'diangkut',
        'proofBase64': FieldValue.delete(),
        'proofUrl': FieldValue.delete(),
        'actedAt': FieldValue.serverTimestamp(),
      });

      if (!mounted) return;
      _ok(context, 'Bukti terunggah. TPS direset & riwayat tersimpan.');
    } catch (e) {
      if (mounted) _err(context, 'Gagal upload: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final has = (widget.currentProof != null && widget.currentProof!.isNotEmpty);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        OutlinedButton.icon(
          onPressed: _busy ? null : _pickAndUpload,
          icon: _busy
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.upload),
          label: const Text('Upload Bukti'),
        ),
        if (has) const SizedBox(width: 6),
        if (has)
          IconButton(
            tooltip: 'Lihat',
            onPressed: () {
              final v = widget.currentProof!;
              Widget imageWidget;
              if (v.startsWith('data:image')) {
                final b64 = v.split(',').last;
                imageWidget = Image.memory(base64Decode(b64), fit: BoxFit.contain);
              } else {
                imageWidget = Image.network(v, fit: BoxFit.contain);
              }
              showDialog(
                context: context,
                builder: (_) => Dialog(child: InteractiveViewer(child: imageWidget)),
              );
            },
            icon: const Icon(Icons.visibility_rounded),
          ),
      ],
    );
  }
}

class _AksiDropdown extends StatelessWidget {
  const _AksiDropdown({required this.status, required this.onAction});

  final String status;
  final void Function(String) onAction;

  @override
  Widget build(BuildContext context) {
    final disabled = status == 'resolved';
    String? current;
    if (status == 'in_progress') current = 'proses';
    if (status == 'resolved') current = 'selesai';

    return DropdownButton<String>(
      value: current,
      hint: const Text('Pilih'),
      items: const [
        DropdownMenuItem(value: 'proses', child: Text('Proses')),
        DropdownMenuItem(value: 'selesai', child: Text('Selesai')),
      ],
      onChanged: disabled
          ? null
          : (val) {
              if (val == null) return;
              onAction(val);
            },
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});
  final String status;

  Color _bg() {
    switch (status) {
      case 'open':
        return Colors.orange.withOpacity(.15);
      case 'in_progress':
        return Colors.blue.withOpacity(.15);
      case 'resolved':
        return Colors.green.withOpacity(.15);
      default:
        return Colors.grey.withOpacity(.15);
    }
  }

  Color _fg() {
    switch (status) {
      case 'open':
        return Colors.orange.shade800;
      case 'in_progress':
        return Colors.blue.shade800;
      case 'resolved':
        return Colors.green.shade800;
      default:
        return Colors.grey.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: _bg(), borderRadius: BorderRadius.circular(999)),
      child: Text(
        _statusLabel(status),
        style: TextStyle(fontWeight: FontWeight.w600, color: _fg()),
      ),
    );
  }
}

String _statusLabel(String v) {
  switch (v) {
    case 'open':
      return 'Open';
    case 'in_progress':
      return 'Proses';
    case 'resolved':
      return 'Selesai';
    default:
      return v;
  }
}

void _ok(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(msg)));

void _err(BuildContext c, String msg) => ScaffoldMessenger.of(c).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: Colors.red),
    );

Future<bool> _confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return result ?? false;
}

//////////////////////////////////////////////////////////////////////////////
// SOFT-HIDE HELPERS (PENTING)
// - `hiddenByCleaners`: array of uid yang menyembunyikan dokumen ini
// - `hiddenAt`: timestamp terakhir penyembunyian (opsional)
//////////////////////////////////////////////////////////////////////////////
List<String> _asStringList(dynamic v) {
  if (v == null) return const [];
  if (v is Iterable) return v.map((e) => e.toString()).toList();
  return const [];
}

bool _isHiddenForCleaner(Map<String, dynamic> data, String uid) {
  final hiddenBy = _asStringList(data['hiddenByCleaners']);
  return hiddenBy.contains(uid);
}

//////////////////////////////////////////////////////////////////////////////
// THUMBNAIL BUKTI UNTUK TABEL RIWAYAT
//////////////////////////////////////////////////////////////////////////////
class _ProofThumb extends StatelessWidget {
  const _ProofThumb({required this.value});
  final String? value;

  bool get _isDataUrl => value != null && value!.startsWith('data:image');

  Uint8List? _decodeDataUrl() {
    try {
      final b64 = value!.split(',').last;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (value == null || value!.isEmpty) return const Text('-');

    Widget thumb;
    if (_isDataUrl) {
      final bytes = _decodeDataUrl();
      if (bytes == null) return const Text('-');
      thumb = Image.memory(bytes, fit: BoxFit.cover, width: 48, height: 48);
    } else {
      thumb = Image.network(value!, fit: BoxFit.cover, width: 48, height: 48);
    }

    return InkWell(
      onTap: () {
        Widget full;
        if (_isDataUrl) {
          final bytes = _decodeDataUrl();
          if (bytes == null) return;
          full = Image.memory(bytes, fit: BoxFit.contain);
        } else {
          full = Image.network(value!, fit: BoxFit.contain);
        }
        showDialog(
          context: context,
          builder: (_) => Dialog(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: InteractiveViewer(child: full),
            ),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Container(
          width: 48,
          height: 48,
          color: Colors.grey.shade200,
          child: thumb,
        ),
      ),
    );
  }
}
