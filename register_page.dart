import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

enum RegisterRole { campus, cleaner }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _cleanerId = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  bool _ob1 = true, _ob2 = true, _loading = false;
  RegisterRole _role = RegisterRole.campus;

  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  bool get _isCleaner => _role == RegisterRole.cleaner;
  String get _title => _isCleaner ? 'DAFTAR PETUGAS' : 'DAFTAR CAMPUS';

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _cleanerId.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  void _snack(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: error ? Colors.red : null),
    );
  }

  Future<void> _back() async {
    final canPop = Navigator.of(context).canPop();
    if (canPop) {
      Navigator.of(context).pop();
    } else {
      // fallback bila halaman ini jadi root
      Navigator.pushReplacementNamed(context, '/welcome'); // ganti jika route Anda berbeda
    }
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);

    try {
      final email = _email.text.trim();
      final password = _pass.text;

      // Firebase Auth: otomatis login setelah create
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = cred.user!.uid;
      final roleStr = _isCleaner ? 'cleaner' : 'campus';

      // Simpan profile user
      await _db.collection('users').doc(uid).set({
        'uid': uid,
        'name': _name.text.trim(),
        'email': email,
        'phone': _phone.text.trim(),
        'role': roleStr,
        if (_isCleaner) 'cleanerId': _cleanerId.text.trim(),

        // petugas: pending; campus: langsung approved (tanpa persetujuan)
        'status': _isCleaner ? 'pending' : 'approved',
        'approved': _isCleaner ? false : true,

        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // KUNCI: agar setelah daftar tidak langsung masuk dashboard
      await _auth.signOut();

      if (!mounted) return;

      _snack(
        _isCleaner
            ? 'Pendaftaran petugas dikirim. Menunggu persetujuan admin.'
            : 'Akun campus berhasil dibuat. Silakan login.',
      );

      Navigator.pushNamedAndRemoveUntil(context, '/login', (_) => false);
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'email-already-in-use'
          ? 'Email sudah terdaftar.'
          : e.code == 'weak-password'
              ? 'Kata sandi terlalu lemah (min 6).'
              : e.message ?? 'Gagal mendaftar.';
      _snack(msg, error: true);
    } catch (e) {
      _snack('Error: $e', error: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,

      // ✅ AppBar dengan tombol kembali
      appBar: AppBar(
        title: Text(_title),
        leading: IconButton(
          tooltip: 'Kembali',
          icon: const Icon(Icons.arrow_back),
          onPressed: _loading ? null : _back,
        ),
      ),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // (opsional) kalau AppBar sudah ada title, ini bisa dihapus.
                  Center(
                    child: Text(
                      _title,
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  SegmentedButton<RegisterRole>(
                    segments: const [
                      ButtonSegment(value: RegisterRole.campus, label: Text('Campus')),
                      ButtonSegment(value: RegisterRole.cleaner, label: Text('Petugas')),
                    ],
                    selected: {_role},
                    onSelectionChanged: (s) => setState(() => _role = s.first),
                  ),
                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _name,
                    decoration: const InputDecoration(labelText: 'Nama'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Gmail'),
                    validator: (v) => (v == null || !v.contains('@')) ? 'Email tidak valid' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(labelText: 'No. Hp'),
                    validator: (v) => (v == null || v.trim().length < 6) ? 'No. HP tidak valid' : null,
                  ),
                  const SizedBox(height: 12),

                  if (_isCleaner) ...[
                    TextFormField(
                      controller: _cleanerId,
                      decoration: const InputDecoration(labelText: 'Nomor Identitas Petugas'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Wajib diisi untuk petugas' : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  TextFormField(
                    controller: _pass,
                    obscureText: _ob1,
                    decoration: InputDecoration(
                      labelText: 'Kata Sandi',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob1 = !_ob1),
                        icon: Icon(_ob1 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) => (v == null || v.length < 6) ? 'Minimal 6 karakter' : null,
                  ),
                  const SizedBox(height: 12),

                  TextFormField(
                    controller: _pass2,
                    obscureText: _ob2,
                    decoration: InputDecoration(
                      labelText: 'Konfirmasi Kata Sandi',
                      suffixIcon: IconButton(
                        onPressed: () => setState(() => _ob2 = !_ob2),
                        icon: Icon(_ob2 ? Icons.visibility : Icons.visibility_off),
                      ),
                    ),
                    validator: (v) => (v != _pass.text) ? 'Konfirmasi tidak sama' : null,
                  ),
                  const SizedBox(height: 18),

                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('DAFTAR'),
                  ),
                  const SizedBox(height: 8),

                  TextButton(
                    onPressed: _loading ? null : () => Navigator.pushReplacementNamed(context, '/login'),
                    child: const Text('Sudah memiliki akun? MASUK'),
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
