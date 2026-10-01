import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:url_launcher/url_launcher.dart';
import '../models/user_model.dart';
import '../utils/push_service.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  String _error = '';
  List<Map<String, dynamic>> _personeller = [];
  List<Map<String, dynamic>> _duyurular = [];
  int _selectedSegment = 0; // 0: Personeller, 1: Duyurular
  String _searchQuery = '';
  String _versionFilter = 'all'; // 'all', 'noctra', 'v10', 'eski'

  // Apple iOS 18 System Colors
  static const Color iosBg = Color(0xFF000000); // True Black
  static const Color iosCardBg = Color(0xFF1C1C1E); // Grouped Card Dark
  static const Color iosCardSecondary = Color(0xFF2C2C2E); // Elevated Card
  static const Color iosSeparator = Color(0xFF38383A); // 0.5px line
  static const Color iosBlue = Color(0xFF0A84FF); // System Blue Dark
  static const Color iosGreen = Color(0xFF30D158); // System Green Dark
  static const Color iosRed = Color(0xFFFF453A); // System Red Dark
  static const Color iosOrange = Color(0xFFFF9F0A); // System Orange Dark
  static const Color iosPurple = Color(0xFFBF5AF2); // System Purple Dark
  static const Color iosTextPrimary = Colors.white;
  static const Color iosTextSecondary = Color(0xFF8E8E93);
  static const Color iosTextTertiary = Color(0xFF636366);

  @override
  void initState() {
    super.initState();
    _fetchData();
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
        debugPrint('Duyurular okuma uyarısı: $de');
      }

      if (!mounted) return;
      setState(() {
        _personeller = personellerList;
        _duyurular = duyurularList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  Future<void> _updateStatus(String id, String newStatus) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: iosBlue),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'durum': newStatus});
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showIosToast(newStatus == 'onaylandi' ? 'Personel hesabı onaylandı' : 'Personel hesabı askıya alındı');

      if (newStatus == 'onaylandi') {
        final personel = _personeller.firstWhere((p) => p['id'] == id, orElse: () => {});
        final cihazId = personel['cihaz_id'] as String?;
        if (cihazId != null && cihazId.isNotEmpty) {
          try {
            await PushService.sendPushNotification(
              title: 'Hesabınız Onaylandı! ✅',
              content: 'İsdemir OS uygulamasına artık tam yetkiyle erişebilirsiniz.',
              targetCihazId: cihazId,
            );
          } catch (e) {
            debugPrint("Push error: $e");
          }
        }
      }

      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showIosToast('Hata: $e', isError: true);
    }
  }

  Future<void> _toggleVipStatus(String id, bool currentStatus) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: iosOrange),
      ),
    );

    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'is_vip': newStatus});
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showIosToast(newStatus ? 'VIP Statüsü Tanımlandı ⭐' : 'VIP Statüsü Kaldırıldı');
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showIosToast('Hata: $e', isError: true);
    }
  }

  Future<void> _toggleTelsizYetkisi(String id, bool currentStatus) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: iosGreen),
      ),
    );

    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'telsiz_yetkisi': newStatus});
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showIosToast(newStatus ? 'Telsiz Yetkisi Açıldı 📻' : 'Telsiz Yetkisi Kapatıldı');
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showIosToast('Hata: $e', isError: true);
    }
  }

  Future<void> _toggleYetkiliStatus(String id, bool currentStatus) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: iosRed),
      ),
    );

    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({
        'is_yetkili': newStatus,
        'yetkili': newStatus,
      });
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showIosToast(newStatus ? '🛡️ Yönetici Yetkisi Verildi' : 'Yönetici Yetkisi Geri Alındı');
      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showIosToast('Hata: $e', isError: true);
    }
  }

  Future<void> _updateNoctraStatus(String id, String newStatus, String? alias) async {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CupertinoActivityIndicator(radius: 16, color: iosPurple),
      ),
    );

    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({
        'noctra_durum': newStatus,
        'noctra_onay_tarihi': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();

      _showIosToast(newStatus == 'onaylandi'
          ? 'Noctra Kasası Onaylandı 🩸 ($alias)'
          : 'Noctra Durumu: $newStatus');

      if (newStatus == 'onaylandi') {
        final personel = _personeller.firstWhere((p) => p['id'] == id, orElse: () => {});
        final cihazId = personel['cihaz_id'] as String?;
        if (cihazId != null && cihazId.isNotEmpty) {
          try {
            await PushService.sendPushNotification(
              title: 'Noctra Erişiminiz Onaylandı! 🩸',
              content: 'Yönetici gizli iletişim protokolüne katılımınızı onayladı. Şifreniz ile kasayı açabilirsiniz.',
              targetCihazId: cihazId,
            );
          } catch (e) {
            debugPrint("Noctra push error: $e");
          }
        }
      }

      _fetchData();
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      _showIosToast('Hata: $e', isError: true);
    }
  }

  void _showIosToast(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? CupertinoIcons.exclamationmark_circle_fill : CupertinoIcons.checkmark_alt_circle_fill,
              color: isError ? iosRed : iosGreen,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1E20),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: const BorderSide(color: Color(0xFF38383A))),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAddDuyuruIosSheet() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showCupertinoModalPopup(
      context: context,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          left: 20,
          right: 20,
          top: 12,
        ),
        decoration: const BoxDecoration(
          color: Color(0xFF1C1C1E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4.5,
                  decoration: BoxDecoration(
                    color: iosTextTertiary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Vazgeç', style: TextStyle(color: iosTextSecondary, fontSize: 16)),
                  ),
                  const Text(
                    'Yeni Duyuru',
                    style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () async {
                      if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                        Navigator.pop(ctx);
                        try {
                          await FirebaseFirestore.instance.collection('duyurular').add({
                            'baslik': titleController.text,
                            'icerik': contentController.text,
                            'tarih': FieldValue.serverTimestamp(),
                          });

                          try {
                            await sendPushNotification(titleController.text, contentController.text);
                          } catch (e) {
                            debugPrint("Push bildirim hatası: $e");
                          }

                          _fetchData();
                          _showIosToast('Duyuru tüm kullanıcılara iletildi');
                        } catch (e) {
                          _showIosToast('Hata: $e', isError: true);
                        }
                      }
                    },
                    child: const Text('Yayınla', style: TextStyle(color: iosBlue, fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF2C2C2E),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    CupertinoTextField(
                      controller: titleController,
                      placeholder: 'Duyuru Başlığı',
                      placeholderStyle: const TextStyle(color: iosTextTertiary, fontSize: 15),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: iosSeparator, width: 0.5)),
                      ),
                    ),
                    CupertinoTextField(
                      controller: contentController,
                      placeholder: 'Duyuru Detayı ve Bildirim Metni...',
                      placeholderStyle: const TextStyle(color: iosTextTertiary, fontSize: 15),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                      maxLines: 4,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: const BoxDecoration(),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Row(
                children: [
                  Icon(CupertinoIcons.paperplane_fill, size: 14, color: iosBlue),
                  SizedBox(width: 6),
                  Text(
                    'OneSignal ile tüm personellere anlık push gönderilir.',
                    style: TextStyle(color: iosTextSecondary, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteDuyuru(String id) async {
    showCupertinoDialog(
      context: context,
      builder: (ctx) => CupertinoAlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: const Text('Bu duyuru kalıcı olarak sistemden ve panodan silinecektir.'),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Vazgeç'),
          ),
          CupertinoDialogAction(
            isDestructiveAction: true,
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await FirebaseFirestore.instance.collection('duyurular').doc(id).delete();
                _fetchData();
                _showIosToast('Duyuru silindi');
              } catch (e) {
                _showIosToast('Hata: $e', isError: true);
              }
            },
            child: const Text('Sil'),
          ),
        ],
      ),
    );
  }

  String formatCurrency(double amount) {
    String str = amount.toStringAsFixed(2);
    str = str.replaceAll('.', ',');
    final parts = str.split(',');
    final whole = parts[0];
    final decimal = parts[1];

    String formattedWhole = '';
    for (int i = 0; i < whole.length; i++) {
      formattedWhole += whole[i];
      if ((whole.length - 1 - i) % 3 == 0 && i != whole.length - 1) {
        formattedWhole += '.';
      }
    }
    return '$formattedWhole,$decimal ₺';
  }

  String _getInitials(String name) {
    List<String> names = name.trim().split(' ');
    String initials = '';
    int numWords = names.length > 2 ? 2 : names.length;
    for (int i = 0; i < numWords; i++) {
      if (names[i].isNotEmpty) {
        initials += names[i][0].toUpperCase();
      }
    }
    return initials.isEmpty ? 'P' : initials;
  }

  Future<void> sendPushNotification(String title, String content) async {
    try {
      await http.post(
        Uri.parse('https://isdemir-chat-server.onrender.com/api/ships/notify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'message': content,
        }),
      );
    } catch (_) {}

    try {
      final key = utf8.decode(base64.decode(
          'b3NfdjJfYXBwX290emZxZWNqdmpnNWRlNG15bWJjc251a21uaGV6YmdrcG5pdWtzNXU3aWNleG1seXE2Nzc2cDYyM2VrMmJ5c3N2emJ4bW8ydHRqcDZjZ2xpdjZpb2pueXp5ZzJvbXViZGplb3J5eXk='));
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $key',
        },
        body: json.encode({
          'app_id': '74f25810-49aa-4dd1-938c-c30229368a63',
          'headings': {'en': title, 'tr': title},
          'contents': {'en': content, 'tr': content},
          'included_segments': ['Total Subscriptions'],
        }),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: iosBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── iOS Navigation Bar ──
            _buildIosNavigationBar(),

            // ── iOS Cupertino Segmented Control ──
            _buildIosSegmentedControl(),

            // ── Segment Content ──
            Expanded(
              child: _isLoading
                  ? const Center(child: CupertinoActivityIndicator(radius: 16, color: iosBlue))
                  : _error.isNotEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(CupertinoIcons.exclamationmark_triangle_fill, color: iosRed, size: 40),
                                const SizedBox(height: 12),
                                Text(_error, style: const TextStyle(color: iosTextSecondary, fontSize: 14), textAlign: TextAlign.center),
                                const SizedBox(height: 16),
                                CupertinoButton.filled(
                                  onPressed: _fetchData,
                                  child: const Text('Tekrar Dene'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _selectedSegment == 0
                          ? _buildPersonelTab()
                          : _buildDuyurularTab(),
            ),
          ],
        ),
      ),
    );
  }

  // ── iOS Navigation Header ──
  Widget _buildIosNavigationBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // iOS Back Button
              CupertinoButton(
                padding: EdgeInsets.zero,
                onPressed: () => Navigator.pop(context),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(CupertinoIcons.chevron_back, color: iosBlue, size: 24),
                    SizedBox(width: 4),
                    Text('Geri', style: TextStyle(color: iosBlue, fontSize: 17, letterSpacing: -0.4)),
                  ],
                ),
              ),

              // iOS Action Icon
              Row(
                children: [
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _fetchData,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: iosCardBg,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: iosSeparator, width: 0.5),
                      ),
                      child: const Icon(CupertinoIcons.arrow_2_circlepath, color: iosBlue, size: 18),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: iosRed.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: iosRed.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(CupertinoIcons.lock_shield_fill, color: iosRed, size: 13),
                        SizedBox(width: 5),
                        Text(
                          'ADMİN',
                          style: TextStyle(color: iosRed, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Admin Paneli',
            style: TextStyle(
              color: iosTextPrimary,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Personel yetkilendirmesi, hakediş ve sistem duyuruları',
            style: TextStyle(color: iosTextSecondary, fontSize: 13.5, letterSpacing: -0.2),
          ),
        ],
      ),
    );
  }

  // ── iOS Cupertino Sliding Segmented Control ──
  Widget _buildIosSegmentedControl() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: iosCardBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: iosSeparator, width: 0.5),
        ),
        child: CupertinoSlidingSegmentedControl<int>(
          backgroundColor: Colors.transparent,
          thumbColor: const Color(0xFF636366),
          groupValue: _selectedSegment,
          children: {
            0: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.person_2_fill, size: 16, color: _selectedSegment == 0 ? Colors.white : iosTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Personeller (${_personeller.length})',
                    style: TextStyle(
                      color: _selectedSegment == 0 ? Colors.white : iosTextSecondary,
                      fontSize: 13.5,
                      fontWeight: _selectedSegment == 0 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            1: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(CupertinoIcons.speaker_2_fill, size: 16, color: _selectedSegment == 1 ? Colors.white : iosTextSecondary),
                  const SizedBox(width: 8),
                  Text(
                    'Duyurular (${_duyurular.length})',
                    style: TextStyle(
                      color: _selectedSegment == 1 ? Colors.white : iosTextSecondary,
                      fontSize: 13.5,
                      fontWeight: _selectedSegment == 1 ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          },
          onValueChanged: (val) {
            if (val != null) setState(() => _selectedSegment = val);
          },
        ),
      ),
    );
  }

  // ── 👥 SEKME 1: PERSONELLER (iOS Grouped Table View) ──
  Widget _buildPersonelTab() {
    final int totalCount = _personeller.length;
    final int v10Count = _personeller.where((p) {
      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      return ver.contains('10') || numVer >= 10;
    }).length;
    final int eskiCount = totalCount - v10Count;
    final int noctraPendingCount = _personeller.where((p) => p['noctra_durum'] == 'beklemede').length;
    final double updatePercent = totalCount > 0 ? (v10Count / totalCount) : 0.0;

    final filteredPersoneller = _personeller.where((p) {
      final name = (p['ad_soyad'] ?? '').toString().toLowerCase();
      final meslek = (p['meslek'] ?? '').toString().toLowerCase();
      final alias = (p['noctra_alias'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty || name.contains(query) || meslek.contains(query) || alias.contains(query);
      if (!matchesSearch) return false;

      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      final isV10 = ver.contains('10') || numVer >= 10;

      if (_versionFilter == 'v10') return isV10;
      if (_versionFilter == 'eski') return !isV10;
      if (_versionFilter == 'noctra') return p['noctra_durum'] == 'beklemede';
      return true;
    }).toList();

    return RefreshIndicator(
      onRefresh: _fetchData,
      color: iosBlue,
      backgroundColor: iosCardBg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        children: [
          // ── iOS Inset Telemetri Kartı ──
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: iosCardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: iosSeparator, width: 0.5),
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
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: iosGreen.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(CupertinoIcons.rocket_fill, color: iosGreen, size: 16),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'v10.0 Sürüm Yayılımı',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14.5),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: iosGreen,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '%${(updatePercent * 100).toInt()} Hazır',
                        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: updatePercent,
                    minHeight: 6,
                    backgroundColor: iosCardSecondary,
                    valueColor: const AlwaysStoppedAnimation<Color>(iosGreen),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('🟢 Güncel: $v10Count personel', style: const TextStyle(color: iosGreen, fontSize: 12, fontWeight: FontWeight.w600)),
                    Text('🟠 Eski: $eskiCount personel', style: const TextStyle(color: iosOrange, fontSize: 12, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // ── iOS Arama Çubuğu ──
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: iosCardBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iosSeparator, width: 0.5),
            ),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              style: const TextStyle(color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Personel adı, unvan veya Noctra ara...',
                hintStyle: const TextStyle(color: iosTextTertiary, fontSize: 14),
                prefixIcon: const Icon(CupertinoIcons.search, color: iosTextSecondary, size: 18),
                suffixIcon: _searchQuery.isNotEmpty
                    ? CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => setState(() => _searchQuery = ''),
                        child: const Icon(CupertinoIcons.clear_thick_circled, color: iosTextTertiary, size: 16),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 8),
              ),
            ),
          ),

          const SizedBox(height: 10),

          // ── iOS Filter Pills ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildIosFilterPill('all', 'Tümü ($totalCount)'),
                const SizedBox(width: 8),
                _buildIosFilterPill('noctra', '🩸 Noctra Talepleri ($noctraPendingCount)', isAlert: noctraPendingCount > 0),
                const SizedBox(width: 8),
                _buildIosFilterPill('v10', '🟢 v10.0 Güncel ($v10Count)'),
                const SizedBox(width: 8),
                _buildIosFilterPill('eski', '🟠 Eski Sürüm ($eskiCount)'),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // ── Personel Listesi ──
          if (filteredPersoneller.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Column(
                  children: const [
                    Icon(CupertinoIcons.person_crop_circle_badge_exclam, size: 40, color: iosTextTertiary),
                    SizedBox(height: 10),
                    Text('Kayıtlı personel bulunamadı', style: TextStyle(color: iosTextSecondary, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            ...filteredPersoneller.map((p) => _buildIosPersonelCard(p)),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildIosFilterPill(String filterKey, String label, {bool isAlert = false}) {
    final isSelected = _versionFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _versionFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? iosBlue : (isAlert ? iosRed.withValues(alpha: 0.15) : iosCardBg),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? iosBlue : (isAlert ? iosRed.withValues(alpha: 0.5) : iosSeparator),
            width: 0.8,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : (isAlert ? iosRed : iosTextSecondary),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  // ── iOS Grouped Card for Personnel ──
  Widget _buildIosPersonelCard(Map<String, dynamic> p) {
    final durum = p['durum'] as String? ?? 'onay_bekliyor';
    final bool isApproved = durum == 'onaylandi';
    final bool isBanned = durum == 'banlandi';

    final Color statusColor = isApproved ? iosGreen : (isBanned ? iosRed : iosOrange);
    final String statusText = isApproved ? 'Onaylı' : (isBanned ? 'Banlı' : 'Bekliyor');
    final IconData statusIcon = isApproved
        ? CupertinoIcons.checkmark_circle_fill
        : (isBanned ? CupertinoIcons.nosign : CupertinoIcons.clock_fill);

    final String meslek = p['meslek'] ?? 'Liman İşçisi A';
    final JobDetails jobDetails = UserModel.jobRates[meslek] ?? UserModel.jobRates['Liman İşçisi A']!;
    final double correctTabanMaas = jobDetails.baseSalary;
    final hakedisler = p['hakedis'] as List<dynamic>? ?? [];
    final hakedis = hakedisler.isNotEmpty ? hakedisler.first : null;
    final double hakedisAmount = hakedis != null ? (hakedis['guncel_hakedis'] as num).toDouble() : correctTabanMaas;
    final String name = p['ad_soyad'] ?? 'İsimsiz Personel';
    final String initials = _getInitials(name);
    final String shortId = p['id'].toString().length >= 4 ? p['id'].toString().substring(0, 4).replaceAll('-', '1') : '1000';
    final bool isVip = p['is_vip'] == true;
    final bool isTelsiz = p['telsiz_yetkisi'] == true;
    final bool isYetkili = p['is_yetkili'] == true || p['yetkili'] == true;
    final String noctraDurum = p['noctra_durum'] as String? ?? 'kayitsiz';
    final String? noctraAlias = p['noctra_alias'] as String?;
    final bool isNoctraPending = noctraDurum == 'beklemede';
    final bool isNoctraApproved = noctraDurum == 'onaylandi';
    final String appVer = p['app_version']?.toString() ?? 'v8.0';
    final bool isV10Updated = appVer.contains('10') || ((p['app_version_num'] as num?)?.toInt() ?? 0) >= 10;
    final String updateTime = p['guncelleme_tarihi_str'] ?? '';
    final logs = p['giris_cikis_log'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: iosCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iosSeparator, width: 0.5),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isApproved
                    ? [const Color(0xFF2E7D32), const Color(0xFF1B5E20)]
                    : [const Color(0xFF4A4A4E), const Color(0xFF2C2C2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                initials,
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white, letterSpacing: -0.3),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 0.8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 10, color: statusColor),
                    const SizedBox(width: 4),
                    Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                  ],
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
                  Text(meslek, style: const TextStyle(color: iosTextSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  Text('• ID: #$shortId', style: const TextStyle(color: iosTextTertiary, fontSize: 11)),
                ],
              ),
              const SizedBox(height: 6),
              // iOS Status Badges Row
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  if (isVip)
                    _buildIosPillBadge(label: 'VIP', color: iosOrange, icon: CupertinoIcons.star_fill),
                  if (isTelsiz)
                    _buildIosPillBadge(label: 'TELSİZ', color: iosGreen, icon: CupertinoIcons.antenna_radiowaves_left_right),
                  if (isYetkili)
                    _buildIosPillBadge(label: 'YETKİLİ', color: iosRed, icon: CupertinoIcons.shield_fill),
                  if (isNoctraPending)
                    _buildIosPillBadge(label: 'NOCTRA TALEP: $noctraAlias', color: iosRed, icon: CupertinoIcons.eye_slash_fill),
                  if (isNoctraApproved)
                    _buildIosPillBadge(label: 'NOCTRA AKTİF', color: iosPurple, icon: CupertinoIcons.lock_shield_fill),
                  _buildIosPillBadge(
                    label: isV10Updated ? (updateTime.isNotEmpty ? 'v10.0 ($updateTime)' : 'v10.0') : 'Eski Sürüm',
                    color: isV10Updated ? iosGreen : iosOrange,
                    icon: isV10Updated ? CupertinoIcons.checkmark_shield_fill : CupertinoIcons.exclamationmark_triangle_fill,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Quick Net Salary Row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: iosCardSecondary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Güncel Hakediş:', style: TextStyle(color: iosTextSecondary, fontSize: 11.5)),
                    Text(
                      formatCurrency(hakedisAmount),
                      style: const TextStyle(color: iosGreen, fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          children: [
            const Divider(color: iosSeparator, height: 1, thickness: 0.5),

            // ── Noctra Talep Kutusu (Beklemedeyse) ──
            if (isNoctraPending)
              Container(
                margin: const EdgeInsets.all(12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iosRed.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: iosRed.withValues(alpha: 0.5), width: 1),
                ),
                child: Row(
                  children: [
                    const Icon(CupertinoIcons.eye_slash_fill, color: iosRed, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Noctra Gizli Kasa Başvurusu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          Text('Kod Adı: "$noctraAlias"', style: const TextStyle(color: iosRed, fontSize: 12, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: iosGreen,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _updateNoctraStatus(p['id'], 'onaylandi', noctraAlias),
                      child: const Text('Onayla', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black)),
                    ),
                    const SizedBox(width: 6),
                    CupertinoButton(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      color: iosRed,
                      borderRadius: BorderRadius.circular(8),
                      onPressed: () => _updateNoctraStatus(p['id'], 'reddedildi', noctraAlias),
                      child: const Text('Reddet', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                    ),
                  ],
                ),
              ),

            // ── iOS Switches List ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Column(
                children: [
                  _buildIosSwitchRow(
                    title: 'Telsiz Yetkisi (Walkie-Talkie)',
                    subtitle: 'Canlı sesli telsiz kanalına erişim izni',
                    value: isTelsiz,
                    activeColor: iosGreen,
                    onChanged: (_) => _toggleTelsizYetkisi(p['id'], isTelsiz),
                  ),
                  const Divider(color: iosSeparator, height: 16, thickness: 0.5),
                  _buildIosSwitchRow(
                    title: 'VIP Hesap Yetkisi',
                    subtitle: 'Özel posta listeleri ve operasyon izinleri',
                    value: isVip,
                    activeColor: iosOrange,
                    onChanged: (_) => _toggleVipStatus(p['id'], isVip),
                  ),
                  const Divider(color: iosSeparator, height: 16, thickness: 0.5),
                  _buildIosSwitchRow(
                    title: 'Yönetici Statüsü (Yetkili)',
                    subtitle: 'Operasyon konsoluna ve onay masasına erişim',
                    value: isYetkili,
                    activeColor: iosRed,
                    onChanged: (_) => _toggleYetkiliStatus(p['id'], isYetkili),
                  ),
                  const Divider(color: iosSeparator, height: 16, thickness: 0.5),
                  _buildIosSwitchRow(
                    title: 'Noctra Gizli Kasa Protokolü',
                    subtitle: isNoctraApproved ? 'Protokol açık' : 'Erişim kapalı',
                    value: isNoctraApproved,
                    activeColor: iosPurple,
                    onChanged: (_) => _updateNoctraStatus(
                      p['id'],
                      isNoctraApproved ? 'reddedildi' : 'onaylandi',
                      noctraAlias,
                    ),
                  ),
                ],
              ),
            ),

            const Divider(color: iosSeparator, height: 1, thickness: 0.5),

            // ── Son Giriş/Çıkış Bilgisi ──
            if (logs.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Son Giriş/Çıkış Hareketleri', style: TextStyle(color: iosTextSecondary, fontSize: 11.5, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    ...logs.take(2).map((l) {
                      final isGiris = (l['islem_tipi'] ?? '').toString().toLowerCase().contains('giris');
                      final hasCoords = l['latitude'] != null && l['longitude'] != null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(isGiris ? CupertinoIcons.arrow_right_circle_fill : CupertinoIcons.arrow_left_circle_fill,
                                color: isGiris ? iosGreen : iosRed, size: 14),
                            const SizedBox(width: 8),
                            Text(isGiris ? 'Giriş Yaptı' : 'Çıkış Yaptı',
                                style: TextStyle(color: isGiris ? iosGreen : iosRed, fontSize: 12, fontWeight: FontWeight.w600)),
                            if (hasCoords) ...[
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () async {
                                  final uri = Uri.parse('https://www.google.com/maps/search/?api=1&query=${l['latitude']},${l['longitude']}');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: const Icon(CupertinoIcons.location_solid, color: iosBlue, size: 13),
                              ),
                            ],
                            const Spacer(),
                            Text('${l['tarih']} ${l['saat']}', style: const TextStyle(color: iosTextTertiary, fontSize: 11)),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

            // ── Onay & Ban Butonları ──
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
              child: Row(
                children: [
                  if (!isApproved)
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: iosGreen,
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => _updateStatus(p['id'], 'onaylandi'),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.checkmark_alt, size: 16, color: Colors.black),
                            SizedBox(width: 6),
                            Text('Hesabı Onayla', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                  if (!isApproved && !isBanned) const SizedBox(width: 10),
                  if (!isBanned)
                    Expanded(
                      child: CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        color: iosRed.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                        onPressed: () => _updateStatus(p['id'], 'banlandi'),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(CupertinoIcons.nosign, size: 16, color: iosRed),
                            SizedBox(width: 6),
                            Text('Askıya Al (Ban)', style: TextStyle(color: iosRed, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIosPillBadge({required String label, required Color color, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 0.8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildIosSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required Color activeColor,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w600)),
              Text(subtitle, style: const TextStyle(color: iosTextSecondary, fontSize: 11)),
            ],
          ),
        ),
        CupertinoSwitch(
          value: value,
          activeTrackColor: activeColor,
          onChanged: onChanged,
        ),
      ],
    );
  }

  // ── 📢 SEKME 2: DUYURULAR (iOS Grouped Style) ──
  Widget _buildDuyurularTab() {
    return RefreshIndicator(
      onRefresh: _fetchData,
      color: iosBlue,
      backgroundColor: iosCardBg,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // iOS Primary Action Button
          CupertinoButton(
            padding: const EdgeInsets.symmetric(vertical: 12),
            color: iosBlue,
            borderRadius: BorderRadius.circular(12),
            onPressed: _showAddDuyuruIosSheet,
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(CupertinoIcons.plus_circle_fill, size: 18, color: Colors.white),
                SizedBox(width: 8),
                Text('Yeni Duyuru Yayınla', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              ],
            ),
          ),

          const SizedBox(height: 16),

          if (_duyurular.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 50),
              child: Center(
                child: Column(
                  children: const [
                    Icon(CupertinoIcons.bell_slash, size: 40, color: iosTextTertiary),
                    SizedBox(height: 10),
                    Text('Yayınlanmış duyuru bulunmuyor', style: TextStyle(color: iosTextSecondary, fontSize: 14)),
                  ],
                ),
              ),
            )
          else
            ..._duyurular.map((d) {
              final dateStr = (d['tarih'] ?? '').toString().split('T').first;
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: iosCardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: iosSeparator, width: 0.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: iosBlue.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(CupertinoIcons.speaker_2_fill, color: iosBlue, size: 18),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d['baslik'] ?? '',
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold, letterSpacing: -0.2),
                              ),
                              const SizedBox(height: 2),
                              Text(dateStr, style: const TextStyle(color: iosTextTertiary, fontSize: 11.5)),
                            ],
                          ),
                        ),
                        CupertinoButton(
                          padding: const EdgeInsets.all(4),
                          onPressed: () => _deleteDuyuru(d['id']),
                          child: const Icon(CupertinoIcons.trash, color: iosRed, size: 18),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      d['icerik'] ?? '',
                      style: const TextStyle(color: Color(0xFFD1D1D6), fontSize: 13, height: 1.4),
                    ),
                  ],
                ),
              );
            }),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
