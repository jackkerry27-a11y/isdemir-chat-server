import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/menu_data.dart';

class YemekScreen extends StatefulWidget {
  const YemekScreen({super.key});

  @override
  State<YemekScreen> createState() => _YemekScreenState();
}

class _YemekScreenState extends State<YemekScreen> {
  int selectedDay = 4;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    
    DateTime now = DateTime.now();
    if (now.month == 9) {
      selectedDay = now.day;
    } else {
      selectedDay = 1; 
    }
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (selectedDay > 4 && _scrollController.hasClients) {
        _scrollController.animateTo(
          (selectedDay - 3) * 75.0, 
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOutCubic,
        );
      }
    });
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  String _getEmojiForFood(String foodName) {
    final lower = foodName.toLowerCase();
    if (lower.contains('çorba')) return '🍲';
    if (lower.contains('peynir')) return '🧀';
    if (lower.contains('zeytin')) return '🫒';
    if (lower.contains('yumurta') || lower.contains('omlet') || lower.contains('menemen')) return '🍳';
    if (lower.contains('reçel') || lower.contains('bal') || lower.contains('pekmez') || lower.contains('ezme')) return '🍯';
    if (lower.contains('karpuz') || lower.contains('meyve')) return '🍉';
    if (lower.contains('tereyağ')) return '🧈';
    if (lower.contains('süt') || lower.contains('ayran')) return '🥛';
    if (lower.contains('çay') || lower.contains('kahve') || lower.contains('meyve suyu')) return '☕';
    if (lower.contains('ekmek') || lower.contains('poğaça') || lower.contains('börek') || lower.contains('simit') || lower.contains('açma')) return '🥐';
    if (lower.contains('pilav') || lower.contains('makarna')) return '🍚';
    if (lower.contains('et') || lower.contains('kebap') || lower.contains('döner') || lower.contains('köfte')) return '🥩';
    if (lower.contains('tavuk') || lower.contains('piliç')) return '🍗';
    if (lower.contains('tatlı') || lower.contains('kek') || lower.contains('sütlaç') || lower.contains('dondurma') || lower.contains('browni') || lower.contains('supangle')) return '🍰';
    if (lower.contains('yoğurt') || lower.contains('cacık')) return '🥣';
    if (lower.contains('salata') || lower.contains('söğüş')) return '🥗';
    return '🍽️';
  }

  @override
  Widget build(BuildContext context) {
    DailyMenu? menu = MenuData.septemberMenu[selectedDay];

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Kırmızı Zemin (En Alt Katman, sadece boya)
          Positioned(
            top: 0, left: 0, right: 0,
            height: 240,
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF7A0000), Color(0xFFE50914)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -40,
                    top: 20,
                    child: Opacity(
                      opacity: 0.1,
                      child: const Icon(Icons.restaurant_menu_rounded, size: 200, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Beyaz Kavisli Zemin (Sabit)
          Positioned(
            top: 160, left: 0, right: 0, bottom: 0,
            child: Container(
              decoration: const BoxDecoration(
                color: Color(0xFFFAFAFA),
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
            ),
          ),
          
          // Kaydırılabilir İçerik (Sadece Yemek Menüleri)
          Positioned(
            top: 240, left: 0, right: 0, bottom: 0,
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 40),
              child: Column(
                children: [
                  // Seçili Gün Başlığı
                  if (menu != null) ...[
                    Text(
                      menu.dateText,
                      style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bugünkü yemek menüsü',
                      style: GoogleFonts.inter(fontSize: 13, color: Color(0xFF718096)),
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Menü Yoksa
                  if (menu == null)
                    Padding(
                      padding: const EdgeInsets.all(40.0),
                      child: Text('Bu güne ait menü bulunamadı.', style: GoogleFonts.inter(color: Colors.grey)),
                    )
                  else ...[
                    // Kahvaltı Kartı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: const Color(0xFF990000).withValues(alpha: 0.1)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(color: const Color(0xFF990000), shape: BoxShape.circle),
                                  child: const Icon(Icons.coffee_rounded, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Kahvaltı', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF990000))),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 12, color: Color(0xFF9CA3AF)),
                                          const SizedBox(width: 4),
                                          Text('07:00 - 09:30', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF990000).withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text('≈ 420 kcal', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF990000))),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            Wrap(
                              spacing: 8,
                              runSpacing: 12,
                              children: menu.breakfast.map((item) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.grey.shade200),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(_getEmojiForFood(item), style: GoogleFonts.inter(fontSize: 16)),
                                      const SizedBox(width: 8),
                                      Text(
                                        item,
                                        style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF4A5568)),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Ana Menü Kartı
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.red.withValues(alpha: 0.05)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: const BoxDecoration(color: Color(0xFF990000), shape: BoxShape.circle),
                                  child: const Icon(Icons.restaurant, color: Colors.white, size: 24),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('Ana Menü', style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFF990000))),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          const Icon(Icons.access_time, size: 12, color: Color(0xFF9CA3AF)),
                                          const SizedBox(width: 4),
                                          Text('12:00 - 14:00', style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9CA3AF))),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    if (menu.totalCalories.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF990000).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Text('≈ ${menu.totalCalories} kcal', style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF990000))),
                                      ),
                                    if (menu.totalProtein.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text('🥩', style: GoogleFonts.inter(fontSize: 11)),
                                            const SizedBox(width: 4),
                                            Text('~${menu.totalProtein} Protein', style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),
                            ...menu.mainCourse.map((item) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 14.0),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(_getEmojiForFood(item.name), style: GoogleFonts.inter(fontSize: 24)),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.name,
                                            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2D3748)),
                                          ),
                                          if (item.protein.isNotEmpty) ...[
                                            const SizedBox(height: 3),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF10B981).withValues(alpha: 0.1),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '🥩 ${item.protein} protein',
                                                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF059669)),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    if (item.calories.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(8),
                                          border: Border.all(color: const Color(0xFF990000).withValues(alpha: 0.15)),
                                        ),
                                        child: Text(
                                          '${item.calories} kcal',
                                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF990000)),
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            }),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Sağlıklı ve Dengeli Afişi
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFEF2F2),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.eco_rounded, color: Color(0xFF990000), size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Sağlıklı ve Dengeli',
                                    style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Menülerimiz diyetisyen kontrolünde hazırlanmakta ve günlük kalori dengesi gözetilmektedir.',
                                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF718096), height: 1.4),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text('🥗', style: GoogleFonts.inter(fontSize: 48)),
                          ],
                        ),
                      ),
                    ),
                  ]
                ],
              ),
            ),
          ),
          
          // Sabit Takvim Şeridi (Her zaman görünür, Yemeklerin Üstünde Sabit!)
          Positioned(
            top: 130, left: 0, right: 0, height: 100,
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              physics: const BouncingScrollPhysics(),
              itemCount: 30,
              itemBuilder: (context, index) {
                int day = index + 1;
                bool isSelected = day == selectedDay;
                DateTime date = DateTime(2026, 9, day);
                final daysShort = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
                String dayName = daysShort[date.weekday - 1]; 
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedDay = day;
                    });
                  },
                  child: Container(
                    width: 65,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF990000) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          day.toString(),
                          style: GoogleFonts.inter(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? Colors.white : const Color(0xFF1A202C),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Eyl\n$dayName',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white.withValues(alpha: 0.9) : const Color(0xFF718096),
                            height: 1.2,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(height: 6),
                          Container(
                            width: 16,
                            height: 3,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // En Üst Katman: App Bar / Geri Butonu (En Yüksek Öncelik - Tıklanabilir)
          Positioned(
            top: 0, left: 0, right: 0,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.only(top: 10, left: 16, right: 24),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 6),
                          Text(
                            'Yemek Menüsü',
                            style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Günlük yemek listesine göz atın',
                            style: GoogleFonts.inter(fontSize: 13, color: Colors.white.withValues(alpha: 0.9)),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.calendar_today_rounded, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
