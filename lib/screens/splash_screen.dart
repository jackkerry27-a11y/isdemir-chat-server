import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
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

  Future<bool> _checkForceUpdate() async {
    try {
      final response = await http.get(
        Uri.parse('${SocketService.serverUrl}/version'),
        headers: {
          'User-Agent': 'IsdemirOS-Mobile/1.0',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('[UPDATE] HTTP Status: ${response.statusCode}');
      print('[UPDATE] Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['latestVersion'] as int;
        final downloadUrl = data['downloadUrl'] as String;
        
        print('[UPDATE] Server version: $latestVersion, App version: ${AppConfig.currentVersion}');

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
    } catch (e) {
      print('[UPDATE] Versiyon kontrolü başarısız: $e');
    }
    return false;
  }

  Future<bool> _checkShorebirdUpdate() async {
    try {
      final shorebirdUpdater = ShorebirdUpdater();
      final status = await shorebirdUpdater.checkForUpdate();
      
      if (status == UpdateStatus.outdated) {
        if (!mounted) return false;
        
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const _ShorebirdUpdateDialogWidget(),
        );
        return true; // Halt navigation
      }
    } catch (e) {
      print('Shorebird güncelleme kontrolü başarısız: $e');
    }
    return false;
  }

  Future<void> _routeToNextScreen() async {
    // 1. Önce cihazda kayıtlı kullanıcı var mı kontrol et
    final user = await UserModel.load();
    
    // Kısa ve zarif bir splash bekleme süresi
    await Future.delayed(const Duration(milliseconds: 1600));
    
    bool shouldHalt = false;
    try {
      shouldHalt = await _checkForceUpdate();
      if (!shouldHalt) {
        shouldHalt = await _checkShorebirdUpdate();
      }
    } catch (e) {
      print("Güncelleme kontrolü sırasında beklenmeyen hata: $e");
    }
    
    if (shouldHalt) {
      return; // Beklemede kal, dialog ekranda
    }
    
    if (!mounted) return;

    // Eğer kullanıcı zaten giriş yapmışsa DOĞRUDAN ana ekrana geç (Flaşlama / Kayıt ekranı görünmesin)
    if (user != null) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => MainScreen(user: user),
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final cihazId = prefs.getString('cihaz_id');

    Widget nextScreen;
    if (cihazId == null) {
      nextScreen = const RegisterScreen();
    } else {
      try {
        final response = await Supabase.instance.client
            .from('personel').select('durum, ad_soyad, meslek, profil_foto').eq('cihaz_id', cihazId).maybeSingle();
        if (response != null && response['durum'] == 'onaylandi') {
          UserModel? restoredUser = await UserModel.load();
          if (restoredUser == null && response['ad_soyad'] != null) {
            final parts = (response['ad_soyad'] as String).split(' ');
            final firstName = parts.isNotEmpty ? parts.first : '';
            final lastName = parts.length > 1 ? parts.sublist(1).join(' ') : '';
            restoredUser = UserModel(
              firstName: firstName,
              lastName: lastName,
              jobTitle: response['meslek'] ?? 'Liman İşçisi A',
              photoPath: response['profil_foto'],
            );
            await restoredUser.save();
          }
          if (restoredUser != null) {
            nextScreen = MainScreen(user: restoredUser);
          } else {
            nextScreen = const ApprovalScreen();
          }
        } else {
          nextScreen = const ApprovalScreen();
        }
      } catch (e) {
        nextScreen = const ApprovalScreen();
      }
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 500),
          pageBuilder: (_, __, ___) => nextScreen,
          transitionsBuilder: (_, animation, __, child) => FadeTransition(opacity: animation, child: child),
        ),
      );
    }
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
  int receivedBytes = 0;
  int totalBytes = 0;
  CancelToken? _cancelToken;
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
    _checkExistingApk();
  }

  void _initVideo() {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/game_video2.mp4')
        ..initialize().then((_) {
          if (!mounted) return;
          _videoController?.setLooping(true);
          _videoController?.play();
          _videoController?.setVolume(1.0);
          setState(() {});
        }).catchError((_) {});
    } catch (_) {}
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
        if (len > 30 * 1024 * 1024) { // 30MB+ valid APK
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
    _videoController?.dispose();
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
            action: SnackBarAction(
              label: 'Tarayıcıda Aç',
              textColor: Colors.white,
              onPressed: _openInBrowser,
            ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Tarayıcı açılamadı: $e'),
            backgroundColor: const Color(0xFFDC2626),
          ),
        );
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
        if (e.type == DioExceptionType.connectionError ||
            e.error is SocketException) {
          errorMsg = 'Bağlantı hatası: İnternet bağlantınızı kontrol edin.';
        } else if (e.type == DioExceptionType.connectionTimeout ||
                   e.type == DioExceptionType.receiveTimeout) {
          errorMsg = 'Bağlantı zaman aşımına uğradı. Lütfen tekrar deneyin.';
        } else {
          errorMsg = 'İndirme tamamlanamadı. Tarayıcı ile indirmeyi deneyebilirsiniz.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            duration: const Duration(seconds: 6),
            backgroundColor: const Color(0xFFDC2626),
            action: SnackBarAction(
              label: 'Tarayıcıda Aç',
              textColor: Colors.white,
              onPressed: _openInBrowser,
            ),
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
            action: SnackBarAction(
              label: 'Tarayıcıda Aç',
              textColor: Colors.white,
              onPressed: _openInBrowser,
            ),
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
    return 'İndirme hazırlanıyor...';
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Yeni Güncelleme', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulamanın yeni bir sürümü mevcut. Kesintisiz kullanım için lütfen güncelleyin.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_videoController != null && _videoController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            if (isDownloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress > 0 ? progress : null,
                  color: const Color(0xFFDC2626),
                  backgroundColor: Colors.grey.shade200,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  _getProgressString(),
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626)),
                ),
              ),
            ],
            if (isDownloaded && !isDownloading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'İndirme tamamlandı. Kurulumu başlatabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(Icons.open_in_browser_rounded, size: 18),
                label: const Text('Tarayıcıdan İndir', style: TextStyle(fontSize: 13)),
                style: TextButton.styleFrom(foregroundColor: Colors.blueGrey.shade700),
                onPressed: _openInBrowser,
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                icon: Icon(
                  isDownloaded ? Icons.install_mobile_rounded : (isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded),
                  size: 18,
                  color: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDownloaded ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: isDownloading ? null : _startDownload,
                label: Text(
                  isDownloaded ? 'Kurulumu Başlat' : (isDownloading ? 'İndiriliyor...' : 'Şimdi Güncelle'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
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
  VideoPlayerController? _videoController;

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  void _initVideo() {
    try {
      _videoController = VideoPlayerController.asset('assets/videos/game_video2.mp4')
        ..initialize().then((_) {
          if (!mounted) return;
          _videoController?.setLooping(true);
          _videoController?.play();
          _videoController?.setVolume(1.0);
          setState(() {});
        }).catchError((_) {});
    } catch (_) {}
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      child: AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.system_update_rounded, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Text('Küçük Yama Güncellemesi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Uygulama için küçük bir yama (patch) mevcut. Sadece saniyeler sürecek bu güncellemeyi alarak yeniliklere hemen erişebilirsiniz.',
              style: TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 16),
            if (_videoController != null && _videoController!.value.isInitialized)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 140,
                  width: double.infinity,
                  child: AspectRatio(
                    aspectRatio: _videoController!.value.aspectRatio,
                    child: VideoPlayer(_videoController!),
                  ),
                ),
              ),
            if (isDownloading) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: const LinearProgressIndicator(
                  color: Color(0xFFDC2626),
                  backgroundColor: Color(0xFFF1F5F9),
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Arka planda yama indiriliyor...',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Color(0xFFDC2626)),
                ),
              ),
            ],
            if (isDownloaded && !isDownloading) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Yama indirildi! Uygulamayı yeniden başlatarak kurabilirsiniz.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF065F46), fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        actions: [
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  isDownloaded ? Icons.refresh_rounded : (isDownloading ? Icons.hourglass_top_rounded : Icons.download_rounded),
                  size: 18,
                  color: Colors.white,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDownloaded ? const Color(0xFF10B981) : const Color(0xFFDC2626),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                ),
                onPressed: isDownloading ? null : (isDownloaded ? _restartApp : _startDownload),
                label: Text(
                  isDownloaded ? 'Yeniden Başlat' : (isDownloading ? 'İndiriliyor...' : 'Şimdi İndir'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
