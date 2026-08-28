import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ship_data.dart';

class GemilerScreen extends StatefulWidget {
  const GemilerScreen({super.key});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> {
  List<ShipData> _allShips = [];
  String _selectedCategory = 'Rihtimdaki'; // 'Rihtimdaki', 'Demirdeki', 'Beklenen', 'Hepsi'
  String _searchQuery = '';
  bool _isLoading = false;
  String _lastUpdatedText = 'Canlı';

  @override
  void initState() {
    super.initState();
    _allShips = ShipData.getAllShips();
    _allShips.sort((a, b) => a.sortDate.compareTo(b.sortDate));

    _fetchLiveShips();
  }

  Future<void> _fetchLiveShips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .get(Uri.parse('https://isdemir-chat-server.onrender.com/api/ships/live'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['ships'] != null) {
          final List<dynamic> shipList = data['ships'];
          final List<ShipData> parsedShips = shipList.map((item) {
            return ShipData(
              id: item['id']?.toString() ?? '',
              kategori: item['kategori'] ?? 'Rihtimdaki',
              gemiAdi: item['gemiAdi'] ?? '',
              tarihStr: item['tarihStr'] ?? '',
              firmaUlke: item['firmaUlke'] ?? '',
              yukCinsi: item['yukCinsi'] ?? '',
              islem: item['islem'] ?? 'Tahliye',
              miktar: item['miktar'] is int ? item['miktar'] : (int.tryParse(item['miktar'].toString()) ?? 0),
              sortDate: DateTime.now(),
              gemiTipi: item['gemiTipi'] ?? 'Bulk Carrier',
              bayrak: item['bayrak'] ?? '🇹🇷 Türkiye',
              imoNo: item['imoNo'] ?? '',
              iskeleNo: item['iskeleNo'] ?? '',
              progress: (item['progress'] is num) ? (item['progress'] as num).toDouble() : 0.0,
              lat: (item['lat'] is num) ? (item['lat'] as num).toDouble() : 36.7264,
              lng: (item['lng'] is num) ? (item['lng'] as num).toDouble() : 36.1863,
              heading: (item['heading'] is num) ? (item['heading'] as num).toDouble() : 45.0,
              speedKnots: (item['speedKnots'] is num) ? (item['speedKnots'] as num).toDouble() : 0.0,
              durum: item['durum'] ?? 'Aktif',
            );
          }).toList();

          if (mounted) {
            setState(() {
              _allShips = parsedShips;
              final now = DateTime.now();
              _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  int _getShipCount(String category) {
    return _allShips.where((s) => s.kategori == category).length;
  }

  int _getTotalTonnage() {
    return _allShips.fold(0, (sum, ship) => sum + ship.miktar);
  }

  List<ShipData> get _filteredShips {
    return _allShips.where((s) {
      final matchesCategory = _selectedCategory == 'Hepsi' || s.kategori == _selectedCategory;
      final matchesSearch = s.gemiAdi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.firmaUlke.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.yukCinsi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.iskeleNo.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _openVesselFinder() async {
    final uri = Uri.parse('https://www.vesselfinder.com/?bbox=36.170,36.715,36.210,36.740');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMarineTraffic() async {
    final uri = Uri.parse('https://www.marinetraffic.com/en/ais/home/centerx:36.1863/centery:36.7264/zoom:15');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _showShipDetailsModal(ShipData ship) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ShipDetailBottomSheet(ship: ship),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rihtimCount = _getShipCount('Rihtimdaki');
    final demirCount = _getShipCount('Demirdeki');
    final beklenenCount = _getShipCount('Beklenen');
    final totalTon = _getTotalTonnage();

    final fNumber = NumberFormat('#,###', 'tr_TR');

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Uygulama zemin rengi
      body: Stack(
        children: [
          // 1. Üst Koyu İndigo Başlık Alanı
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 220,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF3730A3),
                    Color(0xFF4338CA),
                    Color(0xFF4F46E5),
                  ],
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Üst Buton Çubuğu
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                          Row(
                            children: [
                              // Canlı Güncelleme Rozeti
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 7,
                                      height: 7,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF34D399),
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'AIS CANLI • $_lastUpdatedText',
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),

                              // Yenile Butonu
                              IconButton(
                                onPressed: _isLoading ? null : _fetchLiveShips,
                                icon: _isLoading
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.refresh_rounded, color: Colors.white, size: 22),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),

                              // Canlı Haritalar Menüsü
                              PopupMenuButton<String>(
                                onSelected: (val) {
                                  if (val == 'vf') _openVesselFinder();
                                  if (val == 'mt') _openMarineTraffic();
                                },
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'vf',
                                    child: Row(
                                      children: [
                                        Icon(Icons.map_rounded, color: Color(0xFF4338CA), size: 18),
                                        SizedBox(width: 10),
                                        Text('VesselFinder Haritası', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'mt',
                                    child: Row(
                                      children: [
                                        Icon(Icons.public_rounded, color: Color(0xFF4338CA), size: 18),
                                        SizedBox(width: 10),
                                        Text('MarineTraffic Haritası', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                      ],
                                    ),
                                  ),
                                ],
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.map_outlined, color: Colors.white, size: 14),
                                      SizedBox(width: 4),
                                      Text('Harita', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Başlık & Açıklama
                      const Text(
                        'İsdemir Liman Trafiği',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Gerçek zamanlı rıhtım, demir ve yanaşma operasyonları',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // 2. Ana Kaydırılabilir İçerik Alanı
          Positioned.fill(
            top: 155,
            child: RefreshIndicator(
              onRefresh: _fetchLiveShips,
              color: const Color(0xFF4338CA),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Özet İstatistik Kartı
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _buildPortStatsSummaryCard(rihtimCount, demirCount, beklenenCount, fNumber.format(totalTon)),
                    ),
                  ),

                  // Arama ve Filtreleme Şeridi
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: _buildSearchAndCategorySelector(),
                    ),
                  ),

                  // Gemi Listesi
                  _filteredShips.isEmpty
                      ? SliverToBoxAdapter(
                          child: Container(
                            margin: const EdgeInsets.all(24),
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                Icon(Icons.directions_boat_outlined, size: 54, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'Bu kategoride gemi bulunamadı.',
                                  style: TextStyle(color: Color(0xFF64748B), fontSize: 14, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
                          sliver: SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final ship = _filteredShips[index];
                                return _buildExecutiveShipCard(ship, fNumber);
                              },
                              childCount: _filteredShips.length,
                            ),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ÖZET İSTATİSTİK KARTI (Theme-consistent White Card)
  // ----------------------------------------------------
  Widget _buildPortStatsSummaryCard(int rihtimCount, int demirCount, int beklenenCount, String totalTonStr) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E293B).withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.dock_rounded,
                  iconColor: const Color(0xFF10B981),
                  bgColor: const Color(0xFFECFDF5),
                  title: 'Rıhtımda',
                  value: '$rihtimCount Gemi',
                  subtitle: 'Aktif Operasyon',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.anchor_rounded,
                  iconColor: const Color(0xFFF59E0B),
                  bgColor: const Color(0xFFFFFBEB),
                  title: 'Demirde',
                  value: '$demirCount Gemi',
                  subtitle: 'Sıra Bekliyor',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.sailing_rounded,
                  iconColor: const Color(0xFF0284C7),
                  bgColor: const Color(0xFFF0F9FF),
                  title: 'Beklenen',
                  value: '$beklenenCount Gemi',
                  subtitle: 'Seyir Halinde',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildSummaryMetric(
                  icon: Icons.inventory_2_rounded,
                  iconColor: const Color(0xFF8B5CF6),
                  bgColor: const Color(0xFFF5F3FF),
                  title: 'Toplam Hacim',
                  value: '${(totalTonStr.split('.')[0])}k Ton',
                  subtitle: 'Liman Yükü',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: iconColor.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey.shade700, fontSize: 11, fontWeight: FontWeight.w500)),
                const SizedBox(height: 1),
                Text(value, style: TextStyle(color: Colors.grey.shade900, fontSize: 13, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // ARAMA VE KATEGORİ SEÇİCİ
  // ----------------------------------------------------
  Widget _buildSearchAndCategorySelector() {
    return Column(
      children: [
        // Arama Kutusu
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: TextField(
            style: const TextStyle(fontSize: 14, color: Color(0xFF1E293B)),
            onChanged: (val) => setState(() => _searchQuery = val),
            decoration: InputDecoration(
              hintText: 'Gemi adı, yük türü veya iskele ara...',
              hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF4338CA), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18, color: Colors.grey),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Segmented Kategori Butonları
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryTab('Rihtimdaki', 'Rıhtımda (${_getShipCount('Rihtimdaki')})', const Color(0xFF10B981)),
              const SizedBox(width: 8),
              _buildCategoryTab('Demirdeki', 'Demirde (${_getShipCount('Demirdeki')})', const Color(0xFFF59E0B)),
              const SizedBox(width: 8),
              _buildCategoryTab('Beklenen', 'Beklenen (${_getShipCount('Beklenen')})', const Color(0xFF0284C7)),
              const SizedBox(width: 8),
              _buildCategoryTab('Hepsi', 'Tümü (${_allShips.length})', const Color(0xFF4338CA)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryTab(String key, String title, Color activeColor) {
    final isSelected = _selectedCategory == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedCategory = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF4338CA) : Colors.grey.shade200,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF4338CA).withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF64748B),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PROFESYONEL GEMİ KARTI
  // ----------------------------------------------------
  Widget _buildExecutiveShipCard(ShipData ship, NumberFormat fNumber) {
    final isTahliye = ship.islem == 'Tahliye';
    Color statusColor = const Color(0xFF10B981);
    String statusLabel = 'Rıhtımda Yanaşık';

    if (ship.kategori == 'Demirdeki') {
      statusColor = const Color(0xFFF59E0B);
      statusLabel = 'Demirleme Sahasında';
    } else if (ship.kategori == 'Beklenen') {
      statusColor = const Color(0xFF0284C7);
      statusLabel = 'Seyir / Yaklaşıyor';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Kart Başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Gemi İkonu
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Icon(
                      ship.gemiTipi.contains('Tanker') ? Icons.local_gas_station_rounded : Icons.directions_boat_rounded,
                      color: statusColor,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Gemi Adı ve Tipi
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ship.gemiAdi,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            ship.gemiTipi,
                            style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(width: 6),
                          Text('• ${ship.bayrak}', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                        ],
                      ),
                    ],
                  ),
                ),

                // Tahliye / Yükleme Rozeti
                if (ship.miktar > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTahliye ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isTahliye ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                      ),
                    ),
                    child: Text(
                      ship.islem.toUpperCase(),
                      style: TextStyle(
                        color: isTahliye ? const Color(0xFFDC2626) : const Color(0xFF059669),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFF1F5F9)),

          // Detay Bilgileri
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildCardInfoItem(
                        icon: Icons.place_outlined,
                        label: 'İskele / Konum',
                        value: ship.iskeleNo,
                      ),
                    ),
                    Expanded(
                      child: _buildCardInfoItem(
                        icon: Icons.inventory_2_outlined,
                        label: 'Yük & Miktar',
                        value: '${ship.yukCinsi} ${ship.miktar > 0 ? '(${fNumber.format(ship.miktar)} T)' : ''}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: _buildCardInfoItem(
                        icon: Icons.business_outlined,
                        label: 'Firma / Ülke',
                        value: ship.firmaUlke,
                      ),
                    ),
                    Expanded(
                      child: _buildCardInfoItem(
                        icon: Icons.access_time_rounded,
                        label: 'Tarih / Durum',
                        value: ship.tarihStr,
                      ),
                    ),
                  ],
                ),

                // Rıhtımdaki İlerleme Çubuğu
                if (ship.kategori == 'Rihtimdaki' && ship.progress > 0) ...[
                  const SizedBox(height: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            ship.durum,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669)),
                          ),
                          Text(
                            '%${(ship.progress * 100).toInt()}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: ship.progress,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE2E8F0),
                          valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Alt Butonlar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFFF8FAFC),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(18)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.sensors_rounded, size: 14, color: statusColor),
                    const SizedBox(width: 6),
                    Text(
                      statusLabel,
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                    ),
                  ],
                ),
                TextButton.icon(
                  onPressed: () => _showShipDetailsModal(ship),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  ),
                  icon: const Icon(Icons.info_outline_rounded, size: 15),
                  label: const Text('Detaylar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardInfoItem({required IconData icon, required String label, required String value}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8))),
              const SizedBox(height: 1),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// DETAY BOTTOM SHEET (Modern Clean Style)
// ----------------------------------------------------
class _ShipDetailBottomSheet extends StatelessWidget {
  final ShipData ship;

  const _ShipDetailBottomSheet({required this.ship});

  @override
  Widget build(BuildContext context) {
    final isTahliye = ship.islem == 'Tahliye';
    final fNumber = NumberFormat('#,###', 'tr_TR');

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF4338CA), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ship.gemiAdi,
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ship.gemiTipi} • ${ship.imoNo}',
                      style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isTahliye ? const Color(0xFFFEF2F2) : const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isTahliye ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                  ),
                ),
                child: Text(
                  ship.islem.toUpperCase(),
                  style: TextStyle(
                    color: isTahliye ? const Color(0xFFDC2626) : const Color(0xFF059669),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Color(0xFF10B981), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANLI AIS DURUMU', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(ship.durum, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(
                  '${ship.speedKnots} kn',
                  style: const TextStyle(color: Color(0xFF4338CA), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildModalDetailRow('Bayrak', ship.bayrak, 'İskele / Rıhtım', ship.iskeleNo),
          const SizedBox(height: 12),
          _buildModalDetailRow('Yük Cinsi', ship.yukCinsi, 'Miktar', ship.miktar > 0 ? '${fNumber.format(ship.miktar)} Ton' : 'Liman Hizmeti'),
          const SizedBox(height: 12),
          _buildModalDetailRow('Firma / Menşei', ship.firmaUlke, 'Tarih / Laycan', ship.tarihStr),
          const SizedBox(height: 12),
          _buildModalDetailRow('Koordinat', '${ship.lat.toStringAsFixed(4)}° N, ${ship.lng.toStringAsFixed(4)}° E', 'Rota (Heading)', '${ship.heading.toInt()}°'),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final query = Uri.encodeComponent(ship.gemiAdi.split('/')[0].trim());
                    final uri = Uri.parse('https://www.vesselfinder.com/vessels?name=$query');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4338CA),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.map_rounded, size: 16),
                  label: const Text('VesselFinder Haritası', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final query = Uri.encodeComponent(ship.gemiAdi.split('/')[0].trim());
                    final uri = Uri.parse('https://www.marinetraffic.com/en/ais/index/search/all/keyword:$query');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4338CA),
                    side: const BorderSide(color: Color(0xFF4338CA)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.public, size: 16),
                  label: const Text('MarineTraffic', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModalDetailRow(String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val1, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val2, style: const TextStyle(color: Color(0xFF1E293B), fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
