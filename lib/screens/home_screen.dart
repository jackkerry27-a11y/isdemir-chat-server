import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

import '../models/user_model.dart';
import '../services/weather_service.dart';
import '../utils/socket_service.dart';
import '../utils/push_service.dart';
import '../utils/shift_logic.dart';
import '../widgets/glass_widgets.dart';

import 'weather_screen.dart';
import 'yemek_screen.dart';
import 'bordro_screen.dart';
import 'vardiya_screen.dart';
import 'yetkili_screen.dart';
import 'operasyon_ai_screen.dart';
import '../widgets/vip_gate.dart';

///  Apple iOS 18/19 Human Interface Guidelines (HIG) Tasarımlı Saydam Mavi Ana Ekran
class HomeScreen extends StatefulWidget {
  final UserModel user;
  final double totalSalary;
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final VoidCallback onSettingsTapped;
  final VoidCallback onIzinTapped;
  final VoidCallback? onVardiyaTapped;

  const HomeScreen({
    super.key,
    required this.user,
    required this.totalSalary,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.onSettingsTapped,
    required this.onIzinTapped,
    this.onVardiyaTapped,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _weatherTitle = '29°';
  String _weatherSubtitle = 'Güneşli';
  bool _isSalaryHidden = false;
  int _touchedChartSpot = -1;
  VardiyaGunu _selectedVardiya = VardiyaGunu.sali;
  bool _isVip = false;

  @override
  void initState() {
    super.initState();
    _isVip = widget.user.isVip;
    _checkVip();
    _fetchWeather();
    _loadSalaryVisibilityPreference();
    _loadSavedVardiya();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowShipSurvey();
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _checkVip() async {
    final status = await VipGate.checkVipStatus(user: widget.user);
    if (mounted && status != _isVip) {
      setState(() => _isVip = status);
    }
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.user.isVip != _isVip) {
      setState(() => _isVip = widget.user.isVip);
    }
  }

  Future<void> _loadSavedVardiya() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_vardiya_gunu');
    if (saved == 'carsamba') {
      if (mounted) setState(() => _selectedVardiya = VardiyaGunu.carsamba);
    } else if (saved == 'cuma') {
      if (mounted) setState(() => _selectedVardiya = VardiyaGunu.cuma);
    } else if (saved == 'cumartesi') {
      if (mounted) setState(() => _selectedVardiya = VardiyaGunu.cumartesi);
    } else {
      if (mounted) setState(() => _selectedVardiya = VardiyaGunu.sali);
    }
  }

  Future<void> _loadSalaryVisibilityPreference() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSalaryHidden = prefs.getBool('is_home_salary_hidden') ?? false;
    });
  }

  Future<void> _toggleSalaryVisibility() async {
    HapticFeedback.lightImpact();
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isSalaryHidden = !_isSalaryHidden;
    });
    await prefs.setBool('is_home_salary_hidden', _isSalaryHidden);
  }

  Future<void> _checkAndShowShipSurvey() async {
    try {
      if (!widget.user.isVip) return;
      final prefs = await SharedPreferences.getInstance();
      final nowStr = DateTime.now().toIso8601String().split('T').first;
      final lastSurveyDate = prefs.getString('last_ship_survey_date');

      if (lastSurveyDate == nowStr) return;

      final snap = await FirebaseFirestore.instance
          .collection('gemiler')
          .where('durum', whereIn: ['Gemi Başlama Alındı', 'Gemi Bitişte'])
          .limit(1)
          .get();

      if (snap.docs.isEmpty) return;

      final shipDoc = snap.docs.first;
      final data = shipDoc.data();
      final gemiAdi = data['gemiAdi'] ?? 'Bilinmeyen Gemi';
      final rihtimNo = data['rihtimNo'] ?? '?';

      if (!mounted) return;

      await showDialog(
        context: context,
        builder: (ctx) => _ShipSurveyDialog(
          docId: shipDoc.id,
          gemiAdi: gemiAdi,
          rihtimNo: rihtimNo.toString(),
          currentUserName: '${widget.user.firstName} ${widget.user.lastName}',
        ),
      );

      await prefs.setString('last_ship_survey_date', nowStr);
    } catch (e) {
      debugPrint('Anket hatasi: $e');
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted && data != null) {
      setState(() {
        _weatherTitle = '${data.temperature.round()}°';
        _weatherSubtitle = data.getWeatherDescription();
      });
    }
    WeatherService.checkAndTriggerWeatherNotification();
  }

  Future<List<Map<String, dynamic>>> _getCombinedNotifications() async {
    List<Map<String, dynamic>> finalNotifications = [];
    try {
      final dbData = await FirebaseFirestore.instance
          .collection('duyurular')
          .orderBy('tarih', descending: true)
          .get();
      finalNotifications.addAll(dbData.docs.map((doc) {
        var data = doc.data();
        if (data['tarih'] is Timestamp) {
          data['tarih'] = (data['tarih'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList());
      finalNotifications.removeWhere((n) {
        final t = (n['baslik'] ?? n['title'] ?? '').toString().toUpperCase();
        final c = (n['icerik'] ?? n['content'] ?? '').toString().toUpperCase();
        return t.contains('GALA') || c.contains('GALA');
      });
      if (!widget.user.isVip) {
        finalNotifications.removeWhere((n) {
          final t = (n['baslik'] ?? n['title'] ?? '').toString().toLowerCase();
          final c = (n['icerik'] ?? n['content'] ?? '').toString().toLowerCase();
          final type = (n['type'] ?? '').toString().toLowerCase();
          return type.startsWith('ship') || t.contains('gemi') || t.contains('rıhtım') || c.contains('gemi') || c.contains('rıhtım');
        });
      }
    } catch (e) {
      debugPrint('Duyuru error: $e');
    }
    return finalNotifications;
  }

  String _getCurrentShiftBadgeText() {
    final now = DateTime.now();
    final shift = ShiftLogic.getShiftType(now, vardiyaGunu: _selectedVardiya);

    if (shift == ShiftType.tatil) return 'Hafta Tatili';

    final currentMinutes = now.hour * 60 + now.minute;
    if (shift == ShiftType.sabah && currentMinutes >= 720 && currentMinutes < 750) {
      return 'Çay & Yemek Molası';
    } else if (shift == ShiftType.aksam && currentMinutes >= 1140 && currentMinutes < 1170) {
      return 'Çay & Yemek Molası';
    } else if (shift == ShiftType.gece && currentMinutes >= 180 && currentMinutes < 210) {
      return 'Çay & Yemek Molası';
    }

    switch (shift) {
      case ShiftType.sabah:
        return 'Gündüz Vardiyası (09:30 - 16:30)';
      case ShiftType.gece:
        return 'Gece Vardiyası (00:30 - 08:30)';
      case ShiftType.aksam:
        return 'Akşam Vardiyası (16:30 - 00:30)';
      case ShiftType.tatil:
        return 'İstirahat Günü';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['', 'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
    final days = ['', 'PAZARTESİ', 'SALI', 'ÇARŞAMBA', 'PERŞEMBE', 'CUMA', 'CUMARTESİ', 'PAZAR'];
    final dateIosCaption = '${days[now.weekday]}, ${now.day} ${months[now.month]} ${now.year}';

    final jobDetails = widget.user.currentJobDetails;
    final double mesaiKazanci = (widget.normalMesaiGun * jobDetails.normalMesaiRate) +
        (widget.bayramMesaiGun * jobDetails.bayramMesaiRate);

    return Scaffold(
      backgroundColor: const Color(0xFF040A16), // Hafif Saydam Gece Mavisi Derinlik
      body: Stack(
        children: [
          // 🌌 1. Apple iOS 18/19 Hafif Şeffaf Saydam Mavi Ambient Mesh Zemin
          _buildIosAmbientMeshBackground(),

          // 🌟 2. Ön Plan Akışkan iOS Katmanları
          SafeArea(
            top: true,
            bottom: true,
            child: RefreshIndicator(
              color: const Color(0xFF38BDF8), // Apple Sky Blue
              backgroundColor: const Color(0xFF0F1E36),
              onRefresh: () async {
                await _fetchWeather();
                setState(() {});
              },
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    //  Apple Dynamic Island Live Activity Kapsülü
                    _buildDynamicIslandCapsule()
                        .animate()
                        .fadeIn(duration: 350.ms)
                        .scale(begin: const Offset(0.92, 0.92), curve: Curves.easeOutBack),

                    const SizedBox(height: 10),

                    //  Apple iOS Header (Tarih, Hoş Geldin & Profil Zili)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: _buildIosNavigationBar(dateIosCaption),
                    ),

                    const SizedBox(height: 16),

                    // 🚀 Hızlı İşlemler Başlığı (Eskisi Gibi Hemen Üstte)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF00F0FF),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF00F0FF),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Hızlı İşlemler',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          _buildIosPillBadge('HIZLI MENÜ', const Color(0xFF38BDF8)),
                        ],
                      ),
                    ).animate(delay: 50.ms).fadeIn(duration: 350.ms),

                    const SizedBox(height: 10),

                    // 🚀 Hızlı Menü Yatay Akışı (Eskisi Gibi Hakedişin Üstünde)
                    _buildIosQuickActionsRow()
                        .animate(delay: 70.ms)
                        .fadeIn(duration: 400.ms)
                        .slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

                    const SizedBox(height: 20),

                    // 💳 Apple Wallet Titanium Hakediş & Bordro Kokpiti
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildTitaniumHakedisCard(jobDetails.baseSalary, mesaiKazanci)
                          .animate(delay: 110.ms)
                          .fadeIn(duration: 450.ms)
                          .slideY(begin: 0.04, end: 0),
                    ),

                    const SizedBox(height: 22),

                    // 🍱 Apple Bento Grid Hub
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF38BDF8),
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0xFF38BDF8),
                                      blurRadius: 6,
                                      spreadRadius: 1,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Operasyonel Bento Hub',
                                style: GoogleFonts.inter(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                          _buildIosPillBadge('APPLE HIG 2.0', const Color(0xFF38BDF8)),
                        ],
                      ),
                    ),

                    const SizedBox(height: 12),

                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildIosBentoGrid()
                          .animate(delay: 150.ms)
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.04, end: 0),
                    ),

                    const SizedBox(height: 110),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ──  APPLE DYNAMIC ISLAND LIVE ACTIVITY KAPSÜLÜ ──
  Widget _buildDynamicIslandCapsule() {
    return Center(
      child: BouncyTap(
        onTap: () {
          HapticFeedback.lightImpact();
          if (widget.onVardiyaTapped != null) {
            widget.onVardiyaTapped!();
          } else {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const VardiyaScreen()));
          }
        },
        child: Container(
          margin: const EdgeInsets.only(top: 4, bottom: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
          decoration: BoxDecoration(
            color: const Color(0xFF071326).withValues(alpha: 0.90), // Şeffaf saydam derin mavi cam
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: const Color(0xFF38BDF8).withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0A84FF).withValues(alpha: 0.18),
                blurRadius: 14,
                spreadRadius: 1,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.6),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Canlı Nabız / Saydam Mavi Aktivite Noktası
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.9),
                      blurRadius: 8,
                      spreadRadius: 1,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'LIVE ACTIVITY',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF38BDF8),
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                width: 3.5,
                height: 3.5,
                decoration: const BoxDecoration(
                  color: Colors.white30,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                _getCurrentShiftBadgeText(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white54, size: 10),
            ],
          ),
        ),
      ),
    );
  }

  // ──  APPLE IOS HEADER BAR ──
  Widget _buildIosNavigationBar(String dateCaption) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Apple HIG Tarih Başlığı (SF Pro Caption)
        Text(
          dateCaption,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF94A3B8), // Slate Gray
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 4),

        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Sol: Karşılama ve İsdemir OS
            Row(
              children: [
                // İSDEMİR Minimal Monogram (Saydam Mavi Çerçeveli)
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1F38).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.28)),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 3),
                        Container(width: 4, height: 22, decoration: BoxDecoration(color: const Color(0xFFEF4444), borderRadius: BorderRadius.circular(2))),
                        const SizedBox(width: 3),
                        Container(width: 4, height: 16, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Merhaba, ',
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                        Text(
                          widget.user.firstName,
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const Text(' 👋', style: TextStyle(fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 1),
                    Row(
                      children: [
                        Text(
                          'İSDEMİR Port OS',
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF38BDF8),
                          ),
                        ),
                        if (_isVip) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 13),
                        ],
                      ],
                    ),
                  ],
                ),
              ],
            ),

            // Sağ: Bildirim Zili & Profil Avatarı (Saydam Mavi Zemin)
            Row(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _getCombinedNotifications(),
                  builder: (context, snapshot) {
                    final duyurular = snapshot.data ?? [];
                    final count = duyurular.length;
                    return BouncyTap(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showNotifications(context, duyurular);
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0E1F38).withValues(alpha: 0.8),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.22)),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          clipBehavior: Clip.none,
                          children: [
                            const HugeIcon(
                              icon: HugeIcons.strokeRoundedNotification03,
                              color: Colors.white,
                              size: 19,
                            ),
                            if (count > 0)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: const Color(0xFF040A16), width: 1.5),
                                  ),
                                  child: Text(
                                    count > 9 ? '9+' : count.toString(),
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 8.5, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                BouncyTap(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    widget.onSettingsTapped();
                  },
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.7), width: 1.5),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF00F0FF).withValues(alpha: 0.25),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: const Color(0xFF0E1F38),
                          backgroundImage: SocketService.getAvatarProvider(widget.user.photoPath),
                          child: widget.user.photoPath == null ? const Icon(Icons.person, size: 20, color: Colors.white) : null,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          width: 11,
                          height: 11,
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF040A16), width: 2),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ── 💳 APPLE WALLET TITANIUM HAKEDİŞ KARTI (SAYDAM MAVİ DOKULU) ──
  Widget _buildTitaniumHakedisCard(double baseSalary, double mesaiKazanci) {
    return _buildIosGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      borderColor: const Color(0xFF38BDF8).withValues(alpha: 0.26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık & Biometrik / FaceID Göz Butonu
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.credit_card_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'GÜNCEL HAKEDİŞ',
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 6),
                          _buildIosPillBadge('OPTAPAY AI', const Color(0xFF10B981)),
                        ],
                      ),
                      Text(
                        'Ekim 2026 Net Kazanç Durumu',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),

              // Göz / FaceID Butonu
              BouncyTap(
                onTap: _toggleSalaryVisibility,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0E1F38).withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isSalaryHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: _isSalaryHidden ? const Color(0xFFF59E0B) : Colors.white,
                        size: 15,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _isSalaryHidden ? 'Gizli' : 'Göster',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w600, color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            'NET ÖDENECEK TUTAR (KESİNTİSİZ)',
            style: GoogleFonts.inter(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF94A3B8),
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),

          // Tutar Sayacı
          if (_isSalaryHidden)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Text(
                '₺ ••••••••',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 32,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '₺ ',
                  style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: Colors.white),
                ),
                AnimatedFlipCounter(
                  value: widget.totalSalary,
                  fractionDigits: 2,
                  thousandSeparator: '.',
                  decimalSeparator: ',',
                  duration: const Duration(milliseconds: 1300),
                  curve: Curves.easeOutExpo,
                  textStyle: GoogleFonts.inter(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -1.0,
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // Bordro Butonu
          BouncyTap(
            onTap: () {
              HapticFeedback.selectionClick();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BordroScreen(
                    user: widget.user,
                    normalMesaiGun: widget.normalMesaiGun,
                    bayramMesaiGun: widget.bayramMesaiGun,
                    ucretsizIzinGun: 0,
                  ),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7.5),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Bordro & Maaş Dekontu',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 11),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 📊 fl_chart Apple FinTech Trend Çizgisi
          SizedBox(
            height: 64,
            width: double.infinity,
            child: LineChart(
              LineChartData(
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineTouchData: LineTouchData(
                  handleBuiltInTouches: true,
                  touchTooltipData: LineTouchTooltipData(
                    getTooltipColor: (spot) => const Color(0xFF0E1F38),
                    tooltipBorder: const BorderSide(color: Color(0xFF00F0FF), width: 1.2),
                    getTooltipItems: (touchedSpots) {
                      return touchedSpots.map((barSpot) {
                        return LineTooltipItem(
                          _isSalaryHidden
                              ? 'Gün ${barSpot.x.toInt() + 1}\n₺ ••••'
                              : 'Gün ${barSpot.x.toInt() + 1}\n₺ ${(barSpot.y * 6200).toInt()}',
                          GoogleFonts.inter(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
                        );
                      }).toList();
                    },
                  ),
                  touchCallback: (event, response) {
                    if (response?.lineBarSpots != null && response!.lineBarSpots!.isNotEmpty) {
                      setState(() {
                        _touchedChartSpot = response.lineBarSpots!.first.spotIndex;
                      });
                    } else {
                      setState(() {
                        _touchedChartSpot = -1;
                      });
                    }
                  },
                ),
                lineBarsData: [
                  LineChartBarData(
                    spots: const [
                      FlSpot(0, 3.2),
                      FlSpot(1, 3.8),
                      FlSpot(2, 3.5),
                      FlSpot(3, 5.2),
                      FlSpot(4, 5.0),
                      FlSpot(5, 6.8),
                      FlSpot(6, 6.4),
                      FlSpot(7, 7.5),
                    ],
                    isCurved: true,
                    curveSmoothness: 0.35,
                    color: const Color(0xFF00F0FF), // Neon Cyan/Blue
                    barWidth: 2.2,
                    isStrokeCapRound: true,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, barData, index) {
                        final isSelected = index == _touchedChartSpot;
                        return FlDotCirclePainter(
                          radius: isSelected ? 5.0 : 2.5,
                          color: isSelected ? const Color(0xFF00FF66) : Colors.white,
                          strokeWidth: 1.5,
                          strokeColor: const Color(0xFF00F0FF),
                        );
                      },
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF00F0FF).withValues(alpha: 0.24),
                          const Color(0xFF00F0FF).withValues(alpha: 0.0),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                ],
                minX: 0,
                maxX: 7,
                minY: 2.5,
                maxY: 8.0,
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Taban Maaş & Mesai Kazancı Saydam Mavi Kapsülleri
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFF091424).withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.16)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const HugeIcon(icon: HugeIcons.strokeRoundedLayers01, color: Color(0xFF94A3B8), size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'TABAN MAAŞ',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                color: const Color(0xFF94A3B8),
                                letterSpacing: 0.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _isSalaryHidden
                                  ? Text('₺ •••••', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white))
                                  : AnimatedFlipCounter(
                                      value: baseSalary,
                                      prefix: '₺ ',
                                      fractionDigits: 2,
                                      thousandSeparator: '.',
                                      decimalSeparator: ',',
                                      duration: const Duration(milliseconds: 1200),
                                      textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(width: 1, height: 26, color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12.0),
                    child: Row(
                      children: [
                        const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Color(0xFF10B981), size: 17),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'MESAİ KAZANCI',
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  color: const Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 2),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: _isSalaryHidden
                                    ? Text('+ ₺ •••••', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)))
                                    : AnimatedFlipCounter(
                                        value: mesaiKazanci,
                                        prefix: '+ ₺ ',
                                        fractionDigits: 2,
                                        thousandSeparator: '.',
                                        decimalSeparator: ',',
                                        duration: const Duration(milliseconds: 1200),
                                        textStyle: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
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
            ),
          ),
        ],
      ),
    );
  }

  // ── 🚀 APPLE CONTINUOUS SQUIRCLE HIZLI MENÜ AKIŞI ──
  Widget _buildIosQuickActionsRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedPassport01,
            'İzinler',
            '14',
            ' gün kaldı',
            widget.onIzinTapped,
            accentColor: const Color(0xFF10B981), // Emerald Green
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedScan,
            'Operasyon AI',
            'Merkezi',
            ' • Canlı',
            () => _handleOperasyonAiAccess(context),
            accentColor: const Color(0xFF00F0FF), // Neon Azure
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedRestaurant01,
            'Gastronomi',
            'Günün',
            ' Menüsü',
            () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const YemekScreen()));
            },
            accentColor: const Color(0xFFF59E0B), // Warm Amber
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedSun03,
            'Hava Durumu',
            _weatherTitle,
            ' $_weatherSubtitle',
            () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
            },
            accentColor: const Color(0xFFFBBF24), // Gold Yellow
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedMegaphone01,
            'Duyurular',
            'Canlı',
            ' Bildirim',
            () async {
              final notifs = await _getCombinedNotifications();
              if (mounted) _showNotifications(context, notifs);
            },
            accentColor: const Color(0xFFEF4444), // Crimson Red
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedClock01,
            'Vardiya',
            'ChronoPlan',
            ' AI Takvim',
            () async {
              if (widget.onVardiyaTapped != null) {
                widget.onVardiyaTapped!();
              } else {
                await Navigator.push(context, MaterialPageRoute(builder: (_) => const VardiyaScreen()));
              }
              _loadSavedVardiya();
            },
            accentColor: const Color(0xFFA855F7), // Purple
          ),
          _buildIosSquircleButton(
            HugeIcons.strokeRoundedShieldUser,
            'Yetkili',
            'Merkezi',
            ' Yönetim',
            () => _handleYetkiliAccess(context),
            accentColor: const Color(0xFFDC2626), // Steel Red
          ),
        ],
      ),
    );
  }

  Widget _buildIosSquircleButton(
    List<List<dynamic>> icon,
    String title,
    String highlight,
    String subtitle,
    VoidCallback onTap, {
    required Color accentColor,
  }) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12.0),
        child: _buildIosGlassContainer(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          borderRadius: 20,
          child: SizedBox(
            width: 82,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accentColor.withValues(alpha: 0.35)),
                  ),
                  child: Center(
                    child: HugeIcon(icon: icon, color: accentColor, size: 20),
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                RichText(
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    children: [
                      if (highlight.isNotEmpty)
                        TextSpan(
                          text: highlight,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: accentColor),
                        ),
                      TextSpan(
                        text: subtitle,
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── 🍱 APPLE IOS BENTO GRID HUB ──
  Widget _buildIosBentoGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildIosBentoTile(
                icon: HugeIcons.strokeRoundedPassport01,
                iconColor: const Color(0xFF10B981),
                title: 'YILLIK İZİN HAKKI',
                mainValue: '14 Gün Kaldı',
                subValue: '14 / 28 Gün Aktif İzin',
                badgeText: 'Aktif Hak',
                badgeColor: const Color(0xFF10B981),
                onTap: widget.onIzinTapped,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIosBentoTile(
                icon: HugeIcons.strokeRoundedSun03,
                iconColor: const Color(0xFFFBBF24),
                title: 'WEATHERNEXT 3 AI',
                mainValue: '$_weatherTitle $_weatherSubtitle',
                subValue: '100m Vinç: Güvenli Rüzgar',
                badgeText: 'DeepMind AI',
                badgeColor: const Color(0xFF38BDF8),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildIosBentoTile(
                icon: HugeIcons.strokeRoundedRestaurant01,
                iconColor: const Color(0xFFF59E0B),
                title: 'GÜNÜN MENÜSÜ',
                mainValue: 'Gastronomi',
                subValue: 'Gurme Menü & Kalori',
                badgeText: 'Bugün',
                badgeColor: const Color(0xFFF59E0B),
                onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const YemekScreen()));
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildIosBentoTile(
                icon: HugeIcons.strokeRoundedCargoShip,
                iconColor: const Color(0xFF38BDF8),
                title: 'LİMAN & RADAR',
                mainValue: 'AIS Canlı Takip',
                subValue: '4 Aktif Gemi Rıhtımda',
                badgeText: 'Canlı AIS',
                badgeColor: const Color(0xFF38BDF8),
                onTap: () {
                  _checkAndShowShipSurvey();
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildIosBentoTile({
    required List<List<dynamic>> icon,
    required Color iconColor,
    required String title,
    required String mainValue,
    required String subValue,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: _buildIosGlassContainer(
        padding: const EdgeInsets.all(14),
        borderRadius: 20,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.35)),
                  ),
                  child: HugeIcon(icon: icon, color: iconColor, size: 19),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.4),
            ),
            const SizedBox(height: 3),
            Text(
              mainValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              subValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // ── 🛡️ YETKİLİ VE OPERASYON AI GÜVENLİK YÖNETİMİ ──
  Future<void> _handleYetkiliAccess(BuildContext context) async {
    HapticFeedback.mediumImpact();

    if (widget.user.isYetkili) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: widget.user)));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626))),
    );

    bool liveIsYetkili = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null) {
        final query = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          if (data['is_yetkili'] == true || data['yetkili'] == true) {
            liveIsYetkili = true;
            widget.user.isYetkili = true;
            await widget.user.save();
          }
        }
      }
    } catch (_) {}

    if (context.mounted) Navigator.pop(context);

    if (liveIsYetkili) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: widget.user)));
      }
      return;
    }

    if (context.mounted) {
      _showYetkiliAuthDialog(context);
    }
  }

  void _showYetkiliAuthDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: _buildIosGlassContainer(
          padding: const EdgeInsets.all(22.0),
          borderRadius: 24,
          borderColor: const Color(0xFFDC2626).withValues(alpha: 0.5),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.16),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                ),
                child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Yetkili Erişimi Gerekli',
                style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 8),
              Text(
                'Bu bölüme erişmek için Sistem Yöneticisi tarafından hesabınıza "Yetkili" unvanı tanımlanmış olmalıdır.\n\nYönetici şifreniz varsa giriş yapabilirsiniz:',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
              ),
              const SizedBox(height: 18),
              TextField(
                controller: pinController,
                obscureText: true,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Yetkili Yönetici Şifresi',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626), size: 18),
                  filled: true,
                  fillColor: const Color(0xFF091424),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      onPressed: () async {
                        if (pinController.text.trim() == '4896281aa') {
                          widget.user.isYetkili = true;
                          await widget.user.save();
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (context.mounted) {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: widget.user)));
                          }
                        } else {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(content: Text('Hatalı yetkili şifresi!'), backgroundColor: Colors.red),
                          );
                        }
                      },
                      child: Text('Giriş', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleOperasyonAiAccess(BuildContext context) async {
    HapticFeedback.mediumImpact();

    if (!widget.user.isYetkili) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final cihazId = prefs.getString('cihaz_id');
        if (cihazId != null) {
          final query = await FirebaseFirestore.instance
              .collection('personeller')
              .where('cihaz_id', isEqualTo: cihazId)
              .limit(1)
              .get();
          if (query.docs.isNotEmpty) {
            final data = query.docs.first.data();
            if (data['is_yetkili'] == true || data['yetkili'] == true) {
              widget.user.isYetkili = true;
              await widget.user.save();
            }
          }
        }
      } catch (_) {}
    }

    if (context.mounted) {
      _showOperasyonAiAuthDialog(context);
    }
  }

  void _showOperasyonAiAuthDialog(BuildContext context) {
    final passController = TextEditingController();
    bool isObscured = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return Dialog(
            backgroundColor: Colors.transparent,
            child: _buildIosGlassContainer(
              padding: const EdgeInsets.all(22.0),
              borderRadius: 24,
              borderColor: const Color(0xFF00F0FF).withValues(alpha: 0.5),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.16),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.5), width: 1.4),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF00F0FF), size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OPERASYON AI MERKEZİ',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'YALNIZCA YÖNETİCİ & ADMIN',
                      style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFEF4444)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ultralytics YOLOv11 canlı kamera ve çoklu hedef takip merkezine erişmek için yönetici güvenlik şifrenizi giriniz.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: passController,
                    obscureText: isObscured,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Admin Giriş Şifresi',
                      hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
                      prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF00F0FF), size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(isObscured ? Icons.visibility_off_rounded : Icons.visibility_rounded, color: const Color(0xFF94A3B8), size: 18),
                        onPressed: () => setDialogState(() => isObscured = !isObscured),
                      ),
                      filled: true,
                      fillColor: const Color(0xFF091424),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF1E2D4A))),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF00F0FF), width: 1.5)),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF00F0FF),
                            foregroundColor: Colors.black,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            elevation: 0,
                          ),
                          onPressed: () async {
                            if (passController.text.trim() == '4896281aa') {
                              widget.user.isYetkili = true;
                              await widget.user.save();

                              if (ctx.mounted) Navigator.pop(ctx);
                              if (context.mounted) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => OperasyonAiScreen(user: widget.user)),
                                );
                              }
                            } else {
                              HapticFeedback.heavyImpact();
                              ScaffoldMessenger.of(ctx).showSnackBar(
                                const SnackBar(
                                  content: Text('Hatalı güvenlik şifresi! Erişim reddedildi.'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          },
                          child: Text('Giriş Yap', style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 📢 APPLE MODAL SHEET DUYURULAR PANOSU ──
  void _showNotifications(BuildContext context, List<Map<String, dynamic>> duyurular) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF081426).withValues(alpha: 0.94),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
              ),
              child: SizedBox(
                height: MediaQuery.of(context).size.height * 0.72,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tutamaç (iOS Drag Handle)
                    Center(
                      child: Container(
                        width: 38,
                        height: 4.5,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 22.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.campaign_rounded, color: Color(0xFFEF4444), size: 24),
                              const SizedBox(width: 8),
                              Text(
                                'Duyurular Panosu',
                                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close_rounded, color: Colors.white70, size: 22),
                            onPressed: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                    const Divider(color: Color(0xFF1E2D4A)),
                    Expanded(
                      child: duyurular.isEmpty
                          ? Center(
                              child: Text(
                                'Henüz duyuru bulunmuyor.',
                                style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                              itemCount: duyurular.length,
                              itemBuilder: (context, index) {
                                final d = duyurular[index];
                                final isAlert = d['is_alert'] == true;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16.0),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0D1C34).withValues(alpha: 0.8),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: isAlert ? const Color(0xFFEF4444).withValues(alpha: 0.6) : const Color(0xFF38BDF8).withValues(alpha: 0.16),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: (isAlert ? const Color(0xFFEF4444) : const Color(0xFF0284C7)).withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          isAlert ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                          color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    d['baslik'] ?? '',
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.white),
                                                  ),
                                                ),
                                                Text(
                                                  (d['tarih'] ?? '').toString().split('T').first,
                                                  style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              d['icerik'] ?? '',
                                              style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), height: 1.4, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ).animate(delay: (index * 40).ms).fadeIn(duration: 300.ms).slideY(begin: 0.05, end: 0);
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ──  APPLE FROSTED GLASS YARDIMCI BİLEŞENLERİ ──

  // Apple Ambient Mesh Glow Canvas (Hafif Şeffaf Saydam Mavi)
  Widget _buildIosAmbientMeshBackground() {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Derin Gece Mavisi Zemin
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF040A16), // Derin safir mavi
                  Color(0xFF060E1E),
                  Color(0xFF03070E),
                ],
              ),
            ),
          ),

          // Üst Sol - Canlı Saydam Mavi / Azure Glow
          Positioned(
            top: -60,
            left: -40,
            child: Container(
              width: 380,
              height: 380,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.28),
                    const Color(0xFF0A84FF).withValues(alpha: 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Orta Sağ - Yumuşak Cam Mavisi / Electric Cyan Glow
          Positioned(
            top: 200,
            right: -60,
            child: Container(
              width: 340,
              height: 340,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF007AFF).withValues(alpha: 0.22),
                    const Color(0xFF0EA5E9).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Alt Sol - Hafif Saydam Akuamarin / Zümrüt Mavi Glow
          Positioned(
            bottom: 120,
            left: -30,
            child: Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF0284C7).withValues(alpha: 0.18),
                    const Color(0xFF0D9488).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Alt Sağ - Derin Kobalt Mavi Parıltı
          Positioned(
            bottom: -50,
            right: -20,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF1D4ED8).withValues(alpha: 0.16),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Apple iOS Hafif Şeffaf Saydam Mavi Buzlu Cam Konteyneri (60/120 FPS Buttery Smooth)
  Widget _buildIosGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(16),
    double borderRadius = 22,
    Color? borderColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0F1E36).withValues(alpha: 0.72), // Hafif şeffaf saydam mavi ton
            const Color(0xFF091322).withValues(alpha: 0.82),
          ],
        ),
        border: Border.all(
          color: borderColor ?? const Color(0xFF38BDF8).withValues(alpha: 0.18),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.10),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // Apple iOS Mini Pill Rozet
  Widget _buildIosPillBadge(String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.40)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      ),
    );
  }
}

// ── 🚢 GEMİ ANKET DİYALOGU (100% PRESERVED & APPLE SAYDAM MAVİ STYLED) ──
class _ShipSurveyDialog extends StatelessWidget {
  final String docId;
  final String gemiAdi;
  final String rihtimNo;
  final String currentUserName;

  const _ShipSurveyDialog({
    required this.docId,
    required this.gemiAdi,
    required this.rihtimNo,
    required this.currentUserName,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: const Color(0xFF081426).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const HugeIcon(icon: HugeIcons.strokeRoundedCargoShip, size: 40, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 16),
                Text(
                  'Gemi Durum Güncellemesi',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Şu an $rihtimNo. Rıhtımdaki "$gemiAdi" gemisinin durumu nedir?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(color: const Color(0xFFCBD5E1), fontSize: 13),
                ),
                const SizedBox(height: 20),
                _buildOptionButton(context, 'Gemi Başlama Alındı', const Color(0xFF10B981)),
                const SizedBox(height: 10),
                _buildOptionButton(context, 'Gemi Bitişte', const Color(0xFFF59E0B)),
                const SizedBox(height: 10),
                _buildOptionButton(context, 'Gemi Bitti', const Color(0xFF38BDF8)),
                const SizedBox(height: 10),
                _buildOptionButton(context, 'Limandan Ayrıldı', const Color(0xFF94A3B8)),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Daha Sonra', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOptionButton(BuildContext context, String durum, Color color) {
    return SizedBox(
      width: double.infinity,
      height: 46,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color.withValues(alpha: 0.18),
          side: BorderSide(color: color.withValues(alpha: 0.45)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          elevation: 0,
        ),
        onPressed: () async {
          HapticFeedback.lightImpact();
          await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
            'durum': durum,
            'sonGuncelleme': FieldValue.serverTimestamp(),
            'guncelleyenKisi': currentUserName,
          });

          PushService.sendPushNotification(
            title: 'Gemi Durumu Güncellendi',
            content: '$currentUserName: "$gemiAdi" gemisini "$durum" olarak güncelledi.',
            isVipOnly: true,
            additionalData: {'type': 'ship_survey_update', 'ship': gemiAdi},
          );

          if (context.mounted) Navigator.pop(context);
        },
        child: Text(durum, style: GoogleFonts.inter(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ),
    );
  }
}
