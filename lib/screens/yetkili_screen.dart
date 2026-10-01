import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/user_model.dart';
import '../utils/shift_logic.dart';
import '../utils/push_service.dart';

class YetkiliScreen extends StatefulWidget {
  final UserModel currentUser;

  const YetkiliScreen({super.key, required this.currentUser});

  @override
  State<YetkiliScreen> createState() => _YetkiliScreenState();
}

class _YetkiliScreenState extends State<YetkiliScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _personeller = [];
  List<Map<String, dynamic>> _duyurular = [];
  List<Map<String, dynamic>> _swapRequests = [];
  String _searchQuery = '';
  String _filterType = 'all'; // 'all', 'onayli', 'yetkili', 'vip', 'bekleyen', 'v10', 'eski'
  bool _isExportingExcel = false;
  bool _showAnalyticsCharts = true;

  // Duyuru Formu Controller'ları
  final _duyuruTitleCtrl = TextEditingController();
  final _duyuruContentCtrl = TextEditingController();
  bool _duyuruIsAlert = false;
  bool _isSendingDuyuru = false;

  // Command Center Color System
  static const Color obsidianBg = Color(0xFF080B11);
  static const Color cardSurface = Color(0xFF0F141E);
  static const Color cardSurfaceElevated = Color(0xFF161C2B);
  static const Color cardBorder = Color(0xFF222B3D);
  static const Color laserCrimson = Color(0xFFEF4444);
  static const Color cyberCyan = Color(0xFF06B6D4);
  static const Color neonEmerald = Color(0xFF10B981);
  static const Color amberGold = Color(0xFFF59E0B);
  static const Color electricViolet = Color(0xFF8B5CF6);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _duyuruTitleCtrl.dispose();
    _duyuruContentCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final personelSnapshot = await FirebaseFirestore.instance
          .collection('personeller')
          .orderBy('durum', descending: true)
          .get();

      List<Map<String, dynamic>> personellerList = [];
      for (var doc in personelSnapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;

        try {
          final logsSnapshot = await doc.reference.collection('giris_cikis_log').get();
          data['giris_cikis_log'] = logsSnapshot.docs.map((d) => d.data()).toList();

          final hakedisSnapshot = await doc.reference.collection('hakedis').get();
          data['hakedis'] = hakedisSnapshot.docs.map((d) => d.data()).toList();
        } catch (_) {
          data['giris_cikis_log'] = [];
          data['hakedis'] = [];
        }

        personellerList.add(data);
      }

      List<Map<String, dynamic>> duyurularList = [];
      try {
        final duyurularSnapshot = await FirebaseFirestore.instance
            .collection('duyurular')
            .orderBy('tarih', descending: true)
            .get();

        duyurularList = duyurularSnapshot.docs.map((doc) {
          var data = doc.data();
          data['id'] = doc.id;
          if (data['tarih'] is Timestamp) {
            data['tarih'] = (data['tarih'] as Timestamp).toDate().toIso8601String();
          }
          return data;
        }).toList();
      } catch (de) {
        debugPrint('Duyurular çekme uyarısı: $de');
      }

      List<Map<String, dynamic>> swapList = [];
      try {
        final swapSnapshot = await FirebaseFirestore.instance
            .collection('vardiya_takas_talepleri')
            .orderBy('tarih', descending: true)
            .get();
        for (var doc in swapSnapshot.docs) {
          var data = doc.data();
          data['id'] = doc.id;
          if (data['tarih'] is Timestamp) {
            data['tarih_str'] = DateFormat('dd.MM.yyyy HH:mm').format((data['tarih'] as Timestamp).toDate());
          }
          swapList.add(data);
        }
      } catch (e) {
        debugPrint('Vardiya takas verisi çekme hatası: $e');
      }

      if (mounted) {
        setState(() {
          _personeller = personellerList;
          _duyurular = duyurularList;
          _swapRequests = swapList;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          if (e.toString().contains('permission-denied')) {
            _error = 'Firestore Güvenlik Kuralları Erişimi Engelliyor.\nKurallar güncellendi, lütfen "Tekrar Dene" butonuna dokunarak yeniden bağlanın.';
          } else {
            _error = 'Veri çekilirken hata oluştu: $e';
          }
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'durum': newStatus});
      if (!mounted) return;

      _showExecutiveSnackBar(
        title: newStatus == 'onaylandi' ? 'Personel Hesabı Onaylandı' : 'Personel Başvurusu Reddedildi',
        message: newStatus == 'onaylandi' ? 'Kullanıcı artık tam yetkiyle sisteme erişebilir.' : 'İşlem kayıtlara işlendi.',
        color: newStatus == 'onaylandi' ? neonEmerald : laserCrimson,
        icon: newStatus == 'onaylandi' ? Icons.check_circle_rounded : Icons.cancel_rounded,
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'İşlem Hatası', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _toggleYetkiliStatus(String id, bool currentStatus) async {
    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({
        'is_yetkili': newStatus,
        'yetkili': newStatus,
      });
      if (!mounted) return;

      _showExecutiveSnackBar(
        title: newStatus ? 'Yönetici Yetkisi Verildi' : 'Yönetici Yetkisi Kaldırıldı',
        message: newStatus ? 'Personel artık operasyon komuta merkezini yönetebilir.' : 'Standart personel seviyesine çekildi.',
        color: newStatus ? laserCrimson : const Color(0xFF64748B),
        icon: Icons.shield_rounded,
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
    }
  }

  Future<void> _toggleVipStatus(String id, bool currentStatus, {String? name, String? cihazId}) async {
    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'is_vip': newStatus});

      if (newStatus && cihazId != null && cihazId.isNotEmpty) {
        try {
          await PushService.sendPushNotification(
            title: '👑 VIP Yetkiniz Tanımlandı!',
            content: 'Tebrikler ${name ?? ''}! Operasyon merkezi tarafından hesabınıza VIP yetkisi tanımlandı.',
            targetCihazId: cihazId,
          );
        } catch (_) {}
      }

      if (!mounted) return;
      _showExecutiveSnackBar(
        title: newStatus ? '👑 VIP Statüsü Verildi' : 'VIP Statüsü Kaldırıldı',
        message: newStatus ? '${name ?? 'Personel'} için anlık push bildirimi iletildi.' : 'VIP erişimi kapatıldı.',
        color: newStatus ? amberGold : const Color(0xFF64748B),
        icon: Icons.star_rounded,
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
    }
  }

  void _showExecutiveSnackBar({required String title, required String message, required Color color, required IconData icon}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: cardSurfaceElevated,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: color.withValues(alpha: 0.5))),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  Text(message, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 📑 EXCEL / PUANTAJ RAPORU İNDİRME ──
  Future<void> _exportPersonnelToExcel() async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);
    HapticFeedback.mediumImpact();

    try {
      final buffer = StringBuffer();
      buffer.writeln('Sıra;Ad Soyad;Meslek;Vardiya Postası;Sistem Durumu;Saha Durumu;Taban Maaş (TL);Normal Mesai (Gün);Bayram Mesaisi (Gün);Toplam Hakediş (TL);Son Turnike Hareketi;VIP Yetkisi;Yönetici Yetkisi');

      int index = 1;
      for (var p in _personeller) {
        final name = (p['ad_soyad'] ?? 'İsimsiz').toString().replaceAll(';', ',');
        final meslek = (p['meslek'] ?? 'Belirtilmedi').toString().replaceAll(';', ',');
        final vardiya = (p['vardiya'] ?? 'Belirtilmedi').toString().replaceAll(';', ',');
        final durum = (p['durum'] == 'onaylandi' ? 'Onaylı' : 'Bekliyor');
        final sahaDurum = (p['son_hareket_tipi'] == 'is_giris' ? 'Sahada / Fabrikada' : 'Dışarıda');

        final JobDetails jobDetails = UserModel.jobRates[meslek] ?? UserModel.jobRates['Liman İşçisi A']!;
        final hakedisler = p['hakedis'] as List<dynamic>? ?? [];
        final hakedis = hakedisler.isNotEmpty ? hakedisler.first : null;
        final int normalMesaiGun = (hakedis?['normal_mesai_gun'] as num?)?.toInt() ?? 0;
        final int bayramMesaiGun = (hakedis?['bayram_mesai_gun'] as num?)?.toInt() ?? 0;
        final double normalMesaiKazanci = normalMesaiGun * jobDetails.normalMesaiRate;
        final double bayramMesaiKazanci = bayramMesaiGun * jobDetails.bayramMesaiRate;
        final double totalMesai = normalMesaiKazanci + bayramMesaiKazanci;
        final double netHakedis = (hakedis?['guncel_hakedis'] as num?)?.toDouble() ?? (jobDetails.baseSalary + totalMesai);

        String sonHareket = 'Kayıt Yok';
        if (p['son_hareket_tarihi'] != null && p['son_hareket_saati'] != null) {
          sonHareket = '${p['son_hareket_tarihi']} ${p['son_hareket_saati']}';
        }

        final isVip = p['is_vip'] == true ? 'VIP' : 'Standart';
        final isYetkili = (p['is_yetkili'] == true || p['yetkili'] == true) ? 'Yönetici' : 'Personel';

        buffer.writeln('$index;$name;$meslek;$vardiya;$durum;$sahaDurum;${jobDetails.baseSalary.toInt()};$normalMesaiGun;$bayramMesaiGun;${netHakedis.toInt()};$sonHareket;$isVip;$isYetkili');
        index++;
      }

      final tempDir = await getTemporaryDirectory();
      final nowStr = DateFormat('yyyy_MM_dd_HHmm').format(DateTime.now());
      final filePath = '${tempDir.path}/isdemir_personel_puantaj_$nowStr.csv';
      final file = File(filePath);

      final utf8Bom = [0xEF, 0xBB, 0xBF];
      await file.writeAsBytes([...utf8Bom, ...utf8.encode(buffer.toString())]);

      setState(() => _isExportingExcel = false);
      if (!mounted) return;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: neonEmerald, width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: neonEmerald.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_chart_rounded, color: neonEmerald, size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Excel Puantaj Raporu Hazır',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '${_personeller.length} personelin tüm puantaj, maaş, vardiya ve turnike verileri Excel uyumlu (.csv) dosyası olarak dışa aktarıldı.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await OpenFilex.open(filePath);
                      },
                      icon: const Icon(Icons.visibility_rounded, size: 16),
                      label: const Text('Dosyayı Aç'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await SharePlus.instance.share(
                          ShareParams(
                            files: [XFile(filePath)],
                            text: 'İSDEMİR Personel Puantaj ve Maaş Raporu ($nowStr)',
                          ),
                        );
                      },
                      icon: const Icon(Icons.share_rounded, size: 16),
                      label: const Text('Paylaş / Gönder'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonEmerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      setState(() => _isExportingExcel = false);
      if (mounted) {
        _showExecutiveSnackBar(title: 'Rapor Hatası', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _sendDuyuru() async {
    final title = _duyuruTitleCtrl.text.trim();
    final content = _duyuruContentCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      _showExecutiveSnackBar(title: 'Eksik Bilgi', message: 'Lütfen duyuru başlığını ve mesajını giriniz.', color: amberGold, icon: Icons.warning_amber_rounded);
      return;
    }

    setState(() => _isSendingDuyuru = true);

    try {
      await FirebaseFirestore.instance.collection('duyurular').add({
        'baslik': title,
        'icerik': content,
        'tarih': FieldValue.serverTimestamp(),
        'is_alert': _duyuruIsAlert,
        'yayinlayan': widget.currentUser.fullName,
      });

      await PushService.sendPushNotification(
        title: _duyuruIsAlert ? '🚨 [ACİL AMİR DUYURUSU] $title' : '📢 [YETKİLİ DUYURU] $title',
        content: content,
        isVipOnly: false,
        additionalData: {'type': 'yetkili_duyuru', 'is_alert': _duyuruIsAlert},
      );

      _duyuruTitleCtrl.clear();
      _duyuruContentCtrl.clear();
      if (mounted) {
        setState(() {
          _duyuruIsAlert = false;
          _isSendingDuyuru = false;
        });

        _showExecutiveSnackBar(
          title: 'Duyuru Yayınlandı',
          message: 'Tüm personele OneSignal anlık bildirimi iletildi.',
          color: neonEmerald,
          icon: Icons.campaign_rounded,
        );
      }

      _fetchData();
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingDuyuru = false);
        _showExecutiveSnackBar(title: 'Gönderim Hatası', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _deleteDuyuru(String id) async {
    try {
      await FirebaseFirestore.instance.collection('duyurular').doc(id).delete();
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Duyuru Kaldırıldı', message: 'Duyuru panodan silindi.', color: const Color(0xFF64748B), icon: Icons.delete_outline_rounded);
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 0).format(amount);
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(" ");
    String initials = "";
    int numWords = names.length > 2 ? 2 : names.length;
    for (int i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials.isEmpty ? "P" : initials;
  }

  Map<String, String> _getVardiyaInfo(String? vardiyaStr) {
    VardiyaGunu gun = VardiyaGunu.sali;
    String name = 'Salı Vardiyası (Salı Tatil)';

    if (vardiyaStr == 'carsamba') {
      gun = VardiyaGunu.carsamba;
      name = 'Çarşamba Vardiyası (Çarşamba Tatil)';
    } else if (vardiyaStr == 'cuma') {
      gun = VardiyaGunu.cuma;
      name = 'Cuma Vardiyası (Cuma Tatil)';
    } else if (vardiyaStr == 'cumartesi') {
      gun = VardiyaGunu.cumartesi;
      name = 'Cumartesi Vardiyası (Cumartesi Tatil)';
    }

    final todayShift = ShiftLogic.getShiftType(DateTime.now(), vardiyaGunu: gun);
    String liveStatus = ShiftLogic.getShiftName(todayShift);
    String time = ShiftLogic.getShiftTime(todayShift);

    return {
      'vardiyaAdi': name,
      'canliDurum': '$liveStatus ($time)',
    };
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _personeller.where((p) => p['durum'] == 'onay_bekliyor').length;
    final pendingSwapCount = _swapRequests.where((s) => s['durum'] == 'onay_bekliyor').length;
    final totalPersonnel = _personeller.length;

    double totalHakedisPool = 0;
    for (var p in _personeller) {
      final String meslek = p['meslek'] ?? 'Liman İşçisi A';
      final JobDetails jobDetails = UserModel.jobRates[meslek] ?? UserModel.jobRates['Liman İşçisi A']!;
      final hakedisler = p['hakedis'] as List<dynamic>? ?? [];
      final hakedis = hakedisler.isNotEmpty ? hakedisler.first : null;
      final double hakedisAmount = hakedis != null ? (hakedis['guncel_hakedis'] as num).toDouble() : jobDetails.baseSalary;
      totalHakedisPool += hakedisAmount;
    }

    return Scaffold(
      backgroundColor: obsidianBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Modern Executive Frosted App Bar ──
            _buildExecutiveHeader(),

            // ── Modern Floating Segmented Tabs ──
            _buildModernSegmentedTabs(pendingCount, pendingSwapCount),

            // ── Content Area ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: laserCrimson))
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.error_outline_rounded, color: laserCrimson, size: 48),
                                const SizedBox(height: 12),
                                Text(_error, textAlign: TextAlign.center, style: GoogleFonts.inter(color: Colors.white70)),
                                const SizedBox(height: 16),
                                ElevatedButton(onPressed: _fetchData, child: const Text('Tekrar Dene')),
                              ],
                            ),
                          ),
                        )
                      : TabBarView(
                          controller: _tabController,
                          children: [
                            _buildPersonnelAndSalaryTab(totalPersonnel, pendingCount, totalHakedisPool),
                            _buildPendingApprovalsTab(),
                            _buildSwapRequestsTab(),
                            _buildAnnouncementsTab(),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  // ── High-Tech Executive Command Header ──
  Widget _buildExecutiveHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      decoration: const BoxDecoration(
        color: cardSurface,
        border: Border(bottom: BorderSide(color: cardBorder, width: 0.8)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Glass Back Button
              InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: cardSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
                ),
              ),

              const SizedBox(width: 12),

              // Title and Status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: neonEmerald,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: neonEmerald, blurRadius: 6, spreadRadius: 1),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'OPERASYON KOMUTA KONSOLU',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            letterSpacing: 1.2,
                            fontWeight: FontWeight.w900,
                            color: laserCrimson,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Yetkili: ${widget.currentUser.fullName}',
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Action Buttons
              Row(
                children: [
                  // Excel Button
                  InkWell(
                    onTap: _exportPersonnelToExcel,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                      decoration: BoxDecoration(
                        color: neonEmerald.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: neonEmerald.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          _isExportingExcel
                              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: neonEmerald))
                              : const Icon(Icons.table_chart_rounded, color: neonEmerald, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            'Puantaj',
                            style: GoogleFonts.inter(color: neonEmerald, fontSize: 11.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Refresh Button
                  InkWell(
                    onTap: _fetchData,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: cardSurfaceElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: cardBorder),
                      ),
                      child: const Icon(Icons.refresh_rounded, color: Color(0xFF94A3B8), size: 18),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Modern Floating Segmented Tabs ──
  Widget _buildModernSegmentedTabs(int pendingCount, int pendingSwapCount) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cardBorder, width: 0.8),
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(
          color: laserCrimson,
          borderRadius: BorderRadius.circular(10),
          boxShadow: [
            BoxShadow(color: laserCrimson.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 2)),
          ],
        ),
        labelColor: Colors.white,
        unselectedLabelColor: const Color(0xFF8E9EB5),
        labelPadding: EdgeInsets.zero,
        tabs: [
          _buildSegmentTabItem(icon: Icons.people_alt_rounded, text: 'Personel'),
          _buildSegmentTabItem(
            icon: Icons.pending_actions_rounded,
            text: 'Onaylar',
            badgeCount: pendingCount,
            badgeColor: amberGold,
          ),
          _buildSegmentTabItem(
            icon: Icons.swap_calls_rounded,
            text: 'Takas',
            badgeCount: pendingSwapCount,
            badgeColor: cyberCyan,
          ),
          _buildSegmentTabItem(icon: Icons.campaign_rounded, text: 'Duyuru'),
        ],
      ),
    );
  }

  Widget _buildSegmentTabItem({required IconData icon, required String text, int badgeCount = 0, Color badgeColor = laserCrimson}) {
    return Tab(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 15),
          const SizedBox(width: 4),
          Text(text, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold)),
          if (badgeCount > 0) ...[
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: badgeColor,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '$badgeCount',
                style: GoogleFonts.inter(color: Colors.black, fontSize: 9.5, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── SEKME 1: PERSONEL & MAAŞ & MESAİ ──
  Widget _buildPersonnelAndSalaryTab(int totalPersonnel, int pendingCount, double totalHakedisPool) {
    final int v10Count = _personeller.where((p) {
      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      return ver.contains('10') || numVer >= 10;
    }).length;
    final int eskiCount = totalPersonnel - v10Count;
    final double updatePercent = totalPersonnel > 0 ? (v10Count / totalPersonnel) : 0.0;

    final filteredList = _personeller.where((p) {
      final name = (p['ad_soyad'] ?? '').toString().toLowerCase();
      final meslek = (p['meslek'] ?? '').toString().toLowerCase();
      final q = _searchQuery.toLowerCase();
      final matchesQuery = q.isEmpty || name.contains(q) || meslek.contains(q);

      if (!matchesQuery) return false;

      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      final isV10 = ver.contains('10') || numVer >= 10;

      if (_filterType == 'onayli') {
        return p['durum'] == 'onaylandi';
      } else if (_filterType == 'yetkili') {
        return p['is_yetkili'] == true || p['yetkili'] == true;
      } else if (_filterType == 'vip') {
        return p['is_vip'] == true;
      } else if (_filterType == 'bekleyen') {
        return p['durum'] == 'onay_bekliyor';
      } else if (_filterType == 'v10') {
        return isV10;
      } else if (_filterType == 'eski') {
        return !isV10;
      }
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: laserCrimson,
      backgroundColor: cardSurface,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 30),
        children: [
          // ── KPI Telemetri Deck ──
          Row(
            children: [
              Expanded(
                child: _buildModernKpiCard(
                  title: 'TOPLAM PERSONEL',
                  value: '$totalPersonnel Kişi',
                  subtitle: '$pendingCount Başvuru Bekliyor',
                  icon: Icons.groups_rounded,
                  accentColor: cyberCyan,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildModernKpiCard(
                  title: 'HAKEDİŞ HAVUZU',
                  value: _formatCurrency(totalHakedisPool),
                  subtitle: 'Aylık Toplam Bütçe',
                  icon: Icons.payments_rounded,
                  accentColor: neonEmerald,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // ── v10.0 Dağıtım İlerleme Banner'ı ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  neonEmerald.withValues(alpha: 0.15),
                  cardSurface,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: neonEmerald.withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: neonEmerald, size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'v10.0 Sürüm Yayılımı',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: neonEmerald,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '%${(updatePercent * 100).toInt()} Güncellendi',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.black),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: updatePercent,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF1E2430),
                    valueColor: const AlwaysStoppedAnimation<Color>(neonEmerald),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🟢 Güncelleyen: $v10Count Kişi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: neonEmerald)),
                    Text('🟠 Eski Sürüm: $eskiCount Kişi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: amberGold)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Dashboard / Grafikler Aç-Kapa ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'CANLI OPERASYON TELEMETRİSİ',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5),
              ),
              InkWell(
                onTap: () => setState(() => _showAnalyticsCharts = !_showAnalyticsCharts),
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      Icon(_showAnalyticsCharts ? Icons.pie_chart_rounded : Icons.pie_chart_outline_rounded, size: 14, color: cyberCyan),
                      const SizedBox(width: 4),
                      Text(
                        _showAnalyticsCharts ? 'Grafikleri Gizle' : 'Grafikleri Göster',
                        style: GoogleFonts.inter(color: cyberCyan, fontSize: 11.5, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (_showAnalyticsCharts) ...[
            const SizedBox(height: 8),
            _buildAnalyticsSection(),
          ],

          const SizedBox(height: 14),

          // ── Arama Çubuğu ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: const InputDecoration(
                      hintText: 'Personel adı, unvan veya görev ara...',
                      hintStyle: TextStyle(color: Color(0xFF64748B), fontSize: 13),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(() => _searchQuery = ''),
                    child: const Icon(Icons.clear_rounded, color: Color(0xFF94A3B8), size: 18),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ── Filtre Çipleri ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildModernFilterChip('all', 'Tümü (${_personeller.length})'),
                const SizedBox(width: 8),
                _buildModernFilterChip('v10', '🚀 v10.0 Güncel ($v10Count)'),
                const SizedBox(width: 8),
                _buildModernFilterChip('eski', '⚠️ Eski Sürüm ($eskiCount)'),
                const SizedBox(width: 8),
                _buildModernFilterChip('onayli', 'Onaylılar (${_personeller.where((p) => p['durum'] == 'onaylandi').length})'),
                const SizedBox(width: 8),
                _buildModernFilterChip('yetkili', '🛡️ Yetkililer (${_personeller.where((p) => p['is_yetkili'] == true || p['yetkili'] == true).length})'),
                const SizedBox(width: 8),
                _buildModernFilterChip('vip', '👑 VIP (${_personeller.where((p) => p['is_vip'] == true).length})'),
                const SizedBox(width: 8),
                _buildModernFilterChip('bekleyen', '⏳ Bekleyenler ($pendingCount)'),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── Personel Kartları ──
          if (filteredList.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('Kriterlere uygun personel bulunamadı.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
              ),
            )
          else
            ...filteredList.map((p) => _buildExecutivePersonnelCard(p)),
        ],
      ),
    );
  }

  Widget _buildModernKpiCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF8E9EB5), fontWeight: FontWeight.w800, letterSpacing: 0.5)),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: accentColor, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: accentColor, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildModernFilterChip(String type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? laserCrimson : cardSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? laserCrimson : cardBorder),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  // ── Executive Personnel Card ──
  Widget _buildExecutivePersonnelCard(Map<String, dynamic> p) {
    final String name = p['ad_soyad'] ?? 'İsimsiz Personel';
    final String meslek = p['meslek'] ?? 'Liman İşçisi A';
    final String durum = p['durum'] ?? 'onay_bekliyor';
    final bool isApproved = durum == 'onaylandi';
    final bool isYetkili = p['is_yetkili'] == true || p['yetkili'] == true;
    final bool isVip = p['is_vip'] == true;
    final String appVer = p['app_version']?.toString() ?? 'v8.0';
    final bool isV10Updated = appVer.contains('10') || ((p['app_version_num'] as num?)?.toInt() ?? 0) >= 10;
    final String updateTime = p['guncelleme_tarihi_str'] ?? '';

    final JobDetails jobDetails = UserModel.jobRates[meslek] ?? UserModel.jobRates['Liman İşçisi A']!;
    final hakedisler = p['hakedis'] as List<dynamic>? ?? [];
    final hakedis = hakedisler.isNotEmpty ? hakedisler.first : null;

    final int normalMesaiGun = (hakedis?['normal_mesai_gun'] as num?)?.toInt() ?? 0;
    final int bayramMesaiGun = (hakedis?['bayram_mesai_gun'] as num?)?.toInt() ?? 0;
    final double normalMesaiKazanci = normalMesaiGun * jobDetails.normalMesaiRate;
    final double bayramMesaiKazanci = bayramMesaiGun * jobDetails.bayramMesaiRate;
    final double totalMesai = normalMesaiKazanci + bayramMesaiKazanci;
    final double netHakedis = (hakedis?['guncel_hakedis'] as num?)?.toDouble() ?? (jobDetails.baseSalary + totalMesai);

    final vardiyaInfo = _getVardiyaInfo(p['vardiya']);
    final logs = p['giris_cikis_log'] as List<dynamic>? ?? [];
    final int girisSayisi = logs.where((l) => (l['islem_tipi'] ?? '').toString().toLowerCase().contains('giris')).length;
    final int totalHareket = logs.length;
    final String sonGirisTarih = p['son_hareket_tarihi'] ?? (logs.isNotEmpty ? logs.last['tarih'] : 'Kayıt Yok');
    final String sonGirisSaat = p['son_hareket_saati'] ?? (logs.isNotEmpty ? logs.last['saat'] : '');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isYetkili ? laserCrimson.withValues(alpha: 0.7) : (isApproved ? cardBorder : amberGold.withValues(alpha: 0.5)),
          width: isYetkili ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: isYetkili ? laserCrimson.withValues(alpha: 0.2) : cardSurfaceElevated,
                child: Text(
                  _getInitials(name),
                  style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
              if (isYetkili)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: laserCrimson, shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, size: 9, color: Colors.white),
                  ),
                ),
            ],
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.white),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isYetkili)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: laserCrimson.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: laserCrimson),
                  ),
                  child: Text('YETKİLİ', style: GoogleFonts.inter(fontSize: 8.5, fontWeight: FontWeight.w900, color: laserCrimson)),
                ),
              // VIP Quick Button
              GestureDetector(
                onTap: () => _toggleVipStatus(p['id'], isVip, name: name, cihazId: p['cihaz_id']),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isVip ? amberGold.withValues(alpha: 0.25) : cardSurfaceElevated,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: isVip ? amberGold : cardBorder, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: isVip ? amberGold : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        isVip ? 'VIP' : '+VIP',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.w900, color: isVip ? amberGold : const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Text(meslek, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isApproved ? neonEmerald : amberGold).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isApproved ? 'Onaylı' : 'Bekliyor',
                      style: GoogleFonts.inter(
                        fontSize: 9.5,
                        color: isApproved ? neonEmerald : amberGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isV10Updated ? neonEmerald : amberGold).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isV10Updated ? (updateTime.isNotEmpty ? 'v10.0 ($updateTime)' : 'v10.0') : 'Eski',
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: isV10Updated ? neonEmerald : amberGold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Salary quick bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: cardSurfaceElevated,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Hakediş:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF8E9EB5))),
                    Text(
                      _formatCurrency(netHakedis),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: neonEmerald),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: const BoxDecoration(
                color: Color(0xFF0B0E16),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Maaş & Mesai Detay Bloğu
                  Text('💰 MAAŞ VE MESAİ ANALİZİ', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        _buildDataRow('Taban Maaş:', _formatCurrency(jobDetails.baseSalary), isBold: true),
                        const Divider(height: 12, color: cardBorder),
                        _buildDataRow('Normal Mesai ($normalMesaiGun Gün):', '+ ${_formatCurrency(normalMesaiKazanci)}', valueColor: amberGold),
                        const SizedBox(height: 4),
                        _buildDataRow('Bayram Mesaisi ($bayramMesaiGun Gün):', '+ ${_formatCurrency(bayramMesaiKazanci)}', valueColor: electricViolet),
                        const Divider(height: 12, color: cardBorder),
                        _buildDataRow('Toplam Kazanç:', _formatCurrency(netHakedis), valueColor: neonEmerald, isBold: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 2. Vardiya Düzeni
                  Text('🔄 VARDİYA DÜZENİ', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: cyberCyan, size: 15),
                            const SizedBox(width: 8),
                            Expanded(child: Text(vardiyaInfo['vardiyaAdi']!, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.work_history_rounded, color: neonEmerald, size: 15),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Bugün: ${vardiyaInfo['canliDurum']!}', style: GoogleFonts.inter(fontSize: 11.5, color: neonEmerald, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // 3. Giriş-Çıkış Sayaç & GPS
                  Text('📊 UYGULAMA KULLANIM & GİRİŞ-ÇIKIŞ', style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cardSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Uygulama Giriş Sayısı:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1))),
                            Text('$girisSayisi Giriş ($totalHareket Hareket)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: neonEmerald)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Son Hareket:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1))),
                            Text('$sonGirisTarih $sonGirisSaat', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                        if (logs.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showUserLogHistory(name, logs),
                              icon: const Icon(Icons.history_rounded, size: 14),
                              label: const Text('Tüm Oturum Geçmişini Gör', style: TextStyle(fontSize: 11)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: cyberCyan,
                                side: const BorderSide(color: cardBorder),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 4. Aksiyon Butonları
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _toggleYetkiliStatus(p['id'], isYetkili),
                        icon: Icon(isYetkili ? Icons.security_rounded : Icons.shield_outlined, size: 14),
                        label: Text(isYetkili ? 'Yetkiyi Kaldır' : '🛡️ Yetkili Yap', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isYetkili ? cardSurfaceElevated : laserCrimson,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),
                      if (!isApproved) ...[
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(p['id'], 'onaylandi'),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Hesabı Onayla', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: neonEmerald,
                            foregroundColor: Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(p['id'], 'reddedildi'),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: const Text('Reddet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: laserCrimson.withValues(alpha: 0.15),
                            foregroundColor: laserCrimson,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataRow(String label, String value, {Color valueColor = Colors.white, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8))),
        Text(
          value,
          style: GoogleFonts.inter(fontSize: 12, fontWeight: isBold ? FontWeight.bold : FontWeight.w600, color: valueColor),
        ),
      ],
    );
  }

  // ── SEKME 2: BEKLEYEN ONAYLAR ──
  Widget _buildPendingApprovalsTab() {
    final pendingList = _personeller.where((p) => p['durum'] == 'onay_bekliyor').toList();

    if (pendingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: neonEmerald, size: 52),
            const SizedBox(height: 14),
            Text('Onay Bekleyen Personel Yok', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Tüm personel kayıtları sonuçlandırılmıştır.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: pendingList.length,
      itemBuilder: (context, index) {
        final p = pendingList[index];
        final String name = p['ad_soyad'] ?? 'İsimsiz Personel';
        final String meslek = p['meslek'] ?? 'Liman İşçisi A';
        final String tc = p['tc'] ?? '—';
        final String tel = p['telefon'] ?? '—';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: amberGold.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: amberGold.withValues(alpha: 0.15),
                    child: Text(_getInitials(name), style: GoogleFonts.inter(color: amberGold, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(meslek, style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: amberGold.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Bekliyor', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: amberGold)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(Icons.badge_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('T.C: $tc', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1))),
                  const SizedBox(width: 16),
                  const Icon(Icons.phone_rounded, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 6),
                  Text('Tel: $tel', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1))),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _updateStatus(p['id'], 'onaylandi'),
                      icon: const Icon(Icons.check_circle_rounded, size: 16),
                      label: const Text('Başvuruyu Onayla'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: neonEmerald,
                        foregroundColor: Colors.black,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _updateStatus(p['id'], 'reddedildi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: laserCrimson.withValues(alpha: 0.15),
                      foregroundColor: laserCrimson,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text('Reddet'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ── SEKME 3: VARDİYA TAKAS MASASI ──
  Widget _buildSwapRequestsTab() {
    final pendingSwaps = _swapRequests.where((s) => s['durum'] == 'onay_bekliyor').toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: laserCrimson,
      backgroundColor: cardSurface,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: cardBorder),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: amberGold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.swap_calls_rounded, color: amberGold, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Vardiya Takas Masası',
                        style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${pendingSwaps.length} adet onay bekleyen takas var',
                        style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: _showManualShiftAssignDialog,
                  icon: const Icon(Icons.edit_calendar_rounded, size: 14),
                  label: const Text('Manuel Ata', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: cyberCyan,
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAKAS TALEPLERİ (${_swapRequests.length})',
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5),
              ),
              if (_swapRequests.isEmpty)
                TextButton.icon(
                  onPressed: _createSampleSwapRequest,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text('Örnek Talep Oluştur', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: cyberCyan),
                ),
            ],
          ),

          const SizedBox(height: 10),

          if (_swapRequests.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: cardBorder),
              ),
              child: Column(
                children: [
                  const Icon(Icons.swap_horizontal_circle_outlined, size: 48, color: Color(0xFF64748B)),
                  const SizedBox(height: 12),
                  Text('Henüz Vardiya Takas Talebi Yok', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'Personeller vardiya değişimi talep ettiğinde veya "Manuel Ata" butonunu kullandığınızda burada görünecektir.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B)),
                  ),
                ],
              ),
            )
          else
            ..._swapRequests.map((s) => _buildSwapRequestCard(s)),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> swap) {
    final String durum = swap['durum'] ?? 'onay_bekliyor';
    final bool isPending = durum == 'onay_bekliyor';
    final bool isApproved = durum == 'onaylandi';

    final Color statusColor = isPending ? amberGold : (isApproved ? neonEmerald : laserCrimson);
    final String statusLabel = isPending ? '⏳ Bekliyor' : (isApproved ? '✅ Onaylandı' : '❌ Reddedildi');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isPending ? amberGold.withValues(alpha: 0.5) : cardBorder,
          width: isPending ? 1.2 : 0.8,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(statusLabel, style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor)),
              ),
              Text(swap['tarih_str'] ?? '', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Talep Eden:', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                      Text(swap['talep_eden_ad'] ?? 'Personel 1', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(swap['mevcut_vardiya'] ?? 'Salı', style: GoogleFonts.inter(fontSize: 10, color: cyberCyan, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt_rounded, color: amberGold, size: 20),
              ),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardSurfaceElevated,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hedef Personel:', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8))),
                      Text(swap['hedef_personel_ad'] ?? 'Personel 2', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 4),
                      Text(swap['hedef_vardiya'] ?? 'Cuma', style: GoogleFonts.inter(fontSize: 10, color: neonEmerald, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if ((swap['aciklama'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Not: "${swap['aciklama']}"', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontStyle: FontStyle.italic)),
          ],
          if (isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveSwapRequest(swap),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Onayla & Vardiyaları Değiştir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: neonEmerald,
                      foregroundColor: Colors.black,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _rejectSwapRequest(swap),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: laserCrimson.withValues(alpha: 0.15),
                    foregroundColor: laserCrimson,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Reddet'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _approveSwapRequest(Map<String, dynamic> swap) async {
    try {
      final swapId = swap['id'];
      final u1Id = swap['talep_eden_id'];
      final u2Id = swap['hedef_personel_id'];
      final v1 = swap['mevcut_vardiya'];
      final v2 = swap['hedef_vardiya'];

      if (u1Id != null) {
        await FirebaseFirestore.instance.collection('personeller').doc(u1Id).update({'vardiya': v2});
      }
      if (u2Id != null) {
        await FirebaseFirestore.instance.collection('personeller').doc(u2Id).update({'vardiya': v1});
      }

      await FirebaseFirestore.instance.collection('vardiya_takas_talepleri').doc(swapId).update({'durum': 'onaylandi'});

      if (swap['talep_eden_cihaz_id'] != null) {
        await PushService.sendPushNotification(
          title: '✅ Vardiya Takasınız Onaylandı!',
          content: '${swap['hedef_personel_ad']} ile vardiya takasınız onaylandı. Yeni vardiyanız: $v2',
          targetCihazId: swap['talep_eden_cihaz_id'],
        );
      }
      if (swap['hedef_personel_cihaz_id'] != null) {
        await PushService.sendPushNotification(
          title: '✅ Vardiya Takasınız Onaylandı!',
          content: '${swap['talep_eden_ad']} ile vardiya takasınız onaylandı. Yeni vardiyanız: $v1',
          targetCihazId: swap['hedef_personel_cihaz_id'],
        );
      }

      if (!mounted) return;
      _showExecutiveSnackBar(
        title: 'Vardiya Takası Onaylandı',
        message: 'Her iki personelin vardiyası güncellendi ve bildirim iletildi.',
        color: neonEmerald,
        icon: Icons.check_circle_rounded,
      );
      _fetchData();
    } catch (e) {
      if (mounted) {
        _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
      }
    }
  }

  Future<void> _rejectSwapRequest(Map<String, dynamic> swap) async {
    try {
      final swapId = swap['id'];
      await FirebaseFirestore.instance.collection('vardiya_takas_talepleri').doc(swapId).update({'durum': 'reddedildi'});

      if (swap['talep_eden_cihaz_id'] != null) {
        await PushService.sendPushNotification(
          title: 'Vardiya Takas Talebi Reddedildi',
          content: 'Vardiya takas talebiniz operasyon yetkilisi tarafından onaylanmadı.',
          targetCihazId: swap['talep_eden_cihaz_id'],
        );
      }

      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Takas Reddedildi', message: 'Talep iptal edildi.', color: laserCrimson, icon: Icons.cancel_rounded);
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
    }
  }

  void _showManualShiftAssignDialog() {
    String? selectedPersonelId;
    String selectedShift = 'Salı Grubu';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              backgroundColor: cardSurface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18), side: const BorderSide(color: cardBorder)),
              title: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: cyberCyan, size: 20),
                  const SizedBox(width: 8),
                  Text('Vardiya Ata / Değiştir', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personel Seç:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: cardSurfaceElevated,
                        isExpanded: true,
                        value: selectedPersonelId,
                        hint: const Text('Personel seçiniz', style: TextStyle(color: Color(0xFF64748B), fontSize: 12.5)),
                        items: _personeller.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['id'].toString(),
                            child: Text(
                              '${p['ad_soyad'] ?? 'İsimsiz'} (${p['vardiya'] ?? 'Yok'})',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedPersonelId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text('Yeni Vardiya:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: cardSurfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: cardBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: cardSurfaceElevated,
                        isExpanded: true,
                        value: selectedShift,
                        items: const [
                          DropdownMenuItem(value: 'Salı Grubu', child: Text('1. Posta (Salı Grubu)', style: TextStyle(color: Colors.white, fontSize: 12.5))),
                          DropdownMenuItem(value: 'Çarşamba Grubu', child: Text('2. Posta (Çarşamba Grubu)', style: TextStyle(color: Colors.white, fontSize: 12.5))),
                          DropdownMenuItem(value: 'Cuma Grubu', child: Text('3. Posta (Cuma Grubu)', style: TextStyle(color: Colors.white, fontSize: 12.5))),
                          DropdownMenuItem(value: 'Cumartesi Grubu', child: Text('4. Posta (Cumartesi Grubu)', style: TextStyle(color: Colors.white, fontSize: 12.5))),
                        ],
                        onChanged: (val) {
                          if (val != null) setDialogState(() => selectedShift = val);
                        },
                      ),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('İptal', style: TextStyle(color: Color(0xFF94A3B8))),
                ),
                ElevatedButton(
                  onPressed: selectedPersonelId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await FirebaseFirestore.instance
                                .collection('personeller')
                                .doc(selectedPersonelId)
                                .update({'vardiya': selectedShift});
                            if (mounted) {
                              _showExecutiveSnackBar(
                                title: 'Vardiya Güncellendi',
                                message: 'Seçilen personele $selectedShift atandı.',
                                color: neonEmerald,
                                icon: Icons.check_circle_rounded,
                              );
                              _fetchData();
                            }
                          } catch (e) {
                            if (mounted) {
                              _showExecutiveSnackBar(title: 'Hata', message: '$e', color: laserCrimson, icon: Icons.error_outline_rounded);
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: cyberCyan, foregroundColor: Colors.black),
                  child: const Text('Kaydet', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _createSampleSwapRequest() async {
    if (_personeller.length < 2) {
      _showExecutiveSnackBar(title: 'Yetersiz Personel', message: 'En az 2 kayıtlı personel gereklidir.', color: amberGold, icon: Icons.warning_amber_rounded);
      return;
    }
    final p1 = _personeller[0];
    final p2 = _personeller[1];

    await FirebaseFirestore.instance.collection('vardiya_takas_talepleri').add({
      'talep_eden_id': p1['id'],
      'talep_eden_ad': p1['ad_soyad'] ?? 'Personel 1',
      'talep_eden_cihaz_id': p1['cihaz_id'],
      'mevcut_vardiya': p1['vardiya'] ?? 'Salı Grubu',
      'hedef_personel_id': p2['id'],
      'hedef_personel_ad': p2['ad_soyad'] ?? 'Personel 2',
      'hedef_personel_cihaz_id': p2['cihaz_id'],
      'hedef_vardiya': p2['vardiya'] ?? 'Cuma Grubu',
      'durum': 'onay_bekliyor',
      'aciklama': 'Özel mazeret sebebiyle takas talep edilmiştir.',
      'tarih': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    _showExecutiveSnackBar(title: 'Örnek Talep Oluşturuldu', message: 'Test amaçlı takas talebi listeye eklendi.', color: neonEmerald, icon: Icons.check_circle_rounded);
    _fetchData();
  }

  // ── SEKME 4: DUYURU YAYINLA ──
  Widget _buildAnnouncementsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: laserCrimson.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: laserCrimson, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saha & Amir Duyurusu Yayınla', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('OneSignal ile tüm personellere anlık bildirim gider', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _duyuruTitleCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Duyuru Başlığı',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  hintText: 'Örn: Vardiya Değişikliği / İSG Uyarısı',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: cardSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: laserCrimson)),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _duyuruContentCtrl,
                maxLines: 3,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Duyuru İçeriği',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  hintText: 'Personele iletilecek mesajı yazınız...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: cardSurfaceElevated,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: cardBorder)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: laserCrimson)),
                ),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _duyuruIsAlert ? laserCrimson.withValues(alpha: 0.12) : cardSurfaceElevated,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _duyuruIsAlert ? laserCrimson.withValues(alpha: 0.4) : cardBorder),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: _duyuruIsAlert ? laserCrimson : const Color(0xFF64748B), size: 18),
                        const SizedBox(width: 8),
                        Text('Acil Durum (Kırmızı Alarm)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                      ],
                    ),
                    Switch(
                      value: _duyuruIsAlert,
                      onChanged: (val) => setState(() => _duyuruIsAlert = val),
                      activeThumbColor: laserCrimson,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: _isSendingDuyuru ? null : _sendDuyuru,
                  icon: _isSendingDuyuru
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 16),
                  label: Text(_isSendingDuyuru ? 'Yayınlanıyor...' : 'Duyuruyu Yayınla & Push Gönder', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: laserCrimson,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        Text('📋 YAYINDAKİ DUYURULAR (${_duyurular.length})', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF8E9EB5), letterSpacing: 0.5)),
        const SizedBox(height: 10),

        if (_duyurular.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Text('Henüz yayınlanmış duyuru yok.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
            ),
          )
        else
          ..._duyurular.map((d) {
            final isAlert = d['is_alert'] == true;
            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: cardSurface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isAlert ? laserCrimson.withValues(alpha: 0.5) : cardBorder),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isAlert ? laserCrimson : cyberCyan).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAlert ? Icons.warning_rounded : Icons.info_outline_rounded,
                      color: isAlert ? laserCrimson : cyberCyan,
                      size: 16,
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
                            Expanded(child: Text(d['baslik'] ?? '', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white))),
                            Text((d['tarih'] ?? '').toString().split('T').first, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(d['icerik'] ?? '', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.3)),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: laserCrimson, size: 18),
                    onPressed: () => _deleteDuyuru(d['id']),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  // ── 📊 Canlı Saha & Vardiya Grafikleri ──
  Widget _buildAnalyticsSection() {
    final int inFactory = _personeller.where((p) => p['son_hareket_tipi'] == 'is_giris').length;
    final int outside = _personeller.length - inFactory;
    final double inFactoryPercent = _personeller.isEmpty ? 0 : (inFactory / _personeller.length * 100);

    int saliCount = 0;
    int carsambaCount = 0;
    int cumaCount = 0;
    int cumartesiCount = 0;
    int digerCount = 0;

    for (var p in _personeller) {
      final v = (p['vardiya'] ?? '').toString().toLowerCase();
      if (v.contains('sali') || v.contains('salı')) {
        saliCount++;
      } else if (v.contains('carsamba') || v.contains('çarşamba')) {
        carsambaCount++;
      } else if (v.contains('cuma')) {
        cumaCount++;
      } else if (v.contains('cumartesi')) {
        cumartesiCount++;
      } else {
        digerCount++;
      }
    }

    final double maxBarVal = [saliCount, carsambaCount, cumaCount, cumartesiCount, 5]
        .reduce((curr, next) => curr > next ? curr : next)
        .toDouble() + 2;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 80,
                height: 80,
                child: Stack(
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 24,
                        sections: [
                          PieChartSectionData(
                            value: inFactory.toDouble() > 0 ? inFactory.toDouble() : 0.001,
                            color: neonEmerald,
                            radius: 12,
                            showTitle: false,
                          ),
                          PieChartSectionData(
                            value: outside.toDouble() > 0 ? outside.toDouble() : 0.001,
                            color: const Color(0xFF263238),
                            radius: 10,
                            showTitle: false,
                          ),
                        ],
                      ),
                    ),
                    Center(
                      child: Text(
                        '%${inFactoryPercent.toInt()}',
                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
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
                    Text('Canlı Turnike Saha Durumu', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: neonEmerald, shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Sahada:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const Spacer(),
                        Text('$inFactory Kişi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: neonEmerald)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(width: 8, height: 8, decoration: const BoxDecoration(color: Color(0xFF64748B), shape: BoxShape.circle)),
                        const SizedBox(width: 6),
                        Text('Dışarıda / İzinli:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                        const Spacer(),
                        Text('$outside Kişi', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: cardBorder),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Posta Grupları Dağılımı', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
              Text('Toplam ${_personeller.length} Kişi', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 90,
            child: BarChart(
              BarChartData(
                maxY: maxBarVal,
                barTouchData: BarTouchData(enabled: true),
                titlesData: FlTitlesData(
                  show: true,
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        String title = '';
                        switch (value.toInt()) {
                          case 0:
                            title = 'Salı';
                            break;
                          case 1:
                            title = 'Çarş.';
                            break;
                          case 2:
                            title = 'Cuma';
                            break;
                          case 3:
                            title = 'Cmt.';
                            break;
                          case 4:
                            title = 'Diğer';
                            break;
                        }
                        return Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(title, style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF8E9EB5))),
                        );
                      },
                    ),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: [
                  _buildBarGroup(0, saliCount.toDouble(), amberGold),
                  _buildBarGroup(1, carsambaCount.toDouble(), electricViolet),
                  _buildBarGroup(2, cumaCount.toDouble(), cyberCyan),
                  _buildBarGroup(3, cumartesiCount.toDouble(), neonEmerald),
                  _buildBarGroup(4, digerCount.toDouble(), const Color(0xFF64748B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 14,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(5)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 10,
            color: const Color(0xFF141926),
          ),
        ),
      ],
    );
  }

  // ── Kullanıcı Log Geçmişi Modalı ──
  void _showUserLogHistory(String name, List<dynamic> logs) {
    final sorted = List<dynamic>.from(logs)..sort((a, b) {
      try {
        final dtA = DateTime.parse('${a['tarih']} ${a['saat']}');
        final dtB = DateTime.parse('${b['tarih']} ${b['saat']}');
        return dtB.compareTo(dtA);
      } catch (_) {
        return 0;
      }
    });

    showModalBottomSheet(
      context: context,
      backgroundColor: cardSurface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name — Oturum Geçmişi', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Toplam ${sorted.length} turnike kaydı', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: cardBorder),
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final l = sorted[index];
                    final isGiris = (l['islem_tipi'] ?? '').toString().toLowerCase().contains('giris');
                    final hasCoords = l['latitude'] != null && l['longitude'] != null;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: cardSurfaceElevated,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: cardBorder),
                      ),
                      child: Row(
                        children: [
                          Icon(isGiris ? Icons.login_rounded : Icons.logout_rounded, color: isGiris ? neonEmerald : laserCrimson, size: 16),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isGiris ? 'Fabrikaya Giriş Yapıldı' : 'Fabrikadan Çıkış Yapıldı', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white)),
                                if (hasCoords)
                                  GestureDetector(
                                    onTap: () async {
                                      final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${l['latitude']},${l['longitude']}');
                                      if (await canLaunchUrl(uri)) {
                                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                                      }
                                    },
                                    child: Row(
                                      children: [
                                        const Icon(Icons.location_on_rounded, size: 11, color: cyberCyan),
                                        const SizedBox(width: 3),
                                        Text('Konumu Haritada Gör', style: GoogleFonts.inter(fontSize: 10, color: cyberCyan, decoration: TextDecoration.underline)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Text('${l['tarih']} ${l['saat']}', style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8))),
                        ],
                      ),
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
}
