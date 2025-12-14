import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _ob = true;
  bool _loading = false;
  bool _resetting = false;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  void _back() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false);
    }
  }

  bool _isApproved(dynamic raw) {
    if (raw == null) return false;
    if (raw is bool) return raw;

    final s = raw.toString().toLowerCase().trim();

    const ok = <String>{
      'approved',
      'approve',
      'acc',
      'accepted',
      'aktif',
      'active',
      'disetujui',
      'true',
      '1',
      'yes',
      'ya',
      'ok',
    };
    return ok.contains(s);
  }

  bool _isCleanerRole(String role) {
    final r = role.toLowerCase().trim();
    return r == 'cleaner' || r == 'petugas';
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _loadProfile({
    required String uid,
    required String email,
  }) async {
    final users = _db.collection('users');

    final uByUid = await users.doc(uid).get();
    if (uByUid.exists) return uByUid;

    final qU = await users.where('email', isEqualTo: email).limit(1).get();
    if (qU.docs.isNotEmpty) return qU.docs.first;

    final admins = _db.collection('admins');
    final qA = await admins.where('email', isEqualTo: email).limit(1).get();
    if (qA.docs.isNotEmpty) {
      final a = qA.docs.first.data();
      await users.doc(uid).set({
        ...a,
        'uid': uid,
        'email': email,
        'role': 'admin',
        'status': 'approved',
        'approved': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      return await users.doc(uid).get();
    }

    return null;
  }

  String _routeForRole(String role) {
    final r = role.toLowerCase().trim();
    if (r == 'admin') return '/admin';
    if (_isCleanerRole(r)) return '/cleaner';
    return '/campus';
  }

  Future<void> _login() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();

      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: _pass.text,
      );

      final uid = cred.user?.uid;
      if (uid == null) {
        await _auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gagal login (UID tidak ditemukan).')),
        );
        return;
      }

      final prof = await _loadProfile(uid: uid, email: email);
      if (prof == null || !prof.exists) {
        await _auth.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil pengguna tidak ditemukan di Firestore.')),
        );
        return;
      }

      final data = prof.data() ?? {};
      final role = (data['role'] ?? '').toString().toLowerCase().trim();

      if (_isCleanerRole(role)) {
        final approved = _isApproved(data['approved']) || _isApproved(data['status']);
        if (!approved) {
          await _auth.signOut();
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Akun petugas belum disetujui admin.')),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, _routeForRole(role), (_) => false);
    } on FirebaseAuthException catch (e) {
      final msg = (e.code == 'invalid-credential' ||
              e.code == 'wrong-password' ||
              e.code == 'user-not-found')
          ? 'Email / kata sandi salah.'
          : (e.message ?? 'Gagal login.');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Kesalahan: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resetPassword() async {
    final email = _email.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan email yang valid dulu.')),
      );
      return;
    }

    setState(() => _resetting = true);

    try {
      final acs = ActionCodeSettings(
        url: 'http://localhost:58011/#/login',
        handleCodeInApp: false,
      );

      await _auth.sendPasswordResetEmail(
        email: email,
        actionCodeSettings: acs,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Permintaan reset terkirim. Cek inbox/spam: $email'),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;

      String msg;
      switch (e.code) {
        case 'invalid-email':
          msg = 'Format email tidak valid.';
          break;
        case 'unauthorized-continue-uri':
          msg =
              'Domain belum diizinkan untuk reset password.\n'
              'Buka Firebase Console → Authentication → Settings → Authorized domains,\n'
              'tambahkan: localhost (dan domain hosting Anda).';
          break;
        case 'too-many-requests':
          msg = 'Terlalu banyak permintaan. Coba lagi beberapa saat.';
          break;
        default:
          msg = e.message ?? 'Gagal mengirim reset password.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg)),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kesalahan: $e')),
      );
    } finally {
      if (mounted) setState(() => _resetting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: (_loading || _resetting) ? null : _back,
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      'LOGIN',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Gmail'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass,
                    obscureText: _ob,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob = !_ob),
                        icon: Icon(_ob ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) => (v == null || v.isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: (_loading || _resetting) ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('MASUK'),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: (_loading || _resetting) ? null : _resetPassword,
                      child: _resetting ? const Text('Mengirim...') : const Text('Lupa kata sandi?'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: (_loading || _resetting)
                        ? null
                        : () => Navigator.pushReplacementNamed(context, '/register'),
                    child: const Text('Belum punya akun? DAFTAR'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
