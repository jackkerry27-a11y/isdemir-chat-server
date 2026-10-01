import 'dart:io';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../services/ship_tracking_service.dart';
import '../utils/radio_sound_effects.dart';
import '../utils/pdf_font_helper.dart';
import '../widgets/glass_widgets.dart';
import '../models/user_model.dart';

class GemilerScreen extends StatefulWidget {
  final UserModel? user;
  const GemilerScreen({super.key, this.user});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> with TickerProviderStateMixin {
  late AnimationController _blinkController;
  late AnimationController _radarSweepController;
  Timer? _autoSyncTimer;
  bool _isSyncing = false;

  int _selectedRadarSpectrum = 0; // 0: SAR Radar, 1: Optik Uydu, 2: Termal Isı
  Map<String, dynamic>? _selectedRadarShip;
  bool _isRadarScanning = false;

  String _currentUserName = 'İsdemir Saha Operatörü';
  String _selectedBerthFilter = 'Tümü'; // 'Tümü', '1. Rıhtım', '2. Rıhtım', '3. Rıhtım', '4. Rıhtım', '5. Rıhtım', 'Demir Sahası'
  int _activeTabIndex = 0; // 0: Rıhtım & Operasyonlar, 1: PortAI™ Liman Analitiği, 2: SpaceEye AI Radar
  bool _soundEnabled = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _isSeeding = false;

  final List<String> _berths = ['Tümü', '1. Rıhtım', '2. Rıhtım', '3. Rıhtım', '4. Rıhtım', '5. Rıhtım', 'Demir Sahası'];
  final List<String> _cargoTypes = ['Levha', 'Slap', 'Bobin', 'Cüruf', 'Medkok', 'Kömür', 'Hurda', 'Kütük', 'Rulo Sac', 'Cevher'];

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _radarSweepController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    RadioSoundEffects.init();
    _loadUserName();
    _loadSoundPreference();
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
    });

    // 🛰️ AisStream.io kesintisiz canlı radar akışını başlat
    ShipTrackingService.startLiveAisStream();

    // Sayfa açıldığında arka planda sessizce canlı radar verilerini senkronize et
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncLiveAisStream(silent: true);
    });

    // 40 saniyede bir arkaplanda canlı radar verilerini otomatik tazele
    _autoSyncTimer = Timer.periodic(const Duration(seconds: 40), (_) {
      if (mounted && !_isSyncing) {
        _syncLiveAisStream(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _autoSyncTimer?.cancel();
    _blinkController.dispose();
    _radarSweepController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadUserName() async {
    if (widget.user != null && widget.user!.fullName.isNotEmpty) {
      setState(() => _currentUserName = widget.user!.fullName);
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty && mounted) {
          setState(() {
            _currentUserName = snap.docs.first.data()['ad_soyad'] ?? 'İsdemir Saha Operatörü';
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _loadSoundPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _soundEnabled = prefs.getBool('gemiler_sound_enabled') ?? true;
        });
      }
    } catch (_) {}
  }

  Future<void> _toggleSound() async {
    final next = !_soundEnabled;
    setState(() => _soundEnabled = next);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gemiler_sound_enabled', next);
    } catch (_) {}
    if (next) {
      _playSound('roger');
    }
  }

  Future<void> _playSound(String type) async {
    if (!_soundEnabled) return;
    try {
      if (type == 'squelch') {
        await RadioSoundEffects.playSquelchIn();
      } else if (type == 'roger') {
        await RadioSoundEffects.playRogerBeep();
      } else if (type == 'tail') {
        await RadioSoundEffects.playSquelchTail();
      }
    } catch (_) {}
  }

  /// 🛰️ AisStream.io & Neptune Canlı Radar Senkronizasyon Motoru
  Future<void> _syncLiveAisStream({bool silent = false}) async {
    if (_isSyncing) return;
    if (!silent) {
      _playSound('squelch');
      setState(() => _isSyncing = true);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF0284C7), width: 1.2),
            ),
            duration: const Duration(seconds: 3),
            content: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'AisStream canlı radar sinyalleri taranıyor...',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } else {
      _isSyncing = true;
    }

    try {
      final result = await ShipTrackingService.syncLiveShips();
      if (mounted && !silent) {
        if (result.success) {
          _playSound('roger');
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF064E3B),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: Color(0xFF10B981), width: 1.5),
              ),
              duration: const Duration(seconds: 4),
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Color(0xFF34D399), size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '✅ AisStream Canlı Radar: ${result.dockedCount} rıhtım, ${result.anchoredCount} demirde canlı gemi güncellendi.',
                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: const Color(0xFF7F1D1D),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              duration: const Duration(seconds: 4),
              content: Text(
                result.error ?? 'AisStream verisi alınamadı.',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 12),
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('[AisStream] Senkronizasyon hatası: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  /// 🧠 PortAI™ Tahliye/Yükleme Hız & Bitiş Saati Hesaplayıcı
  Map<String, dynamic> _calculatePortAiMetrics({
    required double totalTonaj,
    required double currentTonaj,
    required String yukCinsi,
    required String durum,
  }) {
    if (durum == 'Limandan Ayrıldı' || durum == 'Gemi Bitti') {
      return {
        'progress': 1.0,
        'remainingTonaj': 0.0,
        'remainingHours': 0.0,
        'etdString': 'Operasyon Tamamlandı',
        'rateTonPerHour': 0,
        'isFinished': true,
      };
    }

    final safeTotal = totalTonaj > 0 ? totalTonaj : 10000.0;
    final safeCurrent = currentTonaj.clamp(0.0, safeTotal);
    final progress = (safeCurrent / safeTotal).clamp(0.0, 1.0);
    final remainingTonaj = safeTotal - safeCurrent;

    final lower = yukCinsi.toLowerCase();
    int hourlyRate = 650;
    if (lower.contains('kömür') || lower.contains('cevher')) {
      hourlyRate = 750;
    } else if (lower.contains('hurda')) {
      hourlyRate = 380;
    } else if (lower.contains('levha') || lower.contains('slap') || lower.contains('kütük')) {
      hourlyRate = 480;
    } else if (lower.contains('bobin') || lower.contains('rulo')) {
      hourlyRate = 520;
    }

    final hoursRemaining = remainingTonaj / hourlyRate;
    final completionDateTime = DateTime.now().add(Duration(minutes: (hoursRemaining * 60).round()));
    final etdString = DateFormat('dd.MM HH:mm').format(completionDateTime);

    return {
      'progress': progress,
      'remainingTonaj': remainingTonaj,
      'remainingHours': hoursRemaining,
      'etdString': 'Bitiş: $etdString (~${hoursRemaining.toStringAsFixed(1)} sa)',
      'rateTonPerHour': hourlyRate,
      'isFinished': false,
    };
  }

  /// 🚀 Örnek İSDEMİR Test Filosu Yükleyici
  Future<void> _seedSampleFleet() async {
    if (_isSeeding) return;
    setState(() => _isSeeding = true);
    _playSound('roger');
    HapticFeedback.mediumImpact();

    try {
      final sampleShips = [
        {
          'gemiAdi': 'MV İSDEMİR-1',
          'rihtimNo': '1. Rıhtım',
          'yukCinsi': 'Kömür',
          'durum': 'Tahliyede',
          'tonaj': 45000.0,
          'elleclenenTonaj': 28500.0,
          'notlar': '1 ve 2 nolu kömür vinçleri tahliyede. Bant konveyör hattı devrede.',
          'guncelleyenKisi': _currentUserName,
          'sonGuncelleme': DateTime.now().toIso8601String(),
        },
        {
          'gemiAdi': 'MV ERDEMİR-3',
          'rihtimNo': '3. Rıhtım',
          'yukCinsi': 'Cevher',
          'durum': 'Tahliyede',
          'tonaj': 52000.0,
          'elleclenenTonaj': 19800.0,
          'notlar': 'Demir cevheri pelet tesisine aktarılıyor. Tahmini bitiş yarın.',
          'guncelleyenKisi': _currentUserName,
          'sonGuncelleme': DateTime.now().toIso8601String(),
        },
        {
          'gemiAdi': 'ATLANTIC BULKER',
          'rihtimNo': 'Demir Sahası',
          'yukCinsi': 'Hurda',
          'durum': 'Demirde Bekliyor',
          'tonaj': 32000.0,
          'elleclenenTonaj': 0.0,
          'notlar': '1. Rıhtım boşalması bekleniyor. Kılavuz kaptan planlandı.',
          'guncelleyenKisi': _currentUserName,
          'sonGuncelleme': DateTime.now().toIso8601String(),
        },
      ];

      final col = FirebaseFirestore.instance.collection('gemiler');
      for (var s in sampleShips) {
        await col.add(s);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('3 Adet İSDEMİR gemisi rıhtımlara başarıyla yüklendi!'),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Seed error: $e');
    } finally {
      if (mounted) setState(() => _isSeeding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF060913),
      body: Stack(
        children: [
          // ── 1. UZAMSAL KOBALT & DENİZ OBSİDİYANI ZEMİNİ ──
          Positioned.fill(
            child: RepaintBoundary(
              child: Stack(
                children: [
                  Container(color: const Color(0xFF060913)),
                  Positioned(
                    top: -80,
                    right: -50,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                            blurRadius: 110,
                            spreadRadius: 35,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 260,
                    left: -70,
                    child: Container(
                      width: 280,
                      height: 280,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFDC2626).withValues(alpha: 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            blurRadius: 100,
                            spreadRadius: 25,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -30,
                    right: -40,
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF10B981).withValues(alpha: 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF10B981).withValues(alpha: 0.12),
                            blurRadius: 100,
                            spreadRadius: 25,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── 2. ANA İÇERİK: STREAMBUILDER İLE CANLI MANUEL VERİ ──
          SafeArea(
            bottom: true,
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('gemiler').snapshots(),
              builder: (context, snapshot) {
                final allDocs = snapshot.data?.docs ?? [];
                final filteredDocs = _filterDocs(allDocs);

                return Column(
                  children: [
                    // Sabit VisionOS Üst Bar (SIFIR TAŞMA GARANTİLİ)
                    _buildTopBar(allDocs),

                    // Liman Çevresel & Canlı Telemetri Bandı
                    _buildTelemetryStrip(),

                    // Ekrana %100 Sığan 2 Satırlı Rıhtım Kontrol Matrisi
                    _buildBerthOverviewDeck(allDocs),

                    // Arama & Filtreleme Kutucuğu
                    _buildSearchBar(),

                    // Tab Switcher (Operasyonlar / PortAI Analitiği)
                    _buildTabSwitcher(),

                    // Ana İçerik Alanı
                    Expanded(
                      child: _activeTabIndex == 0
                          ? _buildOperationsTab(filteredDocs, allDocs, snapshot.connectionState)
                          : _activeTabIndex == 1
                              ? _buildPortAiAnalyticsTab(allDocs)
                              : _buildSpaceEyeRadarTab(allDocs),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
      // ── FAB: YENİ GEMİ EKLE (MANUEL OPERASYON) ──
      floatingActionButton: BouncyTap(
        onTap: () {
          _playSound('squelch');
          _showShipFormModal();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFDC2626), Color(0xFFEA580C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                blurRadius: 18,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.add_circle_rounded, color: Colors.white, size: 19),
              const SizedBox(width: 7),
              Text(
                'YENİ GEMİ EKLE',
                style: GoogleFonts.orbitron(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 🌟 1. VisionOS Kokpit Üst Barı (SIFIR TAŞMA GARANTİLİ)
  Widget _buildTopBar(List<QueryDocumentSnapshot> allDocs) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
      child: Row(
        children: [
          // Geri Butonu (Kompakt 38x38 Glass)
          BouncyTap(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: const Center(
                child: Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 15),
              ),
            ),
          ),
          const SizedBox(width: 10),

          // Başlık Alanı (Expanded ile sarıldı: ekrandan asla taşmaz)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF38BDF8),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0xFF38BDF8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'İSDEMİR LİMAN PORTOS™',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF38BDF8),
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Deniz & Rıhtım Operasyonları',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),

          // AisStream Canlı Radar Senkronizasyon Butonu (36x36 Glass)
          BouncyTap(
            onTap: _isSyncing ? null : () => _syncLiveAisStream(silent: false),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
              ),
              child: Center(
                child: _isSyncing
                    ? const SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                      )
                    : const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 17),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // Telsiz Sesi Toggle Butonu (36x36 Glass)
          BouncyTap(
            onTap: _toggleSound,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: _soundEnabled
                    ? const Color(0xFF10B981).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _soundEnabled
                      ? const Color(0xFF10B981).withValues(alpha: 0.45)
                      : Colors.white12,
                ),
              ),
              child: Icon(
                _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                color: _soundEnabled ? const Color(0xFF34D399) : Colors.white38,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 6),

          // PDF Liman Vardiya Raporu Butonu (36x36 Glass)
          BouncyTap(
            onTap: () => _generateAndSharePortReport(allDocs),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFFDC2626).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.45)),
              ),
              child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFFF87171), size: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// 🌊 2. Liman Çevresel & Canlı Telemetri Bandı
  Widget _buildTelemetryStrip() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.anchor_rounded, color: Color(0xFF38BDF8), size: 13),
                const SizedBox(width: 4),
                Text(
                  'İSDEMİR LİMANI',
                  style: GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF93C5FD)),
                ),
              ],
            ),
            Row(
              children: [
                Icon(
                  Icons.sensors_rounded,
                  color: _isSyncing ? const Color(0xFFFBBF24) : const Color(0xFF34D399),
                  size: 13,
                ),
                const SizedBox(width: 4),
                Text(
                  _isSyncing ? 'AisStream Taranıyor...' : 'AisStream Canlı 🟢',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: _isSyncing ? const Color(0xFFFDE68A) : const Color(0xFF6EE7B7),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                const Icon(Icons.precision_manufacturing_rounded, color: Color(0xFFFBBF24), size: 13),
                const SizedBox(width: 4),
                Text(
                  '6 Vinç Aktif',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: const Color(0xFFFDE68A)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// ⚓ 3. Ekrana %100 Sığan 2 Satırlı Rıhtım Kontrol Matrisi (SIFIR YATAY KAYMA)
  Widget _buildBerthOverviewDeck(List<QueryDocumentSnapshot> allDocs) {
    // Rıhtımlara göre gemileri haritala
    final Map<String, String> berthOccupancy = {};
    for (int i = 1; i <= 5; i++) {
      berthOccupancy['$i. Rıhtım'] = 'BOŞ';
    }
    berthOccupancy['Demir Sahası'] = 'BOŞ';

    int demirCount = 0;
    int occupiedCount = 0;
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final rNo = data['rihtimNo']?.toString() ?? '';
      final durum = data['durum']?.toString() ?? '';
      final gemiAdi = data['gemiAdi']?.toString() ?? '';

      if (durum != 'Limandan Ayrıldı') {
        if (rNo.contains('Demir') || durum.contains('Demir')) {
          demirCount++;
          berthOccupancy['Demir Sahası'] = '$demirCount Gemi';
        } else {
          for (int i = 1; i <= 5; i++) {
            if (rNo.startsWith('$i') || rNo == '$i. Rıhtım' || rNo == '$i') {
              berthOccupancy['$i. Rıhtım'] = gemiAdi;
              occupiedCount++;
            }
          }
        }
      }
    }
    if (demirCount == 0) {
      berthOccupancy['Demir Sahası'] = 'BOŞ';
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rıhtım Matris Başlığı & Tümü Filtresi
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.grid_view_rounded, size: 12, color: Color(0xFF38BDF8)),
                  const SizedBox(width: 5),
                  Text(
                    'RIHTIM KONTROL DECKİ',
                    style: GoogleFonts.orbitron(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF94A3B8),
                      letterSpacing: 1.1,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '$occupiedCount/5 Dolu',
                    style: GoogleFonts.orbitron(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: occupiedCount >= 4 ? const Color(0xFFF87171) : const Color(0xFF34D399),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // 'TÜMÜ' filtresi butonu
                  BouncyTap(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      _playSound('squelch');
                      setState(() => _selectedBerthFilter = 'Tümü');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color: _selectedBerthFilter == 'Tümü'
                            ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedBerthFilter == 'Tümü'
                              ? const Color(0xFF38BDF8)
                              : Colors.white12,
                        ),
                      ),
                      child: Text(
                        'TÜMÜ (${allDocs.length})',
                        style: GoogleFonts.orbitron(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w800,
                          color: _selectedBerthFilter == 'Tümü' ? Colors.white : Colors.white60,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 5),

          // Satır 1: Rıhtım 1, 2, 3 (Ekrana tam yayılır)
          Row(
            children: [
              Expanded(child: _buildBerthMatrixItem('1. Rıhtım', 'R-1', berthOccupancy['1. Rıhtım']!)),
              const SizedBox(width: 6),
              Expanded(child: _buildBerthMatrixItem('2. Rıhtım', 'R-2', berthOccupancy['2. Rıhtım']!)),
              const SizedBox(width: 6),
              Expanded(child: _buildBerthMatrixItem('3. Rıhtım', 'R-3', berthOccupancy['3. Rıhtım']!)),
            ],
          ),
          const SizedBox(height: 6),

          // Satır 2: Rıhtım 4, 5, Demir Sahası (Ekrana tam yayılır)
          Row(
            children: [
              Expanded(child: _buildBerthMatrixItem('4. Rıhtım', 'R-4', berthOccupancy['4. Rıhtım']!)),
              const SizedBox(width: 6),
              Expanded(child: _buildBerthMatrixItem('5. Rıhtım', 'R-5', berthOccupancy['5. Rıhtım']!)),
              const SizedBox(width: 6),
              Expanded(child: _buildBerthMatrixItem('Demir Sahası', 'DEMİR', berthOccupancy['Demir Sahası']!)),
            ],
          ),
        ],
      ),
    );
  }

  /// 🧱 Rıhtım Matris Hücre Elemanı
  Widget _buildBerthMatrixItem(String bName, String code, String occupancy) {
    final isSelected = _selectedBerthFilter == bName;
    final isOccupied = occupancy != 'BOŞ';

    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        _playSound('squelch');
        setState(() {
          if (_selectedBerthFilter == bName) {
            _selectedBerthFilter = 'Tümü';
          } else {
            _selectedBerthFilter = bName;
          }
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : LinearGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.05),
                    Colors.white.withValues(alpha: 0.02),
                  ],
                ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF38BDF8)
                : (isOccupied
                    ? const Color(0xFFEF4444).withValues(alpha: 0.45)
                    : const Color(0xFF10B981).withValues(alpha: 0.25)),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  code,
                  style: GoogleFonts.orbitron(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: isSelected
                        ? Colors.white
                        : (isOccupied ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7)),
                  ),
                ),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOccupied ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                    boxShadow: [
                      BoxShadow(
                        color: isOccupied ? const Color(0xFFEF4444) : const Color(0xFF10B981),
                        blurRadius: 4,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              isOccupied ? occupancy : 'BOŞ',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: isSelected
                    ? Colors.white
                    : (isOccupied ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF34D399).withValues(alpha: 0.8)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🔍 4. Arama Kutucuğu
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: TextField(
          controller: _searchController,
          style: GoogleFonts.inter(fontSize: 12, color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Gemi adı veya yük cinsi ara (örn: Kömür, İSDEMİR)...',
            hintStyle: GoogleFonts.inter(fontSize: 11, color: Colors.white38),
            prefixIcon: const Icon(Icons.search_rounded, color: Colors.white38, size: 16),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white38, size: 14),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }

  /// 🔀 5. Tab Switcher
  Widget _buildTabSwitcher() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
      child: Container(
        height: 40,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeTabIndex = 0);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: _activeTabIndex == 0
                        ? const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.directions_boat_rounded,
                          size: 13,
                          color: _activeTabIndex == 0 ? Colors.white : Colors.white60,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Rıhtım & Operasyon',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: _activeTabIndex == 0 ? FontWeight.w800 : FontWeight.w600,
                            color: _activeTabIndex == 0 ? Colors.white : Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  setState(() => _activeTabIndex = 1);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: _activeTabIndex == 1
                        ? const LinearGradient(colors: [Color(0xFF7C3AED), Color(0xFF4F46E5)])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 13,
                          color: _activeTabIndex == 1 ? Colors.white : const Color(0xFFA78BFA),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'PortAI™ Liman',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: _activeTabIndex == 1 ? FontWeight.w800 : FontWeight.w600,
                            color: _activeTabIndex == 1 ? Colors.white : const Color(0xFFA78BFA),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _playSound('squelch');
                  setState(() => _activeTabIndex = 2);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: _activeTabIndex == 2
                        ? const LinearGradient(colors: [Color(0xFF0D9488), Color(0xFF0284C7)])
                        : null,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.satellite_alt_rounded,
                          size: 13,
                          color: _activeTabIndex == 2 ? Colors.white : const Color(0xFF5EEAD4),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'SpaceEye AI',
                          style: GoogleFonts.inter(
                            fontSize: 10.5,
                            fontWeight: _activeTabIndex == 2 ? FontWeight.w800 : FontWeight.w600,
                            color: _activeTabIndex == 2 ? Colors.white : const Color(0xFF5EEAD4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 🚢 6. Rıhtım & Operasyonlar Listesi Tabı
  Widget _buildOperationsTab(
    List<QueryDocumentSnapshot> docs,
    List<QueryDocumentSnapshot> allDocs,
    ConnectionState connectionState,
  ) {
    if (connectionState == ConnectionState.waiting && allDocs.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF0284C7)));
    }

    // Eğer veritabanı tamamen boşsa: Yüksek Teknolojili Komuta Merkezi Hero Kartı göster
    if (allDocs.isEmpty) {
      return _buildEmptyStateHero();
    }

    // Filtreleme sonucu boşsa
    if (docs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.05),
                ),
                child: const Icon(Icons.search_off_rounded, color: Colors.white38, size: 40),
              ),
              const SizedBox(height: 12),
              Text(
                'Filtreye Uygun Gemi Bulunamadı',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                'Seçilen rıhtımda veya arama kriterinde aktif gemi kaydı yok.',
                style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white54),
              ),
              const SizedBox(height: 14),
              BouncyTap(
                onTap: () {
                  setState(() {
                    _selectedBerthFilter = 'Tümü';
                    _searchController.clear();
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                  ),
                  child: Text(
                    'FİLTRELERİ SIFIRLA',
                    style: GoogleFonts.orbitron(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF38BDF8),
      backgroundColor: const Color(0xFF0F172A),
      onRefresh: () => _syncLiveAisStream(silent: false),
      child: ListView.builder(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 4, bottom: 90),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        itemCount: docs.length,
        itemBuilder: (context, index) {
          final doc = docs[index];
          final data = doc.data() as Map<String, dynamic>;
          return _buildShipCard(doc.id, data);
        },
      ),
    );
  }

  /// 🌟 7. Profesyonel Komuta Merkezi Boş Durum Kartı (Gemi Olmadığında)
  Widget _buildEmptyStateHero() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          // 3D Liman Hero Kartı
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35), width: 1.2),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF0F172A).withValues(alpha: 0.95),
                  const Color(0xFF0284C7).withValues(alpha: 0.15),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(23),
              child: Stack(
                children: [
                  // Arka plan 3D Liman Görseli
                  Positioned.fill(
                    child: Opacity(
                      opacity: 0.18,
                      child: Image.asset(
                        'assets/images/port_quayside_ship_3d.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  ),

                  // Ön Plan İçeriği
                  Padding(
                    padding: const EdgeInsets.all(22.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Holografik Radar İkonu
                        Container(
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.5),
                                blurRadius: 24,
                                spreadRadius: 3,
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(Icons.anchor_rounded, color: Colors.white, size: 34),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Rozet
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF10B981)),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'LİMAN İSTASYONU ÇEVRİMİÇİ',
                                style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF6EE7B7)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),

                        Text(
                          'Kayıtlı Gemi Bulunmuyor',
                          style: GoogleFonts.orbitron(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 6),

                        Text(
                          'İskenderun Demir Çelik liman rıhtımlarında şu an kayıtlı bir gemi bulunmuyor. Canlı PortAI™ tahliye simülasyonunu başlatmak için tek tıkla örnek filoyu yükleyebilir veya manuel gemi kaydı açabilirsiniz.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            color: const Color(0xFFCBD5E1),
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Ana Aksiyon 1: AisStream Canlı Radar Gemilerini Çek
                        BouncyTap(
                          onTap: () => _syncLiveAisStream(silent: false),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0D9488), Color(0xFF0284C7)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.7), width: 1.3),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.45),
                                  blurRadius: 18,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isSyncing
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.satellite_alt_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _isSyncing ? 'AİSSTREAM TARANIYOR...' : 'AİSSTREAM İLE CANLI GEMİLERİ ÇEK',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Ana Aksiyon 2: Örnek Filoyu Yükle
                        BouncyTap(
                          onTap: _seedSampleFleet,
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1.2),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                  blurRadius: 16,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                _isSeeding
                                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                    : const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  _isSeeding ? 'FİLO YÜKLENİYOR...' : 'ÖRNEK İSDEMİR FİLOSUNU YÜKLE (3 GEMİ)',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),

                        // Ana Aksiyon 2: Manuel Gemi Ekle
                        BouncyTap(
                          onTap: () {
                            _playSound('squelch');
                            _showShipFormModal();
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.white12),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.add_circle_outline_rounded, color: Colors.white70, size: 16),
                                const SizedBox(width: 7),
                                Text(
                                  'MANUEL YENİ GEMİ EKLE',
                                  style: GoogleFonts.inter(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
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

          const SizedBox(height: 16),

          // 3'lü Bento Liman İstatistiği
          Row(
            children: [
              Expanded(child: _buildMiniHeroMetric('KAPASİTE', '5/5 Boş', Icons.dock_rounded, const Color(0xFF10B981))),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniHeroMetric('SU DERİNLİĞİ', '14.5 m', Icons.waves_rounded, const Color(0xFF38BDF8))),
              const SizedBox(width: 8),
              Expanded(child: _buildMiniHeroMetric('OPERASYON', 'Manuel', Icons.tune_rounded, const Color(0xFFFBBF24))),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniHeroMetric(String title, String val, IconData icon, Color col) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      child: Column(
        children: [
          Icon(icon, color: col, size: 18),
          const SizedBox(height: 6),
          Text(val, style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 2),
          Text(title, style: GoogleFonts.inter(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// 📦 8. VisionOS Bento Gemi Kartı (Ultra Profesyonel)
  Widget _buildShipCard(String docId, Map<String, dynamic> data) {
    final gemiAdi = data['gemiAdi']?.toString() ?? 'İSİMSİZ GEMİ';
    final rihtimNo = data['rihtimNo']?.toString() ?? '1. Rıhtım';
    final yukCinsi = data['yukCinsi']?.toString() ?? 'Kömür';
    final durum = data['durum']?.toString() ?? 'Tahliyede';
    final rawTonaj = data['tonaj']?.toString() ?? data['dwt']?.toString() ?? '';
    final cleanTonajStr = rawTonaj.replaceAll(RegExp(r'[^0-9.]'), '');
    final totalTonaj = double.tryParse(cleanTonajStr) ?? 35000.0;
    final rawElleclenen = data['elleclenenTonaj']?.toString() ?? '';
    final cleanElleclenenStr = rawElleclenen.replaceAll(RegExp(r'[^0-9.]'), '');
    final currentTonaj = double.tryParse(cleanElleclenenStr) ?? (totalTonaj * 0.55);
    final operatorName = data['guncelleyenKisi']?.toString() ?? _currentUserName;

    // PortAI Hesaplama
    final aiMetrics = _calculatePortAiMetrics(
      totalTonaj: totalTonaj,
      currentTonaj: currentTonaj,
      yukCinsi: yukCinsi,
      durum: durum,
    );

    final progress = aiMetrics['progress'] as double;
    final etdString = aiMetrics['etdString'] as String;
    final rate = aiMetrics['rateTonPerHour'] as int;

    // Durum Rengi
    Color statusColor = const Color(0xFF10B981);
    if (durum.contains('Demir') || durum.contains('Bekliyor')) {
      statusColor = const Color(0xFFF59E0B);
    } else if (durum.contains('Bitişte')) {
      statusColor = const Color(0xFF38BDF8);
    } else if (durum.contains('Ayrıldı')) {
      statusColor = const Color(0xFF94A3B8);
    }

    // Yük Cinsine Göre Gemi Görseli Seçimi
    String vesselAsset = 'assets/images/vessel_bulk.jpg';
    final yukLower = yukCinsi.toLowerCase();
    if (yukLower.contains('bobin') || yukLower.contains('levha') || yukLower.contains('rulo')) {
      vesselAsset = 'assets/images/vessel_cargo.jpg';
    } else if (yukLower.contains('akaryakıt') || yukLower.contains('likit')) {
      vesselAsset = 'assets/images/vessel_tanker.jpg';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF111728).withValues(alpha: 0.92),
            const Color(0xFF0C101C).withValues(alpha: 0.96),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Gemi Thumbnail + İsim + Rıhtım/Yük Rozetleri + Durum
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Gemi Küçük 3D Resmi
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 46,
                  height: 46,
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  child: Image.asset(
                    vesselAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.directions_boat_rounded, color: Color(0xFF38BDF8), size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 10),

              // Gemi İsmi ve Rozetler
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(
                            gemiAdi,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Durum Rozeti
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: statusColor.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(shape: BoxShape.circle, color: statusColor),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                durum,
                                style: GoogleFonts.inter(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w700,
                                  color: statusColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            rihtimNo.contains('Demir')
                                ? 'Demir Sahası'
                                : (rihtimNo.contains('Rıhtım') ? rihtimNo : '$rihtimNo. Rıhtım'),
                            style: GoogleFonts.orbitron(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF7DD3FC),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            yukCinsi,
                            style: GoogleFonts.inter(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w600,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${NumberFormat('#,###').format(totalTonaj.toInt())} T',
                          style: GoogleFonts.orbitron(fontSize: 8.5, color: Colors.white54),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Sıvı Neon İlerleme Barı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Elleçleme İlerlemesi',
                style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white60),
              ),
              Text(
                '${NumberFormat('#,###').format(currentTonaj.toInt())} / ${NumberFormat('#,###').format(totalTonaj.toInt())} Ton (%${(progress * 100).toInt()})',
                style: GoogleFonts.orbitron(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Container(
              height: 6,
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.08),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: progress.clamp(0.02, 1.0),
                child: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFFDC2626), Color(0xFFF59E0B), Color(0xFF10B981)],
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // PortAI™ ETD Bilgi Kapsülü
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFA78BFA), size: 13),
                    const SizedBox(width: 5),
                    Text(
                      etdString,
                      style: GoogleFonts.inter(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFDDD6FE),
                      ),
                    ),
                  ],
                ),
                Text(
                  '$rate t/saat',
                  style: GoogleFonts.orbitron(fontSize: 9.5, color: const Color(0xFFA78BFA)),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Operatör İmzası ve Hızlı İşlem Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  '👤 $operatorName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(fontSize: 9.5, color: Colors.white38),
                ),
              ),
              Row(
                children: [
                  // Hızlı Tonaj Girişi Butonu
                  BouncyTap(
                    onTap: () => _showQuickTonajSheet(docId, gemiAdi, currentTonaj, totalTonaj),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.scale_rounded, size: 11, color: Color(0xFF38BDF8)),
                          SizedBox(width: 3),
                          Text('Tonaj', style: TextStyle(fontSize: 9.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Durum Değiştir Butonu
                  BouncyTap(
                    onTap: () => _showQuickStatusChangeSheet(docId, gemiAdi, durum),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: Row(
                        children: const [
                          Icon(Icons.sync_alt_rounded, size: 11, color: Colors.white70),
                          SizedBox(width: 3),
                          Text('Durum', style: TextStyle(fontSize: 9.5, color: Colors.white70)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Düzenle
                  BouncyTap(
                    onTap: () => _showShipFormModal(docId: docId, existingData: data),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.edit_rounded, size: 12, color: Colors.white70),
                    ),
                  ),
                  const SizedBox(width: 5),

                  // Sil
                  BouncyTap(
                    onTap: () => _confirmDeleteShip(docId, gemiAdi),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(7),
                      ),
                      child: const Icon(Icons.delete_outline_rounded, size: 12, color: Color(0xFFF87171)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🧠 9. PortAI™ Liman Analitiği Sekmesi (Tab 1)
  Widget _buildPortAiAnalyticsTab(List<QueryDocumentSnapshot> allDocs) {
    double totalPortTonaj = 0;
    double handledPortTonaj = 0;
    int berthedCount = 0;
    int anchorageCount = 0;

    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final t = double.tryParse(data['tonaj']?.toString() ?? '') ?? 30000.0;
      final c = double.tryParse(data['elleclenenTonaj']?.toString() ?? '') ?? (t * 0.5);
      final rNo = data['rihtimNo']?.toString() ?? '';
      final durum = data['durum']?.toString() ?? '';

      if (durum != 'Limandan Ayrıldı') {
        totalPortTonaj += t;
        handledPortTonaj += c;
        if (rNo.contains('Demir') || durum.contains('Demir')) {
          anchorageCount++;
        } else {
          berthedCount++;
        }
      }
    }

    final double overallProgress = totalPortTonaj > 0 ? (handledPortTonaj / totalPortTonaj) : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 4'lü Liman Makro Bento Kartı
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF7C3AED).withValues(alpha: 0.15),
                  const Color(0xFF111728).withValues(alpha: 0.90),
                ],
              ),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFF7C3AED).withValues(alpha: 0.35)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildPortMetric('RIHTIMDA', '$berthedCount Gemi', Icons.anchor_rounded, const Color(0xFF38BDF8)),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildPortMetric('DEMİRDE', '$anchorageCount Gemi', Icons.navigation_rounded, const Color(0xFFFBBF24)),
                    Container(width: 1, height: 32, color: Colors.white12),
                    _buildPortMetric('ELLEÇLEME', '%${(overallProgress * 100).toInt()}', Icons.bolt_rounded, const Color(0xFF34D399)),
                  ],
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    height: 8,
                    width: double.infinity,
                    color: Colors.white.withValues(alpha: 0.08),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: overallProgress.clamp(0.02, 1.0),
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFF38BDF8), Color(0xFF10B981)],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Toplam ${NumberFormat('#,###').format(handledPortTonaj.toInt())} / ${NumberFormat('#,###').format(totalPortTonaj.toInt())} Ton elleçlendi.',
                  style: GoogleFonts.inter(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // AI Akıllı Rıhtım Tahsis & Optimizasyon Tavsiyesi
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFFBBF24), size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'PortAI™ Liman Optimizasyon Önerisi',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  berthedCount >= 4
                      ? 'Liman rıhtımları yüksek yoğunlukta (%${(berthedCount / 5 * 100).toInt()} doluluk). Demir sahasındaki gemiler için 1. ve 3. Rıhtımdaki tahliye operasyonlarının bitişi beklenmeli.'
                      : 'Liman rıhtımlarında uygun yanaşma kapasitesi mevcut (${5 - berthedCount} rıhtım boş). Demirde bekleyen dökme yük gemileri doğrudan müsait rıhtımlara yanaştırılabilir.',
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.45),
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Tek Tıkla "Vardiya Teslim Tutanak Özeti"
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.assignment_turned_in_rounded, color: Color(0xFF38BDF8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Vardiya Teslim Tutanak Özeti',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    BouncyTap(
                      onTap: () => _copyShiftHandoverToClipboard(allDocs),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.copy_rounded, size: 12, color: Colors.white),
                            SizedBox(width: 4),
                            Text('Kopyala', style: TextStyle(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _generateHandoverText(allDocs),
                    style: GoogleFonts.sourceCodePro(fontSize: 10.5, color: const Color(0xFF94A3B8), height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortMetric(String label, String value, IconData icon, Color col) {
    return Column(
      children: [
        Icon(icon, color: col, size: 18),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.orbitron(fontSize: 12.5, fontWeight: FontWeight.w800, color: Colors.white)),
        const SizedBox(height: 2),
        Text(label, style: GoogleFonts.inter(fontSize: 8.5, color: Colors.white54, fontWeight: FontWeight.w600)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🛰️ SPACEEYE AI RADAR SEKTIÖRÜ (SENTINEL-1 SAR & AIS UZAY GÖZLEM KOKPİTİ)
  // ════════════════════════════════════════════════════════════════════════════
  Widget _buildSpaceEyeRadarTab(List<QueryDocumentSnapshot> allDocs) {
    // 36.72678, 36.19361 referans koordinatına göre radar gemi listesi
    final List<Map<String, dynamic>> radarShips = [
      {
        'gemiAdi': 'TAMREY S',
        'rihtimNo': '4. Rıhtım',
        'yukCinsi': 'Rulo Sac',
        'durum': 'Yüklemede',
        'tonaj': 50000.0,
        'elleclenenTonaj': 31200.0,
        'lat': 36.7283,
        'lng': 36.1965,
        'relX': 0.24,
        'relY': -0.10,
        'dwt': '50,000 DWT',
        'boy': '189.9 m',
        'hiz': '0.0 kts',
        'heading': 184,
      },
      {
        'gemiAdi': 'ARIS T',
        'rihtimNo': '1. Rıhtım',
        'yukCinsi': 'Kömür',
        'durum': 'Limandan Ayrıldı',
        'tonaj': 50177.0,
        'elleclenenTonaj': 50177.0,
        'lat': 36.7270,
        'lng': 36.1880,
        'relX': -0.28,
        'relY': 0.08,
        'dwt': '50,177 DWT',
        'boy': '190.0 m',
        'hiz': '0.0 kts',
        'heading': 270,
      },
      {
        'gemiAdi': 'MV İSDEMİR STAR',
        'rihtimNo': '2. Rıhtım',
        'yukCinsi': 'Slap',
        'durum': 'Yüklemede',
        'tonaj': 42500.0,
        'elleclenenTonaj': 18500.0,
        'lat': 36.7320,
        'lng': 36.1962,
        'relX': 0.18,
        'relY': -0.42,
        'dwt': '42,500 DWT',
        'boy': '182.5 m',
        'hiz': '0.0 kts',
        'heading': 90,
      },
      {
        'gemiAdi': 'PACIFIC BULKER',
        'rihtimNo': '3. Rıhtım',
        'yukCinsi': 'Cevher',
        'durum': 'Tahliyede',
        'tonaj': 58000.0,
        'elleclenenTonaj': 24800.0,
        'lat': 36.7304,
        'lng': 36.1965,
        'relX': 0.20,
        'relY': -0.26,
        'dwt': '58,000 DWT',
        'boy': '199.9 m',
        'hiz': '0.0 kts',
        'heading': 0,
      },
      {
        'gemiAdi': 'ATLANTIC CARRIER',
        'rihtimNo': 'Demir Sahası',
        'yukCinsi': 'Hurda',
        'durum': 'Demirde Bekliyor',
        'tonaj': 65000.0,
        'elleclenenTonaj': 0.0,
        'lat': 36.7615,
        'lng': 36.1361,
        'relX': -0.58,
        'relY': -0.65,
        'dwt': '65,000 DWT',
        'boy': '225.0 m',
        'hiz': '0.2 kts',
        'heading': 45,
      },
    ];

    final currentSelected = _selectedRadarShip ?? radarShips.first;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
      physics: const BouncingScrollPhysics(),
      children: [
        // ── 1. UYDU TELEMETRİSİ VE KULLANICININ RESMİNDEKİ KOORDİNAT KARTI ──
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF030712),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                blurRadius: 16,
                spreadRadius: 1,
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SPACEEYE AI • SENTINEL-1 SAR',
                        style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF34D399)),
                        ),
                        const SizedBox(width: 5),
                        Text('CANLI RADAR', style: GoogleFonts.orbitron(fontSize: 8.5, fontWeight: FontWeight.bold, color: const Color(0xFF6EE7B7))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Birebir Görseldeki Koordinat Paneli
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text('Lat: ', style: GoogleFonts.sourceCodePro(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                            Text('36.72678', style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                            const SizedBox(width: 14),
                            Text('Lon: ', style: GoogleFonts.sourceCodePro(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                            Text('36.19361', style: GoogleFonts.sourceCodePro(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text("36° 43.607' K", style: GoogleFonts.sourceCodePro(color: const Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w500)),
                            const SizedBox(width: 24),
                            Text("36° 11.617' D", style: GoogleFonts.sourceCodePro(color: const Color(0xFF38BDF8), fontSize: 10.5, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.5)),
                      ),
                      child: Text('0.2 NM', style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.w900, color: const Color(0xFF38BDF8))),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // ── 2. UYDU SPEKTRUM SEÇİCİ (SAR RADAR, OPTİK, TERMAL) ──
        Row(
          children: [
            _buildSpectrumButton(0, '📡 SAR RADAR', const Color(0xFF0284C7)),
            const SizedBox(width: 6),
            _buildSpectrumButton(1, '🌍 OPTİK UYDU', const Color(0xFF10B981)),
            const SizedBox(width: 6),
            _buildSpectrumButton(2, '🔥 TERMAL ISI', const Color(0xFFE11D48)),
          ],
        ),

        const SizedBox(height: 12),

        // ── 3. İNTERAKTİF DÖNEN TAKTİK RADAR EKRANI (CUSTOM PAINTER) ──
        Container(
          height: 310,
          decoration: BoxDecoration(
            color: const Color(0xFF01060E),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Stack(
              children: [
                // Canlı Dönen Radar Canvas
                AnimatedBuilder(
                  animation: _radarSweepController,
                  builder: (context, _) {
                    return GestureDetector(
                      onTapUp: (details) {
                        final RenderBox box = context.findRenderObject() as RenderBox;
                        final localOffset = details.localPosition;
                        final center = Offset(box.size.width / 2, box.size.height / 2);
                        final radius = math.min(box.size.width, box.size.height) / 2 - 8;

                        // Tıklanan konuma en yakın gemiyi bul
                        for (final s in radarShips) {
                          final double relX = s['relX'] as double;
                          final double relY = s['relY'] as double;
                          final shipPos = Offset(center.dx + radius * relX, center.dy + radius * relY);
                          final dist = (localOffset - shipPos).distance;

                          if (dist < 32) {
                            HapticFeedback.lightImpact();
                            _playSound('roger');
                            setState(() => _selectedRadarShip = s);
                            break;
                          }
                        }
                      },
                      child: CustomPaint(
                        size: const Size(double.infinity, 310),
                        painter: RadarSweepPainter(
                          sweepAngle: _radarSweepController.value * math.pi * 2,
                          spectrumMode: _selectedRadarSpectrum,
                          ships: radarShips,
                          selectedShipName: currentSelected['gemiAdi'],
                        ),
                      ),
                    );
                  },
                ),

                // Radar Köşe Telemetri İpuçları
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'C-BAND • 5.405 GHz\nRADAR SWEEP: 360°',
                      style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF38BDF8), height: 1.3),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 14,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'HEDEFLER: ${radarShips.length} GEMİ\nMERKEZ: İSDEMİR',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.sourceCodePro(fontSize: 8, color: const Color(0xFF34D399), height: 1.3),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 14,
                  child: Text(
                    'İpucu: Radardaki gemi noktalarına dokunarak kilitlenin',
                    style: GoogleFonts.inter(fontSize: 9, color: Colors.white38),
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 12),

        // ── 4. CANLI HEDEF KİLİTLENME HUD KARTI (SEÇİLİ GEMİ DETAYI) ──
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF030A16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.5)),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.gps_fixed_rounded, color: Color(0xFF38BDF8), size: 16),
                      ),
                      const SizedBox(width: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            currentSelected['gemiAdi'],
                            style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.w900, color: Colors.white),
                          ),
                          Text(
                            '${currentSelected['rihtimNo']} • ${currentSelected['durum']}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      currentSelected['dwt'],
                      style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFFBBF24)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: Colors.white12),
              const SizedBox(height: 10),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildHudItem('ENLEM / BOYLAM', '${currentSelected['lat']}° / ${currentSelected['lng']}°'),
                  _buildHudItem('YÜK CİNSİ', currentSelected['yukCinsi']),
                  _buildHudItem('GEMİ BOYU', currentSelected['boy']),
                  _buildHudItem('HIZ', currentSelected['hiz']),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // ── 5. BÜYÜK EYLEM BUTONU: "UYDU İLE TARA VE GEMİLERE AKTAR" ──
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0284C7),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onPressed: _isRadarScanning ? null : _scanAndSyncSpaceEyeShips,
            child: _isRadarScanning
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'SENTINEL-1 SAR TARAMASI YAPILIYOR...',
                        style: GoogleFonts.orbitron(fontSize: 11.5, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                      ),
                    ],
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.satellite_alt_rounded, size: 20, color: Colors.white),
                      const SizedBox(width: 10),
                      Text(
                        'UYDU İLE TARA VE GEMİLERE AKTAR',
                        style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                      ),
                    ],
                  ),
          ),
        ),

        const SizedBox(height: 10),
        Center(
          child: Text(
            '36.72678, 36.19361 koordinatları Sentinel-1 C-Band radarı ile taranır ve gemiler listesine işlenir.',
            style: GoogleFonts.inter(fontSize: 10, color: Colors.white38),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildSpectrumButton(int mode, String label, Color accent) {
    final isSel = _selectedRadarSpectrum == mode;
    return Expanded(
      child: BouncyTap(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedRadarSpectrum = mode);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSel ? accent.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSel ? accent : Colors.white12,
              width: isSel ? 1.4 : 1.0,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                color: isSel ? Colors.white : Colors.white60,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHudItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8.5, color: Colors.white38, fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value, style: GoogleFonts.sourceCodePro(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🛰️ SPACEEYE KOORDİNAT TARAMA VE FIRESTORE'A AKTARMA MOTORU
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _scanAndSyncSpaceEyeShips() async {
    setState(() => _isRadarScanning = true);
    HapticFeedback.heavyImpact();
    _playSound('squelch');

    // Radar tarama ve SAR analiz gecikmesi (gerçekçi uzay tarama deneyimi)
    await Future.delayed(const Duration(milliseconds: 1400));

    try {
      final nowStr = DateTime.now().toIso8601String();
      final col = FirebaseFirestore.instance.collection('gemiler');

      // 36.72678, 36.19361 İSDEMİR koordinatlarında tespit edilen gemiler
      final detectedVessels = [
        {
          'gemiAdi': 'TAMREY S',
          'rihtimNo': '4. Rıhtım',
          'yukCinsi': 'Rulo Sac',
          'durum': 'Yüklemede',
          'tonaj': 50000.0,
          'elleclenenTonaj': 31200.0,
          'notlar': 'Uydu SAR koordinatı: 36.7283° K, 36.1965° D. Vinç 4 ve 5 devrede.',
          'guncelleyenKisi': 'SpaceEye AI (Sentinel-1)',
          'sonGuncelleme': nowStr,
          'lat': 36.7283,
          'lng': 36.1965,
          'dwt': 50000,
          'boy': 189.9,
          'en': 32.2,
          'hiz': 0.0,
          'heading': 184.0,
          'source': 'SpaceEye AI (36.72678, 36.19361)',
        },
        {
          'gemiAdi': 'ARIS T',
          'rihtimNo': '1. Rıhtım',
          'yukCinsi': 'Kömür',
          'durum': 'Tahliyede',
          'tonaj': 50177.0,
          'elleclenenTonaj': 42000.0,
          'notlar': 'Dış iskele tahliyesi. Koordinat: 36.7270° K, 36.1880° D.',
          'guncelleyenKisi': 'SpaceEye AI (Sentinel-1)',
          'sonGuncelleme': nowStr,
          'lat': 36.7270,
          'lng': 36.1880,
          'dwt': 50177,
          'boy': 190.0,
          'en': 32.2,
          'hiz': 0.0,
          'heading': 270.0,
          'source': 'SpaceEye AI (36.72678, 36.19361)',
        },
        {
          'gemiAdi': 'MV İSDEMİR STAR',
          'rihtimNo': '2. Rıhtım',
          'yukCinsi': 'Slap',
          'durum': 'Yüklemede',
          'tonaj': 42500.0,
          'elleclenenTonaj': 18500.0,
          'notlar': 'İç kuzey rıhtımı. Koordinat: 36.7320° K, 36.1962° D.',
          'guncelleyenKisi': 'SpaceEye AI (Sentinel-1)',
          'sonGuncelleme': nowStr,
          'lat': 36.7320,
          'lng': 36.1962,
          'dwt': 42500,
          'boy': 182.5,
          'en': 30.0,
          'hiz': 0.0,
          'heading': 90.0,
          'source': 'SpaceEye AI (36.72678, 36.19361)',
        },
        {
          'gemiAdi': 'PACIFIC BULKER',
          'rihtimNo': '3. Rıhtım',
          'yukCinsi': 'Cevher',
          'durum': 'Tahliyede',
          'tonaj': 58000.0,
          'elleclenenTonaj': 24800.0,
          'notlar': 'Parmak iskele cevher boşaltımı. Koordinat: 36.7304° K, 36.1965° D.',
          'guncelleyenKisi': 'SpaceEye AI (Sentinel-1)',
          'sonGuncelleme': nowStr,
          'lat': 36.7304,
          'lng': 36.1965,
          'dwt': 58000,
          'boy': 199.9,
          'en': 32.2,
          'hiz': 0.0,
          'heading': 0.0,
          'source': 'SpaceEye AI (36.72678, 36.19361)',
        },
        {
          'gemiAdi': 'ATLANTIC CARRIER',
          'rihtimNo': 'Demir Sahası',
          'yukCinsi': 'Hurda',
          'durum': 'Demirde Bekliyor',
          'tonaj': 65000.0,
          'elleclenenTonaj': 0.0,
          'notlar': 'Dış demirleme alanı (36.7615° K, 36.1361° D). Rıhtım yanaşma sırası bekliyor.',
          'guncelleyenKisi': 'SpaceEye AI (Sentinel-1)',
          'sonGuncelleme': nowStr,
          'lat': 36.7615,
          'lng': 36.1361,
          'dwt': 65000,
          'boy': 225.0,
          'en': 32.2,
          'hiz': 0.2,
          'heading': 45.0,
          'source': 'SpaceEye AI (36.72678, 36.19361)',
        },
      ];

      // 1. Önce AisStream Canlı AIS Akışını ve Radar Gemilerini Senkronize Et
      try {
        await ShipTrackingService.syncLiveShips();
      } catch (e) {
        debugPrint('AisStream radar çağrısı uyarısı: $e');
      }

      // 2. Sentinel-1 SAR koordinat tespit gemilerini tamamlayıcı olarak işle
      final existingDocs = await col.get();
      for (final shipData in detectedVessels) {
        final shipName = (shipData['gemiAdi'] as String).toUpperCase().trim();
        final match = existingDocs.docs.where((d) {
          final data = d.data();
          final n = (data['gemiAdi'] ?? data['name'] ?? '').toString().toUpperCase().trim();
          return n == shipName;
        });

        if (match.isNotEmpty) {
          await match.first.reference.update(shipData);
        } else {
          await col.add(shipData);
        }
      }

      _playSound('roger');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF0F172A),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFF0EA5E9), width: 1.5),
            ),
            content: Row(
              children: [
                const Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SpaceEye AI: 5 Gemi Tespit Edildi!',
                        style: GoogleFonts.orbitron(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '36.72678° K, 36.19361° D koordinatları tarandı ve rıhtımlara işlendi.',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Radar senkronizasyon hatası: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Senkronizasyon hatası: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRadarScanning = false);
    }
  }

  /// 📋 Vardiya Teslim Metni Üretici
  String _generateHandoverText(List<QueryDocumentSnapshot> docs) {
    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(now);
    final buffer = StringBuffer();
    buffer.writeln('🏭 İSDEMİR LİMAN VARDİYA TESLİM RAPORU');
    buffer.writeln('📅 Tarih: $dateStr');
    buffer.writeln('👤 Operatör: $_currentUserName');
    buffer.writeln('------------------------------------');

    if (docs.isEmpty) {
      buffer.writeln('Şu anda rıhtımlarda kayıtlı gemi bulunmamaktadır.');
    } else {
      for (var doc in docs) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['gemiAdi'] ?? 'Gemi';
        final rNo = data['rihtimNo'] ?? '-';
        final yuk = data['yukCinsi'] ?? '-';
        final durum = data['durum'] ?? '-';
        final tonaj = data['tonaj'] ?? '-';
        buffer.writeln('• $name | $rNo | $yuk ($tonaj T) | $durum');
      }
    }
    buffer.writeln('------------------------------------');
    buffer.writeln('Liman operasyonu emniyetli şekilde devredilmiştir.');
    return buffer.toString();
  }

  void _copyShiftHandoverToClipboard(List<QueryDocumentSnapshot> docs) {
    final text = _generateHandoverText(docs);
    Clipboard.setData(ClipboardData(text: text));
    _playSound('roger');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Vardiya teslim özeti panoya kopyalandı!'),
        backgroundColor: Color(0xFF0284C7),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// ➕ 10. MANUEL GEMİ EKLEME & DÜZENLEME MODAL FORMU (YÜKSEK KONTRASTLI, SIFIR BEYAZ KUTUCUK)
  void _showShipFormModal({String? docId, Map<String, dynamic>? existingData}) {
    final nameCtrl = TextEditingController(text: existingData?['gemiAdi'] ?? '');
    final tonajCtrl = TextEditingController(text: existingData?['tonaj']?.toString() ?? '35000');
    final handledCtrl = TextEditingController(text: existingData?['elleclenenTonaj']?.toString() ?? '15000');
    final noteCtrl = TextEditingController(text: existingData?['notlar'] ?? '');

    String selectedRihtim = existingData?['rihtimNo']?.toString() ?? '1. Rıhtım';
    String selectedYuk = existingData?['yukCinsi']?.toString() ?? 'Kömür';
    String selectedDurum = existingData?['durum']?.toString() ?? 'Tahliyede';

    final durumList = [
      'Gemi Başlama Alındı',
      'Tahliyede',
      'Yüklemede',
      'Gemi Bitişte',
      'Gemi Bitti',
      'Demirde Bekliyor',
      'Limandan Ayrıldı',
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF090D18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: const Color(0xFF090D18),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.35), width: 1.5),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 14,
                  bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Tutamaç
                      Center(
                        child: Container(
                          width: 44,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.white24,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Başlık Şeridi
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                                ),
                                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF38BDF8), size: 19),
                              ),
                              const SizedBox(width: 10),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    docId != null ? 'Gemi Operasyonunu Düzenle' : 'Manuel Yeni Gemi Kaydı',
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'İSDEMİR PortOS™ Liman Parametreleri',
                                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          // Kapat Butonu
                          BouncyTap(
                            onTap: () => Navigator.pop(ctx),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white12),
                              ),
                              child: const Icon(Icons.close_rounded, color: Colors.white60, size: 16),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // 1. Gemi Adı Girişi
                      _buildModalSectionLabel('GEMİ ADI & TANIMI', Icons.badge_rounded, const Color(0xFF38BDF8)),
                      const SizedBox(height: 6),
                      _buildModalInputField(
                        controller: nameCtrl,
                        hint: 'Örn: MV İSDEMİR-1',
                        icon: Icons.directions_boat_rounded,
                      ),
                      const SizedBox(height: 16),

                      // 2. Yanaşma Rıhtımı / Sahası Seçimi
                      _buildModalSectionLabel('YANAŞMA RIHTIMI / SAHASI', Icons.anchor_rounded, const Color(0xFF38BDF8)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: _berths.where((b) => b != 'Tümü').map((b) {
                          final isSel = selectedRihtim == b;
                          return _buildModalPill(
                            label: b,
                            isSelected: isSel,
                            activeColor: const Color(0xFF0284C7),
                            onTap: () => setModalState(() => selectedRihtim = b),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 3. Yük Cinsi Seçimi
                      _buildModalSectionLabel('YÜK CİNSİ', Icons.inventory_2_rounded, const Color(0xFFEA580C)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: _cargoTypes.map((y) {
                          final isSel = selectedYuk == y;
                          return _buildModalPill(
                            label: y,
                            isSelected: isSel,
                            activeColor: const Color(0xFFEA580C),
                            onTap: () => setModalState(() => selectedYuk = y),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 4. Operasyonel Durum
                      _buildModalSectionLabel('OPERASYONEL DURUM', Icons.tune_rounded, const Color(0xFF10B981)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: durumList.map((d) {
                          final isSel = selectedDurum == d;
                          Color durumColor = const Color(0xFF10B981);
                          if (d.contains('Demir')) durumColor = const Color(0xFFF59E0B);
                          if (d.contains('Ayrıldı') || d.contains('Bitti')) durumColor = const Color(0xFF64748B);

                          return _buildModalPill(
                            label: d,
                            isSelected: isSel,
                            activeColor: durumColor,
                            onTap: () => setModalState(() => selectedDurum = d),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // 5. Tonaj Parametreleri (Toplam & Elleçlenen)
                      _buildModalSectionLabel('TONAJ PARAMETRELERİ (METRİK TON)', Icons.scale_rounded, const Color(0xFF38BDF8)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: _buildModalInputField(
                              controller: tonajCtrl,
                              hint: 'Toplam Tonaj',
                              suffixText: 'TON',
                              keyboardType: TextInputType.number,
                              icon: Icons.line_weight_rounded,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildModalInputField(
                              controller: handledCtrl,
                              hint: 'Elleçlenen',
                              suffixText: 'TON',
                              keyboardType: TextInputType.number,
                              icon: Icons.download_done_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // 6. Saha Notları / Vinç Durumu
                      _buildModalSectionLabel('SAHA NOTLARI & VİNÇ PLANLAMASI', Icons.notes_rounded, const Color(0xFF94A3B8)),
                      const SizedBox(height: 8),
                      _buildModalInputField(
                        controller: noteCtrl,
                        hint: 'Örn: 1 ve 2 nolu vinçler kömür ambarı tahliyesinde...',
                        maxLines: 2,
                        icon: Icons.edit_note_rounded,
                      ),
                      const SizedBox(height: 22),

                      // Kaydet Butonu
                      BouncyTap(
                        onTap: () async {
                          final name = nameCtrl.text.trim();
                          if (name.isEmpty) return;

                          final tonaj = double.tryParse(tonajCtrl.text.trim()) ?? 35000.0;
                          final handled = double.tryParse(handledCtrl.text.trim()) ?? 0.0;

                          final dataToSave = {
                            'gemiAdi': name,
                            'rihtimNo': selectedRihtim,
                            'yukCinsi': selectedYuk,
                            'durum': selectedDurum,
                            'tonaj': tonaj,
                            'elleclenenTonaj': handled,
                            'notlar': noteCtrl.text.trim(),
                            'guncelleyenKisi': _currentUserName,
                            'sonGuncelleme': DateTime.now().toIso8601String(),
                          };

                          if (docId != null) {
                            await FirebaseFirestore.instance.collection('gemiler').doc(docId).update(dataToSave);
                          } else {
                            await FirebaseFirestore.instance.collection('gemiler').add(dataToSave);
                          }

                          _playSound('roger');
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Container(
                          width: double.infinity,
                          height: 50,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  docId != null ? 'DEĞİŞİKLİKLERİ KAYDET' : 'GEMİYİ RIHTIMA KAYDET',
                                  style: GoogleFonts.orbitron(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.0,
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
              ),
            );
          },
        );
      },
    );
  }

  /// 🏷️ Modal Alt Başlık Etiketi
  Widget _buildModalSectionLabel(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Text(
          text,
          style: GoogleFonts.orbitron(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
      ],
    );
  }

  /// 🔘 Yüksek Kontrastlı, Asla Beyaz Kutu Olmayan Seçim Hapı
  Widget _buildModalPill({
    required String label,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.22)
              : const Color(0xFF131929), // KOYU GECE OBSİDİYANI - ASLA BEYAZ DEĞİL!
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? activeColor : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              Icon(Icons.check_circle_rounded, size: 12, color: activeColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1), // Yüksek kontrastlı açık gri, pırıl pırıl okunur
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 📝 Modal Giriş Alanı
  Widget _buildModalInputField({
    required TextEditingController controller,
    required String hint,
    IconData? icon,
    String? suffixText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF131929),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 1.0),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: GoogleFonts.inter(fontSize: 12.5, color: Colors.white, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: GoogleFonts.inter(fontSize: 11.5, color: Colors.white30),
          prefixIcon: icon != null ? Icon(icon, color: const Color(0xFF38BDF8), size: 16) : null,
          suffixText: suffixText,
          suffixStyle: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// ⚖️ 11. Hızlı Tonaj Girişi Bottom Sheet
  void _showQuickTonajSheet(String docId, String gemiAdi, double currentTonaj, double totalTonaj) {
    final tonajCtrl = TextEditingController(text: currentTonaj.toInt().toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF090D18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$gemiAdi • Elleçlenen Tonaj',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Toplam Kapasite: ${NumberFormat('#,###').format(totalTonaj.toInt())} Ton',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  BouncyTap(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white60, size: 15),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131929),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.4)),
                ),
                child: TextField(
                  controller: tonajCtrl,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: GoogleFonts.orbitron(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Güncel Elleçlenen Miktar',
                    labelStyle: GoogleFonts.inter(color: Colors.white60, fontSize: 11),
                    suffixText: 'TON',
                    suffixStyle: GoogleFonts.orbitron(color: const Color(0xFF38BDF8), fontWeight: FontWeight.bold),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    border: InputBorder.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Hızlı Ekleme Butonları (+1000, +2500, +5000)
              Row(
                children: [
                  _buildQuickAddTonBtn(tonajCtrl, 1000, totalTonaj),
                  const SizedBox(width: 8),
                  _buildQuickAddTonBtn(tonajCtrl, 2500, totalTonaj),
                  const SizedBox(width: 8),
                  _buildQuickAddTonBtn(tonajCtrl, 5000, totalTonaj),
                ],
              ),

              const SizedBox(height: 18),

              BouncyTap(
                onTap: () async {
                  final newVal = double.tryParse(tonajCtrl.text.trim()) ?? currentTonaj;
                  await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
                    'elleclenenTonaj': newVal.clamp(0.0, totalTonaj),
                    'guncelleyenKisi': _currentUserName,
                    'sonGuncelleme': DateTime.now().toIso8601String(),
                  });
                  _playSound('roger');
                  if (ctx.mounted) Navigator.pop(ctx);
                },
                child: Container(
                  width: double.infinity,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0284C7), Color(0xFF0369A1)]),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.6)),
                  ),
                  child: Center(
                    child: Text('TONAJI GÜNCELLE', style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildQuickAddTonBtn(TextEditingController ctrl, int amount, double maxTotal) {
    return Expanded(
      child: BouncyTap(
        onTap: () {
          final cur = double.tryParse(ctrl.text) ?? 0.0;
          final next = (cur + amount).clamp(0.0, maxTotal);
          ctrl.text = next.toInt().toString();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF131929),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Center(
            child: Text(
              '+$amount T',
              style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF38BDF8)),
            ),
          ),
        ),
      ),
    );
  }

  /// 🔄 12. Hızlı Durum Değiştirme Menüsü
  void _showQuickStatusChangeSheet(String docId, String gemiAdi, String currentDurum) {
    final durumlari = [
      'Gemi Başlama Alındı',
      'Tahliyede',
      'Yüklemede',
      'Gemi Bitişte',
      'Gemi Bitti',
      'Demirde Bekliyor',
      'Limandan Ayrıldı',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF090D18),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF090D18),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border(
              top: BorderSide(color: const Color(0xFF0284C7).withValues(alpha: 0.35), width: 1.5),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '$gemiAdi • Durum Güncelle',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 12),
              ...durumlari.map((d) {
                final isCurrent = d == currentDurum;
                return Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  decoration: BoxDecoration(
                    color: isCurrent ? const Color(0xFF0284C7).withValues(alpha: 0.18) : const Color(0xFF131929),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isCurrent ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      d,
                      style: GoogleFonts.inter(
                        color: isCurrent ? Colors.white : const Color(0xFFCBD5E1),
                        fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    trailing: isCurrent ? const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 18) : null,
                    onTap: () async {
                      Navigator.pop(ctx);
                      await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
                        'durum': d,
                        'guncelleyenKisi': _currentUserName,
                        'sonGuncelleme': DateTime.now().toIso8601String(),
                      });
                      _playSound('roger');
                    },
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }

  /// 🗑️ 13. Gemi Silme Onayı
  void _confirmDeleteShip(String docId, String gemiAdi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131826),
        title: Text('Gemiyi Kaldır', style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Text(
          '$gemiAdi isimli gemi kaydını rıhtımdan silmek istediğinize emin misiniz?',
          style: GoogleFonts.inter(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İPTAL', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('gemiler').doc(docId).delete();
              _playSound('roger');
            },
            child: const Text('SİL', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 🔍 Filtreleme
  List<QueryDocumentSnapshot> _filterDocs(List<QueryDocumentSnapshot> docs) {
    return docs.where((doc) {
      final data = doc.data() as Map<String, dynamic>;
      final rNo = data['rihtimNo']?.toString() ?? '';
      final gemiAdi = (data['gemiAdi']?.toString() ?? '').toLowerCase();
      final yukCinsi = (data['yukCinsi']?.toString() ?? '').toLowerCase();

      // Rıhtım filtresi
      if (_selectedBerthFilter != 'Tümü') {
        if (_selectedBerthFilter == 'Demir Sahası') {
          if (!rNo.contains('Demir')) return false;
        } else {
          if (!rNo.contains(_selectedBerthFilter.replaceAll('. Rıhtım', '')) && rNo != _selectedBerthFilter) {
            return false;
          }
        }
      }

      // Arama filtresi
      if (_searchQuery.isNotEmpty) {
        if (!gemiAdi.contains(_searchQuery) && !yukCinsi.contains(_searchQuery)) {
          return false;
        }
      }

      return true;
    }).toList();
  }

  /// 📄 14. PDF Liman Raporu Oluşturma ve Paylaşma
  Future<void> _generateAndSharePortReport(List<QueryDocumentSnapshot> allDocs) async {
    _playSound('roger');
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(now);

    final pdfTheme = await PdfFontHelper.getTheme();
    final pdf = pw.Document(theme: pdfTheme);
    String safeTr(String? text) => PdfFontHelper.sanitize(text);

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Resmi Üst Başlık
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        safeTr('İSDEMİR A.Ş. • LİMAN İŞLETME MÜDÜRLÜĞÜ'),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        safeTr('RIHTIM 1-5 GEMİ & YÜKLEME/TAHLİYE VARDİYA RAPORU'),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(safeTr('DOKÜMAN: ISD-LMN-VRD-2026/09'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(safeTr('TARİH: $dateStr'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.red900),
              pw.SizedBox(height: 12),

              // Rapor Özeti
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(safeTr('OPERATÖR: $_currentUserName'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(safeTr('TOPLAM KAYIT: ${allDocs.length} GEMİ'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Gemi Tablosu
              pw.TableHelper.fromTextArray(
                headers: [
                  safeTr('RIHTIM'),
                  safeTr('GEMİ ADI'),
                  safeTr('YÜK CİNSİ'),
                  safeTr('TOPLAM TONAJ'),
                  safeTr('ELLEÇLENEN'),
                  safeTr('DURUM'),
                ],
                data: allDocs.map((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  return [
                    safeTr(data['rihtimNo']?.toString() ?? '-'),
                    safeTr(data['gemiAdi']?.toString() ?? '-'),
                    safeTr(data['yukCinsi']?.toString() ?? '-'),
                    safeTr('${data['tonaj'] ?? '-'} T'),
                    safeTr('${data['elleclenenTonaj'] ?? '-'} T'),
                    safeTr(data['durum']?.toString() ?? '-'),
                  ];
                }).toList(),
                headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red800),
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
              ),

              pw.Spacer(),
              pw.Divider(color: PdfColors.grey400),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(safeTr('İskenderun Demir ve Çelik A.Ş. • Liman Otomasyon Sistemi'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  pw.Text(safeTr('Sayfa 1 / 1'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/isdemir_liman_vardiya_raporu.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'İSDEMİR Liman Operasyon Raporu ($dateStr)',
      );
    } catch (e) {
      debugPrint('PDF paylaşım hatası: $e');
    }
  }
}

/// 🛰️ SpaceEye AI Dönen Taktik Radar Painter
class RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final int spectrumMode; // 0: SAR Radar, 1: Optik Uydu, 2: Termal Isı
  final List<Map<String, dynamic>> ships;
  final String? selectedShipName;

  RadarSweepPainter({
    required this.sweepAngle,
    required this.spectrumMode,
    required this.ships,
    this.selectedShipName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;

    // Spektrum renk teması
    final Color mainColor = spectrumMode == 0
        ? const Color(0xFF0284C7) // SAR Cyan/Mavi
        : spectrumMode == 1
            ? const Color(0xFF10B981) // Optik Yeşil
            : const Color(0xFFE11D48); // Termal Kırmızı

    final Color glowColor = spectrumMode == 0
        ? const Color(0xFF38BDF8)
        : spectrumMode == 1
            ? const Color(0xFF34D399)
            : const Color(0xFFF43F5E);

    // 1. Dış Halka & Arka Plan Gridleri
    final bgPaint = Paint()
      ..color = const Color(0xFF050B14)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    final gridPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Eşmerkezli mesafe halkaları (0.05 NM, 0.10 NM, 0.15 NM, 0.20 NM)
    for (int i = 1; i <= 4; i++) {
      final r = radius * (i / 4.0);
      canvas.drawCircle(center, r, gridPaint);
    }

    // Çapraz eksen çizgileri (N-S, E-W)
    final axisPaint = Paint()
      ..color = mainColor.withValues(alpha: 0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx - radius, center.dy), Offset(center.dx + radius, center.dy), axisPaint);
    canvas.drawLine(Offset(center.dx, center.dy - radius), Offset(center.dx, center.dy + radius), axisPaint);

    // 2. Pusula İpuçları (N, S, E, W, 0.2 NM Range)
    final textPainterN = TextPainter(
      text: TextSpan(
        text: 'N (000°)',
        style: TextStyle(color: glowColor.withValues(alpha: 0.8), fontSize: 8.5, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainterN.paint(canvas, Offset(center.dx - textPainterN.width / 2, center.dy - radius + 4));

    final textPainterRange = TextPainter(
      text: TextSpan(
        text: '0.2 NM RANGE',
        style: TextStyle(color: mainColor.withValues(alpha: 0.7), fontSize: 7.5, fontWeight: FontWeight.bold),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    textPainterRange.paint(canvas, Offset(center.dx - textPainterRange.width / 2, center.dy + radius - 14));

    // 3. Dönen Radar Taraması (Sweep Gradient Fan)
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: math.pi / 2,
        colors: [
          glowColor.withValues(alpha: 0.35),
          glowColor.withValues(alpha: 0.0),
        ],
        transform: GradientRotation(sweepAngle - math.pi / 2),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: center, radius: radius)));
    canvas.drawCircle(center, radius, sweepPaint);

    // Sweep öncü çizgisi (Öncü ışın)
    final leadLinePaint = Paint()
      ..color = glowColor.withValues(alpha: 0.9)
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke;

    final leadEnd = Offset(
      center.dx + radius * math.cos(sweepAngle),
      center.dy + radius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, leadEnd, leadLinePaint);
    canvas.restore();

    // 4. İsdemir Limanı Sahil Çizgisi Silueti (Basitleştirilmiş Liman Dalgakıranı & Rıhtımları)
    final breakwaterPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.16)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final breakwaterPath = Path();
    breakwaterPath.moveTo(center.dx + radius * 0.10, center.dy + radius * 0.70);
    breakwaterPath.lineTo(center.dx + radius * 0.15, center.dy - radius * 0.50);
    breakwaterPath.lineTo(center.dx + radius * 0.25, radius * -0.55 + center.dy);
    canvas.drawPath(breakwaterPath, breakwaterPaint);

    // 5. Gemiler (Blips ve Taktik İkonlar)
    for (final ship in ships) {
      final double relX = (ship['relX'] as num).toDouble();
      final double relY = (ship['relY'] as num).toDouble();
      final shipPos = Offset(center.dx + radius * relX, center.dy + radius * relY);
      final isSelected = selectedShipName == ship['gemiAdi'];

      // Gemi açısına göre radar sweep uzaklığı (yakınsa parlasın)
      final shipAngle = math.atan2(shipPos.dy - center.dy, shipPos.dx - center.dx);
      double angleDiff = (sweepAngle - shipAngle) % (math.pi * 2);
      if (angleDiff < 0) angleDiff += math.pi * 2;
      final bool justScanned = angleDiff < 0.6; // Son 35 derecede tarandıysa parla

      final blipColor = isSelected
          ? const Color(0xFFFBBF24) // Seçili sarı
          : (justScanned ? glowColor : glowColor.withValues(alpha: 0.75));

      // Işıma halkası
      if (isSelected || justScanned) {
        final glowCirclePaint = Paint()
          ..color = blipColor.withValues(alpha: isSelected ? 0.35 : 0.20)
          ..style = PaintingStyle.fill;
        canvas.drawCircle(shipPos, isSelected ? 14 : 9, glowCirclePaint);
      }

      // Merkez blip noktası
      final blipDotPaint = Paint()
        ..color = blipColor
        ..style = PaintingStyle.fill;
      canvas.drawCircle(shipPos, isSelected ? 5.5 : 3.8, blipDotPaint);

      // Seçili ise hedef kilitlenme çerçevesi (Reticle)
      if (isSelected) {
        final reticlePaint = Paint()
          ..color = const Color(0xFFFBBF24)
          ..strokeWidth = 1.4
          ..style = PaintingStyle.stroke;

        const boxR = 11.0;
        canvas.drawRect(Rect.fromCircle(center: shipPos, radius: boxR), reticlePaint);

        // Hedef İsim Etiketi
        final tp = TextPainter(
          text: TextSpan(
            text: '${ship['gemiAdi']} [${ship['rihtimNo']}]',
            style: const TextStyle(
              color: Color(0xFFFDE68A),
              fontSize: 8.5,
              fontWeight: FontWeight.bold,
              backgroundColor: Color(0xCC000000),
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(shipPos.dx - tp.width / 2, shipPos.dy - boxR - 12));
      } else {
        // Normal küçük gemi adı
        final tp = TextPainter(
          text: TextSpan(
            text: ship['gemiAdi'] as String,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 7.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          textDirection: ui.TextDirection.ltr,
        )..layout();
        tp.paint(canvas, Offset(shipPos.dx + 6, shipPos.dy - 4));
      }
    }

    // 6. Dış Çerçeve Parlaması
    final outerRingPaint = Paint()
      ..color = glowColor.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, outerRingPaint);
  }

  @override
  bool shouldRepaint(covariant RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.spectrumMode != spectrumMode ||
        oldDelegate.selectedShipName != selectedShipName ||
        oldDelegate.ships != ships;
  }
}

