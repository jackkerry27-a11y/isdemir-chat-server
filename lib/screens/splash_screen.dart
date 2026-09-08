import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  String _userName = '';
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
          _userName = '${user.firstName} ${user.lastName}'.trim();
        } else {
          _isVip = prefVip;
        }
        _isLocalChecked = true;
      });
    }
  }

  Future<bool> _checkForceUpdate() async {
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
            builder: (context) => _UpdateDialogWidget(downloadUrl: downloadUrl),
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
        _userName = user.fullName;
      });
    }

    final bool hasForceReloginV7 = prefs.getBool('force_relogin_v7') ?? false;
    if (!hasForceReloginV7) {
      await prefs.remove('cihaz_id');
      await UserModel.clear();
      await prefs.setBool('force_relogin_v7', true);
    }
    
    final cihazId = prefs.getString('cihaz_id');

    Widget nextScreen = user != null ? MainScreen(user: user) : const RegisterScreen();

    if (cihazId == null) {
      nextScreen = const RegisterScreen();
    } else {
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
        if (querySnapshot != null) {
          if (querySnapshot.docs.isEmpty) {
            await UserModel.clear();
            nextScreen = const RegisterScreen();
          } else {
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

  Widget _buildVipSplash() {
    final hasPhoto = _currentUser?.photoPath != null &&
        File(_currentUser!.photoPath!).existsSync();
    final displayName = _userName.isNotEmpty ? _userName : (_currentUser?.fullName ?? 'Yetkili Personel');
    final jobTitle = _currentUser?.jobTitle.isNotEmpty == true ? _currentUser!.jobTitle : 'İsdemir Saha & Liman Operatörü';

    return Scaffold(
      backgroundColor: const Color(0xFF080A0F),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. ZEMİN: LÜKS OBSİDİYAN & METALİK GECE IŞIK AMBİYANSI
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.0, -0.35),
                  radius: 1.1,
                  colors: [
                    Color(0xFF161E2E),
                    Color(0xFF0C1017),
                    Color(0xFF07080C),
                  ],
                ),
              ),
            ),
          ),

          // Altın ve Şampanya Işıltı Hareleri
          Positioned(
            top: -60,
            right: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                    blurRadius: 90,
                    spreadRadius: 30,
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            bottom: 40,
            left: -60,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF10B981).withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF10B981).withValues(alpha: 0.08),
                    blurRadius: 80,
                    spreadRadius: 20,
                  ),
                ],
              ),
            ),
          ),

          // 2. ANA İÇERİK: KURUMSAL İSDEMİR VIP PORTAL
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 22.0, vertical: 12.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // ── ÜST KURUMSAL BAŞLIK & AMBLEM ──
                        Column(
                          children: [
                            const SizedBox(height: 6),
                            // Kurumsal Rozet
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                    blurRadius: 12,
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.security_rounded, color: Color(0xFFFBBF24), size: 14),
                                  const SizedBox(width: 7),
                                  Text(
                                    'KURUMSAL VIP PROTOKOLÜ • SEVİYE 4',
                                    style: GoogleFonts.orbitron(
                                      color: const Color(0xFFFBBF24),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 12),
                            // İsdemir Logosu & Yazısı
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFE50914), Color(0xFF990000)],
                                    ),
                                    border: Border.all(color: const Color(0xFFFBBF24), width: 1.5),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFE50914).withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      ),
                                    ],
                                  ),
                                  child: const Center(
                                    child: Icon(Icons.factory_rounded, color: Colors.white, size: 16),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'İSDEMİR',
                                  style: GoogleFonts.inter(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 2.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
                                        blurRadius: 8,
                                      ),
                                    ],
                                  ),
                                  child: Text(
                                    'VIP',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.black,
                                      letterSpacing: 1.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'İSKENDERUN DEMİR VE ÇELİK A.Ş. • YÖNETİM PORTALI',
                              style: GoogleFonts.inter(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white54,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        // ── MERKEZ: KURUMSAL YÖNETİCİ KİMLİK KARTI (GLASSMORPHIC) ──
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: const Color(0xFF101520).withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.6),
                                blurRadius: 30,
                                offset: const Offset(0, 15),
                              ),
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Avatar ve Doğrulama Halkası
                              Stack(
                                alignment: Alignment.center,
                                children: [
                                  Container(
                                    width: 104,
                                    height: 104,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFFF59E0B).withValues(alpha: 0.25),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 90,
                                    height: 90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFFBBF24), Color(0xFFD97706), Color(0xFFB45309)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                          blurRadius: 20,
                                          spreadRadius: 3,
                                        ),
                                      ],
                                    ),
                                    padding: const EdgeInsets.all(3),
                                    child: ClipOval(
                                      child: Container(
                                        color: const Color(0xFF131722),
                                        child: hasPhoto
                                            ? Image.file(
                                                File(_currentUser!.photoPath!),
                                                fit: BoxFit.cover,
                                              )
                                            : const Icon(
                                                Icons.person_rounded,
                                                color: Color(0xFFFBBF24),
                                                size: 52,
                                              ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF0F141F),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Container(
                                        padding: const EdgeInsets.all(3),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF10B981),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.verified_rounded,
                                          color: Colors.white,
                                          size: 14,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 16),

                              // İsim Soyisim
                              Text(
                                displayName,
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),

                              const SizedBox(height: 6),

                              // Görev / Unvan Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.05),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Text(
                                  jobTitle,
                                  style: GoogleFonts.inter(
                                    fontSize: 12,
                                    color: const Color(0xFFFBBF24),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // İnce Ayırıcı Çizgi
                              Container(
                                height: 1,
                                width: double.infinity,
                                color: Colors.white.withValues(alpha: 0.08),
                              ),

                              const SizedBox(height: 14),

                              // 3 Parametre Bilgi Satırı
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  _buildVipInfoItem('YETKİ', 'VIP LİDER', Icons.stars_rounded, const Color(0xFFFBBF24)),
                                  Container(width: 1, height: 28, color: Colors.white10),
                                  _buildVipInfoItem('ŞİFRELEME', 'AES-256 GCM', Icons.lock_outline_rounded, const Color(0xFF60A5FA)),
                                  Container(width: 1, height: 28, color: Colors.white10),
                                  _buildVipInfoItem('OTURUM', 'AKTİF DOĞRULAMA', Icons.check_circle_outline_rounded, const Color(0xFF34D399)),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // ── ALT: İLERLEME ÇUBUĞU & ANINDA GEÇİŞ BUTONU ──
                        Column(
                          children: [
                            // Canlı İlerleme Göstergesi
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.03),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Container(
                                      height: 6,
                                      width: double.infinity,
                                      color: const Color(0xFF161B26),
                                      child: AnimatedBuilder(
                                        animation: _progressController,
                                        builder: (context, _) {
                                          return FractionallySizedBox(
                                            alignment: Alignment.centerLeft,
                                            widthFactor: _progressController.value.clamp(0.08, 1.0),
                                            child: Container(
                                              decoration: const BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    Color(0xFFF59E0B),
                                                    Color(0xFFFBBF24),
                                                    Color(0xFF10B981),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  AnimatedBuilder(
                                    animation: _progressController,
                                    builder: (context, _) {
                                      final val = _progressController.value;
                                      final percent = (val * 100).toInt().clamp(0, 100);
                                      final statusText = val < 0.4
                                          ? 'VIP Güvenlik Anahtarları Doğrulanıyor...'
                                          : (val < 0.8
                                              ? 'Kurumsal Portala Bağlanılıyor...'
                                              : 'Erişim Onaylandı • Giriş Sağlanıyor');

                                      return Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              const SizedBox(
                                                width: 12,
                                                height: 12,
                                                child: CircularProgressIndicator(
                                                  strokeWidth: 2,
                                                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFBBF24)),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                statusText,
                                                style: GoogleFonts.inter(
                                                  fontSize: 11.5,
                                                  color: Colors.white70,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Text(
                                            '%$percent',
                                            style: GoogleFonts.orbitron(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                              color: const Color(0xFFFBBF24),
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Şık Kurumsal "Sisteme Giriş Yap" Butonu
                            InkWell(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                _proceedToNext();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                      blurRadius: 16,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'SİSTEME GİRİŞ YAP',
                                      style: GoogleFonts.orbitron(
                                        color: Colors.black,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward_rounded, color: Colors.black, size: 18),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 14),

                            // Kurumsal Alt Bilgi
                            Text(
                              '© 2026 İSDEMİR • OYAK Maden Metalürji Grubu • v${AppConfig.currentVersion}.0',
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                color: Colors.white38,
                                fontWeight: FontWeight.w500,
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
          ),
        ],
      ),
    );
  }

  Widget _buildVipInfoItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.orbitron(
            color: Colors.white38,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
  const _UpdateDialogWidget({required this.downloadUrl});

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
    return '${dir.path}/isdemir_update_v5.apk';
  }

  Future<void> _checkExistingApk() async {
    try {
      final path = await _getApkPath();
      final file = File(path);
      if (await file.exists()) {
        final len = await file.length();
        if (len > 30 * 1024 * 1024) {
          if (mounted) {
            setState(() {
              savedApkPath = path;
              isDownloaded = true;
              progress = 1.0;
            });
          }
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
      return Container(
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
              Text('Güncellemeyi İndir', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
      ),
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
                          decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(20)),
                          child: const Text('YENİ', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text('Yeni bir sürüm mevcut!', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  const Text(
                    'Daha iyi bir deneyim için uygulamamızı\ngüncellemenizi öneriyoruz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(20)),
                    child: Text('v${AppConfig.currentVersion + 1}.0.0 • 45.6 MB', style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, fontWeight: FontWeight.w500)),
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
