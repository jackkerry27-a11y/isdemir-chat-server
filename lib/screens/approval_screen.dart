import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
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

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _checkStatus();
  }

  @override
  void dispose() {
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

      final querySnapshot = await FirebaseFirestore.instance
          .collection('personeller')
          .where('cihaz_id', isEqualTo: cihazId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) {
         setState(() {
          _error = 'Kayıt bulunamadı. Silinmiş olabilirsiniz.';
          _isLoading = false;
        });
        return;
      }

      final response = querySnapshot.docs.first.data();
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
      backgroundColor: const Color(0xFF0F0F13),
      body: Stack(
        children: [
          // Background Image with dark overlay
          SizedBox.expand(
            child: Image.asset(
              'assets/images/factory_bg.jpg',
              fit: BoxFit.cover,
            ),
          ),
          
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFFE50914).withValues(alpha: 0.1),
                  const Color(0xFF0F0F13).withValues(alpha: 0.95),
                  const Color(0xFF0F0F13),
                ],
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: _isLoading 
                    ? const CircularProgressIndicator(color: Color(0xFFE50914))
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
        title: 'Hata',
        message: _error,
        action: ElevatedButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
            if (context.mounted) {
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const RegisterScreen()),
                (route) => false,
              );
            }
          },
          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
          child: Text('Kayıt Ekranına Dön', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      );
    }

    if (_status == 'banlandi') {
      return _buildMessageCard(
        icon: Icons.block_rounded,
        title: 'Erişim Engellendi',
        message: 'Cihazınızın sisteme erişimi yönetici tarafından engellenmiştir. Detaylı bilgi için İnsan Kaynakları ile görüşün.',
      );
    }

    return _buildPending();
  }

  Widget _buildPending() {
    return _buildMessageCard(
      title: 'Yönetici Onayı Bekleniyor',
      showPoliceLights: true,
      message: 'Kaydınız başarıyla alındı. Sisteme giriş yapabilmeniz için yöneticinin hesabınızı ve cihazınızı onaylaması beklenmektedir.',
      action: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            colors: [Color(0xFFE50914), Color(0xFF8B0000)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(color: const Color(0xFFE50914).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
          ]
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: _checkStatus,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Text('Durumu Kontrol Et', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ],
            ),
          ),
        ),
      )
    );
  }

  Widget _buildMessageCard({
    IconData? icon, 
    required String title, 
    required String message, 
    Widget? action,
    bool showPoliceLights = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(32),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C22).withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.2), width: 1.5),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 10)),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showPoliceLights)
                _buildConcentricShield()
              else if (icon != null)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE50914).withValues(alpha: 0.1),
                    border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Icon(icon, size: 56, color: const Color(0xFFE50914)),
                ),
                
              const SizedBox(height: 32),
              Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white), textAlign: TextAlign.center),
              
              if (showPoliceLights) ...[
                const SizedBox(height: 20),
                AnimatedBuilder(
                  animation: _blinkController,
                  builder: (context, child) {
                    return Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildDot(0.0),
                        const SizedBox(width: 8),
                        _buildDot(0.5),
                        const SizedBox(width: 8),
                        _buildDot(1.0),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
              ] else ...[
                 const SizedBox(height: 16),
              ],
              
              Text(message, style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFFA1A1AA), height: 1.6), textAlign: TextAlign.center),
              
              if (showPoliceLights) ...[
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.access_time_rounded, color: Color(0xFFE50914), size: 16),
                    const SizedBox(width: 8),
                    Text('Bu işlem biraz zaman alabilir.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA))),
                  ],
                ),
              ],

              const SizedBox(height: 32),
              
              if (action != null) ...[
                SizedBox(width: double.infinity, child: action),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDot(double threshold) {
    bool isActive = (_blinkController.value * 1.5) >= threshold && (_blinkController.value * 1.5) < threshold + 0.5;
    return Container(
      width: 24,
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFE50914) : const Color(0xFF3F3F46),
        borderRadius: BorderRadius.circular(2),
        boxShadow: isActive ? [const BoxShadow(color: Color(0xFFE50914), blurRadius: 6)] : [],
      ),
    );
  }

  Widget _buildConcentricShield() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Outer glow
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: const Color(0xFFE50914).withValues(alpha: 0.15), blurRadius: 60, spreadRadius: 10),
            ],
          ),
        ),
        // Dashed/Dotted outer circle
        Container(
          width: 160,
          height: 160,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.2), width: 1, style: BorderStyle.solid),
          ),
        ),
        // Middle circle
        Container(
          width: 130,
          height: 130,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFE50914).withValues(alpha: 0.05),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 2),
          ),
        ),
        // Inner circle with gradient
        Container(
          width: 90,
          height: 90,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [
                const Color(0xFFE50914).withValues(alpha: 0.6),
                const Color(0xFF8B0000).withValues(alpha: 0.2),
              ],
            ),
          ),
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFFE50914), size: 56),
              const Icon(Icons.person_rounded, color: Colors.white, size: 28),
              Positioned(
                bottom: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C22),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE50914), width: 1.5),
                  ),
                  child: const Icon(Icons.check_rounded, color: Colors.white, size: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
