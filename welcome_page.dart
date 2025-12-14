import 'package:flutter/material.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Scaffold(
      body: Stack(
        children: [
          // Background
          Positioned.fill(child: Container(color: const Color(0xFFAEE5E1))),

          // Content
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 20),
                      Center(
                        child: Text(
                          'TrashWash',
                          style: t.textTheme.displayMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      const Center(
                        child: Icon(
                          Icons.delete_outline,
                          size: 90,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 720),
                          child: Text(
                            'Aplikasi TrashWash dirancang untuk mempermudah petugas kebersihan '
                            'dan warga kampus dalam pelaporan TPS, monitoring, serta saran kebersihan.',
                            textAlign: TextAlign.center,
                            style: t.textTheme.bodyMedium?.copyWith(
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ===== Aksi MASUK / DAFTAR (sudah responsif) =====
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/login'),
                              child: const Text('MASUK'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: FilledButton.tonal(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/register'),
                              child: const Text('DAFTAR'),
                            ),
                          ),
                        ],
                      ),

                      // ===== Jenis Sampah =====
                      const SizedBox(height: 32),
                      Text(
                        'Jenis Sampah',
                        style: t.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),

                      _WasteGrid(cards: [
                        _WasteCardData(
                          icon: Icons.eco_rounded,
                          iconBg: const Color(0xFFD8F4DF),
                          iconColor: const Color(0xFF1B5E20),
                          title: 'Organik',
                          bullets: const [
                            'Sisa makanan, sayur & buah',
                            'Daun, ranting, rumput',
                            'Ampas kopi/teh, kulit telur',
                          ],
                          note: 'Dapat dijadikan kompos.',
                        ),
                        _WasteCardData(
                          icon: Icons.recycling_rounded,
                          iconBg: const Color(0xFFC6F1EE),
                          iconColor: const Color(0xFF006C68),
                          title: 'Non-organik / Daur Ulang',
                          bullets: const [
                            'Botol plastik PET, gelas plastik',
                            'Kertas & kardus kering',
                            'Kaleng minuman, logam',
                          ],
                          note:
                              'Pastikan bersih & kering sebelum didaur ulang.',
                        ),
                        _WasteCardData(
                          icon: Icons.delete_forever_rounded,
                          iconBg: const Color(0xFFDDE7F6),
                          iconColor: const Color(0xFF0D47A1),
                          title: 'Residu',
                          bullets: const [
                            'Popok sekali pakai',
                            'Tisu / serbet kotor',
                            'Puntung rokok, serbuk kotor',
                          ],
                          note:
                              'Tidak bisa didaur ulang — buang ke tempat “Residu/Umum”.',
                        ),
                        _WasteCardData(
                          icon: Icons.warning_amber_rounded,
                          iconBg: const Color(0xFFF8ECD7),
                          iconColor: const Color(0xFF8A5A00),
                          title: 'B3 (Berbahaya)',
                          bullets: const [
                            'Baterai, aki',
                            'Lampu neon, termometer raksa',
                            'Kaleng cat, oli, bahan kimia',
                          ],
                          note:
                              'Jangan campur dengan sampah biasa. Butuh penanganan khusus.',
                        ),
                        _WasteCardData(
                          icon: Icons.memory_rounded,
                          iconBg: const Color(0xFFEADCF7),
                          iconColor: const Color(0xFF5A2E91),
                          title: 'Elektronik (E-waste)',
                          bullets: const [
                            'HP/ponsel rusak',
                            'Adaptor, charger, kabel',
                            'Perangkat elektronik kecil',
                          ],
                          note:
                              'Kumpulkan untuk didaur ulang ke fasilitas E-waste.',
                        ),
                      ]),

                      const SizedBox(height: 8),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 820),
                          child: Text(
                            'Tips: pilah dan laporkan jenis sampah sesuai kategori agar pengangkutan dan daur ulang lebih efisien.',
                            textAlign: TextAlign.center,
                            style: t.textTheme.bodySmall?.copyWith(
                              color: Colors.black87.withOpacity(.75),
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== Grid responsif untuk kartu-kartu jenis sampah ======
class _WasteGrid extends StatelessWidget {
  const _WasteGrid({required this.cards});
  final List<_WasteCardData> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        final cross = w >= 1024
            ? 3
            : w >= 700
                ? 2
                : 1;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cross,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: cross == 1 ? 1.25 : 1.4,
          ),
          itemCount: cards.length,
          itemBuilder: (context, i) => _WasteCard(data: cards[i]),
        );
      },
    );
  }
}

class _WasteCardData {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final List<String> bullets;
  final String note;

  _WasteCardData({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.bullets,
    required this.note,
  });
}

class _WasteCard extends StatelessWidget {
  const _WasteCard({required this.data});
  final _WasteCardData data;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(.70),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(.20), width: 1.1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1F000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: data.iconBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withOpacity(.25),
                    width: 1,
                  ),
                ),
                child: Icon(data.icon, size: 26, color: data.iconColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  data.title,
                  overflow: TextOverflow.ellipsis,
                  style: t.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.bullets.map(
            (p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: _Dot(),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      p,
                      style: t.textTheme.bodyMedium?.copyWith(
                        color: Colors.black87,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            data.note,
            style: t.textTheme.bodySmall?.copyWith(
              color: Colors.black87.withOpacity(.85),
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: Colors.black87.withOpacity(.75),
        shape: BoxShape.circle,
      ),
    );
  }
}
