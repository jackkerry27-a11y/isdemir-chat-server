import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 1. SİBERPUNK MESAJ ÇÖZÜLÜYOR HUD HALKA ANİMASYONU (Ekran 4)
class DecryptionHologramWidget extends StatefulWidget {
  final VoidCallback onDecrypted;
  const DecryptionHologramWidget({super.key, required this.onDecrypted});

  @override
  State<DecryptionHologramWidget> createState() => _DecryptionHologramWidgetState();
}

class _DecryptionHologramWidgetState extends State<DecryptionHologramWidget> with TickerProviderStateMixin {
  late AnimationController _rotationController;
  late AnimationController _progressController;

  @override
  void initState() {
    super.initState();
    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2800),
    );

    _progressController.forward().then((_) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) widget.onDecrypted();
      });
    });
  }

  @override
  void dispose() {
    _rotationController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B10).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.35), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withValues(alpha: 0.25),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Mesaj Çözülüyor...',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 28),

          // Hologram Dönen Halkalar
          SizedBox(
            width: 150,
            height: 150,
            child: AnimatedBuilder(
              animation: _rotationController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _CyberDecryptionRingsPainter(
                    rotation: _rotationController.value,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 28),

          // İlerleme Çubuğu (Kırmızı Parlayan Progress Bar)
          AnimatedBuilder(
            animation: _progressController,
            builder: (context, child) {
              return Column(
                children: [
                  Container(
                    height: 4,
                    width: 220,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Stack(
                      children: [
                        Container(
                          width: 220 * _progressController.value,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF8B0000), Color(0xFFE50914), Color(0xFFFF4D4D)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Bu mesaj yalnızca bir kez görüntülenebilir.\nLütfen bekle...',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF9E9EA7),
                      height: 1.4,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CyberDecryptionRingsPainter extends CustomPainter {
  final double rotation;
  _CyberDecryptionRingsPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final paintRing1 = Paint()
      ..color = const Color(0xFFE50914).withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final paintRing2 = Paint()
      ..color = const Color(0xFFFF2A2A).withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final paintCore = Paint()
      ..color = const Color(0xFFE50914).withValues(alpha: 0.25)
      ..style = PaintingStyle.fill;

    // Dış Daire
    canvas.drawCircle(center, size.width * 0.46, paintRing1);

    // İç Dolgulu Nabız
    final pulse = 0.8 + 0.2 * math.sin(rotation * 2 * math.pi);
    canvas.drawCircle(center, size.width * 0.18 * pulse, paintCore);

    // Çapraz dönen elipsler / yörüngeler
    final angle = rotation * 2 * math.pi;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.85, height: size.height * 0.35),
      paintRing2,
    );
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-angle * 1.5);
    canvas.drawOval(
      Rect.fromCenter(center: Offset.zero, width: size.width * 0.65, height: size.height * 0.25),
      paintRing1,
    );
    canvas.restore();

    // Dönen Kırmızı Glif Noktaları
    final dotPaint = Paint()..color = const Color(0xFFFF3B30);
    for (int i = 0; i < 4; i++) {
      final rad = angle + (i * math.pi / 2);
      final dx = center.dx + (size.width * 0.46) * math.cos(rad);
      final dy = center.dy + (size.height * 0.46) * math.sin(rad);
      canvas.drawCircle(Offset(dx, dy), 3.0, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CyberDecryptionRingsPainter oldDelegate) =>
      oldDelegate.rotation != rotation;
}

/// 2. KENDİNİ İMHA EDEN KORLU KUM SAATİ ANİMASYONU (Ekran 5)
class BurnedMessageHourglassWidget extends StatefulWidget {
  final VoidCallback? onDismiss;
  const BurnedMessageHourglassWidget({super.key, this.onDismiss});

  @override
  State<BurnedMessageHourglassWidget> createState() => _BurnedMessageHourglassWidgetState();
}

class _BurnedMessageHourglassWidgetState extends State<BurnedMessageHourglassWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        color: const Color(0xFF09060A).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE50914).withValues(alpha: 0.18),
            blurRadius: 28,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Parlayan & Küllenen Kum Saati
          SizedBox(
            width: 140,
            height: 160,
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return CustomPaint(
                  painter: _HourglassBurnPainter(progress: _controller.value),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Mesaj görüntülendi\nve kalıcı olarak silindi.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '"Bazı kelimeler sonsuza kadar kaybolmalı."',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              fontStyle: FontStyle.italic,
              color: const Color(0xFFB5A7B3),
            ),
          ),
          if (widget.onDismiss != null) ...[
            const SizedBox(height: 20),
            TextButton(
              onPressed: widget.onDismiss,
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFE50914),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text('Anlaşıldı (Kapat)'),
            ),
          ],
        ],
      ),
    );
  }
}

class _HourglassBurnPainter extends CustomPainter {
  final double progress;
  _HourglassBurnPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final center = Offset(w / 2, h / 2);

    // Kırmızı Işıma Gölgeleri
    final glowPaint = Paint()
      ..color = const Color(0xFFE50914).withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(center, 45, glowPaint);

    final framePaint = Paint()
      ..color = const Color(0xFFFF2A2A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;

    // Kum Saati Çerçevesi (Üst ve Alt üçgenler)
    final path = Path();
    path.moveTo(w * 0.25, h * 0.15);
    path.lineTo(w * 0.75, h * 0.15);
    path.lineTo(w * 0.52, h * 0.5);
    path.lineTo(w * 0.75, h * 0.85);
    path.lineTo(w * 0.25, h * 0.85);
    path.lineTo(w * 0.48, h * 0.5);
    path.close();
    canvas.drawPath(path, framePaint);

    // Üst ve Alt Tabanlar
    final basePaint = Paint()
      ..color = const Color(0xFFE50914)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.18, h * 0.14), Offset(w * 0.82, h * 0.14), basePaint);
    canvas.drawLine(Offset(w * 0.18, h * 0.86), Offset(w * 0.82, h * 0.86), basePaint);

    // Akan Kırmızı Kum Akışı
    final sandPaint = Paint()
      ..color = const Color(0xFFFF4D4D)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(w * 0.5, h * 0.45), Offset(w * 0.5, h * 0.82), sandPaint);

    // Yükselen Kıvılcım / Kül Parçacıkları (Rising Embers)
    final emberPaint = Paint()..color = const Color(0xFFFF5252);
    final random = math.Random(42);
    for (int i = 0; i < 18; i++) {
      final initialY = h * 0.9 - (i * 7);
      final driftX = math.sin((progress * 2 * math.pi) + i) * 16;
      final currentY = (initialY - (progress * 50)) % (h * 0.85);
      final radius = (random.nextDouble() * 2.2) + 0.8;
      final alpha = (1.0 - (currentY / (h * 0.85))).clamp(0.1, 0.9);
      emberPaint.color = Color(0xFFFF3333).withValues(alpha: alpha);
      canvas.drawCircle(Offset(center.dx + driftX, currentY), radius, emberPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _HourglassBurnPainter oldDelegate) => true;
}

/// 3. GİRİŞ EKRANI KIRMIZI PORTAL VE SİLÜET ARKA PLANI (Ekran 1)
class NoctraPortalGlowWidget extends StatelessWidget {
  final double size;
  const NoctraPortalGlowWidget({super.key, this.size = 220});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Dış Kırmızı Neon Halka
          Container(
            width: size * 0.9,
            height: size * 0.9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE50914).withValues(alpha: 0.65),
                  blurRadius: 40,
                  spreadRadius: 8,
                ),
                BoxShadow(
                  color: const Color(0xFF8B0000).withValues(alpha: 0.85),
                  blurRadius: 70,
                  spreadRadius: 20,
                ),
              ],
              border: Border.all(
                color: const Color(0xFFFF2A2A),
                width: 3.5,
              ),
            ),
          ),
          // İç Koyu Sis / Vorteks
          Container(
            width: size * 0.82,
            height: size * 0.82,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFFE50914).withValues(alpha: 0.2),
                  const Color(0xFF0D0305).withValues(alpha: 0.9),
                  const Color(0xFF050102),
                ],
                stops: const [0.1, 0.65, 1.0],
              ),
            ),
          ),
          // Kapüşonlu Silüet İkon / Vektör
          Icon(
            Icons.person_rounded,
            size: size * 0.55,
            color: const Color(0xFF0F0B10),
            shadows: [
              Shadow(
                color: const Color(0xFFE50914).withValues(alpha: 0.9),
                blurRadius: 18,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
