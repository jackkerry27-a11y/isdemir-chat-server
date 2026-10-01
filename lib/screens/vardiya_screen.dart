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

class AiBridgeOpportunity {
  final String title;
  final String description;
  final String leaveDaysText;
  final String totalOffDaysText;
  final String efficiencyBadge;
  final List<DateTime> leaveDates;
  final DateTime holidayDate;

  AiBridgeOpportunity({
    required this.title,
    required this.description,
    required this.leaveDaysText,
    required this.totalOffDaysText,
    required this.efficiencyBadge,
    required this.leaveDates,
    required this.holidayDate,
  });
}

class _VardiyaScreenState extends State<VardiyaScreen> with TickerProviderStateMixin {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  late DateTime _selectedDay;
  VardiyaGunu _selectedVardiya = VardiyaGunu.sali;
  ShiftType? _filterShiftType;
  Timer? _countdownTimer;
  DateTime _now = DateTime.now();
  bool _isGeneratingPdf = false;

  // 🧠 AI Super-Cockpit: 0 = ChronoPlan İzin, 1 = Sirkadiyen Biyoritim, 2 = NASA SAFTE
  int _selectedAiTab = 0;

  // 🌌 Apple VisionOS Aurora Arka Plan Animasyon Kontrolcüsü
  late AnimationController _auroraController;

  @override
  void initState() {
    super.initState();
    _selectedDay = _today;
    _loadSelectedVardiya();
    _checkAndPromptVardiya();

    _auroraController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
    )..repeat(reverse: true);

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
    _auroraController.dispose();
    super.dispose();
  }

  Future<void> _checkAndPromptVardiya() async {
    final prefs = await SharedPreferences.getInstance();
    final hasPrompted = prefs.getBool('has_prompted_vardiya_v2') ?? false;
    final saved = prefs.getString('selected_vardiya_gunu');

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
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35)),
                      ),
                      child: const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 28),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hangi Posta Grubundasın?',
                            style: GoogleFonts.inter(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'ChronoPlan™ AI takviminizi ve izinlerinizi optimize edecek',
                            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ),
                  ],
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
                  color: const Color(0xFF38BDF8),
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
                      '$postaLabel kaydedildi. AI Takvimi hazır!',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFF10B981),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          );
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? color : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
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
              color: isSelected ? color : const Color(0xFF64748B),
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
      setState(() => _selectedVardiya = VardiyaGunu.carsamba);
    } else if (saved == 'cuma') {
      setState(() => _selectedVardiya = VardiyaGunu.cuma);
    } else if (saved == 'cumartesi') {
      setState(() => _selectedVardiya = VardiyaGunu.cumartesi);
    } else if (saved == 'sali') {
      setState(() => _selectedVardiya = VardiyaGunu.sali);
    }
  }

  Future<void> _changeVardiya(VardiyaGunu newVardiya) async {
    setState(() => _selectedVardiya = newVardiya);
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
        return '1. Posta (Salı Grubu)';
      case VardiyaGunu.carsamba:
        return '2. Posta (Çarşamba Grubu)';
      case VardiyaGunu.cuma:
        return '3. Posta (Cuma Grubu)';
      case VardiyaGunu.cumartesi:
        return '4. Posta (Cumartesi Grubu)';
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
        statusText: isInBreak ? '☕ Çay & Yemek Molası' : 'Vardiya Bitimine',
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
        return const Color(0xFFF59E0B); // Amber Gündüz
      case ShiftType.gece:
        return const Color(0xFF38BDF8); // Buz Mavisi Gece
      case ShiftType.aksam:
        return const Color(0xFFA78BFA); // Soft Mor Akşam
      case ShiftType.tatil:
        return const Color(0xFF10B981); // Zümrüt İzin
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
        return 'İstirahat Günü';
    }
  }

  // ── 🧠 OPTION 1: CHRONOPLAN™ AI İZİN & KÖPRÜLEME MOTORU ──
  List<AiBridgeOpportunity> _getBridgeOpportunities() {
    final year = _currentMonth.year;
    return [
      AiBridgeOpportunity(
        title: '29 Ekim Cumhuriyet Bayramı Köprüsü',
        description: '28 Ekim yarım gün + 30 Ekim Cuma yıllık izin ile hafta tatilinizi birleştirin.',
        leaveDaysText: '1.5 Gün İzin',
        totalOffDaysText: '5 Gün Blok Tatil',
        efficiencyBadge: '%233 Verim',
        leaveDates: [DateTime(year, 10, 28), DateTime(year, 10, 30)],
        holidayDate: DateTime(year, 10, 29),
      ),
      AiBridgeOpportunity(
        title: '23 Nisan Ulusal Egemenlik Köprüsü',
        description: 'Perşembe resmi tatilini Cuma 1 gün izin ile haftalık dinlenmeye bağlayın.',
        leaveDaysText: '1 Gün İzin',
        totalOffDaysText: '4 Gün Kesintisiz',
        efficiencyBadge: '%300 Verim',
        leaveDates: [DateTime(year, 4, 24)],
        holidayDate: DateTime(year, 4, 23),
      ),
      AiBridgeOpportunity(
        title: '19 Mayıs Gençlik & Spor Köprüsü',
        description: 'Pazartesi 1 gün izin alarak hafta sonunu Salı resmi bayramıyla bağlayın.',
        leaveDaysText: '1 Gün İzin',
        totalOffDaysText: '4 Gün Dinlenme',
        efficiencyBadge: '%300 Verim',
        leaveDates: [DateTime(year, 5, 18)],
        holidayDate: DateTime(year, 5, 19),
      ),
      AiBridgeOpportunity(
        title: 'Büyük Kurban Bayramı AI Mega Bloğu',
        description: 'Bayram arifesi öncesi 2 gün yıllık izin kullanarak 9 günlük kesintisiz tatil yaratın.',
        leaveDaysText: '2 Gün İzin',
        totalOffDaysText: '9 Gün Blok Tatil',
        efficiencyBadge: '%350 Verim',
        leaveDates: [DateTime(year, 5, 25), DateTime(year, 5, 26)],
        holidayDate: DateTime(year, 5, 27),
      ),
    ];
  }

  AiBridgeOpportunity _getActiveBridgeForCurrentMonth() {
    final list = _getBridgeOpportunities();
    for (final op in list) {
      if (op.holidayDate.month == _currentMonth.month) {
        return op;
      }
    }
    for (final op in list) {
      if (op.holidayDate.isAfter(_now.subtract(const Duration(days: 1)))) {
        return op;
      }
    }
    return list.first;
  }

  bool _isAiBridgeDate(DateTime date) {
    for (final op in _getBridgeOpportunities()) {
      if (op.holidayDate.year == date.year &&
          op.holidayDate.month == date.month &&
          op.holidayDate.day == date.day) {
        return true;
      }
      for (final l in op.leaveDates) {
        if (l.year == date.year && l.month == date.month && l.day == date.day) {
          return true;
        }
      }
    }
    return false;
  }

  // ── 🧬 OPTION 1: SİRKADİYEN BİYORİTİM HESAPLAYICI ──
  int _getCircadianScore(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return 92;
      case ShiftType.aksam:
        return 79;
      case ShiftType.gece:
        if (_now.hour >= 3 && _now.hour <= 5) return 56;
        return 66;
      case ShiftType.tatil:
        return 98;
    }
  }

  Color _getCircadianColor(int score) {
    if (score >= 90) return const Color(0xFF10B981);
    if (score >= 75) return const Color(0xFF38BDF8);
    if (score >= 60) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  String _getCircadianStatus(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return 'Optimum Uyanıklık • Yüksek Kortizol Zirvesi';
      case ShiftType.aksam:
        return 'Dengeli Biyoritim • 21:00 Melatonin Kayması';
      case ShiftType.gece:
        return 'Sirkadiyen Dip • 03:00-05:00 Yüksek Dikkat Riski';
      case ShiftType.tatil:
        return 'Hücresel Yenilenme • REM İyileşmesi';
    }
  }

  // ── 🚀 OPTION 3: NASA SAFTE™ KOGNİTİF YORGUNLUK & ROTASYON RADARI ──
  Map<String, dynamic> _calculateRotationRadar() {
    int daysToNight = 0;
    int daysToRest = 0;
    int daysToRotation = 0;

    ShiftType todayShift = ShiftLogic.getShiftType(_today, vardiyaGunu: _selectedVardiya);
    bool foundNight = false;
    bool foundRest = false;
    bool foundRotation = false;

    for (int i = 1; i <= 30; i++) {
      DateTime checkDate = _today.add(Duration(days: i));
      ShiftType s = ShiftLogic.getShiftType(checkDate, vardiyaGunu: _selectedVardiya);

      if (!foundRest && s == ShiftType.tatil) {
        daysToRest = i;
        foundRest = true;
      }
      if (!foundNight && s == ShiftType.gece) {
        daysToNight = i;
        foundNight = true;
      }
      if (!foundRotation && s != todayShift && s != ShiftType.tatil) {
        daysToRotation = i;
        foundRotation = true;
      }
      if (foundNight && foundRest && foundRotation) break;
    }

    return {
      'daysToNight': daysToNight,
      'daysToRest': daysToRest,
      'daysToRotation': daysToRotation,
    };
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
                        pw.Text(safe('AYLIK PERSONEL VARDİYA ÇALIŞMA CETVELİ (VISION AI)'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
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
                    pw.Text(safe('Oluşturulma: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
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
        return _buildVisionOSSheetContainer(
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.sync_rounded, color: Color(0xFF38BDF8), size: 22),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Posta Grubu Değiştir',
                          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Hafta tatili gününüze göre posta seçin',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA)),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.close_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildVardiyaItem(VardiyaGunu.sali, '1. Posta (Salı Grubu)', 'Hafta Tatili: ', 'Salı Günleri', _selectedVardiya == VardiyaGunu.sali),
              _buildVardiyaItem(VardiyaGunu.carsamba, '2. Posta (Çarşamba Grubu)', 'Hafta Tatili: ', 'Çarşamba Günleri', _selectedVardiya == VardiyaGunu.carsamba),
              _buildVardiyaItem(VardiyaGunu.cuma, '3. Posta (Cuma Grubu)', 'Hafta Tatili: ', 'Cuma Günleri', _selectedVardiya == VardiyaGunu.cuma),
              _buildVardiyaItem(VardiyaGunu.cumartesi, '4. Posta (Cumartesi Grubu)', 'Hafta Tatili: ', 'Cumartesi Günleri', _selectedVardiya == VardiyaGunu.cumartesi),
            ],
          ),
        );
      },
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

  Widget _buildVardiyaItem(VardiyaGunu gun, String title, String subtitleLabel, String subtitleHighlight, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _changeVardiya(gun);
        Navigator.pop(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.12),
            width: isSelected ? 1.6 : 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF38BDF8).withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month_rounded,
                  color: isSelected ? const Color(0xFF38BDF8) : const Color(0xFFA1A1AA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 2),
                    RichText(
                      text: TextSpan(
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA1A1AA)),
                        children: [
                          TextSpan(text: subtitleLabel),
                          TextSpan(text: subtitleHighlight, style: const TextStyle(color: Color(0xFF38BDF8), fontWeight: FontWeight.bold)),
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
                  color: isSelected ? const Color(0xFF38BDF8) : Colors.transparent,
                  border: Border.all(
                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.25),
                    width: 2,
                  ),
                ),
                child: isSelected ? const Icon(Icons.check_rounded, color: Colors.black, size: 14) : null,
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
                  children: [
                    // 🌟 VisionOS Spatial Floating Header
                    _buildTopSpatialGlassBar(),

                    const SizedBox(height: 14),

                    // 📱 VisionOS Canlı Vardiya Kapsülü
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildLiveShiftVisionCard(todayShift, todayProgress)
                          .animate()
                          .fadeIn(duration: 400.ms)
                          .slideY(begin: 0.06, end: 0, curve: Curves.easeOutCubic),
                    ),

                    const SizedBox(height: 16),

                    // 🧠 VisionOS AI Super-Cockpit Adası (ChronoPlan™ & NASA SAFTE™)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionAiSuperCockpit(todayShift),
                    ),

                    const SizedBox(height: 18),

                    // 📅 VisionOS Spatial Takvim Izgarası
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionSpatialCalendar(months, daysOfWeek, emptySlots, daysInMonth, gunduzCount, geceCount, aksamCount, izinCount),
                    ),

                    const SizedBox(height: 16),

                    // 🎯 VisionOS Seçilen Gün Detay Kartı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildVisionSelectedDayCard(selectedShift, selectedColor, isSelectedToday, holidayName),
                    ),

                    const SizedBox(height: 16),

                    // 📄 VisionOS A4 Vardiya Cetveli Hızlı Paylaşım Barı
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
            // Derin Uzay Siyahı
            Container(color: const Color(0xFF07090E)),

            // Aurora 1 (Üst Sol - Cyan / Azure Işık Küresi)
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
                      const Color(0xFF0284C7).withValues(alpha: 0.28),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 2 (Orta Sağ - Yumuşak Mor / Violet Işık Küresi)
            Positioned(
              top: 240 - (t * 60),
              right: -50 + (t * 25),
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF7C3AED).withValues(alpha: 0.22),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 3 (Alt Sol - Zümrüt / Emerald Dinlenme Parıltısı)
            Positioned(
              bottom: 80 + (t * 35),
              left: -30 + (t * 45),
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF10B981).withValues(alpha: 0.20),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Aurora 4 (Alt Sağ - Sıcak Amber Vardiya Parıltısı)
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
                      const Color(0xFFF59E0B).withValues(alpha: 0.16),
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
            const Color(0xFF0F1320).withValues(alpha: 0.85),
            Colors.transparent,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildVisionIconButton(
                    icon: Icons.arrow_back_ios_new_rounded,
                    onTap: _handleBack,
                    iconSize: 16,
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          const SizedBox(width: 8),
                          _buildVisionPillBadge('VISION AI', const Color(0xFF38BDF8)),
                        ],
                      ),
                      Text(
                        'İSDEMİR Liman & Çelik Operasyonu',
                        style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              _buildVisionIconButton(
                icon: Icons.picture_as_pdf_rounded,
                isLoading: _isGeneratingPdf,
                onTap: _isGeneratingPdf ? null : _generateAndShareVardiyaPdf,
                iconSize: 18,
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Posta Grubu Hızlı Seçici Glass Rozeti
          BouncyTap(
            onTap: _showVardiyaSelectionModal,
            child: _buildVisionGlassContainer(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              borderRadius: 18,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                    ),
                    child: const Icon(Icons.shield_rounded, color: Color(0xFF38BDF8), size: 16),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getVardiyaGunuName(_selectedVardiya),
                          style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        Text(
                          'Döngüyü veya hafta tatilinizi değiştirmek için dokunun',
                          style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8), size: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 📱 VisionOS Canlı Vardiya Kapsülü
  Widget _buildLiveShiftVisionCard(ShiftType todayShift, ShiftProgressInfo? todayProgress) {
    final color = _getShiftColor(todayShift);
    final bool isInBreak = todayProgress?.isInBreak == true;
    final bool isInShift = todayProgress?.isInShift == true;

    Color glowColor = isInBreak ? const Color(0xFFF59E0B) : (isInShift ? const Color(0xFF10B981) : const Color(0xFF64748B));

    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(18),
      borderRadius: 24,
      borderColor: glowColor.withValues(alpha: 0.35),
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
                      color: glowColor,
                      boxShadow: [
                        BoxShadow(
                          color: glowColor.withValues(alpha: 0.8),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isInBreak
                        ? 'MOLA AKTİF'
                        : (isInShift ? 'CANLI VARDİYA AKTİF' : 'GÜNÜN ÇALIŞMA PLANI'),
                    style: GoogleFonts.inter(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      color: glowColor,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                ),
                child: Text(
                  _getShiftTime(todayShift),
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: (isInBreak ? const Color(0xFFF59E0B) : color).withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: (isInBreak ? const Color(0xFFF59E0B) : color).withValues(alpha: 0.4)),
                ),
                child: Icon(
                  isInBreak ? Icons.coffee_rounded : _getShiftIcon(todayShift),
                  color: isInBreak ? const Color(0xFFFBBF24) : color,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getShiftName(todayShift),
                      style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    Text(
                      todayProgress?.statusText ?? 'Bugün dinlenme gününüz.',
                      style: GoogleFonts.inter(
                        fontSize: 11.5,
                        color: isInBreak ? const Color(0xFFFCD34D) : const Color(0xFF94A3B8),
                        fontWeight: isInBreak ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              if (todayProgress != null)
                Text(
                  todayProgress.remainingTimeString,
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
            ],
          ),

          // Mola Kalan Sayacı
          if (isInBreak && todayProgress?.breakRemainingString != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.coffee_rounded, color: Color(0xFFFBBF24), size: 16),
                      const SizedBox(width: 8),
                      Text(
                        'Çay & Yemek Molası Bitişine:',
                        style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFFFDE68A)),
                      ),
                    ],
                  ),
                  Text(
                    '${todayProgress!.breakRemainingString} kaldı',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFFFBBF24),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Canlı Vardiya İlerleme Çubuğu (VisionOS Capsule)
          if (todayProgress?.isInShift == true) ...[
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: todayProgress!.progress,
                minHeight: 6,
                backgroundColor: Colors.white.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(
                  isInBreak ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
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
                    color: isInBreak ? const Color(0xFFFBBF24) : const Color(0xFF10B981),
                  ),
                ),
                Text('Bitiş: ${_getShiftTime(todayShift).split(' - ').last}', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
              ],
            ),
          ],

          // Mola & Servis Bilgi Hapları
          if (todayProgress != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.coffee_rounded, color: Color(0xFFF59E0B), size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            todayProgress.breakInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 14, margin: const EdgeInsets.symmetric(horizontal: 6), color: Colors.white.withValues(alpha: 0.15)),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.directions_bus_rounded, color: Color(0xFF38BDF8), size: 14),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            todayProgress.shuttleInfo,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
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

  // 🧠 VisionOS AI Super-Cockpit Adası
  Widget _buildVisionAiSuperCockpit(ShiftType todayShift) {
    return _buildVisionGlassContainer(
      padding: EdgeInsets.zero,
      borderRadius: 24,
      child: Column(
        children: [
          // Segmented Tab Başlıkları (Spatial Floating Pills)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                _buildVisionSegmentPill(0, '🏖️ ChronoPlan™', const Color(0xFF10B981)),
                const SizedBox(width: 6),
                _buildVisionSegmentPill(1, '🧬 Sirkadiyen', const Color(0xFF38BDF8)),
                const SizedBox(width: 6),
                _buildVisionSegmentPill(2, '🚀 NASA SAFTE™', const Color(0xFFF59E0B)),
              ],
            ),
          ),

          // Aktif Tab İçeriği
          Padding(
            padding: const EdgeInsets.only(left: 16, right: 16, bottom: 16, top: 4),
            child: _selectedAiTab == 0
                ? _buildChronoPlanTabContent()
                : (_selectedAiTab == 1
                    ? _buildCircadianTabContent(todayShift)
                    : _buildNasaSafteTabContent(todayShift)),
          ),
        ],
      ),
    );
  }

  Widget _buildVisionSegmentPill(int index, String title, Color activeColor) {
    final isSelected = _selectedAiTab == index;
    return Expanded(
      child: BouncyTap(
        onTap: () {
          setState(() => _selectedAiTab = index);
          HapticFeedback.selectionClick();
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
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
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // 🏖️ TAB 0: ChronoPlan™ AI Smart Leave & Bridge Optimizer
  Widget _buildChronoPlanTabContent() {
    final activeBridge = _getActiveBridgeForCurrentMonth();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded, color: Color(0xFF10B981), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'ChronoPlan™ AI İzin Analizi',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.45)),
              ),
              child: Text(
                activeBridge.efficiencyBadge,
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          activeBridge.title,
          style: GoogleFonts.inter(fontSize: 14.5, fontWeight: FontWeight.w800, color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          activeBridge.description,
          style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.35),
        ),

        const SizedBox(height: 12),

        // Köprüleme Karşılaştırma Kutusu
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('KULLANILAN İZİN', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(activeBridge.leaveDaysText, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFFF59E0B))),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981), size: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('KAZANILAN TATİL', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(activeBridge.totalOffDaysText, style: GoogleFonts.inter(fontSize: 13.5, fontWeight: FontWeight.w800, color: const Color(0xFF10B981))),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // 🧬 TAB 1: Circadian Biological Alertness & Energy Heatmap
  Widget _buildCircadianTabContent(ShiftType todayShift) {
    int score = _getCircadianScore(todayShift);
    Color scoreColor = _getCircadianColor(score);
    String status = _getCircadianStatus(todayShift);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.biotech_rounded, color: Color(0xFF38BDF8), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Sirkadiyen Biyoritim Analizi',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFF38BDF8)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: scoreColor.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: scoreColor.withValues(alpha: 0.35)),
              ),
              child: Text(
                '%$score Uyanıklık',
                style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.w800, color: scoreColor),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: score / 100.0,
            minHeight: 6,
            backgroundColor: Colors.white.withValues(alpha: 0.08),
            valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          status,
          style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w700, color: Colors.white),
        ),
        const SizedBox(height: 3),
        Text(
          todayShift == ShiftType.gece
              ? 'Gece vardiyasında saat 03:00 - 05:00 arası vücut sıcaklığı en düşük seviyededir. Kafein ve parlak ışık desteği tavsiye edilir.'
              : (todayShift == ShiftType.tatil
                  ? 'Kümülatif yorgunluğu sıfırlamak için 8+ saat uyku penceresi kullanın.'
                  : 'Gündüz vardiyasında kortizol zirvesi ile reaksiyon süreniz maksimum seviyededir.'),
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), height: 1.35),
        ),
      ],
    );
  }

  // 🚀 TAB 2: NASA SAFTE™ Cognitive Engine & Rotation Radar
  Widget _buildNasaSafteTabContent(ShiftType todayShift) {
    final radar = _calculateRotationRadar();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.rocket_launch_rounded, color: Color(0xFFF59E0B), size: 16),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'NASA SAFTE™ Kognitif Radar',
                style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w800, color: const Color(0xFFF59E0B)),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '242 ms Reaksiyon',
                style: GoogleFonts.jetBrainsMono(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: _buildRadarVisionMiniTile('🌙 Geceye', '${radar['daysToNight']} Gün', const Color(0xFF38BDF8)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRadarVisionMiniTile('🏖️ İstirahate', '${radar['daysToRest']} Gün', const Color(0xFF10B981)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildRadarVisionMiniTile('🔄 Döngüye', '${radar['daysToRotation']} Gün', const Color(0xFFA78BFA)),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Text(
          '💡 Operasyonel Tavsiye: Gece vardiyası öncesindeki gün 14:00 - 15:30 arası 90 dk güç uykusu kümülatif uyku borcunu %70 azaltır.',
          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), height: 1.35),
        ),
      ],
    );
  }

  Widget _buildRadarVisionMiniTile(String label, String value, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.jetBrainsMono(fontSize: 13, fontWeight: FontWeight.w800, color: accentColor)),
        ],
      ),
    );
  }

  // 📅 VisionOS Spatial Takvim Izgarası
  Widget _buildVisionSpatialCalendar(
    List<String> months,
    List<String> daysOfWeek,
    int emptySlots,
    int daysInMonth,
    int gunduzCount,
    int geceCount,
    int aksamCount,
    int izinCount,
  ) {
    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 26,
      child: Column(
        children: [
          // Ay Navigasyonu & 'Bugün' Neon Rozeti
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildVisionIconButton(
                icon: Icons.chevron_left_rounded,
                onTap: _previousMonth,
                iconSize: 20,
              ),
              Row(
                children: [
                  const Icon(Icons.calendar_today_rounded, color: Color(0xFF38BDF8), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '${months[_currentMonth.month]} ${_currentMonth.year}',
                    style: GoogleFonts.inter(fontSize: 16.5, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildVisionIconButton(
                    icon: Icons.chevron_right_rounded,
                    onTap: _nextMonth,
                    iconSize: 20,
                  ),
                  const SizedBox(width: 8),
                  BouncyTap(
                    onTap: _goToToday,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0284C7), Color(0xFF0369A1)],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(color: const Color(0xFF0284C7).withValues(alpha: 0.45), blurRadius: 10),
                        ],
                      ),
                      child: Text(
                        'Bugün',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Hafta Gün Başlıkları
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(7, (index) {
              bool isTodayWeekday = _today.weekday - 1 == index &&
                  _currentMonth.month == _today.month &&
                  _currentMonth.year == _today.year;
              return SizedBox(
                width: 36,
                child: Text(
                  daysOfWeek[index],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isTodayWeekday ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                  ),
                ),
              );
            }),
          ),

          const SizedBox(height: 8),

          // 7x5 Ay Gün Matrisi (VisionOS Spatial Grid)
          GridView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.90,
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
              bool isBridgeDay = _isAiBridgeDate(date);
              int circadianScore = _getCircadianScore(shift);
              Color circadianDotColor = _getCircadianColor(circadianScore);

              bool isDimmed = _filterShiftType != null && _filterShiftType != shift;
              double cellOpacity = isDimmed ? 0.20 : 1.0;

              Color bgColor = isSelected
                  ? (isToday ? const Color(0xFF0284C7) : shiftColor.withValues(alpha: 0.35))
                  : (isToday ? const Color(0xFF0284C7).withValues(alpha: 0.85) : shiftColor.withValues(alpha: 0.09));

              Color textColor = isToday || isSelected ? Colors.white : shiftColor;

              return Opacity(
                opacity: cellOpacity,
                child: BouncyTap(
                  onTap: () {
                    setState(() => _selectedDay = date);
                    HapticFeedback.selectionClick();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    decoration: BoxDecoration(
                      color: bgColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? (isToday ? Colors.white : shiftColor)
                            : (isToday
                                ? const Color(0xFF38BDF8)
                                : (bayram != null
                                    ? const Color(0xFFF59E0B).withValues(alpha: 0.6)
                                    : (isBridgeDay ? const Color(0xFF10B981).withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.05)))),
                        width: isSelected ? 2.0 : 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: (isToday ? const Color(0xFF0284C7) : shiftColor).withValues(alpha: 0.45),
                                blurRadius: 12,
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
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 3),
                            // Sirkadiyen Biyoritim Mikro Noktası
                            Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: isSelected || isToday ? Colors.white : circadianDotColor,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: circadianDotColor.withValues(alpha: 0.5),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        // Bayram / AI İzin Rozeti
                        if (bayram != null)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 11),
                          )
                        else if (isBridgeDay)
                          Positioned(
                            top: 2,
                            right: 2,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: const BoxDecoration(
                                color: Color(0xFF10B981),
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 16),

          // 📊 VisionOS Bento Shift Matrix (Filtreleme & Aylık Özet)
          _buildVisionBentoShiftMatrix(gunduzCount, geceCount, aksamCount, izinCount),
        ],
      ),
    );
  }

  // 📊 VisionOS Bento Shift Matrix
  Widget _buildVisionBentoShiftMatrix(int gunduz, int gece, int aksam, int tatil) {
    return Row(
      children: [
        Expanded(child: _buildVisionBentoPill('Gündüz', gunduz, const Color(0xFFF59E0B), ShiftType.sabah)),
        const SizedBox(width: 6),
        Expanded(child: _buildVisionBentoPill('Gece', gece, const Color(0xFF38BDF8), ShiftType.gece)),
        const SizedBox(width: 6),
        Expanded(child: _buildVisionBentoPill('Akşam', aksam, const Color(0xFFA78BFA), ShiftType.aksam)),
        const SizedBox(width: 6),
        Expanded(child: _buildVisionBentoPill('İzin', tatil, const Color(0xFF10B981), ShiftType.tatil)),
      ],
    );
  }

  Widget _buildVisionBentoPill(String label, int count, Color color, ShiftType type) {
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
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: isFiltered ? color.withValues(alpha: 0.28) : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isFiltered ? color : Colors.white.withValues(alpha: 0.12),
            width: isFiltered ? 1.6 : 1.0,
          ),
          boxShadow: isFiltered
              ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 10)]
              : null,
        ),
        child: Column(
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: isFiltered ? Colors.white : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '$count g',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isFiltered ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 🎯 VisionOS Seçilen Gün Detay Kartı
  Widget _buildVisionSelectedDayCard(ShiftType selectedShift, Color selectedColor, bool isSelectedToday, String? holidayName) {
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    int circadianScore = _getCircadianScore(selectedShift);
    Color circadianColor = _getCircadianColor(circadianScore);

    return _buildVisionGlassContainer(
      padding: const EdgeInsets.all(16),
      borderRadius: 24,
      borderColor: isSelectedToday ? selectedColor.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: selectedColor.withValues(alpha: 0.22),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: selectedColor.withValues(alpha: 0.4)),
                ),
                child: Icon(_getShiftIcon(selectedShift), color: selectedColor, size: 24),
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
                          style: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                        if (isSelectedToday) ...[
                          const SizedBox(width: 8),
                          _buildVisionPillBadge('BUGÜN', const Color(0xFF38BDF8)),
                        ],
                      ],
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Text(
                          '${_selectedDay.day} ${months[_selectedDay.month]} ${_selectedDay.year}',
                          style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getShiftTime(selectedShift),
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFFCBD5E1)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (!isSelectedToday)
                _buildVisionIconButton(
                  icon: Icons.replay_rounded,
                  onTap: _goToToday,
                  iconSize: 16,
                ),
            ],
          ),

          if (holidayName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.35)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.star_rounded, color: Color(0xFFF59E0B), size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      holidayName,
                      style: GoogleFonts.inter(color: const Color(0xFFFCD34D), fontSize: 11.5, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (selectedShift != ShiftType.tatil) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.coffee_rounded, size: 13, color: Color(0xFFF59E0B)),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Mola: ${ShiftLogic.getBreakTime(selectedShift)}',
                            style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.biotech_rounded, size: 13, color: circadianColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Sirkadiyen: %$circadianScore',
                            style: GoogleFonts.jetBrainsMono(fontSize: 10.5, color: circadianColor, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // 📄 VisionOS A4 Vardiya Cetveli Hızlı Paylaşım Barı
  Widget _buildVisionPdfShareActionBar() {
    return BouncyTap(
      onTap: _isGeneratingPdf ? null : _generateAndShareVardiyaPdf,
      child: _buildVisionGlassContainer(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        borderRadius: 22,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.45)),
              ),
              child: _isGeneratingPdf
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf_rounded, color: Color(0xFF38BDF8), size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Aylık Vardiya Cetveli (Resmi A4 PDF)',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'İSDEMİR formatında indir, yazdır veya WhatsApp ile paylaş',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                  ),
                ],
              ),
            ),
            const Icon(Icons.share_rounded, color: Color(0xFF38BDF8), size: 18),
          ],
        ),
      ),
    );
  }

  // ── 💎 VISIONOS YARDIMCI BİLEŞENLERİ ──

  // Gerçek Apple VisionOS Buzlu Cam Konteyneri (60/120 FPS Buttery Smooth)
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

  // VisionOS İkon Butonu
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

  // VisionOS Mini Rozet
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
