import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import '../models/user_model.dart';
import '../utils/app_config.dart';
import '../utils/socket_service.dart';
import 'register_screen.dart';
import 'approval_screen.dart';
import 'main_screen.dart';

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

  @override
  void initState() {
    super.initState();
    
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );
    
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
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

  Future<void> _checkForceUpdate() async {
    try {
      final response = await http.get(Uri.parse('${SocketService.serverUrl}/version')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['latestVersion'] as int;
        final downloadUrl = data['downloadUrl'] as String;

        if (latestVersion > AppConfig.currentVersion) {
          if (!mounted) return;
          
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => _UpdateDialogWidget(downloadUrl: downloadUrl),
          );
          throw Exception('Force Update Required');
        }
      }
    } catch (e) {
      if (e.toString().contains('Force Update Required')) rethrow;
      print('Versiyon kontrolü başarısız: $e');
    }
  }

  Future<void> _routeToNextScreen() async {
    await Future.delayed(const Duration(milliseconds: 2800));
    await _checkForceUpdate();
    
    final prefs = await SharedPreferences.getInstance();
    final cihazId = prefs.getString('cihaz_id');
    if (!mounted) return;

    Widget nextScreen;
    if (cihazId == null) {
      nextScreen = const RegisterScreen();
    } else {
      try {
        final response = await Supabase.instance.client
            .from('personel').select('durum, ad_soyad, meslek, profil_foto').eq('cihaz_id', cihazId).maybeSingle();
        if (response != null && response['durum'] == 'onaylandi') {
          UserModel? user = await UserModel.load();
          
          // Güncelleme sonrası lokal veri kaybolmuşsa Supabase'den kurtar
          if (user == null && response['ad_soyad'] != null) {
            final parts = (response['ad_soyad'] as String).split(' ');
            final firstName = parts.isNotEmpty ? parts.first : '';
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            user = UserModel(
              firstName: firstName,
              lastName: lastName,
              jobTitle: response['meslek'] ?? 'Liman İşçisi A',
              photoPath: response['profil_foto'],
            );
            await user.save(); // Lokal veriye tekrar kaydet
          }
          
          if (user != null) { nextScreen = MainScreen(user: user); }
          else { nextScreen = const ApprovalScreen(); }
        } else { nextScreen = const ApprovalScreen(); }
      } catch (e) { nextScreen = const ApprovalScreen(); }
    }

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 800),
        pageBuilder: (_, __, ___) => nextScreen,
        transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _mainController.dispose();
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: AnimatedBuilder(
        animation: Listenable.merge([_mainController, _progressController]),
        builder: (context, child) {
          return Stack(
            children: [
              // ── Beyaz temiz arkaplan ──
              Container(color: Colors.white),
              
              // ── Sol üst köşe kırmızı dekoratif şerit ──
              Positioned(
                top: 0,
                left: 0,
                child: FadeTransition(
                  opacity: _bottomFade,
                  child: Container(
                    width: 120,
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFFDC2626), Color(0x00DC2626)],
                      ),
                    ),
                  ),
                ),
              ),
              
              // ── Sağ alt köşe kırmızı dekoratif şerit ──
              Positioned(
                bottom: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _bottomFade,
                  child: Container(
                    width: 120,
                    height: 4,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0x00DC2626), Color(0xFFDC2626)],
                      ),
                    ),
                  ),
                ),
              ),

              // ── Ana İçerik ──
              SafeArea(
                child: Column(
                  children: [
                    const Spacer(flex: 2),
                    
                    // ── Logo ──
                    FadeTransition(
                      opacity: _logoFade,
                      child: ScaleTransition(
                        scale: _logoScale,
                        child: SizedBox(
                          width: 200,
                          height: 200,
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
                    
                    const SizedBox(height: 32),
                    
                    // ── Kırmızı ince ayırıcı ──
                    FadeTransition(
                      opacity: _textFade,
                      child: Container(
                        width: 40,
                        height: 3,
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626),
                          borderRadius: BorderRadius.circular(2),
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
                            const Text(
                              'İSDEMİR',
                              style: TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontSize: 26,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 6.0,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                              decoration: BoxDecoration(
                                border: Border.all(color: const Color(0xFFDC2626), width: 1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'PERSONEL SİSTEMİ',
                                style: TextStyle(
                                  color: Color(0xFFDC2626),
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 3.0,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const Spacer(flex: 3),
                    
                    // ── Alt Kısım: Progress + Versiyon ──
                    FadeTransition(
                      opacity: _bottomFade,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 60.0),
                        child: Column(
                          children: [
                            // İnce progress bar
                            Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF0F0F0),
                                borderRadius: BorderRadius.circular(1),
                              ),
                              alignment: Alignment.centerLeft,
                              child: FractionallySizedBox(
                                widthFactor: _progressController.value,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626),
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 20),
                            
                            // Versiyon bilgisi
                            Text(
                              'v${AppConfig.currentVersion}.0  •  İskenderun Demir ve Çelik A.Ş.',
                              style: const TextStyle(
                                color: Color(0xFFBDBDBD),
                                fontSize: 10,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 40),
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
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _videoController = VideoPlayerController.asset('assets/videos/game_video2.mp4')
      ..initialize().then((_) {
        if (!mounted) return;
        _videoController?.setLooping(true);
        _videoController?.play();
        _videoController?.setVolume(1.0); // Ses: play() sonrası çağrılmalı
        setState(() {});
      });
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  void _startDownload() async {
    if (isDownloaded && savedApkPath != null) {
      await OpenFilex.open(savedApkPath!);
      return;
    }

    setState(() {
      isDownloading = true;
      progress = 0.0;
    });

    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      try {
        final dir = await getTemporaryDirectory();
        final savePath = '${dir.path}/isdemir_update_new.apk';

        final file = File(savePath);
        if (await file.exists()) {
          await file.delete();
        }

        final dio = Dio();
        dio.options = BaseOptions(
          connectTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 120),
          sendTimeout: const Duration(seconds: 30),
        );

        await dio.download(
          widget.downloadUrl,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1 && mounted) {
              setState(() {
                progress = received / total;
              });
            }
          },
        );

        savedApkPath = savePath;

        if (mounted) {
          setState(() {
            isDownloading = false;
            isDownloaded = true;
          });
        }

        await OpenFilex.open(savePath);
        return; // Başarılı, döngüden çık

      } on DioException catch (e) {
        final isLastAttempt = attempt >= maxRetries;
        if (!isLastAttempt) {
          // Kısa bekleme sonrası tekrar dene
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        if (mounted) {
          setState(() {
            isDownloading = false;
            progress = 0.0;
            isDownloaded = false;
          });
          String errorMsg;
          if (e.type == DioExceptionType.connectionError ||
              e.error is SocketException) {
            errorMsg = 'Bağlantı hatası: İnternet bağlantınızı kontrol edin ve tekrar deneyin.';
          } else if (e.type == DioExceptionType.connectionTimeout ||
                     e.type == DioExceptionType.receiveTimeout) {
            errorMsg = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
          } else if (e.response?.statusCode != null) {
            errorMsg = 'Sunucu hatası (${e.response!.statusCode}). Lütfen daha sonra tekrar deneyin.';
          } else {
            errorMsg = 'İndirme başarısız oldu. Lütfen tekrar deneyin.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMsg),
              duration: const Duration(seconds: 5),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      } catch (e) {
        final isLastAttempt = attempt >= maxRetries;
        if (!isLastAttempt) {
          await Future.delayed(Duration(seconds: attempt * 2));
          continue;
        }
        if (mounted) {
          setState(() {
            isDownloading = false;
            progress = 0.0;
            isDownloaded = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.'),
              duration: const Duration(seconds: 5),
              backgroundColor: const Color(0xFFDC2626),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: const Text('Yeni Güncelleme', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Uygulamanın yeni bir sürümü mevcut. Kullanmaya devam etmek için lütfen güncelleyin.'),
            const SizedBox(height: 20),
            if (_videoController != null && _videoController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 150,
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            if (isDownloading) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(value: progress, color: const Color(0xFFDC2626)),
              const SizedBox(height: 10),
              Text('İndiriliyor: ${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ]
          ],
        ),
        actions: [
          if (!isDownloading)
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: _startDownload,
              child: Text(isDownloaded ? 'Kurulumu Başlat' : 'Şimdi Güncelle', style: const TextStyle(color: Colors.white)),
            ),
        ],
      ),
    );
  }
}
