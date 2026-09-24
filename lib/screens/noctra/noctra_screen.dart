import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import '../../models/user_model.dart';
import '../../utils/socket_service.dart';
import 'noctra_chat_detail_screen.dart';
import 'widgets/noctra_animations.dart';

class NoctraScreen extends StatefulWidget {
  final UserModel? user;
  const NoctraScreen({super.key, this.user});

  @override
  State<NoctraScreen> createState() => _NoctraScreenState();
}

class _NoctraScreenState extends State<NoctraScreen> with SingleTickerProviderStateMixin {
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  UserModel? _currentUser;
  String? _personelDocId;
  bool _isLoading = true;

  // Noctra Durumları: 'kayitsiz', 'beklemede', 'onaylandi', 'reddedildi'
  String _noctraDurum = 'kayitsiz';
  String? _savedAlias;
  bool _isLoggedIn = false; // Şifresi girilip kasa açıldı mı?
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;
  String _selectedFilter = 'Tümü'; // 'Tümü', 'Çevrimiçi'

  // Müzik çalar (Kevin MacLeod - Korku / Gerilim)
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isPlayingMusic = false;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  List<dynamic> _onlineUsers = [];
  Map<String, Map<String, dynamic>> _lastMessages = {};
  StreamSubscription<DocumentSnapshot>? _personelSub;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _loadUserAndNoctraState();

    // Çevrimiçi kullanıcıları dinle
    _onlineUsers = SocketService().onlineUsers;
    SocketService().onOnlineUsersUpdated = (users) {
      if (mounted) {
        setState(() {
          _onlineUsers = users;
        });
      }
    };

    // Yeni mesaj gelirse son mesajları güncelle
    final prevMsgCallback = SocketService().onMessageReceived;
    SocketService().onMessageReceived = (data) {
      if (prevMsgCallback != null) prevMsgCallback(data);
      if (mounted) {
        _loadLastMessages();
      }
    };
  }

  @override
  void dispose() {
    _stopHorrorMusic();
    _audioPlayer.dispose();
    _pulseController.dispose();
    _personelSub?.cancel();
    _aliasController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Korku Müziğini Çal / Durdur ──
  Future<void> _startHorrorMusic() async {
    if (_isPlayingMusic) return;
    try {
      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      // Kevin MacLeod - Ghost Story (En popüler telifsiz korku/gerilim müziği)
      await _audioPlayer.play(
        UrlSource('https://ia800301.us.archive.org/15/items/GhostStory_201605/Ghost%20Story.mp3'),
      );
      if (mounted) {
        setState(() => _isPlayingMusic = true);
      }
    } catch (e) {
      debugPrint('Korku müziği çalınamadı (yedek deneniyor): $e');
      try {
        // Alternatif Kevin MacLeod Gerilim Stream URL
        await _audioPlayer.play(
          UrlSource('https://incompetech.com/music/royalty-free/mp3-royaltyfree/Ghost%20Story.mp3'),
        );
        if (mounted) setState(() => _isPlayingMusic = true);
      } catch (_) {}
    }
  }

  Future<void> _stopHorrorMusic() async {
    try {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() => _isPlayingMusic = false);
      }
    } catch (_) {}
  }

  // ── Kullanıcı ve Noctra Yetkisini Yükle ──
  Future<void> _loadUserAndNoctraState() async {
    UserModel? user = widget.user;
    user ??= await UserModel.load();
    _currentUser = user;

    final prefs = await SharedPreferences.getInstance();
    final cihazId = prefs.getString('cihaz_id');

    if (cihazId != null && cihazId.isNotEmpty) {
      try {
        final query = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final doc = query.docs.first;
          _personelDocId = doc.id;
          final data = doc.data();

          final durum = data['noctra_durum'] as String? ?? 'kayitsiz';
          final alias = data['noctra_alias'] as String?;

          setState(() {
            _noctraDurum = durum;
            _savedAlias = alias;
            _isLoading = false;
          });

          // Canlı onay dinleyicisi başlat
          _listenPersonelDoc(doc.id);

          if (durum == 'beklemede') {
            _startHorrorMusic();
          }
          return;
        }
      } catch (e) {
        debugPrint('Firestore Noctra kontrol hatası: $e');
      }
    }

    // Yerel kontrol (Firestore'a erişilemezse)
    final myId = user?.id ?? 'user';
    final localPassword = prefs.getString('noctra_password_$myId');
    final localAlias = prefs.getString('noctra_alias_$myId');

    setState(() {
      _savedAlias = localAlias;
      if (localPassword != null && localPassword.isNotEmpty) {
        _noctraDurum = 'beklemede';
      } else {
        _noctraDurum = 'kayitsiz';
      }
      _isLoading = false;
    });

    if (_noctraDurum == 'beklemede') {
      _startHorrorMusic();
    }
    _loadLastMessages();
  }

  // Canlı Doküman Dinleme (Admin onayladığı an otomatik algılar)
  void _listenPersonelDoc(String docId) {
    _personelSub?.cancel();
    _personelSub = FirebaseFirestore.instance
        .collection('personeller')
        .doc(docId)
        .snapshots()
        .listen((snapshot) {
      if (!snapshot.exists || !mounted) return;
      final data = snapshot.data();
      if (data == null) return;

      final newDurum = data['noctra_durum'] as String? ?? 'kayitsiz';
      final newAlias = data['noctra_alias'] as String?;

      if (newDurum != _noctraDurum || newAlias != _savedAlias) {
        setState(() {
          _noctraDurum = newDurum;
          _savedAlias = newAlias;
        });

        if (newDurum == 'onaylandi') {
          _stopHorrorMusic();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF10B981),
              content: Text('🎉 Tebrikler $_savedAlias! Noctra erişim talebiniz onaylandı.'),
            ),
          );
        } else if (newDurum == 'beklemede') {
          _startHorrorMusic();
        } else {
          _stopHorrorMusic();
        }
      }
    });
  }

  Future<void> _loadLastMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = _currentUser?.id ?? 'user';
      final keys = prefs.getKeys().where((k) => k.startsWith('noctra_last_${myId}_')).toList();
      final Map<String, Map<String, dynamic>> loaded = {};
      for (final key in keys) {
        final targetId = key.replaceFirst('noctra_last_${myId}_', '');
        final jsonStr = prefs.getString(key);
        if (jsonStr != null) {
          loaded[targetId] = Map<String, dynamic>.from(jsonDecode(jsonStr));
        }
      }
      if (mounted) {
        setState(() {
          _lastMessages = loaded;
        });
      }
    } catch (e) {
      debugPrint('Son mesajlar yüklenemedi: $e');
    }
  }

  // ── Takma Ad ve Şifre Oluşturup Admin Onayına Gönderme ──
  Future<void> _handleRegisterNoctra() async {
    final alias = _aliasController.text.trim();
    final pass = _passwordController.text.trim();
    final confirm = _confirmPasswordController.text.trim();

    if (alias.isEmpty) {
      setState(() => _errorMessage = 'Lütfen bir gizli Kod Adı / Takma Ad belirleyin.');
      return;
    }
    if (alias.length < 3) {
      setState(() => _errorMessage = 'Kod adı en az 3 karakter olmalıdır.');
      return;
    }
    if (pass.isEmpty) {
      setState(() => _errorMessage = 'Lütfen bir şifre belirleyin.');
      return;
    }
    if (pass.length < 4) {
      setState(() => _errorMessage = 'Şifre en az 4 karakter olmalıdır.');
      return;
    }
    if (pass != confirm) {
      setState(() => _errorMessage = 'Şifreler birbiriyle eşleşmiyor.');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = _currentUser?.id ?? 'user';
      final cihazId = prefs.getString('cihaz_id');

      await prefs.setString('noctra_alias_$myId', alias);
      await prefs.setString('noctra_password_$myId', pass);

      // Firestore'a kaydet
      if (_personelDocId != null) {
        await FirebaseFirestore.instance.collection('personeller').doc(_personelDocId).update({
          'noctra_alias': alias,
          'noctra_password': pass,
          'noctra_durum': 'beklemede',
          'noctra_talep_tarihi': FieldValue.serverTimestamp(),
        });
      } else if (cihazId != null) {
        final q = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (q.docs.isNotEmpty) {
          _personelDocId = q.docs.first.id;
          await q.docs.first.reference.update({
            'noctra_alias': alias,
            'noctra_password': pass,
            'noctra_durum': 'beklemede',
            'noctra_talep_tarihi': FieldValue.serverTimestamp(),
          });
          _listenPersonelDoc(_personelDocId!);
        }
      }

      setState(() {
        _savedAlias = alias;
        _noctraDurum = 'beklemede';
        _errorMessage = null;
        _isLoading = false;
      });

      _passwordController.clear();
      _confirmPasswordController.clear();

      // Korku müziğini başlat
      _startHorrorMusic();
    } catch (e) {
      setState(() {
        _errorMessage = 'Talep kaydedilemedi: $e';
        _isLoading = false;
      });
    }
  }

  // ── Onaylı Kullanıcının Şifre İle Kasayı Açması ──
  Future<void> _handleUnlockVault() async {
    final pass = _passwordController.text.trim();
    if (pass.isEmpty) {
      setState(() => _errorMessage = 'Lütfen şifrenizi girin.');
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final myId = _currentUser?.id ?? 'user';
    String? correctPassword = prefs.getString('noctra_password_$myId');

    // Firestore'dan da kontrol et
    if (_personelDocId != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('personeller').doc(_personelDocId).get();
        if (doc.exists) {
          final serverPass = doc.data()?['noctra_password'] as String?;
          if (serverPass != null) correctPassword = serverPass;
        }
      } catch (_) {}
    }

    if (pass == correctPassword) {
      setState(() {
        _isLoggedIn = true;
        _errorMessage = null;
      });
      _passwordController.clear();
      _stopHorrorMusic();
    } else {
      setState(() {
        _errorMessage = 'Hatalı şifre! Lütfen tekrar deneyin.';
      });
    }
  }

  void _lockSession() {
    setState(() {
      _isLoggedIn = false;
      _passwordController.clear();
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFF09060A),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFE50914)),
        ),
      );
    }

    // 1. Durum: Henüz Takma Ad ve Şifre Oluşturmamış
    if (_noctraDurum == 'kayitsiz') {
      return Scaffold(
        backgroundColor: const Color(0xFF09060A),
        body: SafeArea(child: _buildRegisterAliasView()),
      );
    }

    // 2. Durum: Admin Onayı Bekleniyor (Korku / Gerilim Temalı Siyah Ekran & Müzik)
    if (_noctraDurum == 'beklemede') {
      return Scaffold(
        backgroundColor: const Color(0xFF050204),
        body: SafeArea(child: _buildHorrorPendingApprovalView()),
      );
    }

    // 3. Durum: Reddedildi
    if (_noctraDurum == 'reddedildi') {
      return Scaffold(
        backgroundColor: const Color(0xFF09060A),
        body: SafeArea(child: _buildRejectedView()),
      );
    }

    // 4. Durum: Onaylandı -> Kasa Kilitli ise Şifre Giriş Ekranı, Açık ise Sohbet Listesi
    return Scaffold(
      backgroundColor: const Color(0xFF09060A),
      body: SafeArea(
        bottom: false,
        child: _isLoggedIn ? _buildChatListView() : _buildUnlockVaultView(),
      ),
    );
  }

  // =========================================================================
  // 1. EKRAN: TAKMA AD VE ŞİFRE OLUŞTURMA (İLK KAYIT)
  // =========================================================================
  Widget _buildRegisterAliasView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            'N O C T R A',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'GİZLİ İLETİŞİM PROTOKOLÜ',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              color: const Color(0xFF9E8E98),
            ),
          ),
          const SizedBox(height: 18),

          const NoctraPortalGlowWidget(size: 160),
          const SizedBox(height: 18),

          Text(
            'KOD ADI & ŞİFRE BELİRLE',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Noctra ağında gerçek adınız gizlenir. Diğer kullanıcılar sizi bu takma adla görecektir. Yönetici onayından sonra ağa erişebilirsiniz.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFC4B8C1), height: 1.4),
          ),
          const SizedBox(height: 20),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B0E11),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE50914)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE50914), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // TAKMA AD (KOD ADI) GİRİŞİ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF140E13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _aliasController,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.masks_outlined, color: Color(0xFFE50914), size: 22),
                hintText: 'Gizli Kod Adınız (Örn: Hayalet, Gölge)',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5E545C), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ŞİFRE
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF140E13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE50914), size: 20),
                hintText: 'Güvenlik Şifresi',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5E545C), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF7E727C),
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ŞİFRE TEKRAR
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF140E13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _confirmPasswordController,
              obscureText: _obscureConfirm,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF7E727C), size: 20),
                hintText: 'Şifreyi Tekrar Girin',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5E545C), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF7E727C),
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleRegisterNoctra,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: const Color(0xFFE50914).withValues(alpha: 0.5),
              ),
              child: Text(
                'TALEP GÖNDER VE KAYDET',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 2. EKRAN: KORKU & GERİLİM TEMALI SİYAH ONAY BEKLEME EKRANI (Kevin MacLeod)
  // =========================================================================
  Widget _buildHorrorPendingApprovalView() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF030103),
        gradient: RadialGradient(
          center: Alignment(0, -0.2),
          radius: 0.9,
          colors: [
            Color(0xFF26050A),
            Color(0xFF0C0305),
            Color(0xFF030103),
          ],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          children: [
            // Üst Ses Göstergesi ve Başlık
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF19060B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.graphic_eq_rounded, color: Color(0xFFE50914), size: 14),
                      const SizedBox(width: 6),
                      Text(
                        _isPlayingMusic ? 'KEVIN MACLEOD: GHOST STORY' : 'SES DURAKLATILDI',
                        style: GoogleFonts.orbitron(
                          fontSize: 8.5,
                          color: const Color(0xFFFF5252),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    _isPlayingMusic ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                    color: const Color(0xFFE50914),
                  ),
                  onPressed: () {
                    if (_isPlayingMusic) {
                      _stopHorrorMusic();
                    } else {
                      _startHorrorMusic();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 25),

            // Korku Nabız Animasyonu (Titreyen Kan Kırmızısı Gölgeli Mühür)
            AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) {
                return Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.4),
                          blurRadius: 50,
                          spreadRadius: 10,
                        ),
                        BoxShadow(
                          color: const Color(0xFF8B0000).withValues(alpha: 0.8),
                          blurRadius: 90,
                          spreadRadius: 25,
                        ),
                      ],
                      border: Border.all(color: const Color(0xFFFF1E1E), width: 3),
                      gradient: const RadialGradient(
                        colors: [Color(0xFF33050B), Color(0xFF0A0204)],
                      ),
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.remove_red_eye_outlined,
                        size: 72,
                        color: Color(0xFFE50914),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 35),

            Text(
              'G Ö L G E L E R   O D A S I',
              style: GoogleFonts.cinzelDecorative(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                letterSpacing: 4,
                color: const Color(0xFFFF3333),
                shadows: [
                  const Shadow(color: Color(0xFFE50914), blurRadius: 15),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'ERİŞİM KİLİTLENDİ • YÖNETİCİ MÜHRÜ BEKLENİYOR',
              style: GoogleFonts.orbitron(
                fontSize: 10,
                letterSpacing: 2,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF9E7B84),
              ),
            ),
            const SizedBox(height: 20),

            // Korku & Gerilim Temalı Gizemli Açıklama Kutusu
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF0F0407),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    blurRadius: 20,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.shield_outlined, color: Color(0xFFE50914), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'KOD ADINIZ:',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFB39EA5)),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _savedAlias ?? 'Bilinmiyor',
                        style: GoogleFonts.orbitron(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF330B12), thickness: 1),
                  const SizedBox(height: 12),
                  Text(
                    '“Kimliğiniz ve izleriniz mühürlendi.\nBu karanlık iletişim tüneline adım atmak için baş yöneticinin onay mührü gereklidir.\n\nDinleyin... Arka plandaki sessizlik her şeyi kaydeder.”',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.cormorantGaramond(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE2C4CB),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 25),

            // ONAY KONTROL ET BUTONU
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: () {
                  _loadUserAndNoctraState();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      backgroundColor: Color(0xFF1E070D),
                      content: Text('🔍 Yönetici onay durumu sorgulanıyor...'),
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                label: Text(
                  'ONAY DURUMUNU KONTROL ET',
                  style: GoogleFonts.outfit(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.white,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFE50914),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: const Color(0xFFE50914).withValues(alpha: 0.6),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Vazgeç / Çıkış
            TextButton(
              onPressed: () {
                _stopHorrorMusic();
                Navigator.of(context).maybePop();
              },
              child: Text(
                'Ağdan Ayrıl',
                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF8B6C74)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 3. EKRAN: ONAYLI KULLANICI İÇİN KASAYI AÇMA (SADECE ŞİFRE GİRİŞİ)
  // =========================================================================
  Widget _buildUnlockVaultView() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          Text(
            'N O C T R A',
            style: GoogleFonts.outfit(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: 6,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'PRIVATE COMMUNICATIONS',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              letterSpacing: 2,
              color: const Color(0xFF9E8E98),
            ),
          ),
          const SizedBox(height: 20),

          const NoctraPortalGlowWidget(size: 160),
          const SizedBox(height: 20),

          // Kod Adı Rozeti
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF150E13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.masks_rounded, color: Color(0xFFE50914), size: 22),
                const SizedBox(width: 10),
                Text(
                  'KOD ADI: ${_savedAlias ?? _currentUser?.fullName ?? 'Operatör'}',
                  style: GoogleFonts.orbitron(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF66).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('ONAYLI', style: TextStyle(color: Color(0xFF00FF66), fontSize: 9, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          Text(
            'KASAYI AÇ',
            style: GoogleFonts.outfit(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lütfen Noctra güvenlik şifrenizi girin.',
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFC4B8C1)),
          ),
          const SizedBox(height: 18),

          if (_errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF2B0E11),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE50914)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFE50914), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_errorMessage!, style: GoogleFonts.inter(color: Colors.white, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],

          // ŞİFRE GİRİŞİ
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: const Color(0xFF140E13),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                icon: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE50914), size: 20),
                hintText: 'Noctra Güvenlik Şifresi',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF5E545C), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: const Color(0xFF7E727C),
                    size: 18,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _handleUnlockVault,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 6,
                shadowColor: const Color(0xFFE50914).withValues(alpha: 0.5),
              ),
              child: Text(
                'KASAYI AÇ',
                style: GoogleFonts.outfit(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // =========================================================================
  // 4. EKRAN: REDDEDİLDİ BİLGİSİ
  // =========================================================================
  Widget _buildRejectedView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.block_flipped, color: Color(0xFFE50914), size: 64),
            const SizedBox(height: 16),
            Text(
              'ERİŞİM REDDEDİLDİ',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Yönetici tarafından Noctra gizli iletişim ağına katılım talebiniz reddedildi.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(color: const Color(0xFF9E8E98), fontSize: 13),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                setState(() => _noctraDurum = 'kayitsiz');
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
              child: const Text('Yeni Talep Gönder', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // =========================================================================
  // 5. EKRAN: SOHBET LİSTESİ (KİŞİLER TAKMA ADLARLA LİSTELENİR)
  // =========================================================================
  Widget _buildChatListView() {
    final myId = _currentUser?.id ?? 'user';
    final myAlias = _savedAlias ?? '';

    return Column(
      children: [
        // Üst Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.lock_rounded, color: Color(0xFFE50914), size: 22),
                onPressed: _lockSession,
                tooltip: 'Oturumu Kilitle',
              ),
              Column(
                children: [
                  Text(
                    'N O C T R A',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 5,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    'KOD ADI: $myAlias',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFE50914),
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                onPressed: () {
                  _loadLastMessages();
                  SocketService().requestShipsUpdate();
                },
                tooltip: 'Yenile',
              ),
            ],
          ),
        ),

        // Arama Çubuğu
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF150F14),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: TextField(
              controller: _searchController,
              onChanged: (_) => setState(() {}),
              style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                icon: const Icon(Icons.search_rounded, color: Color(0xFF6B6069), size: 20),
                hintText: 'Kod adı veya konuşma ara...',
                hintStyle: GoogleFonts.inter(color: const Color(0xFF6B6069), fontSize: 13),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ),

        // Filtreler
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
          child: Row(
            children: [
              _buildFilterChip('Tümü'),
              const SizedBox(width: 8),
              _buildFilterChip('Çevrimiçi'),
            ],
          ),
        ),

        // Gerçek Kullanıcılar (TAKMA ADLARLA LİSTELENİR)
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('personeller').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('Hata: ${snapshot.error}', style: const TextStyle(color: Colors.white54)));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
              }

              final docs = snapshot.data?.docs ?? [];
              final searchQuery = _searchController.text.trim().toLowerCase();

              List<Map<String, dynamic>> personList = [];
              for (var doc in docs) {
                final data = doc.data() as Map<String, dynamic>;
                final adSoyad = (data['ad_soyad'] as String? ?? '').trim();
                if (adSoyad.isEmpty) continue;

                // Takma Ad (Alias)
                final alias = (data['noctra_alias'] as String?)?.trim();
                final displayAlias = (alias != null && alias.isNotEmpty)
                    ? alias
                    : 'Gölge_${adSoyad.split(' ').first}';

                final pUserId = adSoyad.toLowerCase().replaceAll(' ', '_');
                // Kendi kullanıcımızı çıkar
                if (pUserId == myId || displayAlias.toLowerCase() == myAlias.toLowerCase()) {
                  continue;
                }

                // Çevrimiçi mi?
                final isOnline = _onlineUsers.any((u) =>
                    u['userId'] == pUserId || (u['name'] as String? ?? '').toLowerCase() == adSoyad.toLowerCase());

                // Son mesaj
                final lastData = _lastMessages[pUserId];
                final lastMsg = lastData?['content'] ?? 'Güvenli konuşma başlatın';
                final lastTime = lastData?['time'] ?? '';

                // Arama filtresi (Takma ada göre arar)
                if (searchQuery.isNotEmpty) {
                  if (!displayAlias.toLowerCase().contains(searchQuery)) {
                    continue;
                  }
                }

                if (_selectedFilter == 'Çevrimiçi' && !isOnline) {
                  continue;
                }

                personList.add({
                  'userId': pUserId,
                  'alias': displayAlias,
                  'avatar': data['foto_url'] ?? data['photoPath'],
                  'isOnline': isOnline,
                  'lastMessage': lastMsg,
                  'time': lastTime,
                });
              }

              personList.sort((a, b) {
                if (a['isOnline'] == true && b['isOnline'] != true) return -1;
                if (a['isOnline'] != true && b['isOnline'] == true) return 1;
                return (a['alias'] as String).compareTo(b['alias'] as String);
              });

              if (personList.isEmpty) {
                return Center(
                  child: Text(
                    searchQuery.isNotEmpty ? 'Eşleşen kod adı bulunamadı.' : 'Ağda başka kullanıcı bulunamadı.',
                    style: GoogleFonts.inter(color: const Color(0xFF7E737C), fontSize: 13),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: personList.length,
                itemBuilder: (context, index) {
                  final chat = personList[index];
                  return _buildAliasPersonTile(chat);
                },
              );
            },
          ),
        ),

        _buildBottomFeaturesStrip(),
      ],
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF261217) : const Color(0xFF140E13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFE50914) : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : const Color(0xFF8B8089),
          ),
        ),
      ),
    );
  }

  Widget _buildAliasPersonTile(Map<String, dynamic> chat) {
    final isOnline = chat['isOnline'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF110B10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOnline ? const Color(0xFFE50914).withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.04),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => NoctraChatDetailScreen(
                chatId: chat['userId'],
                chatName: chat['alias'], // Takma Ad başlıkta görünür
                chatAvatar: chat['avatar'],
                currentAlias: _savedAlias,
                isOnline: isOnline,
                protocolName: 'NyxChat (P2P + 1x Burn)',
              ),
            ),
          ).then((_) => _loadLastMessages());
        },
        leading: Stack(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1D141A),
                border: Border.all(
                  color: isOnline ? const Color(0xFFE50914).withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.1),
                  width: 1.5,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.masks_rounded,
                  color: isOnline ? const Color(0xFFE50914) : const Color(0xFFB5A7B3),
                  size: 24,
                ),
              ),
            ),
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF00FF66) : const Color(0xFF71717A),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF09060A), width: 1.5),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                chat['alias'],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.orbitron(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                  color: Colors.white,
                ),
              ),
            ),
            if (chat['time'] != null && (chat['time'] as String).isNotEmpty)
              Text(
                chat['time'],
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF756A72)),
              ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  chat['lastMessage'],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: chat['lastMessage'].toString().startsWith('🔥')
                        ? const Color(0xFFFF5252)
                        : const Color(0xFF867B84),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isOnline ? const Color(0xFF00FF66).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: isOnline ? const Color(0xFF00FF66) : const Color(0xFF71717A),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomFeaturesStrip() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0A070B),
        border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _footerIcon(Icons.lock_outline_rounded, 'Uçtan Uca'),
              _footerIcon(Icons.visibility_off_outlined, 'Tek Görüntüleme'),
              _footerIcon(Icons.shield_outlined, 'İz Bırakmaz'),
              _footerIcon(Icons.masks_rounded, 'Kod Adı'),
              _footerIcon(Icons.nightlight_round, 'Karanlık'),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'SAME SECRETS  •  SAFER PEOPLE  —  NOCTRA',
            style: GoogleFonts.inter(
              fontSize: 8,
              letterSpacing: 1.5,
              color: const Color(0xFF6B6069),
            ),
          ),
        ],
      ),
    );
  }

  Widget _footerIcon(IconData icon, String label) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: const Color(0xFF8B8089)),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 8, color: const Color(0xFF70666F)),
        ),
      ],
    );
  }
}
