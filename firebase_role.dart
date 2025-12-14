// lib/firebase_role.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum AppRole { admin, cleaner, campus }

class RoleFirebase {
  final FirebaseAuth auth;
  final FirebaseFirestore db;

  const RoleFirebase._(this.auth, this.db);

  static final RoleFirebase instance = RoleFirebase._(
    FirebaseAuth.instance,
    FirebaseFirestore.instance,
  );

  /// Kompatibel dengan kode kamu yang memanggil RoleFirebase.init(role)
  static Future<RoleFirebase> init(AppRole role) async => instance;

  static AppRole parseRole(dynamic raw) {
    final s = (raw ?? '').toString().trim().toLowerCase();
    if (s == 'admin') return AppRole.admin;
    if (s == 'cleaner' || s == 'petugas') return AppRole.cleaner;
    return AppRole.campus;
  }
}
