import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../utils/app_config.dart';
import '../utils/socket_service.dart';
import 'register_screen.dart';
import 'approval_screen.dart';
import 'main_screen.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';
import 'package:restart_app/restart_app.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _mainController;
  late AnimationController _progressController;
  
  late Animation<double> _logoFade;
  late Animation<double> _logoScale;
  late Animation<Offset> _textSlide;
  late Animation<double> _textFade;
  late Animation<double> _bottomFade;

  bool _isVip = false;
  bool _isLocalChecked = false;
  UserModel? _currentUser;
  bool _hasNavigated = false;
  Widget? _resolvedNextScreen;

  @override
  void initState() {
    super.initState();
    _checkVipStatusLocally();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );
    
    // Logo: fade + scale (0% - 40%)
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.4, curve: Curves.easeOut)),
    );
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)),
    );
    
    // Text: fade + slide up (25% - 60%)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.6, curve: Curves.easeOut)),
    );
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.25, 0.6, curve: Curves.easeOutCubic)),
    );
    
    // Bottom section fade (45% - 75%)
    _bottomFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _mainController, curve: const Interval(0.45, 0.75, curve: Curves.easeOut)),
    );

    _mainController.forward();
    _progressController.forward();
    _routeToNextScreen();
  }

  void _proceedToNext() {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    final target = _resolvedNextScreen ??
        (_currentUser != null
            ? MainScreen(user: _currentUser!)
            : const RegisterScreen());
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 350),
        pageBuilder: (_, _, _) => target,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  Future<void> _checkVipStatusLocally() async {
    final prefs = await SharedPreferences.getInstance();
    final user = await UserModel.load();
    final prefVip = prefs.getBool('isVip') ?? false;
    if (mounted) {
      setState(() {
        _currentUser = user;
        if (user != null) {
          _isVip = user.isVip || prefVip;
        } else {
          _isVip = prefVip;
        }
        _isLocalChecked = true;
      });
    }
  }

  Future<bool> _checkForceUpdate() async {
    // 1. Önce bu cihaza atanmış özel bir erken erişim/beta güncellemesi var mı kontrol et
    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null && cihazId.isNotEmpty) {
        final query = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get()
            .timeout(const Duration(milliseconds: 1800));

        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          if (data.containsKey('ozel_guncelleme') && data['ozel_guncelleme'] is Map) {
            final ozel = Map<String, dynamic>.from(data['ozel_guncelleme'] as Map);
            final bool isAktif = ozel['aktif'] == true;
            final int targetVer = ozel['versiyon_kodu'] is int
                ? ozel['versiyon_kodu'] as int
                : int.tryParse('${ozel['versiyon_kodu']}') ?? 0;
            final String downloadUrl = ozel['download_url'] as String? ?? '';
            final String customNotes = ozel['notlar'] as String? ?? 'Kişiye özel test güncellemesi';

            if (isAktif && targetVer > AppConfig.currentVersion && downloadUrl.isNotEmpty) {
              if (!mounted) return false;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => _UpdateDialogWidget(
                  downloadUrl: downloadUrl,
                  latestVersion: targetVer,
                  isTargetedBeta: true,
                  customNotes: customNotes,
                ),
              );
              return true; // Halt navigation for targeted update
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[TargetedUpdateCheck] Hata: $e');
    }

    // 2. Özel güncelleme yoksa standart genel sürüm kontrolünü yap
    try {
      final response = await http.get(
        Uri.parse('${SocketService.serverUrl}/version'),
        headers: {
          'User-Agent': 'IsdemirOS-Mobile/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(milliseconds: 2000));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['latestVersion'] as int;
        final downloadUrl = data['downloadUrl'] as String;
        
        if (latestVersion > AppConfig.currentVersion) {
          if (!mounted) return false;
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _UpdateDialogWidget(
              downloadUrl: downloadUrl,
              latestVersion: latestVersion,
            ),
          );
          return true; // Halt navigation
        }
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _checkShorebirdUpdate() async {
    try {
      final shorebirdUpdater = ShorebirdUpdater();
      final status = await shorebirdUpdater.checkForUpdate().timeout(const Duration(milliseconds: 1500));
      
      if (status == UpdateStatus.outdated) {
        if (!mounted) return false;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _ShorebirdUpdateDialogWidget(),
        );
        return true; // Halt navigation
      }
    } catch (_) {}
    return false;
  }

  Future<bool> _checkUpdates() async {
    final force = await _checkForceUpdate();
    if (force) return true;
    return await _checkShorebirdUpdate();
  }

  Future<void> _routeToNextScreen() async {
    final user = await UserModel.load();
    final prefs = await SharedPreferences.getInstance();
    final prefVip = prefs.getBool('isVip') ?? false;
    final isVipActive = (user?.isVip ?? false) || prefVip;
    final splashMinWait = Future.delayed(Duration(milliseconds: isVipActive ? 2200 : 850));

    if (user != null && mounted) {
      setState(() {
        _currentUser = user;
        _isVip = isVipActive;
      });
    }

    final cihazId = prefs.getString('cihaz_id');

    // Kayıtlı kullanıcı varsa her zaman doğrudan MainScreen'e yönlendir (asla kayıt ekranına atma)
    Widget nextScreen = user != null ? MainScreen(user: user) : const RegisterScreen();

    if (cihazId != null && cihazId.isNotEmpty) {
      try {
        // Hızlı paralel kontroller (Maksimum 1.8 sn bekleme)
        final updateCheck = _checkUpdates();
        final firestoreCheck = FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get()
            .timeout(const Duration(milliseconds: 1800));

        final results = await Future.wait([updateCheck, firestoreCheck]);
        final shouldHalt = results[0] as bool;
        if (shouldHalt) return;

        final querySnapshot = results[1] as QuerySnapshot<Map<String, dynamic>>?;
        if (querySnapshot != null && querySnapshot.docs.isNotEmpty) {
            final response = querySnapshot.docs.first.data();
            final docRef = querySnapshot.docs.first.reference;
            // 🚀 Uygulama Sürümünü (v9.0) ve Son Giriş Zamanını Anlık Firestore'a Kaydet
            docRef.update({
              'app_version': '${AppConfig.currentVersion}.0',
              'app_version_num': AppConfig.currentVersion,
              'son_giris_tarihi': FieldValue.serverTimestamp(),
              'guncelleme_tarihi_str': DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now()),
            }).catchError((_) {});

            if (response['durum'] == 'onaylandi') {
              UserModel? restoredUser = user;
              if (response['ad_soyad'] != null) {
                final parts = (response['ad_soyad'] as String).split(' ');
                final firstName = parts.isNotEmpty ? parts.first : '';
                final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
                
                if (restoredUser != null) {
                  restoredUser.firstName = firstName;
                  restoredUser.lastName = lastName;
                  restoredUser.jobTitle = response['meslek'] ?? restoredUser.jobTitle;
                  restoredUser.photoPath = response['profil_foto'] ?? restoredUser.photoPath;
                  restoredUser.isVip = response['is_vip'] == true;
                  restoredUser.isYetkili = response['is_yetkili'] == true || response['yetkili'] == true;
                } else {
                  restoredUser = UserModel(
                    firstName: firstName,
                    lastName: lastName,
                    jobTitle: response['meslek'] ?? 'Liman İşçisi A',
                    photoPath: response['profil_foto'],
                    isVip: response['is_vip'] == true,
                    isYetkili: response['is_yetkili'] == true || response['yetkili'] == true,
                  );
                }
                await restoredUser.save();
              }
              if (restoredUser != null) {
                nextScreen = MainScreen(user: restoredUser);
              }
            } else {
              nextScreen = const ApprovalScreen();
            }
          }
      } catch (_) {
        // İnternet yavaşsa veya timeout olursa cihazdaki kayıtlı kullanıcıyla anında geç
        if (user != null) {
          nextScreen = MainScreen(user: user);
        } else {
          nextScreen = const ApprovalScreen();
        }
      }
    }

    _resolvedNextScreen = nextScreen;

    // Minimum gösterim süresini bekle (Otomatik VIP Geçişi)
    await splashMinWait;

    if (!_hasNavigated && mounted) {
      _proceedToNext();
    }
  }

  @override
  void dispose() {
    _mainController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  // =========================================================================
  // 🌟 VIP GİRİŞ EKRANI (BİREBİR GÖRSELDEKİ GİBİ RED CRIMSON & VISIONOS TASARIM)
  // =========================================================================
  Widget _buildVipSplash() {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0305),
      body: GestureDetector(
        onTap: _proceedToNext,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // ── 1. EPİK İSDEMİR ENDÜSTRİYEL GÜNBATIMI DUVAR KAĞIDI ──
            Positioned.fill(
              child: Image.asset(
                'assets/images/isdemir_vip_bg.jpg',
                fit: BoxFit.cover,
              ),
            ),

            // Koyu Atmosferik Vignette ve Gradyan Katmanı
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.30),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.65),
                    ],
                    stops: const [0.0, 0.45, 1.0],
                  ),
                ),
              ),
            ),

            // ── 2. ANA İÇERİK: DİKEY HİZALANMIŞ VIP KOKPİT ──
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                child: Column(
                  children: [
                    const SizedBox(height: 24),

                    // ── ÜST: İSDEMİR LOGO & VIP GİRİŞ BAŞLIĞI ──
                    // 1. Resmi Kırmızı İSDEMİR Amblemi
                    Image.asset(
                      'assets/images/isdemir_logo_transparent.png',
                      height: 78,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),

                    // 2. "İ S D E M İ R   O S"
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        children: [
                          TextSpan(
                            text: 'İ S D E M İ R ',
                            style: GoogleFonts.outfit(
                              color: Colors.white,
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.5,
                            ),
                          ),
                          TextSpan(
                            text: 'O S',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFFE50914),
                              fontSize: 23,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 4.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 3. "———— VIP GİRİŞ ————"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(width: 44, height: 1, color: Colors.white.withValues(alpha: 0.35)),
                        const SizedBox(width: 12),
                        Text(
                          'VIP GİRİŞ',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.95),
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 3.5,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Container(width: 44, height: 1, color: Colors.white.withValues(alpha: 0.35)),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // 4. "Güvenli Erişim • Yetkili Kullanıcılar İçin"
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Güvenli Erişim',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8.0),
                          child: Text(
                            '•',
                            style: TextStyle(
                              color: const Color(0xFFE50914),
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          'Yetkili Kullanıcılar İçin',
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 12,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),

                    const Spacer(flex: 3),

                    // ── ORTA: BUZLU CAM VISIONOS KONTROL PANELİ ──
                    ClipRRect(
                      borderRadius: BorderRadius.circular(28),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                        child: Container(
                          width: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 330),
                          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF260B12).withValues(alpha: 0.68),
                                const Color(0xFF100508).withValues(alpha: 0.78),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(28),
                            border: Border.all(
                              color: const Color(0xFFE50914).withValues(alpha: 0.75),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withValues(alpha: 0.35),
                                blurRadius: 30,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 24,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // 1. NEON KIRMIZI DAİRESEL İLERLEME GÖSTERGESİ (CIRCULAR GAUGE)
                              SizedBox(
                                width: 132,
                                height: 132,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Arka Plan Koyu Halka İzi
                                    SizedBox(
                                      width: 132,
                                      height: 132,
                                      child: CircularProgressIndicator(
                                        value: 1.0,
                                        strokeWidth: 5.5,
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white.withValues(alpha: 0.08),
                                        ),
                                      ),
                                    ),
                                    // Ön Plan Canlı Kırmızı İlerleme Yayı
                                    AnimatedBuilder(
                                      animation: _progressController,
                                      builder: (context, _) {
                                        return SizedBox(
                                          width: 132,
                                          height: 132,
                                          child: CircularProgressIndicator(
                                            value: _progressController.value,
                                            strokeWidth: 5.5,
                                            strokeCap: StrokeCap.round,
                                            valueColor: const AlwaysStoppedAnimation<Color>(
                                              Color(0xFFFF2A2A),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                    // Merkez Güvenlik Kalkanı & Anahtar Deliği İkonu
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Icon(
                                          Icons.shield_outlined,
                                          size: 42,
                                          color: Colors.white.withValues(alpha: 0.65),
                                        ),
                                        Positioned(
                                          top: 14,
                                          child: Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: Colors.white.withValues(alpha: 0.65),
                                            ),
                                          ),
                                        ),
                                        Positioned(
                                          top: 18,
                                          child: Container(
                                            width: 3.5,
                                            height: 7,
                                            decoration: BoxDecoration(
                                              color: Colors.white.withValues(alpha: 0.65),
                                              borderRadius: BorderRadius.circular(1),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),

                              // 2. DURUM YAZISI
                              Text(
                                'Sistem yükleniyor...',
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                'Yetkili erişim doğrulanıyor',
                                style: GoogleFonts.inter(
                                  color: const Color(0xFFC0B4BA),
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 3. YATAY İLERLEME ÇUBUĞU VE YÜZDE ORANI (% 72)
                              AnimatedBuilder(
                                animation: _progressController,
                                builder: (context, _) {
                                  final val = _progressController.value;
                                  final percent = (val * 100).toInt().clamp(0, 100);

                                  return Row(
                                    children: [
                                      // Kırmızı Gradyanlı Yatay Çubuk
                                      Expanded(
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(4),
                                          child: Container(
                                            height: 6,
                                            color: Colors.white.withValues(alpha: 0.12),
                                            child: FractionallySizedBox(
                                              alignment: Alignment.centerLeft,
                                              widthFactor: val.clamp(0.01, 1.0),
                                              child: Container(
                                                decoration: BoxDecoration(
                                                  gradient: const LinearGradient(
                                                    colors: [
                                                      Color(0xFFFF3B30),
                                                      Color(0xFFE50914),
                                                    ],
                                                  ),
                                                  borderRadius: BorderRadius.circular(4),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: const Color(0xFFE50914).withValues(alpha: 0.8),
                                                      blurRadius: 6,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      // Yüzde Metni
                                      Text(
                                        '% $percent',
                                        style: GoogleFonts.inter(
                                          color: Colors.white,
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const Spacer(flex: 4),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_isLocalChecked) {
      return const Scaffold(backgroundColor: Color(0xFF0F0F13));
    }
    if (_isVip) {
      return _buildVipSplash();
    }
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _progressController]),
        builder: (context, child) {
          return Stack(
            children: [
              // ── Beyaz temiz arkaplan ──
              Container(color: Colors.white),
              
              // ── Light Factory Background at Top ──
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: MediaQuery.of(context).size.height * 0.6,
                child: FadeTransition(
                  opacity: _logoFade,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black,
                          Colors.transparent,
                        ],
                        stops: [0.6, 1.0],
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/light_factory_bg.jpg',
                      fit: BoxFit.cover,
                      opacity: const AlwaysStoppedAnimation(0.3),
                    ),
                  ),
                ),
              ),

              // ── Wavy Bottom Graphic ──
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _bottomFade,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: 180, // Adjust height based on mockup
                    child: CustomPaint(
                      painter: _WavyBottomPainter(),
                    ),
                  ),
                ),
              ),

              // ── Ana İçerik ──
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    // ── Logo & Marka Başlığı (Metalik Çelik Işıltısı) ──
                    MetallicSteelShimmer(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Logo ──
                          FadeTransition(
                            opacity: _logoFade,
                            child: ScaleTransition(
                              scale: _logoScale,
                              child: SizedBox(
                                width: 220,
                                height: 120,
                                child: Image.asset(
                                  'assets/images/logo.jpg',
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFFDC2626), width: 2),
                                    ),
                                    child: const Icon(Icons.business, size: 60, color: Color(0xFFDC2626)),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 24),
                          
                          // ── İSDEMİR Yazısı ──
                          SlideTransition(
                            position: _textSlide,
                            child: FadeTransition(
                              opacity: _textFade,
                              child: Column(
                                children: [
                                  Text(
                                    'İSDEMİR',
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF18181B),
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 2.5,
                                      shadows: [
                                        Shadow(
                                          color: const Color(0xFF000000).withValues(alpha: 0.08),
                                          offset: const Offset(0, 2),
                                          blurRadius: 4,
                                        ),
                                        Shadow(
                                          color: const Color(0xFFE50914).withValues(alpha: 0.12),
                                          offset: const Offset(0, 1),
                                          blurRadius: 8,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 22,
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(1),
                                          color: const Color(0xFFE50914),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'PERSONEL SİSTEMİ',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF3F3F46),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 2.0,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        width: 22,
                                        height: 1.5,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(1),
                                          color: const Color(0xFFE50914),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),

                    // ── Welcome Text ──
                    FadeTransition(
                      opacity: _textFade,
                      child: Column(
                        children: [
                          Text(
                            'Hoş geldiniz 👋',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF1C1C22),
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Personel sistemine giriş yaparak\nişlemlerinizi kolayca yönetebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: const Color(0xFF71717A),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 40),

                    // ── Loading Indicator ──
                    FadeTransition(
                      opacity: _textFade,
                      child: Container(
                        width: 48,
                        height: 48,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withValues(alpha: 0.15),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          strokeWidth: 3,
                          color: Color(0xFFE50914),
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 3),
                    
                    // ── Alt Kısım: Versiyon ──
                    FadeTransition(
                      opacity: _bottomFade,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 16.0),
                        child: Text(
                          'v${AppConfig.currentVersion}.0 • İskenderun Demir ve Çelik A.Ş.',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UpdateDialogWidget extends StatefulWidget {
  final String downloadUrl;
  final int latestVersion;
  final bool isTargetedBeta;
  final String? customNotes;

  const _UpdateDialogWidget({
    required this.downloadUrl,
    required this.latestVersion,
    this.isTargetedBeta = false,
    this.customNotes,
  });

  @override
  State<_UpdateDialogWidget> createState() => _UpdateDialogWidgetState();
}

class _UpdateDialogWidgetState extends State<_UpdateDialogWidget> {
  bool isDownloading = false;
  bool isDownloaded = false;
  String? savedApkPath;
  double progress = 0.0;
  int receivedBytes = 0;
  int totalBytes = 0;
  CancelToken? _cancelToken;

  @override
  void initState() {
    super.initState();
    _checkExistingApk();
  }

  Future<String> _getApkPath() async {
    final dir = await getTemporaryDirectory();
    return '${dir.path}/isdemir_update_v${widget.latestVersion}.apk';
  }

  Future<void> _checkExistingApk() async {
    try {
      final dir = await getTemporaryDirectory();
      // Önceki eski sürümlerden kalan tüm apk kalıntılarını temizle
      final entities = dir.listSync();
      for (final e in entities) {
        if (e is File && e.path.contains('isdemir_update_') && !e.path.endsWith('v${widget.latestVersion}.apk')) {
          try { e.deleteSync(); } catch (_) {}
        }
      }
      final path = await _getApkPath();
      final file = File(path);
      if (await file.exists()) {
        final len = await file.length();
        // Gerçek release APK ~187MB, 100MB'tan küçükse eksiktir, temizle
        if (len > 100 * 1024 * 1024) {
          if (mounted) {
            setState(() {
              savedApkPath = path;
              isDownloaded = true;
              progress = 1.0;
            });
          }
        } else {
          try { await file.delete(); } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _cancelToken?.cancel();
    super.dispose();
  }

  Future<void> _installApk(String path) async {
    try {
      final file = File(path);
      if (!await file.exists()) {
        if (mounted) {
          setState(() {
            isDownloaded = false;
            savedApkPath = null;
          });
        }
        _startDownload();
        return;
      }
      await OpenFilex.open(path);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Kurulum başlatılamadı. Tarayıcı ile indirebilirsiniz.'),
            duration: const Duration(seconds: 5),
            backgroundColor: const Color(0xFFDC2626),
            action: SnackBarAction(label: 'Tarayıcıda Aç', textColor: Colors.white, onPressed: _openInBrowser),
          ),
        );
      }
    }
  }

  Future<void> _openInBrowser() async {
    try {
      final uri = Uri.parse(widget.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(uri);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Tarayıcı açılamadı: $e'), backgroundColor: const Color(0xFFDC2626)));
      }
    }
  }

  void _startDownload() async {
    final savePath = await _getApkPath();

    if (isDownloaded && savedApkPath != null) {
      final file = File(savedApkPath!);
      if (await file.exists() && await file.length() > 10 * 1024 * 1024) {
        await _installApk(savedApkPath!);
        return;
      }
    }

    setState(() {
      isDownloading = true;
      progress = 0.0;
      receivedBytes = 0;
      totalBytes = 0;
    });

    _cancelToken = CancelToken();

    try {
      final file = File(savePath);
      if (await file.exists()) {
        await file.delete();
      }

      final dio = Dio();
      dio.options = BaseOptions(
        connectTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 30),
        sendTimeout: const Duration(minutes: 2),
        followRedirects: true,
        maxRedirects: 8,
      );

      await dio.download(
        widget.downloadUrl,
        savePath,
        cancelToken: _cancelToken,
        deleteOnError: false,
        onReceiveProgress: (received, total) {
          if (mounted) {
            setState(() {
              receivedBytes = received;
              totalBytes = total > 0 ? total : 0;
              if (total > 0) {
                progress = (received / total).clamp(0.0, 1.0);
              }
            });
          }
        },
      );

      savedApkPath = savePath;

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = true;
          progress = 1.0;
        });
      }

      await _installApk(savePath);

    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return;
      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = false;
        });
        String errorMsg;
        if (e.type == DioExceptionType.connectionError || e.error is SocketException) {
          errorMsg = 'Bağlantı hatası: İnternet bağlantınızı kontrol edin.';
        } else if (e.type == DioExceptionType.connectionTimeout || e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
        } else {
          errorMsg = 'İndirme tamamlanamadı. Tarayıcı ile indirmeyi deneyebilirsiniz.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFFDC2626),
            action: SnackBarAction(label: 'Tarayıcıda Aç', textColor: Colors.white, onPressed: _openInBrowser),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Beklenmeyen bir hata oluştu. Tarayıcı ile indirmeyi deneyebilirsiniz.'),
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFFDC2626),
            action: SnackBarAction(label: 'Tarayıcıda Aç', textColor: Colors.white, onPressed: _openInBrowser),
          ),
        );
      }
    }
  }

  String _getProgressString() {
    if (totalBytes > 0) {
      final receivedMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
      final totalMB = (totalBytes / (1024 * 1024)).toStringAsFixed(1);
      final percent = (progress * 100).toInt();
      return '$receivedMB MB / $totalMB MB (%$percent)';
    } else if (receivedBytes > 0) {
      final receivedMB = (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
      return '$receivedMB MB indirildi...';
    }
    return 'Hazırlanıyor...';
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDownloadButton() {
    if (isDownloading) {
      return Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFF1E293B)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(value: progress > 0 ? progress : null, color: const Color(0xFF8B5CF6), strokeWidth: 2.5),
            ),
            const SizedBox(width: 12),
            Text(_getProgressString(), style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return Column(
        children: [
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFF10B981)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: _startDownload,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.install_mobile_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text('Kurulumu Başlat', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    setState(() {
                      isDownloaded = false;
                      savedApkPath = null;
                    });
                    _startDownload();
                  },
                  icon: const Icon(Icons.refresh_rounded, size: 16, color: Color(0xFF94A3B8)),
                  label: const Text('Tekrar İndir', style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 12)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF334155)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _openInBrowser,
                  icon: const Icon(Icons.open_in_browser_rounded, size: 16),
                  label: const Text('Tarayıcıda Aç', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    }

    return Column(
      children: [
        Container(
          height: 56,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)], begin: Alignment.centerLeft, end: Alignment.centerRight),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _startDownload,
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('Güncellemeyi İndir', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _openInBrowser,
            icon: const Icon(Icons.open_in_browser_rounded, size: 18, color: Color(0xFF38BDF8)),
            label: const Text('Tarayıcı İle Doğrudan İndir', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 13, fontWeight: FontWeight.bold)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF0284C7)),
              padding: const EdgeInsets.symmetric(vertical: 11),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => exit(0),
            ),
            centerTitle: true,
            title: const Text('Uygulama Güncellemesi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10)],
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [const Color(0xFF6366F1).withValues(alpha: 0.2), const Color(0xFF3B82F6).withValues(alpha: 0.1)],
                          ),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Center(child: Icon(Icons.arrow_upward_rounded, color: Color(0xFF8B5CF6), size: 48)),
                      ),
                      Positioned(
                        top: -8,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: widget.isTargetedBeta ? const Color(0xFFF59E0B) : const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            widget.isTargetedBeta ? '⭐ ERKEN ERİŞİM' : 'YENİ',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  Text(
                    widget.isTargetedBeta ? 'Kişiye Özel Beta Sürümü!' : 'Yeni bir sürüm mevcut!',
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.customNotes ??
                        'Daha iyi bir deneyim için uygulamamızı\ngüncellemenizi öneriyoruz.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                    child: Text('v${widget.latestVersion}.0 • 187 MB', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151C2C),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureItem(icon: Icons.auto_awesome, iconBgColor: const Color(0xFF2E1065), iconColor: const Color(0xFFA855F7), title: 'Yenilikler', subtitle: 'Bu sürümde neler var?'),
                        const SizedBox(height: 20),
                        _buildFeatureItem(icon: Icons.shield_outlined, iconBgColor: const Color(0xFF1E1B4B), iconColor: const Color(0xFF6366F1), title: 'Geliştirilmiş Güvenlik', subtitle: 'Verileriniz artık daha güvende.'),
                        const SizedBox(height: 20),
                        _buildFeatureItem(icon: Icons.speed_rounded, iconBgColor: const Color(0xFF172554), iconColor: const Color(0xFF3B82F6), title: 'Daha Hızlı Performans', subtitle: 'Uygulama performansı artırıldı.'),
                        const SizedBox(height: 20),
                        _buildFeatureItem(icon: Icons.web_asset_rounded, iconBgColor: const Color(0xFF134E4A), iconColor: const Color(0xFF14B8A6), title: 'Yeni Arayüz', subtitle: 'Daha modern ve kullanıcı dostu tasarım.'),
                        const SizedBox(height: 20),
                        _buildFeatureItem(icon: Icons.notifications_active_outlined, iconBgColor: const Color(0xFF451A03), iconColor: const Color(0xFFF59E0B), title: 'Bildirim İyileştirmeleri', subtitle: 'Bildirim tercihlerinizi daha kolay yönetin.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDownloadButton(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => exit(0),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                    ),
                    child: const Text('Daha Sonra Hatırlat', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 14),
                      SizedBox(width: 6),
                      Text('İndirilen dosya %100 güvenlidir.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShorebirdUpdateDialogWidget extends StatefulWidget {
  const _ShorebirdUpdateDialogWidget();

  @override
  State<_ShorebirdUpdateDialogWidget> createState() => _ShorebirdUpdateDialogWidgetState();
}

class _ShorebirdUpdateDialogWidgetState extends State<_ShorebirdUpdateDialogWidget> {
  bool isDownloading = false;
  bool isDownloaded = false;

  @override
  void initState() {
    super.initState();
  }

  Future<void> _startDownload() async {
    setState(() {
      isDownloading = true;
    });

    try {
      final shorebirdUpdater = ShorebirdUpdater();
      await shorebirdUpdater.update();

      if (mounted) {
        setState(() {
          isDownloading = false;
          isDownloaded = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isDownloading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yama indirilirken hata oluştu. Daha sonra tekrar denenecektir.'),
            backgroundColor: Color(0xFFDC2626),
          ),
        );
      }
    }
  }

  void _restartApp() {
    Restart.restartApp();
  }

  Widget _buildDownloadButton() {
    if (isDownloading) {
      return Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFF1E293B)),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: Color(0xFF8B5CF6), strokeWidth: 2.5),
            ),
            SizedBox(width: 12),
            Text('Yama İndiriliyor...', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    if (isDownloaded) {
      return Container(
        height: 56,
        width: double.infinity,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), color: const Color(0xFF10B981)),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _restartApp,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Yeniden Başlat', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      height: 56,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(colors: [Color(0xFF8B5CF6), Color(0xFF3B82F6)], begin: Alignment.centerLeft, end: Alignment.centerRight),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _startDownload,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.arrow_downward_rounded, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Text('Yamayı İndir', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(14)),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Dialog.fullscreen(
        backgroundColor: const Color(0xFF0F172A),
        child: Scaffold(
          backgroundColor: const Color(0xFF0B0F19),
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => exit(0),
            ),
            centerTitle: true,
            title: const Text('Küçük Yama Güncellemesi', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 20),
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: const Color(0xFF6366F1).withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 10)],
                        ),
                      ),
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [const Color(0xFF6366F1).withValues(alpha: 0.2), const Color(0xFF3B82F6).withValues(alpha: 0.1)],
                          ),
                          border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.3), width: 1.5),
                        ),
                        child: const Center(child: Icon(Icons.system_update_rounded, color: Color(0xFF8B5CF6), size: 48)),
                      ),
                      Positioned(
                        top: -8,
                        right: -12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(color: const Color(0xFF10B981), borderRadius: BorderRadius.circular(20)),
                          child: const Text('PATCH', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Hızlı bir yama mevcut!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Uygulama için küçük bir yama (patch) mevcut.\nSadece saniyeler sürecek bu güncellemeyi alarak\nyeniliklere hemen erişebilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                    child: Text('v${AppConfig.currentVersion}.x.x • Hızlı Güncelleme', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF151C2C),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF1E293B)),
                    ),
                    child: Column(
                      children: [
                        _buildFeatureItem(icon: Icons.bug_report_rounded, iconBgColor: const Color(0xFF172554), iconColor: const Color(0xFF3B82F6), title: 'Hata Düzeltmeleri', subtitle: 'Küçük hatalar giderildi.'),
                        const SizedBox(height: 20),
                        _buildFeatureItem(icon: Icons.auto_awesome, iconBgColor: const Color(0xFF2E1065), iconColor: const Color(0xFFA855F7), title: 'Performans İyileştirmeleri', subtitle: 'Daha hızlı bir deneyim.'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  _buildDownloadButton(),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: () => exit(0),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(double.infinity, 56),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: const BorderSide(color: Color(0xFF1E293B), width: 1.5)),
                    ),
                    child: const Text('Daha Sonra Hatırlat', style: TextStyle(color: Color(0xFF8B5CF6), fontSize: 15, fontWeight: FontWeight.w600)),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.lock_outline_rounded, color: Color(0xFF64748B), size: 14),
                      SizedBox(width: 6),
                      Text('İndirilen dosya %100 güvenlidir.', style: TextStyle(color: Color(0xFF64748B), fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 🏭 İSDEMİR Çelik Fabrikası Temalı Metalik Işıltı (Metallic Steel Shimmer & Flare)
class MetallicSteelShimmer extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration pauseDuration;
  final bool showSparkle;

  const MetallicSteelShimmer({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 2000),
    this.pauseDuration = const Duration(milliseconds: 1400),
    this.showSparkle = true,
  });

  @override
  State<MetallicSteelShimmer> createState() => _MetallicSteelShimmerState();
}

class _MetallicSteelShimmerState extends State<MetallicSteelShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _controller.reset();
        _timer?.cancel();
        _timer = Timer(widget.pauseDuration, () {
          if (mounted) {
            _controller.forward();
          }
        });
      }
    });

    // Açılış animasyonları (fade, scale) yerleşirken hafif gecikmeyle ilk ışıltı başlar
    _timer = Timer(const Duration(milliseconds: 700), () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        // Sol üstten sağ alta doğru lineer akış koordinatları (-1.8 -> +1.8)
        final startX = -1.8 + (progress * 3.6);
        final endX = startX + 1.2;

        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            ShaderMask(
              blendMode: BlendMode.srcATop,
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment(startX, -0.6),
                  end: Alignment(endX, 0.6),
                  colors: [
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.0),
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.95),
                    Colors.white.withValues(alpha: 0.85),
                    Colors.white.withValues(alpha: 0.25),
                    Colors.white.withValues(alpha: 0.0),
                  ],
                  stops: const [
                    0.0,
                    0.28,
                    0.42,
                    0.48,
                    0.50,
                    0.52,
                    0.58,
                    1.0,
                  ],
                ).createShader(bounds);
              },
              child: widget.child,
            ),

            // Metalik Kıvılcım / Yıldız Parıltısı (Logo üstünde beliren mikro ışıltı flare)
            if (widget.showSparkle && progress > 0.44 && progress < 0.64)
              Positioned(
                top: 10,
                right: 36,
                child: Opacity(
                  opacity: ((1.0 - (progress - 0.54).abs() * 10)).clamp(0.0, 1.0),
                  child: Transform.rotate(
                    angle: progress * 3.14159 * 2,
                    child: Container(
                      width: 20,
                      height: 20,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withValues(alpha: 0.95),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                          BoxShadow(
                            color: const Color(0xFFE50914).withValues(alpha: 0.45),
                            blurRadius: 16,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.auto_awesome,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
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

class _WavyBottomPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()
      ..color = const Color(0xFF8B0000) // Koyu Kırmızı
      ..style = PaintingStyle.fill;
      
    final paint2 = Paint()
      ..color = const Color(0xFFE50914) // Açık Kırmızı
      ..style = PaintingStyle.fill;

    // Arka Planda Kalan Daha Koyu Dalga
    final path1 = Path();
    path1.moveTo(0, size.height * 0.4);
    path1.quadraticBezierTo(size.width * 0.25, size.height * 0.2, size.width * 0.5, size.height * 0.45);
    path1.quadraticBezierTo(size.width * 0.75, size.height * 0.7, size.width, size.height * 0.3);
    path1.lineTo(size.width, size.height);
    path1.lineTo(0, size.height);
    path1.close();
    canvas.drawPath(path1, paint1);

    // Ön Planda Kalan Parlak Dalga
    final path2 = Path();
    path2.moveTo(0, size.height * 0.55);
    path2.quadraticBezierTo(size.width * 0.25, size.height * 0.35, size.width * 0.5, size.height * 0.65);
    path2.quadraticBezierTo(size.width * 0.75, size.height * 0.95, size.width, size.height * 0.4);
    path2.lineTo(size.width, size.height);
    path2.lineTo(0, size.height);
    path2.close();
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
