import 'dart:io';
import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';

class PersonnelScreen extends StatelessWidget {
  final UserModel user;
  final double totalSalary;

  const PersonnelScreen({super.key, required this.user, required this.totalSalary});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FA), 
      appBar: AppBar(
        title: const Text('Personel Profili', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: const Color(0xFF4338CA), 
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView( // Kaydırma özelliği eklendi ama boşluklar ayarlandı
          child: Column(
            children: [
              // Üst Başlık ve Fotoğraf Alanı
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.bottomCenter,
                children: [
                  Container(
                    height: 80,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4338CA),
                      borderRadius: BorderRadius.only(
                        bottomLeft: Radius.circular(30),
                        bottomRight: Radius.circular(30),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -45,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                      ),
                      child: CircleAvatar(
                        radius: 45,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: SocketService.getAvatarProvider(user.photoPath),
                        child: user.photoPath == null ? const Icon(Icons.person, size: 50, color: Colors.grey) : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 55),
              
              // İsim, Şirket ve Unvan
              Text(
                '${user.firstName} ${user.lastName}'.toUpperCase(),
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF2D3748), letterSpacing: 0.5),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF4338CA).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF4338CA).withOpacity(0.2)),
                ),
                child: Text(
                  'Erkport A.Ş.  •  ${user.jobTitle}',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF4338CA)),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Yeni FinTech Tarzı Aydınlık Maaş Kartı
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                    border: Border.all(color: Colors.grey.shade100),
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4338CA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF4338CA), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('GÜNCEL HAKEDİŞ', style: TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '₺${totalSalary.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1A202C)),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Kart Alt Kısım Detayları (Taban ve Mesai Kırılımı)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildSalaryDetail('Taban Maaş', '₺${user.currentJobDetails.baseSalary.toStringAsFixed(0)}', Colors.grey.shade700),
                            Container(width: 1, height: 30, color: Colors.grey.shade300),
                            _buildSalaryDetail('Ek Mesai', '+ ₺${(totalSalary - user.currentJobDetails.baseSalary).toStringAsFixed(2)}', Colors.green.shade600),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Kurumsal Bilgiler Listesi (Spacer kaldırıldı, boşluk sorunu çözüldü)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildInfoRow(Icons.badge, 'Sicil No', 'ID-104592'),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildInfoRow(Icons.business, 'Departman', 'Liman Operasyonları'),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildInfoRow(Icons.calendar_month, 'İşe Giriş Tarihi', '12.05.2021'),
                      const Divider(height: 1, indent: 56, endIndent: 16),
                      _buildInfoRow(Icons.security, 'Erişim Yetkisi', 'Standart Personel'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSalaryDetail(String label, String value, Color valueColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: valueColor)),
      ],
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F7FA),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: const Color(0xFF4338CA), size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, color: Color(0xFF718096), fontWeight: FontWeight.w600)),
                Text(value, style: const TextStyle(fontSize: 13, color: Color(0xFF2D3748), fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
