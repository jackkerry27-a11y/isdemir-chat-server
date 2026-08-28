import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';
import 'login_screen.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onProfileUpdated;

  const SettingsScreen({super.key, required this.user, required this.onProfileUpdated});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final ImagePicker _picker = ImagePicker();

  Future<void> _pickImage() async {
    final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        widget.user.photoPath = pickedFile.path;
      });
      await widget.user.save();
      widget.onProfileUpdated();
    }
  }

  void _logout() async {
    await UserModel.clear();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _editField(String title, String initialValue, Function(String) onSave) async {
    TextEditingController controller = TextEditingController(text: initialValue);
    
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('$title Düzenle', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          content: TextField(
            controller: controller,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF4338CA), width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4338CA),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Kaydet', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showJobPicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Meslek Seçin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              ...UserModel.jobRates.keys.map((job) {
                return ListTile(
                  title: Text(job, style: TextStyle(fontWeight: job == widget.user.jobTitle ? FontWeight.bold : FontWeight.normal)),
                  trailing: job == widget.user.jobTitle ? const Icon(Icons.check, color: Color(0xFF4338CA)) : null,
                  onTap: () async {
                    setState(() {
                      widget.user.jobTitle = job;
                    });
                    await widget.user.save();
                    widget.onProfileUpdated();
                    if (mounted) Navigator.pop(context);
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Stack(
          children: [
            // Kırmızı Header Zemin
            Container(
              height: 220,
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF2E1065), Color(0xFF4338CA), Color(0xFF3B82F6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            
            // Ana İçerik
            Container(
              margin: const EdgeInsets.only(top: 140),
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profil Kartı
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 20, offset: const Offset(0, 5)),
                        ],
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.grey.shade200, width: 2),
                                    image: widget.user.photoPath != null
                                        ? DecorationImage(image: SocketService.getAvatarProvider(widget.user.photoPath)!, fit: BoxFit.cover)
                                        : null,
                                  ),
                                  child: widget.user.photoPath == null
                                      ? const Icon(Icons.person, size: 40, color: Colors.grey)
                                      : null,
                                ),
                                Positioned(
                                  bottom: 0, right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF4338CA),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.edit, color: Colors.white, size: 12),
                                  ),
                                )
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${widget.user.firstName} ${widget.user.lastName}',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  widget.user.jobTitle,
                                  style: const TextStyle(fontSize: 13, color: Color(0xFF718096)),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: const [
                                      Icon(Icons.badge_rounded, color: Color(0xFF4338CA), size: 14),
                                      SizedBox(width: 4),
                                      Text('Personel', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0AEC0)),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Hesap Bilgileri Başlığı
                    const Text('Hesap Bilgileri', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                    const SizedBox(height: 16),
                    
                    // Ayarlar Listesi
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5)),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildSettingItem(
                            icon: Icons.person_outline_rounded,
                            title: 'Ad',
                            subtitle: widget.user.firstName,
                            onTap: () {
                              _editField('Ad', widget.user.firstName, (val) async {
                                setState(() => widget.user.firstName = val);
                                await widget.user.save();
                                widget.onProfileUpdated();
                              });
                            }
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),
                          _buildSettingItem(
                            icon: Icons.person_outline_rounded,
                            title: 'Soyad',
                            subtitle: widget.user.lastName,
                            onTap: () {
                              _editField('Soyad', widget.user.lastName, (val) async {
                                setState(() => widget.user.lastName = val);
                                await widget.user.save();
                                widget.onProfileUpdated();
                              });
                            }
                          ),
                          const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFFF1F5F9)),
                          _buildSettingItem(
                            icon: Icons.work_outline_rounded,
                            title: 'Meslek',
                            subtitle: widget.user.jobTitle,
                            onTap: _showJobPicker,
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 48),
                    
                    // Çıkış Butonu
                    GestureDetector(
                      onTap: _logout,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.logout_rounded, color: Color(0xFF4338CA), size: 20),
                            SizedBox(width: 8),
                            Text('Hesaptan Çıkış Yap', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Alt Bilgi
                    Center(
                      child: Column(
                        children: const [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.security_rounded, color: Color(0xFF10B981), size: 16),
                              SizedBox(width: 6),
                              Text('Oturumunuz güvenli bir şekilde korunmaktadır.', style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text('Sürüm 1.0.0', style: TextStyle(fontSize: 10, color: Color(0xFFA0AEC0))),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Header Metinleri (Sabit Üst)
            Positioned(
              top: 0, left: 0, right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10, left: 24, right: 24),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Ayarlar',
                            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                          ),
                          Text(
                            'Hesap bilgilerinizi yönetin',
                            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const Icon(Icons.settings_outlined, color: Colors.white, size: 32),
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

  Widget _buildSettingItem({required IconData icon, required String title, required String subtitle, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFF4338CA), size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0AEC0)),
          ],
        ),
      ),
    );
  }
}
