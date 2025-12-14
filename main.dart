// lib/main.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'firebase_options.dart';
import 'firebase_role.dart';

import 'welcome_page.dart';
import 'login_page.dart';
import 'register_page.dart';

import 'cleaner_dashboard.dart';
import 'campus_dashboard.dart';
import 'admin_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // IMPORTANT (WEB): agar 2 akun di tab berbeda tidak saling menimpa session login
  if (kIsWeb) {
    await FirebaseAuth.instance.setPersistence(Persistence.SESSION);
    // Alternatif paling ketat (refresh -> logout):
    // await FirebaseAuth.instance.setPersistence(Persistence.NONE);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => const TrashWashApp();
}

class TrashWashApp extends StatelessWidget {
  const TrashWashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TrashWash',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0E2A47)),
        scaffoldBackgroundColor: const Color(0xFFAEE5E1),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.black.withValues(alpha: .2)),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
        cardTheme: const CardThemeData(
          color: Color(0xFFF1F5F8),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => const WelcomePage(),

        // Universal
        '/login': (_) => const LoginPage(),
        '/register': (_) => const RegisterPage(),

        // Auto-route sesuai role dari Firestore
        '/home': (_) => const _AutoDashboardGate(),

        // Direct dashboard (kalau user buka /admin dsb, tetap dicek role)
        '/admin': (_) => const _RoleDashboardGate(requiredRole: AppRole.admin),
        '/cleaner': (_) => const _RoleDashboardGate(requiredRole: AppRole.cleaner),
        '/campus': (_) => const _RoleDashboardGate(requiredRole: AppRole.campus),

        // Alias lama
        '/login_admin': (_) => const LoginPage(),
        '/login_cleaner': (_) => const LoginPage(),
        '/login_campus': (_) => const LoginPage(),
        '/register_admin': (_) => const RegisterPage(),
        '/register_cleaner': (_) => const RegisterPage(),
        '/register_campus': (_) => const RegisterPage(),
      },
    );
  }
}

/// Ambil role dari Firestore: users/{uid}.role
Future<AppRole> _fetchRole(RoleFirebase rf) async {
  final uid = rf.auth.currentUser?.uid;
  if (uid == null) return AppRole.campus;

  final ds = await rf.db.collection('users').doc(uid).get();
  final data = ds.data();
  return RoleFirebase.parseRole(data?['role']);
}

/// Gate: kalau sudah login → lempar ke dashboard sesuai role
class _AutoDashboardGate extends StatelessWidget {
  const _AutoDashboardGate();

  @override
  Widget build(BuildContext context) {
    final rf = RoleFirebase.instance;

    return StreamBuilder<User?>(
      stream: rf.auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<AppRole>(
          future: _fetchRole(rf),
          builder: (context, rs) {
            if (rs.hasError) {
              return _GateError(message: 'Gagal membaca role: ${rs.error}');
            }
            if (!rs.hasData) {
              return const _GateLoading();
            }

            final role = rs.data!;
            if (role == AppRole.admin) return AdminDashboard(rf: rf);
            if (role == AppRole.cleaner) return CleanerDashboard(rf: rf);
            return CampusDashboard(rf: rf);
          },
        );
      },
    );
  }
}

/// Gate: route /admin /cleaner /campus harus sesuai role
class _RoleDashboardGate extends StatelessWidget {
  const _RoleDashboardGate({required this.requiredRole});
  final AppRole requiredRole;

  @override
  Widget build(BuildContext context) {
    final rf = RoleFirebase.instance;

    return StreamBuilder<User?>(
      stream: rf.auth.authStateChanges(),
      builder: (context, snap) {
        final user = snap.data;
        if (user == null) return const LoginPage();

        return FutureBuilder<AppRole>(
          future: _fetchRole(rf),
          builder: (context, rs) {
            if (rs.hasError) {
              return _GateError(message: 'Gagal membaca role: ${rs.error}');
            }
            if (!rs.hasData) return const _GateLoading();

            final role = rs.data!;
            if (role != requiredRole) {
              return _GateError(
                message: 'Akun ini bukan ${requiredRole.name}. Silakan login dengan akun yang benar.',
              );
            }

            if (role == AppRole.admin) return AdminDashboard(rf: rf);
            if (role == AppRole.cleaner) return CleanerDashboard(rf: rf);
            return CampusDashboard(rf: rf);
          },
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _GateError extends StatelessWidget {
  const _GateError({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    '/login',
                    (r) => false,
                  ),
                  child: const Text('Kembali ke Login'),
                ),
              ],
            ),
          ),
        ),
      );
}
