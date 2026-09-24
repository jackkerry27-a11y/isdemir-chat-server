import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../utils/pdf_font_helper.dart';

class VehicleRecord {
  final String id;
  final String destination;
  final String cargoType;
  final DateTime entryTime;
  DateTime? exitTime;

  VehicleRecord({
    required this.id,
    required this.destination,
    required this.cargoType,
    required this.entryTime,
    this.exitTime,
  });

  bool get isInside => exitTime == null;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'destination': destination,
      'cargoType': cargoType,
      'entryTime': entryTime.toIso8601String(),
      'exitTime': exitTime?.toIso8601String(),
    };
  }

  factory VehicleRecord.fromJson(Map<String, dynamic> json) {
    return VehicleRecord(
      id: json['id'],
      destination: json['destination'],
      cargoType: json['cargoType'],
      entryTime: DateTime.parse(json['entryTime']),
      exitTime: json['exitTime'] != null ? DateTime.parse(json['exitTime']) : null,
    );
  }
}

class VehicleScreen extends StatefulWidget {
  const VehicleScreen({super.key});

  @override
  State<VehicleScreen> createState() => _VehicleScreenState();
}

class _VehicleScreenState extends State<VehicleScreen> {
  int _selectedTab = 0; // 0: Tümü, 1: İçeridekiler, 2: Çıkanlar

  final List<VehicleRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('vehicle_records');
    
    if (recordsJson != null) {
      final List<dynamic> decoded = json.decode(recordsJson);
      setState(() {
        _records.clear();
        _records.addAll(decoded.map((e) => VehicleRecord.fromJson(e)).toList());
      });
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('vehicle_records', encoded);
  }

  String _destination = 'Gv1';
  String _cargo = 'Kömür';

  final List<String> _destinations = ['Gv1', 'Gv2', 'Gv3', 'Gv4', 'Yb8', 'Yb9', 'Yb10', 'Yb11', 'Yb12'];
  final List<String> _cargoTypes = ['Kömür', 'Hurda', 'Rulo Sac', 'Kangal Demir', 'Kütük Demir', 'Diğer'];

  void _showAddVehicleModal() {
    DateTime manualEntryTime = DateTime.now();
    DateTime? manualExitTime;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.85,
            decoration: const BoxDecoration(
              color: Color(0xFF141416),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 16,
              left: 24,
              right: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 48,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF3F3F46),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // Header row
                Row(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE50914).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.2)),
                      ),
                      child: const Icon(Icons.directions_car_rounded, color: Color(0xFFE50914), size: 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: RichText(
                        text: const TextSpan(
                          text: 'Yeni ',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          children: [
                            TextSpan(
                              text: 'Araç Girişi',
                              style: TextStyle(color: Color(0xFFE50914)),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text(
                  'Liman sahasına giren aracın operasyon bilgilerini seçin.',
                  style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
                ),
                const SizedBox(height: 32),
                
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // GİTTİĞİ BÖLGE
                        _buildCustomDropdown(
                          label: 'GİTTİĞİ BÖLGE',
                          icon: Icons.place_rounded,
                          value: _destination,
                          items: _destinations,
                          onChanged: (val) {
                            setModalState(() => _destination = val!);
                            setState(() => _destination = val!);
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // YÜK TİPİ
                        _buildCustomDropdown(
                          label: 'YÜK TİPİ',
                          icon: Icons.inventory_2_rounded,
                          value: _cargo,
                          items: _cargoTypes,
                          onChanged: (val) {
                            setModalState(() => _cargo = val!);
                            setState(() => _cargo = val!);
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // GİRİŞ SAATİ
                        _buildCustomDatePicker(
                          label: 'GİRİŞ SAATİ (OPSİYONEL)',
                          date: manualEntryTime,
                          isExit: false,
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context, 
                              initialDate: manualEntryTime, 
                              firstDate: DateTime(2000), 
                              lastDate: DateTime(2100),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFE50914),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF1C1C22),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (date != null) {
                              if (!mounted) return;
                              final time = await showTimePicker(
                                context: context, 
                                initialTime: TimeOfDay.fromDateTime(manualEntryTime),
                                builder: (context, child) => Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFFE50914),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1C1C22),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (time != null) {
                                setModalState(() {
                                  manualEntryTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        
                        // ÇIKIŞ SAATİ
                        _buildCustomDatePicker(
                          label: 'ÇIKIŞ SAATİ (OPSİYONEL)',
                          date: manualExitTime,
                          isExit: true,
                          onTap: () async {
                            final initialDate = manualExitTime ?? manualEntryTime;
                            final date = await showDatePicker(
                              context: context, 
                              initialDate: initialDate, 
                              firstDate: DateTime(2000), 
                              lastDate: DateTime(2100),
                              builder: (context, child) => Theme(
                                data: ThemeData.dark().copyWith(
                                  colorScheme: const ColorScheme.dark(
                                    primary: Color(0xFFE50914),
                                    onPrimary: Colors.white,
                                    surface: Color(0xFF1C1C22),
                                    onSurface: Colors.white,
                                  ),
                                ),
                                child: child!,
                              ),
                            );
                            if (date != null) {
                              if (!mounted) return;
                              final time = await showTimePicker(
                                context: context, 
                                initialTime: TimeOfDay.fromDateTime(initialDate),
                                builder: (context, child) => Theme(
                                  data: ThemeData.dark().copyWith(
                                    colorScheme: const ColorScheme.dark(
                                      primary: Color(0xFFE50914),
                                      onPrimary: Colors.white,
                                      surface: Color(0xFF1C1C22),
                                      onSurface: Colors.white,
                                    ),
                                  ),
                                  child: child!,
                                ),
                              );
                              if (time != null) {
                                setModalState(() {
                                  manualExitTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                                });
                              }
                            }
                          },
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ),
                
                // Submit Button
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _records.insert(0, VehicleRecord(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        destination: _destination,
                        cargoType: _cargo,
                        entryTime: manualEntryTime,
                        exitTime: manualExitTime,
                      ));
                    });
                    _saveRecords();
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Araç girişi başarıyla kaydedildi.'), backgroundColor: Colors.green),
                    );
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE50914), Color(0xFF990000)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE50914).withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(Icons.login_rounded, color: Colors.white, size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'ARAÇ GİRİŞİNİ YAP',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          );
        }
      ),
    );
  }

  Widget _buildCustomDropdown({
    required String label, 
    required IconData icon, 
    required String value, 
    required List<String> items, 
    required Function(String?) onChanged
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFF141416),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFFE50914), size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: value,
                    dropdownColor: const Color(0xFF1C1C22),
                    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFFE50914)),
                    isExpanded: true,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                    items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
                    onChanged: onChanged,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomDatePicker({
    required String label, 
    required DateTime? date,
    required bool isExit,
    required VoidCallback onTap
  }) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final timeFormat = DateFormat('HH:mm');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: const BoxDecoration(color: Color(0xFFE50914), shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
              ),
            ],
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onTap,
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF141416),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.access_time_rounded, color: Color(0xFFE50914), size: 20),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        date != null ? dateFormat.format(date) : 'Belirtilmedi',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        date != null ? timeFormat.format(date) : 'İçeride',
                        style: TextStyle(color: isExit && date == null ? const Color(0xFFA1A1AA) : const Color(0xFFE50914), fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.calendar_today_outlined, color: Color(0xFFE50914), size: 20),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _markAsExited(VehicleRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Çıkış İşlemi', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Araç çıkış saatini nasıl belirlemek istersiniz?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final date = await showDatePicker(
                context: context, 
                initialDate: DateTime.now(), 
                firstDate: record.entryTime, 
                lastDate: DateTime(2100)
              );
              if (date != null) {
                if (!mounted) return;
                final time = await showTimePicker(
                  context: context, 
                  initialTime: TimeOfDay.now()
                );
                if (time != null) {
                  setState(() {
                    record.exitTime = DateTime(date.year, date.month, date.day, time.hour, time.minute);
                  });
                  _saveRecords();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Araç çıkışı manuel olarak kaydedildi.'), backgroundColor: Colors.orange),
                    );
                  }
                }
              }
            },
            child: const Text('Manuel Seç'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF59E0B),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                record.exitTime = DateTime.now();
              });
              _saveRecords();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Araç çıkışı verildi.'), backgroundColor: Colors.orange),
              );
            },
            child: const Text('Şimdi Çıkış Ver'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndSharePDF() async {
    if (_records.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kaydedilecek araç kaydı bulunmuyor.'), backgroundColor: Colors.red),
      );
      return;
    }

    final pdfTheme = await PdfFontHelper.getTheme();
    final pdf = pw.Document(theme: pdfTheme);

    String normalizeTr(String text) {
      return PdfFontHelper.sanitize(text);
    }

    final logoSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M4 6h4v12H4zm6-4h4v20h-4zm6 4h4v12h-4z" fill="#0B2B6D"/></svg>''';
    final transferSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M20 18v-4h-2v4H6V6h7V4H6c-1.1 0-2 .9-2 2v12c0 1.1.9 2 2 2h12c1.1 0 2-.9 2-2zm-3-8h3l-4-4-4 4h3v4h2v-4z" fill="#0B2B6D"/></svg>''';
    final calSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.11 0-1.99.9-1.99 2L3 20a2 2 0 0 0 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10z" fill="#0B2B6D"/></svg>''';
    final docSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm2 16H8v-2h8v2zm0-4H8v-2h8v2zm-3-5V3.5L18.5 9H13z" fill="#0B2B6D"/></svg>''';
    final infoSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm1 15h-2v-6h2v6zm0-8h-2V7h2v2z" fill="#0B2B6D"/></svg>''';
    final checkSvg = '''<svg viewBox="0 0 24 24" width="24" height="24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" fill="#0B2B6D"/></svg>''';

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        build: (pw.Context context) {
          return [
              // Header
              pw.Row(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: logoSvg, width: 40, height: 40),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ISDEMIR OS', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0B2B6D))),
                          pw.Text('ARAC GIRIS / CIKIS DEKONTU', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Container(
                    width: 48,
                    height: 48,
                    decoration: const pw.BoxDecoration(
                      color: PdfColor.fromInt(0xFFF1F5F9),
                      shape: pw.BoxShape.circle,
                    ),
                    child: pw.Center(child: pw.SvgImage(svg: transferSvg, width: 24, height: 24)),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: const PdfColor.fromInt(0xFF0B2B6D)),
              pw.SizedBox(height: 24),
              
              // Info Cards
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F9FA),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  children: [
                    // Card 1
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 36, height: 36,
                            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EEF8), shape: pw.BoxShape.circle),
                            child: pw.Center(child: pw.SvgImage(svg: calSvg, width: 18, height: 18)),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('TARIH / SAAT', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              pw.Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now()), style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    pw.Container(width: 1, height: 30, color: PdfColors.grey400),
                    pw.SizedBox(width: 16),
                    // Card 2
                    pw.Expanded(
                      child: pw.Row(
                        children: [
                          pw.Container(
                            width: 36, height: 36,
                            decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EEF8), shape: pw.BoxShape.circle),
                            child: pw.Center(child: pw.SvgImage(svg: docSvg, width: 18, height: 18)),
                          ),
                          pw.SizedBox(width: 12),
                          pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('TOPLAM KAYIT', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                              pw.Text('${_records.length}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.black)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 32),
              
              // Table
              pw.TableHelper.fromTextArray(
                context: context,
                border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                headerAlignment: pw.Alignment.center,
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 9),
                headerDecoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFF0B2B6D)),
                cellAlignment: pw.Alignment.center,
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['ISLEM NO', 'BOLGE', 'YUK TIPI', 'GIRIS SAATI', 'CIKIS SAATI', 'SURE'],
                data: _records.map((r) {
                  final entryStr = DateFormat('HH:mm').format(r.entryTime);
                  final exitStr = r.exitTime != null ? DateFormat('HH:mm').format(r.exitTime!) : 'Iceride';
                  String durationStr = '-';
                  if (r.exitTime != null) {
                    final diff = r.exitTime!.difference(r.entryTime);
                    durationStr = '${diff.inHours}sa ${diff.inMinutes % 60}dk';
                  } else {
                    final diff = DateTime.now().difference(r.entryTime);
                    durationStr = '${diff.inHours}sa ${diff.inMinutes % 60}dk (Ic.)';
                  }
                  final shortId = r.id.length > 5 ? r.id.substring(r.id.length - 5) : r.id;
                  return [shortId, normalizeTr(r.destination), normalizeTr(r.cargoType), entryStr, exitStr, durationStr];
                }).toList(),
              ),
              
              pw.SizedBox(height: 40),
              
              // Footer
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F9FA),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey200, width: 1),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Col 1: Aciklama
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.SvgImage(svg: infoSvg, width: 12, height: 12),
                              pw.SizedBox(width: 6),
                              pw.Text('ACIKLAMA', style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Bu belge sisteme kayitli verilere\nistinaden otomatik olarak\nolusturulmustur.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                        ],
                      ),
                    ),
                    pw.Container(width: 1, height: 40, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                    
                    // Col 2: Belge No
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.SvgImage(svg: docSvg, width: 12, height: 12),
                              pw.SizedBox(width: 6),
                              pw.Text('BELGE NO', style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('AGC-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}01', style: pw.TextStyle(fontSize: 9, color: PdfColors.black)),
                          pw.SizedBox(height: 4),
                          pw.Container(height: 1, width: 40, color: const PdfColor.fromInt(0xFF0B2B6D)),
                        ],
                      ),
                    ),
                    pw.Container(width: 1, height: 40, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                    
                    // Col 3: Onay
                    pw.Expanded(
                      flex: 2,
                      child: pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Row(
                            children: [
                              pw.SvgImage(svg: checkSvg, width: 12, height: 12),
                              pw.SizedBox(width: 6),
                              pw.Text('ONAY', style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            ],
                          ),
                          pw.SizedBox(height: 8),
                          pw.Text('Sistem Kayitlidir.', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
                          pw.Text('Islak imza gerektirmez.', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              pw.SizedBox(height: 20),
              
              // Stamp
              pw.Center(
                child: pw.Container(
                  width: 80, height: 80,
                  decoration: pw.BoxDecoration(
                    shape: pw.BoxShape.circle,
                    border: pw.Border.all(color: const PdfColor.fromInt(0xFF0B2B6D), width: 1.5),
                  ),
                  child: pw.Center(
                    child: pw.Container(
                      width: 72, height: 72,
                      decoration: pw.BoxDecoration(
                        shape: pw.BoxShape.circle,
                        border: pw.Border.all(color: const PdfColor.fromInt(0xFF0B2B6D), width: 0.5, style: pw.BorderStyle.dashed),
                      ),
                      child: pw.Center(
                        child: pw.Column(
                          mainAxisAlignment: pw.MainAxisAlignment.center,
                          children: [
                            pw.Text('ISDEMIR OS', style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('SISTEM', style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            pw.Text('KAYITLI', style: pw.TextStyle(fontSize: 7, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                            pw.SizedBox(height: 2),
                            pw.Text('RESMI BELGE', style: pw.TextStyle(fontSize: 6, color: const PdfColor.fromInt(0xFF0B2B6D))),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ];
        },
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Isdemir_Arac_Operasyon_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await Share.shareXFiles([XFile(file.path)], text: 'Günlük Araç Operasyon Dekontu (PDF)');
    } catch (e) {
      debugPrint('PDF Hatasi: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF oluşturulurken hata oluştu: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final topBgColor = const Color(0xFF0F0F13); // Deep dark
    final pageBgColor = const Color(0xFF0F0F13);

    List<VehicleRecord> filteredRecords = _records;
    if (_selectedTab == 1) {
      filteredRecords = _records.where((a) => a.isInside).toList();
    } else if (_selectedTab == 2) {
      filteredRecords = _records.where((a) => !a.isInside).toList();
    }

    final int todayEntries = _records.where((r) => r.entryTime.day == DateTime.now().day).length;
    final int todayExits = _records.where((r) => r.exitTime != null && r.exitTime!.day == DateTime.now().day).length;
    final int insideCount = _records.where((r) => r.isInside).length;

    return Scaffold(
      backgroundColor: topBgColor,
      body: Stack(
        children: [
          // Background Gradient Image
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 350,
            child: Stack(
              children: [
                SizedBox.expand(
                  child: Image.asset(
                    'assets/images/factory_bg.jpg',
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        const Color(0xFFE50914).withValues(alpha: 0.15),
                        const Color(0xFF0F0F13).withValues(alpha: 0.8),
                        const Color(0xFF0F0F13),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          Column(
            children: [
              // CUSTOM APP BAR
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Araç Giriş / Çıkış', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                            SizedBox(height: 4),
                            Text('Tüm giriş ve çıkış kayıtlarını kolayca görüntüleyin.', style: TextStyle(color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // STATS CARD
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C22),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Expanded(child: _buildNewStatItem('Günlük Giriş', todayEntries.toString(), Icons.login_rounded, const Color(0xFFE50914))),
                      Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.1)),
                      Expanded(child: _buildNewStatItem('İçerideki Araç', insideCount.toString(), Icons.directions_car_rounded, const Color(0xFFE50914))),
                      Container(width: 1, height: 50, color: Colors.white.withValues(alpha: 0.1)),
                      Expanded(child: _buildNewStatItem('Günlük Çıkış', todayExits.toString(), Icons.logout_rounded, const Color(0xFFE50914))),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // TABS & LIST SECTION
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: pageBgColor,
                  ),
                  child: Column(
                    children: [
                      // TABS
                      Padding(
                        padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 16),
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C22),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              _buildNewTabItem(0, 'Tümü', null),
                              _buildNewTabItem(1, 'İçeridekiler', Icons.directions_car_rounded),
                              _buildNewTabItem(2, 'Çıkanlar', Icons.logout_rounded),
                            ],
                          ),
                        ),
                      ),
                      
                      // LIST
                      Expanded(
                        child: filteredRecords.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(24),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1C1C22),
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFFE50914).withValues(alpha: 0.2),
                                            blurRadius: 30,
                                            spreadRadius: 5,
                                          )
                                        ],
                                      ),
                                      child: const Icon(Icons.directions_car_rounded, size: 48, color: Color(0xFFE50914)),
                                    ),
                                    const SizedBox(height: 24),
                                    const Text(
                                      'Henüz araç kaydı bulunmuyor',
                                      style: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14, fontWeight: FontWeight.w500),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                itemCount: filteredRecords.length,
                                itemBuilder: (context, index) {
                                  return _buildNewRecordCard(filteredRecords[index]);
                                },
                              ),
                      ),

                      // BOTTOM BUTTONS KALDARILDI - YERİNE FAB EKLENDİ

                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showBottomMenu,
        backgroundColor: const Color(0xFFE50914),
        elevation: 4,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }

  void _showBottomMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF141416),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _generateAndSharePDF();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C22),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Tüm Bilgileri Kaydet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('Tüm kayıtları PDF olarak dışa aktarın', style: TextStyle(fontSize: 12, color: Color(0xFFA1A1AA))),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFA1A1AA)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () {
                  Navigator.pop(context);
                  _showAddVehicleModal();
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFE50914), Color(0xFF990000)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: const Color(0xFFE50914).withValues(alpha: 0.4), blurRadius: 15, offset: const Offset(0, 8))],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 28),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Yeni Giriş', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white)),
                            SizedBox(height: 2),
                            Text('Yeni araç giriş kaydı oluşturun', style: TextStyle(fontSize: 12, color: Colors.white70)),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _deleteRecord(VehicleRecord record) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C22),
        title: const Text('Silmeyi Onayla', style: TextStyle(color: Colors.white)),
        content: const Text('Bu araç kaydını silmek istediğinize emin misiniz?', style: TextStyle(color: Color(0xFFA1A1AA))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal', style: TextStyle(color: Color(0xFFA1A1AA))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914), foregroundColor: Colors.white),
            onPressed: () {
              setState(() {
                _records.remove(record);
              });
              _saveRecords();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Kayıt silindi.'), backgroundColor: Colors.red),
              );
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  Widget _buildNewStatItem(String title, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 4),
        Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFFA1A1AA)), textAlign: TextAlign.center),
      ],
    );
  }

  Widget _buildNewTabItem(int index, String title, IconData? icon) {
    final isSelected = _selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = index),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFE50914) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 16, color: isSelected ? Colors.white : const Color(0xFFA1A1AA)),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNewRecordCard(VehicleRecord record) {
    final dateFormat = DateFormat('dd MMMM yyyy', 'tr_TR');
    final timeFormat = DateFormat('HH:mm');
    
    final entryDateStr = dateFormat.format(record.entryTime);
    final entryTimeStr = timeFormat.format(record.entryTime);
    
    final exitDateStr = record.exitTime != null ? dateFormat.format(record.exitTime!) : '--';
    final exitTimeStr = record.exitTime != null ? timeFormat.format(record.exitTime!) : '--:--';
    
    String durationStr = '';
    if (record.exitTime != null) {
      final diff = record.exitTime!.difference(record.entryTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      durationStr = hours > 0 ? '${hours}sa ${minutes}dk' : '${minutes} dk';
    } else {
      final diff = DateTime.now().difference(record.entryTime);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;
      durationStr = hours > 0 ? '${hours}sa ${minutes}dk' : '${minutes} dk';
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(24),
        border: Border(left: BorderSide(color: record.isInside ? const Color(0xFF10B981) : const Color(0xFFE50914), width: 4)),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Top Row
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: record.isInside ? const Color(0xFF10B981).withValues(alpha: 0.1) : const Color(0xFFE50914).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  color: record.isInside ? const Color(0xFF10B981) : const Color(0xFFE50914),
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Araç İşlemi', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        const Icon(Icons.place, size: 14, color: Color(0xFFE50914)),
                        const SizedBox(width: 4),
                        Text(record.destination, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                        const SizedBox(width: 16),
                        const Icon(Icons.inventory_2_rounded, size: 14, color: Color(0xFFE50914)),
                        const SizedBox(width: 4),
                        Text(record.cargoType, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.timer_outlined, size: 14, color: Color(0xFFE50914)),
                    const SizedBox(width: 4),
                    Text(durationStr, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFFE50914))),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => _deleteRecord(record),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFA1A1AA), size: 18),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.05)),
          const SizedBox(height: 16),
          
          // Bottom Row
          Row(
            children: [
              // Entry
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.login_rounded, size: 18, color: Color(0xFF10B981)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Giriş', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
                        Text(entryTimeStr, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(entryDateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ],
                ),
              ),
              
              Container(width: 1, height: 40, color: Colors.white.withValues(alpha: 0.05)),
              const SizedBox(width: 16),
              
              // Exit
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.logout_rounded, size: 18, color: Color(0xFFE50914)),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Çıkış', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
                        Text(exitTimeStr, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: record.isInside ? const Color(0xFF71717A) : Colors.white)),
                        Text(exitDateStr, style: const TextStyle(fontSize: 11, color: Color(0xFF71717A))),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Action / Chevron
              if (record.isInside)
                GestureDetector(
                  onTap: () => _markAsExited(record),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE50914),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('Çıkış Ver', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                )
              else
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF3F3F46)),
            ],
          ),
        ],
      ),
    );
  }
}
