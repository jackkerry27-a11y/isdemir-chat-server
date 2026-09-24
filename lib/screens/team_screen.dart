import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import '../widgets/glass_widgets.dart';
import '../utils/socket_service.dart';
import '../utils/shift_logic.dart';
import 'chat_detail_screen.dart';

class TeamScreen extends StatefulWidget {
  const TeamScreen({super.key});

  @override
  State<TeamScreen> createState() => _TeamScreenState();
}

class _TeamScreenState extends State<TeamScreen> {
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  int _statusFilter = 0; // 0: Tümü, 1: Fabrikada, 2: Dışarıda
  String _selectedVardiyaFilter = 'Tümü'; // Tümü, Salı, Çarşamba, Cuma, Cumartesi, Tatil
  int _viewMode = 0; // 0: Liste Görünümü, 1: Hiyerarşik Şema (Org Chart)
  final TransformationController _transformController = TransformationController();

  @override
  void dispose() {
    _searchController.dispose();
    _transformController.dispose();
    super.dispose();
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    String initials = '';
    int numWords = names.length > 2 ? 2 : names.length;
    for (int i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials.isEmpty ? '?' : initials;
  }

  ShiftType _getPersonnelTodayShift(String? rawVardiya) {
    final v = (rawVardiya ?? '').toLowerCase().trim();
    if (v.isEmpty || v == 'belirtilmedi' || v == 'yok') {
      return ShiftType.tatil;
    }
    VardiyaGunu gunu = VardiyaGunu.sali;
    if (v.contains('carsamba') || v.contains('çarşamba')) {
      gunu = VardiyaGunu.carsamba;
    } else if (v.contains('cuma')) {
      gunu = VardiyaGunu.cuma;
    } else if (v.contains('cumartesi')) {
      gunu = VardiyaGunu.cumartesi;
    }
    return ShiftLogic.getShiftType(DateTime.now(), vardiyaGunu: gunu);
  }

  String _getShiftLabel(ShiftType shift) {
    switch (shift) {
      case ShiftType.sabah:
        return '☀️ Gündüz (08:00 - 16:00)';
      case ShiftType.aksam:
        return '🌆 Akşam (16:00 - 24:00)';
      case ShiftType.gece:
        return '🌙 Gece (24:00 - 08:00)';
      case ShiftType.tatil:
        return '🏖️ Hafta Tatili';
    }
  }

  Map<String, dynamic> _getLiveStatusBadge(bool isGiris, String? rawVardiya) {
    if (!isGiris) {
      return {
        'label': 'Dışarıda',
        'color': const Color(0xFF64748B),
        'bg': const Color(0xFF1E2430),
        'icon': Icons.directions_walk_rounded,
        'isLive': false,
      };
    }

    final shift = _getPersonnelTodayShift(rawVardiya);
    final now = DateTime.now();
    final currentMinutes = now.hour * 60 + now.minute;

    bool isBreak = false;
    if (shift == ShiftType.sabah && currentMinutes >= 720 && currentMinutes < 750) {
      isBreak = true;
    } else if (shift == ShiftType.aksam && currentMinutes >= 1140 && currentMinutes < 1170) {
      isBreak = true;
    } else if (shift == ShiftType.gece && currentMinutes >= 180 && currentMinutes < 210) {
      isBreak = true;
    }
    if (isBreak) {
      return {
        'label': '☕ Çay Molası',
        'color': const Color(0xFFF59E0B),
        'bg': const Color(0xFFF59E0B).withValues(alpha: 0.12),
        'icon': Icons.coffee_rounded,
        'isLive': true,
      };
    }

    return {
      'label': '🟢 Sahada',
      'color': const Color(0xFF10B981),
      'bg': const Color(0xFF10B981).withValues(alpha: 0.12),
      'icon': Icons.domain_rounded,
      'isLive': true,
    };
  }

  void _showPersonnelDetail(BuildContext context, Map<String, dynamic> p, String docId) {
    HapticFeedback.mediumImpact();
    final isGiris = p['son_hareket_tipi'] == 'is_giris';
    final adSoyad = p['ad_soyad'] ?? 'İsimsiz';
    final meslek = p['meslek'] ?? 'Belirtilmedi';
    final rawVardiya = (p['vardiya'] ?? '').toString().trim();
    final bool hasVardiya = rawVardiya.isNotEmpty &&
        rawVardiya.toLowerCase() != 'belirtilmedi' &&
        rawVardiya.toLowerCase() != 'yok';
    final shift = _getPersonnelTodayShift(rawVardiya);
    final liveStatus = _getLiveStatusBadge(isGiris, rawVardiya);
    final telefon = (p['telefon'] ?? p['phone'] ?? '').toString().trim();
    final photoPath = p['photoPath'] ?? p['foto'];
    final avatarProvider = SocketService.getAvatarProvider(photoPath);

    String sonHareket = 'Hiç hareket yok';
    if (p['son_hareket_tarihi'] != null && p['son_hareket_saati'] != null) {
      sonHareket = '${p['son_hareket_saati']} (${p['son_hareket_tarihi']})';
    } else if (p['son_hareket_saati'] != null) {
      sonHareket = '${p['son_hareket_saati']}';
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF12151D),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
            border: Border.all(color: const Color(0xFF262C3D), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.7),
                blurRadius: 30,
                offset: const Offset(0, -6),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.only(top: 12, bottom: 28, left: 20, right: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Grabber
                  Container(
                    width: 44,
                    height: 4.5,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3B4354),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header row with close button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E2433),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFF334155)),
                        ),
                        child: Text(
                          'PERSONEL DETAYI',
                          style: GoogleFonts.orbitron(
                            fontSize: 9.5,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF94A3B8),
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(ctx),
                        icon: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: const BoxDecoration(
                            color: Color(0xFF222834),
                            shape: BoxShape.circle,
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            color: Colors.white70,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Profile Card
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171B26),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFF2A3347)),
                    ),
                    child: Column(
                      children: [
                        // Big Avatar
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Container(
                              width: 76,
                              height: 76,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF202638),
                                border: Border.all(
                                  color: isGiris ? const Color(0xFF10B981) : const Color(0xFF475569),
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (isGiris ? const Color(0xFF10B981) : Colors.black).withValues(alpha: 0.25),
                                    blurRadius: 14,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: ClipOval(
                                child: avatarProvider != null
                                    ? Image(image: avatarProvider, fit: BoxFit.cover)
                                    : Center(
                                        child: Text(
                                          _getInitials(adSoyad),
                                          style: GoogleFonts.inter(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w900,
                                            color: isGiris ? const Color(0xFF10B981) : Colors.white,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                            Positioned(
                              right: 2,
                              bottom: 2,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: isGiris ? const Color(0xFF10B981) : const Color(0xFF64748B),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color(0xFF12151D), width: 3),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        Text(
                          adSoyad,
                          style: GoogleFonts.inter(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meslek,
                          style: GoogleFonts.inter(
                            fontSize: 13.5,
                            color: const Color(0xFF94A3B8),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),

                        // Status Badge Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: (liveStatus['color'] as Color).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: (liveStatus['color'] as Color).withValues(alpha: 0.4),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                liveStatus['icon'] as IconData,
                                size: 14,
                                color: liveStatus['color'] as Color,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isGiris ? 'Fabrikada • ${liveStatus['label']}' : 'Dışarıda • Fabrika Dışı',
                                style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: liveStatus['color'] as Color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── 📞 HIZLI İLETİŞİM BUTONLARI (1-Tap Direct Actions) ──
                  Row(
                    children: [
                      // Ara Butonu
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.phone_in_talk_rounded,
                          label: 'Telefonla Ara',
                          color: const Color(0xFF10B981),
                          onTap: () async {
                            HapticFeedback.lightImpact();
                            if (telefon.isNotEmpty) {
                              final uri = Uri.parse('tel:$telefon');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Bu personelin kayıtlı telefon numarası bulunamadı.'),
                                  backgroundColor: Color(0xFFDC2626),
                                ),
                              );
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Sohbet Butonu
                      Expanded(
                        child: _buildActionButton(
                          icon: Icons.chat_bubble_rounded,
                          label: 'Sohbet Başlat',
                          color: const Color(0xFF38BDF8),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatDetailScreen(
                                  userId: docId,
                                  userName: adSoyad,
                                  userAvatar: photoPath,
                                  isOnline: isGiris,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // ── 📋 BENTO BİLGİ KARTLARI ──
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF171B26),
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: const Color(0xFF283042)),
                    ),
                    child: Column(
                      children: [
                        _buildInfoRow(
                          icon: Icons.calendar_today_rounded,
                          title: 'Vardiya Postası',
                          value: hasVardiya ? rawVardiya.toUpperCase() : 'SEÇİLMEDİ',
                          accentColor: hasVardiya ? const Color(0xFFA855F7) : const Color(0xFFF59E0B),
                        ),
                        const Divider(color: Color(0xFF222938), height: 22),
                        _buildInfoRow(
                          icon: Icons.access_time_filled_rounded,
                          title: 'Bugünkü Vardiya',
                          value: _getShiftLabel(shift),
                          accentColor: const Color(0xFFF59E0B),
                        ),
                        const Divider(color: Color(0xFF222938), height: 22),
                        _buildInfoRow(
                          icon: Icons.history_rounded,
                          title: 'Son Hareket / Turnike',
                          value: sonHareket,
                          accentColor: const Color(0xFF38BDF8),
                        ),
                        if (telefon.isNotEmpty) ...[
                          const Divider(color: Color(0xFF222938), height: 22),
                          _buildInfoRow(
                            icon: Icons.phone_android_rounded,
                            title: 'İletişim Numarası',
                            value: telefon,
                            accentColor: const Color(0xFF10B981),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    required Color accentColor,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: accentColor, size: 16),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: Stack(
        children: [
          // Ambient Red Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Ekip & Personel',
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Anlık personel durumu ve takibi',
                            style: GoogleFonts.inter(
                              color: const Color(0xFFA1A1AA),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C22),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFF3F3F46).withValues(alpha: 0.5)),
                        ),
                        child: const Icon(Icons.group_rounded, color: Color(0xFFE50914), size: 24),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── 🔀 GÖRÜNÜM SEÇİCİ: LİSTE vs HİYERARŞİ ŞEMASI ──
                _buildViewModeToggle(),
                const SizedBox(height: 16),
                
                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF141414),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF3F3F46).withValues(alpha: 0.3)),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: GoogleFonts.inter(color: Colors.white),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val.toLowerCase();
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Personel ara...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFFA1A1AA)),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFA1A1AA)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),

                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('personeller')
                        .where('durum', isEqualTo: 'onaylandi')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return Center(child: Text('Hata: ${snapshot.error}', style: GoogleFonts.inter(color: Colors.red)));
                      }

                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)));
                      }

                      final allDocs = snapshot.data?.docs ?? [];
                      
                      // Calculate Live Counts
                      final inFactoryCount = allDocs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>;
                        return data['son_hareket_tipi'] == 'is_giris';
                      }).length;
                      final outsideCount = allDocs.length - inFactoryCount;
                      final totalCount = allDocs.length;

                      // 1. Filter by Status Pill (Fabrikada / Dışarıda / Tümü)
                      var docs = allDocs;
                      if (_statusFilter == 1) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['son_hareket_tipi'] == 'is_giris';
                        }).toList();
                      } else if (_statusFilter == 2) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          return data['son_hareket_tipi'] != 'is_giris';
                        }).toList();
                      }

                      // 2. Filter by Vardiya Chips
                      if (_selectedVardiyaFilter != 'Tümü') {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final v = (data['vardiya'] ?? '').toString().toLowerCase();
                          if (_selectedVardiyaFilter == 'Salı') return v.contains('sali') || v.contains('salı');
                          if (_selectedVardiyaFilter == 'Çarşamba') return v.contains('carsamba') || v.contains('çarşamba');
                          if (_selectedVardiyaFilter == 'Cuma') return v.contains('cuma');
                          if (_selectedVardiyaFilter == 'Cumartesi') return v.contains('cumartesi');
                          if (_selectedVardiyaFilter == 'Tatil') {
                            return _getPersonnelTodayShift(v) == ShiftType.tatil;
                          }
                          return true;
                        }).toList();
                      }
                      
                      // 3. Filter by search query
                      if (_searchQuery.isNotEmpty) {
                        docs = docs.where((doc) {
                          final data = doc.data() as Map<String, dynamic>;
                          final adSoyad = (data['ad_soyad'] ?? '').toString().toLowerCase();
                          final meslek = (data['meslek'] ?? '').toString().toLowerCase();
                          return adSoyad.contains(_searchQuery) || meslek.contains(_searchQuery);
                        }).toList();
                      }

                      // Sort: Online users first
                      docs.sort((a, b) {
                        final dataA = a.data() as Map<String, dynamic>;
                        final dataB = b.data() as Map<String, dynamic>;
                        final isOnlineA = dataA['son_hareket_tipi'] == 'is_giris' ? 1 : 0;
                        final isOnlineB = dataB['son_hareket_tipi'] == 'is_giris' ? 1 : 0;
                        return isOnlineB.compareTo(isOnlineA);
                      });

                      // ── 🌳 HİYERARŞİK ORGANİZASYON ŞEMASI MODU ──
                      if (_viewMode == 1) {
                        return _buildOrgChartView(
                          allDocs: allDocs,
                          inFactoryCount: inFactoryCount,
                          outsideCount: outsideCount,
                          totalCount: totalCount,
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // CANLI SAHA DURUM SAYAÇLARI
                          _buildFilterPills(
                            inFactory: inFactoryCount,
                            outside: outsideCount,
                            total: totalCount,
                          ),
                          const SizedBox(height: 12),

                          // ── 🕒 3. AKILLI VARDİYA FİLTRE ÇİPLERİ ──
                          _buildVardiyaChips(),
                          const SizedBox(height: 14),

                          // LIST OR EMPTY STATE
                          Expanded(
                            child: docs.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          _statusFilter == 1
                                              ? Icons.domain_disabled_rounded
                                              : _statusFilter == 2
                                                  ? Icons.person_search_rounded
                                                  : Icons.person_off_rounded,
                                          size: 56,
                                          color: const Color(0xFF3F3F46),
                                        ),
                                        const SizedBox(height: 14),
                                        Text(
                                          _searchQuery.isNotEmpty
                                              ? 'Aramanıza uygun personel bulunamadı'
                                              : _statusFilter == 1
                                                  ? 'Şu anda fabrikada personel bulunmuyor'
                                                  : _statusFilter == 2
                                                      ? 'Şu anda dışarıda personel bulunmuyor'
                                                      : 'Filtreye uygun personel bulunamadı',
                                          style: GoogleFonts.inter(color: const Color(0xFFA1A1AA), fontSize: 14, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 4.0),
                                    physics: const BouncingScrollPhysics(),
                                    itemCount: docs.length,
                                    itemBuilder: (context, index) {
                                      final p = docs[index].data() as Map<String, dynamic>;
                                      final isGiris = p['son_hareket_tipi'] == 'is_giris';
                                      final rawVardiya = (p['vardiya'] ?? '').toString().trim();
                                      final bool hasVardiya = rawVardiya.isNotEmpty &&
                                          rawVardiya.toLowerCase() != 'belirtilmedi' &&
                                          rawVardiya.toLowerCase() != 'yok';
                                      final liveStatus = _getLiveStatusBadge(isGiris, rawVardiya);
                                      final photoPath = p['photoPath'] ?? p['foto'];
                                      final avatarProvider = SocketService.getAvatarProvider(photoPath);

                                      String sonHareket = 'Hareket yok';
                                      if (p['son_hareket_saati'] != null) {
                                        sonHareket = '${p['son_hareket_saati']}';
                                      }

                                      return BouncyTap(
                                        onTap: () => _showPersonnelDetail(context, p, docs[index].id),
                                        child: Container(
                                          margin: const EdgeInsets.only(bottom: 14),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF181B24),
                                            borderRadius: BorderRadius.circular(24),
                                            border: Border.all(
                                              color: isGiris 
                                                  ? const Color(0xFF10B981).withValues(alpha: 0.3) 
                                                  : const Color(0xFF283042),
                                              width: isGiris ? 1.2 : 1.0,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: isGiris
                                                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                                    : Colors.black.withValues(alpha: 0.2),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              // ── Avatar with 5. Canlı Nabız Göstergesi ──
                                              Stack(
                                                children: [
                                                  Container(
                                                    width: 54,
                                                    height: 54,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: const Color(0xFF222838),
                                                      border: Border.all(
                                                        color: isGiris
                                                            ? const Color(0xFF10B981)
                                                            : const Color(0xFF475569),
                                                        width: 1.8,
                                                      ),
                                                      boxShadow: isGiris
                                                          ? [
                                                              BoxShadow(
                                                                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                                                                blurRadius: 10,
                                                                spreadRadius: 1,
                                                              ),
                                                            ]
                                                          : [],
                                                    ),
                                                    child: ClipOval(
                                                      child: avatarProvider != null
                                                          ? Image(image: avatarProvider, fit: BoxFit.cover)
                                                          : Center(
                                                              child: Text(
                                                                _getInitials(p['ad_soyad'] ?? ''),
                                                                style: GoogleFonts.inter(
                                                                  fontWeight: FontWeight.bold,
                                                                  fontSize: 17,
                                                                  color: isGiris ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                                                                ),
                                                              ),
                                                            ),
                                                    ),
                                                  ),
                                                  // Status Indicator Dot (Pulsing halo)
                                                  Positioned(
                                                    right: 0,
                                                    bottom: 0,
                                                    child: Container(
                                                      width: 16,
                                                      height: 16,
                                                      decoration: BoxDecoration(
                                                        color: isGiris ? const Color(0xFF10B981) : const Color(0xFF52525B),
                                                        shape: BoxShape.circle,
                                                        border: Border.all(color: const Color(0xFF181B24), width: 2.8),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 14),
                                              
                                              // User Info
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      p['ad_soyad'] ?? 'İsimsiz',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 15.5,
                                                        fontWeight: FontWeight.bold,
                                                        color: Colors.white,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 3),
                                                    Text(
                                                      p['meslek'] ?? 'Belirtilmedi',
                                                      style: GoogleFonts.inter(
                                                        fontSize: 12.5,
                                                        color: const Color(0xFFA1A1AA),
                                                        fontWeight: FontWeight.w500,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        // Posta Çipi
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: hasVardiya ? const Color(0xFF222836) : const Color(0xFFF59E0B).withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: hasVardiya ? const Color(0xFF2E384D) : const Color(0xFFF59E0B).withValues(alpha: 0.35),
                                                              width: 0.8,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            hasVardiya ? rawVardiya.toUpperCase() : 'SEÇİLMEDİ',
                                                            style: GoogleFonts.inter(
                                                              fontSize: 9.5,
                                                              color: hasVardiya ? const Color(0xFF94A3B8) : const Color(0xFFF59E0B),
                                                              fontWeight: FontWeight.bold,
                                                            ),
                                                          ),
                                                        ),
                                                        const SizedBox(width: 6),
                                                        // ── 5. CANLI DURUM ETİKETİ ──
                                                        Container(
                                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                          decoration: BoxDecoration(
                                                            color: (liveStatus['bg'] as Color),
                                                            borderRadius: BorderRadius.circular(6),
                                                          ),
                                                          child: Text(
                                                            liveStatus['label'] as String,
                                                            style: GoogleFonts.inter(
                                                              fontSize: 9.5,
                                                              fontWeight: FontWeight.bold,
                                                              color: liveStatus['color'] as Color,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              
                                              // Live Status & Time Column
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                                    decoration: BoxDecoration(
                                                      color: isGiris 
                                                          ? const Color(0xFF10B981).withValues(alpha: 0.12) 
                                                          : const Color(0xFF2A3347).withValues(alpha: 0.4),
                                                      borderRadius: BorderRadius.circular(10),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          isGiris ? Icons.business_rounded : Icons.directions_walk_rounded, 
                                                          size: 13, 
                                                          color: isGiris ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          isGiris ? 'Fabrikada' : 'Dışarıda',
                                                          style: GoogleFonts.inter(
                                                            fontSize: 11.5,
                                                            fontWeight: FontWeight.bold,
                                                            color: isGiris ? const Color(0xFF10B981) : const Color(0xFFA1A1AA),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 7),
                                                  Row(
                                                    children: [
                                                      const Icon(Icons.schedule_rounded, size: 12, color: Color(0xFF71717A)),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        sonHareket,
                                                        style: GoogleFonts.inter(
                                                          fontSize: 11.5,
                                                          fontWeight: FontWeight.w600,
                                                          color: const Color(0xFF71717A),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 4),
                                                      const Icon(Icons.chevron_right_rounded, size: 16, color: Color(0xFF475569)),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ).animate(delay: (index * 30).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
                                    },
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                // Padding for bottom nav
                const SizedBox(height: 80),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 🕒 3. VARDİYA FİLTRE ÇİPLERİ ──
  Widget _buildVardiyaChips() {
    final chips = [
      {'id': 'Tümü', 'label': 'Tüm Postalar', 'icon': Icons.all_inclusive_rounded},
      {'id': 'Salı', 'label': 'Salı', 'icon': Icons.calendar_today_rounded},
      {'id': 'Çarşamba', 'label': 'Çarşamba', 'icon': Icons.calendar_today_rounded},
      {'id': 'Cuma', 'label': 'Cuma', 'icon': Icons.calendar_today_rounded},
      {'id': 'Cumartesi', 'label': 'Cumartesi', 'icon': Icons.calendar_today_rounded},
      {'id': 'Tatil', 'label': '🏖️ Bugün Tatil', 'icon': Icons.beach_access_rounded},
    ];

    return SizedBox(
      height: 36,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: chips.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final c = chips[index];
          final isSelected = _selectedVardiyaFilter == c['id'];
          return BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              setState(() {
                _selectedVardiyaFilter = c['id'] as String;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFE50914).withValues(alpha: 0.18) : const Color(0xFF181B24),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected ? const Color(0xFFE50914) : const Color(0xFF283042),
                  width: isSelected ? 1.3 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    c['icon'] as IconData,
                    size: 13,
                    color: isSelected ? const Color(0xFFF87171) : const Color(0xFF94A3B8),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    c['label'] as String,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterPills({
    required int inFactory,
    required int outside,
    required int total,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Row(
        children: [
          _buildPillItem(
            index: 1,
            title: 'Fabrikada',
            count: inFactory,
            icon: Icons.domain_rounded,
            activeColor: const Color(0xFF10B981),
          ),
          const SizedBox(width: 8),
          _buildPillItem(
            index: 2,
            title: 'Dışarıda',
            count: outside,
            icon: Icons.directions_walk_rounded,
            activeColor: const Color(0xFF94A3B8),
          ),
          const SizedBox(width: 8),
          _buildPillItem(
            index: 0,
            title: 'Tümü',
            count: total,
            icon: Icons.groups_rounded,
            activeColor: const Color(0xFFE50914),
          ),
        ],
      ),
    );
  }

  Widget _buildPillItem({
    required int index,
    required String title,
    required int count,
    required IconData icon,
    required Color activeColor,
  }) {
    final isSelected = _statusFilter == index;

    return Expanded(
      child: BouncyTap(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _statusFilter = index;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? activeColor.withValues(alpha: 0.16)
                : const Color(0xFF18181F),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? activeColor
                  : const Color(0xFF2E2E38),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    )
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? activeColor : const Color(0xFFA1A1AA),
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isSelected ? activeColor : const Color(0xFF27272F),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: isSelected ? Colors.black : const Color(0xFFD4D4D8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── 🔀 GÖRÜNÜM SEÇİCİ BİLEŞENİ (LİSTE & HİYERARŞİ) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildViewModeToggle() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: const Color(0xFF14161F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF262C3D), width: 1),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _viewMode = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _viewMode == 0 ? const Color(0xFFE50914) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _viewMode == 0
                        ? [
                            BoxShadow(
                              color: const Color(0xFFE50914).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.view_agenda_rounded,
                        size: 15,
                        color: _viewMode == 0 ? Colors.white : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Liste Görünümü',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: _viewMode == 0 ? FontWeight.w800 : FontWeight.w600,
                          color: _viewMode == 0 ? Colors.white : const Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _viewMode = 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: _viewMode == 1 ? const Color(0xFF38BDF8) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: _viewMode == 1
                        ? [
                            BoxShadow(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : [],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.account_tree_rounded,
                        size: 15,
                        color: _viewMode == 1 ? const Color(0xFF090B10) : const Color(0xFF94A3B8),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Hiyerarşi Şeması',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: _viewMode == 1 ? FontWeight.w900 : FontWeight.w600,
                          color: _viewMode == 1 ? const Color(0xFF090B10) : const Color(0xFF94A3B8),
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

  // ─────────────────────────────────────────────────────────
  // ── 🌳 HİYERARŞİ KADEME BELİRLEME ALGORİTMASI ──
  // ─────────────────────────────────────────────────────────
  int _getHierarchyTier(String? meslek) {
    final m = (meslek ?? '').toLowerCase().trim();
    // Kademe 1: Üst Yönetim, Müdürlük & Başmühendislik
    if (m.contains('başmühendis') ||
        m.contains('basmuhendis') ||
        m.contains('müdür') ||
        m.contains('mudur') ||
        m.contains('direktör') ||
        m.contains('direktor') ||
        m.contains('şef') ||
        m.contains('sef') ||
        m.contains('lider') ||
        m.contains('yönetici') ||
        m.contains('yonetici') ||
        m.contains('başmimar') ||
        m.contains('mühendis') ||
        m.contains('muhendis')) {
      return 1;
    }
    // Kademe 2: Vardiya Amirleri & Formenler
    if (m.contains('amir') ||
        m.contains('formen') ||
        m.contains('posta başı') ||
        m.contains('postabaşı') ||
        m.contains('postabasi') ||
        m.contains('sorumlu') ||
        m.contains('nezaret') ||
        m.contains('başçavuş') ||
        m.contains('başoperatör') ||
        m.contains('basoperator')) {
      return 2;
    }
    // Kademe 3: Ustalar, Teknisyenler & Serdümenler
    if (m.contains('usta') ||
        m.contains('teknisyen') ||
        m.contains('serdümen') ||
        m.contains('serdumen') ||
        m.contains('lashing') ||
        m.contains('uzman') ||
        m.contains('kıdemli') ||
        m.contains('kidemli') ||
        m.contains('tekniker') ||
        m.contains('formen yard')) {
      return 3;
    }
    // Kademe 4: Saha Operatörleri, İşçiler & Diğer
    return 4;
  }

  // ─────────────────────────────────────────────────────────
  // ── 🌳 ORGANİZASYON ŞEMASI (ORG CHART) ANA GÖRÜNÜMÜ ──
  // ─────────────────────────────────────────────────────────
  Widget _buildOrgChartView({
    required List<QueryDocumentSnapshot> allDocs,
    required int inFactoryCount,
    required int outsideCount,
    required int totalCount,
  }) {
    // 1. Vardiya filtresi
    var filteredDocs = allDocs;
    if (_selectedVardiyaFilter != 'Tümü') {
      filteredDocs = filteredDocs.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final v = (data['vardiya'] ?? '').toString().toLowerCase();
        if (_selectedVardiyaFilter == 'Salı') return v.contains('sali') || v.contains('salı');
        if (_selectedVardiyaFilter == 'Çarşamba') return v.contains('carsamba') || v.contains('çarşamba');
        if (_selectedVardiyaFilter == 'Cuma') return v.contains('cuma');
        if (_selectedVardiyaFilter == 'Cumartesi') return v.contains('cumartesi');
        if (_selectedVardiyaFilter == 'Tatil') {
          return _getPersonnelTodayShift(v) == ShiftType.tatil;
        }
        return true;
      }).toList();
    }

    // 2. Kademelere göre grupla
    final tier1 = filteredDocs.where((d) => _getHierarchyTier((d.data() as Map<String, dynamic>)['meslek']) == 1).toList();
    final tier2 = filteredDocs.where((d) => _getHierarchyTier((d.data() as Map<String, dynamic>)['meslek']) == 2).toList();
    final tier3 = filteredDocs.where((d) => _getHierarchyTier((d.data() as Map<String, dynamic>)['meslek']) == 3).toList();
    final tier4 = filteredDocs.where((d) => _getHierarchyTier((d.data() as Map<String, dynamic>)['meslek']) == 4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // CANLI SAHA DURUM SAYAÇLARI
        _buildFilterPills(
          inFactory: inFactoryCount,
          outside: outsideCount,
          total: totalCount,
        ),
        const SizedBox(height: 12),

        // VARDİYA FİLTRE ÇİPLERİ (Şemayı Belirli Vardiyaya Göre İnceleme)
        _buildVardiyaChips(),
        const SizedBox(height: 12),

        // İNTERAKTİF ŞEMA KANVASI
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 4.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090B10),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color(0xFF1F2433), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.6),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Stack(
                  children: [
                    // Siber Taktiksel Arka Plan Izgarası
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _CyberGridPainter(),
                      ),
                    ),

                    // İki Parmakla Yakınlaştırılabilir & Kaydırılabilir Ağaç Alanı
                    InteractiveViewer(
                      transformationController: _transformController,
                      boundaryMargin: const EdgeInsets.all(1000),
                      minScale: 0.25,
                      maxScale: 2.2,
                      constrained: false,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 140.0, vertical: 80.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // ── KADEME 1: YÖNETİM & BAŞMÜHENDİSLİK ──
                            _buildTierSection(
                              tierNumber: 1,
                              title: 'YÖNETİM & BAŞMÜHENDİSLİK',
                              subtitle: '1. Kademe // Stratejik & Operasyonel Liderlik',
                              color: const Color(0xFFF59E0B),
                              icon: Icons.workspace_premium_rounded,
                              docs: tier1,
                            ),
                            _buildTierConnector(
                              color: const Color(0xFFF59E0B),
                              nextColor: const Color(0xFF38BDF8),
                              label: 'VARDİYA YÖNETİMİ BAĞLANTISI',
                            ),

                            // ── KADEME 2: VARDİYA AMİRLERİ & FORMENLER ──
                            _buildTierSection(
                              tierNumber: 2,
                              title: 'VARDİYA AMİRLERİ & FORMENLER',
                              subtitle: '2. Kademe // Saha & Vardiya İdaresi',
                              color: const Color(0xFF38BDF8),
                              icon: Icons.shield_outlined,
                              docs: tier2,
                            ),
                            _buildTierConnector(
                              color: const Color(0xFF38BDF8),
                              nextColor: const Color(0xFF10B981),
                              label: 'TEKNİK VE OPERASYONEL BAĞLANTI',
                            ),

                            // ── KADEME 3: USTALAR, SERDÜMENLER & TEKNİSYENLER ──
                            _buildTierSection(
                              tierNumber: 3,
                              title: 'USTALAR, SERDÜMEN & TEKNİSYENLER',
                              subtitle: '3. Kademe // Teknik Uzmanlık & Saha İcrası',
                              color: const Color(0xFF10B981),
                              icon: Icons.handyman_rounded,
                              docs: tier3,
                            ),
                            _buildTierConnector(
                              color: const Color(0xFF10B981),
                              nextColor: const Color(0xFFF43F5E),
                              label: 'OPERASYON EKİBİNE BAĞLI',
                            ),

                            // ── KADEME 4: SAHA OPERATÖRLERİ & İŞÇİLER ──
                            _buildTierSection(
                              tierNumber: 4,
                              title: 'SAHA OPERATÖRLERİ & İŞÇİLER',
                              subtitle: '4. Kademe // İcra & Taşıma Operasyonu',
                              color: const Color(0xFFF43F5E),
                              icon: Icons.precision_manufacturing_rounded,
                              docs: tier4,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // HUD Kontrolleri (Reset Zoom & Pinch-to-Zoom İpucu)
                    Positioned(
                      right: 14,
                      bottom: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722).withValues(alpha: 0.92),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF283044)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.pinch_rounded, size: 13, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 5),
                                Text(
                                  'Pinch-to-Zoom',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: const Color(0xFF94A3B8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _transformController.value = Matrix4.identity();
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2434),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.5),
                                    blurRadius: 8,
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.fit_screen_rounded, size: 18, color: Color(0xFF38BDF8)),
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
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── 🌳 KADEME BÖLÜMÜ (TIER SECTION) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildTierSection({
    required int tierNumber,
    required String title,
    required String subtitle,
    required Color color,
    required IconData icon,
    required List<QueryDocumentSnapshot> docs,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Kademe Başlık Rozeti
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
          decoration: BoxDecoration(
            color: const Color(0xFF141824),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.6), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 18,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.0,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 14),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.4)),
                ),
                child: Text(
                  '${docs.length}',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),

        // Kademe İçindeki Personel Kartları (Wrap)
        if (docs.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF11141E).withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF262E42)),
            ),
            child: Text(
              'Bu kademede bu filtreye uygun personel bulunmuyor',
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: const Color(0xFF64748B),
                fontStyle: FontStyle.italic,
              ),
            ),
          )
        else
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 16,
            runSpacing: 16,
            children: docs.map((doc) {
              return _buildOrgNodeCard(context, doc, color);
            }).toList(),
          ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── 🌳 AĞAÇ DÜĞÜMÜ PERSONEL KARTI (ORG NODE CARD) ──
  // ─────────────────────────────────────────────────────────
  Widget _buildOrgNodeCard(BuildContext context, QueryDocumentSnapshot doc, Color tierColor) {
    final p = doc.data() as Map<String, dynamic>;
    final isGiris = p['son_hareket_tipi'] == 'is_giris';
    final adSoyad = p['ad_soyad'] ?? 'İsimsiz';
    final meslek = p['meslek'] ?? 'Belirtilmedi';
    final rawVardiya = (p['vardiya'] ?? '').toString().trim();
    final photoPath = p['photoPath'] ?? p['foto'];
    final avatarProvider = SocketService.getAvatarProvider(photoPath);

    final bool matchesSearch = _searchQuery.isEmpty ||
        adSoyad.toLowerCase().contains(_searchQuery) ||
        meslek.toLowerCase().contains(_searchQuery);

    return InkWell(
      onTap: () => _showPersonnelDetail(context, p, doc.id),
      borderRadius: BorderRadius.circular(20),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: matchesSearch ? 1.0 : 0.35,
        child: Container(
          width: 200,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF131722),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: matchesSearch && _searchQuery.isNotEmpty
                  ? const Color(0xFFFBBF24)
                  : tierColor.withValues(alpha: 0.35),
              width: matchesSearch && _searchQuery.isNotEmpty ? 2.0 : 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: (matchesSearch && _searchQuery.isNotEmpty ? const Color(0xFFFBBF24) : tierColor)
                    .withValues(alpha: 0.12),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Üst Canlı Durum ve Vardiya Satırı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: isGiris
                          ? const Color(0xFF10B981).withValues(alpha: 0.15)
                          : const Color(0xFF64748B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isGiris
                            ? const Color(0xFF10B981).withValues(alpha: 0.4)
                            : const Color(0xFF64748B).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isGiris ? const Color(0xFF10B981) : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isGiris ? 'Sahada' : 'Dışarıda',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                            color: isGiris ? const Color(0xFF10B981) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (rawVardiya.isNotEmpty && rawVardiya.toLowerCase() != 'yok' && rawVardiya.toLowerCase() != 'belirtilmedi')
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2436),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        rawVardiya.length > 8 ? rawVardiya.substring(0, 8) : rawVardiya,
                        style: GoogleFonts.inter(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFCBD5E1),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF1F2538),
                  border: Border.all(
                    color: isGiris ? const Color(0xFF10B981) : tierColor.withValues(alpha: 0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isGiris ? const Color(0xFF10B981) : tierColor).withValues(alpha: 0.2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: avatarProvider != null
                      ? Image(image: avatarProvider, fit: BoxFit.cover)
                      : Center(
                          child: Text(
                            _getInitials(adSoyad),
                            style: GoogleFonts.inter(
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),

              // Ad Soyad
              Text(
                adSoyad,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),

              // Meslek / Unvan Rozeti
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  meslek,
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: tierColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 8),

              // Alt Tıklama İpucu
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1F2D),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.touch_app_rounded, size: 11, color: tierColor),
                    const SizedBox(width: 4),
                    Text(
                      'İletişim & Detay',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────
  // ── 🌳 KADEMELER ARASI NEON BAĞLANTI KÖPRÜSÜ ──
  // ─────────────────────────────────────────────────────────
  Widget _buildTierConnector({
    required Color color,
    required Color nextColor,
    required String label,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 2,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [color, nextColor.withValues(alpha: 0.7)],
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          decoration: BoxDecoration(
            color: const Color(0xFF141824),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: nextColor.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.arrow_downward_rounded, size: 11, color: nextColor),
              const SizedBox(width: 5),
              Text(
                label,
                style: GoogleFonts.orbitron(
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                  color: nextColor,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 2,
          height: 18,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [nextColor.withValues(alpha: 0.7), nextColor],
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────
// ── 🌐 SİBER TAKTİKSEL IZGARA ÇİZİCİSİ ──
// ─────────────────────────────────────────────────────────
class _CyberGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF1B2234).withValues(alpha: 0.25)
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

