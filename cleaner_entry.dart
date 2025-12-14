import 'package:flutter/material.dart';
import 'firebase_role.dart';
import 'cleaner_dashboard.dart';

class CleanerEntry extends StatelessWidget {
  const CleanerEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RoleFirebase>(
      future: RoleFirebase.init(AppRole.cleaner),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final rf = snap.data!;
        return CleanerGate(
          rf: rf,
          child: CleanerDashboard(rf: rf),
        );
      },
    );
  }
}

class CleanerGate extends StatelessWidget {
  const CleanerGate({super.key, required this.rf, required this.child});

  final RoleFirebase rf;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final u = rf.auth.currentUser;
    if (u == null) {
      return const Scaffold(
        body: Center(child: Text('Belum login sebagai petugas. Silakan login ulang.')),
      );
    }

    // Gate: pastikan user ini benar2 role cleaner (opsional tapi sangat disarankan)
    return FutureBuilder(
      future: rf.db.collection('users').doc(u.uid).get(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final doc = snap.data!;
        final data = doc.data() as Map<String, dynamic>?;

        final role = (data?['role'] ?? '').toString().toLowerCase();
        final status = (data?['status'] ?? '').toString().toLowerCase();

        final okRole = role.isEmpty ? true : (role == 'cleaner');
        final okStatus = status.isEmpty ? true : (status == 'approved');

        if (!doc.exists || !okRole || !okStatus) {
          return const Scaffold(
            body: Center(
              child: Text('Permission denied: akun ini bukan petugas / belum disetujui.'),
            ),
          );
        }
        return child;
      },
    );
  }
}
