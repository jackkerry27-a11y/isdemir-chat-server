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
import 'package:http/http.dart' as http;

import '../utils/radio_sound_effects.dart';
import '../utils/pdf_font_helper.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/industrial_animations.dart';
import '../widgets/glass_widgets.dart';
import '../widgets/vip_gate.dart';
import '../models/user_model.dart';

class GemilerScreen extends StatefulWidget {
  final UserModel? user;
  const GemilerScreen({super.key, this.user});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> with SingleTickerProviderStateMixin {
  late AnimationController _blinkController;
  String _currentUserName = 'İsdemir Saha Operatörü';
  String _selectedFilter = 'Gemi Başlama Alındı';
  int _activeTabIndex = 0; // 0: Rıhtım & Operasyonlar, 1: Liman Analitik & Rapor
  bool _soundEnabled = true;
  int _touchedBarIndex = -1;
  bool _isCheckingVip = true;
  bool _isVip = false;

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
    _verifyVipAccess();
  }

  Future<void> _verifyVipAccess() async {
    if (widget.user?.isVip == true) {
      _isVip = true;
      _isCheckingVip = false;
      if (mounted) setState(() {});
    }

    final isVip = await VipGate.checkVipStatus(user: widget.user);
    if (mounted) {
      setState(() {
        _isVip = isVip;
        _isCheckingVip = false;
      });
    }
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

  bool _isSyncing = false;

  Future<void> _syncLiveMyShipTracking() async {
    if (_isSyncing) return;
    _playSound('squelch');
    setState(() {
      _isSyncing = true;
      _selectedFilter = 'Gemi Başlama Alındı';
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF161A22),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          duration: const Duration(seconds: 2),
          content: Row(
            children: const [
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
              ),
              SizedBox(width: 12),
              Text('Canlı liman radar verileri güncelleniyor...', style: TextStyle(color: Colors.white, fontSize: 13)),
            ],
          ),
        ),
      );
    }

    try {
      final res = await http
          .get(Uri.parse('https://isdemir-chat-server.onrender.com/api/ships/live'))
          .timeout(const Duration(seconds: 12));
      _playSound('roger');
      if (mounted && res.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF161A22),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            duration: const Duration(seconds: 2),
            content: Row(
              children: const [
                Icon(Icons.check_circle_rounded, color: Color(0xFF10B981), size: 18),
                SizedBox(width: 10),
                Text('Rıhtım 1-5 canlı gemileri başarıyla güncellendi.', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ],
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Sync hata: $e');
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  Color _getStatusColor(String durum) {
    switch (durum) {
      case 'Demir Sahasında (Bekliyor)':
      case 'Demirde Bekliyor':
      case 'Demirde':
        return const Color(0xFFF59E0B); // Amber / Gold for Anchorage
      case 'Gemi Başlama Alındı':
        return const Color(0xFF10B981); // Emerald Green
      case 'Gemi Bitişte':
        return const Color(0xFFF59E0B); // Amber Orange
      case 'Gemi Bitti':
        return const Color(0xFF3B82F6); // High-voltage Blue
      case 'Limandan Ayrılıyor':
        return const Color(0xFFEF4444); // Radiant Red (Departing)
      case 'Limana Giriş Yapıyor':
      case 'Limana Giriş Yaptı':
        return const Color(0xFF06B6D4); // Cyan (Approaching/Entering)
      case 'Limandan Ayrıldı':
        return const Color(0xFF94A3B8); // Muted Slate Gray
      default:
        return const Color(0xFF10B981);
    }
  }

  String _getStatusLabel(String durum) {
    switch (durum) {
      case 'Demir Sahasında (Bekliyor)':
      case 'Demirde Bekliyor':
      case 'Demirde':
        return 'Demirde';
      case 'Gemi Başlama Alındı':
        return 'Başladı';
      case 'Gemi Bitişte':
        return 'Bitişte';
      case 'Gemi Bitti':
        return 'Bitti';
      case 'Limandan Ayrılıyor':
        return 'Ayrılıyor';
      case 'Limana Giriş Yapıyor':
      case 'Limana Giriş Yaptı':
        return 'Giriş Yaptı';
      case 'Limandan Ayrıldı':
        return 'Ayrıldı';
      default:
        return durum;
    }
  }



  // --- YÜK CİNSİ GÜNCELLEME MODALI ---
  void _showEditYukCinsiDialog(String docId, String gemiAdi, String currentYukCinsi) {
    _playSound('squelch');
    HapticFeedback.selectionClick();

    final List<String> quickOptions = [
      'Bobin',
      'Slap',
      'Rulo Sac',
      'Kömür',
      'Cüruf',
      'Hurda',
      'Medkok',
      'Kütük',
      'Levha',
      'Pelet',
      'Cevher',
      'Genel Kargo',
      'Dökme Yük',
      'Paket Sac',
      'Liman Hizmeti',
    ];

    String selectedYuk = currentYukCinsi;
    final TextEditingController customYukController = TextEditingController(
      text: quickOptions.contains(currentYukCinsi) ? '' : currentYukCinsi,
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF13171F),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: const Color(0xFF14B8A6).withValues(alpha: 0.3)),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF14B8A6).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.inventory_2_rounded, color: Color(0xFF14B8A6), size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Yük Cinsini Güncelle',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          gemiAdi,
                          style: const TextStyle(color: Colors.white54, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hızlı Seçim Rozetleri',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: quickOptions.map((opt) {
                        final isSelected = selectedYuk == opt && customYukController.text.trim().isEmpty;
                        return ChoiceChip(
                          label: Text(opt),
                          selected: isSelected,
                          selectedColor: const Color(0xFF14B8A6),
                          backgroundColor: Colors.white.withValues(alpha: 0.05),
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.black : Colors.white70,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 11,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                            side: BorderSide(
                              color: isSelected ? const Color(0xFF14B8A6) : Colors.white12,
                            ),
                          ),
                          onSelected: (val) {
                            if (val) {
                              setDialogState(() {
                                selectedYuk = opt;
                                customYukController.clear();
                              });
                            }
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Veya Özel Yük Cinsi Yazın',
                      style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: customYukController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Örn: Demir Filizi, Boru, Pik...',
                        hintStyle: const TextStyle(color: Colors.white30, fontSize: 13),
                        filled: true,
                        fillColor: Colors.white.withValues(alpha: 0.05),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Colors.white24),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: const BorderSide(color: Color(0xFF14B8A6), width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      ),
                      onChanged: (text) {
                        setDialogState(() {
                          if (text.trim().isNotEmpty) {
                            selectedYuk = text.trim();
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Vazgeç', style: TextStyle(color: Colors.white54)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF14B8A6),
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final finalYuk = customYukController.text.trim().isNotEmpty
                        ? customYukController.text.trim()
                        : selectedYuk;

                    Navigator.pop(ctx);

                    try {
                      await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
                        'yukCinsi': finalYuk,
                        'guncellemeZamani': FieldValue.serverTimestamp(),
                      });
                      _playSound('tail');
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: const Color(0xFF14B8A6),
                            content: Text(
                              '$gemiAdi yük cinsi "$finalYuk" olarak güncellendi.',
                              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                            ),
                          ),
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Güncelleme hatası: $e')),
                        );
                      }
                    }
                  },
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // --- RIHTIM / KONUM GÜNCELLEME MODALI ---
  void _showEditRihtimDialog(
    String docId,
    String gemiAdi,
    String currentRihtim,
    String currentDurum,
  ) {
    _playSound('squelch');
    HapticFeedback.mediumImpact();

    final berths = [
      {'no': '1', 'name': '1. Rıhtım (Dış Uzun İskele)', 'icon': Icons.dock_rounded, 'color': const Color(0xFF10B981)},
      {'no': '2', 'name': '2. Rıhtım (İç Kuzey Rıhtımı)', 'icon': Icons.dock_rounded, 'color': const Color(0xFF10B981)},
      {'no': '3', 'name': '3. Rıhtım (İç Parmak İskele)', 'icon': Icons.dock_rounded, 'color': const Color(0xFF10B981)},
      {'no': '4', 'name': '4. Rıhtım (Güneybatı Rıhtımı)', 'icon': Icons.dock_rounded, 'color': const Color(0xFF10B981)},
      {'no': '5', 'name': '5. Rıhtım (Güneydoğu Rıhtımı)', 'icon': Icons.dock_rounded, 'color': const Color(0xFF10B981)},
      {'no': 'Demir', 'name': 'Demir Sahası (Açıkta Bekleme)', 'icon': Icons.anchor_rounded, 'color': const Color(0xFFF59E0B)},
      {'no': 'Ayrıldı', 'name': 'Limandan Ayrıldı (Boşalt)', 'icon': Icons.directions_boat_rounded, 'color': const Color(0xFFEF4444)},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161A22),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'RIHTIM / KONUM GÜNCELLE',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          gemiAdi,
                          style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              const Text(
                'Geminin güncel konumunu seçin (Anında güncellenir):',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: berths.length,
                  separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                  itemBuilder: (c, i) {
                    final b = berths[i];
                    final isSelected = currentRihtim == b['no'];
                    final color = b['color'] as Color;
                    final bNo = b['no'] as String;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: color.withValues(alpha: 0.2),
                        child: Icon(b['icon'] as IconData, color: color, size: 16),
                      ),
                      title: Text(
                        b['name'] as String,
                        style: TextStyle(
                          color: isSelected ? color : Colors.white,
                          fontSize: 13.5,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      trailing: isSelected
                          ? Icon(Icons.check_circle_rounded, color: color, size: 20)
                          : const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 14),
                      onTap: () async {
                        Navigator.pop(ctx);
                        HapticFeedback.heavyImpact();
                        _playSound('roger');

                        final messenger = ScaffoldMessenger.of(context);

                        try {
                          String newDurum = 'Gemi Başlama Alındı';
                          String newRihtim = bNo;
                          if (bNo == 'Demir') {
                            newDurum = 'Demir Sahasında (Bekliyor)';
                            newRihtim = 'Demir';
                          } else if (bNo == 'Ayrıldı') {
                            newDurum = 'Limandan Ayrıldı';
                            newRihtim = currentRihtim;
                          }

                          await FirebaseFirestore.instance.collection('gemiler').doc(docId).update({
                            'rihtimNo': newRihtim,
                            'durum': newDurum,
                            'guncellemeZamani': FieldValue.serverTimestamp(),
                            'guncelleyenKisi': _currentUserName,
                          });

                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(
                                backgroundColor: const Color(0xFF10B981),
                                content: Text(
                                  '$gemiAdi -> ${b['name']} olarak güncellendi.',
                                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            messenger.showSnackBar(
                              SnackBar(content: Text('Konum güncelleme hatası: $e')),
                            );
                          }
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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

    final pdfTheme = await PdfFontHelper.getTheme();
    final pdf = pw.Document(theme: pdfTheme);
    String safeTr(String? text) => PdfFontHelper.sanitize(text);

    String cleanOp(dynamic op) {
      if (op == null) return '—';
      final s = op.toString();
      if (s.toLowerCase().contains('myship')) {
        return 'Liman Otomasyonu';
      }
      return s;
    }

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
                        safeTr('İSDEMİR A.Ş. — LİMAN İŞLETME MÜDÜRLÜĞÜ'),
                        style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        safeTr('RIHTIM 1-5 GEMİ VE YÜKLEME/TAHLİYE VARDİYA PUANTAJ RAPORU'),
                        style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(safeTr('DOKÜMAN: İSD-LMN-VRD-2026/09'), style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                      pw.Text(safeTr('TARİH: $dateStr'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
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
                    pw.Text(safeTr('Raporu Düzenleyen: $_currentUserName'), style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    pw.Text(safeTr('Aktif Operasyon: ${allDocs.where((d) => d['durum'] != 'Limandan Ayrıldı').length} Gemi'), style: const pw.TextStyle(fontSize: 10)),
                    pw.Text(safeTr('Toplam Kayıt: ${allDocs.length} Gemi'), style: const pw.TextStyle(fontSize: 10)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // 3. Rıhtım 1-5 Durum Çizelgesi
              pw.Text(safeTr('1. RIHTIM 1-5 CANLI YANAŞMA VE KAPASİTE TABLOSU'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('Rıhtım No'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('Gemi Adı'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('Yük Cinsi'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('Operasyonel Durum'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('Sorumlu Operatör'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  for (int r = 1; r <= 5; r++) ...[
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr('$r. Rıhtım (R-$r)'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(
                          padding: const pw.EdgeInsets.all(6),
                          child: pw.Text(
                            safeTr(berthMap[r]?['gemiAdi'] ?? 'BOŞ RIHTIM'),
                            style: pw.TextStyle(
                              fontSize: 9,
                              fontWeight: berthMap[r] != null ? pw.FontWeight.bold : pw.FontWeight.normal,
                              color: berthMap[r] != null ? PdfColors.black : PdfColors.grey600,
                            ),
                          ),
                        ),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr(berthMap[r]?['yukCinsi'] ?? '—'), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr(berthMap[r]?['durum'] ?? 'Yanaşmaya Uygun'), style: const pw.TextStyle(fontSize: 9))),
                        pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(safeTr(cleanOp(berthMap[r]?['guncelleyenKisi'])), style: const pw.TextStyle(fontSize: 9))),
                      ],
                    ),
                  ],
                ],
              ),
              pw.SizedBox(height: 18),

              // 4. Tüm Gemi Operasyonları Detay Dökümü
              pw.Text(safeTr('2. TÜM GEMİ OPERASYONLARI HAREKET LİSTESİ'), style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.SizedBox(height: 6),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.8),
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr('Gemi'), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr('Rıhtım'), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr('Yük'), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr('Durum'), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr('İşlem Yapan'), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  for (var doc in allDocs) ...[
                    pw.TableRow(
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr(doc['gemiAdi'] ?? ''), style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr(doc['rihtimNo'] == 'Demir' ? 'Demir Sahası' : 'R-${doc['rihtimNo'] ?? ''}'), style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr(doc['yukCinsi'] ?? ''), style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr(doc['durum'] ?? ''), style: const pw.TextStyle(fontSize: 8.5))),
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(safeTr(cleanOp(doc['guncelleyenKisi'])), style: const pw.TextStyle(fontSize: 8.5))),
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
                      pw.Text(safeTr('Nöbetçi Rıhtım / Saha Amiri'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 140, height: 0.8, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(safeTr('İmza / Tarih'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: [
                      pw.Text(safeTr('Liman İşletme Başmühendisi / Müdürü'), style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 35),
                      pw.Container(width: 160, height: 0.8, color: PdfColors.black),
                      pw.SizedBox(height: 2),
                      pw.Text(safeTr('Onay / Kaşe'), style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
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



  @override
  Widget build(BuildContext context) {
    if (_isCheckingVip && !_isVip) {
      return const Scaffold(
        backgroundColor: Color(0xFF0C0E12),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFFF59E0B)),
        ),
      );
    }

    if (!_isVip) {
      return VipRestrictedView(
        user: widget.user,
        onAuthorized: () {
          setState(() {
            _isVip = true;
          });
        },
      );
    }

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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'İSDEMİR LİMANI',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.1,
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
                      Flexible(
                        child: Text(
                          'CANLI LİMAN RADARI (TRIDM)',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF10B981),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Canlı Verileri Senkronize Et
          IconButton(
            tooltip: 'Canlı Verileri Senkronize Et',
            icon: _isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : const Icon(Icons.sync_rounded, color: Color(0xFF10B981), size: 22),
            onPressed: _syncLiveMyShipTracking,
          ),
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
                _selectedFilter = 'Gemi Başlama Alındı';
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
          final bittiCount = allShips.where((d) => d['durum'] == 'Gemi Bitti').length;
          final ayrildiCount = allShips.where((d) => d['durum'] == 'Limandan Ayrıldı').length;
          final demirCount = allShips.where((d) {
            final data = d.data() as Map<String, dynamic>;
            final r = data['rihtimNo']?.toString();
            final st = data['durum']?.toString() ?? '';
            return r == 'Demir' || st.contains('Demir') || data['isAnchorage'] == true;
          }).length;

          // Dolu Rıhtım Sayısı (Yalnızca R-1 ile R-5 arası ve ayrılmamış)
          final Set<String> occupiedBerths = {};
          for (var doc in allShips) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['durum'] != 'Limandan Ayrıldı') {
              final r = data['rihtimNo']?.toString();
              if (r != null && ['1', '2', '3', '4', '5'].contains(r)) {
                occupiedBerths.add(r);
              }
            }
          }
          final int emptyBerthCount = 5 - occupiedBerths.length;

          // Filtrelenmiş liste (Başladı, Bitişte, Bitti, Ayrıldı veya Demirde)
          final List<QueryDocumentSnapshot> filteredShips;
          if (_selectedFilter == 'Demir Sahasında (Bekliyor)') {
            filteredShips = allShips.where((d) {
              final data = d.data() as Map<String, dynamic>;
              final r = data['rihtimNo']?.toString();
              final st = data['durum']?.toString() ?? '';
              return r == 'Demir' || st.contains('Demir') || data['isAnchorage'] == true;
            }).toList();
          } else {
            filteredShips = allShips.where((d) => d['durum'] == _selectedFilter).toList();
          }

          // Sıralama: Rıhtım numarasına göre (R-1, R-2 ... R-5) veya mesafeye göre
          filteredShips.sort((a, b) {
            final dataA = a.data() as Map<String, dynamic>;
            final dataB = b.data() as Map<String, dynamic>;

            final rA = int.tryParse(dataA['rihtimNo']?.toString() ?? '99') ?? 99;
            final rB = int.tryParse(dataB['rihtimNo']?.toString() ?? '99') ?? 99;
            if (rA != rB) return rA.compareTo(rB);

            final distA = (dataA['mesafeDemirKm'] is num) ? (dataA['mesafeDemirKm'] as num).toDouble() : 99.0;
            final distB = (dataB['mesafeDemirKm'] is num) ? (dataB['mesafeDemirKm'] as num).toDouble() : 99.0;
            return distA.compareTo(distB);
          });

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
                        bittiCount: bittiCount,
                        ayrildiCount: ayrildiCount,
                        emptyBerthCount: emptyBerthCount,
                        demirCount: demirCount,
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
    );
  }

  // =========================================================================
  // 1. SEKME: RIHTIM VE GEMİ OPERASYONLARI
  // =========================================================================
  Widget _buildOperationsTab({
    required List<QueryDocumentSnapshot> allShips,
    required List<QueryDocumentSnapshot> filteredShips,
    required int baslamaCount,
    required int bittiCount,
    required int ayrildiCount,
    required int emptyBerthCount,
    required int demirCount,
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
                    icon: HugeIcons.strokeRoundedCargoShip,
                    filterKey: 'Gemi Başlama Alındı',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildFlipStatTile(
                    label: 'Demirde',
                    count: demirCount,
                    color: const Color(0xFFF59E0B),
                    icon: HugeIcons.strokeRoundedAnchor,
                    filterKey: 'Demir Sahasında (Bekliyor)',
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
                    filterKey: 'Limandan Ayrıldı',
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
              final gemi = shipData['gemiAdi'] ?? 'Gemi';
              final rNo = shipData['rihtimNo'] ?? '?';
              final durum = shipData['durum'] ?? 'Bağlı';
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF14181F),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF10B981), size: 18),
                      const SizedBox(width: 10),
                      Text('$gemi — R-$rNo ($durum)', style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              );
            },
            onEmptyRihtimTap: (rihtimNo) {
              _playSound('squelch');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  backgroundColor: const Color(0xFF14181F),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  duration: const Duration(seconds: 2),
                  content: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded, color: Color(0xFF38BDF8), size: 18),
                      const SizedBox(width: 10),
                      Text('$rihtimNo. Rıhtım şu anda boş (AIS Radar Takipte)', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
              );
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
                    title: '🟢 Başladı',
                    count: baslamaCount,
                    filterKey: 'Gemi Başlama Alındı',
                    accentColor: const Color(0xFF10B981),
                  ),
                  const SizedBox(width: 8),
                  _buildFilterPill(
                    title: '⚓ Demirde',
                    count: demirCount,
                    filterKey: 'Demir Sahasında (Bekliyor)',
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
          _selectedFilter = filterKey;
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

  // --- ULTRA-MODERN GEMİ TELEMETRİ KARTI ---
  Widget _buildModernShipCard(String docId, Map<String, dynamic> data, int index) {
    final durum = data['durum'] ?? 'Bilinmiyor';
    final isAnchored = data['rihtimNo'] == 'Demir' ||
        (data['durum']?.toString().contains('Demir') ?? false) ||
        data['isAnchorage'] == true;
    final color = _getStatusColor(durum);
    final statusLabel = _getStatusLabel(durum);
    final rNo = int.tryParse(data['rihtimNo']?.toString() ?? '1') ?? 1;

    final berthNames = [
      'Dış İskele',
      'Kuzey Rıhtım',
      'Parmak İskele',
      'Güneybatı',
      'Güneydoğu'
    ];
    final String berthSub;
    if (isAnchored) {
      final distStr = data['mesafeDemirKm'] != null ? ' (${data['mesafeDemirKm']} km)' : '';
      berthSub = 'Demir Sahası // 36.7615°N, 36.1361°E$distStr';
    } else {
      berthSub = (rNo >= 1 && rNo <= 5) ? '$rNo. Rıhtım // ${berthNames[rNo - 1]}' : '';
    }

    final yukCinsi = data['yukCinsi'] ?? 'Genel Kargo';
    Color yukColor = const Color(0xFFF59E0B);
    if (yukCinsi == 'Slap') yukColor = const Color(0xFFFB923C);
    if (yukCinsi == 'Bobin') yukColor = const Color(0xFF14B8A6);
    if (yukCinsi == 'Cüruf') yukColor = const Color(0xFFA855F7);
    if (yukCinsi == 'Kömür') yukColor = const Color(0xFF94A3B8);
    if (yukCinsi == 'Medkok') yukColor = const Color(0xFF84CC16);
    if (yukCinsi == 'Hurda') yukColor = const Color(0xFFEC4899);
    if (isAnchored) yukColor = const Color(0xFFF59E0B);

    final speedNum = (data['speedKnots'] is num)
        ? (data['speedKnots'] as num).toDouble()
        : double.tryParse(data['speedKnots']?.toString() ?? '0.0') ?? 0.0;

    final isMovingAway = durum == 'Limandan Ayrılıyor' ||
        (speedNum > 1.2 && durum != 'Limandan Ayrıldı' && !isAnchored);
    final isEntering = durum == 'Limana Giriş Yapıyor' || durum == 'Limana Giriş Yaptı';

    final gemiAdi = (data['gemiAdi'] ?? 'Gemi').toString().toUpperCase();
    final mmsi = (data['mmsi'] ?? '').toString();

    // Tonaj Bilgisi (Firestore alanından veya özellik kütüphanesinden)
    String tonajStr = (data['tonaj'] ?? data['dwt'] ?? '').toString().trim();
    if (tonajStr.isEmpty || tonajStr == 'null') {
      if (mmsi == '249489000' || gemiAdi.contains('MARAN HORIZON')) {
        tonajStr = '208,000 DWT';
      } else if (mmsi == '255727000' || gemiAdi.contains('NANJING CONFIDENCE')) {
        tonajStr = '31,603 DWT';
      } else if (mmsi == '370126000' || gemiAdi.contains('WHITE IVY')) {
        tonajStr = '16,383 DWT';
      } else if (mmsi == '352002310' || gemiAdi.contains('LADY MERAL')) {
        tonajStr = '31,603 DWT';
      } else if (mmsi == '271002044' || gemiAdi.contains('HACI MEHMET')) {
        tonajStr = '3,270 DWT';
      } else if (mmsi == '271044600' || gemiAdi.contains('TAMREY S')) {
        tonajStr = '31,024 DWT';
      } else if (mmsi == '271002598' || gemiAdi.contains('ENKO HASLAMAN')) {
        tonajStr = '3,375 DWT';
      } else if (mmsi == '271049621' || gemiAdi.contains('LIVA IMAMOGLU')) {
        tonajStr = '6,097 DWT';
      } else if (mmsi == '351381000' || gemiAdi.contains('SEVEN S')) {
        tonajStr = '11,200 DWT';
      } else if (mmsi == '271044425' || gemiAdi.contains('TAHSIN IMAMOGLU')) {
        tonajStr = '5,400 DWT';
      } else {
        tonajStr = 'Kargo Gemisi';
      }
    }

    // ETA (Tahmini Varış) Bilgisi
    String etaStr = (data['eta'] ?? '').toString().trim();
    if (etaStr.isEmpty || etaStr == 'null') {
      if (durum == 'Gemi Başlama Alındı' || durum == 'Gemi Bitişte') {
        etaStr = 'Rıhtımda Bağlı';
      } else if (durum == 'Limandan Ayrıldı') {
        etaStr = 'Limandan Ayrıldı';
      } else if (isAnchored) {
        if (gemiAdi.contains('LIVA')) {
          etaStr = '08.09 09:00';
        } else if (gemiAdi.contains('TAMREY')) {
          etaStr = '17.09 10:00';
        } else if (gemiAdi.contains('ENKO')) {
          etaStr = '05.09 09:00';
        } else {
          etaStr = 'Demirde Bekliyor';
        }
      } else {
        etaStr = 'Operasyon Planında';
      }
    }

    return StaggeredEntrance(
      index: index,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF111728), Color(0xFF0C101A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: color.withValues(alpha: 0.32),
            width: 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.45),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. ÜST BAŞLIK: DURUM LEDİ + GEMİ ADI + RIHTIM VE DURUM ROZETİ
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Yanıp Sönen Canlı Durum Ledi
                  AnimatedBuilder(
                    animation: _blinkController,
                    builder: (context, child) {
                      final isDeparted = durum == 'Limandan Ayrıldı';
                      final pulseVal = isDeparted ? 1.0 : (0.35 + _blinkController.value * 0.65);
                      return Container(
                        width: 11,
                        height: 11,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: color.withValues(alpha: pulseVal),
                          boxShadow: isDeparted
                              ? null
                              : [
                                  BoxShadow(
                                    color: color.withValues(alpha: _blinkController.value * 0.8),
                                    blurRadius: 9,
                                    spreadRadius: 2.5,
                                  ),
                                ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 10),

                  // Gemi Adı & Rıhtım Konumu
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['gemiAdi'] ?? 'Bilinmeyen Gemi',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (berthSub.isNotEmpty)
                          Text(
                            berthSub,
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.3,
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Rıhtım / Demir Rozeti (Dokunup Düzenlenebilir)
                  GestureDetector(
                    onTap: () => _showEditRihtimDialog(
                      docId,
                      data['gemiAdi'] ?? 'Gemi',
                      data['rihtimNo']?.toString() ?? (isAnchored ? 'Demir' : '1'),
                      durum,
                    ),
                    child: isAnchored
                        ? Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.anchor_rounded, size: 12, color: Color(0xFFF59E0B)),
                                const SizedBox(width: 4),
                                Text(
                                  'DEMİRDE',
                                  style: GoogleFonts.orbitron(
                                    color: const Color(0xFFF59E0B),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                              ),
                            ),
                            child: Text(
                              'R-${data['rihtimNo'] ?? '?'}',
                              style: GoogleFonts.orbitron(
                                color: const Color(0xFF38BDF8),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                  ),
                  const SizedBox(width: 6),

                  // Durum Rozeti
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withValues(alpha: 0.45)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                ],
              ),

              // Canlı AIS Telemetri Rozetleri (Hız, Rota, MMSI)
              if (data['speedKnots'] != null || data['mmsi'] != null) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            speedNum > 1.0 ? Icons.speed_rounded : Icons.anchor_rounded,
                            size: 12,
                            color: speedNum > 1.0
                                ? const Color(0xFFEF4444)
                                : const Color(0xFF10B981),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'AIS: ${data['speedKnots'] ?? '0.0'} kt',
                            style: TextStyle(
                              color: speedNum > 1.0 ? const Color(0xFFEF4444) : Colors.white70,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (data['heading'] != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.navigation_rounded, size: 11, color: Colors.white60),
                            const SizedBox(width: 4),
                            Text(
                              'ROTA: ${data['heading']}°',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (data['mmsi'] != null && data['mmsi'].toString().isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                        ),
                        child: Text(
                          'MMSI: ${data['mmsi']}',
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    // Tonaj Rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.scale_rounded, size: 11, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 4),
                          Text(
                            tonajStr,
                            style: const TextStyle(
                              color: Color(0xFF7DD3FC),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // ETA Rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.schedule_rounded, size: 11, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 4),
                          Text(
                            'ETA: $etaStr',
                            style: const TextStyle(
                              color: Color(0xFFFCD34D),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],

              // Kritik Hız ve Ayrılma / Giriş Uyarı Bannerları
              if (isMovingAway) ...[
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFFEF4444).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GEMİ LİMANDAN AYRILIYOR // HIZ: ${data['speedKnots'] ?? '?'} KT',
                          style: const TextStyle(
                            color: Color(0xFFEF4444),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (isEntering) ...[
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF06B6D4).withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: const Color(0xFF06B6D4).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.directions_boat_rounded, color: Color(0xFF06B6D4), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'GEMİ LİMANA GİRİŞ YAPIYOR // HIZ: ${data['speedKnots'] ?? '?'} KT',
                          style: const TextStyle(
                            color: Color(0xFF06B6D4),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              // 2. ORTA ALAN: LOTTİE GEMİ + 3 SÜTUNLU MİKRO BİLGİ BADGELERİ
              Row(
                children: [
                  // Lottie Gemi Çerçevesi
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFF090D15),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: color.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: color.withValues(alpha: 0.18),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: LottieCargoShipWidget(
                          width: 44,
                          height: 44,
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
                        // Rıhtım / Konum Bilgisi (Tıklanıp Düzenlenebilir)
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedAnchor,
                            iconColor: isAnchored ? const Color(0xFFF59E0B) : const Color(0xFF60A5FA),
                            label: isAnchored ? 'KONUM' : 'RIHTIM',
                            value: isAnchored ? 'Açıkta' : 'R-${data['rihtimNo'] ?? '?'}',
                            subtitle: isAnchored ? 'Demir Sahası' : ((rNo >= 1 && rNo <= 5) ? berthNames[rNo - 1] : ''),
                            isEditable: true,
                            onTap: () => _showEditRihtimDialog(
                              docId,
                              data['gemiAdi'] ?? 'Gemi',
                              data['rihtimNo']?.toString() ?? (isAnchored ? 'Demir' : '1'),
                              durum,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Yük Cinsi Bilgisi (Tıklanıp Düzenlenebilir)
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedPackage,
                            iconColor: yukColor,
                            label: 'YÜK',
                            value: yukCinsi,
                            isEditable: true,
                            onTap: () => _showEditYukCinsiDialog(
                              docId,
                              data['gemiAdi'] ?? 'Gemi',
                              yukCinsi,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),

                        // Operatör Bilgisi
                        Expanded(
                          child: _buildMicroBadge(
                            icon: HugeIcons.strokeRoundedUser,
                            iconColor: const Color(0xFF34D399),
                            label: 'OPERATÖR',
                            value: (data['guncelleyenKisi'] ?? 'İsdemir').toString().toLowerCase().contains('demir')
                                ? 'Radar'
                                : (data['guncelleyenKisi'] ?? 'İsdemir').toString().toLowerCase().contains('myship')
                                    ? 'Otomasyon'
                                    : (data['guncelleyenKisi'] ?? 'İsdemir').toString().split(' ').first,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // TONAJ & ETA BİLGİ ŞERİDİ
              Row(
                children: [
                  // TONAJ (DWT & GT)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF38BDF8).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.scale_rounded, color: Color(0xFF38BDF8), size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'GEMİ TONAJI',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  tonajStr,
                                  style: const TextStyle(
                                    color: Color(0xFFE2E8F0),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (data['grossTonaj'] != null && data['grossTonaj'].toString().isNotEmpty)
                                  Text(
                                    data['grossTonaj'].toString(),
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // TAHMİNİ VARIŞ (ETA)
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.18)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.schedule_rounded, color: Color(0xFFF59E0B), size: 15),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'TAHMİNİ VARIŞ (ETA)',
                                  style: TextStyle(
                                    color: Colors.white38,
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  etaStr,
                                  style: const TextStyle(
                                    color: Color(0xFFFCD34D),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                if (data['dest'] != null && data['dest'].toString().isNotEmpty)
                                  Text(
                                    'Hedef: ${data['dest']}',
                                    style: const TextStyle(
                                      color: Color(0xFFF59E0B),
                                      fontSize: 8.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 3. ALT BİLGİ ÇUBUĞU (Liman Vinci / Demir Sahası Bannerı + Radar + Silme)
              Row(
                children: [
                  if (isAnchored)
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF59E0B).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.25)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.anchor_rounded, color: Color(0xFFF59E0B), size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Açıkta Bekliyor // 36.7615°N, 36.1361°E ${data['mesafeDemirKm'] != null ? '(${data['mesafeDemirKm']} km)' : ''}',
                                style: const TextStyle(
                                  color: Color(0xFFFCD34D),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    Expanded(
                      child: IndustrialCraneWidget(
                        isOperating: durum == 'Gemi Başlama Alındı' || durum == 'Gemi Bitişte',
                        themeColor: color,
                        compact: true,
                      ),
                    ),
                  const SizedBox(width: 8),

                  // Otomatik Radar Bilgisi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                    decoration: BoxDecoration(
                      color: isAnchored
                          ? const Color(0xFFF59E0B).withValues(alpha: 0.08)
                          : const Color(0xFF10B981).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isAnchored
                            ? const Color(0xFFF59E0B).withValues(alpha: 0.3)
                            : const Color(0xFF10B981).withValues(alpha: 0.25),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.radar_rounded,
                          color: isAnchored ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                          size: 13,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          isAnchored ? 'Demir Radarı' : 'Radar Takip',
                          style: TextStyle(
                            color: isAnchored ? const Color(0xFFFCD34D) : const Color(0xFF6EE7B7),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 2),

                  // Sil Butonu
                  IconButton(
                    tooltip: 'Kaydı Sil',
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.white38, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    onPressed: () => _confirmDeleteShip(docId, data['gemiAdi'] ?? 'Gemi'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildMicroBadge({
    required List<List<dynamic>> icon,
    required Color iconColor,
    required String label,
    required String value,
    String? subtitle,
    VoidCallback? onTap,
    bool isEditable = false,
  }) {
    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: isEditable
            ? iconColor.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isEditable
              ? iconColor.withValues(alpha: 0.35)
              : Colors.white.withValues(alpha: 0.07),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(icon: icon, color: iconColor, size: 11),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isEditable ? iconColor : Colors.white.withValues(alpha: 0.45),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isEditable) ...[
                Icon(Icons.edit_rounded, color: iconColor.withValues(alpha: 0.75), size: 10),
              ],
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
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              subtitle,
              style: const TextStyle(
                color: Colors.white38,
                fontSize: 8,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(11),
          splashColor: iconColor.withValues(alpha: 0.2),
          highlightColor: iconColor.withValues(alpha: 0.1),
          child: badge,
        ),
      );
    }
    return badge;
  }
}