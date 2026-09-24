import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:animated_flip_counter/animated_flip_counter.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/user_model.dart';
import '../utils/pdf_font_helper.dart';

// Geçmiş bordro verisi modeli
class BordroData {
  final String ay;
  final int yil;
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final int ucretsizIzinGun;
  final int calismaGun;

  const BordroData({
    required this.ay,
    required this.yil,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.ucretsizIzinGun,
    required this.calismaGun,
  });
}

class BordroScreen extends StatefulWidget {
  final UserModel user;
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final int ucretsizIzinGun;

  const BordroScreen({
    super.key,
    required this.user,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.ucretsizIzinGun,
  });

  @override
  State<BordroScreen> createState() => _BordroScreenState();
}

class _BordroScreenState extends State<BordroScreen> {
  int _selectedIndex = 0; // 0 = Güncel ay
  int _selectedTab = 0; // 0 = Dağılım Grafiği, 1 = Puantaj Matrisi, 2 = Detay Kalemler
  bool _isAmountHidden = false; // Gizlilik Modu (Maaşı gizle / göster)
  int _touchedPieIndex = -1;
  bool _isGeneratingPdf = false;

  late final List<BordroData> _bordrolar;

  @override
  void initState() {
    super.initState();
    _bordrolar = [
      BordroData(ay: 'Ağustos', yil: 2026, normalMesaiGun: widget.normalMesaiGun, bayramMesaiGun: widget.bayramMesaiGun, ucretsizIzinGun: widget.ucretsizIzinGun, calismaGun: 30 - widget.ucretsizIzinGun),
      const BordroData(ay: 'Temmuz', yil: 2026, normalMesaiGun: 4, bayramMesaiGun: 2, ucretsizIzinGun: 0, calismaGun: 30),
      const BordroData(ay: 'Haziran', yil: 2026, normalMesaiGun: 0, bayramMesaiGun: 0, ucretsizIzinGun: 0, calismaGun: 30),
      const BordroData(ay: 'Mayıs', yil: 2026, normalMesaiGun: 5, bayramMesaiGun: 3, ucretsizIzinGun: 0, calismaGun: 30),
    ];
  }

  String _formatRawCurrency(double amount) {
    bool isNegative = amount < 0;
    amount = amount.abs();
    String whole = amount.truncate().toString();
    String formattedWhole = '';
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        formattedWhole += '.';
      }
      formattedWhole += whole[i];
    }
    String fractional = ((amount - amount.truncate()).abs() * 100).truncate().toString().padLeft(2, '0');
    return '${isNegative ? '- ' : ''}₺$formattedWhole,$fractional';
  }

  String _formatCurrency(double amount) {
    if (_isAmountHidden) {
      return '₺ ••••••';
    }
    return _formatRawCurrency(amount);
  }

  Future<void> _generateAndSharePDF(BordroData bordro, double brut, double mesai, double kesinti, double net) async {
    if (_isGeneratingPdf) return;
    setState(() => _isGeneratingPdf = true);

    final pdfTheme = await PdfFontHelper.getTheme();
    final pdf = pw.Document(theme: pdfTheme);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = dateFormat.format(DateTime.now());

    String formatCurrencyForPdf(double amount) {
      return _formatRawCurrency(amount).replaceAll('₺', 'TL');
    }

    String normalizeTr(String text) {
      return PdfFontHelper.sanitize(text);
    }

    final logoI = '''<svg viewBox="0 0 24 24" width="32" height="32"><path d="M8 2h8v4H8V2zm2 6h4v14h-4V8z" fill="#0B2B6D"/></svg>''';
    
    final personSvg = '''<svg viewBox="0 0 24 24"><path d="M12 12c2.21 0 4-1.79 4-4s-1.79-4-4-4-4 1.79-4 4 1.79 4 4 4zm0 2c-2.67 0-8 1.34-8 4v2h16v-2c0-2.66-5.33-4-8-4z" fill="#0B2B6D"/></svg>''';
    final workSvg = '''<svg viewBox="0 0 24 24"><path d="M20 6h-4V4c0-1.11-.89-2-2-2h-4c-1.11 0-2 .89-2 2v2H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-6 0h-4V4h4v2z" fill="#0B2B6D"/></svg>''';
    final badgeSvg = '''<svg viewBox="0 0 24 24"><path d="M14 2H6c-1.1 0-1.99.9-1.99 2L4 20c0 1.1.89 2 1.99 2H18c1.1 0 2-.9 2-2V8l-6-6zm-4 16H8v-2h2v2zm6-4H8v-2h8v2zm0-4H8v-2h8v2z" fill="#0B2B6D"/></svg>''';
    final calSvg = '''<svg viewBox="0 0 24 24"><path d="M19 4h-1V2h-2v2H8V2H6v2H5c-1.1 0-2 .9-2 2v14c0 1.1.9 2 2 2h14c1.1 0 2-.9 2-2V6c0-1.1-.9-2-2-2zm0 16H5V10h14v10z" fill="#0B2B6D"/></svg>''';
    
    final walletSvg = '''<svg viewBox="0 0 24 24"><path d="M21 7.28V5c0-1.1-.9-2-2-2H5c-1.11 0-2 .9-2 2v14c0 1.1.89 2 2 2h14c1.1 0 2-.9 2-2v-2.28c.59-.35 1-.98 1-1.72V9c0-.74-.41-1.37-1-1.72zM20 9v6h-7V9h7zM5 19V5h14v2h-6c-1.1 0-2 .9-2 2v6c0 1.1.9 2 2 2h6v2H5z" fill="#10B981"/></svg>''';
    final giftSvg = '''<svg viewBox="0 0 24 24"><path d="M20 6h-2.18c.11-.31.18-.65.18-1 0-1.66-1.34-3-3-3-1.05 0-1.95.54-2.5 1.35l-.5.75-.5-.75C10.95 2.54 10.05 2 9 2 7.34 2 6 3.34 6 5c0 .35.07.69.18 1H4c-1.11 0-1.99.89-1.99 2L2 19c0 1.11.89 2 2 2h16c1.11 0 2-.89 2-2V8c0-1.11-.89-2-2-2zm-5-2c.55 0 1 .45 1 1s-.45 1-1 1h-4v-2h4zM9 4c.55 0 1 .45 1 1v2H6c0-.55.45-1 1-1s1-.45 1-1 1 .45 1 1zM4 8h7v11H4V8zm16 11h-7V8h7v11z" fill="#3B82F6"/></svg>''';
    final percentSvg = '''<svg viewBox="0 0 24 24"><path d="M7 11c1.66 0 3-1.34 3-3S8.66 5 7 5 4 6.34 4 8s1.34 3 3 3zm0-4c.55 0 1 .45 1 1s-.45 1-1 1-1-.45-1-1 .45-1 1-1zm14 14l-14-14 1.41-1.41 14 14L21 21zm-4-4c-1.66 0-3 1.34-3 3s1.34 3 3 3 3-1.34 3-3-1.34-3-3-3zm0 4c-.55 0-1-.45-1-1s.45-1 1-1 1 .45 1 1-.45 1-1 1z" fill="#EF4444"/></svg>''';
    
    final bigShieldSvg = '''<svg viewBox="0 0 24 24"><path d="M12 1L3 5v6c0 5.55 3.84 10.74 9 12 5.16-1.26 9-6.45 9-12V5l-9-4zm-2 16l-4-4 1.41-1.41L10 14.17l6.59-6.59L18 9l-8 8z" fill="#1E293B"/></svg>''';
    final checkCircBlueSvg = '''<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" fill="#0B2B6D"/></svg>''';
    final checkCircGreenSvg = '''<svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z" fill="#10B981"/></svg>''';
    final signatureSvg = '''<svg viewBox="0 0 100 40"><path d="M10 25 Q 30 5 40 15 T 70 10 T 90 20" fill="none" stroke="#0B2B6D" stroke-width="1.5"/><path d="M35 25 L 60 10" fill="none" stroke="#0B2B6D" stroke-width="1.5"/></svg>''';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      pw.SvgImage(svg: logoI, width: 32, height: 32),
                      pw.SizedBox(width: 12),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('ISDEMIR A.S.', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: const PdfColor.fromInt(0xFF0B2B6D))),
                          pw.Text('MAAS DEKONTU', style: pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Text('ISDEMIR', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.grey300)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: const PdfColor.fromInt(0xFF0B2B6D)),
              pw.SizedBox(height: 24),

              // Personnel Info Cards
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F9FA),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Row(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    // Col 1 (Personel, Unvan, Sicil)
                    pw.Expanded(
                      flex: 6,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 32, height: 32,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                                child: pw.Center(child: pw.SvgImage(svg: personSvg, width: 16, height: 16)),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('PERSONEL', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                                  pw.Text(normalizeTr('${widget.user.firstName} ${widget.user.lastName}'), style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                                ],
                              ),
                            ]
                          ),
                          pw.SizedBox(height: 12),
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 32, height: 32,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                                child: pw.Center(child: pw.SvgImage(svg: workSvg, width: 16, height: 16)),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('UNVAN', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                                  pw.Text(normalizeTr(widget.user.jobTitle), style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                                ],
                              ),
                            ]
                          ),
                          pw.SizedBox(height: 12),
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 32, height: 32,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                                child: pw.Center(child: pw.SvgImage(svg: badgeSvg, width: 16, height: 16)),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('SICIL NO', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                                  pw.Text('ISD-947210', style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                                ],
                              ),
                            ]
                          ),
                        ]
                      ),
                    ),
                    pw.Container(width: 1, height: 120, color: PdfColors.grey300, margin: const pw.EdgeInsets.symmetric(horizontal: 16)),
                    // Col 2 (Donem, Tarih)
                    pw.Expanded(
                      flex: 5,
                      child: pw.Column(
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 32, height: 32,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                                child: pw.Center(child: pw.SvgImage(svg: calSvg, width: 16, height: 16)),
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('DONEM', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                                  pw.Text(normalizeTr('${bordro.ay.toUpperCase()} ${bordro.yil}'), style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                                ],
                              ),
                            ]
                          ),
                          pw.SizedBox(height: 16),
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 32, height: 32,
                                decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300), borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6))),
                                child: pw.Center(child: pw.SvgImage(svg: calSvg, width: 16, height: 16)), // Reusing calSvg for date
                              ),
                              pw.SizedBox(width: 12),
                              pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                children: [
                                  pw.Text('TARIH', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                                  pw.Text(dateStr, style: pw.TextStyle(fontSize: 12, color: PdfColors.black)),
                                ],
                              ),
                            ]
                          ),
                        ]
                      )
                    )
                  ]
                )
              ),
              
              pw.SizedBox(height: 24),
              
              // DETAILS TABLE HEADER
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0B2B6D),
                  borderRadius: pw.BorderRadius.only(topLeft: pw.Radius.circular(8), topRight: pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('KAZANC VE KESINTILER', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                    pw.Text('TUTAR (TL)', style: pw.TextStyle(color: PdfColors.white, fontWeight: pw.FontWeight.bold, fontSize: 10)),
                  ]
                )
              ),
              
              // DETAILS TABLE BODY
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  borderRadius: const pw.BorderRadius.only(bottomLeft: pw.Radius.circular(8), bottomRight: pw.Radius.circular(8)),
                ),
                padding: const pw.EdgeInsets.all(16),
                child: pw.Column(
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 36, height: 36,
                              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFECFDF5), shape: pw.BoxShape.circle),
                              child: pw.Center(child: pw.SvgImage(svg: walletSvg, width: 18, height: 18)),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Text('Brut Taban Maas', style: pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                          ]
                        ),
                        pw.Text(formatCurrencyForPdf(brut), style: pw.TextStyle(fontSize: 11, color: const PdfColor.fromInt(0xFF10B981))),
                      ]
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(color: PdfColors.grey200),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 36, height: 36,
                              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFEFF6FF), shape: pw.BoxShape.circle),
                              child: pw.Center(child: pw.SvgImage(svg: giftSvg, width: 18, height: 18)),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Text('Mesai Kazanci', style: pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                          ]
                        ),
                        pw.Text(formatCurrencyForPdf(mesai), style: pw.TextStyle(fontSize: 11, color: PdfColors.black)),
                      ]
                    ),
                    pw.SizedBox(height: 12),
                    pw.Divider(color: PdfColors.grey200),
                    pw.SizedBox(height: 12),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Row(
                          children: [
                            pw.Container(
                              width: 36, height: 36,
                              decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFFEF2F2), shape: pw.BoxShape.circle),
                              child: pw.Center(child: pw.SvgImage(svg: percentSvg, width: 18, height: 18)),
                            ),
                            pw.SizedBox(width: 12),
                            pw.Text('Ucretsiz Izin Kesintisi', style: pw.TextStyle(fontSize: 11, color: const PdfColor.fromInt(0xFFEF4444))),
                          ]
                        ),
                        pw.Text('- ${formatCurrencyForPdf(kesinti)}', style: pw.TextStyle(fontSize: 11, color: const PdfColor.fromInt(0xFFEF4444))),
                      ]
                    ),
                  ]
                )
              ),
              
              pw.SizedBox(height: 24),
              
              // BIG TOTAL CARD
              pw.Container(
                decoration: const pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF0B2B6D),
                  borderRadius: pw.BorderRadius.all(pw.Radius.circular(12)),
                ),
                padding: const pw.EdgeInsets.all(24),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.SvgImage(svg: bigShieldSvg, width: 48, height: 48),
                        pw.SizedBox(width: 16),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('NET ODENEN TUTAR', style: pw.TextStyle(fontSize: 9, color: PdfColors.grey300, fontWeight: pw.FontWeight.bold)),
                            pw.Text('Hesabiniza yatirilacak net tutar', style: pw.TextStyle(fontSize: 8, color: PdfColors.grey400)),
                          ],
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Row(
                          crossAxisAlignment: pw.CrossAxisAlignment.end,
                          children: [
                            pw.Text('TL ', style: pw.TextStyle(fontSize: 16, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                            pw.Text(formatCurrencyForPdf(net).replaceAll('TL', '').trim(), style: pw.TextStyle(fontSize: 24, color: PdfColors.white, fontWeight: pw.FontWeight.bold)),
                          ]
                        ),
                        pw.SizedBox(height: 4),
                        pw.Row(
                          children: [
                            pw.SvgImage(svg: checkCircGreenSvg, width: 12, height: 12),
                            pw.SizedBox(width: 4),
                            pw.Text('Odeme Tamamlandi', style: pw.TextStyle(fontSize: 9, color: const PdfColor.fromInt(0xFF10B981))),
                          ]
                        )
                      ]
                    )
                  ]
                )
              ),

              pw.Spacer(),

              // FOOTER
              pw.Container(
                decoration: pw.BoxDecoration(
                  color: const PdfColor.fromInt(0xFFF8F9FA),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                ),
                padding: const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Row(
                      children: [
                        pw.Container(
                          width: 32, height: 32,
                          decoration: const pw.BoxDecoration(color: PdfColor.fromInt(0xFFE8EEF8), shape: pw.BoxShape.circle),
                          child: pw.Center(child: pw.SvgImage(svg: checkCircBlueSvg, width: 16, height: 16)),
                        ),
                        pw.SizedBox(width: 12),
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text('Bu belge elektronik ortamda olusturulmus olup', style: pw.TextStyle(fontSize: 8, color: PdfColors.black)),
                            pw.Text('islak imza gerektirmez.', style: pw.TextStyle(fontSize: 8, color: const PdfColor.fromInt(0xFF0B2B6D), fontWeight: pw.FontWeight.bold)),
                          ]
                        )
                      ]
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.center,
                      children: [
                        pw.SvgImage(svg: signatureSvg, width: 80, height: 30),
                        pw.SizedBox(height: 4),
                        pw.Text('ISDEMIR A.S.', style: pw.TextStyle(fontSize: 8, color: PdfColors.black, fontWeight: pw.FontWeight.bold)),
                      ]
                    )
                  ]
                )
              )
            ],
          );
        },
      ),
    );

    try {
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/Maas_Dekontu_${bordro.ay}_${bordro.yil}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          text: '${bordro.ay} ${bordro.yil} Maaş Dekontu',
        ),
      );
    } catch (e) {
      debugPrint('PDF Hatasi: $e');
    } finally {
      if (mounted) {
        setState(() => _isGeneratingPdf = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bordro = _bordrolar[_selectedIndex];
    final job = widget.user.currentJobDetails;

    // Hesaplamalar
    final double brutMaas = job.baseSalary;
    final double normalMesaiKazanci = bordro.normalMesaiGun * job.normalMesaiRate;
    final double bayramMesaiKazanci = bordro.bayramMesaiGun * job.bayramMesaiRate;
    final double toplamMesaiKazanci = normalMesaiKazanci + bayramMesaiKazanci;
    final double ucretsizIzinKesintisi = bordro.ucretsizIzinGun * job.unpaidLeaveRate;
    final double netMaas = brutMaas + toplamMesaiKazanci - ucretsizIzinKesintisi;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // ── Koyu İsdemir Kurumsal Başlık Arkaplanı (Header Gradient) ──
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 290,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F172A), // Slate-900 Koyu Çelik
                    Color(0xFF1E293B), // Slate-800
                    Color(0xFF881337), // Rose-900 / Derin İsdemir Bordosu
                  ],
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // ── Özel AppBar (Geri, Başlık, Gizlilik Gözü, PDF Paylaş) ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Maaş Bordrosu & Puantaj',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'İSDEMİR A.Ş. • Personel Portalı',
                              style: GoogleFonts.inter(
                                color: const Color(0xFF94A3B8),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Gizlilik Modu (Göz Butonu)
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: IconButton(
                          icon: Icon(
                            _isAmountHidden ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                          tooltip: _isAmountHidden ? 'Maaşı Göster' : 'Maaşı Gizle',
                          onPressed: () {
                            setState(() => _isAmountHidden = !_isAmountHidden);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Hızlı PDF Paylaşım Butonu
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: _isGeneratingPdf
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                )
                              : const Icon(Icons.share_rounded, color: Colors.white, size: 20),
                          tooltip: 'Dekontu Paylaş',
                          onPressed: _isGeneratingPdf
                              ? null
                              : () => _generateAndSharePDF(bordro, brutMaas, toplamMesaiKazanci, ucretsizIzinKesintisi, netMaas),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 10),

                // ── Ay Seçici (Horizontal Pill List) ──
                SizedBox(
                  height: 42,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _bordrolar.length,
                    itemBuilder: (context, index) {
                      final b = _bordrolar[index];
                      final isSelected = _selectedIndex == index;
                      final isCurrent = index == 0;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              gradient: isSelected
                                  ? const LinearGradient(
                                      colors: [Color(0xFFDC2626), Color(0xFF991B1B)],
                                    )
                                  : null,
                              color: isSelected ? null : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: isSelected ? const Color(0xFFFF8A80) : Colors.white.withValues(alpha: 0.18),
                                width: 1.2,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFFDC2626).withValues(alpha: 0.45),
                                        blurRadius: 10,
                                        offset: const Offset(0, 3),
                                      ),
                                    ]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.event_available_rounded, color: Colors.white, size: 15),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${b.ay} ${b.yil}',
                                  style: GoogleFonts.inter(
                                    color: isSelected ? Colors.white : Colors.white70,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                                    fontSize: 12.5,
                                  ),
                                ),
                                if (isCurrent) ...[
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.white.withValues(alpha: 0.25) : const Color(0xFF10B981),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      'GÜNCEL',
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.5,
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
                ),

                const SizedBox(height: 12),

                // ── Kaydırılabilir Gövde ──
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Column(
                      children: [
                        // ── KART 1: Hologram VIP Bordro Kartı (Credit Card Style) ──
                        _buildVipBordroCard(bordro, netMaas, brutMaas, toplamMesaiKazanci, ucretsizIzinKesintisi),

                        const SizedBox(height: 16),

                        // ── Segment Tab Seçici (Grafik, Puantaj, Detaylar) ──
                        _buildSegmentTabBar(),

                        const SizedBox(height: 16),

                        // ── Seçili Tab İçeriği ──
                        if (_selectedTab == 0)
                          _buildChartTab(bordro, brutMaas, normalMesaiKazanci, bayramMesaiKazanci, ucretsizIzinKesintisi, netMaas)
                        else if (_selectedTab == 1)
                          _buildPuantajTab(bordro, job, normalMesaiKazanci, bayramMesaiKazanci, ucretsizIzinKesintisi)
                        else
                          _buildDetailsTab(bordro, job, brutMaas, normalMesaiKazanci, bayramMesaiKazanci, ucretsizIzinKesintisi, netMaas),

                        const SizedBox(height: 20),

                        // ── PDF İndir ve Paylaş Butonu ──
                        _buildPdfActionCard(bordro, brutMaas, toplamMesaiKazanci, ucretsizIzinKesintisi, netMaas),

                        const SizedBox(height: 32),
                      ],
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

  // ── 💳 Hologram Bordro Kredi Kartı ──
  Widget _buildVipBordroCard(BordroData bordro, double netMaas, double brutMaas, double mesaiKazanci, double kesinti) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E293B), // Slate-800
            Color(0xFF0F172A), // Slate-900
            Color(0xFF5A0C16), // Dark Crimson İsdemir
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Satır: Şirket Logosu & Dönem
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Icon(Icons.factory_rounded, color: Colors.white, size: 18),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İSDEMİR A.Ş.',
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                        ),
                      ),
                      Text(
                        'RESMİ MAAŞ BORDROSU',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF94A3B8),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                ),
                child: Text(
                  '${bordro.ay.toUpperCase()} ${bordro.yil}',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Orta Alan: Net Tutar Başlığı
          Text(
            'HESABA YATIRILACAK NET TUTAR',
            style: GoogleFonts.inter(
              color: const Color(0xFFCBD5E1),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),

          // Net Tutar (AnimatedFlipCounter & Gizlilik Desteği)
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '₺ ',
                style: GoogleFonts.inter(
                  color: const Color(0xFFE2E8F0),
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (_isAmountHidden)
                Text(
                  '• • • • • •',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 3.0,
                  ),
                )
              else
                AnimatedFlipCounter(
                  value: netMaas,
                  fractionDigits: 2,
                  thousandSeparator: '.',
                  decimalSeparator: ',',
                  duration: const Duration(milliseconds: 750),
                  curve: Curves.easeOutCubic,
                  textStyle: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
                ),
              const Spacer(),
              if (mesaiKazanci > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.arrow_upward_rounded, color: Color(0xFF10B981), size: 12),
                      const SizedBox(width: 2),
                      Text(
                        _isAmountHidden ? 'Mesai Ekli' : '+${_formatRawCurrency(mesaiKazanci)}',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 20),

          // Alt Satır: Personel Adı, Görevi ve Onay Rozeti
          Container(
            padding: const EdgeInsets.only(top: 14),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.12), width: 1)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: const Color(0xFFDC2626),
                      child: Text(
                        (widget.user.firstName.isNotEmpty ? widget.user.firstName[0] : 'İ') +
                            (widget.user.lastName.isNotEmpty ? widget.user.lastName[0] : 'S'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${widget.user.firstName} ${widget.user.lastName}',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.user.jobTitle,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF94A3B8),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 14),
                      const SizedBox(width: 4),
                      Text(
                        'Ödendi',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF10B981),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.08, end: 0);
  }

  // ── 🎛️ Segment Tab Bar ──
  Widget _buildSegmentTabBar() {
    final tabs = [
      {'icon': Icons.pie_chart_rounded, 'title': 'Dağılım'},
      {'icon': Icons.calendar_today_rounded, 'title': 'Puantaj'},
      {'icon': Icons.receipt_long_rounded, 'title': 'Kalemler'},
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: List.generate(tabs.length, (index) {
          final isSelected = _selectedTab == index;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedTab = index),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF0F172A) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tabs[index]['icon'] as IconData,
                      color: isSelected ? Colors.white : const Color(0xFF64748B),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      tabs[index]['title'] as String,
                      style: GoogleFonts.inter(
                        color: isSelected ? Colors.white : const Color(0xFF64748B),
                        fontSize: 12.5,
                        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── 📊 TAB 1: fl_chart İnteraktif Pasta / Donut Grafiği ──
  Widget _buildChartTab(BordroData bordro, double brutMaas, double normalMesai, double bayramMesai, double kesinti, double netMaas) {
    final double toplamKazanc = brutMaas + normalMesai + bayramMesai;
    final double mesaiOrani = toplamKazanc > 0 ? ((normalMesai + bayramMesai) / toplamKazanc * 100) : 0.0;

    List<PieChartSectionData> sections = [];
    if (brutMaas > 0) {
      final isTouched = _touchedPieIndex == 0;
      sections.add(PieChartSectionData(
        color: const Color(0xFF3B82F6), // Taban Maaş Mavi
        value: brutMaas,
        title: isTouched ? '₺${(brutMaas / 1000).toStringAsFixed(1)}k' : '%${(brutMaas / toplamKazanc * 100).round()}',
        radius: isTouched ? 44.0 : 36.0,
        titleStyle: GoogleFonts.inter(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }
    if (normalMesai > 0) {
      final isTouched = _touchedPieIndex == 1;
      sections.add(PieChartSectionData(
        color: const Color(0xFF10B981), // Normal Mesai Yeşil
        value: normalMesai,
        title: isTouched ? '₺${(normalMesai / 1000).toStringAsFixed(1)}k' : '%${(normalMesai / toplamKazanc * 100).round()}',
        radius: isTouched ? 44.0 : 36.0,
        titleStyle: GoogleFonts.inter(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }
    if (bayramMesai > 0) {
      final isTouched = _touchedPieIndex == 2;
      sections.add(PieChartSectionData(
        color: const Color(0xFFF59E0B), // Bayram Mesai Amber
        value: bayramMesai,
        title: isTouched ? '₺${(bayramMesai / 1000).toStringAsFixed(1)}k' : '%${(bayramMesai / toplamKazanc * 100).round()}',
        radius: isTouched ? 44.0 : 36.0,
        titleStyle: GoogleFonts.inter(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }
    if (kesinti > 0) {
      final isTouched = _touchedPieIndex == 3;
      sections.add(PieChartSectionData(
        color: const Color(0xFFEF4444), // Kesinti Kırmızı
        value: kesinti,
        title: isTouched ? '-₺${(kesinti / 1000).toStringAsFixed(1)}k' : 'Kesinti',
        radius: isTouched ? 44.0 : 36.0,
        titleStyle: GoogleFonts.inter(fontSize: isTouched ? 12 : 11, fontWeight: FontWeight.w800, color: Colors.white),
      ));
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Gelir ve Kazanç Dağılımı',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'fl_chart Analiz',
                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w700, color: const Color(0xFF64748B)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Donut Grafik
          SizedBox(
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (FlTouchEvent event, pieTouchResponse) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              pieTouchResponse == null ||
                              pieTouchResponse.touchedSection == null) {
                            _touchedPieIndex = -1;
                            return;
                          }
                          _touchedPieIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                        });
                      },
                    ),
                    borderData: FlBorderData(show: false),
                    sectionsSpace: 3,
                    centerSpaceRadius: 46,
                    sections: sections,
                  ),
                ),
                // Donut Ortasındaki Net Tutar Metni
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'TOPLAM NET',
                      style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.0),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isAmountHidden ? '••••••' : _formatRawCurrency(netMaas),
                      style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w900),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Açıklama Göstergeleri (Legend)
          _buildLegendRow(const Color(0xFF3B82F6), 'Taban Maaş', brutMaas, toplamKazanc),
          _buildLegendRow(const Color(0xFF10B981), 'Normal Mesai Kazancı', normalMesai, toplamKazanc),
          _buildLegendRow(const Color(0xFFF59E0B), 'Bayram / Tatil Mesaisi', bayramMesai, toplamKazanc),
          if (kesinti > 0)
            _buildLegendRow(const Color(0xFFEF4444), 'Ücretsiz İzin Kesintisi', -kesinti, toplamKazanc),

          const SizedBox(height: 16),

          // Öngörü ve Mesai Katkı Rozeti
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.insights_rounded, color: Color(0xFF10B981), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    mesaiOrani > 0
                        ? 'Bu ay toplam gelirinizin %${mesaiOrani.toStringAsFixed(1)} kadarı fazla mesai çalışmalarınızdan oluştu.'
                        : 'Bu ay yalnızca standart çalışma yapılmış, ek mesai bulunmamaktadır.',
                    style: GoogleFonts.inter(color: const Color(0xFF475569), fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildLegendRow(Color color, String label, double amount, double total) {
    if (amount.abs() == 0) return const SizedBox.shrink();
    final pct = total > 0 ? (amount.abs() / total * 100).toStringAsFixed(1) : '0';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(color: const Color(0xFF334155), fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '%$pct  ',
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          Text(
            _formatCurrency(amount),
            style: GoogleFonts.inter(
              color: amount < 0 ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  // ── 📅 TAB 2: Aylık Puantaj Matrisi (Vardiya & Gün Kırılımı) ──
  Widget _buildPuantajTab(BordroData bordro, JobDetails job, double normalMesai, double bayramMesai, double kesinti) {
    return Column(
      children: [
        // 2x2 Puantaj İstatistik Grid Kartları
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.work_outline_rounded,
                iconColor: const Color(0xFF3B82F6),
                title: 'Normal Çalışma',
                value: '${bordro.calismaGun} Gün',
                subtitle: 'Standart vardiya',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.access_time_filled_rounded,
                iconColor: const Color(0xFF10B981),
                title: 'Normal Mesai',
                value: '${bordro.normalMesaiGun} Gün',
                subtitle: 'Birim: ${_formatRawCurrency(job.normalMesaiRate)}',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildMetricCard(
                icon: Icons.celebration_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Bayram Mesaisi',
                value: '${bordro.bayramMesaiGun} Gün',
                subtitle: 'Birim: ${_formatRawCurrency(job.bayramMesaiRate)}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildMetricCard(
                icon: Icons.event_busy_rounded,
                iconColor: const Color(0xFFEF4444),
                title: 'Ücretsiz İzin',
                value: '${bordro.ucretsizIzinGun} Gün',
                subtitle: bordro.ucretsizIzinGun > 0 ? 'Kesinti: ${_formatRawCurrency(kesinti)}' : 'Eksik gün yok',
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Saha Doğrulama ve PDKS Bilgi Paneli
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.fingerprint_rounded, color: Color(0xFF0F172A), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'İSDEMİR PDKS Saha Doğrulaması',
                          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFF0F172A)),
                        ),
                        Text(
                          'Turnike ve kartlı geçiş verileriyle tam eşleşti.',
                          style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.verified_rounded, color: Color(0xFF10B981), size: 22),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              const SizedBox(height: 14),
              _buildPuantajDetailRow('Puantaj Dönemi', '${bordro.ay} ${bordro.yil} (1 - 30 ${bordro.ay})'),
              _buildPuantajDetailRow('Sicil No / Personel', 'ISD-947210 / ${widget.user.firstName} ${widget.user.lastName}'),
              _buildPuantajDetailRow('Çalışma Departmanı', widget.user.jobTitle),
              _buildPuantajDetailRow('Toplam Mesai Saati Karşılığı', '${(bordro.normalMesaiGun + bordro.bayramMesaiGun) * 8} Saat'),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildMetricCard({required IconData icon, required Color iconColor, required String title, required String value, required String subtitle}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10.5, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPuantajDetailRow(String title, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 12)),
          Text(val, style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  // ── 📋 TAB 3: Kalemler ve Detaylı Finansal Bordro Tablosu ──
  Widget _buildDetailsTab(BordroData bordro, JobDetails job, double brutMaas, double normalMesai, double bayramMesai, double kesinti, double netMaas) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Resmi Bordro Kalemleri',
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w800, color: const Color(0xFF1E293B)),
          ),
          const SizedBox(height: 16),

          // Kazançlar Başlığı
          _buildCategoryHeader('HAKEDİŞ VE GELİRLER', const Color(0xFF10B981)),
          _buildItemRow('Brüt Taban Maaş', _formatCurrency(brutMaas), 'Aylık sözleşme tutarı'),
          _buildItemRow('Normal Mesai (${bordro.normalMesaiGun} Gün)', _formatCurrency(normalMesai), '${_formatRawCurrency(job.normalMesaiRate)} / gün x 1.5 katsayı'),
          _buildItemRow('Bayram / Resmi Tatil (${bordro.bayramMesaiGun} Gün)', _formatCurrency(bayramMesai), '${_formatRawCurrency(job.bayramMesaiRate)} / gün x 2.0 katsayı'),

          const SizedBox(height: 16),

          // Kesintiler Başlığı
          _buildCategoryHeader('YASAL VE ŞİRKET KESİNTİLERİ', const Color(0xFFEF4444)),
          _buildItemRow(
            'Ücretsiz İzin Kesintisi (${bordro.ucretsizIzinGun} Gün)',
            kesinti > 0 ? '- ${_formatCurrency(kesinti)}' : '₺0,00',
            bordro.ucretsizIzinGun > 0 ? 'Dilekçeli devamsızlık kesintisi' : 'Kesinti bulunmuyor',
            isDeduction: kesinti > 0,
          ),
          _buildItemRow(
            'Gelir ve Damga Vergisi',
            'Muaf (₺0,00)',
            'Asgari ücret muafiyeti uygulanmıştır',
          ),

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE2E8F0)),
          const SizedBox(height: 16),

          // Net Özet
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'NET ÖDENEN TUTAR',
                    style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 13, fontWeight: FontWeight.w900),
                  ),
                  Text(
                    'Banka hesabına aktarılan',
                    style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 11),
                  ),
                ],
              ),
              Text(
                _formatCurrency(netMaas),
                style: GoogleFonts.inter(color: const Color(0xFF0F172A), fontSize: 18, fontWeight: FontWeight.w900),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 350.ms);
  }

  Widget _buildCategoryHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
      child: Row(
        children: [
          Container(width: 4, height: 14, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 8),
          Text(
            title,
            style: GoogleFonts.inter(color: color, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }

  Widget _buildItemRow(String title, String amount, String note, {bool isDeduction = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
                Text(note, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11)),
              ],
            ),
          ),
          Text(
            amount,
            style: GoogleFonts.inter(
              color: isDeduction ? const Color(0xFFEF4444) : const Color(0xFF0F172A),
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  // ── 📄 PDF İndir & Paylaş Buton Kartı ──
  Widget _buildPdfActionCard(BordroData bordro, double brut, double mesai, double kesinti, double net) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: _isGeneratingPdf ? null : () => _generateAndSharePDF(bordro, brut, mesai, kesinti, net),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFDC2626).withValues(alpha: 0.5),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Center(
                    child: _isGeneratingPdf
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                          )
                        : const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 24),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'MAAŞ DEKONTUNU İNDİR & PAYLAŞ',
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w900, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Resmi antetli, dijital imzalı A4 PDF formatı',
                        style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white70, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
