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
  String _filterType = 'all'; // 'all', 'onayli', 'yetkili', 'vip', 'bekleyen'
  bool _isExportingExcel = false;
  bool _showAnalyticsCharts = true;

  // Duyuru Formu Controller'ları
  final _duyuruTitleCtrl = TextEditingController();
  final _duyuruContentCtrl = TextEditingController();
  bool _duyuruIsAlert = false;
  bool _isSendingDuyuru = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {});
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

      final duyurularSnapshot = await FirebaseFirestore.instance
          .collection('duyurular')
          .orderBy('tarih', descending: true)
          .get();

      final duyurularList = duyurularSnapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        if (data['tarih'] is Timestamp) {
          data['tarih'] = (data['tarih'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      // Vardiya takas taleplerini çek
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
        debugPrint('Vardiya takas verisi çekme: $e');
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
          _error = 'Veri çekilirken hata oluştu: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'durum': newStatus});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus == 'onaylandi' ? '✅ Personel başarıyla onaylandı.' : 'Personel kaydı reddedildi.'),
          backgroundColor: newStatus == 'onaylandi' ? const Color(0xFF10B981) : const Color(0xFFEF4444),
        ),
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? '🛡️ Yetkili yetkisi tanımlandı.' : 'Yetkili yetkisi geri alındı.'),
          backgroundColor: newStatus ? const Color(0xFFDC2626) : const Color(0xFF64748B),
        ),
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _toggleVipStatus(String id, bool currentStatus, {String? name, String? cihazId}) async {
    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'is_vip': newStatus});
      
      // VIP yetkisi verildiğinde kullanıcıya OneSignal push bildirimi gönder
      if (newStatus && cihazId != null && cihazId.isNotEmpty) {
        await PushService.sendPushNotification(
          title: '👑 VIP Yetkiniz Tanımlandı!',
          content: 'Tebrikler ${name ?? ''}! Operasyon merkezi tarafından hesabınıza VIP yetkisi verildi. Posta listesi ve operasyonel modüllere erişebilirsiniz.',
          targetCihazId: cihazId,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(newStatus ? Icons.star_rounded : Icons.star_border_rounded, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(newStatus ? '⭐ ${name ?? 'Personele'} VIP Yetkisi Verildi (Bildirim İletildi).' : 'VIP Yetkisi Geri Alındı.'),
              ),
            ],
          ),
          backgroundColor: newStatus ? const Color(0xFFF59E0B) : const Color(0xFF64748B),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  // ── 📑 2. TEK TIKLA EXCEL / PUANTAJ RAPORU İNDİRME ──
  Future<void> _exportPersonnelToExcel() async {
    if (_isExportingExcel) return;
    setState(() => _isExportingExcel = true);
    HapticFeedback.mediumImpact();

    try {
      final buffer = StringBuffer();
      // CSV Başlık Satırı
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

      // Türkçe karakterlerin Excel'de bozulmaması için UTF-8 BOM ekliyoruz
      final utf8Bom = [0xEF, 0xBB, 0xBF];
      await file.writeAsBytes([...utf8Bom, ...utf8.encode(buffer.toString())]);

      setState(() => _isExportingExcel = false);

      if (!mounted) return;

      // Kullanıcıya paylaşma veya açma menüsü göster
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF141722),
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(top: BorderSide(color: Color(0xFF10B981), width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.table_view_rounded, color: Color(0xFF10B981), size: 36),
              ),
              const SizedBox(height: 14),
              Text(
                'Excel Puantaj Raporu Hazır',
                style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                '${_personeller.length} personelin tüm puantaj, maaş, vardiya ve turnike verileri Excel uyumlu (.csv) dosyası olarak hazırlandı.',
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
                        side: const BorderSide(color: Color(0xFF334155)),
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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Rapor oluşturma hatası: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _sendDuyuru() async {
    final title = _duyuruTitleCtrl.text.trim();
    final content = _duyuruContentCtrl.text.trim();

    if (title.isEmpty || content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen başlık ve içerik alanlarını doldurun.')),
      );
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

      // OneSignal Push Bildirimi Yayınla
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

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📢 Duyuru panoya eklendi ve tüm personele push bildirim gönderildi!'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }

      _fetchData();
    } catch (e) {
      if (mounted) {
        setState(() => _isSendingDuyuru = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Duyuru gönderim hatası: $e')));
      }
    }
  }

  Future<void> _deleteDuyuru(String id) async {
    try {
      await FirebaseFirestore.instance.collection('duyurular').doc(id).delete();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru kaldırıldı.')));
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
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

  // Vardiya Adı ve Canlı Durumu
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

    // Toplam Hakediş Havuzu
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
      backgroundColor: const Color(0xFF090A0F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F1118),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.6)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.shield_rounded, color: Color(0xFFDC2626), size: 12),
                      const SizedBox(width: 4),
                      Text('YETKİLİ', style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 10, fontWeight: FontWeight.w900)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('Operasyon Merkezi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
              ],
            ),
            Text(
              'Yetkili: ${widget.currentUser.fullName}',
              style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: _isExportingExcel
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF10B981)),
                  )
                : const Icon(Icons.table_view_rounded, color: Color(0xFF10B981)),
            onPressed: _exportPersonnelToExcel,
            tooltip: 'Excel Puantaj Raporu İndir',
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
            onPressed: _fetchData,
            tooltip: 'Yenile',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFFDC2626),
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFF64748B),
          labelStyle: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold),
          tabs: [
            const Tab(
              icon: Icon(Icons.people_alt_rounded, size: 18),
              text: 'Personel & Maaş',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: pendingCount > 0,
                label: Text('$pendingCount'),
                backgroundColor: const Color(0xFFDC2626),
                child: const Icon(Icons.pending_actions_rounded, size: 18),
              ),
              text: 'Bekleyen ($pendingCount)',
            ),
            Tab(
              icon: Badge(
                isLabelVisible: pendingSwapCount > 0,
                label: Text('$pendingSwapCount'),
                backgroundColor: const Color(0xFFF59E0B),
                child: const Icon(Icons.swap_horizontal_circle_rounded, size: 18),
              ),
              text: 'Vardiya Takas ($pendingSwapCount)',
            ),
            const Tab(
              icon: Icon(Icons.campaign_rounded, size: 18),
              text: 'Duyuru Yayınla',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626)))
          : _error.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70)),
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
    );
  }

  // ── 👥 SEKME 1: PERSONEL & MAAŞ & MESAİ & VARDİYA & GİRİŞ-ÇIKIŞ ──
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
      color: const Color(0xFFDC2626),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── KPI ÖZET KARTLARI ──
          Row(
            children: [
              Expanded(
                child: _buildKpiCard(
                  title: 'Toplam Personel',
                  value: '$totalPersonnel Kişi',
                  subtitle: '$pendingCount Onay Bekliyor',
                  icon: Icons.groups_rounded,
                  color: const Color(0xFF38BDF8),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildKpiCard(
                  title: 'Maaş & Mesai Havuzu',
                  value: _formatCurrency(totalHakedisPool),
                  subtitle: 'Aylık Toplam Hakediş',
                  icon: Icons.payments_rounded,
                  color: const Color(0xFF10B981),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── 🚀 V10.0 GÜNCELLEME TAKİP KARTI ──
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF10B981).withValues(alpha: 0.15),
                  const Color(0xFF141722),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rocket_launch_rounded, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'v10.0 Güncelleme Durumu',
                          style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '%${(updatePercent * 100).toInt()} Güncellendi',
                        style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w900, color: Colors.white),
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
                    valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '🟢 Güncelleyen: $v10Count Kişi',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                    ),
                    Text(
                      '🟠 Eski Sürümde: $eskiCount Kişi',
                      style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B)),
                    ),
                  ],
                ),
              ],
            ),
          ),


          const SizedBox(height: 14),

          // ── 📑 2. RAPOR AL & DASHBOARD AÇ/KAPA DÜĞMELERİ ──
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isExportingExcel ? null : _exportPersonnelToExcel,
                  icon: _isExportingExcel
                      ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.table_view_rounded, size: 16),
                  label: Text(_isExportingExcel ? 'Hazırlanıyor...' : 'Puantaj Excel İndir', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _showAnalyticsCharts = !_showAnalyticsCharts),
                icon: Icon(_showAnalyticsCharts ? Icons.pie_chart_rounded : Icons.pie_chart_outline_rounded, size: 16),
                label: Text(_showAnalyticsCharts ? 'Grafikleri Gizle' : 'Grafikleri Göster', style: const TextStyle(fontSize: 11.5)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF38BDF8),
                  side: const BorderSide(color: Color(0xFF38BDF8)),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── 📊 1. CANLI SAHA & VARDİYA GRAFİKLERİ TELEMETRİSİ ──
          if (_showAnalyticsCharts) _buildAnalyticsSection(),

          const SizedBox(height: 14),

          // ── ARAMA & FİLTRELEME ÇUBUĞU ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF272A36)),
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
                      hintText: 'Personel adı veya meslek ara...',
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

          const SizedBox(height: 12),

          // Filtre Butonları
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('all', 'Tümü (${_personeller.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('v10', '🚀 v10.0 Güncelleyenler ($v10Count)'),
                const SizedBox(width: 8),
                _buildFilterChip('eski', '⚠️ Eski Sürümde Kalanlar ($eskiCount)'),
                const SizedBox(width: 8),
                _buildFilterChip('onayli', 'Onaylılar (${_personeller.where((p) => p['durum'] == 'onaylandi').length})'),
                const SizedBox(width: 8),
                _buildFilterChip('yetkili', '🛡️ Yetkililer (${_personeller.where((p) => p['is_yetkili'] == true || p['yetkili'] == true).length})'),
                const SizedBox(width: 8),
                _buildFilterChip('vip', '👑 VIP (${_personeller.where((p) => p['is_vip'] == true).length})'),
                const SizedBox(width: 8),
                _buildFilterChip('bekleyen', '⏳ Bekleyenler ($pendingCount)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── PERSONEL LİSTESİ ──
          if (filteredList.isEmpty)
            Container(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text('Kriterlere uygun personel bulunamadı.', style: GoogleFonts.inter(color: const Color(0xFF64748B))),
              ),
            )
          else
            ...filteredList.map((p) => _buildExecutivePersonnelCard(p)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final isSelected = _filterType == type;
    return GestureDetector(
      onTap: () => setState(() => _filterType = type),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF141722),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFDC2626) : const Color(0xFF272A36)),
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

  Widget _buildKpiCard({required String title, required String value, required String subtitle, required IconData icon, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF12141C),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF272A36)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600)),
              Icon(icon, color: color, size: 18),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value, style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white)),
          ),
          const SizedBox(height: 2),
          Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  // ── DETAYLI PERSONEL KARTI (Maaş, Mesai, Vardiya, Giriş-Çıkış) ──
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isYetkili
              ? const Color(0xFFDC2626).withValues(alpha: 0.6)
              : (isApproved ? const Color(0xFF272A36) : const Color(0xFFF59E0B).withValues(alpha: 0.5)),
          width: isYetkili ? 1.5 : 1.0,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFF272A36),
                child: Text(_getInitials(name), style: GoogleFonts.inter(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              ),
              if (isYetkili)
                Positioned(
                  bottom: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Color(0xFFDC2626), shape: BoxShape.circle),
                    child: const Icon(Icons.shield_rounded, size: 10, color: Colors.white),
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
                    color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDC2626)),
                  ),
                  child: Text('YETKİLİ', style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w900, color: const Color(0xFFDC2626))),
                ),
              // ── 👑 3. VIP HIZLI TOGGLE BUTONU ──
              GestureDetector(
                onTap: () => _toggleVipStatus(p['id'], isVip, name: name, cihazId: p['cihaz_id']),
                child: Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: isVip ? const Color(0xFFF59E0B).withValues(alpha: 0.25) : const Color(0xFF1E2430),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isVip ? const Color(0xFFF59E0B) : const Color(0xFF334155),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.star_rounded, size: 12, color: isVip ? const Color(0xFFF59E0B) : const Color(0xFF64748B)),
                      const SizedBox(width: 3),
                      Text(
                        isVip ? 'VIP' : '+VIP',
                        style: GoogleFonts.inter(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: isVip ? const Color(0xFFF59E0B) : const Color(0xFF94A3B8),
                        ),
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
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                    decoration: BoxDecoration(
                      color: (isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isApproved ? 'Onaylı' : 'Bekliyor',
                      style: GoogleFonts.inter(fontSize: 9.5, color: isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B), fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isV10Updated ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: isV10Updated ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isV10Updated ? Icons.verified_rounded : Icons.pending_actions_rounded,
                          size: 9,
                          color: isV10Updated ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 3),
                        Text(
                          isV10Updated ? 'v10.0 GÜNCEL' : 'ESKİ SÜRÜM',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isV10Updated ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (updateTime.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      updateTime,
                      style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 8),

              // 💰 Hızlı Maaş & Mesai Şeridi
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D0F15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Net Hakediş:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF64748B))),
                    Text(
                      _formatCurrency(netHakedis),
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w900, color: const Color(0xFF10B981)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Color(0xFF0D0F15),
                borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. MAAŞ & MESAİ DETAY BLOKU
                  Text('💰 MAAŞ VE MESAİ DETAYI', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141722),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF272A36)),
                    ),
                    child: Column(
                      children: [
                        _buildDataRow('Taban Maaş:', _formatCurrency(jobDetails.baseSalary), isBold: true),
                        const Divider(height: 12, color: Color(0xFF272A36)),
                        _buildDataRow('Normal Mesai ($normalMesaiGun Gün):', '+ ${_formatCurrency(normalMesaiKazanci)}', valueColor: const Color(0xFFF59E0B)),
                        const SizedBox(height: 4),
                        _buildDataRow('Bayram Mesaisi ($bayramMesaiGun Gün):', '+ ${_formatCurrency(bayramMesaiKazanci)}', valueColor: const Color(0xFF8B5CF6)),
                        const Divider(height: 12, color: Color(0xFF272A36)),
                        _buildDataRow('Toplam Kazanç:', _formatCurrency(netHakedis), valueColor: const Color(0xFF10B981), isBold: true),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 2. VARDİYA BİLGİSİ
                  Text('🔄 VARDİYA DÜZENİ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141722),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF272A36)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text(vardiyaInfo['vardiyaAdi']!, style: GoogleFonts.inter(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600))),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.work_history_rounded, color: Color(0xFF10B981), size: 16),
                            const SizedBox(width: 8),
                            Expanded(child: Text('Bugün: ${vardiyaInfo['canliDurum']!}', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF10B981), fontWeight: FontWeight.bold))),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // 3. UYGULAMA GİRİŞ-ÇIKIŞ KULLANIM SAYACI
                  Text('📊 UYGULAMA KULLANIM & GİRİŞ-ÇIKIŞ', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF141722),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF272A36)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.phone_android_rounded, color: Color(0xFF00FF66), size: 16),
                                const SizedBox(width: 8),
                                Text('Uygulama Giriş Sayısı:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1))),
                              ],
                            ),
                            Text(
                              '$girisSayisi Giriş ($totalHareket Hareket)',
                              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: const Color(0xFF00FF66)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.access_time_rounded, color: Color(0xFF94A3B8), size: 16),
                                const SizedBox(width: 8),
                                Text('Son Hareket:', style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1))),
                              ],
                            ),
                            Text(
                              '$sonGirisTarih $sonGirisSaat',
                              style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
                            ),
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
                                foregroundColor: const Color(0xFF38BDF8),
                                side: const BorderSide(color: Color(0xFF38BDF8)),
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 4. AKSİYON BUTONLARI (Yetkili Yap, Onayla, VIP)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      // Yetkili Butonu
                      ElevatedButton.icon(
                        onPressed: () => _toggleYetkiliStatus(p['id'], isYetkili),
                        icon: Icon(isYetkili ? Icons.security_rounded : Icons.shield_outlined, size: 14),
                        label: Text(isYetkili ? 'Yetkiyi Kaldır' : '🛡️ Yetkili Yap', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isYetkili ? const Color(0xFF272A36) : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),

                      // VIP Butonu
                      ElevatedButton.icon(
                        onPressed: () => _toggleVipStatus(p['id'], isVip, name: name, cihazId: p['cihaz_id']),
                        icon: Icon(isVip ? Icons.star_border_rounded : Icons.star_rounded, size: 14),
                        label: Text(isVip ? 'VIP Yetkisini Kaldır' : '👑 VIP Yap & Bildir', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVip ? const Color(0xFF272A36) : const Color(0xFFF59E0B),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                      ),

                      // Onay / Ret Butonları
                      if (!isApproved) ...[
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(p['id'], 'onaylandi'),
                          icon: const Icon(Icons.check_rounded, size: 14),
                          label: const Text('Onayla', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF10B981),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: () => _updateStatus(p['id'], 'reddedildi'),
                          icon: const Icon(Icons.close_rounded, size: 14),
                          label: const Text('Reddet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFEF4444),
                            foregroundColor: Colors.white,
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

  // ── ⏳ SEKME 2: BEKLEYEN ONAYLAR (Hızlı Onay Listesi) ──
  Widget _buildPendingApprovalsTab() {
    final pendingList = _personeller.where((p) => p['durum'] == 'onay_bekliyor').toList();

    if (pendingList.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Color(0xFF10B981), size: 56),
            const SizedBox(height: 16),
            Text('Onay bekleyen personel bulunmuyor.', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
            const SizedBox(height: 6),
            Text('Tüm kayıt başvuruları sonuçlandırılmış.', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF64748B))),
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
            color: const Color(0xFF141722),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                    child: Text(_getInitials(name), style: GoogleFonts.inter(color: const Color(0xFFF59E0B), fontWeight: FontWeight.bold)),
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
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('Bekliyor', style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
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
                        backgroundColor: const Color(0xFF10B981),
                        foregroundColor: Colors.white,
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () => _updateStatus(p['id'], 'reddedildi'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      foregroundColor: const Color(0xFFEF4444),
                      elevation: 0,
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

  // ── 📢 SEKME 3: DUYURU & ACİL ANONS YAYINLA ──
  Widget _buildAnnouncementsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── YENİ DUYURU FORMU KARTI ──
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF141722),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFDC2626).withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.campaign_rounded, color: Color(0xFFDC2626), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Saha & Amir Duyurusu Yayınla', style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text('OneSignal ile tüm personellere anlık bildirim gider', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Başlık
              TextField(
                controller: _duyuruTitleCtrl,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Duyuru Başlığı',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  hintText: 'Örn: Vardiya Değişikliği / İSG Uyarısı',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0D0F15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                ),
              ),

              const SizedBox(height: 12),

              // İçerik
              TextField(
                controller: _duyuruContentCtrl,
                maxLines: 4,
                style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Duyuru İçeriği',
                  labelStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                  hintText: 'Saha personellerine iletilecek mesajı yazınız...',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12),
                  filled: true,
                  fillColor: const Color(0xFF0D0F15),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFF272A36))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Color(0xFFDC2626))),
                ),
              ),

              const SizedBox(height: 12),

              // Acil Durum / Kırmızı Uyarı Anahtarı
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _duyuruIsAlert ? const Color(0xFFDC2626).withValues(alpha: 0.12) : const Color(0xFF0D0F15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _duyuruIsAlert ? const Color(0xFFDC2626).withValues(alpha: 0.4) : const Color(0xFF272A36)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: _duyuruIsAlert ? const Color(0xFFDC2626) : const Color(0xFF64748B), size: 20),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Acil Durum Bildirimi (Kırmızı Alarm)', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                            Text('Önemli operasyon durdurması veya hava alarmı', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                          ],
                        ),
                      ],
                    ),
                    Switch(
                      value: _duyuruIsAlert,
                      onChanged: (val) => setState(() => _duyuruIsAlert = val),
                      activeThumbColor: const Color(0xFFDC2626),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Gönder Butonu
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isSendingDuyuru ? null : _sendDuyuru,
                  icon: _isSendingDuyuru
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.send_rounded, size: 18),
                  label: Text(_isSendingDuyuru ? 'Yayınlanıyor...' : 'Duyuruyu Yayınla & Push Gönder', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFDC2626),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // ── AKTİF DUYURULAR LİSTESİ ──
        Text('📋 YAYINDAKİ DUYURULAR (${_duyurular.length})', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8))),
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
                color: const Color(0xFF141722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: isAlert ? const Color(0xFFDC2626).withValues(alpha: 0.5) : const Color(0xFF272A36)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: (isAlert ? const Color(0xFFDC2626) : const Color(0xFF38BDF8)).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isAlert ? Icons.warning_rounded : Icons.info_outline_rounded,
                      color: isAlert ? const Color(0xFFDC2626) : const Color(0xFF38BDF8),
                      size: 18,
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
                    icon: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444), size: 18),
                    tooltip: 'Duyuruyu Sil',
                    onPressed: () => _deleteDuyuru(d['id']),
                  ),
                ],
              ),
            );
          }),

        const SizedBox(height: 40),
      ],
    );
  }

  // ── 📊 1. CANLI SAHA & VARDİYA GRAFİKLERİ BİLEŞENİ ──
  Widget _buildAnalyticsSection() {
    final int inFactory = _personeller.where((p) => p['son_hareket_tipi'] == 'is_giris').length;
    final int outside = _personeller.length - inFactory;
    final double inFactoryPercent = _personeller.isEmpty ? 0 : (inFactory / _personeller.length * 100);

    // Vardiya dağılımları
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
      decoration: BoxDecoration(
        color: const Color(0xFF12151F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF262C3E)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // 1. DONUT GRAFİĞİ (Saha Durumu)
                Row(
                  children: [
                    // Donut Grafik
                    SizedBox(
                      width: 95,
                      height: 95,
                      child: Stack(
                        children: [
                          PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 28,
                              sections: [
                                PieChartSectionData(
                                  value: inFactory.toDouble() > 0 ? inFactory.toDouble() : 0.001,
                                  color: const Color(0xFF10B981),
                                  radius: 14,
                                  showTitle: false,
                                ),
                                PieChartSectionData(
                                  value: outside.toDouble() > 0 ? outside.toDouble() : 0.001,
                                  color: const Color(0xFF334155),
                                  radius: 12,
                                  showTitle: false,
                                ),
                              ],
                            ),
                          ),
                          Center(
                            child: Text(
                              '%${inFactoryPercent.toInt()}',
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Açıklamalar
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Canlı Saha Katılımı',
                            style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('Sahada (Fabrikada):', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                              const Spacer(),
                              Text('$inFactory Kişi', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF10B981))),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(width: 9, height: 9, decoration: const BoxDecoration(color: Color(0xFF334155), shape: BoxShape.circle)),
                              const SizedBox(width: 8),
                              Text('Dışarıda / İzinli:', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                              const Spacer(),
                              Text('$outside Kişi', style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFF222838)),
                const SizedBox(height: 14),

                // 2. ÇUBUK GRAFİĞİ (Posta Dağılımı)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Posta Grupları Dağılımı',
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    Text(
                      'Toplam ${_personeller.length} Personel',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 110,
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
                                  title = '1. Salı';
                                  break;
                                case 1:
                                  title = '2. Çarş.';
                                  break;
                                case 2:
                                  title = '3. Cuma';
                                  break;
                                case 3:
                                  title = '4. Cmt.';
                                  break;
                                case 4:
                                  title = 'Diğer';
                                  break;
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  title,
                                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF94A3B8)),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      gridData: const FlGridData(show: false),
                      borderData: FlBorderData(show: false),
                      barGroups: [
                        _buildBarGroup(0, saliCount.toDouble(), const Color(0xFFF59E0B)),
                        _buildBarGroup(1, carsambaCount.toDouble(), const Color(0xFF8B5CF6)),
                        _buildBarGroup(2, cumaCount.toDouble(), const Color(0xFF3B82F6)),
                        _buildBarGroup(3, cumartesiCount.toDouble(), const Color(0xFF10B981)),
                        _buildBarGroup(4, digerCount.toDouble(), const Color(0xFF64748B)),
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

  BarChartGroupData _buildBarGroup(int x, double y, Color color) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: y,
          color: color,
          width: 18,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            toY: 10,
            color: const Color(0xFF1A1F2C),
          ),
        ),
      ],
    );
  }

  // ── 🔄 6. VARDİYA TAKAS TALEPLERİ ONAY MASASI SEKME GÖRÜNÜMÜ ──
  Widget _buildSwapRequestsTab() {
    final pendingSwaps = _swapRequests.where((s) => s['durum'] == 'onay_bekliyor').toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: const Color(0xFFDC2626),
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Üst Hızlı İşlem Kartı
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF141722),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFF272A36)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.swap_calls_rounded, color: Color(0xFFF59E0B), size: 22),
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
                        '${pendingSwaps.length} adet onay bekleyen takas talebi var',
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
                    backgroundColor: const Color(0xFF38BDF8),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // Liste Başlığı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'TAKAS TALEPLERİ (${_swapRequests.length})',
                style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w800, color: const Color(0xFF94A3B8)),
              ),
              if (_swapRequests.isEmpty)
                TextButton.icon(
                  onPressed: _createSampleSwapRequest,
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 14),
                  label: const Text('Örnek Talep Oluştur', style: TextStyle(fontSize: 11)),
                  style: TextButton.styleFrom(foregroundColor: const Color(0xFF38BDF8)),
                ),
            ],
          ),

          const SizedBox(height: 10),

          if (_swapRequests.isEmpty)
            Container(
              margin: const EdgeInsets.only(top: 20),
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: const Color(0xFF141722),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFF272A36)),
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
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _showManualShiftAssignDialog,
                    icon: const Icon(Icons.edit_calendar_rounded, size: 16),
                    label: const Text('Personele Vardiya Ata'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF38BDF8),
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            )
          else
            ..._swapRequests.map((s) => _buildSwapRequestCard(s)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSwapRequestCard(Map<String, dynamic> swap) {
    final String durum = swap['durum'] ?? 'onay_bekliyor';
    final bool isPending = durum == 'onay_bekliyor';
    final bool isApproved = durum == 'onaylandi';

    final Color statusColor = isPending
        ? const Color(0xFFF59E0B)
        : (isApproved ? const Color(0xFF10B981) : const Color(0xFFEF4444));
    final String statusLabel = isPending
        ? '⏳ Onay Bekliyor'
        : (isApproved ? '✅ Onaylandı' : '❌ Reddedildi');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF141722),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPending ? const Color(0xFFF59E0B).withValues(alpha: 0.5) : const Color(0xFF272A36),
          width: isPending ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Üst Durum & Tarih
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: statusColor),
                ),
              ),
              Text(
                swap['tarih_str'] ?? '',
                style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Karşılıklı Takas Kutuları
          Row(
            children: [
              // Talep Eden Personel
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2030),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E384D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Talep Eden:', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        swap['talep_eden_ad'] ?? 'Personel 1',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          swap['mevcut_vardiya'] ?? 'Salı',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.sync_alt_rounded, color: Color(0xFFF59E0B), size: 22),
              ),

              // Hedef Personel
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B2030),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2E384D)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Hedef Personel:', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                      const SizedBox(height: 2),
                      Text(
                        swap['hedef_personel_ad'] ?? 'Personel 2',
                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.bold, color: Colors.white),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          swap['hedef_vardiya'] ?? 'Cuma',
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF10B981)),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if ((swap['aciklama'] ?? '').toString().isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1118),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.chat_bubble_outline_rounded, size: 14, color: Color(0xFF94A3B8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      swap['aciklama'] ?? '',
                      style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFCBD5E1), fontStyle: FontStyle.italic),
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (isPending) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _approveSwapRequest(swap),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('Onayla & Vardiyaları Değiştir', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: () => _rejectSwapRequest(swap),
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Reddet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Vardiyalar başarıyla takas edildi ve personellere bildirim gönderildi!'),
          backgroundColor: Color(0xFF10B981),
        ),
      );
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Takas onaylama hatası: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vardiya takas talebi reddedildi.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      _fetchData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
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
              backgroundColor: const Color(0xFF141722),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Color(0xFF2A3347))),
              title: Row(
                children: [
                  const Icon(Icons.edit_calendar_rounded, color: Color(0xFF38BDF8), size: 22),
                  const SizedBox(width: 10),
                  Text('Vardiya Ata / Değiştir', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personel Seç:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E384D)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E2433),
                        isExpanded: true,
                        value: selectedPersonelId,
                        hint: const Text('Personel seçiniz', style: TextStyle(color: Color(0xFF64748B), fontSize: 13)),
                        items: _personeller.map((p) {
                          return DropdownMenuItem<String>(
                            value: p['id'].toString(),
                            child: Text(
                              '${p['ad_soyad'] ?? 'İsimsiz'} (${p['vardiya'] ?? 'Vardiya Yok'})',
                              style: const TextStyle(color: Colors.white, fontSize: 12.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) => setDialogState(() => selectedPersonelId = val),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Yeni Vardiya:', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E2433),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFF2E384D)),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        dropdownColor: const Color(0xFF1E2433),
                        isExpanded: true,
                        value: selectedShift,
                        items: const [
                          DropdownMenuItem(value: 'Salı Grubu', child: Text('1. Posta (Salı Grubu)', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'Çarşamba Grubu', child: Text('2. Posta (Çarşamba Grubu)', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'Cuma Grubu', child: Text('3. Posta (Cuma Grubu)', style: TextStyle(color: Colors.white, fontSize: 13))),
                          DropdownMenuItem(value: 'Cumartesi Grubu', child: Text('4. Posta (Cumartesi Grubu)', style: TextStyle(color: Colors.white, fontSize: 13))),
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Vardiya başarıyla $selectedShift olarak güncellendi!'),
                                  backgroundColor: const Color(0xFF10B981),
                                ),
                              );
                              _fetchData();
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF38BDF8), foregroundColor: Colors.black),
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('En az 2 personel kayıtlı olmalıdır.')),
      );
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
      'aciklama': 'Özel ailevi mazeret sebebiyle bu haftalık vardiya değişimi talep ediyorum.',
      'tarih': FieldValue.serverTimestamp(),
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Test amaçlı örnek takas talebi oluşturuldu!'), backgroundColor: Color(0xFF10B981)),
    );
    _fetchData();
  }

  // ── DETAYLI LOG GEÇMİŞİ MODALI ──
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
      backgroundColor: const Color(0xFF141722),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$name — Oturum Geçmişi', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      Text('Toplam ${sorted.length} kayıtlı işlem', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white70),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(color: Color(0xFF272A36)),
              Expanded(
                child: ListView.builder(
                  itemCount: sorted.length,
                  itemBuilder: (context, index) {
                    final l = sorted[index];
                    final isGiris = (l['islem_tipi'] ?? '').toString().toLowerCase().contains('giris');
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D0F15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF272A36)),
                      ),
                      child: Row(
                        children: [
                          Icon(isGiris ? Icons.login_rounded : Icons.logout_rounded, color: isGiris ? const Color(0xFF10B981) : const Color(0xFFEF4444), size: 18),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(isGiris ? 'Uygulamaya Giriş Yapıldı' : 'Uygulamadan Çıkış Yapıldı', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                if (l['latitude'] != null && l['longitude'] != null)
                                  Text('GPS: ${l['latitude']}, ${l['longitude']}', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B))),
                              ],
                            ),
                          ),
                          Text('${l['tarih']} ${l['saat']}', style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
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
