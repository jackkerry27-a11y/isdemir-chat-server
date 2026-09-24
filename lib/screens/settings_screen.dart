import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';
import 'login_screen.dart';

import 'package:intl/intl.dart';

class SettingsScreen extends StatefulWidget {
  final UserModel user;
  final VoidCallback onProfileUpdated;
  final double totalSalary;
  final double baseSalary;
  final double ekMesai;

  const SettingsScreen({
    super.key, 
    required this.user, 
    required this.onProfileUpdated,
    this.totalSalary = 0,
    this.baseSalary = 0,
    this.ekMesai = 0,
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Photo picking removed to fix shorebird build

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
          backgroundColor: const Color(0xFF1C1C22),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF3F3F46))),
          title: Text('$title Düzenle', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
          content: TextField(
            controller: controller,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFF0F0F13),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3F3F46))),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE50914), width: 2),
              ),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF3F3F46))),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('İptal', style: GoogleFonts.inter(color: const Color(0xFFA1A1AA))),
            ),
            ElevatedButton(
              onPressed: () {
                onSave(controller.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: Text('Kaydet', style: GoogleFonts.inter(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showJobPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Meslek Seçin', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 16),
              ...UserModel.jobRates.keys.map((job) {
                return ListTile(
                  title: Text(job, style: GoogleFonts.inter(color: Colors.white, fontWeight: job == widget.user.jobTitle ? FontWeight.bold : FontWeight.normal)),
                  trailing: job == widget.user.jobTitle ? const Icon(Icons.check, color: Color(0xFFE50914)) : null,
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
    final currencyFormatter = NumberFormat.currency(locale: 'tr_TR', symbol: '₺');
    final formattedTotal = currencyFormatter.format(widget.totalSalary);
    final formattedBase = currencyFormatter.format(widget.baseSalary);
    final formattedEkMesai = currencyFormatter.format(widget.ekMesai);

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      appBar: AppBar(
        backgroundColor: const Color(0xFF8B0000), // Gradient starting color
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Personel Profili', style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF8B0000), Color(0xFF3F0000), Color(0xFF0F0F13)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            // Profile Header
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F0F13), Color(0xFF0F0F13)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // Avatar
                  Stack(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE50914), width: 3),
                          image: widget.user.photoPath != null
                              ? DecorationImage(image: SocketService.getAvatarProvider(widget.user.photoPath)!, fit: BoxFit.cover)
                              : null,
                        ),
                        child: widget.user.photoPath == null
                            ? const Icon(Icons.person, size: 50, color: Colors.white)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: GestureDetector(
                          onTap: () {
                            _editField('Ad', widget.user.firstName, (val) async {
                                setState(() => widget.user.firstName = val);
                                await widget.user.save();
                                widget.onProfileUpdated();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE50914),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF0F0F13), width: 2),
                            ),
                            child: const Icon(Icons.edit, color: Colors.white, size: 16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${widget.user.firstName} ${widget.user.lastName}',
                    style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  // Role Pill
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C22),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.business, color: Color(0xFFE50914), size: 16),
                        const SizedBox(width: 8),
                        Text(
                          'Erkport A.Ş. • ${widget.user.jobTitle}',
                          style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                children: [
                  // Hakediş Kartı
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFE50914),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  'GÜNCEL HAKEDİŞ',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFA1A1AA), letterSpacing: 1),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF8B0000).withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.visibility, color: Color(0xFFE50914), size: 20),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          formattedTotal,
                          style: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 24),
                        Container(
                          height: 1,
                          color: const Color(0xFF3F3F46),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Taban Maaş', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA))),
                                  const SizedBox(height: 4),
                                  Text(formattedBase, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: const Color(0xFF3F3F46)),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Ek Mesai', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA))),
                                  const SizedBox(height: 4),
                                  Text('+ $formattedEkMesai', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFE50914))),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Alt Liste
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C22),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF3F3F46)),
                    ),
                    child: Column(
                      children: [
                        _buildProfileListItem(
                          icon: Icons.badge_rounded,
                          title: 'Sicil No',
                          trailingText: 'ID-104592', // Bu bir örnek ID, isterseniz widget.user.id vb kullanabilirsiniz
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFF3F3F46)),
                        _buildProfileListItem(
                          icon: Icons.domain_rounded,
                          title: 'Departman',
                          trailingText: 'Liman Operasyonları',
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFF3F3F46)),
                        _buildProfileListItem(
                          icon: Icons.calendar_month_rounded,
                          title: 'İşe Giriş Tarihi',
                          trailingText: '12.05.2021',
                        ),
                        const Divider(height: 1, indent: 64, endIndent: 20, color: Color(0xFF3F3F46)),
                        _buildProfileListItem(
                          icon: Icons.security_rounded,
                          title: 'Erişim Yetkisi',
                          trailingWidget: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B0000).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text('Standart Personel', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFFE50914))),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Çıkış Butonu
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B0000).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3)),
                      ),
                      child: Center(
                        child: Text('Hesaptan Çıkış Yap', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFFE50914))),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildProfileListItem({
    required IconData icon,
    required String title,
    String? trailingText,
    Widget? trailingWidget,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF8B0000).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFFE50914), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(title, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
          if (trailingText != null)
            Text(trailingText, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
          if (trailingWidget != null) trailingWidget,
          const SizedBox(width: 12),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFE50914), size: 20),
        ],
      ),
    );
  }
}
