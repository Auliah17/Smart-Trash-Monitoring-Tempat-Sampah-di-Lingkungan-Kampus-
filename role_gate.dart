import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminGate extends StatelessWidget {
  const AdminGate({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnap) {
        if (authSnap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final user = authSnap.data;
        if (user == null) {
          return const _GateMessage(
            title: 'Belum login',
            message: 'Silakan login sebagai admin terlebih dahulu.',
          );
        }

        final adminDoc =
            FirebaseFirestore.instance.collection('admins').doc(user.uid);

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: adminDoc.snapshots(),
          builder: (context, adminSnap) {
            if (adminSnap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (adminSnap.hasError) {
              return _GateMessage(
                title: 'Gagal cek admin',
                message: 'Error: ${adminSnap.error}',
              );
            }

            final exists = adminSnap.data?.exists == true;
            final data = adminSnap.data?.data() ?? {};
            final roleOk = (data['role'] ?? '') == 'admin';
            final approved = (data['status'] ?? '') == 'approved';

            if (!exists || !roleOk || !approved) {
              return const _GateMessage(
                title: 'Akses ditolak',
                message:
                    'Akun ini bukan admin / belum approved. Silakan login dengan akun admin yang benar.',
              );
            }

            return child;
          },
        );
      },
    );
  }
}

class _GateMessage extends StatelessWidget {
  const _GateMessage({required this.title, required this.message});
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(message),
                const SizedBox(height: 12),
                FilledButton.tonal(
                  onPressed: () async {
                    await FirebaseAuth.instance.signOut();
                    if (context.mounted) {
                      Navigator.pushNamedAndRemoveUntil(
                          context, '/', (r) => false);
                    }
                  },
                  child: const Text('Kembali / Login Ulang'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
