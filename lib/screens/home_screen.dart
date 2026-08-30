import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import 'personnel_screen.dart';
import 'weather_screen.dart';
import 'yemek_screen.dart';
import '../utils/socket_service.dart';
import '../services/weather_service.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  final double totalSalary;
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final VoidCallback onSettingsTapped;
  final VoidCallback onIzinTapped;

  const HomeScreen({
    super.key,
    required this.user,
    required this.totalSalary,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.onSettingsTapped,
    required this.onIzinTapped,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _weatherTitle = '32°';
  String _weatherSubtitle = 'Payas';
  
  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted && data != null) {
      setState(() {
        _weatherTitle = '${data.temperature.round()}°';
      });
    }
    // Hava durumu ve deniz uyarı bildirimlerini kontrol et
    WeatherService.checkAndTriggerWeatherNotification();
  }

  Future<List<Map<String, dynamic>>> _getCombinedNotifications() async {
    List<Map<String, dynamic>> finalNotifications = [];
    
    try {
      final dbData = await Supabase.instance.client.from('duyurular').select().order('tarih', ascending: false);
      finalNotifications.addAll(List<Map<String, dynamic>>.from(dbData));
    } catch (e) {
      print('Duyuru error: $e');
    }
    
    final weather = await WeatherService.getCurrentWeather();
    if (weather != null) {
      if (weather.waveHeight >= 1.0) {
        finalNotifications.insert(0, {
          'baslik': '⚠️ Deniz Uyarısı',
          'icerik': 'Dalga boyu 1 metrenin üzerinde (${weather.waveHeight}m). Liman ve sahil operasyonlarında dikkatli olun.',
          'tarih': DateTime.now().toIso8601String(),
          'is_alert': true,
        });
      }
      if (weather.nextRainTime != null) {
        final timeStr = "${weather.nextRainTime!.hour.toString().padLeft(2, '0')}:00";
        finalNotifications.insert(0, {
          'baslik': '🌧️ Yağmur Uyarısı',
          'icerik': 'Saat $timeStr civarında yağmur bekleniyor. Gerekli önlemleri alınız.',
          'tarih': DateTime.now().toIso8601String(),
          'is_alert': true,
        });
      }
    }
    
    return finalNotifications;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final days = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];
    final dateStr = '${now.day} ${months[now.month]} ${now.year}, ${days[now.weekday]}';

    // Format currency
    String formatCurrency(double amount) {
      String str = amount.toStringAsFixed(2);
      str = str.replaceAll('.', ',');
      final parts = str.split(',');
      final whole = parts[0];
      final decimal = parts[1];
      
      String formattedWhole = '';
      for (int i = 0; i < whole.length; i++) {
        formattedWhole += whole[i];
        if ((whole.length - 1 - i) % 3 == 0 && i != whole.length - 1) {
          formattedWhole += '.';
        }
      }
      return '₺ $formattedWhole,$decimal';
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: RefreshIndicator(
        color: const Color(0xFF4338CA),
        onRefresh: () async {
          await _fetchWeather();
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: Stack(
            children: [
              // Mavi/Mor Header Zemin
              Container(
                height: 380, // Arka planın beyaz alana kadar uzanması için yüksekliği artırıldı
                width: double.infinity,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF2E1065), Color(0xFF4338CA), Color(0xFF3B82F6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Dekoratif dalgalar
                    Positioned(
                      top: 40, right: -60,
                      child: Container(
                        width: 250, height: 250,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.05),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 80, left: -100,
                      child: Container(
                        width: 400, height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.03),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Üst Header Verileri (İsdemir OS, Profil) - Sabit konumda
              Positioned(
                top: 0, left: 0, right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 20, left: 24, right: 24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 52, height: 52,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Center(
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Container(width: 6, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 3),
                                    Container(width: 6, height: 28, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                    const SizedBox(width: 3),
                                    Container(width: 6, height: 20, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(2))),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'isdemir OS',
                                  style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                                ),
                                Text(
                                  'Dashboard',
                                  style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            FutureBuilder(
                              future: _getCombinedNotifications(),
                              builder: (context, AsyncSnapshot<List<Map<String, dynamic>>> snapshot) {
                                final duyurular = snapshot.data ?? [];
                                final count = duyurular.length;
                                return Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    InkWell(
                                      onTap: () => _showNotifications(context, duyurular),
                                      borderRadius: BorderRadius.circular(14),
                                      child: Container(
                                        width: 44, height: 44,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(14),
                                        ),
                                        child: const Icon(Icons.notifications_none_rounded, color: Colors.white),
                                      ),
                                    ),
                                    if (count > 0)
                                      Positioned(
                                        right: 8, top: 8,
                                        child: Container(
                                          width: 8, height: 8,
                                          decoration: const BoxDecoration(
                                            color: Color(0xFFEF4444),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      )
                                  ],
                                );
                              }
                            ),
                            const SizedBox(width: 16),
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: const Color(0xFF818CF8), width: 2),
                                  ),
                                  child: CircleAvatar(
                                    radius: 26,
                                    backgroundColor: Colors.white24,
                                    backgroundImage: SocketService.getAvatarProvider(widget.user.photoPath),
                                    child: widget.user.photoPath == null ? const Icon(Icons.person, size: 28, color: Colors.white) : null,
                                  ),
                                ),
                                Positioned(
                                  right: -2, bottom: -2,
                                  child: Container(
                                    width: 18, height: 18,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: const Color(0xFF3B82F6), width: 3),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Ana İçerik
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 140), // Üst bar boşluğu
                  
                  // Karşılama Metni (Mavi arka plan üzerinde)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Günaydın, ${widget.user.firstName} 👋',
                          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: const TextStyle(fontSize: 14, color: Colors.white70, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),

                  // Kavisli Beyaz Alan
                  Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        Center(
                          child: Container(
                            width: 40, height: 4,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Hızlı Menü İkonları
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          physics: const BouncingScrollPhysics(),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildQuickAction(Icons.calendar_month_rounded, 'İzinler', const Color(0xFFE11D48), '', '', widget.onIzinTapped),
                              _buildQuickAction(Icons.people_alt_rounded, 'Personel', const Color(0xFF2563EB), '', '', () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => PersonnelScreen(user: widget.user, totalSalary: widget.totalSalary)));
                              }),
                              _buildQuickAction(Icons.restaurant_rounded, 'Yemek', const Color(0xFFD97706), 'Bugün', 'Menü', () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const YemekScreen()));
                              }),
                              _buildQuickAction(Icons.wb_sunny_rounded, 'Hava Durumu', const Color(0xFF059669), _weatherTitle, _weatherSubtitle, () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const WeatherScreen()));
                              }),
                              _buildQuickAction(Icons.settings_rounded, 'Ayarlar', const Color(0xFF6D28D9), '', 'Sistem', widget.onSettingsTapped),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Güncel Hakediş Kartı (Mavi Gradient)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24.0),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF4338CA), Color(0xFF312E81)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(color: const Color(0xFF4338CA).withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 10)),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: IntrinsicHeight(
                                child: Padding(
                                  padding: const EdgeInsets.all(24.0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Kart Başlığı
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.white.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 20),
                                              ),
                                              const SizedBox(width: 12),
                                              const Text(
                                                'Güncel Hakediş',
                                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF1E1B4B).withValues(alpha: 0.4),
                                              borderRadius: BorderRadius.circular(20),
                                            ),
                                            child: Row(
                                              children: const [
                                                Text('Bu Ay', style: TextStyle(fontSize: 12, color: Colors.white70)),
                                                SizedBox(width: 4),
                                                Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: Colors.white70),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      const Text('Bu ayki hakediş özetiniz', style: TextStyle(fontSize: 13, color: Colors.white70)),
                                      const SizedBox(height: 24),
                                      
                                      Text(
                                        formatCurrency(widget.totalSalary),
                                        style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -1),
                                      ),
                                      const SizedBox(height: 12),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        child: const Text('Net Ödenecek Tutar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                                      ),
                                      const SizedBox(height: 32),
                                      
                                      // Taban ve Mesai Alt Kısım
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E1B4B).withValues(alpha: 0.4),
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.wallet_rounded, color: Colors.white70, size: 20),
                                                  const SizedBox(width: 12),
                                                  Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      const Text('Taban', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                                      const SizedBox(height: 2),
                                                      Text('₺ ${formatCurrency(widget.user.currentJobDetails.baseSalary).replaceAll('₺ ', '')}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(width: 1, height: 30, color: Colors.white.withValues(alpha: 0.2)),
                                            Expanded(
                                              child: Padding(
                                                padding: const EdgeInsets.only(left: 16.0),
                                                child: Row(
                                                  children: [
                                                    const Icon(Icons.schedule_rounded, color: Colors.white70, size: 20),
                                                    const SizedBox(width: 12),
                                                    Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        const Text('Mesai', style: TextStyle(fontSize: 11, color: Colors.white70)),
                                                        const SizedBox(height: 2),
                                                        Text('+ ₺ ${(widget.normalMesaiGun * widget.user.currentJobDetails.normalMesaiRate + widget.bayramMesaiGun * widget.user.currentJobDetails.bayramMesaiRate).toStringAsFixed(0)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF10B981))),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showNotifications(BuildContext context, List<Map<String, dynamic>> duyurular) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Duyurular Panosu', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    )
                  ],
                ),
              ),
              const Divider(color: Color(0xFFF1F5F9)),
              Expanded(
                child: duyurular.isEmpty
                    ? const Center(child: Text('Henüz duyuru bulunmuyor.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        itemCount: duyurular.length,
                        itemBuilder: (context, index) {
                          final d = duyurular[index];
                          final isAlert = d['is_alert'] == true;
                          return Card(
                            elevation: 0,
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: BorderSide(color: isAlert ? const Color(0xFFEF4444).withValues(alpha: 0.3) : Colors.grey.shade200, width: isAlert ? 2 : 1),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isAlert ? const Color(0xFFFEF2F2) : const Color(0xFF4338CA).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(12)
                                    ),
                                    child: Icon(isAlert ? Icons.warning_amber_rounded : Icons.campaign_rounded, color: isAlert ? const Color(0xFFEF4444) : const Color(0xFF4338CA)),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(child: Text(d['baslik'] ?? '', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: isAlert ? const Color(0xFF991B1B) : const Color(0xFF1A202C)))),
                                            Text((d['tarih'] ?? '').toString().split('T').first, style: const TextStyle(fontSize: 11, color: Color(0xFFA0AEC0))),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text(d['icerik'] ?? '', style: const TextStyle(color: Color(0xFF4A5568), height: 1.4, fontSize: 13)),
                                      ],
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAction(IconData icon, String label, Color color, String subtitleHighlight, String subtitleText, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 16.0),
        child: Column(
          children: [
            Container(
              width: 76, height: 76,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4)),
                ],
              ),
              child: Icon(icon, color: color, size: 36),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
            const SizedBox(height: 2),
            if (subtitleHighlight.isNotEmpty || subtitleText.isNotEmpty)
              RichText(
                text: TextSpan(
                  children: [
                    if (subtitleHighlight.isNotEmpty)
                      TextSpan(text: '$subtitleHighlight ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color)),
                    TextSpan(text: subtitleText, style: const TextStyle(fontSize: 11, color: Color(0xFF718096))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
