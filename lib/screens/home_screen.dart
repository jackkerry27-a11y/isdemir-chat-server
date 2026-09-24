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
import '../widgets/industrial_animations.dart';
import '../widgets/glass_widgets.dart';

import 'weather_screen.dart';
import 'posta_listesi_screen.dart';
import 'bordro_screen.dart';
import 'vardiya_screen.dart';
import 'yemek_screen.dart';
import 'yetkili_screen.dart';
import 'operasyon_ai_screen.dart';
import '../widgets/vip_gate.dart';
import '../widgets/vip_hologram_card.dart';

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
  WeatherData? _weatherData;
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
      // 🔒 Gemiyle ilgili anket ve bildirimleri sadece VIP olanlar görür
      if (!widget.user.isVip) return;
      final prefs = await SharedPreferences.getInstance();
      final nowStr = DateTime.now().toIso8601String().split('T').first;
      final lastSurveyDate = prefs.getString('last_ship_survey_date');

      // Günde sadece 1 kez çıkması için
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
      debugPrint('Anket hatası: $e');
    }
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted && data != null) {
      setState(() {
        _weatherData = data;
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



  // Aktif vardiya ve mola durumunu hesapla
  String _getCurrentShiftBadgeText() {
    final now = DateTime.now();
    final shift = ShiftLogic.getShiftType(now, vardiyaGunu: _selectedVardiya);

    if (shift == ShiftType.tatil) return '🏖️ Hafta Tatili';

    // Mola saatleri kontrolü
    final currentMinutes = now.hour * 60 + now.minute;
    if (shift == ShiftType.sabah && currentMinutes >= 720 && currentMinutes < 750) {
      return '☕ Çay & Yemek Molası';
    } else if (shift == ShiftType.aksam && currentMinutes >= 1140 && currentMinutes < 1170) {
      return '☕ Çay & Yemek Molası';
    } else if (shift == ShiftType.gece && currentMinutes >= 180 && currentMinutes < 210) {
      return '☕ Çay & Yemek Molası';
    }

    switch (shift) {
      case ShiftType.sabah:
        return '☀️ Gündüz Vardiyası';
      case ShiftType.gece:
        return '🌙 Gece Vardiyası';
      case ShiftType.aksam:
        return '🌆 Akşam Vardiyası';
      case ShiftType.tatil:
        return '🏖️ Tatil Günü';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final days = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final dateStr = '${now.day} ${months[now.month]} ${now.year}, ${days[now.weekday]}';

    final jobDetails = widget.user.currentJobDetails;
    final double mesaiKazanci = (widget.normalMesaiGun * jobDetails.normalMesaiRate) +
        (widget.bayramMesaiGun * jobDetails.bayramMesaiRate);

    return Scaffold(
      backgroundColor: const Color(0xFF090A0F),
      body: IndustrialCraneRefreshIndicator(
        onRefresh: () async {
          await _fetchWeather();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Stack(
            children: [
              // 🏭 Fabrika Arkaplan Görseli + Yumuşak Gradient Maske
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 440,
                child: ShaderMask(
                  shaderCallback: (rect) {
                    return const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.black, Colors.transparent],
                      stops: [0.35, 1.0],
                    ).createShader(rect);
                  },
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    'assets/images/factory_bg.jpg',
                    fit: BoxFit.cover,
                    opacity: const AlwaysStoppedAnimation(0.45),
                  ),
                ),
              ),

              // 🔥 İSDEMİR Akkor Çelik Kıvılcım Parçacıkları (Ember Particles)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 440,
                child: IndustrialEmberParticlesWidget(
                  particleCount: 26,
                  height: 440,
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 56),

                  // ── 🌟 1. ÜST BAR: DYNAMIC ISLAND & KİŞİSEL KOKPİT ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            // İSDEMİR 3-Bar Logosu (Metalik Çelik Parıltısı)
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: const Color(0xFF161922).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                    blurRadius: 14,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(width: 6, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 3.5),
                                    Container(width: 6, height: 28, decoration: BoxDecoration(color: const Color(0xFFDC2626), borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 3.5),
                                    Container(width: 6, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'isdemir OS',
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    Text(
                                      'Hoş geldin, ',
                                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12.5),
                                    ),
                                    Text(
                                      widget.user.firstName,
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                                    ),
                                    const Text(' 👋', style: TextStyle(fontSize: 12.5)),
                                    if (_isVip) ...[
                                      const SizedBox(width: 8),
                                      InkWell(
                                        onTap: () {
                                          HapticFeedback.mediumImpact();
                                          VipCardModal.show(context, user: widget.user);
                                        },
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFF59E0B), Color(0xFFD97706), Color(0xFFB45309)],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              ),
                                            ],
                                            border: Border.all(color: const Color(0xFFFDE68A), width: 1),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Text('👑', style: TextStyle(fontSize: 10)),
                                              const SizedBox(width: 3),
                                              Text(
                                                'VIP KİMLİK',
                                                style: GoogleFonts.orbitron(
                                                  fontSize: 8.5,
                                                  fontWeight: FontWeight.w900,
                                                  color: Colors.white,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Sağ Taraf: Bildirim Zili & Profil Avatarı
                        Row(
                          children: [
                            FutureBuilder<List<Map<String, dynamic>>>(
                              future: _getCombinedNotifications(),
                              builder: (context, snapshot) {
                                final duyurular = snapshot.data ?? [];
                                final count = duyurular.length;
                                return InkWell(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    _showNotifications(context, duyurular);
                                  },
                                  borderRadius: BorderRadius.circular(22),
                                  child: Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF141722).withValues(alpha: 0.85),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF272A36), width: 1.2),
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
                                                color: const Color(0xFFDC2626),
                                                borderRadius: BorderRadius.circular(10),
                                                border: Border.all(color: const Color(0xFF090A0F), width: 2),
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
                            InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                widget.onSettingsTapped();
                              },
                              borderRadius: BorderRadius.circular(24),
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    radius: 21,
                                    backgroundColor: const Color(0xFF1E2230),
                                    backgroundImage: SocketService.getAvatarProvider(widget.user.photoPath),
                                    child: widget.user.photoPath == null ? const Icon(Icons.person, size: 22, color: Colors.white) : null,
                                  ),
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: Container(
                                      width: 12,
                                      height: 12,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF10B981),
                                        shape: BoxShape.circle,
                                        border: Border.all(color: const Color(0xFF090A0F), width: 2),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.6),
                                            blurRadius: 6,
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
                      ],
                    ),
                  ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.05, end: 0),

                  const SizedBox(height: 14),

                  // ── 📅 Canlı Vardiya Durumu & Tarih Şeridi ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const HugeIcon(icon: HugeIcons.strokeRoundedCalendar01, color: Color(0xFF64748B), size: 14),
                            const SizedBox(width: 6),
                            Text(
                              dateStr,
                              style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        // Canlı Vardiya / Mola Rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E2433).withValues(alpha: 0.9),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF334155), width: 0.8),
                          ),
                          child: Text(
                            _getCurrentShiftBadgeText(),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFF1F5F9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ).animate(delay: 60.ms).fadeIn(duration: 350.ms),

                  const SizedBox(height: 16),

                  // ── 🚀 HIZLI MENÜ (İzinler, Yemek, Duyurular...) ──
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: [
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedPassport01,
                          'İzinler',
                          '14',
                          ' gün kaldı',
                          widget.onIzinTapped,
                          iconColor: const Color(0xFF00FF66),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedScan,
                          'Operasyon AI',
                          'Merkezi',
                          ' • Canlı',
                          () => _handleOperasyonAiAccess(context),
                          iconColor: const Color(0xFF00F0FF),
                          customIcon: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF00F0FF), Color(0xFF8B5CF6)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF00F0FF).withValues(alpha: 0.45),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                              border: Border.all(color: const Color(0xFFE0E7FF), width: 1.2),
                            ),
                            child: const Center(
                              child: Icon(Icons.filter_center_focus_rounded, color: Colors.black87, size: 21),
                            ),
                          ),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedRestaurant01,
                          'Yemek',
                          'Bugün',
                          ' Menü',
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const YemekScreen()));
                          },
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedMegaphone01,
                          'Duyurular',
                          '3',
                          ' yeni',
                          () async {
                            final notifs = await _getCombinedNotifications();
                            if (context.mounted) _showNotifications(context, notifs);
                          },
                          iconColor: const Color(0xFFE50914),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedCreditCard,
                          'VIP Kimlik',
                          'Hologram',
                          ' Dijital Kart',
                          () async {
                            final isVip = await VipGate.checkVipStatus(user: widget.user);
                            if (!context.mounted) return;
                            if (!isVip) {
                              VipGate.showVipLockDialog(
                                context,
                                user: widget.user,
                                onGranted: () {
                                  VipCardModal.show(context, user: widget.user);
                                },
                              );
                              return;
                            }
                            VipCardModal.show(context, user: widget.user);
                          },
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedTask01,
                          'VIP Liste',
                          '',
                          'Posta Listesi',
                          () async {
                            final isVip = await VipGate.checkVipStatus(user: widget.user);
                            if (!context.mounted) return;
                            if (!isVip) {
                              VipGate.showVipLockDialog(
                                context,
                                user: widget.user,
                                onGranted: () {
                                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostaListesiScreen(user: widget.user)));
                                },
                              );
                              return;
                            }
                            Navigator.push(context, MaterialPageRoute(builder: (_) => PostaListesiScreen(user: widget.user)));
                          },
                          iconColor: const Color(0xFFF59E0B),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedSun03,
                          'Hava Durumu',
                          _weatherTitle,
                          ' $_weatherSubtitle',
                          () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
                          },
                          iconColor: const Color(0xFFFBBF24),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedClock01,
                          'Vardiya',
                          '09:30',
                          ' Düzeni',
                          () async {
                            if (widget.onVardiyaTapped != null) {
                              widget.onVardiyaTapped!();
                            } else {
                              await Navigator.push(context, MaterialPageRoute(builder: (_) => const VardiyaScreen()));
                            }
                            _loadSavedVardiya();
                          },
                          iconColor: const Color(0xFFA855F7),
                        ),
                        _buildQuickActionMenu(
                          HugeIcons.strokeRoundedShieldUser,
                          'Yetkili',
                          'Merkezi',
                          ' Yönetim',
                          () => _handleYetkiliAccess(context),
                          iconColor: const Color(0xFFDC2626),
                        ),
                      ],
                    ),
                  ).animate(delay: 90.ms).fadeIn(duration: 400.ms).slideX(begin: 0.04, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 18),

                  // ── 💳 2. TITANIUM VAULT HAKEDİŞ & MAAŞ KARTI ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildTitaniumHakedisCard(jobDetails.baseSalary, mesaiKazanci),
                  ).animate(delay: 120.ms).fadeIn(duration: 450.ms).slideY(begin: 0.04, end: 0),

                  const SizedBox(height: 22),

                  // ── 🍱 3. BENTO-BOX: AKILLI EYLEM MERKEZİ ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Hızlı Erişim',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Text(
                          'Bento Hub',
                          style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: const Color(0xFF64748B), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildBentoGrid(),
                  ).animate(delay: 180.ms).fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),

                  const SizedBox(height: 18),

                  // ── 🌦️ 7 GÜNLÜK WEATHERNEXT 3 AI HAVA TAHMİNİ ──
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: _buildWeeklyWeatherCard(),
                  ).animate(delay: 220.ms).fadeIn(duration: 400.ms).slideY(begin: 0.04, end: 0),

                  const SizedBox(height: 100),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── 🚀 HIZLI İŞLEM MENÜSÜ ELEMANI ──
  Widget _buildQuickActionMenu(
    List<List<dynamic>> icon,
    String title,
    String highlight,
    String subtitle,
    VoidCallback onTap, {
    Color iconColor = const Color(0xFFE50914),
    Widget? customIcon,
  }) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        margin: const EdgeInsets.only(right: 12.0),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        width: 104,
        decoration: BoxDecoration(
          color: const Color(0xFF141722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF272A36), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            customIcon ??
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                    border: Border.all(color: iconColor.withValues(alpha: 0.25), width: 1),
                  ),
                  child: HugeIcon(icon: icon, color: iconColor, size: 22),
                ),
            const SizedBox(height: 10),
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
                      style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor),
                    ),
                  TextSpan(
                    text: subtitle,
                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFA1A1AA)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 🛡️ YETKİLİ ERİŞİM KONTROLÜ & GÜVENLİK PENCERESİ ──
  Future<void> _handleYetkiliAccess(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // 1. Önce yerel model kontrolü
    if (widget.user.isYetkili) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: widget.user)));
      return;
    }

    // 2. Canlı Firestore kontrolü (Admin az önce bu personele Yetkili yetkisi vermiş olabilir)
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

    if (context.mounted) Navigator.pop(context); // Yükleme animasyonunu kapat

    if (liveIsYetkili) {
      if (context.mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: widget.user)));
      }
      return;
    }

    // 3. Yetkili değilse şık PIN / Güvenlik Doğrulama Penceresi Göster
    if (context.mounted) {
      _showYetkiliAuthDialog(context);
    }
  }

  void _showYetkiliAuthDialog(BuildContext context) {
    final pinController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: const Color(0xFF141722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22), side: const BorderSide(color: Color(0xFF272A36))),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
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
                  fillColor: const Color(0xFF0D0F15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626))),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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

  // ── 🛡️ OPERASYON AI MERKEZİ GÜVENLİK VE ADMIN ŞİFRE KONTROLÜ ──
  Future<void> _handleOperasyonAiAccess(BuildContext context) async {
    HapticFeedback.mediumImpact();

    // 1. Canlı Firestore kontrolü ile admin yetkisini kontrol et
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

    // 2. Operasyon AI Merkezi şifre penceresini aç (Şifre: 4896281aa)
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
            backgroundColor: const Color(0xFF0F121C),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: const BorderSide(color: Color(0xFF00F0FF), width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4), width: 1.4),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                          blurRadius: 16,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFF00F0FF), size: 36),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'OPERASYON AI MERKEZİ',
                    style: GoogleFonts.orbitron(fontSize: 14.5, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'YALNIZCA YÖNETİCİ & ADMIN',
                      style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFFF87171)),
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
                      fillColor: const Color(0xFF090B12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF262C3E))),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: Color(0xFF262C3E))),
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
                              // Yetkili yap ve kaydet
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
                          child: Text('Giriş Yap', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold)),
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

  // ── 💳 TITANIUM VAULT HAKEDİŞ KARTI ──
  Widget _buildTitaniumHakedisCard(double baseSalary, double mesaiKazanci) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF780A12), Color(0xFF260508), Color(0xFF0F0B10)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.45), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF780A12).withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Arkaplan yumuşak küre efekti
            Positioned(
              top: -30,
              right: -30,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.04),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kart Başlığı & Aksiyonlar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                            ),
                            child: const HugeIcon(icon: HugeIcons.strokeRoundedWallet02, color: Colors.white, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'GÜNCEL HAKEDİŞ',
                                style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                              ),
                              Text('Bu aydaki net hakediş özetiniz', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1))),
                            ],
                          ),
                        ],
                      ),
                      // Gizlilik Modu (Eye Toggle 👁️) & Dönem Butonu
                      Row(
                        children: [
                          BouncyTap(
                            onTap: _toggleSalaryVisibility,
                            child: Container(
                              padding: const EdgeInsets.all(7),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.3),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              child: Icon(
                                _isSalaryHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                color: _isSalaryHidden ? const Color(0xFFF59E0B) : Colors.white70,
                                size: 17,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                            ),
                            child: Text(
                              'Bu Ay',
                              style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Text(
                    'NET ÖDENECEK TUTAR',
                    style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.8),
                  ),
                  const SizedBox(height: 4),

                  // Büyük Tutar Sayacı veya Maskeli Görünüm
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
                          style: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        AnimatedFlipCounter(
                          value: widget.totalSalary,
                          fractionDigits: 2,
                          thousandSeparator: '.',
                          decimalSeparator: ',',
                          duration: const Duration(milliseconds: 1300),
                          curve: Curves.easeOutExpo,
                          textStyle: GoogleFonts.inter(
                            fontSize: 35,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                            letterSpacing: -1.0,
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 12),

                  // Bordro Detayına Git Butonu
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
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.85),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Bordro & Maaş Dekontu', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white, size: 11),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 📊 fl_chart Etkileşimli Kazanç Dalgası
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
                            getTooltipColor: (spot) => const Color(0xFF141722),
                            tooltipBorder: const BorderSide(color: Color(0xFFDC2626), width: 1),
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
                            color: const Color(0xFFDC2626),
                            barWidth: 2.2,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) {
                                final isSelected = index == _touchedChartSpot;
                                return FlDotCirclePainter(
                                  radius: isSelected ? 5 : 2.8,
                                  color: isSelected ? const Color(0xFF00FF66) : Colors.white,
                                  strokeWidth: 1.5,
                                  strokeColor: const Color(0xFFDC2626),
                                );
                              },
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFDC2626).withValues(alpha: 0.32),
                                  const Color(0xFFDC2626).withValues(alpha: 0.0),
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

                  // Alt Kırılım: Taban Maaş & Mesai Kazancı
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0F15).withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              const HugeIcon(icon: HugeIcons.strokeRoundedLayers01, color: Color(0xFF94A3B8), size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('TABAN MAAŞ', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), letterSpacing: 0.5, fontWeight: FontWeight.bold)),
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
                        Container(width: 1, height: 26, color: Colors.white.withValues(alpha: 0.15)),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 12.0),
                            child: Row(
                              children: [
                                const HugeIcon(icon: HugeIcons.strokeRoundedClock01, color: Color(0xFF10B981), size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('MESAİ KAZANCI', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), letterSpacing: 0.5, fontWeight: FontWeight.bold)),
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
            ),
          ],
        ),
      ),
    );
  }

  // ── 🍱 BENTO-BOX GRID (Hızlı Erişim & Durum) ──
  Widget _buildBentoGrid() {
    return Column(
      children: [
        Row(
          children: [
            // 1. İzin Durumu Bento Kartı
            Expanded(
              child: _buildBentoTile(
                icon: HugeIcons.strokeRoundedPassport01,
                iconColor: const Color(0xFF10B981),
                title: 'YILLIK İZİN',
                mainValue: '14 Gün',
                subValue: '14 / 28 Gün Kaldı',
                badgeText: 'Aktif Hak',
                badgeColor: const Color(0xFF10B981),
                onTap: widget.onIzinTapped,
              ),
            ),
            const SizedBox(width: 12),
            // 2. Hava & Liman Rüzgarı Bento Kartı (WeatherNext 3 AI)
            Expanded(
              child: _buildBentoTile(
                icon: HugeIcons.strokeRoundedSun03,
                iconColor: const Color(0xFFFBBF24),
                title: 'WEATHERNEXT 3 AI',
                mainValue: '$_weatherTitle $_weatherSubtitle',
                subValue: '7 Günlük AI Tahmin • 100m Vinç',
                badgeText: 'DeepMind AI',
                badgeColor: const Color(0xFF8B5CF6),
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
            // 3. Posta Listesi Bento Kartı
            Expanded(
              child: _buildBentoTile(
                icon: HugeIcons.strokeRoundedTask01,
                iconColor: const Color(0xFFF59E0B),
                title: 'POSTA LİSTESİ',
                mainValue: 'Ekip Dağılımı',
                subValue: 'Vardiya Personel Çizelgesi',
                badgeText: '👑 VIP',
                badgeColor: const Color(0xFFF59E0B),
                onTap: () async {
                  final isVip = await VipGate.checkVipStatus(user: widget.user);
                  if (!context.mounted) return;
                  if (!isVip) {
                    VipGate.showVipLockDialog(
                      context,
                      user: widget.user,
                      onGranted: () {
                        Navigator.push(context, MaterialPageRoute(builder: (_) => PostaListesiScreen(user: widget.user)));
                      },
                    );
                    return;
                  }
                  Navigator.push(context, MaterialPageRoute(builder: (_) => PostaListesiScreen(user: widget.user)));
                },
              ),
            ),
            const SizedBox(width: 12),
            // 4. Vardiya Takvimi Bento Kartı
            Expanded(
              child: _buildBentoTile(
                icon: HugeIcons.strokeRoundedCalendar01,
                iconColor: const Color(0xFFA855F7),
                title: 'VARDİYA TAKVİMİ',
                mainValue: '09:30 - 16:30',
                subValue: '☕ 12:00 - 12:30 Mola',
                badgeText: 'Salı Düzeni',
                badgeColor: const Color(0xFFA855F7),
                onTap: () {
                  if (widget.onVardiyaTapped != null) {
                    widget.onVardiyaTapped!();
                  } else {
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const VardiyaScreen()));
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── 🌦️ 7 GÜNLÜK WEATHERNEXT 3 AI HAVA TAHMİN BİLEŞENİ ──
  Widget _buildWeeklyWeatherCard() {
    final dailyList = _weatherData?.dailyForecasts ?? [];
    final hasData = dailyList.isNotEmpty;

    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
      },
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF141722),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Başlık & AI Rozeti
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)],
                          ),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Colors.white, size: 14),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '7 GÜNLÜK HAVA TAHMİNİ',
                                style: GoogleFonts.orbitron(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'WeatherNext 3',
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFC4B5FD),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Payas 5km Izgara • 100m Kule Vinç Modeli',
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155), width: 0.8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Detaylar',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: Color(0xFF38BDF8)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: Color(0xFF222634), height: 1),

            // 7 Günlük Yatay Kartlar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: hasData
                  ? SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      child: Row(
                        children: List.generate(dailyList.length, (idx) {
                          final day = dailyList[idx];
                          final isToday = idx == 0;
                          final dayName = isToday ? 'Bugün' : WeatherService.getWeekdayName(day.date);
                          final dateStr = '${day.date.day}/${day.date.month}';

                          return Container(
                            margin: const EdgeInsets.only(right: 9),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            width: 86,
                            decoration: BoxDecoration(
                              gradient: isToday
                                  ? LinearGradient(
                                      colors: [
                                        const Color(0xFF8B5CF6).withValues(alpha: 0.22),
                                        const Color(0xFF1E1B4B).withValues(alpha: 0.4),
                                      ],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    )
                                  : null,
                              color: isToday ? null : const Color(0xFF0F1118),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isToday
                                    ? const Color(0xFF8B5CF6).withValues(alpha: 0.6)
                                    : const Color(0xFF262A38),
                                width: isToday ? 1.2 : 0.9,
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  dayName,
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                                    color: isToday ? const Color(0xFFA78BFA) : Colors.white,
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: GoogleFonts.inter(
                                    fontSize: 9.5,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 7),
                                Icon(
                                  WeatherService.getWeatherIcon(day.weatherCode),
                                  color: WeatherService.getWeatherColor(day.weatherCode),
                                  size: 24,
                                ),
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${day.maxTemp.round()}°',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${day.minTemp.round()}°',
                                      style: GoogleFonts.inter(
                                        fontSize: 10.5,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // Yağış veya Vinç Rüzgarı
                                if (day.rainProbability > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.water_drop_rounded, size: 9, color: Color(0xFF38BDF8)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '%${day.rainProbability}',
                                          style: GoogleFonts.inter(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFF7DD3FC),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                else
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.air_rounded, size: 9, color: Color(0xFFFBBF24)),
                                        const SizedBox(width: 2),
                                        Text(
                                          '${day.windSpeed100mMax.round()}k',
                                          style: GoogleFonts.inter(
                                            fontSize: 8.5,
                                            fontWeight: FontWeight.w700,
                                            color: const Color(0xFFFDE68A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 4),
                                // AI Güven Skoru
                                Text(
                                  '%${day.aiConfidence} AI',
                                  style: GoogleFonts.inter(
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFA78BFA),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ),
                    )
                  : const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF8B5CF6)),
                      ),
                    ),
            ),

            // Alt AI Canlı Durum Şeridi
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: const BoxDecoration(
                color: Color(0xFF0F1118),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(22),
                  bottomRight: Radius.circular(22),
                ),
                border: Border(
                  top: BorderSide(color: Color(0xFF222634), width: 1),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.shield_outlined, size: 13, color: Color(0xFF10B981)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'WeatherNext 3 AI: 7 günlük rüzgar ve fırtına emniyet analizi aktif.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'İSDEMİR',
                    style: GoogleFonts.orbitron(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFDC2626),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBentoTile({
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
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF141722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF272A36), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
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
                    color: iconColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: iconColor.withValues(alpha: 0.25)),
                  ),
                  child: HugeIcon(icon: icon, color: iconColor, size: 19),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    badgeText,
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w700, color: badgeColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF94A3B8), letterSpacing: 0.3),
            ),
            const SizedBox(height: 2),
            Text(
              mainValue,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
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





  // ── 📢 DUYURULAR PANOSU MODALI ──
  void _showNotifications(BuildContext context, List<Map<String, dynamic>> duyurular) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141722),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.72,
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.campaign_rounded, color: Color(0xFFDC2626), size: 24),
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
              const Divider(color: Color(0xFF272A36)),
              Expanded(
                child: duyurular.isEmpty
                    ? Center(
                        child: Text(
                          'Henüz duyuru bulunmuyor.',
                          style: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: duyurular.length,
                        itemBuilder: (context, index) {
                          final d = duyurular[index];
                          final isAlert = d['is_alert'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16.0),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E212D),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isAlert ? const Color(0xFFDC2626).withValues(alpha: 0.6) : const Color(0xFF2E3446),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: (isAlert ? const Color(0xFFDC2626) : const Color(0xFF3B82F6)).withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Icon(
                                    isAlert ? Icons.warning_amber_rounded : Icons.info_outline_rounded,
                                    color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF3B82F6),
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
        );
      },
    );
  }
}

// ── 🚢 GEMİ ANKET DİYALOGU (Mevcut Mantık Korundu) ──
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
      backgroundColor: const Color(0xFF141722),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
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
            _buildOptionButton(context, 'Gemi Bitti', const Color(0xFF3B82F6)),
            const SizedBox(height: 10),
            _buildOptionButton(context, 'Limandan Ayrıldı', const Color(0xFF64748B)),
            const SizedBox(height: 14),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Daha Sonra', style: GoogleFonts.inter(color: const Color(0xFF94A3B8))),
            ),
          ],
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
          backgroundColor: color.withValues(alpha: 0.15),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
