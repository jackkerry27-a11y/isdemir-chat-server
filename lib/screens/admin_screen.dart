import 'package:flutter/material.dart';
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
  late TabController _tabController;
  String _searchQuery = '';
  String _versionFilter = 'all'; // 'all', 'v9', 'eski'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });

    try {
      final personelSnapshot = await FirebaseFirestore.instance.collection('personeller').orderBy('durum', descending: true).get();
      
      List<Map<String, dynamic>> personellerList = [];
      for (var doc in personelSnapshot.docs) {
        var data = doc.data();
        data['id'] = doc.id;
        
        try {
          final logsSnapshot = await doc.reference.collection('giris_cikis_log').get();
          data['giris_cikis_log'] = logsSnapshot.docs.map((d) => d.data()).toList();
          
          final hakedisSnapshot = await doc.reference.collection('hakedis').get();
          data['hakedis'] = hakedisSnapshot.docs.map((d) => d.data()).toList();
        } catch(e) {
          data['giris_cikis_log'] = [];
          data['hakedis'] = [];
        }
        
        personellerList.add(data);
      }
      
      final duyurularSnapshot = await FirebaseFirestore.instance.collection('duyurular').orderBy('tarih', descending: true).get();
      final duyurularList = duyurularSnapshot.docs.map((doc) {
        var data = doc.data();
        data['id'] = doc.id;
        // Timestamp to string if needed, but UI handles string, we might need to handle Timestamp
        if(data['tarih'] is Timestamp) {
          data['tarih'] = (data['tarih'] as Timestamp).toDate().toIso8601String();
        }
        return data;
      }).toList();

      setState(() {
        _personeller = personellerList;
        _duyurular = duyurularList;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Veri çekilirken hata oluştu. Hata: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF4338CA))),
    );
    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'durum': newStatus});
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Durum güncellendi.')));
      
      if (newStatus == 'onaylandi') {
        final personel = _personeller.firstWhere((p) => p['id'] == id, orElse: () => {});
        final cihazId = personel['cihaz_id'] as String?;
        if (cihazId != null) {
          try {
            await PushService.sendPushNotification(
              title: 'Hesabınız Onaylandı!',
              content: 'İsdemir OS uygulamasına artık tam erişimle giriş yapabilirsiniz.',
              targetCihazId: cihazId,
            );
          } catch (e) {
            print("Push error: $e");
          }
        }
      }
      
      _fetchData();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _toggleVipStatus(String id, bool currentStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFE50914))),
    );
    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'is_vip': !currentStatus});
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(currentStatus ? 'VIP Yetkisi Alındı.' : 'VIP Yetkisi Verildi.')));
      _fetchData();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _toggleTelsizYetkisi(String id, bool currentStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFF00FF66))),
    );
    try {
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({'telsiz_yetkisi': !currentStatus});
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(currentStatus ? 'Telsiz yetkisi kaldırıldı.' : 'Telsiz yetkisi verildi.'),
          backgroundColor: currentStatus ? const Color(0xFFEF4444) : const Color(0xFF10B981),
        ),
      );
      _fetchData();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  Future<void> _toggleYetkiliStatus(String id, bool currentStatus) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFDC2626))),
    );
    try {
      final newStatus = !currentStatus;
      await FirebaseFirestore.instance.collection('personeller').doc(id).update({
        'is_yetkili': newStatus,
        'yetkili': newStatus,
      });
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(newStatus ? '🛡️ Yetkili Statüsü Verildi.' : 'Yetkili Statüsü Kaldırıldı.'),
          backgroundColor: newStatus ? const Color(0xFFDC2626) : const Color(0xFF64748B),
        ),
      );
      _fetchData();
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    }
  }

  void _showAddDuyuruDialog() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yeni Duyuru Yayınla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: titleController, decoration: const InputDecoration(labelText: 'Başlık', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: contentController, maxLines: 3, decoration: const InputDecoration(labelText: 'İçerik', border: OutlineInputBorder())),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isNotEmpty && contentController.text.isNotEmpty) {
                Navigator.pop(context);
                try {
                  await FirebaseFirestore.instance.collection('duyurular').add({
                    'baslik': titleController.text,
                    'icerik': contentController.text,
                    'tarih': FieldValue.serverTimestamp(),
                  });

                  // Push bildirimi gönder
                  try {
                    await sendPushNotification(titleController.text, contentController.text);
                  } catch (e) {
                    print("Bildirim gönderilemedi: $e");
                  }
                  _fetchData();
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru yayınlandı.')));
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA), foregroundColor: Colors.white),
            child: const Text('Yayınla'),
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
    return initials;
  }

  Future<void> _deleteDuyuru(String id) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duyuruyu Sil'),
        content: const Text('Bu duyuruyu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('İptal')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await FirebaseFirestore.instance.collection('duyurular').doc(id).delete();
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru silindi.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> sendPushNotification(String title, String content) async {
    // 1. Render sunucumuz üzerinden güvenli bildirim gönderimi
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

    // 2. Yedek doğrudan OneSignal REST API
    try {
      final key = utf8.decode(base64.decode('b3NfdjJfYXBwX290emZxZWNqdmpnNWRlNG15bWJjc251a21uaGV6YmdrcG5pdWtzNXU3aWNleG1seXE2Nzc2cDYyM2VrMmJ5c3N2emJ4bW8ydHRqcDZjZ2xpdjZpb2pueXp5ZzJvbXViZGplb3J5eXk='));
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
      backgroundColor: const Color(0xFF0F0F13),
      body: Stack(
        children: [
          // Arka plan resim ve gradient
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
                        const Color(0xFFE50914).withValues(alpha: 0.2),
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
              _buildHeader(),
              Expanded(
                child: _isLoading 
                    ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
                    : _error.isNotEmpty 
                        ? Center(child: Text(_error, style: const TextStyle(color: Colors.red)))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildPersonelTab(),
                              _buildDuyurularTab(),
                            ],
                          ),
              ),
            ],
          ),
        ],
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        backgroundColor: const Color(0xFFE50914),
        elevation: 10,
        
        icon: const Icon(Icons.add_circle, color: Colors.white),
        label: const Text('Yeni Personel Ekle', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Admin Paneli', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    SizedBox(height: 4),
                    Text('Personel yönetimi ve bordro takibi', style: TextStyle(color: Colors.white70, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE50914),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: const Color(0xFFE50914).withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 4)),
                  ]
                ),
                child: const Icon(Icons.people_alt, color: Colors.white, size: 28),
              )
            ],
          ),
          const SizedBox(height: 32),
          Container(
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C22),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFFE50914).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5), width: 1),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.people, size: 18),
                      SizedBox(width: 8),
                      Text('Personeller', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.campaign, size: 18),
                      SizedBox(width: 8),
                      Text('Duyurular', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPersonelTab() {
    final int totalCount = _personeller.length;
    final int v9Count = _personeller.where((p) {
      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      return ver.contains('9') || numVer >= 9;
    }).length;
    final int eskiCount = totalCount - v9Count;
    final double updatePercent = totalCount > 0 ? (v9Count / totalCount) : 0.0;

    final filteredPersoneller = _personeller.where((p) {
      final name = (p['ad_soyad'] ?? '').toString().toLowerCase();
      final meslek = (p['meslek'] ?? '').toString().toLowerCase();
      final query = _searchQuery.toLowerCase().trim();
      final matchesSearch = query.isEmpty || name.contains(query) || meslek.contains(query);
      if (!matchesSearch) return false;

      final ver = p['app_version']?.toString() ?? '';
      final numVer = (p['app_version_num'] as num?)?.toInt() ?? 0;
      final isV9 = ver.contains('9') || numVer >= 9;

      if (_versionFilter == 'v9') return isV9;
      if (_versionFilter == 'eski') return !isV9;
      return true;
    }).toList();

    return Column(
      children: [
        // ── 🚀 V9.0 CANLI GÜNCELLEME TELEMETRİ BANNER'I ──
        Container(
          margin: const EdgeInsets.fromLTRB(24, 16, 24, 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                const Color(0xFF10B981).withValues(alpha: 0.15),
                const Color(0xFF1E293B).withValues(alpha: 0.7),
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
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.rocket_launch_rounded, color: Color(0xFF10B981), size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'v9.0 Uygulama Güncelleme Takibi',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
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
                      '%${(updatePercent * 100).toInt()} Güncel',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 11),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // İlerleme Çubuğu
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: updatePercent,
                  minHeight: 6,
                  backgroundColor: const Color(0xFF334155),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '🟢 Güncelleyenler: $v9Count Kişi',
                    style: const TextStyle(color: Color(0xFF10B981), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '🟠 Eski Sürüm: $eskiCount Kişi',
                    style: const TextStyle(color: Color(0xFFF59E0B), fontSize: 11.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── ARAMA & FİLTRELER ──
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8),
          child: Column(
            children: [
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C22),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  onChanged: (val) => setState(() => _searchQuery = val),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText: 'Personel adı veya meslek ara...',
                    hintStyle: TextStyle(color: Color(0xFFA1A1AA), fontSize: 14),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFA1A1AA)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildVersionFilterChip('all', 'Tümü ($totalCount)'),
                    const SizedBox(width: 8),
                    _buildVersionFilterChip('v9', '🟢 v9.0 Güncel ($v9Count)'),
                    const SizedBox(width: 8),
                    _buildVersionFilterChip('eski', '🟠 Eski Sürüm ($eskiCount)'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: filteredPersoneller.isEmpty
              ? const Center(child: Text('Kayıtlı personel bulunamadı.', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  itemCount: filteredPersoneller.length,
                  itemBuilder: (context, index) {
                    final p = filteredPersoneller[index];
                    final logs = p['giris_cikis_log'] as List<dynamic>? ?? [];
                    final hakedisler = p['hakedis'] as List<dynamic>? ?? [];
                    final hakedis = hakedisler.isNotEmpty ? hakedisler.first : null;
                    final durum = p['durum'] as String? ?? 'bilinmiyor';
                    
                    return _buildPersonelCard(p, hakedis, durum, logs);
                  },
                ),
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  Widget _buildVersionFilterChip(String filterKey, String label) {
    final isSelected = _versionFilter == filterKey;
    return GestureDetector(
      onTap: () => setState(() => _versionFilter = filterKey),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFE50914) : const Color(0xFF1C1C22),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? const Color(0xFFE50914) : const Color(0xFF334155)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }


  Widget _buildPersonelCard(Map<String, dynamic> p, dynamic hakedis, String durum, List<dynamic> logs) {
    Color statusColor;
    String statusText;
    IconData statusIcon;

    switch (durum) {
      case 'onaylandi':
        statusColor = const Color(0xFF10B981);
        statusText = 'Onaylı';
        statusIcon = Icons.check_circle_outline;
        break;
      case 'banlandi':
        statusColor = const Color(0xFFE50914);
        statusText = 'Banlandı';
        statusIcon = Icons.block;
        break;
      case 'onay_bekliyor':
      default:
        statusColor = const Color(0xFFF59E0B);
        statusText = 'Bekliyor';
        statusIcon = Icons.access_time;
        break;
    }

    final String meslek = p['meslek'] ?? 'Liman İşçisi A';
    final JobDetails jobDetails = UserModel.jobRates[meslek] ?? UserModel.jobRates['Liman İşçisi A']!;
    final double correctTabanMaas = jobDetails.baseSalary;
    final double hakedisAmount = hakedis != null ? (hakedis['guncel_hakedis'] as num).toDouble() : correctTabanMaas;
    final String name = p['ad_soyad'] ?? 'İsimsiz Personel';
    final String initials = _getInitials(name);
    final String shortId = p['id'].toString().length >= 4 ? p['id'].toString().substring(0,4).replaceAll('-', '1') : '1000';
    final bool isVip = p['is_vip'] == true;
    final bool isTelsiz = p['telsiz_yetkisi'] == true;
    final bool isYetkili = p['is_yetkili'] == true || p['yetkili'] == true;
    final String appVer = p['app_version']?.toString() ?? 'v8.0';
    final bool isV9Updated = appVer.contains('9') || ((p['app_version_num'] as num?)?.toInt() ?? 0) >= 9;
    final String updateTime = p['guncelleme_tarihi_str'] ?? '';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C22),
        borderRadius: BorderRadius.circular(16),
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: const BoxDecoration(
          border: Border(left: BorderSide(color: Color(0xFFE50914), width: 4)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            childrenPadding: EdgeInsets.zero,
            iconColor: Colors.white,
            collapsedIconColor: Colors.white,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56, height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE50914),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ),
                          if (isVip)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE50914).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFE50914)),
                                ),
                                child: const Text('VIP', style: TextStyle(color: Color(0xFFE50914), fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          if (isTelsiz)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.radio_rounded, size: 11, color: Color(0xFF10B981)),
                                    SizedBox(width: 3),
                                    Text('TELSİZ', style: TextStyle(color: Color(0xFF10B981), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                          if (isYetkili)
                            Padding(
                              padding: const EdgeInsets.only(left: 6.0),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0xFFDC2626)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: const [
                                    Icon(Icons.shield_rounded, size: 11, color: Color(0xFFDC2626)),
                                    SizedBox(width: 3),
                                    Text('YETKİLİ', style: TextStyle(color: Color(0xFFDC2626), fontSize: 9, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.work_outline, size: 14, color: Color(0xFFA1A1AA)),
                          const SizedBox(width: 4),
                          Text(p['meslek'] ?? 'Belirtilmedi', style: const TextStyle(color: Color(0xFFA1A1AA), fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('ID: 100$shortId • İşe Giriş: 12.03.2022', style: const TextStyle(color: Color(0xFF71717A), fontSize: 11)),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: isV9Updated ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                color: isV9Updated ? const Color(0xFF10B981).withValues(alpha: 0.5) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  isV9Updated ? Icons.verified_rounded : Icons.pending_actions_rounded,
                                  size: 11,
                                  color: isV9Updated ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isV9Updated ? 'v9.0 GÜNCEL' : 'ESKİ SÜRÜM (v8)',
                                  style: TextStyle(
                                    color: isV9Updated ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (updateTime.isNotEmpty) ...[
                            const SizedBox(width: 8),
                            Text(
                              updateTime,
                              style: const TextStyle(color: Color(0xFF71717A), fontSize: 10.5),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            subtitle: Column(
              children: [
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF27272A).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Güncel Hakediş', style: TextStyle(fontSize: 11, color: Color(0xFFA1A1AA))),
                          const SizedBox(height: 4),
                          Text(formatCurrency(hakedisAmount), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                          if (hakedisAmount > correctTabanMaas) ...[
                             const SizedBox(height: 4),
                             Text('+ ${formatCurrency(hakedisAmount - correctTabanMaas)} Mesai', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ]
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3F3F46).withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.description_outlined, size: 16, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Detay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _toggleTelsizYetkisi(p['id'], isTelsiz),
                        icon: Icon(isTelsiz ? Icons.radio_rounded : Icons.radio_button_off_rounded, size: 16, color: Colors.white),
                        label: Text(isTelsiz ? 'Telsiz Açık' : 'Telsiz Ver', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isTelsiz ? const Color(0xFF10B981) : const Color(0xFF334155),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _toggleVipStatus(p['id'], isVip),
                        icon: Icon(isVip ? Icons.star_border : Icons.star, size: 16, color: Colors.white),
                        label: Text(isVip ? 'VIP İptal' : 'VIP Yap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isVip ? const Color(0xFF27272A) : const Color(0xFFE50914),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => _toggleYetkiliStatus(p['id'], isYetkili),
                        icon: Icon(isYetkili ? Icons.security_rounded : Icons.shield_outlined, size: 16, color: Colors.white),
                        label: Text(isYetkili ? 'Yetkili İptal' : 'Yetkili Yap', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: isYetkili ? const Color(0xFF27272A) : const Color(0xFFDC2626),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),

            children: [
              const Divider(height: 1, color: Color(0xFFF1F5F9)),
              if (logs.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Son Giriş/Çıkış Hareketleri', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                      const SizedBox(height: 8),
                      ...(() {
                        final sortedLogs = List<dynamic>.from(logs)..sort((a, b) {
                          try {
                            final dtA = DateTime.parse('${a['tarih']} ${a['saat']}');
                            final dtB = DateTime.parse('${b['tarih']} ${b['saat']}');
                            return dtB.compareTo(dtA);
                          } catch (e) { return 0; }
                        });
                        return sortedLogs.take(3).map((log) {
                          final isGiris = log['islem_tipi'] == 'is_giris';
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6.0),
                            child: Row(
                              children: [
                                Icon(isGiris ? Icons.login_rounded : Icons.logout_rounded, size: 14, color: isGiris ? Colors.green : Colors.red),
                                const SizedBox(width: 8),
                                Text(isGiris ? 'Giriş Yaptı' : 'Çıkış Yaptı', style: TextStyle(fontSize: 12, color: isGiris ? Colors.green : Colors.red, fontWeight: FontWeight.w600)),
                                const Spacer(),
                                Text('${log['tarih']} ${log['saat']}', style: const TextStyle(fontSize: 12, color: Color(0xFF718096))),
                                if (log['latitude'] != null && log['longitude'] != null)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 8.0),
                                    child: GestureDetector(
                                      onTap: () async {
                                        final url = 'https://www.google.com/maps/search/?api=1&query=${log['latitude']},${log['longitude']}';
                                        if (await canLaunchUrl(Uri.parse(url))) {
                                          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      child: const Icon(Icons.location_on, size: 16, color: Colors.blueAccent),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }).toList();
                      })(),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
              // Mesai Detay Bölümü
              if (hakedis != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.access_time_filled_rounded, size: 14, color: Color(0xFF2563EB)),
                          const SizedBox(width: 6),
                          const Text('Mesai Detayları', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF4A5568))),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(hakedis['ay'] ?? '', style: const TextStyle(fontSize: 10, color: Color(0xFF2563EB), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Taban Maaş
                      _buildMesaiRow(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Taban Maaş',
                        value: formatCurrency(correctTabanMaas),
                        color: const Color(0xFF475569),
                      ),
                      const SizedBox(height: 8),
                      // Normal Mesai
                      _buildMesaiRow(
                        icon: Icons.work_history_rounded,
                        label: 'Normal Mesai',
                        days: (hakedis['normal_mesai_gun'] as num?)?.toInt() ?? 0,
                        value: '+ ${formatCurrency(((hakedis['normal_mesai_gun'] as num?)?.toInt() ?? 0) * jobDetails.normalMesaiRate)}',
                        color: const Color(0xFF2563EB),
                      ),
                      const SizedBox(height: 8),
                      // Bayram Mesaisi
                      _buildMesaiRow(
                        icon: Icons.celebration_rounded,
                        label: 'Bayram Mesaisi',
                        days: (hakedis['bayram_mesai_gun'] as num?)?.toInt() ?? 0,
                        value: '+ ${formatCurrency(((hakedis['bayram_mesai_gun'] as num?)?.toInt() ?? 0) * jobDetails.bayramMesaiRate)}',
                        color: const Color(0xFFEA580C),
                      ),
                      const SizedBox(height: 12),
                      // Toplam Çizgisi
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Güncel Hakediş', style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                            Text(formatCurrency(hakedisAmount), style: const TextStyle(color: Color(0xFF10B981), fontSize: 14, fontWeight: FontWeight.w900)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF1F5F9)),
              ],
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (durum == 'onay_bekliyor' || durum == 'banlandi')
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _updateStatus(p['id'], 'onaylandi'),
                          icon: const Icon(Icons.check_circle_rounded),
                          label: const Text('Onayla'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF10B981), foregroundColor: Colors.white, elevation: 0),
                        ),
                      ),
                    if (durum == 'onay_bekliyor' || durum == 'onaylandi')
                      ...[
                        if (durum == 'onay_bekliyor') const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () => _updateStatus(p['id'], 'banlandi'),
                            icon: const Icon(Icons.block_rounded),
                            label: const Text('Banla'),
                            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444), foregroundColor: Colors.white, elevation: 0),
                          ),
                        ),
                      ]
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildMesaiRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    int? days,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF4A5568))),
        if (days != null) ...[
          const SizedBox(width: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text('$days gün', style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold)),
          ),
        ],
        const Spacer(),
        Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }

  Widget _buildDuyurularTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: ElevatedButton.icon(
            onPressed: _showAddDuyuruDialog,
            icon: const Icon(Icons.add),
            label: const Text('Yeni Duyuru Ekle', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4338CA),
              foregroundColor: Colors.white,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 4,
              shadowColor: const Color(0xFF4338CA).withValues(alpha: 0.4),
            ),
          ),
        ),
        Expanded(
          child: _duyurular.isEmpty
              ? const Center(child: Text('Henüz duyuru yok.', style: TextStyle(color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  itemCount: _duyurular.length,
                  itemBuilder: (context, index) {
                    final d = _duyurular[index];
                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey.shade200),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4338CA).withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.campaign_rounded, color: Color(0xFF4338CA), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(d['baslik'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C)))),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            (d['tarih'] ?? '').toString().split('T').first,
                                            style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 12),
                                          ),
                                          IconButton(
                                            onPressed: () => _deleteDuyuru(d['id']),
                                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(d['icerik'] ?? '', style: const TextStyle(color: Color(0xFF4A5568), height: 1.5, fontSize: 13)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}
