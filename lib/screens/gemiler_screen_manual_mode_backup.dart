import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

import '../utils/push_service.dart';
import '../utils/radio_sound_effects.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/industrial_animations.dart';
import '../widgets/glass_widgets.dart';

class GemilerScreen extends StatefulWidget {
  const GemilerScreen({super.key});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  String _currentUserName = 'İsdemir Saha Operatörü';
  String _selectedFilter = 'Tümü';
  int _activeTabIndex = 0; // 0: Rıhtım & Operasyonlar, 1: Liman Analitik & Rapor
  bool _soundEnabled = true;
  int _touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    RadioSoundEffects.init();
    _loadUserName();
    _loadSoundPreference();
  }

  Future<void> _loadUserName() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cihazId = prefs.getString('cihaz_id');
      if (cihazId != null) {
        final snap = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (snap.docs.isNotEmpty) {
          if (mounted) {
            setState(() {
              _currentUserName = snap.docs.first.data()['ad_soyad'] ?? 'İsdemir Saha Operatörü';
            });
          }
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

  @override
  void dispose() {
    _blinkController.dispose();
    super.dispose();
  }

  Color _getStatusColor(String durum) {
    switch (durum) {
      case 'Gemi Başlama Alındı':
        return const Color(0xFF10B981); // Emerald Green
      case 'Gemi Bitişte':
        return const Color(0xFFF59E0B); // Amber Orange
      case 'Gemi Bitti':
        return const Color(0xFF3B82F6); // High-voltage Blue
      case 'Limandan Ayrıldı':
        return const Color(0xFF94A3B8); // Muted Slate Gray
      default:
        return const Color(0xFF94A3B8);
    }
  }

  String _getStatusLabel(String durum) {
    switch (durum) {
      case 'Gemi Başlama Alındı':
        return 'Başladı';
      case 'Gemi Bitişte':
        return 'Bitişte';
      case 'Gemi Bitti':
        return 'Bitti';
      case 'Limandan Ayrıldı':
        return 'Ayrıldı';
      default:
        return durum;
    }
  }

  // --- HIZLI OPERASYON AŞAMASI İLERLETME ---
  Future<void> _advanceShipStage(String docId, Map<String, dynamic> data) async {
    _playSound('squelch');
    final currentStatus = data['durum'] ?? 'Gemi Başlama Alındı';
    String nextStatus;

    if (currentStatus == 'Gemi Başlama Alındı') {
      nextStatus = 'Gemi Bitişte';
    } else if (currentStatus == 'Gemi Bitişte') {
      nextStatus = 'Gemi Bitti';
    } else if (currentStatus == 'Gemi Bitti') {
      nextStatus = 'Limandan Ayrıldı';
    } else {
      nextStatus = 'Gemi Başlama Alındı';
    }

    try {
      await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
        'durum': nextStatus,
        'sonGuncelleme': FieldValue.serverTimestamp(),
        'guncelleyenKisi': _currentUserName,
      });

      _playSound('roger');

      // Amiri ve ekibi bilgilendir
      PushService.sendPushNotification(
        title: 'Gemi Durumu Güncellendi',
        content: '$_currentUserName: "${data['gemiAdi']}" gemisi "$nextStatus" aşamasına geçirildi.',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF161A22),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${data['gemiAdi']} durumu "$nextStatus" yapıldı.',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugPrint('Aşama ilerletme hatası: $e');
    }
  }

  // --- GEMİ SİLME ONAY MODALI ---
  void _confirmDeleteShip(String docId, String gemiAdi) {
    _playSound('squelch');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF161A22),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: const Color(0xFFE50914).withValues(alpha: 0.4)),
        ),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: Color(0xFFE50914)),
            const SizedBox(width: 10),
            const Text('Gemi Kaydını Sil', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          '"$gemiAdi" operasyon kaydını rıhtımdan silmek istediğinize emin misiniz?',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseFirestore.instance.collection('gemiler').doc(docId).delete();
              _playSound('tail');
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // --- RESMİ İSDEMİR LİMAN VARDİYA RAPORU (A4 PDF) ---
  Future<void> _generateAndSharePortReport(List<QueryDocumentSnapshot> allDocs) async {
    _playSound('roger');
    HapticFeedback.mediumImpact();

    final now = DateTime.now();
    final dateStr = DateFormat('dd.MM.yyyy HH:mm').format(now);
    final pdf = pw.Document();

    // Rıhtımlara göre gemi eşleştirmesi
    final Map<int, Map<String, dynamic>?> berthMap = {1: null, 2: null, 3: null, 4: null, 5: null};
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final rNo = int.tryParse(data['rihtimNo']?.toString() ?? '0');
      if (rNo != null && rNo >= 1 && rNo <= 5) {
        if (data['durum'] != 'Limandan Ayrıldı') {
          berthMap[rNo] = data;
        }
      }
    }

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // 1. Resmi Üst Başlık
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'İSDEMİR A.Ş. — LİMAN İŞLETME MÜDÜRLÜĞÜ',
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'RIHTIM 1-5 GEMİ VE YÜKLEME/TAHLİYE VARDİYA PUANTAJ RAPORU',
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('DOKÜMAN: İSD-LMN-VRD-2026/09', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text('TARİH: $dateStr', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColors.red900),
              pw.SizedBox(height: 12),

              // 2. Rapor Meta Özeti
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
                    pw.Text('Raporu Düzenleyen: $_currentUserName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Aktif Operasyon: ${allDocs.where((d) => d['durum'] != 'Limandan Ayrıldı').length} Gemi', style: const pw.TextStyle(fontSize: 10)),
                    pw.Text('Toplam Kayıt: ${allDocs.length} Gemi', style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 3. Rıhtım 1-5 Durum Çizelgesi
              pw.Text('1. RIHTIM 1-5 CANLI YANAŞMA VE KAPASİTE TABLOSU', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Rıhtım No', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Gemi Adı', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Yük Cinsi', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Operasyonel Durum', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Sorumlu Operatör', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  for (int r = 1; r <= 5; r++) ...[
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('$r. Rıhtım (R-$r)', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            berthMap[r]?['gemiAdi'] ?? 'BOŞ RIHTIM',
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: berthMap[r] != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: berthMap[r] != null ? PdfColors.black : PdfColors.grey600,
                            ),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(berthMap[r]?['yukCinsi'] ?? '—', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(berthMap[r]?['durum'] ?? 'Yanaşmaya Uygun', style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(berthMap[r]?['guncelleyenKisi'] ?? '—', style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 18),

              // 4. Tüm Gemi Operasyonları Detay Dökümü
              pw.Text('2. TÜM GEMİ OPERASYONLARI HAREKET LİSTESİ', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Gemi', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Rıhtım', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Yük', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Durum', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('İşlem Yapan', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  for (var doc in allDocs) ...[
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(doc['gemiAdi'] ?? '', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('R-${doc['rihtimNo'] ?? ''}', style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(doc['yukCinsi'] ?? '', style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(doc['durum'] ?? '', style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(doc['guncelleyenKisi'] ?? 'İsdemir', style: const pw.TextStyle(fontSize: 8.5))),
                      ],
                    ),
                  ],
                ],
              ),
              pw.Spacer(),

              // 5. Onay ve İmza Alanları
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Nöbetçi Rıhtım / Saha Amiri', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 140, height: 0.8, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('İmza / Tarih', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text('Liman İşletme Başmühendisi / Müdürü', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 160, height: 0.8, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text('Onay / Kaşe', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/isdemir_liman_vardiya_raporu_${now.millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: 'İSDEMİR A.Ş. Liman Rıhtım 1-5 Vardiya Raporu ($dateStr)',
        ),
      );
    } catch (e) {
      debugPrint('PDF paylaşım hatası: $e');
    }
  }

  // --- GEMİ EKLEME / DÜZENLEME MODAL FORMU ---
  void _showShipFormModal({String? docId, Map<String, dynamic>? existingData}) {
    _playSound('squelch');
    final nameCtrl = TextEditingController(text: existingData?['gemiAdi'] ?? '');
    String selectedRihtim = existingData?['rihtimNo']?.toString() ?? '1';
    String selectedDurum = existingData?['durum'] ?? 'Gemi Başlama Alındı';
    String selectedYukCinsi = existingData?['yukCinsi'] ?? 'Levha';

    final durumlar = [
      {'val': 'Gemi Başlama Alındı', 'label': 'Gemi Başlama Alındı', 'color': const Color(0xFF10B981)},
      {'val': 'Gemi Bitişte', 'label': 'Gemi Bitişte', 'color': const Color(0xFFF59E0B)},
      {'val': 'Gemi Bitti', 'label': 'Gemi Bitti', 'color': const Color(0xFF3B82F6)},
      {'val': 'Limandan Ayrıldı', 'label': 'Limandan Ayrıldı', 'color': const Color(0xFF94A3B8)},
    ];

    final rihtimlar = ['1', '2', '3', '4', '5'];
    final yukCinsleri = ['Levha', 'Slap', 'Bobin', 'Cüruf', 'Medkok', 'Kömür', 'Hurda', 'Kütük', 'Rulo'];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14181F),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                left: 20,
                right: 20,
                top: 14,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sürükleme Tutamacı
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    // Başlık
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE50914).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFFE50914).withValues(alpha: 0.3),
                            ),
                          ),
                          child: const HugeIcon(
                            icon: HugeIcons.strokeRoundedCargoShip,
                            color: Color(0xFFE50914),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              docId == null ? 'Yeni Gemi Operasyonu Başlat' : 'Gemi Operasyonunu Güncelle',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Operatör: $_currentUserName',
                              style: const TextStyle(
                                color: Colors.white38,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Gemi Adı
                    const Text(
                      'GEMİ ADI',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: nameCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        hintText: 'Örn: MV İSDEMİR-1',
                        hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.25)),
                        prefixIcon: const Icon(Icons.directions_boat_rounded, color: Colors.white54, size: 20),
                        filled: true,
                        fillColor: const Color(0xFF1D232C),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Rıhtım & Yük Cinsi 2 Kolon
                    Row(
                      children: [
                        // Rıhtım Seçimi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'RIHTIM NO',
                                style: TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedRihtim,
                                dropdownColor: const Color(0xFF1D232C),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1D232C),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                                  ),
                                ),
                                items: rihtimlar
                                    .map((r) => DropdownMenuItem(
                                          value: r,
                                          child: Text('$r. Rıhtım (R-$r)'),
                                        ))
                                    .toList(),
                                onChanged: (val) => setModalState(() => selectedRihtim = val!),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Yük Cinsi Seçimi
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'YÜK CİNSİ',
                                style: TextStyle(
                                  color: Color(0xFFE50914),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<String>(
                                initialValue: selectedYukCinsi,
                                dropdownColor: const Color(0xFF1D232C),
                                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF1D232C),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                                  ),
                                ),
                                items: yukCinsleri
                                    .map((y) => DropdownMenuItem(
                                          value: y,
                                          child: Text(y),
                                        ))
                                    .toList(),
                                onChanged: (val) => setModalState(() => selectedYukCinsi = val!),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Operasyonel Durum
                    const Text(
                      'OPERASYONEL DURUM',
                      style: TextStyle(
                        color: Color(0xFFE50914),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    DropdownButtonFormField<String>(
                      initialValue: selectedDurum,
                      dropdownColor: const Color(0xFF1D232C),
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: const Color(0xFF1D232C),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFE50914), width: 1.5),
                        ),
                      ),
                      items: durumlar.map((d) {
                        final dVal = d['val'] as String;
                        final dColor = d['color'] as Color;
                        return DropdownMenuItem<String>(
                          value: dVal,
                          child: Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: dColor,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(d['label'] as String),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setModalState(() => selectedDurum = val!),
                    ),
                    const SizedBox(height: 26),

                    // Kaydet Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: const LinearGradient(
                            colors: [Color(0xFFE50914), Color(0xFFB91C1C)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withValues(alpha: 0.35),
                              blurRadius: 14,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          onPressed: () async {
                            if (nameCtrl.text.trim().isEmpty) return;
                            _playSound('roger');
                            HapticFeedback.mediumImpact();

                            final data = {
                              'gemiAdi': nameCtrl.text.trim(),
                              'rihtimNo': selectedRihtim,
                              'durum': selectedDurum,
                              'yukCinsi': selectedYukCinsi,
                              'sonGuncelleme': FieldValue.serverTimestamp(),
                              'guncelleyenKisi': _currentUserName,
                            };

                            if (docId == null) {
                              data['ekleyenKisi'] = _currentUserName;
                              data['eklenmeTarihi'] = FieldValue.serverTimestamp();
                              await FirebaseFirestore.instance.collection('gemiler').add(data);
                            } else {
                              await FirebaseFirestore.instance.collection('gemiler').doc(docId).update(data);
                            }

                            PushService.sendPushNotification(
                              title: 'İsdemir Liman Operasyonu',
                              content: '$_currentUserName: "${nameCtrl.text.trim()}" gemisini $selectedRihtim. Rıhtıma ($selectedDurum) olarak işledi.',
                            );

                            if (context.mounted) Navigator.pop(context);
                          },
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                docId == null ? Icons.add_task_rounded : Icons.check_circle_outline_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                docId == null ? 'Operasyonu Başlat & Bildir' : 'Değişiklikleri Onayla',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0C0E12),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14181F),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white70, size: 20),
          onPressed: () {
            _playSound('squelch');
            Navigator.pop(context);
          },
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.3)),
              ),
              child: const HugeIcon(
                icon: HugeIcons.strokeRoundedAnchor,
                color: Color(0xFFE50914),
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'İSDEMİR LİMANI',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.3,
                  ),
                ),
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color(0xFF10B981),
                        boxShadow: [
                          BoxShadow(color: Color(0xFF10B981), blurRadius: 4, spreadRadius: 1),
                        ],
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'CANLI RADAR // RIHTIM 1-5',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          // Ses Açma / Kapatma Butonu
          IconButton(
            tooltip: _soundEnabled ? 'Telsiz Sesleri Açık' : 'Telsiz Sesleri Sessizde',
            icon: Icon(
              _soundEnabled ? Icons.volume_up_rounded : Icons.volume_off_rounded,
              color: _soundEnabled ? const Color(0xFF10B981) : Colors.white38,
              size: 22,
            ),
            onPressed: _toggleSound,
          ),
          // Filtreleri Sıfırla
          IconButton(
            tooltip: 'Filtreleri Sıfırla',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 22),
            onPressed: () {
              _playSound('squelch');
              setState(() {
                _selectedFilter = 'Tümü';
              });
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('gemiler')
            .orderBy('sonGuncelleme', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const ShipListSkeleton();
          }

          final allShips = snapshot.data?.docs ?? [];

          // Metrik Sayaçları
          final baslamaCount = allShips.where((d) => d['durum'] == 'Gemi Başlama Alındı').length;
          final bitisteCount = allShips.where((d) => d['durum'] == 'Gemi Bitişte').length;
          final bittiCount = allShips.where((d) => d['durum'] == 'Gemi Bitti').length;
          final ayrildiCount = allShips.where((d) => d['durum'] == 'Limandan Ayrıldı').length;

          // Dolu Rıhtım Sayısı (R-1 ile R-5 arası ve ayrılmamış)
          final Set<String> occupiedBerths = {};
          for (var doc in allShips) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['durum'] != 'Limandan Ayrıldı') {
              final r = data['rihtimNo']?.toString();
              if (r != null) occupiedBerths.add(r);
            }
          }
          final int emptyBerthCount = 5 - occupiedBerths.length;

          // Filtrelenmiş liste
          final filteredShips = _selectedFilter == 'Tümü'
              ? allShips
              : allShips.where((d) => d['durum'] == _selectedFilter).toList();

          return Column(
            children: [
              // 1. ÜST SEGMENT SEÇİCİ (Rıhtım & Operasyonlar vs Liman Analitiği)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFF161A22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _playSound('squelch');
                          setState(() => _activeTabIndex = 0);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTabIndex == 0 ? const Color(0xFFE50914) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.directions_boat_filled_rounded,
                                size: 16,
                                color: _activeTabIndex == 0 ? Colors.white : Colors.white54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Rıhtım & Operasyon',
                                style: TextStyle(
                                  color: _activeTabIndex == 0 ? Colors.white : Colors.white54,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          _playSound('squelch');
                          setState(() => _activeTabIndex = 1);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: _activeTabIndex == 1 ? const Color(0xFFE50914) : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.bar_chart_rounded,
                                size: 16,
                                color: _activeTabIndex == 1 ? Colors.white : Colors.white54,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Analitik & A4 Rapor',
                                style: TextStyle(
                                  color: _activeTabIndex == 1 ? Colors.white : Colors.white54,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.bold,
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

              // 2. ANA İÇERİK (SEÇİLEN SEKME)
              Expanded(
                child: _activeTabIndex == 0
                    ? _buildOperationsTab(
                        allShips: allShips,
                        filteredShips: filteredShips,
                        baslamaCount: baslamaCount,
                        bitisteCount: bitisteCount,
                        bittiCount: bittiCount,
                        ayrildiCount: ayrildiCount,
                        emptyBerthCount: emptyBerthCount,
                      )
                    : _buildAnalyticsTab(
                        allShips: allShips,
                        occupiedBerths: occupiedBerths,
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: const Color(0xFFE50914),
        elevation: 6,
        onPressed: () => _showShipFormModal(),
        tooltip: 'Gemi Yanaştır / Operasyon Başlat',
        icon: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
        label: const Text(
          'Gemi Yanaştır',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.4),
        ),
      ),
    );
  }

  // =========================================================================
  // 1. SEKME: RIHTIM VE GEMİ OPERASYONLARI
  // =========================================================================
  Widget _buildOperationsTab({
    required List<QueryDocumentSnapshot> allShips,
    required List<QueryDocumentSnapshot> filteredShips,
    required int baslamaCount,
    required int bitisteCount,
    required int bittiCount,
    required int ayrildiCount,
    required int emptyBerthCount,
  }) {
    return CustomScrollView(
      slivers: [
        // KPI TELEMETRİ SAYAÇLARI (AnimatedFlipCounter)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Row(
              children: [
                Expanded(
                  child: _buildFlipStatTile(
                    label: 'Başladı',
                    count: baslamaCount,
                    color: const Color(0xFF10B981),
                    icon: HugeIcons.strokeRoundedAnchor,
                    filterKey: 'Gemi Başlama Alındı',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFlipStatTile(
                    label: 'Bitişte',
                    count: bitisteCount,
                    color: const Color(0xFFF59E0B),
                    icon: HugeIcons.strokeRoundedCargoShip,
                    filterKey: 'Gemi Bitişte',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFlipStatTile(
                    label: 'Bitti',
                    count: bittiCount,
                    color: const Color(0xFF3B82F6),
                    icon: HugeIcons.strokeRoundedCheckmarkCircle02,
                    filterKey: 'Gemi Bitti',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFlipStatTile(
                    label: 'Boş Rıhtım',
                    count: emptyBerthCount,
                    color: const Color(0xFF38BDF8),
                    icon: HugeIcons.strokeRoundedSailboatOffshore,
                    filterKey: 'Tümü',
                  ),
                ),
              ],
            ),
          ),
        ),

        // CANLI RIHTIM DİJİTAL İKİZİ (PortBerthSchemeWidget)
        SliverToBoxAdapter(
          child: PortBerthSchemeWidget(
            ships: allShips.map((s) => s.data() as Map<String, dynamic>).toList(),
            onShipTap: (shipData) {
              _playSound('squelch');
              final matchingDoc = allShips.firstWhere(
                (s) => (s.data() as Map)['gemiAdi'] == shipData['gemiAdi'],
              );
              _showShipFormModal(docId: matchingDoc.id, existingData: shipData);
            },
            onEmptyRihtimTap: (rihtimNo) {
              _playSound('squelch');
              _showShipFormModal(existingData: {'rihtimNo': rihtimNo.toString()});
            },
          ),
        ),

        // YATAY FİLTRELEME ÇİPLERİ
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: SizedBox(
              height: 38,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildFilterPill(
                    title: 'Tümü',
                    count: allShips.length,
                    filterKey: 'Tümü',
                    accentColor: const Color(0xFF6366F1),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    title: '🟢 Başladı',
                    count: baslamaCount,
                    filterKey: 'Gemi Başlama Alındı',
                    accentColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    title: '🟡 Bitişte',
                    count: bitisteCount,
                    filterKey: 'Gemi Bitişte',
                    accentColor: const Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    title: '🔵 Bitti',
                    count: bittiCount,
                    filterKey: 'Gemi Bitti',
                    accentColor: const Color(0xFF3B82F6),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    title: '⚪ Ayrıldı',
                    count: ayrildiCount,
                    filterKey: 'Limandan Ayrıldı',
                    accentColor: const Color(0xFF94A3B8),
                  ),
                ],
              ),
            ),
          ),
        ),

        // GEMİ KARTLARI LİSTESİ VEYA BOŞ DURUM
        if (filteredShips.isEmpty)
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                color: const Color(0xFF14181F),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
              ),
              child: Column(
                children: [
                  const LottieCargoShipWidget(width: 130, height: 80),
                  const SizedBox(height: 14),
                  Text(
                    'KAYITLI GEMİ BULUNAMADI',
                    style: GoogleFonts.orbitron(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Seçili filtreye uygun operasyon kaydı yok.',
                    style: TextStyle(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final ship = filteredShips[index];
                  final data = ship.data() as Map<String, dynamic>;
                  return _buildModernShipCard(ship.id, data, index);
                },
                childCount: filteredShips.length,
              ),
            ),
          ),

        const SliverToBoxAdapter(child: SizedBox(height: 85)),
      ],
    );
  }

  // =========================================================================
  // 2. SEKME: LİMAN ANALİTİK & RESMİ A4 VARDİYA RAPORU
  // =========================================================================
  Widget _buildAnalyticsTab({
    required List<QueryDocumentSnapshot> allShips,
    required Set<String> occupiedBerths,
  }) {
    // Yük cinslerine göre adetler
    final Map<String, int> cargoCounts = {};
    for (var doc in allShips) {
      final y = doc['yukCinsi']?.toString() ?? 'Diğer';
      cargoCounts[y] = (cargoCounts[y] ?? 0) + 1;
    }

    final int occupiedCount = occupiedBerths.length;
    final double occupancyRate = (occupiedCount / 5.0) * 100;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. A4 RESMİ VARDİYA RAPORU BANNER'I
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF38BDF8), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Resmi Liman Vardiya Raporu',
                        style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Rıhtım 1-5 puantajını A4 PDF olarak paylaş',
                        style: TextStyle(color: Colors.white60, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  ),
                  onPressed: () => _generateAndSharePortReport(allShips),
                  icon: const Icon(Icons.share_rounded, size: 16),
                  label: const Text('Rapor Al', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                ),
              ],
            ),
          ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 18),

          // 2. RIHTIM DOLULUK KAPASİTE GÖSTERGESİ (Gauge / Ring)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF14181F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.anchor_rounded, color: Color(0xFF10B981), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'RIHTIM DOLULUK KAPASİTESİ',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '$occupiedCount / 5 Rıhtım Dolu',
                      style: const TextStyle(color: Color(0xFF10B981), fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    // Donut Chart
                    SizedBox(
                      width: 100,
                      height: 100,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 36,
                              startDegreeOffset: -90,
                              sections: [
                                PieChartSectionData(
                                  value: occupiedCount.toDouble(),
                                  color: const Color(0xFF10B981),
                                  radius: 12,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: (5 - occupiedCount).toDouble(),
                                  color: const Color(0xFF1E293B),
                                  radius: 10,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '%${occupancyRate.toStringAsFixed(0)}',
                                style: GoogleFonts.orbitron(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const Text('Kapasite', style: TextStyle(color: Colors.white38, fontSize: 9)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 20),
                    // Rıhtım Açıklama Barları
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (int r = 1; r <= 5; r++) ...[
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: occupiedBerths.contains(r.toString())
                                        ? const Color(0xFF10B981)
                                        : Colors.white24,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$r. Rıhtım:',
                                  style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  occupiedBerths.contains(r.toString()) ? 'YANAŞIK GEMİ VAR' : 'BOŞ',
                                  style: TextStyle(
                                    color: occupiedBerths.contains(r.toString()) ? const Color(0xFF10B981) : Colors.white38,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            if (r < 5) const SizedBox(height: 5),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 18),

          // 3. YÜK CİNSİ DAĞILIMI (fl_chart BarChart)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFF14181F),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.category_rounded, color: Color(0xFFF59E0B), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'YÜK CİNSİ DAĞILIMI',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Toplam ${cargoCounts.length} Kategori',
                      style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                if (cargoCounts.isEmpty)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text('Veri bulunamadı.', style: TextStyle(color: Colors.white38)),
                    ),
                  )
                else
                  SizedBox(
                    height: 180,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: (cargoCounts.values.fold(0, (max, v) => v > max ? v : max) + 1).toDouble(),
                        barTouchData: BarTouchData(
                          enabled: true,
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => const Color(0xFF1E293B),
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final key = cargoCounts.keys.elementAt(group.x.toInt());
                              return BarTooltipItem(
                                '$key\n',
                                const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                children: [
                                  TextSpan(
                                    text: '${rod.toY.toInt()} Gemi',
                                    style: const TextStyle(color: Color(0xFFF59E0B), fontWeight: FontWeight.w700),
                                  ),
                                ],
                              );
                            },
                          ),
                          touchCallback: (event, response) {
                            setState(() {
                              if (response?.spot != null && event is! FlTapUpEvent) {
                                _touchedBarIndex = response!.spot!.touchedBarGroupIndex;
                              } else {
                                _touchedBarIndex = -1;
                              }
                            });
                          },
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < cargoCounts.keys.length) {
                                  final title = cargoCounts.keys.elementAt(idx);
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6.0),
                                    child: Text(
                                      title.length > 5 ? '${title.substring(0, 5)}..' : title,
                                      style: TextStyle(
                                        color: _touchedBarIndex == idx ? const Color(0xFFF59E0B) : Colors.white60,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: Colors.white.withValues(alpha: 0.05),
                            strokeWidth: 1,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(cargoCounts.length, (idx) {
                          final count = cargoCounts.values.elementAt(idx);
                          return BarChartGroupData(
                            x: idx,
                            barRods: [
                              BarChartRodData(
                                toY: count.toDouble(),
                                color: _touchedBarIndex == idx ? const Color(0xFFF59E0B) : const Color(0xFF38BDF8),
                                width: 18,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                                backDrawRodData: BackgroundBarChartRodData(
                                  show: true,
                                  toY: (cargoCounts.values.fold(0, (max, v) => v > max ? v : max) + 1).toDouble(),
                                  color: Colors.white.withValues(alpha: 0.03),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
              ],
            ),
          ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.1, end: 0),

          const SizedBox(height: 85),
        ],
      ),
    );
  }

  // =========================================================================
  // YARDIMCI BİLEŞENLER
  // =========================================================================

  Widget _buildFlipStatTile({
    required String label,
    required int count,
    required Color color,
    required List<List<dynamic>> icon,
    required String filterKey,
  }) {
    final bool isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        _playSound('squelch');
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilter = isSelected ? 'Tümü' : filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : const Color(0xFF14181F),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.55) : Colors.white.withValues(alpha: 0.06),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.22),
                    blurRadius: 10,
                    spreadRadius: 1,
                  )
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: HugeIcon(
                icon: icon,
                color: color,
                size: 15,
              ),
            ),
            const SizedBox(height: 6),
            AnimatedFlipCounter(
              value: count,
              textStyle: GoogleFonts.orbitron(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? color : Colors.white54,
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterPill({
    required String title,
    required int count,
    required String filterKey,
    required Color accentColor,
  }) {
    final bool isSelected = _selectedFilter == filterKey;
    return GestureDetector(
      onTap: () {
        _playSound('squelch');
        HapticFeedback.selectionClick();
        setState(() {
          _selectedFilter = filterKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.22) : const Color(0xFF161A22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08),
            width: isSelected ? 1.3 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 0.5,
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected ? accentColor.withValues(alpha: 0.4) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                count.toString(),
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.white54,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- MODERN GEMİ KARTI ---
  Widget _buildModernShipCard(String docId, Map<String, dynamic> data, int index) {
    final durum = data['durum'] ?? 'Bilinmiyor';
    final color = _getStatusColor(durum);
    final statusLabel = _getStatusLabel(durum);

    return StaggeredEntrance(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF14181F),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.07),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ÜST BAŞLIK: DURUM LEDİ + GEMİ ADI + RIHTIM ROZETİ
              Row(
                children: [
                  // Yanıp Sönen Durum Ledi
                  AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, child) {
                      final isDeparted = durum == 'Limandan Ayrıldı';
                      final pulseVal = isDeparted ? 1.0 : (0.4 + _blinkController.value * 0.6);
                      return Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: pulseVal),
                          boxShadow: isDeparted
                              ? null
                              : [
                                  BoxShadow(
                                    color: color.withValues(alpha: _blinkController.value * 0.7),
                                    blurRadius: 8,
                                    spreadRadius: 2,
                                  ),
                                ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Gemi Adı
                  Expanded(
                    child: Text(
                      data['gemiAdi'] ?? 'Bilinmeyen Gemi',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.4,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Rıhtım Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Text(
                      'R-${data['rihtimNo'] ?? '?'}',
                      style: const TextStyle(
                        color: Color(0xFF38BDF8),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),

                  // Durum Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 2. 4 ADIMLI GÖRSEL OPERASYON STEPPER'I (Tıklanabilir İlerleme)
              _buildOperationStepper(durum, color, () => _advanceShipStage(docId, data)),
              const SizedBox(height: 14),

              // 3. ORTA ALAN: LOTTİE GEMİ + 3 SÜTUNLU MİKRO BİLGİ BADGELERİ
              Row(
                children: [
                  // Lottie Gemi Çerçevesi
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0C0E12),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.15),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: LottieCargoShipWidget(
                          width: 42,
                          height: 42,
                          animate: durum != 'Limandan Ayrıldı',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // 3 Mikro Bilgi Kutusu (Rıhtım, Yük Cinsi, Operatör)
                  Expanded(
                    child: Row(
                      children: [
                        // Rıhtım Bilgisi
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedAnchor,
                            iconColor: const Color(0xFF60A5FA),
                            label: 'RIHTIM',
                            value: '${data['rihtimNo'] ?? '?'}. Rıhtım',
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Yük Cinsi Bilgisi
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedPackage,
                            iconColor: const Color(0xFFF59E0B),
                            label: 'YÜK',
                            value: data['yukCinsi'] ?? '-',
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Operatör Bilgisi
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedUser,
                            iconColor: const Color(0xFF34D399),
                            label: 'OPERATÖR',
                            value: (data['guncelleyenKisi'] ?? 'İsdemir').toString().split(' ').first,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 4. ALT EYLEM ÇUBUĞU (Liman Vinci + Düzenle / Sil Butonları)
              Row(
                children: [
                  IndustrialCraneWidget(
                    isOperating: durum == 'Gemi Başlama Alındı' || durum == 'Gemi Bitişte',
                    themeColor: color,
                    compact: true,
                  ),
                  const Spacer(),
                  // Aşama İlerlet Butonu
                  if (durum != 'Limandan Ayrıldı') ...[
                    TextButton.icon(
                      onPressed: () => _advanceShipStage(docId, data),
                      icon: const Icon(Icons.fast_forward_rounded, color: Color(0xFF10B981), size: 16),
                      label: const Text(
                        'Aşama Atla',
                        style: TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        backgroundColor: const Color(0xFF10B981).withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Düzenle Butonu
                  IconButton(
                    tooltip: 'Düzenle',
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedEdit02,
                      color: Colors.white70,
                      size: 16,
                    ),
                    onPressed: () => _showShipFormModal(docId: docId, existingData: data),
                  ),
                  // Sil Butonu
                  IconButton(
                    tooltip: 'Sil',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                    onPressed: () => _confirmDeleteShip(docId, data['gemiAdi'] ?? 'Gemi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn(duration: 350.ms, delay: (index * 40).ms).slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic);
  }

  // 4 Aşamalı Taktik Operasyon Stepper'ı
  Widget _buildOperationStepper(String durum, Color themeColor, VoidCallback onAdvance) {
    int activeStep = 0;
    if (durum == 'Gemi Başlama Alındı') {
      activeStep = 1;
    } else if (durum == 'Gemi Bitişte') {
      activeStep = 2;
    } else if (durum == 'Gemi Bitti') {
      activeStep = 2;
    } else if (durum == 'Limandan Ayrıldı') {
      activeStep = 3;
    }

    final steps = ['Yanaştı', 'Başlama', 'Bitişte', 'Ayrıldı'];

    return GestureDetector(
      onTap: onAdvance,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: List.generate(steps.length, (idx) {
            final isCompleted = idx < activeStep || (idx == 3 && durum == 'Limandan Ayrıldı');
            final isCurrent = idx == activeStep && durum != 'Limandan Ayrıldı';

            return Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isCompleted
                                    ? themeColor
                                    : (isCurrent ? themeColor.withValues(alpha: 0.25) : Colors.white10),
                                border: Border.all(
                                  color: isCurrent || isCompleted ? themeColor : Colors.white24,
                                  width: isCurrent ? 2 : 1,
                                ),
                              ),
                              child: isCompleted
                                  ? const Icon(Icons.check, size: 9, color: Colors.white)
                                  : (isCurrent
                                      ? Center(
                                          child: Container(
                                            width: 5,
                                            height: 5,
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: themeColor,
                                            ),
                                          ),
                                        )
                                      : null),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          steps[idx],
                          style: TextStyle(
                            color: isCurrent
                                ? Colors.white
                                : (isCompleted ? Colors.white70 : Colors.white30),
                            fontSize: 9.5,
                            fontWeight: isCurrent ? FontWeight.w800 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (idx < steps.length - 1)
                    Container(
                      width: 18,
                      height: 1.5,
                      margin: const EdgeInsets.only(bottom: 14),
                      color: idx < activeStep ? themeColor.withValues(alpha: 0.7) : Colors.white12,
                    ),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }

  Widget _buildMicroBadge({
    required List<List<dynamic>> icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: iconColor, size: 10),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}