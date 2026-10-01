import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/user_model.dart';
import '../utils/pdf_font_helper.dart';
import '../widgets/glass_widgets.dart';

enum MesaiType { normal, bayram }

class MesaiRecord {
  final String id;
  final DateTime date;
  final DateTime submitDate;
  final MesaiType type;
  final String note;

  MesaiRecord({
    required this.id,
    required this.date,
    required this.submitDate,
    required this.type,
    this.note = '',
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'submitDate': submitDate.toIso8601String(),
      'type': type.index,
      'note': note,
    };
  }

  factory MesaiRecord.fromJson(Map<String, dynamic> json) {
    return MesaiRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      submitDate: DateTime.parse(json['submitDate']),
      type: MesaiType.values[json['type']],
      note: json['note'] ?? '',
    );
  }
}

class MesaiScreen extends StatefulWidget {
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final double normalMesaiRate;
  final double bayramMesaiRate;
  final Function(int, int) onMesaiChanged;
  final VoidCallback? onBackToHome;
  final UserModel? user;

  const MesaiScreen({
    super.key,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.normalMesaiRate,
    required this.bayramMesaiRate,
    required this.onMesaiChanged,
    this.onBackToHome,
    this.user,
  });

  @override
  State<MesaiScreen> createState() => _MesaiScreenState();
}

class _MesaiScreenState extends State<MesaiScreen> with TickerProviderStateMixin {
  final List<MesaiRecord> _records = [];
  int _selectedFilterIndex = 0; // 0 = Tümü, 1 = Normal, 2 = Bayram
  int _simulatedExtraDays = 0; // Canlı Hakediş Simülatörü
  bool _isGeneratingPdf = false;
  int _selectedAiTab = 0; // 0: OptaPay Net Hakediş, 1: LexGuard 270s Kota, 2: Turnike & Puantaj

  // 🌌 Apple VisionOS Aurora Arka Plan Animasyon Kontrolcüsü
  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

    _loadRecords();
  }

  @override
  void dispose() {
    _auroraController.dispose();
    super.dispose();
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('mesai_records');

    if (recordsJson != null) {
      final List<dynamic> decoded = json.decode(recordsJson);
      setState(() {
        _records.clear();
        _records.addAll(decoded.map((e) => MesaiRecord.fromJson(e)).toList());
        _records.sort((a, b) => b.date.compareTo(a.date));
      });
      _notifyParent();
    } else {
      _initializeDummyRecords();
      _saveRecords();
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('mesai_records', encoded);
  }

  void _initializeDummyRecords() {
    DateTime now = DateTime.now();
    for (int i = 0; i < widget.normalMesaiGun; i++) {
      _records.add(MesaiRecord(
        id: 'n_$i',
        date: now.subtract(Duration(days: i + 1)),
        submitDate: now,
        type: MesaiType.normal,
        note: 'Saha operasyon mesaisi',
      ));
    }
    for (int i = 0; i < widget.bayramMesaiGun; i++) {
      _records.add(MesaiRecord(
        id: 'b_$i',
        date: now.subtract(Duration(days: i + 10)),
        submitDate: now,
        type: MesaiType.bayram,
        note: 'Resmi bayram nöbet mesaisi',
      ));
    }

    _records.sort((a, b) => b.date.compareTo(a.date));
  }

  void _notifyParent() {
    int normal = _records.where((r) => r.type == MesaiType.normal).length;
    int bayram = _records.where((r) => r.type == MesaiType.bayram).length;
    widget.onMesaiChanged(normal, bayram);
  }

  void _removeRecord(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _records.removeWhere((r) => r.id == id);
    });
    _saveRecords();
    _notifyParent();
  }

  void _addRecordNow(MesaiType type) {
    HapticFeedback.lightImpact();
    setState(() {
      _records.add(MesaiRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        submitDate: DateTime.now(),
        type: type,
        note: type == MesaiType.normal ? 'Hızlı Normal Mesai' : 'Hızlı Bayram Mesaisi',
      ));
      _records.sort((a, b) => b.date.compareTo(a.date));
    });
    _saveRecords();
    _notifyParent();
  }

  void _removeLatestRecord(MesaiType type) {
    HapticFeedback.lightImpact();
    setState(() {
      final idx = _records.indexWhere((r) => r.type == type);
      if (idx != -1) {
        _records.removeAt(idx);
      }
    });
    _saveRecords();
    _notifyParent();
  }

  // 📅 VisionOS Tarih Seçerek Mesai Ekleme Modalı
  Future<void> _showAddDatePickerModal(MesaiType type) async {
    HapticFeedback.lightImpact();
    DateTime selectedDate = DateTime.now();
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isNormal = type == MesaiType.normal;
            final themeColor = isNormal ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: _buildVisionOSSheetContainer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 44,
                        height: 4.5,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: themeColor.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: themeColor.withValues(alpha: 0.35)),
                              ),
                              child: Icon(
                                isNormal ? Icons.work_history_rounded : Icons.celebration_rounded,
                                color: themeColor,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isNormal ? 'Normal Mesai Girişi' : 'Bayram Mesaisi Girişi',
                                  style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.bold, color: Colors.white),
                                ),
                                Text(
                                  isNormal ? '1.5x Katsayı • 8 Saat' : '2.0x Katsayı • Çift Yevmiye',
                                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: Colors.white70),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    Text('Mesai Tarihi', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFCBD5E1))),
                    const SizedBox(height: 8),

                    // Hızlı Gün Seçimi ve Takvim Butonu
                    Row(
                      children: [
                        _buildQuickDayPill(
                          'Bugün',
                          DateTime.now(),
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                          themeColor,
                        ),
                        const SizedBox(width: 8),
                        _buildQuickDayPill(
                          'Dün',
                          DateTime.now().subtract(const Duration(days: 1)),
                          selectedDate,
                          (d) => setModalState(() => selectedDate = d),
                          themeColor,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: BouncyTap(
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: selectedDate,
                                firstDate: DateTime(DateTime.now().year - 1),
                                lastDate: DateTime.now(),
                                builder: (context, child) {
                                  return Theme(
                                    data: ThemeData.dark().copyWith(
                                      colorScheme: ColorScheme.dark(
                                        primary: themeColor,
                                        surface: const Color(0xFF101420),
                                      ),
                                    ),
                                    child: child!,
                                  );
                                },
                              );
                              if (picked != null) {
                                setModalState(() => selectedDate = picked);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.06),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.calendar_month_rounded, color: Colors.white70, size: 16),
                                  const SizedBox(width: 6),
                                  Text(
                                    DateFormat('dd.MM.yyyy').format(selectedDate),
                                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    Text('Açıklama / Görev Notu (İsteğe Bağlı)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: const Color(0xFFCBD5E1))),
                    const SizedBox(height: 8),
                    TextField(
                      controller: noteController,
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Örn: Rıhtım gemi tahliyesi ek vardiyası...',
                        hintStyle: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: themeColor, width: 1.5)),
                      ),
                    ),

                    const SizedBox(height: 22),

                    // Onay Butonu
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: themeColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                        onPressed: () {
                          HapticFeedback.mediumImpact();
                          setState(() {
                            _records.add(MesaiRecord(
                              id: DateTime.now().millisecondsSinceEpoch.toString(),
                              date: selectedDate,
                              submitDate: DateTime.now(),
                              type: type,
                              note: noteController.text.trim().isNotEmpty
                                  ? noteController.text.trim()
                                  : (isNormal ? 'Normal Mesai' : 'Bayram Mesaisi'),
                            ));
                            _records.sort((a, b) => b.date.compareTo(a.date));
                          });
                          _saveRecords();
                          _notifyParent();
                          Navigator.pop(ctx);
                        },
                        child: Text('Mesaiyi Kaydet', style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
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

  Widget _buildQuickDayPill(String title, DateTime day, DateTime currentSelected, Function(DateTime) onSelect, Color themeColor) {
    final bool isSelected = day.year == currentSelected.year && day.month == currentSelected.month && day.day == currentSelected.day;
    return BouncyTap(
      onTap: () => onSelect(day),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? themeColor.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? themeColor : Colors.white.withValues(alpha: 0.12), width: 1.2),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  // ── 📄 A4 Resmi Mesai Puantaj Cetveli PDF Çıktısı ──
  Future<void> _generateAndShareMesaiPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfTheme = await PdfFontHelper.getTheme();
      final pdf = pw.Document(theme: pdfTheme);
      final now = DateTime.now();
      final months = ['', 'Ocak', 'Subat', 'Mart', 'Nisan', 'Mayis', 'Haziran', 'Temmuz', 'Agustos', 'Eylul', 'Ekim', 'Kasim', 'Aralik'];

      final int normalCount = _records.where((r) => r.type == MesaiType.normal).length;
      final int bayramCount = _records.where((r) => r.type == MesaiType.bayram).length;
      final double normalTotal = normalCount * widget.normalMesaiRate;
      final double bayramTotal = bayramCount * widget.bayramMesaiRate;
      final double totalOvertime = normalTotal + bayramTotal;

      List<List<String>> tableData = [];
      for (int i = 0; i < _records.length; i++) {
        final r = _records[i];
        final isNormal = r.type == MesaiType.normal;
        tableData.add([
          '${i + 1}',
          DateFormat('dd.MM.yyyy').format(r.date),
          isNormal ? 'Normal Mesai (1.5x)' : 'Bayram Mesaisi (2.0x)',
          '8 Saat',
          'TL ${(isNormal ? widget.normalMesaiRate : widget.bayramMesaiRate).toStringAsFixed(0)}',
          r.note.isNotEmpty ? r.note : '-',
        ]);
      }

      final userName = widget.user != null ? '${widget.user!.firstName} ${widget.user!.lastName}' : 'ISDEMIR Personeli';

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('ISKENDERUN DEMIR VE CELIK A.S.', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF881337))),
                        pw.SizedBox(height: 2),
                        pw.Text('RESMI AYLIK PERSONEL EK MESAI CETVELI (VISION AI)', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Text('${months[now.month]} ${now.year}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Personel: $userName', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.Text('Tanzim Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Container(height: 1.5, color: const PdfColor.fromInt(0xFF881337)),
                pw.SizedBox(height: 12),
              ],
            );
          },
          build: (context) {
            return [
              pw.TableHelper.fromTextArray(
                headers: ['No', 'Calisilan Tarih', 'Mesai Turu', 'Sure', 'Birim Ucret', 'Gorev / Aciklama'],
                data: tableData.isEmpty
                    ? [['-', '-', 'Kayitli mesai bulunmuyor', '-', '-', '-']]
                    : tableData,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
                cellHeight: 20,
                cellStyle: const pw.TextStyle(fontSize: 8.5),
                cellAlignments: {
                  0: pw.Alignment.center,
                  1: pw.Alignment.center,
                  2: pw.Alignment.centerLeft,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerRight,
                  5: pw.Alignment.centerLeft,
                },
              ),
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8FAFC),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  border: pw.Border.all(color: PdfColors.grey300),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                  children: [
                    pw.Text('Normal Mesai: $normalCount Gun (TL ${normalTotal.toStringAsFixed(0)})', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFDC2626))),
                    pw.Text('Bayram Mesaisi: $bayramCount Gun (TL ${bayramTotal.toStringAsFixed(0)})', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD97706))),
                    pw.Text('Toplam Ek Kazanc: TL ${totalOvertime.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF059669))),
                  ],
                ),
              ),
              pw.SizedBox(height: 36),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    children: [
                      pw.Text('Calisan Personel', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 25),
                      pw.Text(userName, style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('(Imza)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    children: [
                      pw.Text('Vardiya Amiri / Formen', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 25),
                      pw.Text('Kontrol & Onay', style: const pw.TextStyle(fontSize: 8.5)),
                      pw.Text('(Kase / Imza)', style: pw.TextStyle(fontSize: 8, fontStyle: pw.FontStyle.italic, color: PdfColors.grey600)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Text(
                'Bu belge ISDEMIR Personel Bilgi Sistemi uzerinden elektronik ortamda uretilmis olup, bordro hakedis odemeleri amir onayina tabidir.',
                style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
              ),
            ];
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Isdemir_Mesai_Raporu_${now.year}_${now.month}.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${months[now.month]} ${now.year} İSDEMİR Mesai Bildirim Çizelgesi',
        ),
      );
    } catch (e) {
      debugPrint('Mesai PDF Hatasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    int currentNormalCount = _records.where((r) => r.type == MesaiType.normal).length;
    int currentBayramCount = _records.where((r) => r.type == MesaiType.bayram).length;

    final double normalKazanc = currentNormalCount * widget.normalMesaiRate;
    final double bayramKazanc = currentBayramCount * widget.bayramMesaiRate;
    final double totalKazanc = normalKazanc + bayramKazanc;
    final int totalHours = (currentNormalCount + currentBayramCount) * 8;

    List<MesaiRecord> displayedRecords = _records;
    if (_selectedFilterIndex == 1) {
      displayedRecords = _records.where((r) => r.type == MesaiType.normal).toList();
    } else if (_selectedFilterIndex == 2) {
      displayedRecords = _records.where((r) => r.type == MesaiType.bayram).toList();
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF07090E),
        body: Stack(
          children: [
            // 🌌 1. Apple VisionOS Ambient Aurora Arka Planı
            _buildAnimatedAuroraCanvas(),

            // 🌟 2. Ön Plan Kaydırılabilir Cam Katmanları
            SafeArea(
              top: false,
              bottom: true,
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🌟 VisionOS Spatial Floating Top Bar
                    _buildTopSpatialGlassBar(),

                    const SizedBox(height: 14),

                    // 💎 VisionOS Titanium Emerald Vault Hero (Toplam Kazanç Kapsülü)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionEmeraldVaultHero(totalKazanc, currentNormalCount + currentBayramCount, totalHours)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.05, end: 0, curve: Curves.easeOutCubic),
                    ),

                    const SizedBox(height: 16),

                    // ⚡ VisionOS Hızlı Mesai Giriş Kapsülleri (Normal & Bayram)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildVisionMesaiStepperCard(
                              title: 'Normal Mesai',
                              multiplierText: '1.5x Katsayı',
                              rateText: '₺${widget.normalMesaiRate.toStringAsFixed(0)} / gün',
                              days: currentNormalCount,
                              totalValue: normalKazanc,
                              accentColor: const Color(0xFFEF4444),
                              icon: Icons.work_history_rounded,
                              onIncrement: () => _addRecordNow(MesaiType.normal),
                              onDecrement: () => _removeLatestRecord(MesaiType.normal),
                              onPickDate: () => _showAddDatePickerModal(MesaiType.normal),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _buildVisionMesaiStepperCard(
                              title: 'Bayram Mesaisi',
                              multiplierText: '2.0x Çift',
                              rateText: '₺${widget.bayramMesaiRate.toStringAsFixed(0)} / gün',
                              days: currentBayramCount,
                              totalValue: bayramKazanc,
                              accentColor: const Color(0xFFF59E0B),
                              icon: Icons.celebration_rounded,
                              onIncrement: () => _addRecordNow(MesaiType.bayram),
                              onDecrement: () => _removeLatestRecord(MesaiType.bayram),
                              onPickDate: () => _showAddDatePickerModal(MesaiType.bayram),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 🧠 VisionOS AI Super-Cockpit Adası (OptaPay™ & LexGuard™)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionOptaPayAiCockpit(
                        totalKazanc: totalKazanc,
                        normalCount: currentNormalCount,
                        bayramCount: currentBayramCount,
                        totalHours: totalHours,
                      ),
                    ),

                    const SizedBox(height: 18),

                    // 🧮 VisionOS Bento Kazanç Simülatörü
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionSimulatorBentoCard(totalKazanc),
                    ),

                    const SizedBox(height: 22),

                    // 📜 VisionOS Geçmiş Mesailer Listesi
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionRecordsSection(displayedRecords, currentNormalCount, currentBayramCount),
                    ),

                    const SizedBox(height: 16),

                    // 📄 VisionOS A4 PDF Puantaj Cetveli Paylaşım Barı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionPdfShareActionBar(),
                    ),

                    const SizedBox(height: 50),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🌌 Apple VisionOS Ambient Aurora Canvas
  Widget _buildAnimatedAuroraCanvas() {
    return AnimatedBuilder(
      animation: _auroraController,
      builder: (context, child) {
        final t = _auroraController.value;

        return Stack(
          children: [
            Container(color: const Color(0xFF07090E)),

            // Aurora 1 (Zümrüt Yeşil - Kazanç Işık Küresi)
            Positioned(
              top: -60 + (t * 40),
              left: -40 + (t * 30),
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.26),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 2 (Sıcak Amber Işık Küresi)
            Positioned(
              top: 240 - (t * 50),
              right: -50 + (t * 20),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFF59E0B).withValues(alpha: 0.18),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 3 (Cyan / Azure Işık Küresi)
            Positioned(
              bottom: 100 + (t * 30),
              left: -30 + (t * 40),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF0284C7).withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 4 (Mor / Violet)
            Positioned(
              bottom: -40 - (t * 20),
              right: -30 + (t * 30),
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // 🌟 VisionOS Spatial Floating Top Bar
  Widget _buildTopSpatialGlassBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.only(top: 56, left: 16, right: 16, bottom: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF0F1420).withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                _buildVisionIconButton(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: _handleBack,
                  iconSize: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'Mesai İşlemleri',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 20,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          _buildVisionPillBadge('OPTAPAY AI', const Color(0xFF10B981)),
                        ],
                      ),
                      Text(
                        'İSDEMİR Çelik & Liman Puantajı',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          _buildVisionIconButton(
            icon: Icons.picture_as_pdf_rounded,
            isLoading: _isGeneratingPdf,
            onTap: _isGeneratingPdf ? null : _generateAndShareMesaiPdf,
            iconSize: 18,
          ),
        ],
      ),
    );
  }

  // 💎 VisionOS Titanium Emerald Vault Hero
  Widget _buildVisionEmeraldVaultHero(double totalKazanc, int totalDays, int totalHours) {
    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(20),
      borderRadius: 26,
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.45),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF10B981),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOPLAM EK KAZANÇ',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10B981),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Text(
                  '$totalDays Gün • $totalHours Saat',
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '+ ₺ ',
                style: GoogleFonts.inter(fontSize: 26, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
              ),
              AnimatedFlipCounter(
                value: totalKazanc,
                fractionDigits: 2,
                thousandSeparator: '.',
                decimalSeparator: ',',
                duration: const Duration(milliseconds: 1000),
                curve: Curves.easeOutExpo,
                textStyle: GoogleFonts.inter(
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // 0 Kesinti İlkesi Hapı
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.verified_rounded, size: 14, color: Color(0xFF34D399)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '0 Kesinti İlkesi: Kazancınız doğrudan net hakedişinize yansır.',
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: const Color(0xFFD1FAE5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⚡ VisionOS Mesai Stepper Kartı
  Widget _buildVisionMesaiStepperCard({
    required String title,
    required String multiplierText,
    required String rateText,
    required int days,
    required double totalValue,
    required Color accentColor,
    required IconData icon,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
    required VoidCallback onPickDate,
  }) {
    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(14),
      borderRadius: 22,
      borderColor: accentColor.withValues(alpha: 0.3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: accentColor, size: 20),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  multiplierText,
                  style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            title,
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          Text(rateText, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),

          const SizedBox(height: 12),

          // Stepper (- 0 +)
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(19),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                BouncyTap(
                  onTap: onDecrement,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Icon(Icons.remove_rounded, color: accentColor, size: 18),
                  ),
                ),
                AnimatedFlipCounter(
                  value: days,
                  duration: const Duration(milliseconds: 250),
                  textStyle: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                BouncyTap(
                  onTap: onIncrement,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    alignment: Alignment.center,
                    child: Icon(Icons.add_rounded, color: accentColor, size: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Tarih Seç Butonu & Anlık Tutar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BouncyTap(
                onTap: onPickDate,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, size: 14, color: Colors.white70),
                ),
              ),
              Row(
                children: [
                  Text('₺', style: GoogleFonts.inter(fontSize: 11, color: accentColor, fontWeight: FontWeight.bold)),
                  AnimatedFlipCounter(
                    value: totalValue,
                    fractionDigits: 0,
                    thousandSeparator: '.',
                    duration: const Duration(milliseconds: 600),
                    textStyle: GoogleFonts.jetBrainsMono(fontSize: 12.5, fontWeight: FontWeight.w800, color: accentColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 🧠 VisionOS AI Super-Cockpit Adası
  Widget _buildVisionOptaPayAiCockpit({
    required double totalKazanc,
    required int normalCount,
    required int bayramCount,
    required int totalHours,
  }) {
    final double baseSalary = widget.user?.currentJobDetails.baseSalary ?? 45000.0;
    final double projectedNetTotal = baseSalary + totalKazanc;

    return _buildVisionGlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      borderColor: const Color(0xFF10B981).withValues(alpha: 0.35),
      child: Column(
        children: [
          // Segmented Tab Başlıkları
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildVisionAiSegmentPill(0, '💰 OptaPay™ Net', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildVisionAiSegmentPill(1, '⚖️ LexGuard 270s', const Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                _buildVisionAiSegmentPill(2, '🛡️ Turnike', const Color(0xFFF59E0B)),
              ],
            ),
          ),

          // Aktif Tab İçeriği
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
            child: _selectedAiTab == 0
                ? _buildVisionOptaPayView(baseSalary, totalKazanc, projectedNetTotal, normalCount, bayramCount)
                : (_selectedAiTab == 1
                    ? _buildVisionLexGuardView(totalHours, normalCount + bayramCount)
                    : _buildVisionTurnikeView(normalCount, bayramCount, totalHours)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionAiSegmentPill(int index, String title, Color activeColor) {
    final isSelected = _selectedAiTab == index;
    return Expanded(
      child: BouncyTap(
        onTap: () {
          setState(() => _selectedAiTab = index);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? activeColor.withValues(alpha: 0.22) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? activeColor.withValues(alpha: 0.8) : Colors.transparent,
              width: 1.2,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(color: activeColor.withValues(alpha: 0.3), blurRadius: 10),
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 💰 VisionOS OptaPay Net Hakediş Görünümü
  Widget _buildVisionOptaPayView(
    double baseSalary,
    double totalKazanc,
    double projectedNetTotal,
    int normalCount,
    int bayramCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 16),
                const SizedBox(width: 6),
                Text(
                  'Google DeepMind OptaPay™ AI',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '0 KESİNTİ (TAM ÖDEME)',
                style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Ay Sonu Net Projeksiyon Kutusu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('AY SONU PROJEKSİYON HAKEDİŞ', style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w700, color: const Color(0xFF6EE7B7))),
                      const SizedBox(height: 2),
                      Text('Taban Maaş + Mesailer (Net)', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  Text(
                    '₺${projectedNetTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF34D399)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: Colors.white.withValues(alpha: 0.08)),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Taban Aylık:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  Text('₺${baseSalary.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Net Mesai Katkısı ($normalCount Normal + $bayramCount Bayram):', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  Text('+ ₺${totalKazanc.toStringAsFixed(0)}', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF10B981), fontWeight: FontWeight.bold)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ⚖️ VisionOS LexGuard 270 Saat Yasal Kota Görünümü
  Widget _buildVisionLexGuardView(int totalHours, int totalDays) {
    const int maxLegalHours = 270;
    final int remainingHours = (maxLegalHours - totalHours).clamp(0, maxLegalHours);
    final double quotaRatio = (totalHours / maxLegalHours).clamp(0.0, 1.0);
    final int remainingDays = (remainingHours / 8).floor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(Icons.gavel_rounded, color: Color(0xFF38BDF8), size: 16),
                const SizedBox(width: 6),
                Text(
                  '4857 Sayılı İş Kanunu (Md. 41)',
                  style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF38BDF8)),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'Kalan: $remainingHours Sa ($remainingDays Gün)',
                style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF7DD3FC)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        // Kota İlerleme Çubuğu
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Kullanılan: $totalHours Saat ($totalDays Gün)', style: GoogleFonts.inter(fontSize: 10.5, color: Colors.white, fontWeight: FontWeight.w600)),
                Text(
                  '%${(quotaRatio * 100).toStringAsFixed(1)} Kota',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: quotaRatio > 0.8 ? const Color(0xFFEF4444) : (quotaRatio > 0.5 ? const Color(0xFFFBBF24) : const Color(0xFF34D399)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: quotaRatio,
                minHeight: 8,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  quotaRatio > 0.8 ? const Color(0xFFEF4444) : (quotaRatio > 0.5 ? const Color(0xFFFBBF24) : const Color(0xFF10B981)),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              const Icon(Icons.security_rounded, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '11 Saat Kesintisiz Dinlenme Kuralı: İki vardiya arasındaki asgari dinlenme hakkı korunmaktadır.',
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🛡️ VisionOS Turnike & Puantaj Doğrulama Görünümü
  Widget _buildVisionTurnikeView(int normalCount, int bayramCount, int totalHours) {
    return Column(
      children: [
        _buildVisionTurnikeTile(
          icon: Icons.fingerprint_rounded,
          title: 'Turnike & RFID Kart Okuma',
          subtitle: 'Giriş ve çıkış logları ile mesai kayıtları %100 örtüşüyor.',
          statusBadge: '100% UYUMLU',
          statusColor: const Color(0xFF10B981),
        ),
        const SizedBox(height: 8),
        _buildVisionTurnikeTile(
          icon: Icons.fact_check_rounded,
          title: '0-Çakışma Güvencesi',
          subtitle: 'İzin, rapor veya istirahatli günlerle çakışan mesai kaydı yok.',
          statusBadge: 'SIFIR ANOMALİ',
          statusColor: const Color(0xFF38BDF8),
        ),
      ],
    );
  }

  Widget _buildVisionTurnikeTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String statusBadge,
    required Color statusColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: statusColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        statusBadge,
                        style: GoogleFonts.jetBrainsMono(fontSize: 8, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 🧮 VisionOS Bento Kazanç Simülatörü
  Widget _buildVisionSimulatorBentoCard(double currentTotal) {
    final double simulatedExtra = _simulatedExtraDays * widget.normalMesaiRate;
    final double newTotal = currentTotal + simulatedExtra;

    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.calculate_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text('Ek Mesai Kazanç Simülatörü', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              if (_simulatedExtraDays > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '+₺${simulatedExtra.toStringAsFixed(0)} Net',
                    style: GoogleFonts.jetBrainsMono(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text('Ek gün mesaiye kaldığınızda tahmini yeni kazancınızı simüle edin:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),

          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildVisionSimPill(0, 'Sıfırla'),
              _buildVisionSimPill(1, '+1 Gün'),
              _buildVisionSimPill(2, '+2 Gün'),
              _buildVisionSimPill(3, '+3 Gün'),
              _buildVisionSimPill(5, '+5 Gün'),
            ],
          ),

          if (_simulatedExtraDays > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Simüle Edilen Yeni Toplam:', style: GoogleFonts.inter(fontSize: 11.5, color: Colors.white, fontWeight: FontWeight.w600)),
                  Text(
                    '₺ ${newTotal.toStringAsFixed(0)}',
                    style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w900, color: const Color(0xFF34D399)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildVisionSimPill(int days, String label) {
    final isSelected = _simulatedExtraDays == days;
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _simulatedExtraDays = days);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
          ),
        ),
      ),
    );
  }

  // 📜 VisionOS Geçmiş Mesailer Listesi
  Widget _buildVisionRecordsSection(List<MesaiRecord> displayedRecords, int currentNormalCount, int currentBayramCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Mesai Kayıtlarım', style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white)),
            Text('${displayedRecords.length} Kayıt', style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ],
        ),

        const SizedBox(height: 10),

        // Filtreleme Hapları
        Row(
          children: [
            _buildVisionFilterPill('Tümü (${_records.length})', 0),
            const SizedBox(width: 8),
            _buildVisionFilterPill('Normal ($currentNormalCount)', 1),
            const SizedBox(width: 8),
            _buildVisionFilterPill('Bayram ($currentBayramCount)', 2),
          ],
        ),

        const SizedBox(height: 12),

        displayedRecords.isEmpty
            ? Container(
                padding: const EdgeInsets.symmetric(vertical: 36),
                alignment: Alignment.center,
                child: Column(
                  children: [
                    const Icon(Icons.event_busy_rounded, size: 44, color: Color(0xFF475569)),
                    const SizedBox(height: 8),
                    Text('Kayıtlı mesai bulunmuyor.', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 13)),
                  ],
                ),
              )
            : ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: displayedRecords.length,
                itemBuilder: (context, index) {
                  final record = displayedRecords[index];
                  final isNormal = record.type == MesaiType.normal;
                  final color = isNormal ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
                  final amount = isNormal ? widget.normalMesaiRate : widget.bayramMesaiRate;

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: _buildVisionGlassContainer(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 18,
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(9),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isNormal ? Icons.work_history_rounded : Icons.celebration_rounded,
                              color: color,
                              size: 18,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      isNormal ? 'Normal Mesai' : 'Bayram Mesaisi',
                                      style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(
                                      '+ ₺ ${amount.toStringAsFixed(0)}',
                                      style: GoogleFonts.jetBrainsMono(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(record.date),
                                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1)),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _removeRecord(record.id),
                                    ),
                                  ],
                                ),
                                if (record.note.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    record.note,
                                    style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ).animate(delay: (index * 30).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
                },
              ),
      ],
    );
  }

  Widget _buildVisionFilterPill(String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : Colors.white.withValues(alpha: 0.1),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          title,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  // 📄 VisionOS A4 PDF Puantaj Cetveli Paylaşım Barı
  Widget _buildVisionPdfShareActionBar() {
    return BouncyTap(
      onTap: _isGeneratingPdf ? null : _generateAndShareMesaiPdf,
      child: _buildVisionGlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 22,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
              ),
              child: _isGeneratingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF34D399), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aylık Mesai Puantaj Cetveli (Resmi A4 PDF)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'İSDEMİR formatında imzalı hakediş belgesi oluştur',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.share_rounded, color: Color(0xFF34D399), size: 18),
          ],
        ),
      ),
    );
  }

  // ── 💎 VISIONOS YARDIMCI BİLEŞENLERİ ──

  Widget _buildVisionGlassContainer({
    required Widget child,
    EdgeInsetsGeometry? padding = const EdgeInsets.all(16),
    double borderRadius = 22,
    Color? borderColor,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF131826).withValues(alpha: 0.82),
            const Color(0xFF0B0F19).withValues(alpha: 0.90),
          ],
        ),
        border: Border.all(
          color: borderColor ?? Colors.white.withValues(alpha: 0.14),
          width: 1.1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildVisionOSSheetContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.only(top: 18, left: 22, right: 22, bottom: 38),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1420).withValues(alpha: 0.94),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildVisionIconButton({
    required IconData icon,
    VoidCallback? onTap,
    double iconSize = 18,
    bool isLoading = false,
  }) {
    return BouncyTap(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF1B2332).withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
        ),
        child: isLoading
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : Icon(icon, color: Colors.white, size: iconSize),
      ),
    );
  }

  Widget _buildVisionPillBadge(String text, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.22),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accentColor.withValues(alpha: 0.45)),
      ),
      child: Text(
        text,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 9,
          fontWeight: FontWeight.bold,
          color: accentColor,
        ),
      ),
    );
  }
}
