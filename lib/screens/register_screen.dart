import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
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
  final ImagePicker _picker = ImagePicker();

  String? _base64Image;

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 150,
      maxHeight: 150,
      imageQuality: 60,
    );
    if (pickedFile != null) {
      final bytes = await File(pickedFile.path).readAsBytes();
      final base64String = 'base64:' + base64Encode(bytes);
      setState(() {
        _imageFile = File(pickedFile.path);
        _base64Image = base64String;
      });
    }
  }

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

        final adSoyad = '$_firstName $_lastName';
        
        final selectedJob = UserModel.jobRates[_jobTitle];
        final tabanMaas = selectedJob?.baseSalary ?? 30000.0;

        // Supabase'e kayıt atalım
        await Supabase.instance.client.from('personel').insert({
          'ad_soyad': adSoyad,
          'cihaz_id': cihazId,
          'durum': 'onay_bekliyor',
          'meslek': _jobTitle,
          'taban_maas': tabanMaas
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
      backgroundColor: const Color(0xFFF3F4F6),
      body: SingleChildScrollView(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Arka plan mavi/mor alan
            Container(
              height: 260,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF4338CA), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // Dekoratif yuvarlak şekiller (Tasarımı zenginleştirmek için)
            Positioned(
              right: -50,
              top: -50,
              child: Container(width: 200, height: 200, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))),
            ),
            Positioned(
              left: -30,
              top: 150,
              child: Container(width: 150, height: 150, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: 0.05))),
            ),

            // İçerik (Header)
            SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Text('İşdemir OS Kayıt', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 48), // Balance for back button
                  ],
                ),
              ),
            ),
            
            // Beyaz İçerik Alanı
            Container(
              margin: const EdgeInsets.only(top: 180),
              constraints: BoxConstraints(
                minHeight: MediaQuery.of(context).size.height - 180,
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
                      const Text('Profil Fotoğrafı', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E293B))),
                      const SizedBox(height: 4),
                      const Text('Seç (Opsiyonel)', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                      
                      const SizedBox(height: 32),
                      
                      // Input Fields
                      _buildCustomTextField(
                        label: 'Adınız',
                        icon: Icons.badge_rounded,
                        onSaved: (val) => _firstName = val!,
                        validator: (val) => val == null || val.isEmpty ? 'Lütfen adınızı girin' : null,
                      ),
                      const SizedBox(height: 16),
                      _buildCustomTextField(
                        label: 'Soyadınız',
                        icon: Icons.badge_rounded,
                        onSaved: (val) => _lastName = val!,
                        validator: (val) => val == null || val.isEmpty ? 'Lütfen soyadınızı girin' : null,
                      ),
                      const SizedBox(height: 16),
                      
                      // Dropdown
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(left: 4, bottom: 8),
                            child: Text('Mesleğiniz', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF64748B))),
                          ),
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
                              border: Border.all(color: const Color(0xFFF1F5F9)),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: _jobTitle,
                              icon: const Icon(Icons.arrow_drop_down_rounded, color: Color(0xFF475569)),
                              decoration: InputDecoration(
                                prefixIcon: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
                                    child: const Icon(Icons.work_rounded, color: Color(0xFF4338CA), size: 20),
                                  ),
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              items: UserModel.jobRates.keys.map((String job) {
                                return DropdownMenuItem<String>(
                                  value: job,
                                  child: Text(job, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B))),
                                );
                              }).toList(),
                              onChanged: (val) => setState(() => _jobTitle = val!),
                              onSaved: (val) => _jobTitle = val!,
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),
                      
                      // Kayıt Butonu
                      Container(
                        width: double.infinity,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF4338CA), Color(0xFF3B82F6)],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                          boxShadow: [
                            BoxShadow(color: const Color(0xFF4338CA).withValues(alpha: 0.4), blurRadius: 12, offset: const Offset(0, 6)),
                          ]
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _register,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(Icons.save_rounded, color: Colors.white, size: 22),
                                SizedBox(width: 12),
                                Text('Sisteme Kaydol', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            
            // Profile Photo (Overlapping the header)
            Positioned(
              top: 120,
              left: 0,
              right: 0,
              child: Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: _pickImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white, // Ensure white background for border
                        ),
                        child: CircleAvatar(
                          radius: 56,
                          backgroundColor: const Color(0xFFEEF2FF),
                          backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                          child: _imageFile == null
                              ? const Icon(Icons.person, size: 64, color: Color(0xFF94A3B8))
                              : null,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _imageFile != null ? const Color(0xFF10B981) : const Color(0xFF4338CA),
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: (_imageFile != null ? const Color(0xFF10B981) : const Color(0xFF4338CA)).withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))],
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: Icon(
                          _imageFile != null ? Icons.check_rounded : Icons.add_a_photo_rounded, 
                          color: Colors.white, 
                          size: 18
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({required String label, required IconData icon, required void Function(String?) onSaved, required String? Function(String?) validator}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: TextFormField(
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 14),
          prefixIcon: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: const Color(0xFFEEF2FF), borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: const Color(0xFF4338CA), size: 20),
            ),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        validator: validator,
        onSaved: onSaved,
      ),
    );
  }
}
