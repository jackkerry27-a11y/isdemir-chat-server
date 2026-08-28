import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/ship_data.dart';

class GemilerScreen extends StatefulWidget {
  const GemilerScreen({super.key});

  @override
  State<GemilerScreen> createState() => _GemilerScreenState();
}

class _GemilerScreenState extends State<GemilerScreen> {
  late List<ShipData> _allShips;
  String _selectedCategory = 'Rihtimdaki'; // 'Rihtimdaki', 'Demirdeki', 'Beklenen'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _allShips = ShipData.getAllShips();
    _allShips.sort((a, b) => a.sortDate.compareTo(b.sortDate));
  }

  int _getShipCount(String category) {
    return _allShips.where((s) => s.kategori == category).length;
  }

  int _getTotalTonnage() {
    return _allShips.fold(0, (sum, ship) => sum + ship.miktar);
  }

  List<ShipData> get _filteredShips {
    return _allShips.where((s) {
      final matchesCategory = s.kategori == _selectedCategory;
      final matchesSearch = s.gemiAdi.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.firmaUlke.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          s.yukCinsi.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildSliverHeader(),
          SliverToBoxAdapter(
            child: _buildBodyContent(),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  return _buildShipCard(_filteredShips[index]);
                },
                childCount: _filteredShips.length,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 100)), // Bottom padding
        ],
      ),
    );
  }

  Widget _buildSliverHeader() {
    return SliverAppBar(
      expandedHeight: 220.0,
      pinned: true,
      backgroundColor: const Color(0xFF4338CA), // Koyu kırmızı
      elevation: 0,
      iconTheme: const IconThemeData(color: Colors.white),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Arka plan gradyanı ve görsel
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF4338CA),
                    Color(0xFF2E1065),
                  ],
                ),
              ),
            ),
            // Opsiyonel liman görseli
            Opacity(
              opacity: 0.15,
              child: Image.asset(
                'assets/images/port_background.png',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const SizedBox(),
              ),
            ),
            // Başlık ve Açıklama
            Positioned(
              top: 100, // AppBar'ın altına gelmesi için
              left: 20,
              right: 20,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Gemi Durum Raporu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Liman operasyonlarını anlık takip edin.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            // Alt kısımdaki sekmeler
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildCustomTab('Rihtimdaki', 'Rıhtımdaki', Icons.directions_boat_rounded),
                    _buildCustomTab('Demirdeki', 'Demirdeki', Icons.anchor_rounded),
                    _buildCustomTab('Beklenen', 'Beklenen', Icons.calendar_month_rounded),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTab(String categoryId, String label, IconData icon) {
    final isSelected = _selectedCategory == categoryId;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCategory = categoryId;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF3B82F6) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.white70,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white70,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBodyContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      transform: Matrix4.translationValues(0, -10, 0), // Sekmelerin biraz altına sarkması için
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Arama çubuğu
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      onChanged: (value) => setState(() => _searchQuery = value),
                      decoration: InputDecoration(
                        hintText: 'Gemi, firma, yük arayın...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Icon(Icons.search_rounded, color: Colors.grey[400]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.filter_list_rounded, color: Colors.grey[700], size: 20),
                      const SizedBox(width: 6),
                      Text('Filtrele', style: TextStyle(color: Colors.grey[800], fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // İstatistik Kartları (Yatay kaydırılabilir)
          SizedBox(
            height: 90,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildStatCard('Rıhtımdaki', _getShipCount('Rihtimdaki').toString(), 'Gemi', Icons.directions_boat_rounded, const Color(0xFF10B981)),
                const SizedBox(width: 12),
                _buildStatCard('Demirdeki', _getShipCount('Demirdeki').toString(), 'Gemi', Icons.anchor_rounded, const Color(0xFFF59E0B)),
                const SizedBox(width: 12),
                _buildStatCard('Beklenen', _getShipCount('Beklenen').toString(), 'Gemi', Icons.calendar_month_rounded, const Color(0xFF8B5CF6)),
                const SizedBox(width: 12),
                _buildStatCard('Toplam Yük', NumberFormat('#,###', 'tr_TR').format(_getTotalTonnage()), 'Ton', Icons.shopping_bag_rounded, const Color(0xFF3B82F6)),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String count, String unit, IconData icon, Color color) {
    return Container(
      width: 130,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            count,
            style: const TextStyle(
              color: Colors.black87,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShipCard(ShipData ship) {
    // Kategoriye göre veya işleme göre renk belirleme
    Color primaryColor;
    IconData actionIcon;
    String actionLabel = ship.islem;

    if (ship.islem.toLowerCase().contains('tahliye')) {
      primaryColor = const Color(0xFF10B981); // Yeşil
      actionIcon = Icons.arrow_downward_rounded;
    } else if (ship.islem.toLowerCase().contains('yukleme') || ship.islem.toLowerCase().contains('yükleme')) {
      primaryColor = const Color(0xFFF59E0B); // Turuncu
      actionIcon = Icons.arrow_upward_rounded;
    } else {
      primaryColor = const Color(0xFF3B82F6); // Mavi (Beklenen vs)
      actionIcon = Icons.swap_horiz_rounded;
    }
    
    // MKK MADRID için özel durum (resimdeki gibi mavi olması için)
    if (ship.gemiAdi == 'MKK MADRID') {
      primaryColor = const Color(0xFF3B82F6);
    }

    final numberFormat = NumberFormat('#,###', 'tr_TR');
    final miktarFormatted = numberFormat.format(ship.miktar);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Sol dikey renkli bar
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  bottomLeft: Radius.circular(16),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Sol İkon
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.directions_boat_rounded, color: primaryColor, size: 28),
                    ),
                    const SizedBox(width: 16),
                    
                    // Orta Bilgiler (Ad, Firma, Yük)
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            ship.gemiAdi,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Icon(Icons.business_rounded, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ship.firmaUlke,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.inventory_2_rounded, size: 14, color: Colors.grey[500]),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  ship.yukCinsi,
                                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Sağ Bilgiler (Tarih, İşlem, Tonaj)
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tarih Hapı
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.calendar_month_rounded, size: 12, color: primaryColor),
                                const SizedBox(width: 4),
                                Text(
                                  ship.tarihStr,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                          // İşlem
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(actionIcon, color: primaryColor, size: 14),
                              const SizedBox(width: 2),
                              Text(
                                actionLabel,
                                style: TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Tonaj
                          Text(
                            miktarFormatted,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w900,
                              color: Colors.black87,
                            ),
                          ),
                          const Text(
                            'Ton',
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    const SizedBox(width: 8),
                    // Yön ikonu
                    Icon(Icons.chevron_right_rounded, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
