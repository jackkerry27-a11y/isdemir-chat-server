import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

enum MesaiType { normal, bayram }

class MesaiRecord {
  final String id;
  final DateTime date;
  final DateTime submitDate;
  final MesaiType type;

  MesaiRecord({
    required this.id,
    required this.date,
    required this.submitDate,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date.toIso8601String(),
      'submitDate': submitDate.toIso8601String(),
      'type': type.index,
    };
  }

  factory MesaiRecord.fromJson(Map<String, dynamic> json) {
    return MesaiRecord(
      id: json['id'],
      date: DateTime.parse(json['date']),
      submitDate: DateTime.parse(json['submitDate']),
      type: MesaiType.values[json['type']],
    );
  }
}

class MesaiScreen extends StatefulWidget {
  final int normalMesaiGun;
  final int bayramMesaiGun;
  final double normalMesaiRate;
  final double bayramMesaiRate;
  final Function(int, int) onMesaiChanged;

  const MesaiScreen({
    super.key,
    required this.normalMesaiGun,
    required this.bayramMesaiGun,
    required this.normalMesaiRate,
    required this.bayramMesaiRate,
    required this.onMesaiChanged,
  });

  @override
  State<MesaiScreen> createState() => _MesaiScreenState();
}

class _MesaiScreenState extends State<MesaiScreen> {
  final List<MesaiRecord> _records = [];

  @override
  void initState() {
    super.initState();
    _loadRecords();
  }

  Future<void> _loadRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String? recordsJson = prefs.getString('mesai_records');
    
    if (recordsJson != null) {
      final List<dynamic> decoded = json.decode(recordsJson);
      setState(() {
        _records.clear();
        _records.addAll(decoded.map((e) => MesaiRecord.fromJson(e)).toList());
        _records.sort((a, b) => b.date.compareTo(a.date));
      });
      _notifyParent();
    } else {
      _initializeDummyRecords();
      _saveRecords();
    }
  }

  Future<void> _saveRecords() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = json.encode(_records.map((r) => r.toJson()).toList());
    await prefs.setString('mesai_records', encoded);
  }

  void _initializeDummyRecords() {
    DateTime now = DateTime.now();
    for (int i = 0; i < widget.normalMesaiGun; i++) {
      _records.add(MesaiRecord(
        id: 'n_$i',
        date: now.subtract(Duration(days: i + 1)),
        submitDate: now,
        type: MesaiType.normal,
      ));
    }
    for (int i = 0; i < widget.bayramMesaiGun; i++) {
      _records.add(MesaiRecord(
        id: 'b_$i',
        date: now.subtract(Duration(days: i + 10)),
        submitDate: now,
        type: MesaiType.bayram,
      ));
    }
    
    // Sort by date descending
    _records.sort((a, b) => b.date.compareTo(a.date));
  }

  void _notifyParent() {
    int normal = _records.where((r) => r.type == MesaiType.normal).length;
    int bayram = _records.where((r) => r.type == MesaiType.bayram).length;
    widget.onMesaiChanged(normal, bayram);
  }

  void _removeRecord(String id) {
    setState(() {
      _records.removeWhere((r) => r.id == id);
    });
    _saveRecords();
    _notifyParent();
  }

  void _addRecordNow(MesaiType type) {
    setState(() {
      _records.add(MesaiRecord(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        date: DateTime.now(),
        submitDate: DateTime.now(),
        type: type,
      ));
      _records.sort((a, b) => b.date.compareTo(a.date));
    });
    _saveRecords();
    _notifyParent();
  }

  void _removeLatestRecord(MesaiType type) {
    setState(() {
      final idx = _records.indexWhere((r) => r.type == type);
      if (idx != -1) {
        _records.removeAt(idx);
      }
    });
    _saveRecords();
    _notifyParent();
  }

  String _formatCurrency(double amount) {
    String whole = amount.truncate().toString();
    String formattedWhole = '';
    for (int i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) {
        formattedWhole += '.';
      }
      formattedWhole += whole[i];
    }
    String fractional = ((amount - amount.truncate()) * 100).truncate().toString().padLeft(2, '0');
    return '₺$formattedWhole,$fractional';
  }

  @override
  Widget build(BuildContext context) {
    int currentNormalCount = _records.where((r) => r.type == MesaiType.normal).length;
    int currentBayramCount = _records.where((r) => r.type == MesaiType.bayram).length;

    final double normalKazanc = currentNormalCount * widget.normalMesaiRate;
    final double bayramKazanc = currentBayramCount * widget.bayramMesaiRate;
    final double totalKazanc = normalKazanc + bayramKazanc;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Stack(
              children: [
                Container(
                  height: 280,
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF2E1065), Color(0xFF4338CA), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                Positioned(
                  right: -50,
                  top: -50,
                  child: Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                Positioned(
                  left: -30,
                  bottom: 80,
                  child: Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.05),
                    ),
                  ),
                ),
                SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left_rounded, color: Colors.white, size: 28),
                              onPressed: () {}, 
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            const Text(
                              'Mesai İşlemleri',
                              style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white70, width: 1),
                              ),
                              child: const Icon(Icons.info_outline_rounded, color: Colors.white, size: 14),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Aylık Mesai Girişi',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'Aşağıdan çalıştığınız mesai günlerini kaydedebilir,\ngeçmiş tarihli mesailerinizi takip edebilirsiniz.',
                                    style: TextStyle(
                                      color: Colors.white.withValues(alpha: 0.8),
                                      fontSize: 12,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: SizedBox(
                                height: 90,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  alignment: Alignment.centerRight,
                                  children: [
                                    Container(
                                      width: 70,
                                      height: 75,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF7C3AED),
                                        borderRadius: BorderRadius.circular(12),
                                        boxShadow: [
                                          BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(2, 5)),
                                        ],
                                        border: Border.all(color: const Color(0xFF8B5CF6), width: 1),
                                      ),
                                      child: const Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(Icons.calendar_month_rounded, color: Colors.white, size: 40),
                                        ],
                                      ),
                                    ),
                                    Positioned(
                                      bottom: -10,
                                      right: -10,
                                      child: Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
                                          ],
                                        ),
                                        child: const Icon(Icons.access_time_filled_rounded, color: Color(0xFF4338CA), size: 24),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 230,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNewMesaiCard(
                    title: 'Normal Mesai',
                    rateText: '₺${widget.normalMesaiRate.toStringAsFixed(0)} / gün',
                    days: currentNormalCount,
                    totalValue: normalKazanc,
                    color: const Color(0xFF2563EB),
                    bgColor: const Color(0xFFEFF6FF),
                    icon: Icons.work_history_rounded,
                    onIncrement: () => _addRecordNow(MesaiType.normal),
                    onDecrement: () => _removeLatestRecord(MesaiType.normal),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  _buildNewMesaiCard(
                    title: 'Bayram Mesaisi',
                    rateText: '₺${widget.bayramMesaiRate.toStringAsFixed(0)} / gün',
                    days: currentBayramCount,
                    totalValue: bayramKazanc,
                    color: const Color(0xFFEA580C),
                    bgColor: const Color(0xFFFFF7ED),
                    icon: Icons.celebration_rounded,
                    onIncrement: () => _addRecordNow(MesaiType.bayram),
                    onDecrement: () => _removeLatestRecord(MesaiType.bayram),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFF0FDF4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.trending_up_rounded, color: Color(0xFF10B981), size: 20),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),
                                  const Text('Toplam Ek Kazanç', style: TextStyle(fontSize: 13, color: Color(0xFF4B5563), fontWeight: FontWeight.bold)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '+ ${_formatCurrency(totalKazanc)}',
                                    style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF10B981), letterSpacing: -0.5),
                                  ),
                                ],
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFDCFCE7),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Stack(
                                    alignment: Alignment.center,
                                    clipBehavior: Clip.none,
                                    children: [
                                      Positioned(
                                        left: 10,
                                        bottom: 15,
                                        child: Icon(Icons.monetization_on, color: const Color(0xFF34D399).withValues(alpha: 0.8), size: 36),
                                      ),
                                      Positioned(
                                        right: 15,
                                        top: 15,
                                        child: Icon(Icons.monetization_on, color: const Color(0xFF10B981), size: 44),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  const Text(
                    'Geçmiş Mesailerim',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          
          if (_records.isEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.event_busy_rounded, color: Colors.grey.withValues(alpha: 0.3), size: 64),
                      const SizedBox(height: 16),
                      const Text('Henüz kaydedilmiş mesai bulunmuyor.', style: TextStyle(color: Colors.grey, fontSize: 14)),
                    ],
                  ),
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final record = _records[index];
                    final isNormal = record.type == MesaiType.normal;
                    final color = isNormal ? const Color(0xFF2563EB) : const Color(0xFFEA580C);
                    final bgColor = isNormal ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED);
                    final icon = isNormal ? Icons.work_history_rounded : Icons.celebration_rounded;
                    final title = isNormal ? 'Normal Mesai' : 'Bayram Mesaisi';

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2)),
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                          child: Icon(icon, color: color, size: 20),
                        ),
                        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1F2937))),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.event, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Mesai: ${DateFormat('dd MMMM yyyy').format(record.date)}',
                                  style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563), fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.edit_calendar, size: 12, color: Colors.grey),
                                const SizedBox(width: 4),
                                Text(
                                  'Kayıt: ${DateFormat('dd MMMM yyyy HH:mm').format(record.submitDate)}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ],
                            ),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                          onPressed: () => _removeRecord(record.id),
                        ),
                      ),
                    );
                  },
                  childCount: _records.length,
                ),
              ),
            ),
            
          const SliverToBoxAdapter(
            child: SizedBox(height: 120),
          )
        ],
      ),
    );
  }

  Widget _buildNewMesaiCard({
    required String title,
    required String rateText,
    required int days,
    required double totalValue,
    required Color color,
    required Color bgColor,
    required IconData icon,
    required VoidCallback onIncrement,
    required VoidCallback onDecrement,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            left: 0, top: 20, bottom: 20,
            child: Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(topRight: Radius.circular(4), bottomRight: Radius.circular(4)),
              ),
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: bgColor,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color, size: 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937))),
                          const SizedBox(height: 4),
                          Text(rateText, style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                    Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: bgColor.withValues(alpha: 0.5), 
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: onDecrement,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                child: Icon(Icons.remove, color: color, size: 18),
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 24,
                            child: Text(
                              days.toString(),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1F2937)),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: onIncrement,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                alignment: Alignment.center,
                                child: Icon(Icons.add, color: color, size: 18),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 20),
                const Divider(color: Color(0xFFF3F4F6), thickness: 1, height: 1),
                const SizedBox(height: 16),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Bu kalemden kazancınız', style: TextStyle(fontSize: 13, color: Color(0xFF6B7280))),
                    Text(
                      '+ ${_formatCurrency(totalValue)}',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
