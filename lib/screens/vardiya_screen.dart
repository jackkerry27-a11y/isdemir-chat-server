import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/shift_logic.dart';

class VardiyaScreen extends StatefulWidget {
  const VardiyaScreen({super.key});

  @override
  State<VardiyaScreen> createState() => _VardiyaScreenState();
}

class _VardiyaScreenState extends State<VardiyaScreen> {
  DateTime _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  final DateTime _today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  VardiyaGunu _selectedVardiya = VardiyaGunu.sali;

  @override
  void initState() {
    super.initState();
    _loadSelectedVardiya();
  }

  Future<void> _loadSelectedVardiya() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('selected_vardiya_gunu');
    if (saved == 'carsamba') {
      setState(() {
        _selectedVardiya = VardiyaGunu.carsamba;
      });
    } else if (saved == 'cumartesi') {
      setState(() {
        _selectedVardiya = VardiyaGunu.cumartesi;
      });
    }
  }

  Future<void> _changeVardiya(VardiyaGunu newVardiya) async {
    setState(() {
      _selectedVardiya = newVardiya;
    });
    final prefs = await SharedPreferences.getInstance();
    String saveStr = 'sali';
    if (newVardiya == VardiyaGunu.carsamba) saveStr = 'carsamba';
    if (newVardiya == VardiyaGunu.cumartesi) saveStr = 'cumartesi';
    await prefs.setString('selected_vardiya_gunu', saveStr);
  }

  void _showVardiyaSelectionModal() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Vardiya Değiştir', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1A202C))),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _selectedVardiya == VardiyaGunu.sali ? const Color(0xFF4338CA) : Colors.grey.shade200, width: 2),
                ),
                leading: Icon(Icons.calendar_today_rounded, color: _selectedVardiya == VardiyaGunu.sali ? const Color(0xFF4338CA) : Colors.grey),
                title: const Text('Salı Vardiyası', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hafta Tatili: Salı'),
                trailing: _selectedVardiya == VardiyaGunu.sali ? const Icon(Icons.check_circle, color: Color(0xFF4338CA)) : null,
                onTap: () {
                  _changeVardiya(VardiyaGunu.sali);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _selectedVardiya == VardiyaGunu.carsamba ? const Color(0xFF4338CA) : Colors.grey.shade200, width: 2),
                ),
                leading: Icon(Icons.calendar_today_rounded, color: _selectedVardiya == VardiyaGunu.carsamba ? const Color(0xFF4338CA) : Colors.grey),
                title: const Text('Çarşamba Vardiyası', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hafta Tatili: Çarşamba'),
                trailing: _selectedVardiya == VardiyaGunu.carsamba ? const Icon(Icons.check_circle, color: Color(0xFF4338CA)) : null,
                onTap: () {
                  _changeVardiya(VardiyaGunu.carsamba);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: _selectedVardiya == VardiyaGunu.cumartesi ? const Color(0xFF4338CA) : Colors.grey.shade200, width: 2),
                ),
                leading: Icon(Icons.calendar_today_rounded, color: _selectedVardiya == VardiyaGunu.cumartesi ? const Color(0xFF4338CA) : Colors.grey),
                title: const Text('Cumartesi Vardiyası', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Hafta Tatili: Cuma (2x Sab, 2x Gec, 2x Aks)'),
                trailing: _selectedVardiya == VardiyaGunu.cumartesi ? const Icon(Icons.check_circle, color: Color(0xFF4338CA)) : null,
                onTap: () {
                  _changeVardiya(VardiyaGunu.cumartesi);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }
  
  void _goToToday() {
    setState(() {
      _currentMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
    });
  }

  Color _getShiftColor(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return const Color(0xFFF59E0B); // Turuncu (Gündüz)
      case ShiftType.gece:
        return const Color(0xFF3B82F6); // Mavi (Gece)
      case ShiftType.aksam:
        return const Color(0xFF8B5CF6); // Mor (Akşam)
      case ShiftType.tatil:
        return const Color(0xFF10B981); // Yeşil (İzin/Tatil)
    }
  }

  IconData _getShiftIcon(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return Icons.wb_sunny_rounded;
      case ShiftType.gece:
        return Icons.nightlight_round;
      case ShiftType.aksam:
        return Icons.wb_twilight_rounded;
      case ShiftType.tatil:
        return Icons.beach_access_rounded;
    }
  }

  String _getShiftName(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return 'Gündüz Vardiyası';
      case ShiftType.gece:
        return 'Gece Vardiyası';
      case ShiftType.aksam:
        return 'Akşam Vardiyası';
      case ShiftType.tatil:
        return 'İzin Günü';
    }
  }

  String _getShiftTime(ShiftType type) {
    switch (type) {
      case ShiftType.sabah:
        return '09:30 - 16:30';
      case ShiftType.gece:
        return '00:30 - 09:30';
      case ShiftType.aksam:
        return '16:30 - 24:30';
      case ShiftType.tatil:
        return 'Hafta Tatili';
    }
  }

  @override
  Widget build(BuildContext context) {
    final months = ['', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran', 'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'];
    final daysOfWeek = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];

    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday; // Pazartesi = 1
    int emptySlots = firstWeekday - 1;

    ShiftType todayShift = ShiftLogic.getShiftType(_today, vardiyaGunu: _selectedVardiya);
    Color todayColor = _getShiftColor(todayShift);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: double.infinity,
                  height: 320, 
                  padding: const EdgeInsets.only(top: 70, left: 24, right: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4338CA), Color(0xFF2E1065)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.elliptical(150, 60),
                      bottomRight: Radius.elliptical(250, 90),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Vardiya Takvimi',
                                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: -0.5),
                              ),
                              SizedBox(height: 6),
                              Text(
                                'Çalışma saatlerinizi görüntüleyin',
                                style: TextStyle(fontSize: 14, color: Colors.white70),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: _showVardiyaSelectionModal,
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.edit_calendar_rounded, color: Colors.white, size: 32),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Vardiya Seçim Butonları
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _changeVardiya(VardiyaGunu.sali),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedVardiya == VardiyaGunu.sali ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Salı Vardiyası',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedVardiya == VardiyaGunu.sali ? const Color(0xFF4338CA) : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _changeVardiya(VardiyaGunu.carsamba),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _selectedVardiya == VardiyaGunu.carsamba ? Colors.white : Colors.transparent,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      'Çarşamba Vardiyası',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: _selectedVardiya == VardiyaGunu.carsamba ? const Color(0xFF4338CA) : Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Positioned(
                  right: -50, top: -20,
                  child: IgnorePointer(
                    child: Container(
                      width: 200, height: 200,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                  ),
                ),
                
                Container(
                  margin: const EdgeInsets.only(top: 160, left: 24, right: 24),
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10)),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.chevron_left_rounded, color: Color(0xFF1A202C)),
                            onPressed: _previousMonth,
                          ),
                          Text(
                            '${months[_currentMonth.month]} ${_currentMonth.year}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                          ),
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.chevron_right_rounded, color: Color(0xFF1A202C)),
                                onPressed: _nextMonth,
                              ),
                              const SizedBox(width: 4),
                              GestureDetector(
                                onTap: _goToToday,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFEF2F2),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text('Bugün', style: TextStyle(color: Color(0xFF4338CA), fontSize: 12, fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: List.generate(7, (index) {
                          bool isTodayWeekday = _today.weekday - 1 == index && _currentMonth.month == _today.month && _currentMonth.year == _today.year;
                          return SizedBox(
                            width: 32,
                            child: Text(
                              daysOfWeek[index],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: isTodayWeekday ? const Color(0xFF4338CA) : const Color(0xFF718096),
                              ),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 12),
                      
                      GridView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 0.8,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                        ),
                        itemCount: emptySlots + daysInMonth,
                        itemBuilder: (context, index) {
                          if (index < emptySlots) return const SizedBox();
                          
                          int day = index - emptySlots + 1;
                          DateTime date = DateTime(_currentMonth.year, _currentMonth.month, day);
                          bool isToday = date.year == _today.year && date.month == _today.month && date.day == _today.day;
                          
                          ShiftType shift = ShiftLogic.getShiftType(date, vardiyaGunu: _selectedVardiya);
                          Color shiftColor = _getShiftColor(shift);
                          
                          Color bgColor = isToday ? const Color(0xFF4338CA) : shiftColor.withValues(alpha: 0.1);
                          Color textColor = isToday ? Colors.white : shiftColor;
                          Color dotColor = isToday ? Colors.white : shiftColor;
                          
                          return Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  day.toString(),
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Container(
                                  width: 4, height: 4,
                                  decoration: BoxDecoration(
                                    color: dotColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      
                      const SizedBox(height: 20),
                      
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLegendItem('Gündüz', const Color(0xFFF59E0B)),
                          const SizedBox(width: 12),
                          _buildLegendItem('Gece', const Color(0xFF3B82F6)),
                          const SizedBox(width: 12),
                          _buildLegendItem('Akşam', const Color(0xFF8B5CF6)),
                          const SizedBox(width: 12),
                          _buildLegendItem('İzin', const Color(0xFF10B981)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 60, height: 60,
                      decoration: BoxDecoration(
                        color: todayColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(_getShiftIcon(todayShift), color: todayColor, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getShiftName(todayShift),
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: todayColor),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.access_time_rounded, size: 12, color: Color(0xFF64748B)),
                                    const SizedBox(width: 4),
                                    Text(
                                      _getShiftTime(todayShift),
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${_today.day} ${months[_today.month]} ${_today.year}',
                            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: Color(0xFFA0AEC0)),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Vardiya Kılavuzu',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Expanded(child: _buildGuideCard(ShiftType.sabah)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildGuideCard(ShiftType.gece)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _buildGuideCard(ShiftType.aksam)),
                      const SizedBox(width: 16),
                      Expanded(child: _buildGuideCard(ShiftType.tatil)),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF4A5568))),
      ],
    );
  }

  Widget _buildGuideCard(ShiftType type) {
    Color color = _getShiftColor(type);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getShiftIcon(type), color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            _getShiftName(type),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A202C)),
          ),
          const SizedBox(height: 4),
          Text(
            _getShiftTime(type),
            style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
          ),
          const SizedBox(height: 12),
          Container(
            height: 3,
            width: 30,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ],
      ),
    );
  }
}
