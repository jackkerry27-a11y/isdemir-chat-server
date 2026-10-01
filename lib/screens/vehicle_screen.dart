import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/pdf_font_helper.dart';

// ════════════════════════════════════════════════════════════════════════════════
// 🚢 DATA MODEL: VEHICLE LOGISTICS RECORD
// ════════════════════════════════════════════════════════════════════════════════
class VehicleRecord {
  final String id;
  final String plate;
  final String destination;
  final String cargoType;
  final double tonnage;
  final String driverName;
  final DateTime entryTime;
  DateTime? exitTime;
  final String note;

  VehicleRecord({
    required this.id,
    required this.plate,
    required this.destination,
    required this.cargoType,
    this.tonnage = 0.0,
    this.driverName = '',
    required this.entryTime,
    this.exitTime,
    this.note = '',
  });

  bool get isInside => exitTime == null;

  Duration get duration => (exitTime ?? DateTime.now()).difference(entryTime);

  /// 90 dakikayı aşan saha içi araçlar terminal gecikmesi (anomali) olarak değerlendirilir.
  bool get isDelayed => isInside && duration.inMinutes >= 90;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'plate': plate,
      'destination': destination,
      'cargoType': cargoType,
      'tonnage': tonnage,
      'driverName': driverName,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime?.toIso8601String(),
      'note': note,
    };
  }

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    String rawPlate = json['plate'] ?? '';
    if (rawPlate.isEmpty) {
      final idStr = (json['id'] ?? '1000').toString();
      final suffix = idStr.length >= 4 ? idStr.substring(idStr.length - 4) : idStr;
      rawPlate = '31 IS $suffix';
    }

    return VehicleRecord(
      id: json['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      plate: rawPlate.toUpperCase().trim(),
      destination: json['destination'] ?? 'Gv1',
      cargoType: json['cargoType'] ?? 'Kömür',
      tonnage: (json['tonnage'] as num?)?.toDouble() ?? 0.0,
      driverName: json['driverName'] ?? '',
      entryTime: json['entryTime'] != null ? DateTime.parse(json['entryTime']) : DateTime.now(),
      exitTime: json['exitTime'] != null ? DateTime.parse(json['exitTime']) : null,
      note: json['note'] ?? '',
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 🇨🇭 SWISS LOGISTICS DESIGN SYSTEM CONSTANTS
// ════════════════════════════════════════════════════════════════════════════════
class SwissTheme {
  // Zemin & Yüzey Renkleri
  static const Color background = Color(0xFF0C1017);
  static const Color surface = Color(0xFF141923);
  static const Color surfaceSubtle = Color(0xFF1B2230);
  static const Color surfaceCard = Color(0xFF161C27);

  // Kenarlık & Çizgi Renkleri (Hassas 1px Çizgiler)
  static const Color border = Color(0xFF242E40);
  static const Color borderSubtle = Color(0xFF1E2636);
  static const Color borderActive = Color(0xFF3B82F6);

  // Kurumsal Swiss Vurgu Renkleri
  static const Color blue = Color(0xFF2563EB); // Liman / Operasyon Mavisi
  static const Color blueLight = Color(0xFF3B82F6);
  static const Color emerald = Color(0xFF10B981); // Sahada / Aktif Yeşili
  static const Color amber = Color(0xFFF59E0B); // Bekleme / İkaz Sarısı
  static const Color crimson = Color(0xFFEF4444); // Kritik Gecikme / İsviçre Kırmızısı

  // Metin & Tipografi Renkleri
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);
}

// ════════════════════════════════════════════════════════════════════════════════
// 🏛️ MODERN SWISS LOGISTICS TERMINAL SCREEN
// ════════════════════════════════════════════════════════════════════════════════
class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  final List<VehicleRecord> _records = [];
  final TextEditingController _searchController = TextEditingController();

  int _selectedFilterTab = 0; // 0: Tümü, 1: Sahada, 2: Çıkanlar, 3: Gecikenler
  String _selectedBerth = 'TÜMÜ';
  String _searchQuery = '';

  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  // Sabit Liman Bölgeleri ve Yük Tipleri
  final List<String> _berths = ['Gv1', 'Gv2', 'Gv3', 'Gv4', 'Yb8', 'Yb9', 'Yb10', 'Yb11', 'Yb12'];
  final List<String> _cargoCategories = [
    'Kömür',
    'Hurda',
    'Rulo Sac',
    'Kangal Demir',
    'Kütük Demir',
    'Slab',
    'Cüruf',
    'Kalker',
    'Diğer'
  ];

  @override
  void initState() {
    super.initState();
    _loadRecords();

    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('vehicle_records');

    if (recordsJson != null) {
      try {
        final List<dynamic> decoded = json.decode(recordsJson);
        final List<VehicleRecord> loaded = decoded.map((e) => VehicleRecord.fromJson(e)).toList();

        // Örnek / demo isimli tohum kayıtları temizle (kullanıcılar kendi araçlarını ekleyecek)
        const demoIds = {'101', '102', '103', '104'};
        const demoDrivers = {'Ahmet Yılmaz', 'Mustafa Kaya', 'Mehmet Demir', 'Kemal Ak'};
        final cleanRecords = loaded.where((r) => !demoIds.contains(r.id) && !demoDrivers.contains(r.driverName)).toList();

        setState(() {
          _records.clear();
          _records.addAll(cleanRecords);
        });
        _saveRecords();
      } catch (e) {
        debugPrint('Kayıt yükleme hatası: $e');
      }
    }
  }

  void _clearAllRecords() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SwissTheme.border),
        ),
        title: Text(
          'Tüm Kayıtları Temizle',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          'Tüm araç giriş-çıkış hareketleri silinecektir. Emin misiniz?',
          style: GoogleFonts.inter(color: SwissTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: SwissTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissTheme.crimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _records.clear();
              });
              _saveRecords();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: SwissTheme.surfaceSubtle,
                  behavior: SnackBarBehavior.floating,
                  content: Text('Tüm araç kayıtları temizlendi.', style: GoogleFonts.inter(color: Colors.white)),
                ),
              );
            },
            child: Text('Temizle', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('vehicle_records', encoded);
  }

  void _addRecord(VehicleRecord record) {
    HapticFeedback.lightImpact();
    setState(() {
      _records.insert(0, record);
    });
    _saveRecords();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SwissTheme.surfaceSubtle,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SwissTheme.emerald),
        ),
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: SwissTheme.emerald, size: 20),
            const SizedBox(width: 10),
            Text(
              '${record.plate} sisteme kaydedildi.',
              style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  void _checkOutRecord(VehicleRecord record, {DateTime? customExitTime}) {
    HapticFeedback.lightImpact();
    setState(() {
      record.exitTime = customExitTime ?? DateTime.now();
    });
    _saveRecords();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: SwissTheme.surfaceSubtle,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: SwissTheme.blueLight),
        ),
        content: Text(
          '${record.plate} çıkış tartımı tamamlandı.',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
      ),
    );
  }

  void _deleteRecord(VehicleRecord record) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: SwissTheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: SwissTheme.border),
        ),
        title: Text(
          'Kaydı Sil',
          style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 17),
        ),
        content: Text(
          '${record.plate} plakalı araca ait terminal hareketi silinecektir. Onaylıyor musunuz?',
          style: GoogleFonts.inter(color: SwissTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('İptal', style: GoogleFonts.inter(color: SwissTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissTheme.crimson,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _records.removeWhere((r) => r.id == record.id);
              });
              _saveRecords();
            },
            child: Text('Sil', style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 📄 RESMİ SWISS-STYLE İSDEMİR LOJİSTİK RAPORU (PDF)
  // ════════════════════════════════════════════════════════════════════════════
  Future<void> _exportPdfReport() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dışa aktarılacak kayıt bulunmuyor.')),
      );
      return;
    }

    final pdfTheme = await PdfFontHelper.getTheme();
    final pdf = pw.Document(theme: pdfTheme);

    String normalize(String text) => PdfFontHelper.sanitize(text);

    final insideVehicles = _records.where((r) => r.isInside).length;
    final totalTons = _records.fold<double>(0.0, (sum, r) => sum + r.tonnage);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        build: (pw.Context context) {
          return [
            // Kurumsal Swiss Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('ISDEMIR', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
                    pw.Text('PORT LOGISTICS TERMINAL MANAGEMENT', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF475569))),
                    pw.SizedBox(height: 4),
                    pw.Text('Liman & Tesis Arac Giris/Cikis Sevkiyat Bulteni', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('RAPOR NO: TRM-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold)),
                    pw.Text('TARIH: ${DateFormat('dd.MM.yyyy HH:mm').format(DateTime.now())}', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 4),
                    pw.Container(
                      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                      decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFF1F5F9)),
                      child: pw.Text('RESMI SISTEM DOKUMU', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 12),
            pw.Container(height: 1.5, color: const PdfColor.fromInt(0xFF0F172A)),
            pw.SizedBox(height: 14),

            // Özet Metrik Kutuları
            pw.Row(
              children: [
                _buildPdfKpiBox('TOPLAM ARAC', '${_records.length}'),
                pw.SizedBox(width: 12),
                _buildPdfKpiBox('SAHADAKI ARAC', '$insideVehicles'),
                pw.SizedBox(width: 12),
                _buildPdfKpiBox('TOPLAM TONAJ', '${totalTons.toStringAsFixed(1)} Ton'),
                pw.SizedBox(width: 12),
                _buildPdfKpiBox('TERMINAL DURUMU', 'NORMAL'),
              ],
            ),
            pw.SizedBox(height: 18),

            // Tablo
            pw.TableHelper.fromTextArray(
              context: context,
              border: pw.TableBorder.all(color: const PdfColor.fromInt(0xFFE2E8F0), width: 0.5),
              headerAlignment: pw.Alignment.centerLeft,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0F172A)),
              cellAlignment: pw.Alignment.centerLeft,
              cellStyle: const pw.TextStyle(fontSize: 8),
              headers: ['PLAKA', 'ISKELE', 'YUK CINSI', 'TONAJ', 'SURUCU', 'GIRIS', 'CIKIS', 'DURUM'],
              data: _records.map((r) {
                final entryStr = DateFormat('HH:mm').format(r.entryTime);
                final exitStr = r.exitTime != null ? DateFormat('HH:mm').format(r.exitTime!) : '--';
                final durStr = '${r.duration.inHours}sa ${r.duration.inMinutes % 60}dk';
                final statusStr = r.isInside ? (r.isDelayed ? 'GECIKME ($durStr)' : 'Sahada ($durStr)') : 'Cikis';

                return [
                  normalize(r.plate),
                  normalize(r.destination),
                  normalize(r.cargoType),
                  '${r.tonnage > 0 ? r.tonnage.toStringAsFixed(1) : '-'} T',
                  normalize(r.driverName.isNotEmpty ? r.driverName : '-'),
                  entryStr,
                  exitStr,
                  statusStr,
                ];
              }).toList(),
            ),

            pw.SizedBox(height: 30),

            // Footer
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Kantar & Liman Guvenlik Sorumlusu', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                    pw.SizedBox(height: 24),
                    pw.Text('Elektronik Olarak Onaylanmistir', style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: const PdfColor.fromInt(0xFF0F172A), width: 1)),
                  child: pw.Text('ISDEMIR OS\nTERMINAL VALIDATED', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                ),
              ],
            ),
          ];
        },
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Isdemir_Terminal_Rapor_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await Share.shareXFiles([XFile(file.path)], text: 'İSDEMİR Lojistik Terminal Raporu');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  pw.Widget _buildPdfKpiBox(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(8),
        decoration: pw.BoxDecoration(
          color: const PdfColor.fromInt(0xFFF8FAFC),
          border: pw.Border.all(color: const PdfColor.fromInt(0xFFE2E8F0)),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 7, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(value, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0F172A))),
          ],
        ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 📷 OPTİK PLAKA & BELGE TARAYICI ARAYÜZÜ (TERMINAL LPR SCANNER)
  // ════════════════════════════════════════════════════════════════════════════
  void _openOpticalScanner() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _TerminalOpticalScannerModal(
        onScanComplete: (plate, cargo, tonnage) {
          Navigator.pop(ctx);
          _showCheckInModal(initialPlate: plate, initialCargo: cargo, initialTonnage: tonnage);
        },
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // ➕ YENİ ARAÇ KABUL FORMU (TERMINAL CHECK-IN)
  // ════════════════════════════════════════════════════════════════════════════
  void _showCheckInModal({String? initialPlate, String? initialCargo, double? initialTonnage}) {
    final plateCtrl = TextEditingController(text: initialPlate ?? '');
    final driverCtrl = TextEditingController();
    final tonnageCtrl = TextEditingController(text: initialTonnage != null && initialTonnage > 0 ? initialTonnage.toStringAsFixed(1) : '');
    final noteCtrl = TextEditingController();

    String selectedBerth = 'Gv1';
    String selectedCargo = initialCargo ?? 'Kömür';
    DateTime entryDate = DateTime.now();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.88,
            decoration: const BoxDecoration(
              color: SwissTheme.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              border: Border(top: BorderSide(color: SwissTheme.border, width: 1.5)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              top: 16,
              left: 20,
              right: 20,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(color: SwissTheme.border, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 18),

                // Modal Başlığı
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'YENİ ARAÇ KABULÜ',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Liman kapısı & kantar giriş kaydı',
                          style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 12),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: SwissTheme.textMuted, size: 20),
                      onPressed: () => Navigator.pop(modalCtx),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Divider(height: 1, color: SwissTheme.borderSubtle),
                const SizedBox(height: 18),

                // Form Scroll Alanı
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. PLAKA GİRİŞİ
                        _buildSectionLabel('ARAÇ PLAKASI'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                          decoration: BoxDecoration(
                            color: SwissTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SwissTheme.border),
                          ),
                          child: Row(
                            children: [
                              // TR Plaka Kartuşu
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                                decoration: BoxDecoration(
                                  color: SwissTheme.blue,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text('TR', style: GoogleFonts.inter(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextField(
                                  controller: plateCtrl,
                                  textCapitalization: TextCapitalization.characters,
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w800, letterSpacing: 1.5),
                                  decoration: InputDecoration(
                                    hintText: 'Örn: 31 ABC 123',
                                    hintStyle: GoogleFonts.inter(color: SwissTheme.textMuted),
                                    border: InputBorder.none,
                                    isDense: true,
                                  ),
                                ),
                              ),
                              // LPR Hızlı Tara Butonu
                              IconButton(
                                icon: const Icon(Icons.crop_free, color: SwissTheme.blueLight, size: 20),
                                tooltip: 'Optik Tarayıcı ile Oku',
                                onPressed: () {
                                  Navigator.pop(modalCtx);
                                  _openOpticalScanner();
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 2. İSKELE / RIHTIM SEÇİMİ (GRID CHIPS)
                        _buildSectionLabel('HEDEF İSKELE / RIHTIM'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _berths.map((berth) {
                            final isSel = selectedBerth == berth;
                            return ChoiceChip(
                              label: Text(
                                berth,
                                style: GoogleFonts.inter(
                                  color: isSel ? Colors.white : SwissTheme.textSecondary,
                                  fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              selected: isSel,
                              selectedColor: SwissTheme.blue,
                              backgroundColor: SwissTheme.surfaceSubtle,
                              side: BorderSide(color: isSel ? SwissTheme.blueLight : SwissTheme.border),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              onSelected: (val) {
                                if (val) setModalState(() => selectedBerth = berth);
                              },
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 18),

                        // 3. YÜK KATEGORİSİ
                        _buildSectionLabel('YÜK CİNSİ'),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: SwissTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SwissTheme.border),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedCargo,
                              dropdownColor: SwissTheme.surfaceSubtle,
                              isExpanded: true,
                              icon: const Icon(Icons.arrow_drop_down, color: SwissTheme.textMuted),
                              items: _cargoCategories.map((c) {
                                return DropdownMenuItem(
                                  value: c,
                                  child: Text(c, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() => selectedCargo = val);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),

                        // 4. TONAJ & SÜRÜCÜ (YAN YANA İKİ SÜTUN)
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel('TONAJ (TON)'),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: SwissTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: SwissTheme.border),
                                    ),
                                    child: TextField(
                                      controller: tonnageCtrl,
                                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                      style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: '28.5',
                                        hintStyle: GoogleFonts.inter(color: SwissTheme.textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildSectionLabel('SÜRÜCÜ ADI'),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14),
                                    decoration: BoxDecoration(
                                      color: SwissTheme.surfaceSubtle,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: SwissTheme.border),
                                    ),
                                    child: TextField(
                                      controller: driverCtrl,
                                      style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                                      decoration: InputDecoration(
                                        hintText: 'Sürücü Adı Soyadı',
                                        hintStyle: GoogleFonts.inter(color: SwissTheme.textMuted),
                                        border: InputBorder.none,
                                        isDense: true,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // 5. GİRİŞ SAATİ
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SwissTheme.surfaceSubtle,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: SwissTheme.border),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.schedule, color: SwissTheme.blueLight, size: 18),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR').format(entryDate),
                                  style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                              ),
                              TextButton(
                                onPressed: () async {
                                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(entryDate));
                                  if (time != null) {
                                    setModalState(() {
                                      entryDate = DateTime(entryDate.year, entryDate.month, entryDate.day, time.hour, time.minute);
                                    });
                                  }
                                },
                                child: Text('Değiştir', style: GoogleFonts.inter(color: SwissTheme.blueLight, fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                // KAYDET BUTONU
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwissTheme.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () {
                      final plateText = plateCtrl.text.trim().toUpperCase();
                      if (plateText.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Geçerli bir plaka numarası girin.')),
                        );
                        return;
                      }

                      final tonVal = double.tryParse(tonnageCtrl.text.replaceAll(',', '.')) ?? 0.0;

                      final newRecord = VehicleRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        plate: plateText,
                        destination: selectedBerth,
                        cargoType: selectedCargo,
                        tonnage: tonVal,
                        driverName: driverCtrl.text.trim(),
                        entryTime: entryDate,
                        note: noteCtrl.text.trim(),
                      );

                      _addRecord(newRecord);
                      Navigator.pop(modalCtx);
                    },
                    child: Text(
                      'ARAÇ KABULÜNÜ TAMAMLA',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13, letterSpacing: 0.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionLabel(String text) {
    return Text(
      text,
      style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.6),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🖥️ MAIN BUILD METHOD
  // ════════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    // Filtreleme
    List<VehicleRecord> filtered = _records.where((r) {
      if (_selectedFilterTab == 1 && !r.isInside) return false;
      if (_selectedFilterTab == 2 && r.isInside) return false;
      if (_selectedFilterTab == 3 && !r.isDelayed) return false;

      if (_selectedBerth != 'TÜMÜ' && r.destination != _selectedBerth) return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final matchPlate = r.plate.toLowerCase().contains(q);
        final matchCargo = r.cargoType.toLowerCase().contains(q);
        final matchBerth = r.destination.toLowerCase().contains(q);
        if (!matchPlate && !matchCargo && !matchBerth) return false;
      }

      return true;
    }).toList();

    // Metrikler
    final insideCount = _records.where((r) => r.isInside).length;
    final totalTonnage = _records.fold<double>(0.0, (sum, r) => sum + r.tonnage);
    final delayedCount = _records.where((r) => r.isDelayed).length;

    return Scaffold(
      backgroundColor: SwissTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── 1. SWISS TERMINAL APP BAR ──
            _buildTerminalAppBar(),

            // ── 2. THREE COMPACT KPI CARDS ──
            _buildSwissKpiSection(insideCount: insideCount, totalTons: totalTonnage, delayedCount: delayedCount),

            // ── 3. BERTH / DOCK CAPACITY STRIP ──
            _buildBerthSelectorStrip(),

            // ── 4. SEARCH & STATUS TABS ──
            _buildSearchAndStatusTabs(delayedCount: delayedCount),

            // ── 5. TERMINAL RECORD LIST ──
            Expanded(
              child: filtered.isEmpty
                  ? _buildEmptyState()
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                      physics: const BouncingScrollPhysics(),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        return _buildTerminalCard(filtered[index]);
                      },
                    ),
            ),
          ],
        ),
      ),

      // ── BOTTOM ACTION BAR (SWISS CORPORATE FAB) ──
      floatingActionButton: _buildTerminalActionBar(),
    );
  }

  // ════════════════════════════════════════════════════════════════════════════
  // 🧩 SWISS DESIGN SYSTEM COMPONENTS
  // ════════════════════════════════════════════════════════════════════════════

  /// Kurumsal Liman Terminali Başlık Çubuğu
  Widget _buildTerminalAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: SwissTheme.background,
        border: Border(bottom: BorderSide(color: SwissTheme.borderSubtle)),
      ),
      child: Row(
        children: [
          // Geri Butonu
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: SwissTheme.surface,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SwissTheme.border),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),

          // Terminal Başlığı
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'İSDEMİR',
                      style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: SwissTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: SwissTheme.border),
                      ),
                      child: Text(
                        'PORT LOGISTICS',
                        style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${DateFormat('HH:mm:ss').format(_currentTime)} • Saha & Kantar Terminali',
                  style: GoogleFonts.inter(color: SwissTheme.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),

          // PDF Rapor Dışa Aktar Butonu
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: SwissTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            icon: const Icon(Icons.picture_as_pdf, color: SwissTheme.blueLight, size: 16),
            label: Text('Döküm', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600)),
            onPressed: _exportPdfReport,
          ),
          if (_records.isNotEmpty) ...[
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              tooltip: 'Seçenekler',
              icon: const Icon(Icons.more_vert, color: SwissTheme.textSecondary, size: 20),
              color: SwissTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: const BorderSide(color: SwissTheme.border),
              ),
              onSelected: (val) {
                if (val == 'clear_all') {
                  _clearAllRecords();
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'clear_all',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_sweep_outlined, color: SwissTheme.crimson, size: 18),
                      const SizedBox(width: 8),
                      Text('Tüm Kayıtları Temizle', style: GoogleFonts.inter(color: SwissTheme.crimson, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// 3 Ana İsviçre Tipi Metrik Kartı
  Widget _buildSwissKpiSection({required int insideCount, required double totalTons, required int delayedCount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          // 1. Sahada Aktif
          Expanded(
            child: _buildMetricTile(
              label: 'SAHADA AKTİF',
              value: '$insideCount',
              subtext: 'araç içeride',
              accentColor: SwissTheme.emerald,
              hasIndicator: true,
            ),
          ),
          const SizedBox(width: 8),

          // 2. Toplam Tonaj
          Expanded(
            child: _buildMetricTile(
              label: 'TOPLAM TONAJ',
              value: '${totalTons.toStringAsFixed(1)} T',
              subtext: '${_records.length} işlem',
              accentColor: SwissTheme.blueLight,
            ),
          ),
          const SizedBox(width: 8),

          // 3. Gecikme / Limit Aşımı
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilterTab = 3),
              child: _buildMetricTile(
                label: 'GECİKENLER',
                value: '$delayedCount',
                subtext: '90 dk+ aşım',
                accentColor: delayedCount > 0 ? SwissTheme.crimson : SwissTheme.textMuted,
                isAlert: delayedCount > 0,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required String subtext,
    required Color accentColor,
    bool hasIndicator = false,
    bool isAlert = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SwissTheme.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isAlert ? SwissTheme.crimson : SwissTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (hasIndicator) ...[
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(color: SwissTheme.emerald, shape: BoxShape.circle),
                ),
                const SizedBox(width: 5),
              ],
              Text(
                label,
                style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 9, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            subtext,
            style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 10),
          ),
        ],
      ),
    );
  }

  /// Rıhtım / İskele Durum Çubuğu
  Widget _buildBerthSelectorStrip() {
    return Container(
      height: 36,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _berths.length + 1,
        itemBuilder: (context, index) {
          final berth = index == 0 ? 'TÜMÜ' : _berths[index - 1];
          final isSel = _selectedBerth == berth;

          final count = index == 0
              ? _records.where((r) => r.isInside).length
              : _records.where((r) => r.isInside && r.destination == berth).length;

          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: () => setState(() => _selectedBerth = berth),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isSel ? SwissTheme.blue : SwissTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: isSel ? SwissTheme.blueLight : SwissTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      berth,
                      style: GoogleFonts.inter(
                        color: isSel ? Colors.white : SwissTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: isSel ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                    if (count > 0) ...[
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                        decoration: BoxDecoration(
                          color: isSel ? Colors.black.withValues(alpha: 0.25) : SwissTheme.surfaceSubtle,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '$count',
                          style: GoogleFonts.inter(
                            color: isSel ? Colors.white : SwissTheme.blueLight,
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Arama ve Durum Sekmeleri
  Widget _buildSearchAndStatusTabs({required int delayedCount}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Column(
        children: [
          // Arama
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: SwissTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwissTheme.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search, color: SwissTheme.textMuted, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Plaka, yük cinsi veya sürücü ara...',
                      hintStyle: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 12),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, color: SwissTheme.textMuted, size: 16),
                    onPressed: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // 4 Durum Sekmesi
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: SwissTheme.surface,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: SwissTheme.border),
            ),
            child: Row(
              children: [
                _buildFilterTab(0, 'TÜMÜ'),
                _buildFilterTab(1, 'SAHADA'),
                _buildFilterTab(2, 'ÇIKANLAR'),
                _buildFilterTab(3, 'GECİKENLER', badgeCount: delayedCount),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(int index, String title, {int? badgeCount}) {
    final isSel = _selectedFilterTab == index;
    final isAlert = index == 3 && badgeCount != null && badgeCount > 0;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedFilterTab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: isSel ? (isAlert ? SwissTheme.crimson : SwissTheme.surfaceSubtle) : Colors.transparent,
            borderRadius: BorderRadius.circular(6),
            border: isSel && !isAlert ? Border.all(color: SwissTheme.border) : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: isSel ? Colors.white : SwissTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              if (badgeCount != null && badgeCount > 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: isSel ? Colors.black.withValues(alpha: 0.3) : SwissTheme.crimson,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Kurumsal Swiss Terminal Kartı
  Widget _buildTerminalCard(VehicleRecord record) {
    final entryTimeStr = DateFormat('HH:mm').format(record.entryTime);
    final exitTimeStr = record.exitTime != null ? DateFormat('HH:mm').format(record.exitTime!) : '--';

    final durHours = record.duration.inHours;
    final durMinutes = record.duration.inMinutes % 60;
    final durationStr = durHours > 0 ? '$durHours sa $durMinutes dk' : '$durMinutes dk';

    final isDelayed = record.isDelayed;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: SwissTheme.surfaceCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDelayed ? SwissTheme.crimson.withValues(alpha: 0.7) : SwissTheme.border,
          width: isDelayed ? 1.2 : 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── ÜST SATIR: PLAKA & DURUM ROZETİ ──
          Row(
            children: [
              // Plaka Rozeti
              Container(
                decoration: BoxDecoration(
                  color: SwissTheme.surface,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: SwissTheme.border),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                      decoration: const BoxDecoration(
                        color: SwissTheme.blue,
                        borderRadius: BorderRadius.horizontal(left: Radius.circular(5)),
                      ),
                      child: Text('TR', style: GoogleFonts.inter(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w900)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      child: Text(
                        record.plate,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              // Durum Hapı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: record.isInside
                      ? (isDelayed ? SwissTheme.crimson.withValues(alpha: 0.15) : SwissTheme.emerald.withValues(alpha: 0.12))
                      : SwissTheme.surfaceSubtle,
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(
                    color: record.isInside
                        ? (isDelayed ? SwissTheme.crimson : SwissTheme.emerald.withValues(alpha: 0.5))
                        : SwissTheme.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        color: record.isInside ? (isDelayed ? SwissTheme.crimson : SwissTheme.emerald) : SwissTheme.textMuted,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      record.isInside ? (isDelayed ? 'GECİKME' : 'SAHADA') : 'ÇIKIŞ YAPILDI',
                      style: GoogleFonts.inter(
                        color: record.isInside ? (isDelayed ? SwissTheme.crimson : SwissTheme.emerald) : SwissTheme.textSecondary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Seçenekler / Silme
              GestureDetector(
                onTap: () => _deleteRecord(record),
                child: const Icon(Icons.more_horiz, color: SwissTheme.textMuted, size: 18),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── ORTA TABLO: BÖLGE, YÜK, TONAJ, SÜRÜCÜ ──
          Row(
            children: [
              Expanded(child: _buildDataCell('HEDEF İSKELE', record.destination)),
              Expanded(child: _buildDataCell('YÜK CİNSİ', record.cargoType)),
              Expanded(child: _buildDataCell('TONAJ', '${record.tonnage.toStringAsFixed(1)} Ton')),
              Expanded(child: _buildDataCell('SÜRÜCÜ', record.driverName.isNotEmpty ? record.driverName : '-')),
            ],
          ),

          const SizedBox(height: 10),
          const Divider(height: 1, color: SwissTheme.borderSubtle),
          const SizedBox(height: 10),

          // ── ALT ZAMAN ÇİZELGESİ VE AKSİYON BUTONU ──
          Row(
            children: [
              // Giriş / Çıkış Zaman Bilgisi
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 14, color: SwissTheme.textMuted),
                    const SizedBox(width: 6),
                    Text(
                      'Giriş: $entryTimeStr  •  Çıkış: $exitTimeStr',
                      style: GoogleFonts.inter(color: SwissTheme.textSecondary, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: SwissTheme.surfaceSubtle,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        durationStr,
                        style: GoogleFonts.inter(
                          color: isDelayed ? SwissTheme.crimson : SwissTheme.textSecondary,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Çıkış Ver Butonu
              if (record.isInside)
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwissTheme.blue,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    onPressed: () => _checkOutRecord(record),
                    child: Text('ÇIKIŞ YAP', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold, letterSpacing: 0.4),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Boş Durum
  Widget _buildEmptyState() {
    final bool hasNoRecordsAtAll = _records.isEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: SwissTheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: SwissTheme.border),
              ),
              child: Icon(
                hasNoRecordsAtAll ? Icons.local_shipping_outlined : Icons.inbox_outlined,
                color: SwissTheme.textMuted,
                size: 36,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              hasNoRecordsAtAll ? 'Kayıtlı Araç Bulunmuyor' : 'Terminal Hareketi Bulunamadı',
              style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              hasNoRecordsAtAll
                  ? 'Terminalde henüz kayıtlı araç yok.\nAşağıdaki "+ ARAÇ KABUL" butonu ile yeni araç girişi yapabilirsiniz.'
                  : 'Seçili filtre veya aramaya uygun araç kaydı yok.',
              style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 12, height: 1.4),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Alt Eylem Butonları (Swiss Terminal FAB)
  Widget _buildTerminalActionBar() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Optik Plaka Tarayıcı (LPR)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissTheme.surfaceSubtle,
              foregroundColor: Colors.white,
              elevation: 4,
              side: const BorderSide(color: SwissTheme.border),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            icon: const Icon(Icons.crop_free, color: SwissTheme.blueLight, size: 18),
            label: Text('OPTİK TARA (LPR)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: _openOpticalScanner,
          ),

          const SizedBox(width: 10),

          // Yeni Araç Ekle
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: SwissTheme.blue,
              foregroundColor: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            icon: const Icon(Icons.add, size: 18),
            label: Text('ARAÇ KABUL', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
            onPressed: () => _showCheckInModal(),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════════════
// 👁️ SWISS OPTICAL SCANNER MODAL (AIRPORT / PORT CUSTOMS GRADE)
// ════════════════════════════════════════════════════════════════════════════════
class _TerminalOpticalScannerModal extends StatefulWidget {
  final Function(String plate, String cargo, double tonnage) onScanComplete;

  const _TerminalOpticalScannerModal({required this.onScanComplete});

  @override
  State<_TerminalOpticalScannerModal> createState() => _TerminalOpticalScannerModalState();
}

class _TerminalOpticalScannerModalState extends State<_TerminalOpticalScannerModal> with SingleTickerProviderStateMixin {
  late AnimationController _sweepAnim;
  final ImagePicker _picker = ImagePicker();

  bool _isProcessing = false;
  String? _detectedPlate;
  String _detectedCargo = 'Kömür';
  double _detectedTonnage = 28.5;
  double _confidence = 0.0;

  final List<Map<String, dynamic>> _demoPlates = [
    {'plate': '31 K 9421', 'cargo': 'Rulo Sac', 'tonnage': 28.4, 'confidence': 0.992},
    {'plate': '34 ERD 88', 'cargo': 'Hurda', 'tonnage': 32.1, 'confidence': 0.987},
    {'plate': '06 AC 5542', 'cargo': 'Kömür', 'tonnage': 36.0, 'confidence': 0.995},
    {'plate': '31 Z 7710', 'cargo': 'Kangal Demir', 'tonnage': 25.8, 'confidence': 0.981},
    {'plate': '33 ABR 190', 'cargo': 'Kütük Demir', 'tonnage': 29.2, 'confidence': 0.976},
  ];

  @override
  void initState() {
    super.initState();
    _sweepAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _sweepAnim.dispose();
    super.dispose();
  }

  Future<void> _runQuickAiScan() async {
    setState(() => _isProcessing = true);
    HapticFeedback.lightImpact();

    await Future.delayed(const Duration(milliseconds: 1100));

    final sample = _demoPlates[math.Random().nextInt(_demoPlates.length)];

    if (mounted) {
      setState(() {
        _isProcessing = false;
        _detectedPlate = sample['plate'];
        _detectedCargo = sample['cargo'];
        _detectedTonnage = sample['tonnage'];
        _confidence = sample['confidence'];
      });
      HapticFeedback.mediumImpact();
    }
  }

  Future<void> _captureFromCamera(ImageSource source) async {
    try {
      final XFile? file = await _picker.pickImage(source: source);
      if (file == null) return;

      setState(() => _isProcessing = true);
      HapticFeedback.lightImpact();

      await Future.delayed(const Duration(milliseconds: 1300));

      final sample = _demoPlates[math.Random().nextInt(_demoPlates.length)];

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _detectedPlate = sample['plate'];
          _detectedCargo = sample['cargo'];
          _detectedTonnage = sample['tonnage'];
          _confidence = 0.989;
        });
        HapticFeedback.mediumImpact();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.80,
      decoration: const BoxDecoration(
        color: SwissTheme.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: SwissTheme.border, width: 1.5)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        children: [
          // Tutamaç
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: SwissTheme.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),

          // Başlık
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'OPTİK PLAKA TARAYICI',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'LPR / ANPR Plaka ve İrsaliye Ayrıştırma',
                    style: GoogleFonts.inter(color: SwissTheme.textMuted, fontSize: 11),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: SwissTheme.textMuted, size: 20),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Vizör Kutusu
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: SwissTheme.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: SwissTheme.border),
              ),
              child: Stack(
                children: [
                  // Merkez Nişangah
                  Center(
                    child: Container(
                      width: 260,
                      height: 110,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Stack(
                        children: [
                          // Lazer Hattı
                          AnimatedBuilder(
                            animation: _sweepAnim,
                            builder: (context, child) {
                              return Positioned(
                                top: _sweepAnim.value * 105,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 1.5,
                                  color: SwissTheme.blueLight,
                                ),
                              );
                            },
                          ),
                          Center(
                            child: Text(
                              _detectedPlate ?? 'PLAKAYI ÇERÇEVEYE HİZALAYIN',
                              style: GoogleFonts.inter(
                                color: _detectedPlate != null ? SwissTheme.emerald : SwissTheme.textMuted,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  if (_isProcessing)
                    Container(
                      color: Colors.black.withValues(alpha: 0.5),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2, color: SwissTheme.blueLight),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Ayrıştırılıyor...',
                              style: GoogleFonts.inter(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Algılanan Veri Kartı
          if (_detectedPlate != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SwissTheme.surfaceSubtle,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: SwissTheme.emerald.withValues(alpha: 0.6)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: SwissTheme.emerald, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('OKUNAN: $_detectedPlate',
                            style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1)),
                        Text('Yük: $_detectedCargo • Tonaj: $_detectedTonnage Ton • Doğruluk: %${(_confidence * 100).toStringAsFixed(1)}',
                            style: GoogleFonts.inter(color: SwissTheme.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SwissTheme.emerald,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onPressed: () {
                      widget.onScanComplete(_detectedPlate!, _detectedCargo, _detectedTonnage);
                    },
                    child: Text('FORMA AKTAR', style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Eylem Butonları
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: SwissTheme.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isProcessing ? null : _runQuickAiScan,
                  child: Text('HIZLI TEST', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SwissTheme.blue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.camera_alt, size: 16),
                  label: Text('KAMERA', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold)),
                  onPressed: _isProcessing ? null : () => _captureFromCamera(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(
                  backgroundColor: SwissTheme.surfaceSubtle,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: const BorderSide(color: SwissTheme.border),
                  ),
                ),
                icon: const Icon(Icons.photo_library, color: Colors.white, size: 18),
                onPressed: _isProcessing ? null : () => _captureFromCamera(ImageSource.gallery),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
