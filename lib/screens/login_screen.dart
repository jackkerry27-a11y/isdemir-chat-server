import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _passwordController = TextEditingController();
  String _errorMessage = '';
  bool _isObscure = true;
  bool _rememberMe = true;

  void _login() async {
    if (_passwordController.text == '4896281aa') {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('rememberMe', _rememberMe);
      
      final user = await UserModel.load();
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => MainScreen(user: user)),
        );
      }
    } else {
      setState(() {
        _errorMessage = 'Hatalı şifre.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Arka plan dekoratif dokunuşlar
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4338CA).withValues(alpha: 0.03),
              ),
            ),
          ),
          Positioned(
            top: 150,
            left: -150,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF4338CA).withValues(alpha: 0.02),
              ),
            ),
          ),
          
          // Sol Fabrika İkonu
          Positioned(
            top: 150,
            left: -30,
            child: Opacity(
              opacity: 0.15,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4338CA), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.location_city_rounded,
                  size: 220,
                ),
              ),
            ),
          ),
          
          // Sağ İnsan (Mühendis) İkonu
          Positioned(
            top: 140,
            right: -30,
            child: Opacity(
              opacity: 0.15,
              child: ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF4338CA), Colors.transparent],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ).createShader(bounds),
                blendMode: BlendMode.srcIn,
                child: const Icon(
                  Icons.engineering_rounded,
                  size: 240,
                ),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo Alanı
                    const SizedBox(height: 20),
                    Image.asset(
                      'assets/images/logo.jpg',
                      height: 100,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const Icon(
                        Icons.business,
                        size: 80,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Hoş Geldiniz',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1A202C),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'İsdemir Personel Giriş Portalı',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF718096),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 32),
                    
                    // Giriş Formu Kartı
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Erişim Bilgileri',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF1A202C),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Sisteme giriş yapmak için bilgilerinizi giriniz.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF718096),
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          // Şifre Alanı
                          TextField(
                            controller: _passwordController,
                            obscureText: _isObscure,
                            style: const TextStyle(color: Color(0xFF1A202C), fontSize: 15),
                            decoration: InputDecoration(
                              hintText: 'Şifre',
                              hintStyle: const TextStyle(color: Color(0xFFA0AEC0)),
                              prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFA0AEC0), size: 22),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: const Color(0xFFA0AEC0),
                                  size: 22,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _isObscure = !_isObscure;
                                  });
                                },
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(vertical: 18),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade200, width: 1.5),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5),
                              ),
                            ),
                          ),
                          
                          if (_errorMessage.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(_errorMessage, style: const TextStyle(color: Color(0xFFE53E3E), fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                          
                          const SizedBox(height: 20),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: Checkbox(
                                      value: _rememberMe,
                                      onChanged: (val) {
                                        setState(() {
                                          _rememberMe = val ?? true;
                                        });
                                      },
                                      activeColor: const Color(0xFF3B82F6),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                                      side: BorderSide(color: Colors.grey.shade300, width: 1.5),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Beni Hatırla',
                                    style: TextStyle(fontSize: 13, color: Color(0xFF4A5568), fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              const Text(
                                'Şifremi Unuttum?',
                                style: TextStyle(fontSize: 13, color: Color(0xFF3B82F6), fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),
                          
                          SizedBox(
                            width: double.infinity,
                            height: 54,
                            child: ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF3B82F6),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                              child: const Text(
                                'SİSTEME GİRİŞ',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Güvenlik Kartı
                    Container(
                      constraints: const BoxConstraints(maxWidth: 400),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.security_rounded, color: Color(0xFF3B82F6), size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Güvenliğiniz Bizim İçin Önemli',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF2D3748),
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Kişisel verileriniz 256-bit SSL şifreleme ile korunmaktadır.',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF4A5568),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 40),
                    
                    // Footer
                    const Text(
                      '© 2024 İsdemir. Tüm hakları saklıdır.',
                      style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 12),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        'v1.2.0',
                        style: TextStyle(color: Color(0xFFA0AEC0), fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
