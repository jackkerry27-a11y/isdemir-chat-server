import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/pdf_font_helper.dart';

/// İzin Talebi Veri Modeli
class LeaveRequest {
  final String id;
  final String title;
  final String leaveType; // 'Yıllık İzin', 'Mazeret İzni', 'Evlilik İzni', 'Doğum İzni', 'Rapor', 'Ücretsiz İzin'
  final DateTime startDate;
  final DateTime endDate;
  final int days;
  final String status; // 'Onaylandı', 'Amir Onayında', 'İK İncelemesinde'
  final String? notes;
  final DateTime createdAt;

  LeaveRequest({
    required this.id,
    required this.title,
    required this.leaveType,
    required this.startDate,
    required this.endDate,
    required this.days,
    required this.status,
    this.notes,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'leaveType': leaveType,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate.toIso8601String(),
    'days': days,
    'status': status,
    'notes': notes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory LeaveRequest.fromJson(Map<String, dynamic> json) => LeaveRequest(
    id: json['id'] as String? ?? '',
    title: json['title'] as String? ?? '',
    leaveType: json['leaveType'] as String? ?? 'Yıllık İzin',
    startDate: DateTime.tryParse(json['startDate'] as String? ?? '') ?? DateTime.now(),
    endDate: DateTime.tryParse(json['endDate'] as String? ?? '') ?? DateTime.now(),
    days: json['days'] as int? ?? 1,
    status: json['status'] as String? ?? 'Onaylandı',
    notes: json['notes'] as String?,
    createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
  );
}

class IzinlerScreen extends StatefulWidget {
  final int ucretliIzinGun;
  final int ucretsizIzinGun;
  final double unpaidLeaveRate;
  final Function(int, int) onIzinChanged;

  const IzinlerScreen({
    super.key,
    required this.ucretliIzinGun,
    required this.ucretsizIzinGun,
    required this.unpaidLeaveRate,
    required this.onIzinChanged,
  });

  @override
  State<IzinlerScreen> createState() => _IzinlerScreenState();
}

class _IzinlerScreenState extends State<IzinlerScreen> {
  late int _ucretliGun;
  late int _ucretsizGun;
  final int _maxUcretli = 14;
  final int _maxUcretsiz = 30;

  UserModel? _currentUser;
  bool _isGeneratingPdf = false;

  final List<LeaveRequest> _leaveRequests = [];

  @override
  void initState() {
    super.initState();
    _ucretliGun = widget.ucretliIzinGun;
    _ucretsizGun = widget.ucretsizIzinGun;
    _loadUser();
    _loadLeaveRequests();
  }

  Future<void> _loadLeaveRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('saved_leave_requests');
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        final loaded = decoded.map((e) => LeaveRequest.fromJson(Map<String, dynamic>.from(e as Map))).toList();
        if (mounted) {
          setState(() {
            _leaveRequests.clear();
            _leaveRequests.addAll(loaded);
            _recalculateDaysFromRequests();
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _leaveRequests.clear();
            _recalculateDaysFromRequests();
          });
        }
      }
    } catch (e) {
      debugPrint('İzin talepleri yüklenirken hata: $e');
    }
  }

  void _recalculateDaysFromRequests() {
    int yillik = 0;
    int ucretsiz = 0;
    for (final req in _leaveRequests) {
      if (req.leaveType == 'Yıllık İzin') {
        yillik += req.days;
      } else if (req.leaveType == 'Ücretsiz İzin') {
        ucretsiz += req.days;
      }
    }
    _ucretliGun = yillik.clamp(0, _maxUcretli);
    _ucretsizGun = ucretsiz.clamp(0, _maxUcretsiz);
    _notifyChanges();
  }

  Future<void> _saveLeaveRequests() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final encoded = jsonEncode(_leaveRequests.map((e) => e.toJson()).toList());
      await prefs.setString('saved_leave_requests', encoded);
    } catch (e) {
      debugPrint('İzin talepleri kaydedilirken hata: $e');
    }
  }

  Future<void> _loadUser() async {
    final u = await UserModel.load();
    if (mounted && u != null) {
      setState(() => _currentUser = u);
    }
  }

  void _notifyChanges() {
    widget.onIzinChanged(_ucretliGun, _ucretsizGun);
  }

  /// Yeni İzin Talebi Oluşturma (1 Gün Düşme Hatası Düzeltildi)
  Future<void> _createLeaveRequest({DateTime? preselectedDate}) async {
    final result = await showModalBottomSheet<_DatePickerResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AdvancedDatePickerSheet(initialDate: preselectedDate),
    );

    if (result == null || !mounted) return;

    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    final String startStr = formatter.format(result.start);
    final String endStr = formatter.format(result.end);
    final int days = result.days;
    final String type = result.leaveType;

    // Kalan hak simülasyonu
    final bool isYillik = type == 'Yıllık İzin';
    final bool isUcretsiz = type == 'Ücretsiz İzin';
    final int simulatedRemaining = isYillik
        ? (_maxUcretli - (_ucretliGun + days)).clamp(0, _maxUcretli)
        : (_maxUcretli - _ucretliGun);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF161922),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: Color(0xFF2E364A), width: 1.2),
        ),
        titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
        actionsPadding: const EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.15),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: const Icon(Icons.event_available_rounded, color: Color(0xFF10B981), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İzin Talep Onayı',
                    style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 17, color: Colors.white),
                  ),
                  Text(
                    type,
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF10B981)),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF252C3D)),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Tarih Aralığı:', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                      Text(
                        days == 1 ? startStr : '$startStr – $endStr',
                        style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ],
                  ),
                  const Divider(color: Color(0xFF1F2637), height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Talep Edilen Süre:', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$days Gün',
                          style: GoogleFonts.inter(color: const Color(0xFF10B981), fontWeight: FontWeight.w900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                  if (isYillik) ...[
                    const Divider(color: Color(0xFF1F2637), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Kalan Yıllık İzniniz:', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                        Text(
                          '$simulatedRemaining Gün',
                          style: GoogleFonts.inter(color: const Color(0xFFFBBF24), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                  if (isUcretsiz) ...[
                    const Divider(color: Color(0xFF1F2637), height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Tahmini Maaş Kesintisi:', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 12)),
                        Text(
                          '₺${(days * widget.unpaidLeaveRate).toStringAsFixed(0)}',
                          style: GoogleFonts.inter(color: const Color(0xFFF43F5E), fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isYillik
                  ? '⚠️ Bu talep onaylandığında yıllık izin bakiyenizden tam $days GÜN düşülecektir.'
                  : (isUcretsiz
                      ? '⚠️ Ücretsiz izin aldığınız gün kadar maaşınızdan kesinti uygulanır.'
                      : '✅ Bu izin türü yasal mazeret iznidir, yıllık izninizden DÜŞÜLMEZ.'),
              style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8), height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Vazgeç', style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE50914),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            child: Text('Talebi Onayla', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() {
        final newReq = LeaveRequest(
          id: 'REQ-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
          title: '$type Talebi',
          leaveType: type,
          startDate: result.start,
          endDate: result.end,
          days: days,
          status: 'Onaylandı', // Kişi işaretlediğinde direkt onaylı görünsün
          notes: result.note,
          createdAt: DateTime.now(),
        );
        _leaveRequests.insert(0, newReq);
        _recalculateDaysFromRequests();
      });
      _saveLeaveRequests();

      if (!mounted) return;
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '$days günlük $type onaylandı ve takviminize işlendi.',
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
  }

  /// İzin Talebini İptal Etme
  void _cancelRequest(LeaveRequest request) {
    setState(() {
      _leaveRequests.remove(request);
      _recalculateDaysFromRequests();
    });
    _saveLeaveRequests();
    HapticFeedback.mediumImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${request.days} günlük ${request.leaveType} iptal edildi. İzin bakiyeniz iade edildi.'),
        backgroundColor: const Color(0xFFEF4444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  /// Resmi İSDEMİR İzin Formu PDF Üretici
  Future<void> _exportPdfForm(LeaveRequest req) async {
    setState(() => _isGeneratingPdf = true);
    HapticFeedback.mediumImpact();

    try {
      final pdf = pw.Document();
      final theme = await PdfFontHelper.getTheme();
      final DateFormat df = DateFormat('dd.MM.yyyy');

      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          margin: const pw.EdgeInsets.all(36),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey700, width: 1.5),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            PdfFontHelper.sanitize('İSKENDERUN DEMİR VE ÇELİK A.Ş.'),
                            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red900),
                          ),
                          pw.Text(
                            PdfFontHelper.sanitize('PERSONEL İZİN TALEP VE BİLDİRİM FORMU'),
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
                          ),
                        ],
                      ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.end,
                        children: [
                          pw.Text('Form No: ${req.id}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                          pw.Text('Tarih: ${df.format(req.createdAt)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(height: 18),

                // Bölüm 1: Personel Bilgileri
                pw.Text(PdfFontHelper.sanitize('1. PERSONEL BİLGİLERİ'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Adı Soyadı', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfFontHelper.sanitize(_currentUser?.fullName ?? 'İsimsiz Personel'), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Sicil No / ID', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfFontHelper.sanitize(_currentUser?.id ?? '31420'), style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Görevi / Unvanı', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfFontHelper.sanitize(_currentUser?.jobTitle ?? 'Saha Personeli'), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Birim / Tesis', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('İSDEMİR İşletme', style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // Bölüm 2: İzin Bilgileri
                pw.Text(PdfFontHelper.sanitize('2. İZİN VE TALEP DETAYLARI'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('İzin Türü', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfFontHelper.sanitize(req.leaveType), style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10, color: PdfColors.blue800))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Toplam Süre', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('${req.days} Gün', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Başlangıç Tarihi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(df.format(req.startDate), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Bitiş Tarihi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(df.format(req.endDate), style: const pw.TextStyle(fontSize: 10))),
                      ],
                    ),
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('İşe Başlama Tarihi', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(df.format(req.endDate.add(const Duration(days: 1))), style: const pw.TextStyle(fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text('Onay Durumu', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(PdfFontHelper.sanitize(req.status), style: const pw.TextStyle(fontSize: 10, color: PdfColors.green800))),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 18),

                // Açıklama / Not
                if (req.notes != null && req.notes!.isNotEmpty) ...[
                  pw.Container(
                    width: double.infinity,
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: pw.BorderRadius.circular(6)),
                    child: pw.Text('Talep Açıklaması: ${PdfFontHelper.sanitize(req.notes)}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800)),
                  ),
                  pw.SizedBox(height: 24),
                ] else ...[
                  pw.SizedBox(height: 24),
                ],

                // İmzalar Tablosu
                pw.Text(PdfFontHelper.sanitize('3. ONAY VE İMZA PROTOKOLÜ'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Container(
                      width: 150,
                      height: 80,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('PERSONEL İMZASI', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Spacer(),
                          pw.Text(PdfFontHelper.sanitize(_currentUser?.fullName ?? 'İmza'), style: const pw.TextStyle(fontSize: 8)),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 150,
                      height: 80,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('VARDİYA AMİRİ ONAYI', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Spacer(),
                          pw.Text(PdfFontHelper.sanitize('Kaşe / İmza'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                    pw.Container(
                      width: 150,
                      height: 80,
                      decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400)),
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.center,
                        children: [
                          pw.Text('İNSAN KAYNAKLARI ONAYI', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                          pw.Spacer(),
                          pw.Text(PdfFontHelper.sanitize('Sistem Kaydı Yapıldı'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                        ],
                      ),
                    ),
                  ],
                ),
                pw.Spacer(),

                // Dipnot
                pw.Center(
                  child: pw.Text(
                    PdfFontHelper.sanitize('Bu belge İSDEMİR OS Dijital İzin Yönetim Sistemi tarafından üretilmiştir.'),
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ),
              ],
            );
          },
        ),
      );

      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/Isdemir_Izin_Formu_${req.days}Gun.pdf';
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      // ignore: deprecated_member_use
      await Share.shareXFiles(
        [XFile(filePath)],
        text: 'İSDEMİR İzin Formu - ${req.days} Gün (${req.leaveType})',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulurken hata: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final double totalDeduction = _ucretsizGun * widget.unpaidLeaveRate;
    final int remainingYillik = (_maxUcretli - _ucretliGun).clamp(0, _maxUcretli);
    final double yillikPercent = remainingYillik / _maxUcretli;
    final double ucretsizPercent = (_ucretsizGun / _maxUcretsiz).clamp(0.0, 1.0);

    final now = DateTime.now();
    final trMonths = ['', 'OCAK', 'ŞUBAT', 'MART', 'NİSAN', 'MAYIS', 'HAZİRAN', 'TEMMUZ', 'AĞUSTOS', 'EYLÜL', 'EKİM', 'KASIM', 'ARALIK'];
    final trDays = ['', 'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'];

    return Scaffold(
      backgroundColor: const Color(0xFF0F0F13),
      body: Stack(
        children: [
          // Arka plan ortam ışıması
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE50914).withValues(alpha: 0.12),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── 1. DİNAMİK CANLI TAKVİM BAŞLIĞI ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1D26),
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFF2B3244)),
                          ),
                          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'İzin Yönetimi',
                              style: GoogleFonts.inter(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: -0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Yıllık ve mazeret haklarınız',
                              style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
                            ),
                          ],
                        ),
                      ),

                      // Dinamik Canlı Takvim Bloğu (Hardcoded July 17 yerine)
                      Container(
                        width: 68,
                        decoration: BoxDecoration(
                          color: const Color(0xFF161922),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1.2),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFE50914).withValues(alpha: 0.15),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 3),
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Color(0xFF8B0000), Color(0xFFE50914)],
                                ),
                                borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                              ),
                              child: Text(
                                trMonths[now.month],
                                textAlign: TextAlign.center,
                                style: GoogleFonts.orbitron(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${now.day}',
                              style: GoogleFonts.orbitron(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, height: 1.1),
                            ),
                            Text(
                              trDays[now.weekday],
                              style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w600, color: const Color(0xFFA1A1AA)),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 2. ANA İÇERİK LİSTESİ ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // ── ÇİFT HALKALI GÖSTERGE KARTLARI ──
                        Row(
                          children: [
                            // 🟢 Yıllık İzin Halkası
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141722),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.08),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 74,
                                          height: 74,
                                          child: CircularProgressIndicator(
                                            value: yillikPercent,
                                            strokeWidth: 7,
                                            backgroundColor: const Color(0xFF1E2638),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$remainingYillik',
                                              style: GoogleFonts.orbitron(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.white,
                                              ),
                                            ),
                                            Text(
                                              '/ $_maxUcretli Gün',
                                              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Yıllık İzin Hakkı',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(
                                      'Maaş Kesintisiz',
                                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF10B981), fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),

                            // 🔴 Ücretsiz İzin & Kesinti Halkası
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF141722),
                                  borderRadius: BorderRadius.circular(22),
                                  border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.3)),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFFEF4444).withValues(alpha: 0.08),
                                      blurRadius: 14,
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        SizedBox(
                                          width: 74,
                                          height: 74,
                                          child: CircularProgressIndicator(
                                            value: ucretsizPercent,
                                            strokeWidth: 7,
                                            backgroundColor: const Color(0xFF1E2638),
                                            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFEF4444)),
                                            strokeCap: StrokeCap.round,
                                          ),
                                        ),
                                        Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '$_ucretsizGun',
                                              style: GoogleFonts.orbitron(
                                                fontSize: 20,
                                                fontWeight: FontWeight.w900,
                                                color: const Color(0xFFEF4444),
                                              ),
                                            ),
                                            Text(
                                              '/ 30 Gün',
                                              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFF94A3B8)),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Ücretsiz İzin',
                                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                                    ),
                                    Text(
                                      totalDeduction > 0 ? '- ₺${totalDeduction.toStringAsFixed(0)} Kesinti' : 'Kesinti Yok',
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: totalDeduction > 0 ? const Color(0xFFEF4444) : const Color(0xFF94A3B8),
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ── 💡 3. AKILLI KÖPRÜ İZİN ASİSTANI KARTI ──
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1A1A26), Color(0xFF131520)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.1),
                                blurRadius: 16,
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(6),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFBBF24), size: 16),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'AKILLI KÖPRÜ İZİN FIRSATI',
                                    style: GoogleFonts.orbitron(
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFFFBBF24),
                                      letterSpacing: 0.8,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '29 Ekim Cumhuriyet Bayramı öncesinde 28 Ekim için sadece 1 GÜN yıllık izin alarak hafta sonuyla birlikte kesintisiz 4.5 GÜN tatil yapabilirsiniz!',
                                style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFCBD5E1), height: 1.45),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    side: const BorderSide(color: Color(0xFFF59E0B), width: 1),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                                  ),
                                  onPressed: () => _createLeaveRequest(preselectedDate: DateTime(2026, 10, 28)),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.beach_access_rounded, size: 16, color: Color(0xFFFBBF24)),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Bu Fırsatı Planla (28 Ekim - 1 Gün)',
                                        style: GoogleFonts.inter(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFFFBBF24),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // ── 4. YENİ İZİN TALEBİ BUTONU ──
                        SizedBox(
                          width: double.infinity,
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () => _createLeaveRequest(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE50914),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 6,
                              shadowColor: const Color(0xFFE50914).withValues(alpha: 0.4),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle),
                                  child: const Icon(Icons.add_rounded, color: Colors.white, size: 18),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  'Yeni İzin Talebi Oluştur',
                                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 26),

                        // ── 5. AKTİF İZİNLER LİSTESİ ──
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Aktif İzinleriniz',
                              style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E2330),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '${_leaveRequests.length} İzin',
                                style: GoogleFonts.orbitron(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        if (_leaveRequests.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: const Color(0xFF141722),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF22293A)),
                            ),
                            child: Column(
                              children: [
                                const Icon(Icons.event_note_rounded, size: 42, color: Color(0xFF475569)),
                                const SizedBox(height: 10),
                                Text(
                                  'Henüz bir izin talebiniz bulunmuyor',
                                  style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _leaveRequests.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 14),
                            itemBuilder: (ctx, i) => _buildActiveLeaveCard(_leaveRequests[i]),
                          ),

                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isGeneratingPdf)
            Container(
              color: Colors.black.withValues(alpha: 0.7),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFE50914)),
                    SizedBox(height: 16),
                    Text(
                      'İSDEMİR Resmi İzin Formu Hazırlanıyor...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Doğrudan Onaylı Aktif İzin Kartı (Amir ve İK Onay Aşamaları Kaldırıldı)
  Widget _buildActiveLeaveCard(LeaveRequest req) {
    final DateFormat formatter = DateFormat('dd.MM.yyyy');

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.4),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.08),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Başlık Şeridi
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                  ),
                  child: Icon(
                    req.leaveType == 'Yıllık İzin'
                        ? Icons.beach_access_rounded
                        : (req.leaveType == 'Ücretsiz İzin' ? Icons.airplanemode_active_rounded : Icons.badge_rounded),
                    color: const Color(0xFF10B981),
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.title,
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        req.days == 1
                            ? formatter.format(req.startDate)
                            : '${formatter.format(req.startDate)} – ${formatter.format(req.endDate)}',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2638),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    '${req.days} Gün',
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                  ),
                ),
              ],
            ),
          ),

          // ── Doğrudan Onaylı Durum Şeridi (Direkt Aktif) ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                    child: const Icon(Icons.check_rounded, size: 12, color: Colors.black),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ONAYLANDI & AKTİF İZİN',
                    style: GoogleFonts.orbitron(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF10B981),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Takvime İşlendi',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (req.notes != null && req.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1017),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'Not: ${req.notes}',
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontStyle: FontStyle.italic),
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),

          // Alt Aksiyon Butonları (PDF Formu + İptal Et)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF10131B),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(22)),
            ),
            child: Row(
              children: [
                // PDF Dilekçe Butonu
                InkWell(
                  onTap: () => _exportPdfForm(req),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.picture_as_pdf_rounded, size: 14, color: Color(0xFF38BDF8)),
                        const SizedBox(width: 6),
                        Text(
                          'Resmi Form (PDF)',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),

                // İptal Et Butonu
                TextButton(
                  onPressed: () => _cancelRequest(req),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFFEF4444),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  ),
                  child: Text(
                    'İptal Et',
                    style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// ── 📅 GELİŞMİŞ VE GÜN HESAPLAMASI DÜZELTİLMİŞ TARİH SEÇİCİ ──
// ─────────────────────────────────────────────────────────────
class _DatePickerResult {
  final DateTime start;
  final DateTime end;
  final int days;
  final String leaveType;
  final String? note;

  _DatePickerResult({
    required this.start,
    required this.end,
    required this.days,
    required this.leaveType,
    this.note,
  });
}

class _AdvancedDatePickerSheet extends StatefulWidget {
  final DateTime? initialDate;

  const _AdvancedDatePickerSheet({this.initialDate});

  @override
  State<_AdvancedDatePickerSheet> createState() => _AdvancedDatePickerSheetState();
}

class _AdvancedDatePickerSheetState extends State<_AdvancedDatePickerSheet> {
  static const Color _accent = Color(0xFFE50914);
  static const List<String> _aylar = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const List<String> _gunler = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  int _mode = 0; // 0: Tek Gün İzin, 1: Tarih Aralığı
  String _selectedType = 'Yıllık İzin';
  late DateTime _displayMonth;
  DateTime? _startDate;
  DateTime? _endDate;
  final TextEditingController _noteController = TextEditingController();

  final List<String> _leaveTypes = [
    'Yıllık İzin',
    'Mazeret İzni',
    'Evlilik İzni',
    'Doğum İzni',
    'Rapor / İstirahat',
    'Ücretsiz İzin',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialDate ?? DateTime.now();
    _displayMonth = DateTime(init.year, init.month);
    if (widget.initialDate != null) {
      _startDate = DateTime(init.year, init.month, init.day);
      _endDate = _startDate;
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _onDayTap(DateTime day) {
    final cleanDay = DateTime(day.year, day.month, day.day);

    setState(() {
      if (_mode == 0) {
        // ── TEK GÜN MODU: 1 DOKUNUŞ = TAM 1 GÜN ──
        _startDate = cleanDay;
        _endDate = cleanDay;
      } else {
        // ── ARALIK MODU ──
        if (_startDate == null || (_startDate != null && _endDate != null && _startDate != _endDate)) {
          _startDate = cleanDay;
          _endDate = null;
        } else {
          if (cleanDay.isBefore(_startDate!)) {
            _endDate = _startDate;
            _startDate = cleanDay;
          } else {
            _endDate = cleanDay;
          }
        }
      }
    });
  }

  int get _calculatedDays {
    if (_startDate == null) return 0;
    if (_endDate == null || _startDate == _endDate) return 1;
    return _endDate!.difference(_startDate!).inDays + 1;
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  bool _isStart(DateTime day) => _startDate != null && _isSameDay(day, _startDate!);
  bool _isEnd(DateTime day) => _endDate != null && _isSameDay(day, _endDate!);
  bool _isSameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  List<Widget> _buildDays() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    int startOffset = firstDay.weekday - 1;
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);

    List<Widget> cells = [];
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_displayMonth.year, _displayMonth.month, d);
      final isStart = _isStart(day);
      final isEnd = _isEnd(day);
      final inRange = _isInRange(day);
      final isSelected = isStart || isEnd;
      final isToday = _isSameDay(day, DateTime.now());

      cells.add(
        GestureDetector(
          onTap: () => _onDayTap(day),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 2.5),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent
                  : inRange
                      ? _accent.withValues(alpha: 0.15)
                      : Colors.transparent,
              borderRadius: isStart && _endDate != null && _endDate != _startDate
                  ? const BorderRadius.horizontal(left: Radius.circular(20))
                  : isEnd && _startDate != null && _endDate != _startDate
                      ? const BorderRadius.horizontal(right: Radius.circular(20))
                      : BorderRadius.circular(20),
            ),
            child: Center(
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? _accent : Colors.transparent,
                  border: isToday && !isSelected ? Border.all(color: _accent, width: 1.5) : null,
                ),
                child: Center(
                  child: Text(
                    '$d',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }
    return cells;
  }

  @override
  Widget build(BuildContext context) {
    final bool canSave = _startDate != null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: Color(0xFF141722),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0xFF2C3549), width: 1.5)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4.5,
            decoration: BoxDecoration(color: const Color(0xFF3B4354), borderRadius: BorderRadius.circular(3)),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('İzin Talebi Belirleyin', style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                    Text('İzin türü ve gün sayısını seçin', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── İZİN TÜRLERİ KAYDIRILABİLİR ÇİPLER ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _leaveTypes.map((t) {
                final isSel = _selectedType == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(t),
                    selected: isSel,
                    onSelected: (_) => setState(() => _selectedType = t),
                    selectedColor: _accent,
                    backgroundColor: const Color(0xFF1C2232),
                    labelStyle: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: isSel ? FontWeight.bold : FontWeight.w500,
                      color: isSel ? Colors.white : const Color(0xFF94A3B8),
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // ── SEÇİM MODU: TEK GÜN vs TARİH ARALIĞI ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: const Color(0xFF0F121A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262E40)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _mode = 0;
                          if (_startDate != null) _endDate = _startDate;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == 0 ? _accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '📌 Tek Gün İzin',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: _mode == 0 ? FontWeight.bold : FontWeight.w600,
                              color: _mode == 0 ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _mode = 1),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        decoration: BoxDecoration(
                          color: _mode == 1 ? _accent : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            '📅 Tarih Aralığı',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: _mode == 1 ? FontWeight.bold : FontWeight.w600,
                              color: _mode == 1 ? Colors.white : const Color(0xFF94A3B8),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── SEÇİLEN TARİH VE GÜN SAYAÇ KUTUSU ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF10131C),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF262E40)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Seçilen Tarih:', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        _startDate == null
                            ? 'Henüz gün seçilmedi'
                            : (_mode == 0 || _endDate == null || _startDate == _endDate
                                ? '${_startDate!.day} ${_aylar[_startDate!.month]} ${_startDate!.year}'
                                : '${_startDate!.day} ${_aylar[_startDate!.month]} – ${_endDate!.day} ${_aylar[_endDate!.month]}'),
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      '$_calculatedDays GÜN',
                      style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // ── TAKVİM GÖRÜNÜMÜ ──
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
              decoration: BoxDecoration(
                color: const Color(0xFF10131C),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF262E40)),
              ),
              child: Column(
                children: [
                  // Ay Değiştirici
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.chevron_left_rounded, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
                          });
                        },
                      ),
                      Text(
                        '${_aylar[_displayMonth.month]} ${_displayMonth.year}',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      IconButton(
                        icon: const Icon(Icons.chevron_right_rounded, color: Colors.white),
                        onPressed: () {
                          setState(() {
                            _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),

                  // Gün Başlıkları
                  Row(
                    children: _gunler.map((g) => Expanded(
                      child: Center(
                        child: Text(g, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF64748B))),
                      ),
                    )).toList(),
                  ),
                  const SizedBox(height: 6),

                  // Gün Izgarası
                  Expanded(
                    child: GridView.count(
                      crossAxisCount: 7,
                      physics: const NeverScrollableScrollPhysics(),
                      children: _buildDays(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── ONAYLA VE DEVAM ET BUTONU ──
          Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).padding.bottom + 12),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: canSave
                    ? () {
                        final end = _endDate ?? _startDate!;
                        Navigator.pop(
                          context,
                          _DatePickerResult(
                            start: _startDate!,
                            end: end,
                            days: _calculatedDays,
                            leaveType: _selectedType,
                            note: _noteController.text.trim().isNotEmpty ? _noteController.text.trim() : null,
                          ),
                        );
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave ? _accent : Colors.white12,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  canSave ? '$_calculatedDays Gün İzin Talep Et' : 'Lütfen Takvimden Gün Seçin',
                  style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
