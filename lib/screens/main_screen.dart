import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../widgets/glass_widgets.dart';
import 'home_screen.dart';
import 'mesai_screen.dart';
import 'settings_screen.dart';
import 'izinler_screen.dart';
import 'vardiya_screen.dart';
import 'bordro_screen.dart';
import 'gemiler_screen.dart';
import '../widgets/vip_gate.dart';
import 'admin_screen.dart';
import 'vehicle_screen.dart';
import 'team_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'isg_screen.dart';
import 'telsiz_screen.dart';
import 'yetkili_screen.dart';
import '../utils/socket_service.dart';
import '../utils/app_config.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';

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

      final querySnapshot = await FirebaseFirestore.instance
          .collection('personeller')
          .where('cihaz_id', isEqualTo: cihazId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final String personelId = querySnapshot.docs.first.id;
      final now = DateTime.now();
      final dateStr = DateFormat('yyyy-MM-dd').format(now);
      final timeStr = DateFormat('HH:mm:ss').format(now);

      double? lat;
      double? lng;
      
      try {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
          LocationPermission permission = await Geolocator.checkPermission();
          if (permission == LocationPermission.denied) {
            permission = await Geolocator.requestPermission();
          }
          if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
            Position position = await Geolocator.getCurrentPosition(
              locationSettings: const LocationSettings(accuracy: LocationAccuracy.high)
            );
            lat = position.latitude;
            lng = position.longitude;
          }
        }
      } catch(e) {
        debugPrint('Konum alinamadi: $e');
      }

      final Map<String, dynamic> logData = {
        'islem_tipi': type,
        'tarih': dateStr,
        'saat': timeStr,
      };

      if (lat != null && lng != null) {
        logData['latitude'] = lat;
        logData['longitude'] = lng;
      }

      await FirebaseFirestore.instance.collection('personeller').doc(personelId).collection('giris_cikis_log').add(logData);

      final Map<String, dynamic> updateData = {
        'son_hareket_tipi': type,
        'son_hareket_tarihi': dateStr,
        'son_hareket_saati': timeStr,
        'app_version': '${AppConfig.currentVersion}.0',
        'app_version_num': AppConfig.currentVersion,
        'son_aktiflik_tam': FieldValue.serverTimestamp(),
        'guncelleme_tarihi_str': '$dateStr $timeStr',
      };

      if (lat != null && lng != null) {
        updateData['son_hareket_latitude'] = lat;
        updateData['son_hareket_longitude'] = lng;
      }

      await FirebaseFirestore.instance.collection('personeller').doc(personelId).update(updateData);

      // Bildirim isteği üzerine iptal edildi
      // final adSoyad = querySnapshot.docs.first.data()['ad_soyad'] as String? ?? 'Bir personel';
      // final islemText = type == 'is_giris' ? 'Giriş Yaptı' : 'Çıkış Yaptı';
      // try {
      //   await PushService.sendPushNotification(
      //     title: 'Personel Hareketi',
      //     content: '$adSoyad $islemText',
      //   );
      // } catch (e) {
      //   debugPrint('Push gönderilemedi: $e');
      // }

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
    HapticFeedback.selectionClick();
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

      final querySnapshot = await FirebaseFirestore.instance
          .collection('personeller')
          .where('cihaz_id', isEqualTo: cihazId)
          .limit(1)
          .get();

      if (querySnapshot.docs.isEmpty) return;

      final personelId = querySnapshot.docs.first.id;
      final jobDetails = widget.user.currentJobDetails;
      final brutMaas = jobDetails.baseSalary;
      final mesaiKazanci = (normal * jobDetails.normalMesaiRate) + (bayram * jobDetails.bayramMesaiRate);
      final ucretsizKesinti = _ucretsizIzinGun * jobDetails.unpaidLeaveRate;
      final guncelHakedis = brutMaas + mesaiKazanci - ucretsizKesinti;

      final dateStr = DateFormat('yyyy-MM').format(DateTime.now());

      final hakedisQuery = await FirebaseFirestore.instance
          .collection('personeller').doc(personelId).collection('hakedis')
          .where('ay', isEqualTo: dateStr)
          .limit(1)
          .get();

      if (hakedisQuery.docs.isNotEmpty) {
        await hakedisQuery.docs.first.reference.update({
          'normal_mesai_gun': normal,
          'bayram_mesai_gun': bayram,
          'guncel_hakedis': guncelHakedis,
        });
      } else {
        await FirebaseFirestore.instance.collection('personeller').doc(personelId).collection('hakedis').add({
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
    setState(() {}); 
  }

  void _openSettings() {
    final jobDetails = widget.user.currentJobDetails;
    double totalSalary = jobDetails.baseSalary 
        + (_normalMesaiGun * jobDetails.normalMesaiRate) 
        + (_bayramMesaiGun * jobDetails.bayramMesaiRate)
        - (_ucretsizIzinGun * jobDetails.unpaidLeaveRate);
        
    Navigator.push(context, MaterialPageRoute(builder: (_) => SettingsScreen(
        user: widget.user, 
        onProfileUpdated: _refreshProfile,
        totalSalary: totalSalary,
        baseSalary: jobDetails.baseSalary.toDouble(),
        ekMesai: ((_normalMesaiGun * jobDetails.normalMesaiRate) + (_bayramMesaiGun * jobDetails.bayramMesaiRate)).toDouble(),
      )));
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
    HapticFeedback.mediumImpact();
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
      VardiyaScreen(
        onBackToHome: () => _onItemTapped(0),
      ),
      MesaiScreen(
        normalMesaiGun: _normalMesaiGun,
        bayramMesaiGun: _bayramMesaiGun,
        normalMesaiRate: jobDetails.normalMesaiRate,
        bayramMesaiRate: jobDetails.bayramMesaiRate,
        onMesaiChanged: _updateMesai,
        onBackToHome: () => _onItemTapped(0),
        user: widget.user,
      ),
      const TeamScreen(),
    ];

    return Theme(
      data: Theme.of(context).copyWith(
        textTheme: GoogleFonts.interTextTheme(Theme.of(context).textTheme),
      ),
      child: PopScope(
        canPop: _currentIndex == 0,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          if (_currentIndex != 0) {
            _onItemTapped(0);
          }
        },
        child: Scaffold(
          backgroundColor: const Color(0xFF0C0E12),
        extendBody: true,
        body: AmbientAuroraBackground(
          child: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
        ),
        floatingActionButton: SizedBox(
          width: 72,
          height: 72,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer concentric ring
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE50914).withValues(alpha: 0.1),
                ),
              ),
              // Inner concentric ring
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE50914).withValues(alpha: 0.2),
                ),
              ),
              // Main FAB with BouncyTap
              BouncyTap(
                onTap: _showQuickActions,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFF990000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.6),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Center(
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedAdd01,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
        bottomNavigationBar: Theme(
          data: ThemeData(splashColor: Colors.transparent, highlightColor: Colors.transparent),
          child: Container(
            margin: const EdgeInsets.only(left: 16.0, right: 16.0, bottom: 20.0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(32),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.45),
                  blurRadius: 25,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(32),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF14171F).withValues(alpha: 0.78),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                      width: 1.2,
                    ),
                  ),
                  child: BottomAppBar(
                    color: Colors.transparent,
                    shape: const CircularNotchedRectangle(),
                    notchMargin: 10,
                    padding: EdgeInsets.zero,
                    height: 76,
                    elevation: 0,
                    clipBehavior: Clip.antiAlias,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Expanded(child: Center(child: _buildNavItem(HugeIcons.strokeRoundedHome01, 'Ana Sayfa', 0))),
                        Expanded(child: Center(child: _buildNavItem(HugeIcons.strokeRoundedCalendar01, 'Vardiya', 1))),
                        const SizedBox(width: 72), // FAB notch
                        Expanded(child: Center(child: _buildNavItem(HugeIcons.strokeRoundedClock01, 'Mesai', 2))),
                        Expanded(child: Center(child: _buildNavItem(HugeIcons.strokeRoundedUserGroup, 'Ekip', 3))),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
  Widget _buildNavItem(List<List<dynamic>> icon, String label, int index) {
    final isSelected = _currentIndex == index;
    
    return BouncyTap(
      onTap: () => _onItemTapped(index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.15) : Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: isSelected ? Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4), width: 1) : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFFE50914).withValues(alpha: 0.3),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: icon,
                  color: isSelected ? const Color(0xFFE50914) : const Color(0xFFA1A1AA),
                  size: 23,
                ),
                if (isSelected) const SizedBox(height: 3),
                if (isSelected) 
                  Text(
                    label,
                    maxLines: 1,
                    softWrap: false,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE50914),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          // Dot indicator
          Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
              boxShadow: isSelected
                  ? [
                      const BoxShadow(
                        color: Color(0xFFE50914),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ]
                  : null,
            ),
          ),
          if (!isSelected)
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFA1A1AA),
              ),
            ),
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

  void _showAdminPasswordDialog(BuildContext context) {
    Navigator.pop(context);
    
    final TextEditingController passwordController = TextEditingController();
    bool obscureText = true;
    
    showDialog(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C30), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE50914).withValues(alpha: 0.05),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE50914).withValues(alpha: 0.1),
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFE50914).withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFE50914).withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFFE50914), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: const [
                          TextSpan(text: 'Admin ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Girişi', style: TextStyle(color: Color(0xFFE50914))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Yönetim paneline erişmek için şifrenizi girin.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFA1A1AA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: passwordController,
                      obscureText: obscureText,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Şifre',
                        hintStyle: const TextStyle(color: Color(0xFF71717A)),
                        filled: true,
                        fillColor: const Color(0xFF141416),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2C2C30)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFE50914)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE50914)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF71717A),
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF2C2C30), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.shield_rounded, color: const Color(0xFF3F3F46), size: 16),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF2C2C30), thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF2C2C30)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: const Color(0xFFA1A1AA),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('İptal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
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
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  
  void _checkAndOpenGemiler(BuildContext context) async {
    Navigator.pop(context);

    if (user.isVip) {
      Navigator.push(parentContext, MaterialPageRoute(builder: (_) => GemilerScreen(user: user)));
      return;
    }

    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );

    final isAuthorized = await VipGate.checkVipStatus(user: user);

    if (parentContext.mounted) {
      Navigator.pop(parentContext);
    }

    if (!parentContext.mounted) return;

    if (!isAuthorized) {
      VipGate.showAccessDeniedDialog(
        parentContext,
        user: user,
        onGranted: () {
          if (parentContext.mounted) {
            Navigator.push(parentContext, MaterialPageRoute(builder: (_) => GemilerScreen(user: user)));
          }
        },
      );
      return;
    }

    Navigator.push(
      parentContext,
      MaterialPageRoute(builder: (_) => GemilerScreen(user: user)),
    );
  }

  void _checkAndOpenTelsiz(BuildContext context) async {
    Navigator.pop(context);

    if (user.isVip) {
      Navigator.push(parentContext, MaterialPageRoute(builder: (_) => TelsizScreen(user: user)));
      return;
    }

    // Hızlı VIP izin kontrolü göstergesi
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
      ),
    );

    final isAuthorized = await VipGate.checkVipStatus(user: user);

    if (parentContext.mounted) {
      Navigator.pop(parentContext);
    }

    if (!parentContext.mounted) return;

    if (!isAuthorized) {
      VipGate.showAccessDeniedDialog(
        parentContext,
        user: user,
        onGranted: () {
          if (parentContext.mounted) {
            Navigator.push(parentContext, MaterialPageRoute(builder: (_) => TelsizScreen(user: user)));
          }
        },
      );
      return;
    }

    if (parentContext.mounted) {
      Navigator.push(
        parentContext,
        MaterialPageRoute(builder: (_) => TelsizScreen(user: user)),
      );
    }
  }

  void _checkAndOpenYetkili(BuildContext context) async {
    Navigator.pop(context);

    if (user.isYetkili) {
      Navigator.push(
        parentContext,
        MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: user)),
      );
      return;
    }

    // Hızlı canlı yetki kontrolü
    showDialog(
      context: parentContext,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFDC2626)),
      ),
    );

    bool liveIsYetkili = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null) {
        final query = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (query.docs.isNotEmpty) {
          final data = query.docs.first.data();
          if (data['is_yetkili'] == true || data['yetkili'] == true) {
            liveIsYetkili = true;
            user.isYetkili = true;
            await user.save();
          }
        }
      }
    } catch (_) {}

    if (parentContext.mounted) {
      Navigator.pop(parentContext);
    }

    if (!parentContext.mounted) return;

    if (liveIsYetkili) {
      Navigator.push(
        parentContext,
        MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: user)),
      );
      return;
    }

    _showYetkiliPasswordDialog();
  }

  void _showYetkiliPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    bool obscureText = true;

    showDialog(
      context: parentContext,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF2C2C30), width: 1),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFDC2626).withValues(alpha: 0.05),
                          ),
                        ),
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          ),
                        ),
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 24),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                        children: const [
                          TextSpan(text: 'Yetkili ', style: TextStyle(color: Colors.white)),
                          TextSpan(text: 'Girişi', style: TextStyle(color: Color(0xFFDC2626))),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Operasyon ve Yetkili merkezine erişmek için Admin onayınız olmalı veya Master PIN girmelisiniz.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: const Color(0xFFA1A1AA),
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: passwordController,
                      obscureText: obscureText,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Yetkili Şifresi / Master PIN',
                        hintStyle: const TextStyle(color: Color(0xFF71717A)),
                        filled: true,
                        fillColor: const Color(0xFF141416),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFF2C2C30)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: Color(0xFFDC2626)),
                        ),
                        prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFDC2626)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                            color: const Color(0xFF71717A),
                          ),
                          onPressed: () {
                            setState(() {
                              obscureText = !obscureText;
                            });
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        const Expanded(child: Divider(color: Color(0xFF2C2C30), thickness: 1)),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Icon(Icons.shield_rounded, color: const Color(0xFF3F3F46), size: 16),
                        ),
                        const Expanded(child: Divider(color: Color(0xFF2C2C30), thickness: 1)),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              side: const BorderSide(color: Color(0xFF2C2C30)),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              foregroundColor: const Color(0xFFA1A1AA),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('İptal', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              backgroundColor: const Color(0xFFDC2626),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              elevation: 0,
                            ),
                            onPressed: () {
                              if (passwordController.text == '4896281aa') {
                                Navigator.pop(ctx);
                                Navigator.push(
                                  parentContext,
                                  MaterialPageRoute(builder: (_) => YetkiliScreen(currentUser: user)),
                                );
                              } else {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  const SnackBar(content: Text('Hatalı yetkili şifresi!'), backgroundColor: Colors.red),
                                );
                              }
                            },
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Text('Giriş Yap', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                                SizedBox(width: 8),
                                Icon(Icons.arrow_forward_rounded, size: 18),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF161922),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: const Color(0xFF2E3544), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.6),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 24, left: 16, right: 16),
            child: Column(
                     children: [
                // ── Grabber ──
                Container(
                  width: 44,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: const Color(0xFF384050),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 16),
                
                // ── Header: iOS 18 Control Center Stili ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.4)),
                              ),
                              child: Text(
                                'CONTROL CENTER',
                                style: GoogleFonts.orbitron(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.bold,
                                  color: const Color(0xFFF87171),
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'İSDEMİR OS',
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          'Hızlı İşlemler',
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFF222834),
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFF333D50), width: 1),
                        ),
                        child: const HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          color: Colors.white70,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ).animate().fadeIn(duration: 200.ms).slideY(begin: -0.08, end: 0, curve: Curves.easeOut),
                
                const SizedBox(height: 18),
                
                // ── 🛡️ HERO BENTO KART: Yetkili Operasyon Merkezi (iOS 18 Spotlight Tile) ──
                BouncyTap(
                  onTap: () => _checkAndOpenYetkili(context),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [
                          Color(0xFF241216),
                          Color(0xFF161A24),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.45),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFEF4444).withValues(alpha: 0.55),
                              width: 1.2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFEF4444).withValues(alpha: 0.25),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: HugeIcon(
                              icon: HugeIcons.strokeRoundedShieldUser,
                              color: Color(0xFFEF4444),
                              size: 24,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Yetkili Operasyon Konsolu',
                                    style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10131B),
                                      borderRadius: BorderRadius.circular(6),
                                      border: Border.all(
                                        color: const Color(0xFFEF4444),
                                        width: 0.9,
                                      ),
                                    ),
                                    child: Text(
                                      user.isYetkili ? 'VIP YETKİLİ' : '🔒 KİLİTLİ',
                                      style: GoogleFonts.orbitron(
                                        color: const Color(0xFFFCA5A5),
                                        fontSize: 8,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Personel maaşları, canlı vardiya & onaylar',
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: const Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Color(0xFFEF4444),
                            size: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ).animate(delay: 40.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.96, 0.96), curve: Curves.easeOutBack),
                
                const SizedBox(height: 14),
                
                // ── 🍱 2-COLUMN BENTO GRID: 1. Satır (Telsiz & Gemiler) ──
                Row(
                  children: [
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedRadio01,
                        title: 'Telsiz',
                        subtitle: 'Canlı Bas-Konuş',
                        accentColor: const Color(0xFF10B981),
                        badge: user.isVip ? 'VIP' : '🔒 VIP',
                        isLiveGlow: true,
                        onTap: () => _checkAndOpenTelsiz(context),
                      ).animate(delay: 80.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedCargoShip,
                        title: 'Gemiler',
                        subtitle: 'Liman Trafiği',
                        accentColor: const Color(0xFF38BDF8),
                        badge: user.isVip ? 'VIP' : '🔒 VIP',
                        onTap: () => _checkAndOpenGemiler(context),
                      ).animate(delay: 110.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // ── 🍱 2-COLUMN BENTO GRID: 2. Satır (Araçlar & Bordro) ──
                Row(
                  children: [
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedContainerTruck01,
                        title: 'Araçlar',
                        subtitle: 'Giriş / Çıkış',
                        accentColor: const Color(0xFFF97316),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const VehicleScreen()));
                        },
                      ).animate(delay: 140.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedInvoice01,
                        title: 'Bordro',
                        subtitle: 'Maaş & Mesai',
                        accentColor: const Color(0xFFFBBF24),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(parentContext, MaterialPageRoute(builder: (_) => BordroScreen(
                            user: user,
                            normalMesaiGun: normalMesaiGun,
                            bayramMesaiGun: bayramMesaiGun,
                            ucretsizIzinGun: ucretsizIzinGun,
                          )));
                        },
                      ).animate(delay: 170.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                  ],
                ),
                
                const SizedBox(height: 12),
                
                // ── 🍱 2-COLUMN BENTO GRID: 3. Satır (Admin Paneli & İSG) ──
                Row(
                  children: [
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedShield01,
                        title: 'Admin Paneli',
                        subtitle: 'Yönetim Konsolu',
                        accentColor: const Color(0xFFDC2626),
                        onTap: () => _showAdminPasswordDialog(context),
                      ).animate(delay: 200.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _BentoControlTile(
                        hugeIcon: HugeIcons.strokeRoundedHealth,
                        title: 'İSG',
                        subtitle: 'İş & Saha Güvenliği',
                        accentColor: const Color(0xFFEC4899),
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(parentContext, MaterialPageRoute(builder: (_) => const IsgScreen()));
                        },
                      ).animate(delay: 230.ms).fadeIn(duration: 250.ms).scale(begin: const Offset(0.94, 0.94), curve: Curves.easeOutBack),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── 📱 APPLE iOS 18 BENTO CONTROL TILE WIDGET ──
class _BentoControlTile extends StatelessWidget {
  final List<List<dynamic>> hugeIcon;
  final String title;
  final String subtitle;
  final Color accentColor;
  final VoidCallback onTap;
  final String? badge;
  final bool isLiveGlow;

  const _BentoControlTile({
    required this.hugeIcon,
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.onTap,
    this.badge,
    this.isLiveGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 78,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF161A24),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isLiveGlow
                ? accentColor.withValues(alpha: 0.55)
                : const Color(0xFF283042),
            width: isLiveGlow ? 1.4 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: accentColor.withValues(alpha: isLiveGlow ? 0.18 : 0.04),
              blurRadius: isLiveGlow ? 12 : 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // iOS Squircle Icon Box
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(
                  color: accentColor.withValues(alpha: 0.35),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.15),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Center(
                child: HugeIcon(
                  icon: hugeIcon,
                  color: accentColor,
                  size: 23,
                ),
              ),
            ),
            const SizedBox(width: 11),
            // Title & Status
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (badge != null)
                        Container(
                          margin: const EdgeInsets.only(left: 3),
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10131B),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.4),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            badge!,
                            style: GoogleFonts.orbitron(
                              fontSize: 7.5,
                              fontWeight: FontWeight.bold,
                              color: accentColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      color: isLiveGlow ? accentColor : const Color(0xFF94A3B8),
                      fontWeight: isLiveGlow ? FontWeight.w600 : FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
