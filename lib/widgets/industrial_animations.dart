import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:custom_refresh_indicator/custom_refresh_indicator.dart';
import 'package:lottie/lottie.dart';

/// 1. Canlı Çalışan Liman Vinci & Konteyner/Yükleme Lottie Animasyonu
class IndustrialCraneWidget extends StatefulWidget {
  final bool isOperating;
  final Color themeColor;
  final bool compact;

  const IndustrialCraneWidget({
    super.key,
    this.isOperating = true,
    this.themeColor = const Color(0xFFF59E0B),
    this.compact = false,
  });

  @override
  State<IndustrialCraneWidget> createState() => _IndustrialCraneWidgetState();
}

class _IndustrialCraneWidgetState extends State<IndustrialCraneWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _beaconController;

  @override
  void initState() {
    super.initState();
    _beaconController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isOperating) {
      _beaconController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant IndustrialCraneWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isOperating && !_beaconController.isAnimating) {
      _beaconController.repeat(reverse: true);
    } else if (!widget.isOperating && _beaconController.isAnimating) {
      _beaconController.stop();
    }
  }

  @override
  void dispose() {
    _beaconController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _beaconController,
      builder: (context, child) {
        final beaconAlpha = 0.3 + 0.7 * sin(_beaconController.value * pi).abs();

        return Container(
          padding: EdgeInsets.symmetric(
            horizontal: widget.compact ? 8 : 10,
            vertical: widget.compact ? 5 : 6,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF14181D),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.themeColor.withValues(alpha: widget.isOperating ? 0.45 : 0.2),
              width: 1.2,
            ),
            boxShadow: widget.isOperating
                ? [
                    BoxShadow(
                      color: widget.themeColor.withValues(alpha: 0.15),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Lottie veya Vektörel Vinç Animasyonu
              if (widget.isOperating)
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: SizedBox(
                    width: widget.compact ? 36 : 46,
                    height: widget.compact ? 26 : 32,
                    child: Lottie.asset(
                      'assets/animations/crane_loading.json',
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.precision_manufacturing_rounded,
                          size: widget.compact ? 20 : 24,
                          color: widget.themeColor,
                        );
                      },
                    ),
                  ),
                )
              else
                Icon(
                  Icons.precision_manufacturing_rounded,
                  size: widget.compact ? 18 : 22,
                  color: Colors.white30,
                ),
              SizedBox(width: widget.compact ? 6 : 8),

              // Tepe Flaşörü (Sarı İkaz Lambası)
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.isOperating
                      ? widget.themeColor.withValues(alpha: beaconAlpha)
                      : Colors.white24,
                  boxShadow: widget.isOperating
                      ? [
                          BoxShadow(
                            color: widget.themeColor.withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 2,
                          ),
                        ]
                      : null,
                ),
              ),
              SizedBox(width: widget.compact ? 6 : 8),

              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.isOperating ? 'STS VİNÇ AKTİF' : 'VİNÇ BEKLEMEDE',
                      style: GoogleFonts.orbitron(
                        fontSize: widget.compact ? 8.5 : 9,
                        fontWeight: FontWeight.w900,
                        color: widget.isOperating ? widget.themeColor : Colors.white38,
                        letterSpacing: widget.compact ? 0.5 : 1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      widget.isOperating ? 'Yükleme/Tahliye Sürüyor' : 'Operasyon Tamamlandı',
                      style: TextStyle(
                        fontSize: widget.compact ? 9 : 10,
                        color: Colors.white54,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 1.B Gerçekçi Yük Gemisi Lottie Widget'ı
class LottieCargoShipWidget extends StatelessWidget {
  final double width;
  final double height;
  final bool animate;

  const LottieCargoShipWidget({
    super.key,
    this.width = 120,
    this.height = 70,
    this.animate = true,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Lottie.asset(
        'assets/animations/ship_sailing.json',
        fit: BoxFit.contain,
        animate: animate,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(
            Icons.directions_boat_filled_rounded,
            size: 36,
            color: Color(0xFFE50914),
          );
        },
      ),
    );
  }
}

/// 2. Canlı Su Dalgası Efekti (Liman / Rıhtım Arka Planı)
class AnimatedSeaWaveWidget extends StatefulWidget {
  final double height;
  final Color waveColor;

  const AnimatedSeaWaveWidget({
    super.key,
    this.height = 14,
    this.waveColor = const Color(0xFF0284C7),
  });

  @override
  State<AnimatedSeaWaveWidget> createState() => _AnimatedSeaWaveWidgetState();
}

class _AnimatedSeaWaveWidgetState extends State<AnimatedSeaWaveWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(double.infinity, widget.height),
          painter: _SeaWavePainter(
            animationValue: _waveController.value,
            color: widget.waveColor,
          ),
        );
      },
    );
  }
}

class _SeaWavePainter extends CustomPainter {
  final double animationValue;
  final Color color;

  _SeaWavePainter({required this.animationValue, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 1) {
      final y = sin((x / size.width * 2 * pi) + (animationValue * 2 * pi)) * 3.5 + (size.height / 2);
      path.lineTo(x, y);
    }

    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SeaWavePainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}

/// 3. İSDEMİR Rıhtım 1-5 İnteraktif Dijital İkiz Şeması
class PortBerthSchemeWidget extends StatelessWidget {
  final List<Map<String, dynamic>> ships;
  final Function(Map<String, dynamic> shipData)? onShipTap;
  final Function(int rihtimNo)? onEmptyRihtimTap;

  const PortBerthSchemeWidget({
    super.key,
    required this.ships,
    this.onShipTap,
    this.onEmptyRihtimTap,
  });

  @override
  Widget build(BuildContext context) {
    // Dolu rıhtım sayısını hesapla (1-5)
    int occupiedCount = 0;
    for (int r = 1; r <= 5; r++) {
      final isOccupied = ships.any(
        (s) => s['rihtimNo']?.toString() == r.toString() && s['durum'] != 'Limandan Ayrıldı',
      );
      if (isOccupied) occupiedCount++;
    }

    // Demir sahasında bekleyen gemiler (Koordinat: 36.761552, 36.136181)
    final anchoredShips = ships.where((s) {
      final r = s['rihtimNo']?.toString();
      final st = s['durum']?.toString() ?? '';
      return r == 'Demir' || st.contains('Demir') || s['isAnchorage'] == true;
    }).toList();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1321),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF38BDF8).withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Üst Başlık ve Canlı Telemetri Barı
          Row(
            children: [
              // Pulsing Radar Dot
              Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF10B981),
                  boxShadow: [
                    BoxShadow(color: Color(0xFF10B981), blurRadius: 8, spreadRadius: 2),
                  ],
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'LİMAN & DEMİR // CANLI RADAR',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: 0.8,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              // Demir Sahası Rozeti
              if (anchoredShips.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.45)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.anchor_rounded, size: 11, color: Color(0xFFF59E0B)),
                      const SizedBox(width: 4),
                      Text(
                        '${anchoredShips.length} DEMİRDE',
                        style: GoogleFonts.orbitron(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFFF59E0B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
              ],
              // Doluluk Oranı Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hub_rounded, size: 11, color: Color(0xFF38BDF8)),
                    const SizedBox(width: 4),
                    Text(
                      '$occupiedCount / 5 DOLU',
                      style: GoogleFonts.orbitron(
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. 5 Rıhtım Kartı + 1 Demir Sahası Kartı (Yatay Kaydırılabilir)
          SizedBox(
            height: 108,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                // 6. Kart: DEMİR SAHASI (36.761552, 36.136181)
                if (index == 5) {
                  final hasAnchored = anchoredShips.isNotEmpty;
                  final count = anchoredShips.length;
                  final statusColor = hasAnchored ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8);
                  final previewText = hasAnchored
                      ? (count == 1
                          ? (anchoredShips.first['gemiAdi'] ?? 'Gemi')
                          : '${anchoredShips.first['gemiAdi']} (+$count)')
                      : 'Açıkta Gemi Yok';

                  return GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      if (hasAnchored && onShipTap != null) {
                        onShipTap!(anchoredShips.first);
                      }
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 154,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: hasAnchored ? const Color(0xFF19140B) : const Color(0xFF0C101A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: statusColor.withValues(alpha: hasAnchored ? 0.7 : 0.2),
                          width: hasAnchored ? 1.4 : 1,
                        ),
                        boxShadow: hasAnchored
                            ? [
                                BoxShadow(
                                  color: statusColor.withValues(alpha: 0.16),
                                  blurRadius: 10,
                                  offset: const Offset(0, 3),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: Text(
                                  'DEMİR SAHASI',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w900,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.anchor_rounded,
                                size: 15,
                                color: statusColor,
                              ),
                            ],
                          ),
                          Text(
                            previewText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: hasAnchored ? FontWeight.bold : FontWeight.w600,
                              color: hasAnchored ? Colors.white : Colors.white38,
                              letterSpacing: 0.2,
                            ),
                          ),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                                ),
                                child: Text(
                                  hasAnchored ? '$count GEMİ BEKLİYOR' : 'AÇIKTA BEKLEME',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    color: statusColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                }

                final rihtimNo = index + 1;
                // Bu rıhtımdaki aktif gemiyi bul
                final dockedShip = ships.firstWhere(
                  (s) => s['rihtimNo']?.toString() == rihtimNo.toString() && s['durum'] != 'Limandan Ayrıldı',
                  orElse: () => <String, dynamic>{},
                );

                final isOccupied = dockedShip.isNotEmpty;
                final shipName = isOccupied ? (dockedShip['gemiAdi'] ?? 'Gemi') : 'BOŞ RIHTIM';
                final durum = isOccupied ? (dockedShip['durum'] ?? '') : 'Yanaşmaya Uygun';
                final yuk = isOccupied ? (dockedShip['yukCinsi'] ?? '') : '';
                final speed = isOccupied ? (dockedShip['speedKnots']?.toString() ?? '0.0') : '';

                Color statusColor = const Color(0xFF10B981);
                if (durum == 'Gemi Başlama Alındı') statusColor = const Color(0xFF10B981);
                if (durum == 'Gemi Bitişte') statusColor = const Color(0xFFF59E0B);
                if (durum == 'Gemi Bitti') statusColor = const Color(0xFF3B82F6);
                if (durum == 'Limandan Ayrılıyor') statusColor = const Color(0xFFEF4444);
                if (durum == 'Limana Giriş Yapıyor') statusColor = const Color(0xFF06B6D4);
                if (!isOccupied) statusColor = const Color(0xFF38BDF8);

                final berthSubtitles = [
                  'Dış İskele',
                  'Kuzey Rıhtım',
                  'Parmak İskele',
                  'Güneybatı',
                  'Güneydoğu'
                ];
                final berthSub = (rihtimNo >= 1 && rihtimNo <= 5) ? berthSubtitles[rihtimNo - 1] : '';

                return GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (isOccupied && onShipTap != null) {
                      onShipTap!(dockedShip);
                    } else if (!isOccupied && onEmptyRihtimTap != null) {
                      onEmptyRihtimTap!(rihtimNo);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 148,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isOccupied
                          ? const Color(0xFF131A2B)
                          : const Color(0xFF0C101A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isOccupied
                            ? statusColor.withValues(alpha: 0.65)
                            : Colors.white.withValues(alpha: 0.09),
                        width: isOccupied ? 1.4 : 1,
                      ),
                      boxShadow: isOccupied
                          ? [
                              BoxShadow(
                                color: statusColor.withValues(alpha: 0.15),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : null,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Üst Bar: Rıhtım No + Durum İkonu
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isOccupied
                                        ? statusColor.withValues(alpha: 0.2)
                                        : Colors.white.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'R-$rihtimNo',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w900,
                                      color: isOccupied ? Colors.white : Colors.white60,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  berthSub,
                                  style: const TextStyle(
                                    fontSize: 8.5,
                                    color: Colors.white38,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            Icon(
                              isOccupied ? Icons.directions_boat_filled_rounded : Icons.radar_rounded,
                              size: 15,
                              color: isOccupied ? statusColor : Colors.white24,
                            ),
                          ],
                        ),

                        // Orta: Gemi İsmi
                        Text(
                          shipName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: isOccupied ? FontWeight.bold : FontWeight.w600,
                            color: isOccupied ? Colors.white : Colors.white38,
                            letterSpacing: 0.2,
                          ),
                        ),

                        // Alt: Yük & Hız veya Boş Rozeti
                        Row(
                          children: [
                            if (isOccupied) ...[
                              if (yuk.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.only(right: 5),
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(4),
                                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                                  ),
                                  child: Text(
                                    yuk,
                                    style: const TextStyle(
                                      fontSize: 8.5,
                                      color: Color(0xFFF59E0B),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                decoration: BoxDecoration(
                                  color: statusColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  speed.isNotEmpty ? '$speed kt' : 'Bağlı',
                                  style: TextStyle(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                  ),
                                ),
                              ),
                            ] else ...[
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.radar_rounded, size: 10, color: Color(0xFF38BDF8)),
                                    SizedBox(width: 4),
                                    Text(
                                      'Boş Rıhtım',
                                      style: TextStyle(
                                        fontSize: 8.5,
                                        color: Color(0xFF38BDF8),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),

          // Alt Deniz Dalgası Animasyonu
          const AnimatedSeaWaveWidget(height: 10),
        ],
      ),
    );
  }
}

/// 4. İSG Canlı Kazasız Gün Sayacı & Güvenlik Kalkanı Animasyonu
class SafetyDaysBannerWidget extends StatefulWidget {
  final int daysWithoutAccident;

  const SafetyDaysBannerWidget({
    super.key,
    this.daysWithoutAccident = 184,
  });

  @override
  State<SafetyDaysBannerWidget> createState() => _SafetyDaysBannerWidgetState();
}

class _SafetyDaysBannerWidgetState extends State<SafetyDaysBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glowAlpha = 0.3 + (_pulseController.value * 0.4);

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF064E3B), Color(0xFF065F46)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: const Color(0xFF10B981).withValues(alpha: glowAlpha),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF10B981).withValues(alpha: glowAlpha * 0.4),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.15),
                ),
                child: const Icon(
                  Icons.verified_user_rounded,
                  color: Color(0xFF34D399),
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'HEDEF: SIFIR İŞ KAZASI',
                      style: GoogleFonts.orbitron(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: const Color(0xFF6EE7B7),
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          '${widget.daysWithoutAccident}',
                          style: GoogleFonts.orbitron(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 6),
                        const Text(
                          'GÜNDÜR KAZASIZ',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'İsdemir Liman ve Saha Operasyonları',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF10B981),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF10B981).withValues(alpha: glowAlpha),
                      blurRadius: 8,
                      spreadRadius: 3,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// 5. İSDEMİR Akkor Çelik Kıvılcım Parçacıkları (Ember Particles)
class IndustrialEmberParticlesWidget extends StatefulWidget {
  final int particleCount;
  final double height;
  const IndustrialEmberParticlesWidget({
    super.key,
    this.particleCount = 28,
    this.height = 400,
  });

  @override
  State<IndustrialEmberParticlesWidget> createState() => _IndustrialEmberParticlesWidgetState();
}

class _EmberParticle {
  double x;
  double y;
  final double size;
  final double speed;
  final double swaySpeed;
  final double swayDistance;
  final double phase;
  final Color color;
  final double baseOpacity;

  _EmberParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.swaySpeed,
    required this.swayDistance,
    required this.phase,
    required this.color,
    required this.baseOpacity,
  });
}

class _IndustrialEmberParticlesWidgetState extends State<IndustrialEmberParticlesWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_EmberParticle> _particles;
  final Random _random = Random();

  static const List<Color> _emberColors = [
    Color(0xFFFFB300),
    Color(0xFFFF7043),
    Color(0xFFFFD54F),
    Color(0xFFFF3D00),
  ];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _particles = List.generate(widget.particleCount, (index) {
      return _EmberParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        size: 1.5 + _random.nextDouble() * 2.8,
        speed: 0.08 + _random.nextDouble() * 0.16,
        swaySpeed: 1.5 + _random.nextDouble() * 3.0,
        swayDistance: 0.015 + _random.nextDouble() * 0.035,
        phase: _random.nextDouble() * 2 * pi,
        color: _emberColors[_random.nextInt(_emberColors.length)],
        baseOpacity: 0.4 + _random.nextDouble() * 0.55,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return CustomPaint(
            size: Size(double.infinity, widget.height),
            painter: _EmberPainter(
              progress: _controller.value,
              particles: _particles,
            ),
          );
        },
      ),
    );
  }
}

class _EmberPainter extends CustomPainter {
  final double progress;
  final List<_EmberParticle> particles;

  _EmberPainter({required this.progress, required this.particles});

  @override
  void paint(Canvas canvas, Size size) {
    for (final p in particles) {
      final currentYNorm = (p.y - (progress * p.speed * 5)) % 1.0;
      final actualY = (currentYNorm < 0 ? currentYNorm + 1.0 : currentYNorm) * size.height;

      final sway = sin((progress * 2 * pi * p.swaySpeed) + p.phase) * p.swayDistance;
      final actualX = ((p.x + sway) % 1.0) * size.width;

      final heightFactor = 1.0 - (actualY / size.height);
      final alpha = (sin(heightFactor * pi) * p.baseOpacity).clamp(0.0, 1.0);

      if (alpha <= 0.02) continue;

      final glowPaint = Paint()
        ..color = p.color.withValues(alpha: alpha * 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawCircle(Offset(actualX, actualY), p.size * 2.2, glowPaint);

      final corePaint = Paint()
        ..color = p.color.withValues(alpha: alpha)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(Offset(actualX, actualY), p.size, corePaint);
    }
  }

  @override
  bool shouldRepaint(covariant _EmberPainter oldDelegate) => true;
}

/// 6. Sanayi Vinci Kancasıyla Sayfa Yenileme (Industrial Crane Hook Pull-to-Refresh)
class IndustrialCraneRefreshIndicator extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;

  const IndustrialCraneRefreshIndicator({
    super.key,
    required this.child,
    required this.onRefresh,
  });

  @override
  State<IndustrialCraneRefreshIndicator> createState() => _IndustrialCraneRefreshIndicatorState();
}

class _IndustrialCraneRefreshIndicatorState extends State<IndustrialCraneRefreshIndicator> {
  bool _didVibrate = false;

  @override
  Widget build(BuildContext context) {
    return CustomRefreshIndicator(
      onRefresh: widget.onRefresh,
      offsetToArmed: 100.0,
      builder: (BuildContext context, Widget child, IndicatorController controller) {
        final dragProgress = controller.value.clamp(0.0, 1.5);

        if (controller.isArmed && !_didVibrate) {
          _didVibrate = true;
          HapticFeedback.heavyImpact();
        } else if (!controller.isArmed) {
          _didVibrate = false;
        }

        final cableHeight = (dragProgress * 55.0).clamp(0.0, 75.0);

        return Stack(
          children: [
            Transform.translate(
              offset: Offset(0.0, dragProgress * 65.0),
              child: child,
            ),
            if (dragProgress > 0.05)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 90,
                        height: 6,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B),
                          borderRadius: BorderRadius.circular(3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: cableHeight,
                        width: 28,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(width: 2, color: const Color(0xFF71717A)),
                            Container(width: 2, color: const Color(0xFF71717A)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E222A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: controller.isArmed
                                ? const Color(0xFFF59E0B)
                                : const Color(0xFF3F3F46),
                            width: 1.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: controller.isArmed
                                  ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                                  : Colors.black.withValues(alpha: 0.3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.anchor_rounded,
                              color: controller.isArmed
                                  ? const Color(0xFFF59E0B)
                                  : const Color(0xFFE50914),
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              controller.isLoading
                                  ? 'VARDİYA YÜKLENİYOR...'
                                  : controller.isArmed
                                      ? 'BIRAKIN (VİNÇ BAĞLANDI)'
                                      : 'İSDEMİR VİNCİ İNİYOR',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                                color: controller.isArmed
                                    ? const Color(0xFFF59E0B)
                                    : Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}
