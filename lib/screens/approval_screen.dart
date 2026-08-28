import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import 'main_screen.dart';
import '../models/user_model.dart';
import 'dart:io';
import 'register_screen.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({super.key});

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _status = 'onay_bekliyor';
  String _error = '';
  late AnimationController _blinkController;
  late VideoPlayerController _videoController;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    
    // Kullanıcının kaydettiği Battlefield 6 oyun videosu
    _videoController = VideoPlayerController.asset('assets/videos/game_video.mp4')
      ..initialize().then((_) {
        _videoController.setLooping(true);
        _videoController.play();
        setState(() {}); // Video yüklendiğinde ekranı güncelle
      });

    _checkStatus();
  }

  @override
  void dispose() {
    _videoController.dispose();
    _blinkController.dispose();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');

      if (cihazId == null) {
        setState(() {
          _error = 'Cihaz kimliği bulunamadı. Lütfen yeniden kayıt olun.';
          _isLoading = false;
        });
        return;
      }

      final response = await Supabase.instance.client
          .from('personel')
          .select('durum')
          .eq('cihaz_id', cihazId)
          .maybeSingle();

      if (response == null) {
         setState(() {
          _error = 'Kayıt bulunamadı. Silinmiş olabilirsiniz.';
          _isLoading = false;
        });
        return;
      }

      final durum = response['durum'] as String;
      
      setState(() {
        _status = durum;
        _isLoading = false;
      });

      if (_status == 'onaylandi' && mounted) {
        final user = await UserModel.load();
        if (user != null) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => MainScreen(user: user)),
          );
        }
      }

    } catch (e) {
      setState(() {
        _error = 'Bağlantı hatası: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Arka plan tam ekran video
          if (_videoController.value.isInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _videoController.value.size.width,
                  height: _videoController.value.size.height,
                  child: VideoPlayer(_videoController),
                ),
              ),
            ),
          
          // Videonun üstüne hafif karanlık katman (yazıların okunması için)
          if (_videoController.value.isInitialized)
            Container(
              color: Colors.black.withValues(alpha: 0.4),
            ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Color(0xFF4338CA))
                    : _buildContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_error.isNotEmpty) {
      return _buildMessageCard(
        icon: Icons.error_outline_rounded,
        iconColor: Colors.red,
        title: 'Hata',
        message: _error,
        action: ElevatedButton(
          onPressed: () async {
            // Cihaz bilgilerini temizle ve kayıt ekranına dön
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            await Supabase.instance.client.auth.signOut();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          child: const Text('Kayıt Ekranına Dön', style: TextStyle(color: Colors.white)),
        )
      );
    }

    if (_status == 'banlandi') {
      return _buildMessageCard(
        icon: Icons.block_rounded,
        iconColor: Colors.red,
        title: 'Erişim Engellendi',
        message: 'Cihazınızın sisteme erişimi yönetici tarafından engellenmiştir. Detaylı bilgi için İnsan Kaynakları ile görüşün.',
      );
    }

    return _buildPending();
  }

  Widget _buildPending() {
    return _buildMessageCard(
      icon: Icons.hourglass_empty_rounded,
      iconColor: const Color(0xFFEA580C),
      title: 'Yönetici Onayı Bekleniyor',
      showPoliceLights: true,
      message: 'Kaydınız başarıyla alındı. Sisteme giriş yapabilmeniz için yöneticinin hesabınızı ve cihazınızı onaylaması beklenmektedir.\nBu işlem biraz zaman alabilir.',
      action: ElevatedButton.icon(
        onPressed: _checkStatus,
        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
        label: const Text('Durumu Kontrol Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF4338CA),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      )
    );
  }

  Widget _buildMessageCard({
    IconData? icon, 
    Color? iconColor, 
    Widget? topWidget,
    required String title, 
    required String message, 
    Widget? action,
    bool showPoliceLights = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
        children: [
          if (topWidget != null) 
            topWidget
          else if (icon != null)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
              ),
              child: Icon(icon, size: 56, color: iconColor),
            ),
          const SizedBox(height: 32),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)), textAlign: TextAlign.center),
          
          if (showPoliceLights) ...[
            const SizedBox(height: 16),
            AnimatedBuilder(
              animation: _blinkController,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: _blinkController.value < 0.5 ? 1.0 : 0.2),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: _blinkController.value < 0.5 ? [const BoxShadow(color: Colors.blue, blurRadius: 6)] : [],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 24,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.orange.withValues(alpha: _blinkController.value >= 0.5 ? 1.0 : 0.2),
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: _blinkController.value >= 0.5 ? [const BoxShadow(color: Colors.orange, blurRadius: 6)] : [],
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 24),
          ] else ...[
             const SizedBox(height: 16),
          ],
          
          Text(message, style: const TextStyle(fontSize: 13, color: Color(0xFF64748B), height: 1.6), textAlign: TextAlign.center),
          if (action != null) ...[
            SizedBox(width: double.infinity, child: action),
          ]
        ],
      ),
    ),
    ),
    );
  }
}
