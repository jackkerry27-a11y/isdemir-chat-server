import 'package:flutter/material.dart';

class IsgScreen extends StatefulWidget {
  const IsgScreen({super.key});

  @override
  State<IsgScreen> createState() => _IsgScreenState();
}

class _IsgScreenState extends State<IsgScreen> {
  final List<_IsgKural> _kurallar = [
    _IsgKural(
      baslik: 'Kişisel Koruyucu Donanım',
      aciklama: 'Çalışma alanında baret, yelek, eldiven ve koruyucu ayakkabı mutlaka kullanılmalıdır.',
      icon: Icons.safety_divider_rounded,
      renk: const Color(0xFFEF4444),
    ),
    _IsgKural(
      baslik: 'Yangın Güvenliği',
      aciklama: 'Yangın söndürücülerin konumunu bilin. Acil çıkış kapılarını ve toplanma noktasını öğrenin.',
      icon: Icons.local_fire_department_rounded,
      renk: const Color(0xFFF97316),
    ),
    _IsgKural(
      baslik: 'Elektrik Güvenliği',
      aciklama: 'Elektrikli ekipmanları ıslak elle kullanmayın. Arızalı ekipmanları yetkili kişiye bildirin.',
      icon: Icons.electric_bolt_rounded,
      renk: const Color(0xFFEAB308),
    ),
    _IsgKural(
      baslik: 'Kimyasal Güvenlik',
      aciklama: 'Kimyasal maddeleri kullanırken güvenlik veri sayfalarını okuyun ve uygun KKD kullanın.',
      icon: Icons.science_rounded,
      renk: const Color(0xFF8B5CF6),
    ),
    _IsgKural(
      baslik: 'Elle Taşıma',
      aciklama: 'Ağır yükleri kaldırırken bacaklarınızı kullanın, beli zorlamayın. Gerektiğinde yardım isteyin.',
      icon: Icons.fitness_center_rounded,
      renk: const Color(0xFF0EA5E9),
    ),
    _IsgKural(
      baslik: 'Acil Durum',
      aciklama: 'Kaza, yaralanma veya acil durumda derhal amirlerinizi ve ilk yardım ekibini haberdar edin.',
      icon: Icons.emergency_rounded,
      renk: const Color(0xFF10B981),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // AppBar
          SliverAppBar(
            expandedHeight: 160,
            floating: false,
            pinned: true,
            backgroundColor: const Color(0xFF1E293B),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.health_and_safety_rounded, color: Color(0xFFEF4444), size: 28),
                            ),
                            const SizedBox(width: 12),
                            const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'İSG',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'İş Sağlığı ve Güvenliği',
                                  style: TextStyle(
                                    color: Colors.white60,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Uyarı Kartı
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECACA)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Güvenliğiniz önceliğimizdir. Lütfen tüm kuralları dikkatle okuyun.',
                        style: TextStyle(
                          color: Color(0xFF991B1B),
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Kurallar Başlık
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 8),
              child: Text(
                'Temel Güvenlik Kuralları',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                ),
              ),
            ),
          ),

          // Kural Kartları
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final kural = _kurallar[index];
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, 0, 16, index == _kurallar.length - 1 ? 24 : 12),
                  child: _IsgKuralKart(kural: kural),
                );
              },
              childCount: _kurallar.length,
            ),
          ),

          // Acil İletişim
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Acil İletişim Numaraları',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AcilNumara(icon: Icons.local_hospital_rounded, baslik: 'Ambulans', numara: '112', renk: const Color(0xFFEF4444)),
                  const SizedBox(height: 8),
                  _AcilNumara(icon: Icons.local_fire_department_rounded, baslik: 'İtfaiye', numara: '110', renk: const Color(0xFFF97316)),
                  const SizedBox(height: 8),
                  _AcilNumara(icon: Icons.local_police_rounded, baslik: 'Polis', numara: '155', renk: const Color(0xFF3B82F6)),
                  const SizedBox(height: 8),
                  _AcilNumara(icon: Icons.work_rounded, baslik: 'İSG Sorumlusu', numara: 'Dahili: 1234', renk: const Color(0xFF10B981)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IsgKural {
  final String baslik;
  final String aciklama;
  final IconData icon;
  final Color renk;

  _IsgKural({
    required this.baslik,
    required this.aciklama,
    required this.icon,
    required this.renk,
  });
}

class _IsgKuralKart extends StatelessWidget {
  final _IsgKural kural;

  const _IsgKuralKart({required this.kural});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kural.renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(kural.icon, color: kural.renk, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kural.baslik,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  kural.aciklama,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AcilNumara extends StatelessWidget {
  final IconData icon;
  final String baslik;
  final String numara;
  final Color renk;

  const _AcilNumara({
    required this.icon,
    required this.baslik,
    required this.numara,
    required this.renk,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: renk.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: renk, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              baslik,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1F2937),
              ),
            ),
          ),
          Text(
            numara,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: renk,
            ),
          ),
        ],
      ),
    );
  }
}
