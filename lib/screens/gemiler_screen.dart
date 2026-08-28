import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;
import '../models/ship_data.dart';

class GemilerScreen extends StatefulWidget {
  const GemilerScreen({super.key});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> with SingleTickerProviderStateMixin {
  List<ShipData> _allShips = [];
  String _searchQuery = '';
  bool _isLoading = false;
  bool _isRadarExpanded = false; // Varsayılan kapalı, tıklanınca açılır
  String _lastUpdatedText = '18:19:49 (Canlı AIS)';

  late AnimationController _radarAnimController;

  @override
  void initState() {
    super.initState();
    _allShips = ShipData.getAllShips();
    _allShips.sort((a, b) => a.sortDate.compareTo(b.sortDate));

    _radarAnimController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _fetchLiveShips();
  }

  @override
  void dispose() {
    _radarAnimController.dispose();
    super.dispose();
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
              _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Canlı AIS)';
            });
          }
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          final now = DateTime.now();
          _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Canlı AIS)';
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
      final matchesSearch = s.gemiAdi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.firmaUlke.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.yukCinsi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.iskeleNo.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
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
      backgroundColor: const Color(0xFF060B14), // Tam karanlık modern uzay mavisi zemin
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchLiveShips,
          color: const Color(0xFF00E5FF),
          backgroundColor: const Color(0xFF0F1E36),
          child: Column(
            children: [
              // 1. Üst Başlık Çubuğu
              _buildTopAppBar(),

              // Ana Kaydırılabilir İçerik
              Expanded(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 2. İsdemir Liman Radarı Açılır Kartı
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                        child: _buildRadarCollapsibleCard(),
                      ),
                    ),

                    // 3. Liman İstatistik Şeridi (Rıhtımda, Demirde, Beklenen, Hacim)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildPortStatsBar(rihtimCount, demirCount, beklenenCount, fNumber.format(totalTon)),
                      ),
                    ),

                    // 4. Arama Çubuğu
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                        child: _buildSearchBar(),
                      ),
                    ),

                    // 5. Gemi Listesi
                    _filteredShips.isEmpty
                        ? SliverToBoxAdapter(
                            child: Container(
                              padding: const EdgeInsets.all(40),
                              alignment: Alignment.center,
                              child: Column(
                                children: [
                                  Icon(Icons.directions_boat_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'Gemi bulunamadı.',
                                    style: TextStyle(color: Colors.white60, fontSize: 14),
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
                                  return _buildVesselCard(ship, fNumber);
                                },
                                childCount: _filteredShips.length,
                              ),
                            ),
                          ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // ÜST BAŞLIK ÇUBUĞU (Screenshot Exact Match)
  // ----------------------------------------------------
  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A1220),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.06))),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 14),

          // Yuvarlak Radar İkonu
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFF0F2642),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.4), width: 1.5),
            ),
            child: const Center(
              child: Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 20),
            ),
          ),
          const SizedBox(width: 12),

          // Liman Başlığı & Canlı Bilgisi
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'İSDEMİR LİMANI',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF064E3B),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.6)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'CANLI',
                            style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.w900),
                          ),
                          SizedBox(width: 3),
                          Text('•', style: TextStyle(color: Color(0xFF34D399), fontSize: 9)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                const Text(
                  '36.7264° K, 36.1863° D',
                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
                Text(
                  _lastUpdatedText,
                  style: const TextStyle(color: Color(0xFF64748B), fontSize: 10),
                ),
              ],
            ),
          ),

          // Yenile İkonu
          IconButton(
            onPressed: _isLoading ? null : _fetchLiveShips,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF00E5FF), size: 22),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),

          // Harita Açılır Butonu
          PopupMenuButton<String>(
            onSelected: (val) {
              if (val == 'vf') _openVesselFinder();
              if (val == 'mt') _openMarineTraffic();
            },
            color: const Color(0xFF0F1E36),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'vf',
                child: Row(
                  children: [
                    Icon(Icons.map_rounded, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 10),
                    Text('VesselFinder Haritası', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mt',
                child: Row(
                  children: [
                    Icon(Icons.public_rounded, color: Color(0xFF00E5FF), size: 18),
                    SizedBox(width: 10),
                    Text('MarineTraffic Haritası', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0C2744),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_book_rounded, color: Color(0xFF00E5FF), size: 14),
                  SizedBox(width: 5),
                  Text('Harita', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                  SizedBox(width: 2),
                  Icon(Icons.arrow_drop_down, color: Colors.white70, size: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // RADAR AÇILIR PANELİ (Collapsible Radar Bar)
  // ----------------------------------------------------
  Widget _buildRadarCollapsibleCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.radar_rounded, color: Color(0xFF00E5FF), size: 18),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'İsdemir Liman Radarı (VesselFinder Canlı)',
                      style: TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _isRadarExpanded = !_isRadarExpanded;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF132238),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isRadarExpanded ? 'Gizle' : 'Genişlet',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          _isRadarExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: Colors.white70,
                          size: 14,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isRadarExpanded) ...[
            ClipRRect(
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
              child: SizedBox(
                height: 220,
                width: double.infinity,
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _radarAnimController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: _IsdemirPortRadarPainter(
                            sweepAngle: _radarAnimController.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),

                    // Canlı Gemiler
                    ..._allShips.map((ship) {
                      return _buildRadarShipMarker(ship);
                    }),

                    // Sol Alt Koordinat
                    Positioned(
                      left: 10,
                      bottom: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'LAT: 36.72641° N • LON: 36.18631° E',
                          style: TextStyle(color: Color(0xFF00E5FF), fontSize: 9, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRadarShipMarker(ShipData ship) {
    double top = 0;
    double left = 0;
    Color shipColor = const Color(0xFFEAB308);

    if (ship.gemiAdi.contains('CHEMICAL EXPLORER')) {
      shipColor = const Color(0xFFF97316);
      top = 120;
      left = 35;
    } else if (ship.gemiAdi.contains('IONIC SPIRIT')) {
      shipColor = const Color(0xFFEAB308);
      top = 90;
      left = 110;
    } else if (ship.gemiAdi.contains('GALA A')) {
      shipColor = const Color(0xFFEAB308);
      top = 110;
      left = 135;
    } else if (ship.gemiAdi.contains('GOLDEN SHARK')) {
      shipColor = const Color(0xFFEAB308);
      top = 140;
      left = 130;
    } else if (ship.gemiAdi.contains('MED') || ship.gemiAdi.contains('PILOT')) {
      shipColor = const Color(0xFF10B981);
      top = 130;
      left = 75;
    } else if (ship.gemiAdi.contains('BORA') || ship.gemiAdi.contains('AKKALE')) {
      shipColor = const Color(0xFF06B6D4);
      top = 125;
      left = 160;
    } else {
      shipColor = const Color(0xFF10B981);
      top = 135;
      left = 120;
    }

    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () => _showShipDetailsModal(ship),
        child: Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: shipColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: shipColor.withValues(alpha: 0.8),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.navigation_rounded, color: Colors.black87, size: 8),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // İSTATİSTİK ŞERİDİ (Screenshot Exact 4 Metrics)
  // ----------------------------------------------------
  Widget _buildPortStatsBar(int rihtimCount, int demirCount, int beklenenCount, String totalTonStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Rıhtımda', '$rihtimCount', 'Gemi', const Color(0xFF10B981), Icons.location_on_rounded),
          ),
          Container(width: 1, height: 40, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Demirde', '$demirCount', 'Gemi', const Color(0xFFF59E0B), Icons.anchor_rounded),
          ),
          Container(width: 1, height: 40, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Beklenen', '$beklenenCount', 'Gemi', const Color(0xFF00E5FF), Icons.access_time_filled_rounded),
          ),
          Container(width: 1, height: 40, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Hacim', '${(totalTonStr.split('.')[0])}k', 'Ton', const Color(0xFFA855F7), Icons.inventory_2_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
        ),
        Text(
          unit,
          style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 9.5, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  // ----------------------------------------------------
  // ARAMA ÇUBUĞU
  // ----------------------------------------------------
  Widget _buildSearchBar() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: TextField(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        onChanged: (val) => setState(() => _searchQuery = val),
        decoration: InputDecoration(
          hintText: 'Gemi adı, yük cinsi, iskele veya ülke ara...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 18),
          suffixIcon: const Icon(Icons.tune_rounded, color: Color(0xFF00E5FF), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PROFESYONEL GEMİ KARTI (Screenshot Exact Match)
  // ----------------------------------------------------
  Widget _buildVesselCard(ShipData ship, NumberFormat fNumber) {
    final isTahliye = ship.islem == 'Tahliye';

    // Sol taraftaki fotoğraf seçimi
    String assetImage = 'assets/images/vessel_tanker.jpg';
    Color glowDotColor = const Color(0xFF10B981); // Rıhtım yeşili

    if (ship.gemiAdi.contains('CHEMICAL EXPLORER')) {
      assetImage = 'assets/images/vessel_tanker.jpg';
      glowDotColor = const Color(0xFF10B981);
    } else if (ship.gemiAdi.contains('IONIC SPIRIT')) {
      assetImage = 'assets/images/vessel_bulk.jpg';
      glowDotColor = const Color(0xFFF59E0B);
    } else if (ship.gemiAdi.contains('GALA A')) {
      assetImage = 'assets/images/vessel_cargo.jpg';
      glowDotColor = const Color(0xFF00E5FF);
    } else if (ship.gemiAdi.contains('GOLDEN SHARK')) {
      assetImage = 'assets/images/vessel_bulk.jpg';
      glowDotColor = const Color(0xFFEAB308);
    } else {
      assetImage = 'assets/images/vessel_cargo.jpg';
      glowDotColor = const Color(0xFF10B981);
    }

    return GestureDetector(
      onTap: () => _showShipDetailsModal(ship),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E3A5F)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. SOL TARAF: Gemi Fotoğrafı + Sol Üst Parlayan Nokta
                SizedBox(
                  width: 105,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        assetImage,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: const Color(0xFF0F1E36),
                            child: const Center(
                              child: Icon(Icons.directions_boat_rounded, color: Color(0xFF00E5FF), size: 36),
                            ),
                          );
                        },
                      ),
                      // Fotoğrafın sağ kenarına yumuşak karanlık geçiş
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.transparent,
                              const Color(0xFF0B1424).withValues(alpha: 0.7),
                            ],
                          ),
                        ),
                      ),
                      // Sol Üst Köşe Parlayan Durum Noktası
                      Positioned(
                        top: 10,
                        left: 10,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: glowDotColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: glowDotColor.withValues(alpha: 0.9),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. SAĞ TARAF: Gemi Bilgileri ve 2x2 Izgara
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Üst Satır: İkon + Gemi Adı + YÜKLEME/TAHLİYE Rozeti
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: isTahliye ? const Color(0xFF7F1D1D).withValues(alpha: 0.4) : const Color(0xFF064E3B).withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.directions_boat_filled_rounded,
                                color: isTahliye ? const Color(0xFFF87171) : const Color(0xFF34D399),
                                size: 14,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    ship.gemiAdi,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  Text(
                                    '${ship.gemiTipi} • ${ship.bayrak}',
                                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                color: isTahliye ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : const Color(0xFF064E3B).withValues(alpha: 0.8),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: isTahliye ? const Color(0xFFDC2626).withValues(alpha: 0.6) : const Color(0xFF10B981).withValues(alpha: 0.6),
                                ),
                              ),
                              child: Text(
                                ship.islem.toUpperCase(),
                                style: TextStyle(
                                  color: isTahliye ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 10),

                        // 2x2 Izgara
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.location_on_rounded,
                                iconColor: const Color(0xFF00E5FF),
                                title: 'KONUM / İSKELE',
                                value: ship.iskeleNo,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.inventory_2_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'YÜK CİNSİ & MİKTAR',
                                value: '${ship.yukCinsi} ${ship.miktar > 0 ? '(${fNumber.format(ship.miktar)} Ton)' : ''}',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.calendar_today_rounded,
                                iconColor: const Color(0xFFA855F7),
                                title: 'TARİH / DURUM',
                                value: ship.tarihStr,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.business_rounded,
                                iconColor: const Color(0xFF94A3B8),
                                title: 'FİRMA / MENŞEİ',
                                value: ship.firmaUlke,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGridItem({required IconData icon, required Color iconColor, required String title, required String value}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 10, color: iconColor),
            const SizedBox(width: 3),
            Text(
              title,
              style: const TextStyle(color: Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// RADAR PAINTER
// ----------------------------------------------------
class _IsdemirPortRadarPainter extends CustomPainter {
  final double sweepAngle;

  _IsdemirPortRadarPainter({required this.sweepAngle});

  @override
  void paint(Canvas canvas, Size size) {
    final seaRect = Rect.fromLTWH(0, 0, size.width, size.height);
    final seaPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.2, 0.4),
        radius: 1.2,
        colors: const [
          Color(0xFF0F2744),
          Color(0xFF070F1A),
        ],
      ).createShader(seaRect);
    canvas.drawRect(seaRect, seaPaint);

    final landPaint = Paint()
      ..color = const Color(0xFF132238)
      ..style = PaintingStyle.fill;

    final landStroke = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final portPath = Path();
    portPath.moveTo(0, 0);
    portPath.lineTo(size.width * 0.35, 0);
    portPath.lineTo(size.width * 0.30, size.height * 0.45);
    
    // Dış İskele
    portPath.lineTo(size.width * 0.12, size.height * 0.56);
    portPath.lineTo(size.width * 0.14, size.height * 0.60);
    portPath.lineTo(size.width * 0.32, size.height * 0.50);
    
    // İç Rıhtım
    portPath.lineTo(size.width * 0.38, size.height * 0.68);
    portPath.lineTo(size.width * 0.44, size.height * 0.62);
    portPath.lineTo(size.width * 0.48, size.height * 0.72);
    portPath.lineTo(size.width * 0.42, size.height * 0.80);
    
    // Dalgakıran
    portPath.lineTo(size.width * 0.30, size.height * 0.88);
    portPath.lineTo(size.width * 0.32, size.height * 0.92);
    portPath.lineTo(size.width * 0.48, size.height * 0.85);
    portPath.lineTo(size.width * 0.52, size.height * 1.0);
    portPath.lineTo(0, size.height);
    portPath.close();

    canvas.drawPath(portPath, landPaint);
    canvas.drawPath(portPath, landStroke);

    // Sonar Halkaları
    final radarCenter = Offset(size.width * 0.38, size.height * 0.52);
    final ringPaint = Paint()
      ..color = const Color(0xFF00E5FF).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = 35; r <= 160; r += 40) {
      canvas.drawCircle(radarCenter, r, ringPaint);
    }

    // Tarama Işını
    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: const Alignment(-0.24, 0.04),
        startAngle: 0.0,
        endAngle: math.pi / 3,
        transform: GradientRotation(sweepAngle),
        colors: [
          const Color(0xFF00E5FF).withValues(alpha: 0.4),
          const Color(0xFF00E5FF).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: radarCenter, radius: 160));

    canvas.drawCircle(radarCenter, 160, sweepPaint);
  }

  @override
  bool shouldRepaint(covariant _IsdemirPortRadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}

// ----------------------------------------------------
// CANLI GEMİ DETAY MODAL BOTTOM SHEET
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
        color: Color(0xFF0B1424),
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
                color: Colors.white.withValues(alpha: 0.2),
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
                  color: const Color(0xFF0C2744),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF00E5FF), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ship.gemiAdi,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${ship.gemiTipi} • ${ship.imoNo}',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: isTahliye ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ship.islem.toUpperCase(),
                  style: TextStyle(
                    color: isTahliye ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7),
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
              color: const Color(0xFF070E1A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E3A5F)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Color(0xFF34D399), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANLI AIS KONUMU', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${ship.lat.toStringAsFixed(4)}° N, ${ship.lng.toStringAsFixed(4)}° E', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(
                  '${ship.speedKnots} kn',
                  style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildDetailRow('Bayrak', ship.bayrak, 'İskele / Rıhtım', ship.iskeleNo),
          const SizedBox(height: 12),
          _buildDetailRow('Yük Cinsi', ship.yukCinsi, 'Miktar', ship.miktar > 0 ? '${fNumber.format(ship.miktar)} Ton' : 'Liman Hizmeti'),
          const SizedBox(height: 12),
          _buildDetailRow('Firma / Menşei', ship.firmaUlke, 'Tarih / Laycan', ship.tarihStr),

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
                    backgroundColor: const Color(0xFF0C2744),
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: const Text('VesselFinder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final query = Uri.encodeComponent(ship.gemiAdi.split('/')[0].trim());
                    final uri = Uri.parse('https://www.marinetraffic.com/en/ais/index/search/all/keyword:$query');
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0C2744),
                    foregroundColor: const Color(0xFF00E5FF),
                    side: const BorderSide(color: Color(0xFF00E5FF)),
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

  Widget _buildDetailRow(String label1, String val1, String label2, String val2) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label1, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val1, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
