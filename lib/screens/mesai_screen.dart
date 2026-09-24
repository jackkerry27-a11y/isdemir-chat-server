import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
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

class _MesaiScreenState extends State<MesaiScreen> {
  final List<MesaiRecord> _records = [];
  int _selectedFilterIndex = 0; // 0 = Tümü, 1 = Normal, 2 = Bayram
  int _simulatedExtraDays = 0; // Canlı Hakediş Simülatörü
  bool _isGeneratingPdf = false;
  int _touchedBarIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadRecords();
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

  // 📅 Tarih Seçerek Mesai Ekleme Modalı
  Future<void> _showAddDatePickerModal(MesaiType type) async {
    HapticFeedback.lightImpact();
    DateTime selectedDate = DateTime.now();
    final TextEditingController noteController = TextEditingController();

    await showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141722),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final isNormal = type == MesaiType.normal;
            final themeColor = isNormal ? const Color(0xFFDC2626) : const Color(0xFFF97316);

            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 24,
                bottom: MediaQuery.of(context).viewInsets.bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                              color: themeColor.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
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
                                style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                              ),
                              Text(
                                isNormal ? '1.5x Katsayı • 8 Saat' : '2.0x Katsayı • Çift Yevmiye',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
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
                                      surface: const Color(0xFF141722),
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
                              color: const Color(0xFF1E2230),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF334155)),
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
                      fillColor: const Color(0xFF1E2230),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // Onay Butonu
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
                      child: Text('Mesaiyi Kaydet', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ),
                ],
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
          color: isSelected ? themeColor.withValues(alpha: 0.25) : const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? themeColor : const Color(0xFF334155), width: 1.2),
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
                        pw.Text('RESMI AYLIK PERSONEL EK MESAI CETVELI', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
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

    // Filtrelenmiş liste
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
        backgroundColor: const Color(0xFF090A0F),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── 🌟 1. ÜST HEADER & GRADYAN BANNER ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 56, left: 20, right: 20, bottom: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF064E3B), Color(0xFF062D24), Color(0xFF090A0F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
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
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: IconButton(
                                onPressed: _handleBack,
                                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Mesai İşlemleri',
                                  style: GoogleFonts.inter(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Text(
                                  'Ek Çalışma & Hakediş Puantajı',
                                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        // PDF Rapor Paylaş Butonu
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: IconButton(
                            icon: _isGeneratingPdf
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                            tooltip: 'A4 Mesai Raporu Paylaş',
                            onPressed: _isGeneratingPdf ? null : _generateAndShareMesaiPdf,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),

                    // ── 💎 TITANIUM EMERALD MESAI KASASI (Hero Kart) ──
                    _buildEmeraldVaultHero(totalKazanc, currentNormalCount + currentBayramCount, totalHours),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ── ⚡ 2. HIZLI MESAİ EKLEME KARTLARI (Normal & Bayram) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Column(
                  children: [
                    _buildModernMesaiEntryCard(
                      title: 'Normal Mesai',
                      multiplierText: '1.5x Katsayı',
                      rateText: '₺${widget.normalMesaiRate.toStringAsFixed(0)} / gün',
                      days: currentNormalCount,
                      totalValue: normalKazanc,
                      accentColor: const Color(0xFFDC2626),
                      icon: Icons.work_history_rounded,
                      onIncrement: () => _addRecordNow(MesaiType.normal),
                      onDecrement: () => _removeLatestRecord(MesaiType.normal),
                      onPickDate: () => _showAddDatePickerModal(MesaiType.normal),
                    ),
                    const SizedBox(height: 14),
                    _buildModernMesaiEntryCard(
                      title: 'Bayram & Resmi Tatil',
                      multiplierText: '2.0x Çift Yevmiye',
                      rateText: '₺${widget.bayramMesaiRate.toStringAsFixed(0)} / gün',
                      days: currentBayramCount,
                      totalValue: bayramKazanc,
                      accentColor: const Color(0xFFF97316),
                      icon: Icons.celebration_rounded,
                      onIncrement: () => _addRecordNow(MesaiType.bayram),
                      onDecrement: () => _removeLatestRecord(MesaiType.bayram),
                      onPickDate: () => _showAddDatePickerModal(MesaiType.bayram),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── 📊 3. fl_chart HAFTALIK MESAİ DAĞILIM GRAFİĞİ ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildOvertimeBarChartCard(),
              ),

              const SizedBox(height: 24),

              // ── 🧮 4. AKILLI GELECEK HAKEDİŞ SİMÜLATÖRÜ ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: _buildOvertimeSimulatorCard(totalKazanc),
              ),

              const SizedBox(height: 26),

              // ── 📜 5. GEÇMİŞ MESAİLER LİSTESİ & FİLTRELER ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Mesai Kayıtlarım',
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      '${displayedRecords.length} Kayıt',
                      style: GoogleFonts.jetBrainsMono(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Filtreleme Hapları
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Row(
                  children: [
                    _buildFilterPill('Tümü (${_records.length})', 0),
                    const SizedBox(width: 8),
                    _buildFilterPill('Normal ($currentNormalCount)', 1),
                    const SizedBox(width: 8),
                    _buildFilterPill('Bayram ($currentBayramCount)', 2),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Liste
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: displayedRecords.isEmpty
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        alignment: Alignment.center,
                        child: Column(
                          children: [
                            const Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFF475569)),
                            const SizedBox(height: 10),
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
                          final color = isNormal ? const Color(0xFFDC2626) : const Color(0xFFF97316);
                          final amount = isNormal ? widget.normalMesaiRate : widget.bayramMesaiRate;

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFF272A36)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    isNormal ? Icons.work_history_rounded : Icons.celebration_rounded,
                                    color: color,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
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
                                            style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              DateFormat('dd MMMM yyyy, EEEE', 'tr_TR').format(record.date),
                                              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w500),
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
                                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B), fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ).animate(delay: (index * 30).ms).fadeIn(duration: 250.ms).slideY(begin: 0.04, end: 0);
                        },
                      ),
              ),

              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
    );
  }

  // ── 💎 TITANIUM EMERALD HERO KARTI ──
  Widget _buildEmeraldVaultHero(double totalKazanc, int totalDays, int totalHours) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F382A), Color(0xFF062319), Color(0xFF090A0F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.5), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.22),
            blurRadius: 24,
            offset: const Offset(0, 8),
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
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'TOPLAM EK KAZANÇ',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981), letterSpacing: 0.8),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                ),
                child: Text(
                  '$totalDays Gün • $totalHours Saat',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
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
                style: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
              ),
              AnimatedFlipCounter(
                value: totalKazanc,
                fractionDigits: 2,
                thousandSeparator: '.',
                decimalSeparator: ',',
                duration: const Duration(milliseconds: 1100),
                curve: Curves.easeOutExpo,
                textStyle: GoogleFonts.inter(
                  fontSize: 34,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF10B981),
                  letterSpacing: -0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Bu tutar ay sonu maaş hakedişinize net olarak yansıtılacaktır.',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ── ⚡ MODERN MESAİ GİRİŞ KARTI ──
  Widget _buildModernMesaiEntryCard({
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF272A36)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accentColor.withValues(alpha: 0.3)),
                ),
                child: Icon(icon, color: accentColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            multiplierText,
                            style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: accentColor),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(rateText, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ],
                ),
              ),

              // Sayıcı (- 0 +)
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF090A0F),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Row(
                  children: [
                    BouncyTap(
                      onTap: onDecrement,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        alignment: Alignment.center,
                        child: Icon(Icons.remove_rounded, color: accentColor, size: 18),
                      ),
                    ),
                    SizedBox(
                      width: 26,
                      child: Center(
                        child: AnimatedFlipCounter(
                          value: days,
                          duration: const Duration(milliseconds: 300),
                          textStyle: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
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
            ],
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: Color(0xFF272A36)),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Tarih Seçerek Ekle Butonu
              Flexible(
                child: BouncyTap(
                  onTap: onPickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2230),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.edit_calendar_rounded, size: 14, color: Color(0xFFCBD5E1)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            'Tarih Seçerek Ekle',
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Bu Kalemden Kazanç
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Kazanç: ', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  Text('+ ₺ ', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: accentColor)),
                  AnimatedFlipCounter(
                    value: totalValue,
                    fractionDigits: 2,
                    thousandSeparator: '.',
                    decimalSeparator: ',',
                    duration: const Duration(milliseconds: 700),
                    textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: accentColor),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── 📊 3. fl_chart HAFTALIK MESAİ GRAFİĞİ ──
  Widget _buildOvertimeBarChartCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF272A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Aylık Mesai Trendi', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                  Text('Haftalara göre mesai günü dağılımı', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                ],
              ),
              Row(
                children: [
                  _buildChartLegendDot(const Color(0xFFDC2626), 'Normal'),
                  const SizedBox(width: 10),
                  _buildChartLegendDot(const Color(0xFFF97316), 'Bayram'),
                ],
              ),
            ],
          ),

          const SizedBox(height: 20),

          SizedBox(
            height: 140,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY: 5,
                barTouchData: BarTouchData(
                  enabled: true,
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipColor: (group) => const Color(0xFF1E2230),
                    tooltipBorder: const BorderSide(color: Color(0xFF10B981), width: 1),
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      String type = rodIndex == 0 ? 'Normal' : 'Bayram';
                      return BarTooltipItem(
                        '$type: ${rod.toY.toInt()} Gün\n(Hafta ${group.x + 1})',
                        GoogleFonts.inter(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                  touchCallback: (event, response) {
                    if (response?.spot != null) {
                      setState(() {
                        _touchedBarIndex = response!.spot!.touchedBarGroupIndex;
                      });
                    } else {
                      setState(() {
                        _touchedBarIndex = -1;
                      });
                    }
                  },
                ),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            '${(value + 1).toInt()}. Hafta',
                            style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _makeBarGroup(0, 2, 0),
                  _makeBarGroup(1, 3, 1),
                  _makeBarGroup(2, 1, 0),
                  _makeBarGroup(3, 2, 1),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _makeBarGroup(int x, double normalDays, double bayramDays) {
    final isTouched = _touchedBarIndex == x;
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: normalDays,
          color: const Color(0xFFDC2626),
          width: isTouched ? 14 : 11,
          borderRadius: BorderRadius.circular(4),
        ),
        BarChartRodData(
          toY: bayramDays,
          color: const Color(0xFFF97316),
          width: isTouched ? 14 : 11,
          borderRadius: BorderRadius.circular(4),
        ),
      ],
    );
  }

  Widget _buildChartLegendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFCBD5E1))),
      ],
    );
  }

  // ── 🧮 4. AKILLI GELECEK HAKEDİŞ SİMÜLATÖRÜ ──
  Widget _buildOvertimeSimulatorCard(double currentTotal) {
    final double simulatedExtra = _simulatedExtraDays * widget.normalMesaiRate;
    final double newTotal = currentTotal + simulatedExtra;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF272A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calculate_rounded, color: Color(0xFF38BDF8), size: 20),
              const SizedBox(width: 8),
              Text(
                'Ek Mesai Kazanç Simülatörü',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Bu ay ek olarak kaç gün daha mesaiye kalırsanız ne kazanırsınız?',
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 14),

          // Simülatör Seçim Butonları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSimPill(0, 'Sıfırla'),
              _buildSimPill(1, '+1 Gün'),
              _buildSimPill(2, '+2 Gün'),
              _buildSimPill(3, '+3 Gün'),
              _buildSimPill(5, '+5 Gün'),
            ],
          ),

          if (_simulatedExtraDays > 0) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Tahmini Ek Hakediş:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      Text(
                        '+ ₺ ${simulatedExtra.toStringAsFixed(0)} Net Kazanç',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('Yeni Toplam Mesai:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      Text(
                        '₺ ${newTotal.toStringAsFixed(0)}',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSimPill(int days, String label) {
    final isSelected = _simulatedExtraDays == days;
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _simulatedExtraDays = days);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.25) : const Color(0xFF1E2230),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFF334155),
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

  Widget _buildFilterPill(String title, int index) {
    final isSelected = _selectedFilterIndex == index;
    return BouncyTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _selectedFilterIndex = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF10B981).withValues(alpha: 0.25) : const Color(0xFF141722),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF10B981) : const Color(0xFF272A36),
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
}
