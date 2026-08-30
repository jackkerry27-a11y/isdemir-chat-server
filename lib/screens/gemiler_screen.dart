import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/ship_data.dart';
import '../utils/socket_service.dart';

class GemilerScreen extends StatefulWidget {
  const GemilerScreen({super.key});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> {
  List<ShipData> _allShips = [];
  String _searchQuery = '';
  String _selectedCategory = 'Tümü'; // 'Tümü', 'Rihtimdaki', 'Demirdeki', 'Beklenen', 'Ayrilan'
  bool _isLoading = false;
  String _lastUpdatedText = 'Canlı AIS';
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _allShips = ShipData.getAllShips();
    _allShips.sort((a, b) => a.sortDate.compareTo(b.sortDate));

    // İlk HTTP yüklemesi
    _fetchLiveShips();

    // Socket.io Canlı Gemi Güncellemelerini Dinle
    SocketService().onShipsUpdated = (shipList) {
      if (mounted && shipList.isNotEmpty) {
        _processReceivedShips(shipList);
      }
    };
    SocketService().requestShipsUpdate();

    // Her 20 saniyede bir otomatik tazeleyen yedek timer
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (timer) {
      if (mounted) {
        _fetchLiveShips(silent: true);
      }
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    SocketService().onShipsUpdated = null;
    super.dispose();
  }

  void _processReceivedShips(List<dynamic> shipList) {
    try {
      final List<ShipData> parsed = shipList.map((item) => ShipData.fromJson(item as Map<String, dynamic>)).toList();
      setState(() {
        _allShips = parsed;
        final now = DateTime.now();
        _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Canlı AIS)';
      });
    } catch (e) {
      debugPrint('Gemi verisi işleme hatası: $e');
    }
  }

  Future<void> _fetchLiveShips({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final response = await http
          .get(Uri.parse('https://isdemir-chat-server.onrender.com/api/ships/live'))
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final data = json.decode(utf8.decode(response.bodyBytes));
        if (data['success'] == true && data['ships'] != null) {
          final List<dynamic> shipList = data['ships'];
          if (mounted) {
            _processReceivedShips(shipList);
          }
        }
      }
    } catch (_) {
      if (mounted && !silent) {
        final now = DateTime.now();
        setState(() {
          _lastUpdatedText = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')} (Çevrimdışı/Yedek)';
        });
      }
    } finally {
      if (mounted && !silent) {
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
      final matchesCategory = _selectedCategory == 'Tümü' || s.kategori == _selectedCategory;
      final query = _searchQuery.toLowerCase();
      final matchesSearch = s.gemiAdi.toLowerCase().contains(query) ||
          s.firmaUlke.toLowerCase().contains(query) ||
          s.yukCinsi.toLowerCase().contains(query) ||
          s.iskeleNo.toLowerCase().contains(query) ||
          s.durum.toLowerCase().contains(query);
      return matchesCategory && matchesSearch;
    }).toList();
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
    final ayrilanCount = _getShipCount('Ayrilan');
    final totalTon = _getTotalTonnage();

    final fNumber = NumberFormat('#,###', 'tr_TR');

    return Scaffold(
      backgroundColor: const Color(0xFF060B14), // Tam karanlık modern uzay mavisi zemin
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _fetchLiveShips(silent: false),
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
                    // 2. Liman İstatistik Şeridi (Rıhtımda, Demirde, Beklenen, Ayrılan, Hacim)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                        child: _buildPortStatsBar(rihtimCount, demirCount, beklenenCount, ayrilanCount, fNumber.format(totalTon)),
                      ),
                    ),

                    // 3. Kategori Filtre Butonları
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: _buildCategoryChips(rihtimCount, demirCount, beklenenCount, ayrilanCount),
                      ),
                    ),

                    // 4. Arama Çubuğu
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
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
                                  Text(
                                    _searchQuery.isNotEmpty
                                        ? 'Aramanıza uygun gemi bulunamadı.'
                                        : 'Bu kategoride gemi bulunmuyor.',
                                    style: const TextStyle(color: Colors.white60, fontSize: 14),
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
  // ÜST BAŞLIK ÇUBUĞU
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
                            'CANLI AIS',
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

          // Yenile Butonu
          IconButton(
            onPressed: _isLoading ? null : () => _fetchLiveShips(silent: false),
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
        ],
      ),
    );
  }

  // ----------------------------------------------------
  // İSTATİSTİK ŞERİDİ (5 Metrik)
  // ----------------------------------------------------
  Widget _buildPortStatsBar(int rihtimCount, int demirCount, int beklenenCount, int ayrilanCount, String totalTonStr) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1424),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E3A5F)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildStatItem('Rıhtımda', '$rihtimCount', 'Gemi', const Color(0xFF10B981), Icons.location_on_rounded, 'Rihtimdaki'),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Demirde', '$demirCount', 'Gemi', const Color(0xFFF59E0B), Icons.anchor_rounded, 'Demirdeki'),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Yaklaşan', '$beklenenCount', 'Gemi', const Color(0xFF00E5FF), Icons.directions_boat_rounded, 'Beklenen'),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Ayrılan', '$ayrilanCount', 'Gemi', const Color(0xFF94A3B8), Icons.sailing_rounded, 'Ayrilan'),
          ),
          Container(width: 1, height: 36, color: const Color(0xFF1E3A5F)),
          Expanded(
            child: _buildStatItem('Hacim', '${(totalTonStr.split('.')[0])}k', 'Ton', const Color(0xFFA855F7), Icons.inventory_2_rounded, 'Tümü'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, String unit, Color color, IconData icon, String categoryFilter) {
    final isSelected = _selectedCategory == categoryFilter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = (_selectedCategory == categoryFilter && categoryFilter != 'Tümü') ? 'Tümü' : categoryFilter;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: isSelected ? color.withValues(alpha: 0.15) : Colors.transparent,
        ),
        child: Column(
          children: [
            Icon(icon, size: 15, color: color),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: isSelected ? Colors.white : const Color(0xFF94A3B8), fontSize: 9.5, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500)),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w900),
            ),
            Text(
              unit,
              style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 8.5, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // KATEGORİ FİLTRE ÇİPLERİ
  // ----------------------------------------------------
  Widget _buildCategoryChips(int rihtim, int demir, int beklenen, int ayrilan) {
    final categories = [
      {'key': 'Tümü', 'label': 'Tüm Gemiler (${_allShips.length})', 'icon': Icons.all_inclusive_rounded, 'color': const Color(0xFF6366F1)},
      {'key': 'Rihtimdaki', 'label': 'Rıhtımda ($rihtim)', 'icon': Icons.location_on_rounded, 'color': const Color(0xFF10B981)},
      {'key': 'Demirdeki', 'label': 'Demirde ($demir)', 'icon': Icons.anchor_rounded, 'color': const Color(0xFFF59E0B)},
      {'key': 'Beklenen', 'label': 'Yaklaşan ($beklenen)', 'icon': Icons.directions_boat_rounded, 'color': const Color(0xFF00E5FF)},
      {'key': 'Ayrilan', 'label': 'Son Ayrılan ($ayrilan)', 'icon': Icons.sailing_rounded, 'color': const Color(0xFF94A3B8)},
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: categories.map((cat) {
          final isSelected = _selectedCategory == cat['key'];
          final Color color = cat['color'] as Color;
          return GestureDetector(
            onTap: () => setState(() => _selectedCategory = cat['key'] as String),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected ? color.withValues(alpha: 0.2) : const Color(0xFF0B1424),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? color : const Color(0xFF1E3A5F),
                  width: isSelected ? 1.5 : 1.0,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(cat['icon'] as IconData, size: 14, color: isSelected ? color : const Color(0xFF94A3B8)),
                  const SizedBox(width: 6),
                  Text(
                    cat['label'] as String,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
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
          hintText: 'Gemi adı, yük cinsi, iskele veya durum ara...',
          hintStyle: const TextStyle(color: Color(0xFF64748B), fontSize: 12.5),
          prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF00E5FF), size: 18),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear, color: Colors.white54, size: 18),
                  onPressed: () => setState(() => _searchQuery = ''),
                )
              : const Icon(Icons.tune_rounded, color: Color(0xFF00E5FF), size: 18),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        ),
      ),
    );
  }

  // ----------------------------------------------------
  // PROFESYONEL GEMİ KARTI
  // ----------------------------------------------------
  Widget _buildVesselCard(ShipData ship, NumberFormat fNumber) {
    final isTahliye = ship.islem == 'Tahliye';
    final isAyrildi = ship.kategori == 'Ayrilan';
    final isBeklenen = ship.kategori == 'Beklenen';
    final isDemirde = ship.kategori == 'Demirdeki';

    // Sol taraftaki fotoğraf ve rozet seçimi
    String networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_bulk.jpg';
    Color glowDotColor = const Color(0xFF10B981);

    if (isAyrildi) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_cargo.jpg';
      glowDotColor = const Color(0xFF94A3B8);
    } else if (ship.gemiAdi.contains('CHEMICAL EXPLORER')) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_tanker.jpg';
      glowDotColor = const Color(0xFF10B981);
    } else if (ship.gemiAdi.contains('IONIC SPIRIT')) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_bulk.jpg';
      glowDotColor = const Color(0xFFF59E0B);
    } else if (ship.gemiAdi.contains('GALA A')) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_cargo.jpg';
      glowDotColor = const Color(0xFF00E5FF);
    } else if (ship.gemiAdi.contains('GOLDEN SHARK')) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_bulk.jpg';
      glowDotColor = const Color(0xFFEAB308);
    } else if (ship.gemiAdi.contains('MED ') || ship.gemiAdi.contains('KAPTAN')) {
      networkImageUrl = 'https://raw.githubusercontent.com/jackkerry27-a11y/isdemir-chat-server/main/assets/images/vessel_cargo.jpg';
      glowDotColor = const Color(0xFF06B6D4);
    } else if (isBeklenen) {
      glowDotColor = const Color(0xFF00E5FF);
    } else if (isDemirde) {
      glowDotColor = const Color(0xFFF59E0B);
    }

    // Durum Rozeti Metni ve Rengi
    String badgeText = ship.islem.toUpperCase();
    Color badgeBg = isTahliye ? const Color(0xFF7F1D1D).withValues(alpha: 0.6) : const Color(0xFF064E3B).withValues(alpha: 0.8);
    Color badgeBorder = isTahliye ? const Color(0xFFDC2626).withValues(alpha: 0.6) : const Color(0xFF10B981).withValues(alpha: 0.6);
    Color badgeFg = isTahliye ? const Color(0xFFFCA5A5) : const Color(0xFF6EE7B7);

    if (isAyrildi) {
      badgeText = 'AYRILDI';
      badgeBg = const Color(0xFF334155).withValues(alpha: 0.7);
      badgeBorder = const Color(0xFF64748B);
      badgeFg = const Color(0xFFE2E8F0);
    } else if (isBeklenen) {
      badgeText = 'YAKLAŞIYOR';
      badgeBg = const Color(0xFF0C4A6E).withValues(alpha: 0.7);
      badgeBorder = const Color(0xFF0284C7);
      badgeFg = const Color(0xFF7DD3FC);
    } else if (isDemirde) {
      badgeText = 'DEMİRDE';
      badgeBg = const Color(0xFF78350F).withValues(alpha: 0.7);
      badgeBorder = const Color(0xFFD97706);
      badgeFg = const Color(0xFFFDE68A);
    }

    return GestureDetector(
      onTap: () => _showShipDetailsModal(ship),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF0B1424),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAyrildi ? const Color(0xFF334155) : const Color(0xFF1E3A5F),
          ),
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
                      Image.network(
                        networkImageUrl,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return Container(
                            color: const Color(0xFF0F1E36),
                            child: const Center(
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00E5FF)),
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [Color(0xFF0F2642), Color(0xFF071424)],
                              ),
                            ),
                            child: const Center(
                              child: Icon(Icons.directions_boat_rounded, color: Color(0xFF00E5FF), size: 36),
                            ),
                          );
                        },
                      ),
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
                        // Üst Satır: İkon + Gemi Adı + Durum Rozeti
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                isAyrildi ? Icons.sailing_rounded : Icons.directions_boat_filled_rounded,
                                color: badgeFg,
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
                                color: badgeBg,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: badgeBorder),
                              ),
                              child: Text(
                                badgeText,
                                style: TextStyle(
                                  color: badgeFg,
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
                                icon: isAyrildi ? Icons.sailing_rounded : Icons.location_on_rounded,
                                iconColor: isAyrildi ? const Color(0xFF94A3B8) : const Color(0xFF00E5FF),
                                title: isAyrildi ? 'ÇIKIŞ / MEVCUT KONUM' : 'KONUM / İSKELE',
                                value: ship.iskeleNo,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.inventory_2_rounded,
                                iconColor: const Color(0xFFF59E0B),
                                title: 'YÜK & MİKTAR',
                                value: '${ship.yukCinsi} ${ship.miktar > 0 ? '(${fNumber.format(ship.miktar)} T)' : ''}',
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
                                icon: Icons.schedule_rounded,
                                iconColor: const Color(0xFFA855F7),
                                title: isAyrildi ? 'AYRILMA ZAMANI' : 'TARİH / DURUM',
                                value: ship.tarihStr,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _buildGridItem(
                                icon: Icons.speed_rounded,
                                iconColor: const Color(0xFF34D399),
                                title: 'CANLI AIS DURUMU',
                                value: ship.durum.isNotEmpty ? ship.durum : (ship.speedKnots > 0 ? '${ship.speedKnots} kn Seyirde' : 'Yanaşık'),
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
            Expanded(
              child: Text(
                title,
                style: const TextStyle(color: Color(0xFF64748B), fontSize: 8, fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
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
// CANLI GEMİ DETAY MODAL BOTTOM SHEET
// ----------------------------------------------------
class _ShipDetailBottomSheet extends StatelessWidget {
  final ShipData ship;

  const _ShipDetailBottomSheet({required this.ship});

  @override
  Widget build(BuildContext context) {
    final isTahliye = ship.islem == 'Tahliye';
    final isAyrildi = ship.kategori == 'Ayrilan';
    final isBeklenen = ship.kategori == 'Beklenen';
    final isDemirde = ship.kategori == 'Demirdeki';
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
                child: Icon(
                  isAyrildi ? Icons.sailing_rounded : Icons.directions_boat_filled_rounded,
                  color: const Color(0xFF00E5FF),
                  size: 28,
                ),
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
                  color: isAyrildi
                      ? const Color(0xFF334155)
                      : (isTahliye ? const Color(0xFF7F1D1D) : const Color(0xFF064E3B)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  isAyrildi ? 'AYRILDI' : (isBeklenen ? 'YAKLAŞIYOR' : (isDemirde ? 'DEMİRDE' : ship.islem.toUpperCase())),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Canlı AIS Konum ve Hız Kartı
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
                      const Text('CANLI AIS TELEMETRİSİ', style: TextStyle(color: Color(0xFF64748B), fontSize: 10, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 2),
                      Text('${ship.lat.toStringAsFixed(4)}° N, ${ship.lng.toStringAsFixed(4)}° E', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      if (ship.durum.isNotEmpty)
                        Text(ship.durum, style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${ship.speedKnots} kn',
                      style: const TextStyle(color: Color(0xFF00E5FF), fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      'Pruva: ${ship.heading.round()}°',
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          _buildDetailRow('Bayrak', ship.bayrak, isAyrildi ? 'Ayrılış Rıhtımı' : 'İskele / Rıhtım', ship.iskeleNo),
          const SizedBox(height: 12),
          _buildDetailRow('Yük Cinsi', ship.yukCinsi, 'Miktar', ship.miktar > 0 ? '${fNumber.format(ship.miktar)} Ton' : 'Liman Hizmeti'),
          const SizedBox(height: 12),
          _buildDetailRow('Firma / Menşei', ship.firmaUlke, 'Zaman / Durum', ship.tarihStr),
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
