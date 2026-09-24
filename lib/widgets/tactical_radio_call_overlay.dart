import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../screens/telsiz_screen.dart';
import '../utils/radio_sound_effects.dart';

class TacticalRadioCallOverlay {
  static OverlayEntry? _currentEntry;
  static Timer? _autoDismissTimer;

  /// Ekranda aktif bir çağrı overlay'i varsa kapatır
  static void dismiss() {
    _autoDismissTimer?.cancel();
    _autoDismissTimer = null;
    _currentEntry?.remove();
    _currentEntry = null;
  }

  /// Ekranın üstünden kayarak inen Taktik Telsiz Çağrı HUD Kartını gösterir
  static void show({
    required BuildContext context,
    required String inviterName,
    required String channel,
    required String channelName,
    required String freq,
    UserModel? user,
  }) {
    // Varsa eski kartı kaldır
    dismiss();

    // 2-Tonlu Taktik Selcall / Paging Ses Efektini ve Çift Titreşimi Çal
    RadioSoundEffects.playTacticalCallAlert();

    OverlayState? overlayState = Overlay.maybeOf(context, rootOverlay: true);
    if (overlayState == null) {
      try {
        overlayState = Navigator.of(context, rootNavigator: true).overlay;
      } catch (_) {}
    }

    if (overlayState == null) {
      debugPrint('[TacticalRadioCallOverlay] OverlayState bulunamadı.');
      return;
    }

    _currentEntry = OverlayEntry(
      builder: (ctx) => _TacticalRadioBannerWidget(
        inviterName: inviterName,
        channel: channel,
        channelName: channelName,
        freq: freq,
        user: user,
        onDismiss: dismiss,
        onConnect: () async {
          dismiss();
          final effectiveUser = user ?? await UserModel.load();
          if (effectiveUser != null && ctx.mounted) {
            Navigator.of(context, rootNavigator: true).push(
              MaterialPageRoute(
                builder: (_) => TelsizScreen(user: effectiveUser, initialChannel: channel),
              ),
            );
          }
        },
      ),
    );

    overlayState.insert(_currentEntry!);

    // 8 saniye sonra otomatik kapanma
    _autoDismissTimer = Timer(const Duration(seconds: 8), () {
      dismiss();
    });
  }
}

class _TacticalRadioBannerWidget extends StatefulWidget {
  final String inviterName;
  final String channel;
  final String channelName;
  final String freq;
  final UserModel? user;
  final VoidCallback onDismiss;
  final VoidCallback onConnect;

  const _TacticalRadioBannerWidget({
    required this.inviterName,
    required this.channel,
    required this.channelName,
    required this.freq,
    required this.user,
    required this.onDismiss,
    required this.onConnect,
  });

  @override
  State<_TacticalRadioBannerWidget> createState() => _TacticalRadioBannerWidgetState();
}

class _TacticalRadioBannerWidgetState extends State<_TacticalRadioBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 8,
      left: 12,
      right: 12,
      child: Material(
        color: Colors.transparent,
        child: Dismissible(
          key: const Key('tactical_radio_call_banner'),
          direction: DismissDirection.up,
          onDismissed: (_) => widget.onDismiss(),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xF50F1417),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.7), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00FF66).withValues(alpha: 0.25),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Arka plan taktik scanline çizgisi
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.05,
                      child: CustomPaint(
                        painter: _TacticalGridPainter(),
                      ),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Üst Başlık Satırı (RX Durumu, Çağıran Kişi, Kapatma)
                        Row(
                          children: [
                            // Yanıp sönen RX LED
                            AnimatedBuilder(
                              animation: _animController,
                              builder: (ctx, _) {
                                final glow = _animController.value;
                                return Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00FF66),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF00FF66).withValues(alpha: 0.4 + glow * 0.6),
                                        blurRadius: 6 + glow * 6,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                            const SizedBox(width: 8),

                            // Telsiz Çağrı Rozeti
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF00FF66).withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'RX CANLI ÇAĞRI',
                                style: GoogleFonts.orbitron(
                                  color: const Color(0xFF00FF66),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.1,
                                ),
                              ),
                            ),
                            const Spacer(),

                            // Minyatür frekans dalgası
                            _buildMiniWaveform(),

                            const SizedBox(width: 8),
                            InkWell(
                              onTap: widget.onDismiss,
                              borderRadius: BorderRadius.circular(12),
                              child: Padding(
                                padding: const EdgeInsets.all(4),
                                child: Icon(Icons.close_rounded, color: Colors.white.withValues(alpha: 0.6), size: 18),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // Ana İçerik: Çağıran Personel ve Kanal Bilgisi
                        Row(
                          children: [
                            // Telsiz İkon Avatarı
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF00FF66).withValues(alpha: 0.2),
                                    const Color(0xFF00FF66).withValues(alpha: 0.05),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.4)),
                              ),
                              child: const Center(
                                child: Icon(Icons.cell_tower_rounded, color: Color(0xFF00FF66), size: 24),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // Personel Adı ve Frekans Detayı
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    widget.inviterName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      const Icon(Icons.sensors_rounded, color: Color(0xFFF59E0B), size: 12),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          '${widget.channelName} (${widget.freq})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: GoogleFonts.orbitron(
                                            color: const Color(0xFFF59E0B),
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Alt Aksiyon Barı: "MANDALA BAĞLAN" Butonu
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: widget.onConnect,
                                icon: const Icon(Icons.mic_rounded, color: Colors.black, size: 18),
                                label: Text(
                                  'MANDALA BAĞLAN // FREKANSA GİR',
                                  style: GoogleFonts.orbitron(
                                    color: Colors.black,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF00FF66),
                                  foregroundColor: Colors.black,
                                  elevation: 6,
                                  shadowColor: const Color(0xFF00FF66).withValues(alpha: 0.5),
                                  padding: const EdgeInsets.symmetric(vertical: 10),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
            .animate()
            .slideY(begin: -0.6, end: 0, duration: 400.ms, curve: Curves.easeOutBack)
            .fadeIn(duration: 250.ms),
      ),
    );
  }

  Widget _buildMiniWaveform() {
    return AnimatedBuilder(
      animation: _animController,
      builder: (ctx, _) {
        final val = _animController.value;
        final heights = [
          8 + 6 * (val * 0.8),
          12 + 10 * ((1 - val) * 0.9),
          16 + 8 * (val),
          10 + 12 * ((val * 1.2).clamp(0.0, 1.0)),
          14 + 6 * ((1 - val)),
        ];

        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(heights.length, (idx) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1.5),
              width: 2.5,
              height: heights[idx],
              decoration: BoxDecoration(
                color: const Color(0xFF00FF66),
                borderRadius: BorderRadius.circular(2),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF00FF66).withValues(alpha: 0.6),
                    blurRadius: 3,
                  ),
                ],
              ),
            );
          }),
        );
      },
    );
  }
}

class _TacticalGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 0.5;

    const step = 8.0;
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
