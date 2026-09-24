import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../utils/shift_logic.dart';
import '../utils/pdf_font_helper.dart';
import '../widgets/glass_widgets.dart';

class VardiyaScreen extends StatefulWidget {
  final VoidCallback? onBackToHome;
  const VardiyaScreen({super.key, this.onBackToHome});

  @override
  State<VardiyaScreen> createState() => _VardiyaScreenState();
}

class ShiftProgressInfo {
  final bool isInShift;
  final bool isBeforeShift;
  final bool isAfterShift;
  final double progress;
  final String statusText;
  final String remainingTimeString;
  final DateTime shiftStart;
  final DateTime shiftEnd;
  final String breakInfo;
  final String shuttleInfo;
  final bool isInBreak;
  final String? breakRemainingString;

  ShiftProgressInfo({
    required this.isInShift,
    required this.isBeforeShift,
    required this.isAfterShift,
    required this.progress,
    required this.statusText,
    required this.remainingTimeString,
    required this.shiftStart,
    required this.shiftEnd,
    required this.breakInfo,
    required this.shuttleInfo,
    this.isInBreak = false,
    this.breakRemainingString,
  });
}

class _VardiyaScreenState extends State<VardiyaScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late DateTime _selectedDay;
  VardiyaGunu _selectedVardiya = VardiyaGunu.sali;
  ShiftType? _filterShiftType;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();
  bool _isGeneratingPdf = false;
  int _touchedChartIndex = -1;

  @override
  void initState() {
    super.initState();
    _selectedDay = _today;
    _loadSelectedVardiya();
    _checkAndPromptVardiya();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _now = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkAndPromptVardiya() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('has_prompted_vardiya_v2') ?? false;
    final saved = prefs.getString('selected_vardiya_gunu');

    // Eğer kullanıcı daha önce vardiya seçmediyse veya soru sorulmadıysa
    if (!hasPrompted || saved == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showInitialVardiyaQuestionModal();
        }
      });
    }
  }

  void _showInitialVardiyaQuestionModal() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return PopScope(
          canPop: false,
          child: Container(
            padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 36),
            decoration: const BoxDecoration(
              color: Color(0xFF13161F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              border: Border(
                top: BorderSide(color: Color(0xFF3B82F6), width: 2.5),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black87,
                  blurRadius: 40,
                  offset: Offset(0, -10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF333B4F),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.3)),
                      ),
                      child: const Icon(Icons.help_outline_rounded, color: Color(0xFF60A5FA), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hangi Vardiyadasın?',
                            style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Lütfen çalıştığınız posta grubunu seçin',
                            style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2433),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF2E384D)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Seçiminiz hem takviminizi ayarlayacak hem de Ekip sekmesinde arkadaşlarınızın sizi doğru vardiyada görmesini sağlayacaktır.',
                          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _buildQuestionVardiyaOption(
                  ctx: ctx,
                  gun: VardiyaGunu.sali,
                  postaLabel: '1. Posta (Salı Grubu)',
                  tatilLabel: 'Hafta Tatili: Salı Günleri',
                  icon: Icons.wb_sunny_rounded,
                  color: const Color(0xFFF59E0B),
                ),
                _buildQuestionVardiyaOption(
                  ctx: ctx,
                  gun: VardiyaGunu.carsamba,
                  postaLabel: '2. Posta (Çarşamba Grubu)',
                  tatilLabel: 'Hafta Tatili: Çarşamba Günleri',
                  icon: Icons.wb_twilight_rounded,
                  color: const Color(0xFF8B5CF6),
                ),
                _buildQuestionVardiyaOption(
                  ctx: ctx,
                  gun: VardiyaGunu.cuma,
                  postaLabel: '3. Posta (Cuma Grubu)',
                  tatilLabel: 'Hafta Tatili: Cuma Günleri',
                  icon: Icons.nightlight_round,
                  color: const Color(0xFF3B82F6),
                ),
                _buildQuestionVardiyaOption(
                  ctx: ctx,
                  gun: VardiyaGunu.cumartesi,
                  postaLabel: '4. Posta (Cumartesi Grubu)',
                  tatilLabel: 'Hafta Tatili: Cumartesi Günleri',
                  icon: Icons.beach_access_rounded,
                  color: const Color(0xFF10B981),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildQuestionVardiyaOption({
    required BuildContext ctx,
    required VardiyaGunu gun,
    required String postaLabel,
    required String tatilLabel,
    required IconData icon,
    required Color color,
  }) {
    final isSelected = _selectedVardiya == gun;
    return GestureDetector(
      onTap: () async {
        await _changeVardiya(gun);
        if (ctx.mounted) {
          Navigator.pop(ctx);
        }
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '$postaLabel kaydedildi. Ekip listesinde güncellendi!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.15) : const Color(0xFF1A1F2C),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : const Color(0xFF2A3347),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    postaLabel,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tatilLabel,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.radio_button_checked_rounded : Icons.arrow_forward_ios_rounded,
              color: isSelected ? color : const Color(0xFF475569),
              size: isSelected ? 22 : 15,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadSelectedVardiya() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_vardiya_gunu');
    if (saved == 'carsamba') {
      setState(() {
        _selectedVardiya = VardiyaGunu.carsamba;
      });
    } else if (saved == 'cuma') {
      setState(() {
        _selectedVardiya = VardiyaGunu.cuma;
      });
    } else if (saved == 'cumartesi') {
      setState(() {
        _selectedVardiya = VardiyaGunu.cumartesi;
      });
    } else if (saved == 'sali') {
      setState(() {
        _selectedVardiya = VardiyaGunu.sali;
      });
    }
  }

  Future<void> _changeVardiya(VardiyaGunu newVardiya) async {
    setState(() {
      _selectedVardiya = newVardiya;
    });
    final prefs = await SharedPreferences.getInstance();
    String saveStr = 'sali';
    String displayVardiya = 'Salı Grubu';
    if (newVardiya == VardiyaGunu.carsamba) {
      saveStr = 'carsamba';
      displayVardiya = 'Çarşamba Grubu';
    } else if (newVardiya == VardiyaGunu.cuma) {
      saveStr = 'cuma';
      displayVardiya = 'Cuma Grubu';
    } else if (newVardiya == VardiyaGunu.cumartesi) {
      saveStr = 'cumartesi';
      displayVardiya = 'Cumartesi Grubu';
    }
    await prefs.setString('selected_vardiya_gunu', saveStr);
    await prefs.setBool('has_prompted_vardiya_v2', true);

    final cihazId = prefs.getString('cihaz_id');
    if (cihazId != null) {
      try {
        final querySnapshot = await FirebaseFirestore.instance
            .collection('personeller')
            .where('cihaz_id', isEqualTo: cihazId)
            .limit(1)
            .get();
        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.update({
            'vardiya': displayVardiya,
          });
        }
      } catch (e) {
        debugPrint('Vardiya kayit hatasi: $e');
      }
    }
  }

  String _getVardiyaGunuName(VardiyaGunu gun) {
    switch (gun) {
      case VardiyaGunu.sali:
        return 'Salı Vardiyası';
      case VardiyaGunu.carsamba:
        return 'Çarşamba Vardiyası';
      case VardiyaGunu.cuma:
        return 'Cuma Vardiyası';
      case VardiyaGunu.cumartesi:
        return 'Cumartesi Vardiyası';
    }
  }

  ShiftProgressInfo? _calculateShiftProgress(DateTime targetDay, ShiftType type) {
    if (type == ShiftType.tatil) return null;

    DateTime start;
    DateTime end;
    DateTime breakStart;
    DateTime breakEnd;
    String breakInfo = '';
    String shuttleInfo = '';

    if (type == ShiftType.sabah) {
      start = DateTime(targetDay.year, targetDay.month, targetDay.day, 9, 30);
      end = DateTime(targetDay.year, targetDay.month, targetDay.day, 16, 30);
      breakStart = DateTime(targetDay.year, targetDay.month, targetDay.day, 12, 0);
      breakEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, 12, 30);
      breakInfo = '12:00 - 12:30 Çay & Yemek';
      shuttleInfo = '08:45 Biniş • 16:45 Çıkış';
    } else if (type == ShiftType.aksam) {
      start = DateTime(targetDay.year, targetDay.month, targetDay.day, 16, 30);
      end = DateTime(targetDay.year, targetDay.month, targetDay.day + 1, 0, 30);
      breakStart = DateTime(targetDay.year, targetDay.month, targetDay.day, 19, 0);
      breakEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, 19, 30);
      breakInfo = '19:00 - 19:30 Çay & Yemek';
      shuttleInfo = '15:45 Biniş • 00:45 Çıkış';
    } else {
      start = DateTime(targetDay.year, targetDay.month, targetDay.day, 0, 30);
      end = DateTime(targetDay.year, targetDay.month, targetDay.day, 9, 30);
      breakStart = DateTime(targetDay.year, targetDay.month, targetDay.day, 3, 0);
      breakEnd = DateTime(targetDay.year, targetDay.month, targetDay.day, 3, 30);
      breakInfo = '03:00 - 03:30 Çay & Yemek';
      shuttleInfo = '23:45 Biniş • 09:45 Çıkış';
    }

    final totalSeconds = end.difference(start).inSeconds;
    final bool isInBreak = _now.isAfter(breakStart) && _now.isBefore(breakEnd);
    String? breakRemaining;
    if (isInBreak) {
      final bDiff = breakEnd.difference(_now);
      final bMin = bDiff.inMinutes.toString().padLeft(2, '0');
      final bSec = (bDiff.inSeconds % 60).toString().padLeft(2, '0');
      breakRemaining = '$bMin:$bSec';
    }

    if (_now.isBefore(start)) {
      final diff = start.difference(_now);
      final h = diff.inHours.toString().padLeft(2, '0');
      final m = (diff.inMinutes % 60).toString().padLeft(2, '0');
      final s = (diff.inSeconds % 60).toString().padLeft(2, '0');
      return ShiftProgressInfo(
        isInShift: false,
        isBeforeShift: true,
        isAfterShift: false,
        progress: 0.0,
        statusText: 'Vardiyanın Başlamasına',
        remainingTimeString: '$h:$m:$s',
        shiftStart: start,
        shiftEnd: end,
        breakInfo: breakInfo,
        shuttleInfo: shuttleInfo,
        isInBreak: false,
      );
    } else if (_now.isAfter(end)) {
      return ShiftProgressInfo(
        isInShift: false,
        isBeforeShift: false,
        isAfterShift: true,
        progress: 1.0,
        statusText: 'Vardiya Tamamlandı',
        remainingTimeString: '00:00:00',
        shiftStart: start,
        shiftEnd: end,
        breakInfo: breakInfo,
        shuttleInfo: shuttleInfo,
        isInBreak: false,
      );
    } else {
      final elapsed = _now.difference(start).inSeconds;
      final remaining = end.difference(_now);
      final progress = (elapsed / totalSeconds).clamp(0.0, 1.0);
      final h = remaining.inHours.toString().padLeft(2, '0');
      final m = (remaining.inMinutes % 60).toString().padLeft(2, '0');
      final s = (remaining.inSeconds % 60).toString().padLeft(2, '0');
      return ShiftProgressInfo(
        isInShift: true,
        isBeforeShift: false,
        isAfterShift: false,
        progress: progress,
        statusText: isInBreak ? '☕ Çay ve Yemek Molasındasınız' : 'Vardiya Bitimine Kalan Süre',
        remainingTimeString: '$h:$m:$s',
        shiftStart: start,
        shiftEnd: end,
        breakInfo: breakInfo,
        shuttleInfo: shuttleInfo,
        isInBreak: isInBreak,
        breakRemainingString: breakRemaining,
      );
    }
  }

  Color _getShiftColor(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return const Color(0xFFF59E0B); // Gündüz Amber
      case ShiftType.gece:
        return const Color(0xFF3B82F6); // Gece Mavi
      case ShiftType.aksam:
        return const Color(0xFF8B5CF6); // Akşam Mor
      case ShiftType.tatil:
        return const Color(0xFF10B981); // İzin Yeşil
    }
  }

  IconData _getShiftIcon(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return Icons.wb_sunny_rounded;
      case ShiftType.gece:
        return Icons.nightlight_round;
      case ShiftType.aksam:
        return Icons.wb_twilight_rounded;
      case ShiftType.tatil:
        return Icons.beach_access_rounded;
    }
  }

  String _getShiftName(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return 'Gündüz Vardiyası';
      case ShiftType.gece:
        return 'Gece Vardiyası';
      case ShiftType.aksam:
        return 'Akşam Vardiyası';
      case ShiftType.tatil:
        return 'Hafta Tatili';
    }
  }

  String _getShiftTime(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return '09:30 - 16:30';
      case ShiftType.gece:
        return '00:30 - 09:30';
      case ShiftType.aksam:
        return '16:30 - 24:30';
      case ShiftType.tatil:
        return 'Hafta Tatili';
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
      _selectedDay = _today;
      _filterShiftType = null;
    });
    HapticFeedback.mediumImpact();
  }

  void _handleBack() {
    HapticFeedback.lightImpact();
    if (widget.onBackToHome != null) {
      widget.onBackToHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  // ── 📄 A4 Vardiya Cetveli PDF Paylaşımı ──
  Future<void> _generateAndShareVardiyaPdf() async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    try {
      final pdfTheme = await PdfFontHelper.getTheme();
      final pdf = pw.Document(theme: pdfTheme);
      String safe(String? t) => PdfFontHelper.sanitize(t);

      final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
      final daysOfWeek = ['Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

      int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
      String vardiyaAdi = _getVardiyaGunuName(_selectedVardiya);

      int gunduz = 0, gece = 0, aksam = 0, tatil = 0;
      List<List<String>> tableRows = [];

      for (int d = 1; d <= daysInMonth; d++) {
        final date = DateTime(_currentMonth.year, _currentMonth.month, d);
        final shift = ShiftLogic.getShiftType(date, vardiyaGunu: _selectedVardiya);
        final holiday = HolidayLogic.getHolidayName(date);
        final weekdayName = daysOfWeek[date.weekday - 1];

        String shiftName = 'Gündüz';
        String shiftTime = '09:30 - 16:30';

        if (shift == ShiftType.sabah) {
          gunduz++;
          shiftName = 'Gündüz';
          shiftTime = '09:30 - 16:30';
        } else if (shift == ShiftType.gece) {
          gece++;
          shiftName = 'Gece';
          shiftTime = '00:30 - 09:30';
        } else if (shift == ShiftType.aksam) {
          aksam++;
          shiftName = 'Akşam';
          shiftTime = '16:30 - 24:30';
        } else {
          tatil++;
          shiftName = 'Hafta Tatili';
          shiftTime = 'Tatil';
        }

        tableRows.add([
          safe('$d ${months[_currentMonth.month]}'),
          safe(weekdayName),
          safe(shiftName),
          safe(shiftTime),
          safe(holiday ?? '-'),
        ]);
      }

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
                        pw.Text(safe('İSKENDERUN DEMİR VE ÇELİK A.Ş.'), style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF881337))),
                        pw.SizedBox(height: 2),
                        pw.Text(safe('AYLIK PERSONEL VARDİYA ÇALIŞMA CETVELİ'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      ],
                    ),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: pw.BoxDecoration(
                        color: const PdfColor.fromInt(0xFFF1F5F9),
                        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                        border: pw.Border.all(color: PdfColors.grey300),
                      ),
                      child: pw.Text(safe('${months[_currentMonth.month]} ${_currentMonth.year}'), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(safe('Vardiya Düzeni: $vardiyaAdi'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800)),
                    pw.Text(safe('Oluşturulma Tarihi: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
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
                headers: [safe('Tarih'), safe('Gün'), safe('Vardiya'), safe('Saatler'), safe('Durum / Bayram')],
                data: tableRows,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF1E293B)),
                cellHeight: 18,
                cellStyle: const pw.TextStyle(fontSize: 8),
                cellAlignments: {
                  0: pw.Alignment.centerLeft,
                  1: pw.Alignment.centerLeft,
                  2: pw.Alignment.center,
                  3: pw.Alignment.center,
                  4: pw.Alignment.centerLeft,
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
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                      children: [
                        pw.Text(safe('Gündüz: $gunduz Gün (${gunduz * 8} Sa)'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFFD97706))),
                        pw.Text(safe('Gece: $gece Gün (${gece * 8} Sa)'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF2563EB))),
                        pw.Text(safe('Akşam: $aksam Gün (${aksam * 8} Sa)'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF7C3AED))),
                        pw.Text(safe('Hafta Tatili: $tatil Gün'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF059669))),
                      ],
                    ),
                    pw.SizedBox(height: 8),
                    pw.Container(height: 0.5, color: PdfColors.grey300),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      safe('Çay ve Yemek Molaları: Gündüz (12:00 - 12:30) | Akşam (19:00 - 19:30) | Gece (03:00 - 03:30)'),
                      style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 12),
              pw.Text(
                safe('Bu çizelge İSDEMİR Personel Bilgi Sistemi üzerinden otomatik üretilmiştir. Resmi vardiya değişiklikleri amir onayı ile geçerlilik kazanır.'),
                style: pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic),
              ),
            ];
          },
        ),
      );

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Isdemir_Vardiya_${_currentMonth.year}_${_currentMonth.month}.pdf');
      await file.writeAsBytes(await pdf.save());

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${months[_currentMonth.month]} ${_currentMonth.year} İSDEMİR Vardiya Çizelgesi',
        ),
      );
    } catch (e) {
      debugPrint('Vardiya PDF Hatasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  void _showVardiyaSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.only(top: 24, left: 24, right: 24, bottom: 40),
          decoration: const BoxDecoration(
            color: Color(0xFF141416),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFFDC2626), size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vardiya Döngüsü Seç',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Liman ve fabrika saha vardiya planı',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Color(0xFF1C1C22),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              _buildVardiyaItem(
                VardiyaGunu.sali, 
                'Salı Vardiyası', 
                'Hafta Tatili: ', 'Salı Günleri', 
                _selectedVardiya == VardiyaGunu.sali
              ),
              _buildVardiyaItem(
                VardiyaGunu.carsamba, 
                'Çarşamba Vardiyası', 
                'Hafta Tatili: ', 'Çarşamba Günleri', 
                _selectedVardiya == VardiyaGunu.carsamba
              ),
              _buildVardiyaItem(
                VardiyaGunu.cuma, 
                'Cuma Vardiyası', 
                'Hafta Tatili: ', 'Cuma Günleri', 
                _selectedVardiya == VardiyaGunu.cuma
              ),
              _buildVardiyaItem(
                VardiyaGunu.cumartesi, 
                'Cumartesi Vardiyası', 
                'Hafta Tatili: ', 'Cumartesi Günleri', 
                _selectedVardiya == VardiyaGunu.cumartesi
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVardiyaItem(VardiyaGunu gun, String title, String subtitleLabel, String subtitleHighlight, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _changeVardiya(gun);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626).withValues(alpha: 0.08) : const Color(0xFF18181B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF27272A),
            width: 1.2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFDC2626).withValues(alpha: 0.15) : const Color(0xFF27272A),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  color: isSelected ? const Color(0xFFDC2626) : const Color(0xFFA1A1AA),
                  size: 22,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 3),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFFA1A1AA)),
                        children: [
                          TextSpan(text: subtitleLabel),
                          TextSpan(text: subtitleHighlight, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF3F3F46),
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check_rounded, color: Colors.white, size: 14) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final daysOfWeek = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // Pazartesi = 1
    int emptySlots = firstWeekday - 1;

    int gunduzCount = 0;
    int geceCount = 0;
    int aksamCount = 0;
    int izinCount = 0;

    for (int d = 1; d <= daysInMonth; d++) {
      final dDate = DateTime(_currentMonth.year, _currentMonth.month, d);
      final s = ShiftLogic.getShiftType(dDate, vardiyaGunu: _selectedVardiya);
      switch (s) {
        case ShiftType.sabah:
          gunduzCount++;
          break;
        case ShiftType.gece:
          geceCount++;
          break;
        case ShiftType.aksam:
          aksamCount++;
          break;
        case ShiftType.tatil:
          izinCount++;
          break;
      }
    }

    ShiftType todayShift = ShiftLogic.getShiftType(_today, vardiyaGunu: _selectedVardiya);
    ShiftProgressInfo? todayProgress = _calculateShiftProgress(_today, todayShift);

    ShiftType selectedShift = ShiftLogic.getShiftType(_selectedDay, vardiyaGunu: _selectedVardiya);
    Color selectedColor = _getShiftColor(selectedShift);
    bool isSelectedToday = _selectedDay.year == _today.year &&
        _selectedDay.month == _today.month &&
        _selectedDay.day == _today.day;

    String? holidayName = HolidayLogic.getHolidayName(_selectedDay);

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
            children: [
              // ── Üst Başlık & Gradient Arkaplan ──
              Container(
                width: double.infinity,
                padding: const EdgeInsets.only(top: 60, left: 20, right: 20, bottom: 24),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF5A0C16), Color(0xFF1E1015), Color(0xFF090A0F)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Üst Menü Satırı
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
                                'Vardiya Takvimi',
                                style: GoogleFonts.inter(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              Text(
                                'İSDEMİR Saha & Liman Operasyonu',
                                style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                              ),
                            ],
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          // PDF İndir & Paylaş Butonu
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: _isGeneratingPdf
                                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                              tooltip: 'Aylık Vardiya PDF Paylaş',
                              onPressed: _isGeneratingPdf ? null : _generateAndShareVardiyaPdf,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Vardiya Seçici Modalı Açan Buton
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(Icons.swap_horiz_rounded, color: Colors.white, size: 22),
                              tooltip: 'Vardiya Düzenini Değiştir',
                              onPressed: _showVardiyaSelectionModal,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 18),

                  // ── 🔴 CANLI VARDİYA HUB (Live Activity Card) ──
                  _buildLiveActivityHub(todayShift, todayProgress)
                      .animate()
                      .fadeIn(duration: 400.ms)
                      .slideY(begin: 0.08, end: 0, curve: Curves.easeOutCubic),

                  const SizedBox(height: 16),

                  // ── Vardiya Hızlı Geçiş Hapları ──
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      children: [
                        _buildQuickVardiyaTab(VardiyaGunu.sali, 'Salı'),
                        _buildQuickVardiyaTab(VardiyaGunu.carsamba, 'Çarşamba'),
                        _buildQuickVardiyaTab(VardiyaGunu.cuma, 'Cuma'),
                        _buildQuickVardiyaTab(VardiyaGunu.cumartesi, 'Cumartesi'),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── TAKVİM GÖVDESİ ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: const Color(0xFF272A36)),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                  ],
                ),
                child: Column(
                  children: [
                    // Ay Başlığı & Navigasyon
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                          onPressed: _previousMonth,
                        ),
                        Text(
                          '${months[_currentMonth.month]} ${_currentMonth.year}',
                          style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                              onPressed: _nextMonth,
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: _goToToday,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.5)),
                                ),
                                child: Text('Bugün', style: GoogleFonts.inter(color: const Color(0xFFFF6B6B), fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Hafta Günleri
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: List.generate(7, (index) {
                        bool isTodayWeekday = _today.weekday - 1 == index && _currentMonth.month == _today.month && _currentMonth.year == _today.year;
                        return SizedBox(
                          width: 34,
                          child: Text(
                            daysOfWeek[index],
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: isTodayWeekday ? const Color(0xFFDC2626) : const Color(0xFF94A3B8),
                            ),
                          ),
                        );
                      }),
                    ),

                    const SizedBox(height: 10),

                    // 7x5 Ay Gün Matrisi
                    GridView.builder(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        childAspectRatio: 0.88,
                        mainAxisSpacing: 6,
                        crossAxisSpacing: 6,
                      ),
                      itemCount: emptySlots + daysInMonth,
                      itemBuilder: (context, index) {
                        if (index < emptySlots) return const SizedBox();

                        int day = index - emptySlots + 1;
                        DateTime date = DateTime(_currentMonth.year, _currentMonth.month, day);
                        bool isToday = date.year == _today.year && date.month == _today.month && date.day == _today.day;
                        bool isSelected = date.year == _selectedDay.year && date.month == _selectedDay.month && date.day == _selectedDay.day;

                        ShiftType shift = ShiftLogic.getShiftType(date, vardiyaGunu: _selectedVardiya);
                        Color shiftColor = _getShiftColor(shift);
                        String? bayram = HolidayLogic.getHolidayName(date);

                        bool isDimmed = _filterShiftType != null && _filterShiftType != shift;
                        double cellOpacity = isDimmed ? 0.22 : 1.0;

                        Color bgColor = isSelected
                            ? (isToday ? const Color(0xFFDC2626) : shiftColor.withValues(alpha: 0.35))
                            : (isToday ? const Color(0xFFDC2626).withValues(alpha: 0.85) : shiftColor.withValues(alpha: 0.08));
                        Color textColor = isToday || isSelected ? Colors.white : shiftColor;
                        Color dotColor = isToday || isSelected ? Colors.white : shiftColor;

                        return Opacity(
                          opacity: cellOpacity,
                          child: BouncyTap(
                            onTap: () {
                              setState(() {
                                _selectedDay = date;
                              });
                              HapticFeedback.selectionClick();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              decoration: BoxDecoration(
                                color: bgColor,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected
                                      ? (isToday ? Colors.white : shiftColor)
                                      : (isToday ? const Color(0xFFDC2626) : (bayram != null ? const Color(0xFFF59E0B).withValues(alpha: 0.6) : Colors.transparent)),
                                  width: isSelected ? 2.0 : 1.0,
                                ),
                                boxShadow: isSelected
                                    ? [
                                        BoxShadow(
                                          color: (isToday ? const Color(0xFFDC2626) : shiftColor).withValues(alpha: 0.45),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        day.toString(),
                                        style: GoogleFonts.inter(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w800,
                                          color: textColor,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        width: 5,
                                        height: 5,
                                        decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
                                      ),
                                    ],
                                  ),
                                  // Bayram Yıldız Simgesi
                                  if (bayram != null)
                                    Positioned(
                                      top: 2,
                                      right: 2,
                                      child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 10),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 18),

                    // 📊 Aylık Vardiya Dağılım Hapları (Filtreleme)
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFilterPill('Gündüz', gunduzCount, const Color(0xFFF59E0B), ShiftType.sabah),
                        _buildFilterPill('Gece', geceCount, const Color(0xFF3B82F6), ShiftType.gece),
                        _buildFilterPill('Akşam', aksamCount, const Color(0xFF8B5CF6), ShiftType.aksam),
                        _buildFilterPill('İzin', izinCount, const Color(0xFF10B981), ShiftType.tatil),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── SEÇİLEN GÜN DETAY KARTI ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFF12141C),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: isSelectedToday ? selectedColor.withValues(alpha: 0.6) : const Color(0xFF272A36),
                    width: isSelectedToday ? 1.5 : 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(color: selectedColor.withValues(alpha: 0.12), blurRadius: 20, offset: const Offset(0, 8)),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: selectedColor.withValues(alpha: 0.18),
                            shape: BoxShape.circle,
                            border: Border.all(color: selectedColor.withValues(alpha: 0.4), width: 1.2),
                          ),
                          child: Icon(_getShiftIcon(selectedShift), color: selectedColor, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _getShiftName(selectedShift),
                                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  if (isSelectedToday) ...[
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.6)),
                                      ),
                                      child: Text('BUGÜN', style: GoogleFonts.inter(color: const Color(0xFFFF8A80), fontSize: 9, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E212D),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      _getShiftTime(selectedShift),
                                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: const Color(0xFFCBD5E1)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${_selectedDay.day} ${months[_selectedDay.month]} ${_selectedDay.year}',
                                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                                  ),
                                ],
                              ),
                              if (selectedShift != ShiftType.tatil) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    const Icon(Icons.coffee_rounded, size: 13, color: Color(0xFFF59E0B)),
                                    const SizedBox(width: 5),
                                    Text(
                                      'Çay & Yemek Molası: ${ShiftLogic.getBreakTime(selectedShift)}',
                                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (!isSelectedToday)
                          BouncyTap(
                            onTap: _goToToday,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.replay_rounded, color: Colors.white70, size: 18),
                            ),
                          ),
                      ],
                    ),

                    if (holidayName != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 18),
                            const SizedBox(width: 8),
                            Text(
                              holidayName,
                              style: GoogleFonts.inter(color: const Color(0xFFFCD34D), fontSize: 12, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── 📊 fl_chart AYLIK ÇALIŞMA ANALİTİĞİ ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: _buildMonthlyAnalyticsCard(gunduzCount, geceCount, aksamCount, izinCount, daysInMonth),
            ),

            const SizedBox(height: 16),

            // ── 📄 A4 VARDİYA CETVELİ PDF İNDİR BUTONU ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6)),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: _isGeneratingPdf ? null : _generateAndShareVardiyaPdf,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFDC2626),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Center(
                              child: _isGeneratingPdf
                                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                  : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'AYLIK VARDİYA CETVELİNİ İNDİR',
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.3),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Resmi İSDEMİR A4 Çizelgesi (PDF)',
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.share_rounded, color: Colors.white70, size: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // ── VARDİYA KILAVUZU ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Vardiya Kılavuzu & Mola Saatleri',
                    style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildGuideCard(ShiftType.sabah, '09:30 - 16:30', '12:00 - 12:30 Mola', '08:45 Servis')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGuideCard(ShiftType.gece, '00:30 - 09:30', '03:00 - 03:30 Mola', '23:45 Servis')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: _buildGuideCard(ShiftType.aksam, '16:30 - 24:30', '19:00 - 19:30 Mola', '15:45 Servis')),
                      const SizedBox(width: 12),
                      Expanded(child: _buildGuideCard(ShiftType.tatil, 'Hafta Tatili', 'Mola Yok', 'Tam Gün İzin')),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 100),
          ],
        ),
      ),
    ),
  );
  }

  // ── 📱 Canlı Vardiya Hub Widget'ı ──
  Widget _buildLiveActivityHub(ShiftType todayShift, ShiftProgressInfo? todayProgress) {
    final color = _getShiftColor(todayShift);
    final bool isInBreak = todayProgress?.isInBreak == true;
    final bool isInShift = todayProgress?.isInShift == true;

    Color hubBorderColor = color.withValues(alpha: 0.3);
    Color hubGlowColor = color;
    if (isInBreak) {
      hubBorderColor = const Color(0xFFF59E0B).withValues(alpha: 0.6);
      hubGlowColor = const Color(0xFFF59E0B);
    } else if (isInShift) {
      hubBorderColor = const Color(0xFF00FF66).withValues(alpha: 0.5);
      hubGlowColor = const Color(0xFF00FF66);
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: hubBorderColor,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: hubGlowColor.withValues(alpha: 0.18),
            blurRadius: 20,
            offset: const Offset(0, 6),
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
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isInBreak
                          ? const Color(0xFFF59E0B)
                          : (isInShift ? const Color(0xFF00FF66) : const Color(0xFF64748B)),
                      boxShadow: [
                        BoxShadow(
                          color: (isInBreak
                                  ? const Color(0xFFF59E0B)
                                  : (isInShift ? const Color(0xFF00FF66) : const Color(0xFF64748B)))
                              .withValues(alpha: 0.6),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isInBreak
                        ? '☕ ÇAY VE YEMEK MOLASINDASINIZ'
                        : (isInShift ? 'CANLI VARDİYA AKTİF' : 'GÜNÜN VARDİYASI'),
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                      color: isInBreak
                          ? const Color(0xFFF59E0B)
                          : (isInShift ? const Color(0xFF00FF66) : const Color(0xFF94A3B8)),
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isInBreak ? const Color(0xFFF59E0B) : color).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getShiftTime(todayShift),
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: isInBreak ? const Color(0xFFFBBF24) : color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: (isInBreak ? const Color(0xFFF59E0B) : color).withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isInBreak ? Icons.restaurant_rounded : _getShiftIcon(todayShift),
                  color: isInBreak ? const Color(0xFFFBBF24) : color,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getShiftName(todayShift),
                      style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      todayProgress?.statusText ?? 'Bugün dinlenme gününüz.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: isInBreak ? const Color(0xFFFCD34D) : const Color(0xFF94A3B8),
                        fontWeight: isInBreak ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              if (todayProgress != null)
                Text(
                  todayProgress.remainingTimeString,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),

          // 🍵 Aktif Mola Bildirim Bandı
          if (isInBreak && todayProgress?.breakRemainingString != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF3B2508), Color(0xFF261908)],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.coffee_rounded, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Afiyet olsun! Molanın bitimine:',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                  Text(
                    '${todayProgress!.breakRemainingString} kaldı',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Canlı İlerleme Çubuğu
          if (todayProgress?.isInShift == true) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: todayProgress!.progress,
                minHeight: 6,
                backgroundColor: const Color(0xFF222634),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isInBreak ? const Color(0xFFF59E0B) : const Color(0xFF00FF66),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Başlangıç: ${_getShiftTime(todayShift).split(' - ').first}', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
                Text(
                  '%${(todayProgress.progress * 100).toInt()} Tamamlandı',
                  style: GoogleFonts.inter(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: isInBreak ? const Color(0xFFFBBF24) : const Color(0xFF00FF66),
                  ),
                ),
                Text('Bitiş: ${_getShiftTime(todayShift).split(' - ').last}', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
              ],
            ),
          ],

          // Mola & Servis Bilgisi
          if (todayProgress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: isInBreak
                    ? const Color(0xFFF59E0B).withValues(alpha: 0.12)
                    : const Color(0xFF0D0F15),
                borderRadius: BorderRadius.circular(10),
                border: isInBreak
                    ? Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.coffee_rounded,
                          color: isInBreak ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              todayProgress.breakInfo,
                              maxLines: 1,
                              style: GoogleFonts.inter(
                                fontSize: 10.5,
                                color: isInBreak ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
                                fontWeight: isInBreak ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 4), color: const Color(0xFF272A36)),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: Color(0xFF3B82F6), size: 13),
                        const SizedBox(width: 5),
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              todayProgress.shuttleInfo,
                              maxLines: 1,
                              style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickVardiyaTab(VardiyaGunu gun, String title) {
    final isSelected = _selectedVardiya == gun;
    return Expanded(
      child: GestureDetector(
        onTap: () => _changeVardiya(gun),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFDC2626) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFFCBD5E1),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── 📊 fl_chart Aylık Analitik Kartı ──
  Widget _buildMonthlyAnalyticsCard(int gunduz, int gece, int aksam, int tatil, int totalDays) {
    int totalHours = (gunduz + gece + aksam) * 8;

    List<PieChartSectionData> sections = [];
    if (gunduz > 0) {
      final isTouched = _touchedChartIndex == 0;
      sections.add(PieChartSectionData(
        color: const Color(0xFFF59E0B),
        value: gunduz.toDouble(),
        title: isTouched ? '${gunduz * 8}h' : '%${(gunduz / totalDays * 100).round()}',
        radius: isTouched ? 38.0 : 30.0,
        titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (gece > 0) {
      final isTouched = _touchedChartIndex == 1;
      sections.add(PieChartSectionData(
        color: const Color(0xFF3B82F6),
        value: gece.toDouble(),
        title: isTouched ? '${gece * 8}h' : '%${(gece / totalDays * 100).round()}',
        radius: isTouched ? 38.0 : 30.0,
        titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (aksam > 0) {
      final isTouched = _touchedChartIndex == 2;
      sections.add(PieChartSectionData(
        color: const Color(0xFF8B5CF6),
        value: aksam.toDouble(),
        title: isTouched ? '${aksam * 8}h' : '%${(aksam / totalDays * 100).round()}',
        radius: isTouched ? 38.0 : 30.0,
        titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }
    if (tatil > 0) {
      final isTouched = _touchedChartIndex == 3;
      sections.add(PieChartSectionData(
        color: const Color(0xFF10B981),
        value: tatil.toDouble(),
        title: isTouched ? '$tatil g' : '%${(tatil / totalDays * 100).round()}',
        radius: isTouched ? 38.0 : 30.0,
        titleStyle: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
      ));
    }

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF272A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Aylık Çalışma Dağılımı (fl_chart)',
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E212D),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Toplam $totalHours Saat',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedChartIndex = -1;
                            return;
                          }
                          _touchedChartIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 2,
                    centerSpaceRadius: 28,
                    sections: sections,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    _buildMiniLegend(const Color(0xFFF59E0B), 'Gündüz', '$gunduz Gün (${gunduz * 8}h)'),
                    _buildMiniLegend(const Color(0xFF3B82F6), 'Gece', '$gece Gün (${gece * 8}h)'),
                    _buildMiniLegend(const Color(0xFF8B5CF6), 'Akşam', '$aksam Gün (${aksam * 8}h)'),
                    _buildMiniLegend(const Color(0xFF10B981), 'Tatil / İzin', '$tatil Gün Dinlenme'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMiniLegend(Color color, String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600)),
            ],
          ),
          Text(val, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, int count, Color color, ShiftType type) {
    final bool isFiltered = _filterShiftType == type;
    return BouncyTap(
      onTap: () {
        setState(() {
          if (_filterShiftType == type) {
            _filterShiftType = null;
          } else {
            _filterShiftType = type;
          }
        });
        HapticFeedback.selectionClick();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isFiltered ? color.withValues(alpha: 0.25) : color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isFiltered ? color : color.withValues(alpha: 0.3),
            width: isFiltered ? 1.6 : 1.0,
          ),
          boxShadow: isFiltered
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 8, spreadRadius: 1)]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
            Text(
              '$label ($count)',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: isFiltered ? FontWeight.bold : FontWeight.w600,
                color: isFiltered ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGuideCard(ShiftType type, String time, String breakTime, String shuttle) {
    Color color = _getShiftColor(type);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(_getShiftIcon(type), color: color, size: 22),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _getShiftName(type),
            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: GoogleFonts.inter(fontSize: 11, color: color, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: Color(0xFF272A36)),
          const SizedBox(height: 8),
          Text('☕ $breakTime', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
          Text('🚌 $shuttle', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
        ],
      ),
    );
  }
}
