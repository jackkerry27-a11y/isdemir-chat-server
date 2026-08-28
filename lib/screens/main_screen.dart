import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'dart:ui';
import 'dart:math' as math;
import 'home_screen.dart';
import 'mesai_screen.dart';
import 'settings_screen.dart';
import 'izinler_screen.dart';
import 'vardiya_screen.dart';
import 'bordro_screen.dart';
import 'gemiler_screen.dart';
import 'admin_screen.dart';
import 'vehicle_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'chat_list_screen.dart';
import 'isg_screen.dart';
import '../utils/socket_service.dart';

class MainScreen extends StatefulWidget {
  final UserModel user;
  const MainScreen({super.key, required this.user});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with WidgetsBindingObserver {
  int _currentIndex = 0;
  
  int _normalMesaiGun = 0;
  int _bayramMesaiGun = 0;
  int _ucretliIzinGun = 0;
  int _ucretsizIzinGun = 0;
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _logActivity('is_giris');
    _loadData();
    // Socket.io'ya bağlan
    SocketService().connect(
      '${widget.user.firstName}_${widget.user.lastName}'.toLowerCase().replaceAll(' ', '_'),
      '${widget.user.firstName} ${widget.user.lastName}',
      widget.user.photoPath,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    SocketService().disconnect();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _logActivity('is_giris');
    } else if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      _logActivity('is_cikis');
    }
  }

  Future<void> _logActivity(String type) async {
    if (type == 'is_giris' && _isOnline) return;
    if (type == 'is_cikis' && !_isOnline) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId == null) return;

      final personelRes = await Supabase.instance.client
          .from('personel')
          .select('id')
          .eq('cihaz_id', cihazId)
          .maybeSingle();

      if (personelRes == null || personelRes['id'] == null) return;

      final String personelId = personelRes['id'];
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      await Supabase.instance.client.from('giris_cikis_log').insert({
        'personel_id': personelId,
        'islem_tipi': type,
        'tarih': dateStr,
        'saat': timeStr,
      });

      setState(() {
        _isOnline = (type == 'is_giris');
      });
    } catch (e) {
      debugPrint('Aktiflik loglanamadı: $e');
    }
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _normalMesaiGun = prefs.getInt('normalMesaiGun') ?? 0;
      _bayramMesaiGun = prefs.getInt('bayramMesaiGun') ?? 0;
      _ucretliIzinGun = prefs.getInt('ucretliIzinGun') ?? 0;
      _ucretsizIzinGun = prefs.getInt('ucretsizIzinGun') ?? 0;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  void _updateMesai(int normal, int bayram) async {
    setState(() {
      _normalMesaiGun = normal;
      _bayramMesaiGun = bayram;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('normalMesaiGun', normal);
    await prefs.setInt('bayramMesaiGun', bayram);

    try {
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId == null) return;

      final personelRes = await Supabase.instance.client
          .from('personel')
          .select('id')
          .eq('cihaz_id', cihazId)
          .maybeSingle();

      if (personelRes == null || personelRes['id'] == null) return;

      final personelId = personelRes['id'];
      final jobDetails = widget.user.currentJobDetails;
      final brutMaas = jobDetails.baseSalary;
      final mesaiKazanci = (normal * jobDetails.normalMesaiRate) + (bayram * jobDetails.bayramMesaiRate);
      final ucretsizKesinti = _ucretsizIzinGun * jobDetails.unpaidLeaveRate;
      final guncelHakedis = brutMaas + mesaiKazanci - ucretsizKesinti;

      final dateStr = DateFormat('yyyy-MM').format(DateTime.now());

      final existing = await Supabase.instance.client
          .from('hakedis')
          .select('id')
          .eq('personel_id', personelId)
          .eq('ay', dateStr)
          .maybeSingle();

      if (existing != null) {
        await Supabase.instance.client.from('hakedis').update({
          'normal_mesai_gun': normal,
          'bayram_mesai_gun': bayram,
          'guncel_hakedis': guncelHakedis,
        }).eq('id', existing['id']);
      } else {
        await Supabase.instance.client.from('hakedis').insert({
          'personel_id': personelId,
          'ay': dateStr,
          'normal_mesai_gun': normal,
          'bayram_mesai_gun': bayram,
          'guncel_hakedis': guncelHakedis,
        });
      }
    } catch (e) {
      debugPrint('Mesai kaydedilirken hata: $e');
    }
  }

  void _updateIzin(int ucretli, int ucretsiz) {
    setState(() {
      _ucretliIzinGun = ucretli;
      _ucretsizIzinGun = ucretsiz;
    });
    SharedPreferences.getInstance().then((prefs) {
      prefs.setInt('ucretliIzinGun', ucretli);
      prefs.setInt('ucretsizIzinGun', ucretsiz);
    });
  }

  void _refreshProfile() {
    setState(() {}); // Kullanıcı profili değiştiğinde ekranı güncelle
  }

  void _openSettings() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(user: widget.user, onProfileUpdated: _refreshProfile)));
  }

  void _openIzinler() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => IzinlerScreen(
      ucretliIzinGun: _ucretliIzinGun,
      ucretsizIzinGun: _ucretsizIzinGun,
      unpaidLeaveRate: widget.user.currentJobDetails.unpaidLeaveRate,
      onIzinChanged: _updateIzin,
    )));
  }

  void _showQuickActions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (BuildContext dialogContext) {
        return _QuickActionsSheet(
          parentContext: context,
          user: widget.user,
          normalMesaiGun: _normalMesaiGun,
          bayramMesaiGun: _bayramMesaiGun,
          ucretsizIzinGun: _ucretsizIzinGun,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final jobDetails = widget.user.currentJobDetails;
    double totalSalary = jobDetails.baseSalary 
        + (_normalMesaiGun * jobDetails.normalMesaiRate) 
        + (_bayramMesaiGun * jobDetails.bayramMesaiRate)
        - (_ucretsizIzinGun * jobDetails.unpaidLeaveRate);

    final List<Widget> pages = [
      HomeScreen(
        user: widget.user,
        totalSalary: totalSalary,
        normalMesaiGun: _normalMesaiGun,
        bayramMesaiGun: _bayramMesaiGun,
        onSettingsTapped: _openSettings,
        onIzinTapped: _openIzinler,
      ),
      const VardiyaScreen(),
      MesaiScreen(
        normalMesaiGun: _normalMesaiGun,
        bayramMesaiGun: _bayramMesaiGun,
        normalMesaiRate: jobDetails.normalMesaiRate,
        bayramMesaiRate: jobDetails.bayramMesaiRate,
        onMesaiChanged: _updateMesai,
      ),
      SettingsScreen(user: widget.user, onProfileUpdated: _refreshProfile), // Profil (Settings)
    ];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: IndexedStack(
        index: _currentIndex,
        children: pages,
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF4338CA).withValues(alpha: 0.3),
              blurRadius: 15,
              spreadRadius: 2,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: _showQuickActions,
          backgroundColor: const Color(0xFF4338CA),
          shape: const CircleBorder(),
          elevation: 0,
          child: const Icon(Icons.menu_rounded, color: Colors.white, size: 30),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: BottomAppBar(
        clipBehavior: Clip.antiAlias,
        shape: const AutomaticNotchedShape(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
          ),
          CircleBorder(),
        ),
        notchMargin: 10.0,
        color: Colors.white,
        elevation: 20,
        shadowColor: Colors.black.withValues(alpha: 0.5),
        child: Padding(
          padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(Icons.home_rounded, 'Anasayfa', 0),
              _buildNavItem(Icons.calendar_month_rounded, 'Vardiya', 1),
              const SizedBox(width: 40), // Boşluk (FAB için)
              _buildNavItem(Icons.history_rounded, 'Mesai İşlemleri', 2),
              _buildNavItem(Icons.person_outline_rounded, 'Profil', 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF4338CA) : const Color(0xFF718096);
    final bgColor = isSelected ? const Color(0xFF4338CA).withValues(alpha: 0.1) : const Color(0xFFF3F4F6);
    
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: color,
            ),
          ),
          if (isSelected) ...[
            const SizedBox(height: 3),
            Container(width: 4, height: 4, decoration: const BoxDecoration(color: Color(0xFF4338CA), shape: BoxShape.circle)),
          ] else ...[
            const SizedBox(height: 7),
          ]
        ],
      ),
    );
  }
}

class _QuickActionsSheet extends StatelessWidget {
  final BuildContext parentContext;
  final UserModel user;
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final int ucretsizIzinGun;

  const _QuickActionsSheet({
    required this.parentContext,
    required this.user,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.ucretsizIzinGun,
  });

  void _handleNotImplemented(BuildContext context, String moduleName) {
    Navigator.pop(context);
    ScaffoldMessenger.of(parentContext).showSnackBar(
      SnackBar(content: Text('$moduleName modülü yakında eklenecek!')),
    );
  }

  void _showAdminPasswordDialog(BuildContext context) {
    Navigator.pop(context);
    
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Admin Girişi', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF4338CA))),
          content: TextField(
            controller: passwordController,
            obscureText: true,
            decoration: InputDecoration(
              labelText: 'Şifre (Geçici şifre: 123456)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              prefixIcon: const Icon(Icons.lock_rounded, color: Color(0xFF4338CA)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('İptal', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
              onPressed: () {
                if (passwordController.text == '4896281aa') { 
                  Navigator.pop(ctx);
                  Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const AdminScreen()));
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Hatalı şifre!'), backgroundColor: Colors.red),
                  );
                }
              },
              child: const Text('Giriş Yap'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 12, bottom: 32),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          
          // Başlık
          const Text(
            'Hızlı İşlemler',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sık kullandığınız modüllere hızlı erişim sağlayın.',
            style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
          ),
          
          const SizedBox(height: 32),
          
          // İlk Satır (Ekip, Gemiler, Bordro)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickActionItem(
                icon: Icons.local_shipping_rounded,
                title: 'Araçlar',
                subtitle: 'Giriş/Çıkış',
                color: const Color(0xFF10B981), // Yeşil
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const VehicleScreen()));
                },
              ),
              _QuickActionItem(
                icon: Icons.directions_boat_rounded,
                title: 'Gemiler',
                subtitle: 'Liman trafiği',
                color: const Color(0xFF0EA5E9), // Mavi
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const GemilerScreen()));
                },
              ),
              _QuickActionItem(
                icon: Icons.receipt_long_rounded,
                title: 'Bordro',
                subtitle: 'Maaş & bordro',
                color: const Color(0xFF64748B), // Gri
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(parentContext, MaterialPageRoute(builder: (_) => BordroScreen(
                    user: user,
                    normalMesaiGun: normalMesaiGun,
                    bayramMesaiGun: bayramMesaiGun,
                    ucretsizIzinGun: ucretsizIzinGun,
                  )));
                },
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // İkinci Satır (Admin, [Boşluk], İSG)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _QuickActionItem(
                icon: Icons.shield_rounded,
                title: 'Admin Paneli',
                subtitle: 'Yönetim paneli',
                color: const Color(0xFF6366F1), // İndigo/Mor
                onTap: () => _showAdminPasswordDialog(context),
              ),
              
              // Merkezdeki X butonu (Kapatma)
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                  ),
                  child: Center(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF4338CA),
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 28),
                    ),
                  ),
                ),
              ),
              
              _QuickActionItem(
                icon: Icons.health_and_safety_rounded,
                title: 'İSG',
                subtitle: 'İş güvenliği',
                color: const Color(0xFFEF4444), // Kırmızı
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const IsgScreen()));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickActionItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _QuickActionItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 100, // Fixed width for uniform wrapping
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color.withValues(alpha: 0.1),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B7280),
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
