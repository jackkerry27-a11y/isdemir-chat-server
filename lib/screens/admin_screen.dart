import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/user_model.dart';

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
      final client = Supabase.instance.client;
      
      final personelResponse = await client.from('personel').select('''
        id, ad_soyad, taban_maas, durum, meslek,
        giris_cikis_log(tarih, islem_tipi, saat),
        hakedis(normal_mesai_gun, bayram_mesai_gun, guncel_hakedis, ay)
      ''').order('durum', ascending: false);
      
      final duyurularResponse = await client.from('duyurular').select().order('tarih', ascending: false);

      setState(() {
        _personeller = List<Map<String, dynamic>>.from(personelResponse);
        _duyurular = List<Map<String, dynamic>>.from(duyurularResponse);
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
      await Supabase.instance.client.from('personel').update({'durum': newStatus}).eq('id', id);
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Durum güncellendi.')));
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
                  await Supabase.instance.client.from('duyurular').insert({
                    'baslik': titleController.text,
                    'icerik': contentController.text,
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
        await Supabase.instance.client.from('duyurular').delete().eq('id', id);
        _fetchData();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Duyuru silindi.')));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
      }
    }
  }

  Future<void> sendPushNotification(String title, String content) async {
    var url = Uri.parse('https://onesignal.com/api/v1/notifications');
    await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': 'Basic ${const String.fromEnvironment('ONESIGNAL_API_KEY', defaultValue: 'YOUR_ONESIGNAL_KEY_HERE')}',
      },
      body: json.encode({
        'app_id': '74f25810-49aa-4dd1-938c-c30229368a63',
        'headings': {'en': title, 'tr': title},
        'contents': {'en': content, 'tr': content},
        'included_segments': ['Total Subscriptions'],
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF4338CA)))
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
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Yeni personel ekleme
        },
        backgroundColor: Colors.white,
        elevation: 4,
        icon: const Icon(Icons.add_circle, color: Color(0xFF4338CA)),
        label: const Text('Yeni Personel Ekle', style: TextStyle(color: Color(0xFF4338CA), fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, left: 24, right: 24, bottom: 0),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E1065), Color(0xFF4338CA), Color(0xFF3B82F6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
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
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.people_alt, color: Colors.white, size: 28),
              )
            ],
          ),
          const SizedBox(height: 24),
          TabBar(
            controller: _tabController,
            indicator: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            indicatorPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: -16),
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            dividerColor: Colors.transparent,
            tabs: const [
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.people, size: 20),
                    SizedBox(width: 8),
                    Text('Personeller', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.campaign, size: 20),
                    SizedBox(width: 8),
                    Text('Duyurular', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildPersonelTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                    ],
                  ),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Personel ara...',
                      hintStyle: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 14),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFFA0AEC0)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 48,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Row(
                  children: const [
                    Icon(Icons.filter_list, color: Color(0xFF4338CA), size: 20),
                    SizedBox(width: 8),
                    Text('Filtrele', style: TextStyle(color: Color(0xFF1A202C), fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
              )
            ],
          ),
        ),
        Expanded(
          child: _personeller.isEmpty
              ? const Center(child: Text('Kayıtlı personel bulunamadı.', style: TextStyle(fontSize: 16, color: Colors.grey)))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                  itemCount: _personeller.length,
                  itemBuilder: (context, index) {
                    final p = _personeller[index];
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
        statusColor = const Color(0xFFEF4444);
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
    // Rastgele sahte ID görseli
    final String shortId = p['id'].toString().length >= 4 ? p['id'].toString().substring(0,4).replaceAll('-', '1') : '1000';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 15, offset: const Offset(0, 4)),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: statusColor, width: 4)),
        ),
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding: const EdgeInsets.all(16),
            childrenPadding: EdgeInsets.zero,
            title: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                Container(
                  width: 56, height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(initials, style: TextStyle(color: statusColor, fontSize: 20, fontWeight: FontWeight.bold)),
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
                          Expanded(child: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1A202C)))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(statusIcon, size: 12, color: statusColor),
                                const SizedBox(width: 4),
                                Text(statusText, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          )
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.work_outline, size: 14, color: Color(0xFF718096)),
                          const SizedBox(width: 4),
                          Text(p['meslek'] ?? 'Belirtilmedi', style: const TextStyle(color: Color(0xFF4A5568), fontSize: 13)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text('ID: 100$shortId • İşe Giriş: 12.03.2022', style: const TextStyle(color: Color(0xFFA0AEC0), fontSize: 11)),
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
                    color: statusColor.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Güncel Hakediş', style: TextStyle(fontSize: 11, color: Color(0xFF718096))),
                          const SizedBox(height: 4),
                          Text(formatCurrency(hakedisAmount), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: statusColor)),
                          if (hakedisAmount > correctTabanMaas) ...[
                             const SizedBox(height: 4),
                             Text('+ ${formatCurrency(hakedisAmount - correctTabanMaas)} Mesai', style: const TextStyle(fontSize: 11, color: Color(0xFF10B981), fontWeight: FontWeight.bold)),
                          ]
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2))],
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.description_outlined, size: 16, color: Color(0xFF4A5568)),
                            SizedBox(width: 6),
                            Text('Detay', style: TextStyle(color: Color(0xFF1A202C), fontWeight: FontWeight.bold, fontSize: 13)),
                          ],
                        ),
                      )
                    ],
                  ),
                ),
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
