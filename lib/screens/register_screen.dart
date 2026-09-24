import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import '../models/user_model.dart';
import 'approval_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  String _firstName = '';
  String _lastName = '';
  String _jobTitle = 'Liman İşçisi A';
  File? _imageFile;
  String? _base64Image;

  void _register() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF4338CA))),
      );

      try {
        final prefs = await SharedPreferences.getInstance();
        var cihazId = prefs.getString('cihaz_id');
        if (cihazId == null) {
          cihazId = const Uuid().v4();
          await prefs.setString('cihaz_id', cihazId);
        }
        OneSignal.login(cihazId);

        final adSoyad = '$_firstName $_lastName';
        
        final selectedJob = UserModel.jobRates[_jobTitle];
        final tabanMaas = selectedJob?.baseSalary ?? 30000.0;

        // Firestore'a kayıt atalım
        await FirebaseFirestore.instance.collection('personeller').add({
          'ad_soyad': adSoyad,
          'cihaz_id': cihazId,
          'durum': 'onay_bekliyor',
          'meslek': _jobTitle,
          'taban_maas': tabanMaas,
          'is_vip': false,
          'kayit_tarihi': FieldValue.serverTimestamp(),
        });

        // Modeli lokale de kaydedelim (eski kod uyumluluğu için)
        final user = UserModel(
          firstName: _firstName,
          lastName: _lastName,
          jobTitle: _jobTitle,
          photoPath: _base64Image,
        );
        await user.save();
        
        if (mounted) {
          Navigator.of(context).pop(); // loading kapat
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ApprovalScreen()),
          );
        }
      } catch (e) {
        if (mounted) {
          Navigator.of(context).pop(); // loading kapat
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Kayıt başarısız: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Arka plan kırmızı alan
            Container(
              height: 320,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7A0000), Color(0xFFE50914)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Opacity(
                opacity: 0.15,
                child: Image.asset(
                  'assets/images/factory_bg.jpg',
                  fit: BoxFit.cover,
                ),
              ),
            ),

            // İçerik (Header)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    Column(
                      children: [
                        Text('İşdemir OS Kayıt', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('Hesabınızı oluşturun', style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      ],
                    ),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),
            ),
            
            // Beyaz İçerik Alanı
            Container(
              margin: const EdgeInsets.only(top: 200),
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 200,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(32), topRight: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 80, left: 24, right: 24, bottom: 40),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      Text('Profil Bilgilerinizi Girin', style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 18, color: const Color(0xFF1C1C22))),
                      const SizedBox(height: 8),
                      Text('Lütfen kişisel bilgilerinizi eksiksiz doldurun.', style: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 14)),
                      
                      const SizedBox(height: 32),
                      
                      // Input Fields
                      _buildCustomTextField(
                        label: 'Adınız',
                        hint: 'Adınızı giriniz',
                        icon: Icons.person,
                        onSaved: (val) => _firstName = val!,
                        validator: (val) => val == null || val.isEmpty ? 'Lütfen adınızı girin' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomTextField(
                        label: 'Soyadınız',
                        hint: 'Soyadınızı giriniz',
                        icon: Icons.person,
                        onSaved: (val) => _lastName = val!,
                        validator: (val) => val == null || val.isEmpty ? 'Lütfen soyadınızı girin' : null,
                      ),
                      const SizedBox(height: 24),
                      
                      // Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text('Mesleğiniz', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: const Color(0xFF3F3F46))),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFF4F4F5), width: 1.5),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _jobTitle,
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF1C1C22)),
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(12.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFFFF0F1), borderRadius: BorderRadius.circular(12)),
                                    child: const Icon(Icons.work_rounded, color: Color(0xFFE50914), size: 20),
                                  ),
                                ),
                                labelText: 'Liman İşçiliği',
                                labelStyle: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: UserModel.jobRates.keys.map((String job) {
                                return DropdownMenuItem<String>(
                                  value: job,
                                  child: Text(job, style: GoogleFonts.inter(fontWeight: FontWeight.w700, color: const Color(0xFF1C1C22))),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _jobTitle = val!),
                              onSaved: (val) => _jobTitle = val!,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 32),
                      
                      // Güvenli Kayıt Box
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF6F7),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.security_rounded, color: Color(0xFFE50914), size: 28),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Güvenli Kayıt', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF1C1C22))),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Bilgileriniz 256-bit SSL şifreleme ile korunmakta ve sadece yetkili kişiler tarafından erişilebilir.',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF71717A), height: 1.4),
                                  ),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),
                      
                      // Kayıt Butonu
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          color: const Color(0xFFE50914),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFFE50914).withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 8)),
                          ]
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _register,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.lock_rounded, color: Colors.white, size: 20),
                                const SizedBox(width: 12),
                                Text('Sisteme Kaydol', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                const SizedBox(width: 12),
                                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 20),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_outline, size: 14, color: Color(0xFF71717A)),
                          const SizedBox(width: 6),
                          Flexible(
                            child: RichText(
                              textAlign: TextAlign.center,
                              text: TextSpan(
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF71717A)),
                                children: const [
                                  TextSpan(text: 'Kayıt olarak, '),
                                  TextSpan(text: 'KVKK aydınlatma metnini\n', style: TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.w600)),
                                  TextSpan(text: 'okuduğunuzu ve kabul ettiğinizi onaylarsınız.'),
                                ],
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
            
            // Profile Photo (Overlapping the header)
            Positioned(
              top: 130,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: Stack(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 20, offset: const Offset(0, 10))],
                      ),
                      child: const CircleAvatar(
                        radius: 60,
                        backgroundColor: Color(0xFFF4F4F5),
                        child: Icon(Icons.person, size: 70, color: Color(0xFFD4D4D8)),
                      ),
                    ),
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE50914),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({required String label, required String hint, required IconData icon, required void Function(String?) onSaved, required String? Function(String?) validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF4F4F5), width: 1.5),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: TextFormField(
        style: GoogleFonts.inter(fontWeight: FontWeight.w600, color: const Color(0xFF1C1C22)),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(color: const Color(0xFF71717A), fontSize: 12),
          hintText: hint,
          hintStyle: GoogleFonts.inter(color: const Color(0xFFA1A1AA), fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFFFF0F1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: const Color(0xFFE50914), size: 20),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }
}
