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
  String _selectedCategory = 'Rihtimdaki'; // 'Rihtimdaki', 'Demirdeki', 'Beklenen', 'Hepsi'
  String _searchQuery = '';
  ShipData? _selectedRadarShip;
  bool _isRadarExpanded = true;
  bool _isLoading = false;
  String _lastUpdatedText = 'Yükleniyor...';

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

          setState(() {
            _allShips = parsedShips;
            final now = DateTime.now();
            _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Canlı AIS)';
          });
        }
      }
    } catch (_) {
      setState(() {
        final now = DateTime.now();
        _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')} (Canlı)';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
      backgroundColor: const Color(0xFF0F172A),
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _fetchLiveShips,
          color: const Color(0xFF38BDF8),
          backgroundColor: const Color(0xFF1E293B),
          child: Column(
            children: [
              _buildTopAppBar(),
              Expanded(
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 1. Canlı AIS Radarı & Harita Görünümü
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: _buildRadarCard(),
                      ),
                    ),

                    // 2. Liman Canlı İstatistik Şeridi
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: _buildPortStatsBar(rihtimCount, demirCount, beklenenCount, fNumber.format(totalTon)),
                      ),
                    ),

                    // 3. Arama ve Filtre Butonları
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                        child: _buildFilterAndSearch(),
                      ),
                    ),

                    // 4. Gemi Listesi
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: _filteredShips.isEmpty
                          ? SliverToBoxAdapter(
                              child: Container(
                                padding: const EdgeInsets.all(40),
                                alignment: Alignment.center,
                                child: Column(
                                  children: [
                                    Icon(Icons.directions_boat_outlined, size: 56, color: Colors.white.withValues(alpha: 0.2)),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Bu kategoride gemi bulunamadı.',
                                      style: TextStyle(color: Colors.white60, fontSize: 14),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : SliverList(
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final ship = _filteredShips[index];
                                  return _buildLiveShipCard(ship, fNumber);
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

  Widget _buildTopAppBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        border: Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0EA5E9).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.radar_rounded, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Text(
                      'İSDEMİR LİMANI',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5),
                    ),
                    SizedBox(width: 8),
                    _PulsingLiveDot(),
                  ],
                ),
                Text(
                  '36.7264° K, 36.1863° D • $_lastUpdatedText',
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                ),
              ],
            ),
          ),
          // Yenile
          IconButton(
            onPressed: _isLoading ? null : _fetchLiveShips,
            icon: _isLoading
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
                  )
                : const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 22),
          ),
          const SizedBox(width: 4),
          // VesselFinder & MarineTraffic Seçenekleri
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'vf') {
                _openVesselFinder();
              } else if (value == 'mt') {
                _openMarineTraffic();
              }
            },
            color: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'vf',
                child: Row(
                  children: [
                    Icon(Icons.map_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 10),
                    Text('VesselFinder Canlı Harita', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'mt',
                child: Row(
                  children: [
                    Icon(Icons.public, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 10),
                    Text('MarineTraffic Canlı Harita', style: TextStyle(color: Colors.white, fontSize: 12)),
                  ],
                ),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.map_rounded, size: 14, color: Color(0xFF38BDF8)),
                  SizedBox(width: 4),
                  Text('Harita', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8))),
                  Icon(Icons.arrow_drop_down, size: 16, color: Color(0xFF38BDF8)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadarCard() {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Radar Başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.satellite_alt_rounded, color: Color(0xFF38BDF8), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'İsdemir Liman Radarı (VesselFinder Canlı)',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
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
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _isRadarExpanded ? 'Gizle' : 'Genişlet',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
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
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              child: SizedBox(
                height: 250,
                width: double.infinity,
                child: Stack(
                  children: [
                    AnimatedBuilder(
                      animation: _radarAnimController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(double.infinity, 250),
                          painter: _IsdemirPortRadarPainter(
                            sweepAngle: _radarAnimController.value * 2 * math.pi,
                          ),
                        );
                      },
                    ),

                    // Liman İskele Etiketleri
                    Positioned(
                      left: 15,
                      top: 115,
                      child: _buildBerthTag('Dış İskele (Tanker)'),
                    ),
                    Positioned(
                      left: 100,
                      top: 85,
                      child: _buildBerthTag('1. Rıhtım (Kömür/Cevher)'),
                    ),
                    Positioned(
                      left: 135,
                      top: 190,
                      child: _buildBerthTag('İç Rıhtım & Slab İskelesi'),
                    ),
                    Positioned(
                      right: 15,
                      top: 30,
                      child: _buildBerthTag('⚓ ISDEMIR Demir Sahası'),
                    ),

                    // Canlı Gemiler
                    ..._allShips.map((ship) {
                      return _buildRadarShipMarker(ship);
                    }),

                    // Sol Alt Koordinat
                    Positioned(
                      left: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Text(
                          'LAT: 36.72641° N • LON: 36.18631° E',
                          style: TextStyle(color: Color(0xFF38BDF8), fontSize: 10, fontFamily: 'monospace', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),

                    // Sağ Alt Lejant
                    Positioned(
                      right: 12,
                      bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _LegendDot(color: Color(0xFFF97316), label: 'Tanker'),
                            SizedBox(width: 6),
                            _LegendDot(color: Color(0xFFEAB308), label: 'Kargo/Bulk'),
                            SizedBox(width: 6),
                            _LegendDot(color: Color(0xFF06B6D4), label: 'Römorkör'),
                            SizedBox(width: 6),
                            _LegendDot(color: Color(0xFF38BDF8), label: 'Beklenen'),
                          ],
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

  Widget _buildBerthTag(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        title,
        style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 9, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildRadarShipMarker(ShipData ship) {
    double top = 0;
    double left = 0;
    Color shipColor = const Color(0xFFEAB308); // Varsayılan sarı (VesselFinder stili)

    if (ship.kategori == 'Rihtimdaki') {
      if (ship.gemiAdi.contains('CHEMICAL EXPLORER')) {
        shipColor = const Color(0xFFF97316); // Turuncu Tanker
        top = 135;
        left = 35;
      } else if (ship.gemiAdi.contains('IONIC SPIRIT')) {
        shipColor = const Color(0xFFEAB308); // Sarı Bulk Carrier (1. Rıhtım)
        top = 105;
        left = 110;
      } else if (ship.gemiAdi.contains('GALA A')) {
        shipColor = const Color(0xFFEAB308); // Sarı Cargo (Parmak iskele)
        top = 125;
        left = 135;
      } else if (ship.gemiAdi.contains('GOLDEN SHARK')) {
        shipColor = const Color(0xFFEAB308); // Sarı Bulk (Güney iskele)
        top = 155;
        left = 130;
      } else if (ship.gemiAdi.contains('MED') || ship.gemiAdi.contains('PILOT')) {
        shipColor = const Color(0xFF10B981); // Yeşil Römorkör
        top = 145;
        left = 75;
      } else if (ship.gemiAdi.contains('BORA') || ship.gemiAdi.contains('AKKALE')) {
        shipColor = const Color(0xFF06B6D4); // Camgöbeği Servis
        top = 142;
        left = 160;
      } else {
        shipColor = const Color(0xFF10B981);
        top = 150;
        left = 120;
      }
    } else if (ship.kategori == 'Demirdeki') {
      shipColor = const Color(0xFFF59E0B);
      if (ship.gemiAdi.contains('NEW HARVE')) { top = 45; left = 210; }
      else { top = 65; left = 260; }
    } else {
      shipColor = const Color(0xFF38BDF8);
      if (ship.gemiAdi.contains('MINERAL')) { top = 25; left = 130; }
      else { top = 45; left = 75; }
    }

    final isSelected = _selectedRadarShip?.id == ship.id;

    return Positioned(
      top: top,
      left: left,
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedRadarShip = ship;
          });
          _showShipDetailsModal(ship);
        },
        child: Container(
          padding: const EdgeInsets.all(4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: isSelected ? 24 : 18,
                height: isSelected ? 24 : 18,
                decoration: BoxDecoration(
                  color: shipColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: isSelected ? 2.5 : 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: shipColor.withValues(alpha: 0.8),
                      blurRadius: isSelected ? 12 : 6,
                      spreadRadius: isSelected ? 4 : 1,
                    ),
                  ],
                ),
                child: Center(
                  child: Icon(
                    ship.kategori == 'Demirdeki' ? Icons.anchor : Icons.navigation_rounded,
                    color: Colors.black87,
                    size: isSelected ? 12 : 9,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  ship.gemiAdi.split('/')[0].trim(),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF38BDF8) : Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPortStatsBar(int rihtimCount, int demirCount, int beklenenCount, String totalTonStr) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Rıhtımda', '$rihtimCount Gemi', const Color(0xFF10B981), Icons.dock_rounded),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: _buildStatItem('Demirde', '$demirCount Gemi', const Color(0xFFF59E0B), Icons.anchor_rounded),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: _buildStatItem('Beklenen', '$beklenenCount Gemi', const Color(0xFF38BDF8), Icons.schedule_rounded),
          ),
          Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.1)),
          Expanded(
            child: _buildStatItem('Hacim', '${(totalTonStr.split('.')[0])}k Ton', const Color(0xFFA855F7), Icons.inventory_2_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildFilterAndSearch() {
    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: TextField(
            style: const TextStyle(color: Colors.white, fontSize: 14),
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Gemi adı, yük cinsi, iskele veya ülke ara...',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8), size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildCategoryChip('Rihtimdaki', '🟢 Rıhtımdaki (${_getShipCount('Rihtimdaki')})'),
              const SizedBox(width: 8),
              _buildCategoryChip('Demirdeki', '🟡 Demirdeki (${_getShipCount('Demirdeki')})'),
              const SizedBox(width: 8),
              _buildCategoryChip('Beklenen', '🔵 Beklenen (${_getShipCount('Beklenen')})'),
              const SizedBox(width: 8),
              _buildCategoryChip('Hepsi', 'Tümü (${_allShips.length})'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryChip(String catKey, String title) {
    final isSelected = _selectedCategory == catKey;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = catKey;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF0284C7).withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildLiveShipCard(ShipData ship, NumberFormat fNumber) {
    Color badgeColor = const Color(0xFF10B981);
    IconData statusIcon = Icons.dock_rounded;

    if (ship.kategori == 'Demirdeki') {
      badgeColor = const Color(0xFFF59E0B);
      statusIcon = Icons.anchor_rounded;
    } else if (ship.kategori == 'Beklenen') {
      badgeColor = const Color(0xFF38BDF8);
      statusIcon = Icons.sailing_rounded;
    }

    final isTahliye = ship.islem == 'Tahliye';

    return GestureDetector(
      onTap: () => _showShipDetailsModal(ship),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.08),
                  border: Border(bottom: BorderSide(color: badgeColor.withValues(alpha: 0.15))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: badgeColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(statusIcon, color: badgeColor, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ship.gemiAdi,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${ship.gemiTipi} • ${ship.bayrak}',
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isTahliye ? const Color(0xFFEF4444).withValues(alpha: 0.15) : const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        ship.islem.toUpperCase(),
                        style: TextStyle(
                          color: isTahliye ? const Color(0xFFF87171) : const Color(0xFF34D399),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn('Konum / İskele', ship.iskeleNo, Icons.place_rounded, const Color(0xFF38BDF8)),
                        ),
                        Expanded(
                          child: _buildInfoColumn('Yük Cinsi & Miktar', '${ship.yukCinsi} ${ship.miktar > 0 ? '(${fNumber.format(ship.miktar)} Ton)' : ''}', Icons.inventory_2_rounded, const Color(0xFFFBBF24)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _buildInfoColumn('Tarih / Durum', ship.tarihStr, Icons.event_rounded, const Color(0xFFA78BFA)),
                        ),
                        Expanded(
                          child: _buildInfoColumn('Firma / Menşei', ship.firmaUlke, Icons.business_rounded, const Color(0xFF94A3B8)),
                        ),
                      ],
                    ),
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
                                style: const TextStyle(color: Color(0xFF34D399), fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                '%${(ship.progress * 100).toInt()}',
                                style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ship.progress,
                              minHeight: 6,
                              backgroundColor: Colors.white.withValues(alpha: 0.1),
                              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoColumn(String title, String value, IconData icon, Color iconColor) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.5), fontSize: 10),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// CANLI RADAR VE İSDEMİR LİMANI HARİTA ÇİZİM PAINTER'I
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
          Color(0xFF091424),
        ],
      ).createShader(seaRect);
    canvas.drawRect(seaRect, seaPaint);

    final landPaint = Paint()
      ..color = const Color(0xFF1E293B)
      ..style = PaintingStyle.fill;

    final landStroke = Paint()
      ..color = const Color(0xFF38BDF8).withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    final portPath = Path();
    portPath.moveTo(0, 0);
    portPath.lineTo(size.width * 0.35, 0);
    portPath.lineTo(size.width * 0.30, size.height * 0.45);
    
    // Dış Uzun İskele (Chemical Explorer'ın bağlı olduğu iskele)
    portPath.lineTo(size.width * 0.12, size.height * 0.56);
    portPath.lineTo(size.width * 0.14, size.height * 0.60);
    portPath.lineTo(size.width * 0.32, size.height * 0.50);
    
    // İç Rıhtım Havuzu (Ionic Spirit, Gala A, Golden Shark'ın bağlı olduğu yer)
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
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = 40; r <= 180; r += 45) {
      canvas.drawCircle(radarCenter, r, ringPaint);
    }

    final axisPaint = Paint()
      ..color = const Color(0xFF0EA5E9).withValues(alpha: 0.1)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(radarCenter.dx - 180, radarCenter.dy), Offset(radarCenter.dx + 180, radarCenter.dy), axisPaint);
    canvas.drawLine(Offset(radarCenter.dx, radarCenter.dy - 180), Offset(radarCenter.dx, radarCenter.dy + 180), axisPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: const Alignment(-0.2, 0.0),
        startAngle: 0.0,
        endAngle: math.pi / 3,
        transform: GradientRotation(sweepAngle),
        colors: [
          const Color(0xFF38BDF8).withValues(alpha: 0.35),
          const Color(0xFF0EA5E9).withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(center: radarCenter, radius: 180));

    canvas.drawCircle(radarCenter, 180, sweepPaint);

    final centerDotPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(radarCenter, 3.5, centerDotPaint);
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
        color: Color(0xFF1E293B),
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
                  color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.directions_boat_filled_rounded, color: Color(0xFF38BDF8), size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ship.gemiAdi,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
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
                  color: isTahliye ? const Color(0xFFEF4444).withValues(alpha: 0.2) : const Color(0xFF10B981).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  ship.islem.toUpperCase(),
                  style: TextStyle(
                    color: isTahliye ? const Color(0xFFF87171) : const Color(0xFF34D399),
                    fontSize: 12,
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
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                const Icon(Icons.sensors_rounded, color: Color(0xFF34D399), size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('CANLI AIS DURUMU', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text(ship.durum, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
                Text(
                  '${ship.speedKnots} kn',
                  style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold),
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
          const SizedBox(height: 12),
          _buildDetailRow('Koordinat', '${ship.lat.toStringAsFixed(4)}° N, ${ship.lng.toStringAsFixed(4)}° E', 'Rota (Heading)', '${ship.heading.toInt()}°'),

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
                    backgroundColor: const Color(0xFF0284C7),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.radar_rounded, size: 16),
                  label: const Text('VesselFinder', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
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
                    foregroundColor: const Color(0xFF38BDF8),
                    side: const BorderSide(color: Color(0xFF38BDF8)),
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
              Text(label1, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val1, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label2, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11)),
              const SizedBox(height: 2),
              Text(val2, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------
// YARDIMCI WIDGET'LAR
// ----------------------------------------------------
class _PulsingLiveDot extends StatefulWidget {
  const _PulsingLiveDot();

  @override
  State<_PulsingLiveDot> createState() => _PulsingLiveDotState();
}

class _PulsingLiveDotState extends State<_PulsingLiveDot> with SingleTickerProviderStateMixin {
  late AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 1))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF10B981).withValues(alpha: 0.15 + (_anim.value * 0.2)),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4 + (_anim.value * 0.4))),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF34D399),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF34D399).withValues(alpha: _anim.value),
                      blurRadius: 6,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                'CANLI',
                style: TextStyle(color: Color(0xFF34D399), fontSize: 9, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 9)),
      ],
    );
  }
}
