import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../utils/push_service.dart';

class VipGate {
  /// Kullanıcının VIP yetkisini doğrular.
  /// Önce yerel önbelleği kontrol eder, ardından Firestore ile anlık senkronize eder.
  static Future<bool> checkVipStatus({UserModel? user}) async {
    bool isVip = user?.isVip ?? false;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (!isVip) {
        isVip = prefs.getBool('isVip') ?? false;
      }

      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null) {
        final query = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final remoteVip = query.docs.first.data()['is_vip'] == true;
          isVip = remoteVip;
          await prefs.setBool('isVip', remoteVip);
          PushService.setVipTag(remoteVip);
          if (user != null) {
            user.isVip = remoteVip;
            await user.save();
          }
        }
      }
    } catch (e) {
      debugPrint('VipGate yetki kontrol hatası: $e');
    }

    PushService.setVipTag(isVip);
    return isVip;
  }

  /// Modern VIP Erişim Engellendi Modal İletişim Kutusunu Gösterir.
  static void showAccessDeniedDialog(
    BuildContext context, {
    UserModel? user,
    VoidCallback? onGranted,
  }) {
    HapticFeedback.heavyImpact();
    showDialog(
      context: context,
      builder: (ctx) => _VipAccessDeniedDialog(user: user, onGranted: onGranted),
    );
  }

  /// showAccessDeniedDialog ile aynı işlevi gören takma ad
  static void showVipLockDialog(
    BuildContext context, {
    UserModel? user,
    VoidCallback? onGranted,
  }) {
    showAccessDeniedDialog(context, user: user, onGranted: onGranted);
  }
}

class _VipAccessDeniedDialog extends StatefulWidget {
  final UserModel? user;
  final VoidCallback? onGranted;

  const _VipAccessDeniedDialog({this.user, this.onGranted});

  @override
  State<_VipAccessDeniedDialog> createState() => _VipAccessDeniedDialogState();
}

class _VipAccessDeniedDialogState extends State<_VipAccessDeniedDialog> {
  bool _isChecking = false;

  Future<void> _checkAgain() async {
    setState(() => _isChecking = true);
    HapticFeedback.mediumImpact();

    final isVip = await VipGate.checkVipStatus(user: widget.user);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (isVip) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.verified_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VIP yetkiniz doğrulandı! Erişim sağlandı.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      widget.onGranted?.call();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1C1917),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFFBBF24)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VIP yetkisi bulunamadı. Lütfen yöneticinizle görüşün.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF14181F),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
      ),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 26),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VIP ERİŞİM KİLİDİ',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'YALNIZCA VIP PERSONEL',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF59E0B),
                    fontSize: 10.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined, color: Color(0xFFFBBF24), size: 12),
                const SizedBox(width: 6),
                Text(
                  'KOD: 403 // TACTICAL SECURE PORT',
                  style: GoogleFonts.orbitron(
                    color: const Color(0xFFFBBF24),
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'İskenderun Demir & Çelik Limanı rıhtım radar sistemi, tahliye/yükleme durumları ve operasyonel gemi kayıtları yalnızca VIP yetkisine sahip personellerin erişimine açıktır.\n\nErişim yetkisi almak için liman amirliği veya sistem yöneticisi ile iletişime geçiniz.',
            style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.45),
          ),
        ],
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                ),
                onPressed: _isChecking ? null : _checkAgain,
                child: _isChecking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)),
                      )
                    : Text(
                        'DURUMU YENİLE',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFBBF24),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF27272A),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  elevation: 0,
                ),
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'ANLAŞILDI',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// GemilerScreen veya benzeri VIP ekranlar için tam sayfa engelleme görünümü
class VipRestrictedView extends StatefulWidget {
  final UserModel? user;
  final VoidCallback onAuthorized;
  final VoidCallback? onBack;

  const VipRestrictedView({
    super.key,
    this.user,
    required this.onAuthorized,
    this.onBack,
  });

  @override
  State<VipRestrictedView> createState() => _VipRestrictedViewState();
}

class _VipRestrictedViewState extends State<VipRestrictedView> {
  bool _isChecking = false;

  Future<void> _recheckStatus() async {
    setState(() => _isChecking = true);
    HapticFeedback.mediumImpact();

    final isVip = await VipGate.checkVipStatus(user: widget.user);

    if (!mounted) return;
    setState(() => _isChecking = false);

    if (isVip) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.verified_rounded, color: Colors.white),
              SizedBox(width: 10),
              Text(
                'VIP yetkiniz doğrulandı! Hoş geldiniz.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      );
      widget.onAuthorized();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF1C1917),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          content: Row(
            children: const [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFFBBF24)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Henüz VIP yetkisi tanımlanmamış. Amirinizle görüşünüz.',
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14181F),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              'GÜVENLİK PROTOKOLÜ',
              style: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Glowing golden lock badge
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        const Color(0xFFF59E0B).withValues(alpha: 0.05),
                        Colors.transparent,
                      ],
                    ),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1B18),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.6), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: Color(0xFFFBBF24),
                        size: 34,
                      ),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat(reverse: true))
                 .scale(begin: const Offset(0.96, 0.96), end: const Offset(1.04, 1.04), duration: 1800.ms),

                const SizedBox(height: 24),

                // Tactical tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFFBBF24), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        'KOD: 403 // VIP PROTOKOLÜ',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFBBF24),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                Text(
                  'VIP ERİŞİM KİLİDİ',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 8),

                Text(
                  'YALNIZCA VIP PERSONEL YETKİSİ GEREKLİDİR',
                  style: GoogleFonts.inter(
                    color: const Color(0xFFF59E0B),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                // Info Container
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFF14181F),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF262D3D), width: 1.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Bu operasyonel rıhtım radar modülü, canlı gemi takip telemetrisi ve vardiya puantaj raporları gizli liman operasyonları kapsamında sadece VIP yetkili personellerin erişimine açıktır.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFFCBD5E1),
                          fontSize: 13,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: Color(0xFF262D3D), height: 1),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Gerekli Yetki Düzeyi:', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Color(0xFFFBBF24), size: 14),
                              const SizedBox(width: 4),
                              Text('VIP Operatör', style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 12)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Mevcut Durumunuz:', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'Standart Personel (Yetkisiz)',
                              style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // Action Buttons
                Row(
                  children: [
                    // Retry Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFF59E0B), width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          ),
                          onPressed: _isChecking ? null : _recheckStatus,
                          icon: _isChecking
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFFFBBF24)),
                                )
                              : const Icon(Icons.refresh_rounded, color: Color(0xFFFBBF24), size: 18),
                          label: Text(
                            'Yetkiyi Yenile',
                            style: GoogleFonts.orbitron(color: const Color(0xFFFBBF24), fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Back to Home Button
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF27272A),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            elevation: 0,
                          ),
                          onPressed: widget.onBack ?? () => Navigator.pop(context),
                          child: Text(
                            'Geri Dön',
                            style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
