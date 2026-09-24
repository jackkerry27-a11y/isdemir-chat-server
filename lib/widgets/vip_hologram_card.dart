import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';

// ═══════════════════════════════════════════════════════════════════
// 👑 İSDEMİR OS - DİNAMİK HOLOGRAMLI VIP DİJİTAL KİMLİK KARTI
// ═══════════════════════════════════════════════════════════════════

class VipCardModal {
  static void show(BuildContext context, {required UserModel user}) {
    HapticFeedback.heavyImpact();
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'VIP Card',
      barrierColor: Colors.black.withValues(alpha: 0.82),
      transitionDuration: const Duration(milliseconds: 350),
      transitionBuilder: (context, anim, secondaryAnim, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutBack);
        return ScaleTransition(
          scale: curved,
          child: FadeTransition(opacity: anim, child: child),
        );
      },
      pageBuilder: (context, animation, secondaryAnimation) {
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: _VipCardModalContent(user: user),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _VipCardModalContent extends StatefulWidget {
  final UserModel user;
  const _VipCardModalContent({required this.user});

  @override
  State<_VipCardModalContent> createState() => _VipCardModalContentState();
}

class _VipCardModalContentState extends State<_VipCardModalContent>
    with TickerProviderStateMixin {
  // 3D Flip Animasyonu
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;

  // Hologram Sürekli Işık Parıltısı
  late AnimationController _sheenController;

  // 3D Tilt Değişkenleri
  double _tiltX = 0.0;
  double _tiltY = 0.0;

  bool _isBack = false;
  late String _verificationToken;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _flipAnimation = CurvedAnimation(
      parent: _flipController,
      curve: Curves.easeInOutBack,
    );

    _sheenController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _generateSecurityToken();
  }

  void _generateSecurityToken() {
    final ts = DateTime.now().millisecondsSinceEpoch.toString();
    final uid = widget.user.id.length > 4 ? widget.user.id.substring(0, 4) : '0892';
    _verificationToken = 'ISD-VIP-OMNI-$uid-${ts.substring(ts.length - 6)}';
  }

  @override
  void dispose() {
    _flipController.dispose();
    _sheenController.dispose();
    super.dispose();
  }

  void _toggleFlip() {
    HapticFeedback.mediumImpact();
    if (_isBack) {
      _flipController.reverse();
    } else {
      _flipController.forward();
    }
    setState(() {
      _isBack = !_isBack;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Üst Kapatma Butonu & Rozet ──
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFB45309), Color(0xFFD97706), Color(0xFFF59E0B)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Text('👑 ', style: TextStyle(fontSize: 12)),
                  Text(
                    'İSDEMİR VIP DİJİTAL KİMLİK',
                    style: GoogleFonts.orbitron(
                      fontSize: 10.5,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => Navigator.pop(context),
              icon: Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2433),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: const Icon(Icons.close_rounded, size: 18, color: Colors.white70),
              ),
            ),
          ],
        ),

        const SizedBox(height: 18),

        // ── 3D ETKİLEŞİMLİ VE ÇEVRİLEBİLİR HOLOGRAM KART ──
        GestureDetector(
          onPanUpdate: (details) {
            setState(() {
              _tiltX += details.delta.dx * 0.008;
              _tiltY += details.delta.dy * 0.008;
              _tiltX = _tiltX.clamp(-0.45, 0.45);
              _tiltY = _tiltY.clamp(-0.45, 0.45);
            });
          },
          onPanEnd: (_) {
            setState(() {
              _tiltX = 0.0;
              _tiltY = 0.0;
            });
          },
          onTap: _toggleFlip,
          child: AnimatedBuilder(
            animation: Listenable.merge([_flipAnimation, _sheenController]),
            builder: (context, child) {
              final angle = _flipAnimation.value * math.pi;
              final isUnder = angle > (math.pi / 2);

              // 3D Perspektif Matrisi
              final transform = Matrix4.identity()
                ..setEntry(3, 2, 0.0015)
                ..rotateX(-_tiltY * 0.35)
                ..rotateY(_tiltX * 0.35 + angle);

              return Transform(
                transform: transform,
                alignment: Alignment.center,
                child: isUnder
                    ? Transform(
                        transform: Matrix4.identity()..rotateY(math.pi),
                        alignment: Alignment.center,
                        child: _VipCardBack(
                          user: widget.user,
                          token: _verificationToken,
                          tiltX: _tiltX,
                          tiltY: _tiltY,
                          sheenProgress: _sheenController.value,
                        ),
                      )
                    : _VipCardFront(
                        user: widget.user,
                        tiltX: _tiltX,
                        tiltY: _tiltY,
                        sheenProgress: _sheenController.value,
                      ),
              );
            },
          ),
        ),

        const SizedBox(height: 14),

        Text(
          '👆 Karta dokunarak arka yüzünü çevirebilir, parmağınızla 3D eğebilirsiniz.',
          style: GoogleFonts.inter(
            fontSize: 11.5,
            color: const Color(0xFF94A3B8),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),

        const SizedBox(height: 20),

        // ── 🛠️ KART EYLEM BUTONLARI ──
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Kartı Çevir
            _buildActionButton(
              icon: Icons.flip_camera_android_rounded,
              label: _isBack ? 'Ön Yüze Dön' : 'Arka Yüzü Çevir',
              color: const Color(0xFF38BDF8),
              onTap: _toggleFlip,
            ),
            const SizedBox(width: 12),
            // Güvenlik Kodu Kopyala
            _buildActionButton(
              icon: Icons.qr_code_rounded,
              label: 'QR Token Kopyala',
              color: const Color(0xFFF59E0B),
              onTap: () {
                Clipboard.setData(ClipboardData(text: _verificationToken));
                HapticFeedback.lightImpact();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('✅ VIP Doğrulama Token\'ı kopyalandı: $_verificationToken'),
                    backgroundColor: const Color(0xFF10B981),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161B26),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ── 🎴 VIP KART ÖN YÜZÜ (FRONT SIDE) ──
// ─────────────────────────────────────────────────────────
class _VipCardFront extends StatelessWidget {
  final UserModel user;
  final double tiltX;
  final double tiltY;
  final double sheenProgress;

  const _VipCardFront({
    required this.user,
    required this.tiltX,
    required this.tiltY,
    required this.sheenProgress,
  });

  @override
  Widget build(BuildContext context) {
    final avatarProvider = SocketService.getAvatarProvider(user.photoPath);
    final fullName = '${user.firstName} ${user.lastName}'.toUpperCase();
    final role = user.jobTitle.isNotEmpty
        ? user.jobTitle.toUpperCase()
        : 'VIP OPERATÖR // SAHA & LİMAN';

    return Container(
      width: 340,
      height: 215,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF131722),
            Color(0xFF0B0E17),
            Color(0xFF171B26),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.7),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.22),
            blurRadius: 25,
            spreadRadius: 2,
            offset: Offset(tiltX * 15, tiltY * 15),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // 1. Dinamik Hologram Sedef & Gökkuşağı Katmanı
            Positioned.fill(
              child: CustomPaint(
                painter: _HologramSheenPainter(
                  tiltX: tiltX,
                  tiltY: tiltY,
                  progress: sheenProgress,
                ),
              ),
            ),

            // 2. Mikro Güvenlik Guilloché Çizgileri
            Positioned.fill(
              child: CustomPaint(
                painter: _GuillocheSecurityPainter(),
              ),
            ),

            // 3. Ön Yüz Kart İçeriği
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Üst Başlık & İsdemir Amblemi
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFFE50914),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'İSDEMİR ÇELİK FABRİKALARI',
                                style: GoogleFonts.orbitron(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'T.C. PROTOKOL GİRİŞ & YETKİ KARTI',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 7.5,
                              color: const Color(0xFFF59E0B),
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                      // VIP Rozeti
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F141F),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.1),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.verified_rounded, size: 11, color: Color(0xFFF59E0B)),
                            const SizedBox(width: 4),
                            Text(
                              'VIP PASS',
                              style: GoogleFonts.orbitron(
                                fontSize: 8,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFFF59E0B),
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  // Orta Kısım: EMV Metal Çip & NFC İkonu
                  Row(
                    children: [
                      const _EMVChipWidget(),
                      const SizedBox(width: 12),
                      Icon(
                        Icons.contactless_rounded,
                        color: Colors.white.withValues(alpha: 0.6),
                        size: 22,
                      ),
                      const Spacer(),
                      // Güvenlik Düzeyi
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1F2C).withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                        ),
                        child: Text(
                          'CLEARANCE: LEVEL 4 // OMNI',
                          style: GoogleFonts.orbitron(
                            fontSize: 7.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Alt Kısım: Personel Fotoğrafı, İsim & Sicil
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Fotoğraf
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF1E2538),
                          border: Border.all(
                            color: const Color(0xFFF59E0B),
                            width: 1.8,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: avatarProvider != null
                              ? Image(image: avatarProvider, fit: BoxFit.cover)
                              : Center(
                                  child: Text(
                                    user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'V',
                                    style: GoogleFonts.orbitron(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18,
                                      color: const Color(0xFFF59E0B),
                                    ),
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // İsim ve Departman
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              fullName,
                              style: GoogleFonts.orbitron(
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 0.6,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              role,
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFFCBD5E1),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ISD-VIP •••• •••• 8920',
                              style: GoogleFonts.orbitron(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFF59E0B),
                                letterSpacing: 1.2,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Son Geçerlilik
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'VALID THRU',
                            style: GoogleFonts.inter(
                              fontSize: 6.5,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                          Text(
                            '12/28',
                            style: GoogleFonts.orbitron(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ],
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

// ─────────────────────────────────────────────────────────
// ── 🎴 VIP KART ARKA YÜZÜ (BACK SIDE) ──
// ─────────────────────────────────────────────────────────
class _VipCardBack extends StatelessWidget {
  final UserModel user;
  final String token;
  final double tiltX;
  final double tiltY;
  final double sheenProgress;

  const _VipCardBack({
    required this.user,
    required this.token,
    required this.tiltX,
    required this.tiltY,
    required this.sheenProgress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 340,
      height: 215,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0F131D),
            Color(0xFF080B12),
            Color(0xFF141926),
          ],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
            blurRadius: 20,
            offset: Offset(tiltX * 15, tiltY * 15),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.8),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Hologram Katmanı
            Positioned.fill(
              child: CustomPaint(
                painter: _HologramSheenPainter(
                  tiltX: tiltX,
                  tiltY: tiltY,
                  progress: sheenProgress,
                ),
              ),
            ),

            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 12),
                // 1. Manyetik Şerit (Black Magnetic Stripe)
                Container(
                  width: double.infinity,
                  height: 38,
                  decoration: const BoxDecoration(
                    color: Color(0xFF07080D),
                    boxShadow: [
                      BoxShadow(color: Colors.black, blurRadius: 4),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // 2. Canlı Güvenlik QR Kodu & Yetkiler
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      // Dinamik QR Kod Çizimi
                      Container(
                        width: 76,
                        height: 76,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFF59E0B), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: CustomPaint(
                          painter: _SecurityQRPainter(token: token),
                        ),
                      ),

                      const SizedBox(width: 12),

                      // Yetkili Erişim Alanları
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAccessZone('✓ NİZAMİYE 1 & 2 PROTOKOL GEÇİŞ'),
                            _buildAccessZone('✓ LİMAN & RIHTIMLAR TAM ERİŞİM'),
                            _buildAccessZone('✓ TELSİZ KRİZ MASASI FREKANSI'),
                            _buildAccessZone('✓ YETKİLİ OPERASYON KONSOLU'),
                            const SizedBox(height: 4),
                            Text(
                              'GÜVENLİK TOKENI: ${token.substring(0, math.min(18, token.length))}...',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 7,
                                color: const Color(0xFFF59E0B),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // 3. Alt Güvenlik Açıklaması & Barkod
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF070910).withValues(alpha: 0.7),
                    border: const Border(top: BorderSide(color: Color(0xFF1E283C), width: 0.8)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Bu kart İSDEMİR A.Ş. mülkiyetindedir. Bulunduğunda nizamiyeye teslim ediniz.',
                        style: GoogleFonts.inter(fontSize: 6.5, color: const Color(0xFF64748B)),
                      ),
                      Text(
                        'AUTH 100%',
                        style: GoogleFonts.orbitron(fontSize: 7.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAccessZone(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2.5),
      child: Row(
        children: [
          const Icon(Icons.shield_rounded, size: 9, color: Color(0xFF10B981)),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.orbitron(
                fontSize: 7.5,
                fontWeight: FontWeight.bold,
                color: Colors.white70,
                letterSpacing: 0.3,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// ── 💎 HOLOGRAM SEDEF & GÖKKUŞAĞI YANSIYAN IŞIK ÇİZİCİSİ ──
// ─────────────────────────────────────────────────────────
class _HologramSheenPainter extends CustomPainter {
  final double tiltX;
  final double tiltY;
  final double progress;

  _HologramSheenPainter({
    required this.tiltX,
    required this.tiltY,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shift = (progress * 2 - 1) * size.width * 1.5;
    final tiltOffset = Offset(tiltX * size.width * 0.8, tiltY * size.height * 0.8);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    final gradient = LinearGradient(
      begin: Alignment(-1.0 + tiltX, -1.0 + tiltY),
      end: Alignment(1.0 + tiltX, 1.0 + tiltY),
      colors: [
        Colors.transparent,
        const Color(0xFF00F0FF).withValues(alpha: 0.08),
        const Color(0xFFEC4899).withValues(alpha: 0.12),
        const Color(0xFFFBBF24).withValues(alpha: 0.16),
        const Color(0xFFA855F7).withValues(alpha: 0.12),
        const Color(0xFF10B981).withValues(alpha: 0.08),
        Colors.transparent,
      ],
      stops: const [0.0, 0.25, 0.40, 0.50, 0.60, 0.75, 1.0],
      transform: GradientRotation(math.pi / 4 + tiltX * 0.5),
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect.shift(Offset(shift, 0) + tiltOffset))
      ..blendMode = BlendMode.screen;

    canvas.drawRect(rect, paint);
  }

  @override
  bool shouldRepaint(covariant _HologramSheenPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.tiltX != tiltX ||
        oldDelegate.tiltY != tiltY;
  }
}

// ─────────────────────────────────────────────────────────
// ── 🛡️ GÜVENLİK GUİLLOCHÉ MİKRO ÇİZGİLERİ ──
// ─────────────────────────────────────────────────────────
class _GuillocheSecurityPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFFF59E0B).withValues(alpha: 0.04)
      ..strokeWidth = 0.6
      ..style = PaintingStyle.stroke;

    final center = Offset(size.width * 0.65, size.height * 0.5);
    for (double r = 15; r < size.width * 0.8; r += 12) {
      canvas.drawCircle(center, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────
// ── 💳 METALİK EMV AKILLI ÇİP GRAFİĞİ ──
// ─────────────────────────────────────────────────────────
class _EMVChipWidget extends StatelessWidget {
  const _EMVChipWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        gradient: const LinearGradient(
          colors: [
            Color(0xFFD97706),
            Color(0xFFFDE68A),
            Color(0xFFB45309),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: const Color(0xFFF59E0B), width: 0.8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _EMVLinesPainter(),
      ),
    );
  }
}

class _EMVLinesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF78350F).withValues(alpha: 0.6)
      ..strokeWidth = 0.9;

    // Yatay Bölücü Çizgi
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
    // Dikey Bölücüler
    canvas.drawLine(Offset(size.width * 0.35, 0), Offset(size.width * 0.35, size.height), paint);
    canvas.drawLine(Offset(size.width * 0.65, 0), Offset(size.width * 0.65, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────
// ── 🔳 GÜVENLİK QR KOD ÇİZİCİSİ (CANLI LAZER TARAYICILI) ──
// ─────────────────────────────────────────────────────────
class _SecurityQRPainter extends CustomPainter {
  final String token;
  _SecurityQRPainter({required this.token});

  @override
  void paint(Canvas canvas, Size size) {
    final blackPaint = Paint()..color = const Color(0xFF0F172A);

    // 3 Köşe Bulucu Kutuları
    _drawFinderPattern(canvas, const Offset(0, 0), 20, blackPaint);
    _drawFinderPattern(canvas, Offset(size.width - 20, 0), 20, blackPaint);
    _drawFinderPattern(canvas, Offset(0, size.height - 20), 20, blackPaint);

    // Matris Noktaları (Token tabanlı deterministik desen)
    const gridSize = 8;
    final cellW = (size.width - 12) / gridSize;
    final cellH = (size.height - 12) / gridSize;

    int hash = token.hashCode;
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Köşeleri atla
        if ((r < 3 && c < 3) || (r < 3 && c > gridSize - 4) || (r > gridSize - 4 && c < 3)) {
          continue;
        }
        if (((hash >> ((r * gridSize + c) % 30)) & 1) == 1) {
          canvas.drawRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(6 + c * cellW, 6 + r * cellH, cellW * 0.8, cellH * 0.8),
              const Radius.circular(1.5),
            ),
            blackPaint,
          );
        }
      }
    }
  }

  void _drawFinderPattern(Canvas canvas, Offset offset, double size, Paint paint) {
    // Dış Kutu
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(offset.dx, offset.dy, size, size), const Radius.circular(3)),
      paint,
    );
    // İç Beyaz Kutu
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx + 3, offset.dy + 3, size - 6, size - 6),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
    // Merkez Siyah Kutu
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(offset.dx + 6, offset.dy + 6, size - 12, size - 12),
        const Radius.circular(1.5),
      ),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
