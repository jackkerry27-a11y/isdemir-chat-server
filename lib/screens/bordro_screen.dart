import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/user_model.dart';

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

  String _formatCurrency(double amount) {
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

  Future<void> _generateAndSharePDF(BordroData bordro, double brut, double mesai, double kesinti, double net) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');
    final dateStr = dateFormat.format(DateTime.now());

    String formatCurrencyForPdf(double amount) {
      return _formatCurrency(amount).replaceAll('₺', 'TL');
    }

    String normalizeTr(String text) {
      return text
          .replaceAll('ı', 'i')
          .replaceAll('İ', 'I')
          .replaceAll('ğ', 'g')
          .replaceAll('Ğ', 'G')
          .replaceAll('ü', 'u')
          .replaceAll('Ü', 'U')
          .replaceAll('ş', 's')
          .replaceAll('Ş', 'S')
          .replaceAll('ö', 'o')
          .replaceAll('Ö', 'O')
          .replaceAll('ç', 'c')
          .replaceAll('Ç', 'C');
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
      
      await Share.shareXFiles([XFile(file.path)], text: '${bordro.ay} ${bordro.yil} Maaş Dekontu');
    } catch (e) {
      debugPrint('PDF Hatasi: $e');
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
      backgroundColor: const Color(0xFFF4F6F8), // Açık gri arkaplan
      body: Stack(
        children: [
          // Kırmızı Header Arkaplanı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4338CA), // Koyu İsdemir kırmızısı
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                ),
              ),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                // Özel AppBar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Maaş Bordrosu',
                              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Kazancınızı detaylı olarak görüntüleyin.',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.receipt_long_rounded, color: Colors.white),
                          onPressed: () {},
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Ay Seçici (Horizontal Scroll)
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _bordrolar.length,
                    itemBuilder: (context, index) {
                      final b = _bordrolar[index];
                      final isSelected = _selectedIndex == index;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: GestureDetector(
                          onTap: () => setState(() => _selectedIndex = index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade300,
                                width: isSelected ? 1.5 : 1.0,
                              ),
                              boxShadow: isSelected
                                  ? [BoxShadow(color: const Color(0xFF4338CA).withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))]
                                  : [],
                            ),
                            child: Row(
                              children: [
                                if (isSelected) ...[
                                  const Icon(Icons.calendar_month_rounded, color: Color(0xFF4338CA), size: 16),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  '${b.ay} ${b.yil}',
                                  style: TextStyle(
                                    color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade600,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 16),

                // Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      children: [
                        // KART 1: Personel ve Şirket Bilgileri
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                            ],
                          ),
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              // Şirket Başlığı
                              Row(
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4338CA),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Icon(Icons.domain_rounded, color: Colors.white, size: 28),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'İSDEMİR A.Ş.',
                                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Color(0xFF1A202C)),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          'PERSONEL MAAŞ BORDROSU',
                                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey.shade500),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      '${bordro.ay.toUpperCase()} ${bordro.yil}',
                                      style: const TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.bold, fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                              
                              const SizedBox(height: 20),
                              
                              // Personel Bilgileri Listesi
                              _buildPersonelRow(Icons.person_outline, 'Ad Soyad', '${widget.user.firstName} ${widget.user.lastName}'),
                              _buildDottedDivider(),
                              _buildPersonelRow(Icons.admin_panel_settings_outlined, 'Ünvan', widget.user.jobTitle),
                              _buildDottedDivider(),
                              _buildPersonelRow(Icons.badge_outlined, 'Sicil No', 'ISD-947210'),
                              _buildDottedDivider(),
                              _buildPersonelRow(Icons.calendar_today_outlined, 'Çalışma Gün', '${bordro.calismaGun}'),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),

                        // KART 2: Taban Maaş
                        _buildDetailCard(
                          icon: Icons.account_balance_wallet_rounded,
                          iconColor: const Color(0xFF475569),
                          title: 'TABAN MAAŞ',
                          subtitle: 'Brüt Taban Maaş',
                          amount: brutMaas,
                          trailingIcon: Icons.keyboard_arrow_down_rounded,
                        ),

                        const SizedBox(height: 12),

                        // KART 3: Mesai Kazançları
                        _buildDetailCard(
                          icon: Icons.access_time_filled_rounded,
                          iconColor: const Color(0xFF2563EB),
                          title: 'MESAİ KAZANÇLARI',
                          subtitle: toplamMesaiKazanci > 0 ? 'Bu ay toplam mesai kazancı' : 'Bu ay mesai yapılmamıştır.',
                          amount: toplamMesaiKazanci > 0 ? toplamMesaiKazanci : null,
                          trailingIcon: toplamMesaiKazanci > 0 ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                        ),

                        const SizedBox(height: 12),

                        // KART 4: İzin Durumu
                        _buildDetailCard(
                          icon: Icons.event_busy_rounded,
                          iconColor: const Color(0xFF9333EA),
                          title: 'İZİN DURUMU',
                          subtitle: bordro.ucretsizIzinGun > 0 ? 'Kullanılan ücretsiz izin' : 'Bu ay ücretsiz izin kullanılmamıştır.',
                          amount: bordro.ucretsizIzinGun > 0 ? -ucretsizIzinKesintisi : null,
                          trailingIcon: bordro.ucretsizIzinGun > 0 ? Icons.keyboard_arrow_down_rounded : Icons.chevron_right_rounded,
                        ),

                        // PDF Olarak İndir Butonu
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () => _generateAndSharePDF(bordro, brutMaas, toplamMesaiKazanci, ucretsizIzinKesintisi, netMaas),
                            icon: const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 20),
                            label: const Text('MAAŞ DEKONTUNU İNDİR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF4338CA),
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              elevation: 4,
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
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

  Widget _buildPersonelRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF4338CA).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF4338CA), size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(label, style: const TextStyle(color: Color(0xFF64748B), fontSize: 13)),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDottedDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 54.0),
      child: CustomPaint(
        size: const Size(double.infinity, 1),
        painter: DottedLinePainter(),
      ),
    );
  }

  Widget _buildDetailCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    double? amount,
    required IconData trailingIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: iconColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(color: iconColor, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 0.3),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 11),
                ),
              ],
            ),
          ),
          if (amount != null) ...[
            Text(
              _formatCurrency(amount),
              style: const TextStyle(color: Color(0xFF1E293B), fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(width: 12),
          ],
          Icon(trailingIcon, color: const Color(0xFF94A3B8), size: 20),
        ],
      ),
    );
  }
}

class DottedLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;
      
    const double dashWidth = 4, dashSpace = 4;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
