import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class LeaveRequest {
  final String title;
  final DateTime startDate;
  final DateTime endDate;
  final String status;

  LeaveRequest({
    required this.title,
    required this.startDate,
    required this.endDate,
    required this.status,
  });
}

class IzinlerScreen extends StatefulWidget {
  final int ucretliIzinGun;
  final int ucretsizIzinGun;
  final double unpaidLeaveRate;
  final Function(int, int) onIzinChanged;

  const IzinlerScreen({
    super.key,
    required this.ucretliIzinGun,
    required this.ucretsizIzinGun,
    required this.unpaidLeaveRate,
    required this.onIzinChanged,
  });

  @override
  State<IzinlerScreen> createState() => _IzinlerScreenState();
}

class TopCurveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    // Start a bit down to allow for a rounded corner effect on the left
    path.moveTo(0, 30);
    path.quadraticBezierTo(0, 10, 25, 12); // Top-left rounded corner
    
    // Slanted curve across the top
    path.quadraticBezierTo(size.width * 0.5, 20, size.width - 25, 45); 
    
    // Top-right rounded corner
    path.quadraticBezierTo(size.width, 50, size.width, 75);
    
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _IzinlerScreenState extends State<IzinlerScreen> {
  late int _ucretliGun;
  late int _ucretsizGun;
  final int _maxUcretli = 14;
  final int _maxUcretsiz = 30;

  final List<LeaveRequest> _leaveRequests = [
    LeaveRequest(
      title: 'Yıllık İzin',
      startDate: DateTime(2024, 6, 12),
      endDate: DateTime(2024, 6, 14),
      status: 'Onaylandı',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _ucretliGun = widget.ucretliIzinGun;
    _ucretsizGun = widget.ucretsizIzinGun;
  }

  void _notifyChanges() {
    widget.onIzinChanged(_ucretliGun, _ucretsizGun);
  }

  Future<void> _createLeaveRequest() async {
    final DateTimeRange? pickedRange = await showModalBottomSheet<DateTimeRange>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CustomDateRangePicker(),
    );

    if (pickedRange != null) {
      if (!mounted) return;
      
      final DateFormat formatter = DateFormat('dd.MM.yyyy');
      final String startStr = formatter.format(pickedRange.start);
      final String endStr = formatter.format(pickedRange.end);

      final bool? confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('İzin Onayı', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Text(
            '$startStr - $endStr tarihleri arasında yıllık izin talebi oluşturulacak.\n\nOnaylıyor musunuz?',
            style: const TextStyle(height: 1.5),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Reddet', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF382FE0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Onayla', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );

      if (confirm == true) {
        final days = pickedRange.end.difference(pickedRange.start).inDays + 1;
        setState(() {
          _leaveRequests.insert(
            0,
            LeaveRequest(
              title: 'Yıllık İzin',
              startDate: pickedRange.start,
              endDate: pickedRange.end,
              status: 'Onaylandı',
            ),
          );
          // Kullanılan ücretli izin günlerine ekle
          _ucretliGun = (_ucretliGun + days).clamp(0, _maxUcretli);
        });
        _notifyChanges();

        if (!mounted) return;
        final remaining = _maxUcretli - _ucretliGun;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İzin onaylandı! Kalan ücretli izin: $remaining gün.'),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _cancelRequest(LeaveRequest request) {
    final days = request.endDate.difference(request.startDate).inDays + 1;
    setState(() {
      _leaveRequests.remove(request);
      // İptal edilince kullanılan günleri geri ekle
      _ucretliGun = (_ucretliGun - days).clamp(0, _maxUcretli);
    });
    _notifyChanges();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('İzin iptal edildi. Kalan ücretli izin: ${_maxUcretli - _ucretliGun} gün.'),
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAllRequests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx2, setSheetState) {
          return Container(
            height: MediaQuery.of(context).size.height * 0.75,
            decoration: const BoxDecoration(
              color: Color(0xFFF9FAFF),
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Row(
                    children: [
                      Text('Tüm İzin Taleplerim',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E293B))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: _leaveRequests.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.event_busy_rounded, size: 48, color: Color(0xFFCBD5E1)),
                              SizedBox(height: 12),
                              Text('Henüz izin talebiniz bulunmuyor.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.w500)),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _leaveRequests.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (_, i) => _buildRequestItem(
                            _leaveRequests[i],
                            onDelete: () {
                              setSheetState(() => _cancelRequest(_leaveRequests[i]));
                            },
                          ),
                        ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double totalDeduction = _ucretsizGun * widget.unpaidLeaveRate;
    final blueColor = const Color(0xFF2823AC);

    return Scaffold(
      backgroundColor: blueColor,
      body: Stack(
        children: [
          // Header Content
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        const Text(
                          'İzin Yönetimi',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'İzin haklarınızı buradan takip edebilirsiniz.',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                        ),
                      ],
                    ),
                  ),
                  // Calendar Widget
                  Container(
                    width: 65,
                    height: 75,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 15, offset: const Offset(0, 8))
                      ]
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF14D58), Color(0xFFF5794F)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
                          ),
                          child: const Text('July', textAlign: TextAlign.center, style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(height: 2),
                        const Text('17', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: Color(0xFF1E293B), height: 1.1)),
                        const Text('Çarşamba', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF64748B))),
                      ],
                    ),
                  )
                ],
              ),
            ),
          ),
          
          // White Background Area
          Positioned(
            top: 140,
            left: 0,
            right: 0,
            bottom: 0,
            child: ClipPath(
              clipper: TopCurveClipper(),
              child: Container(
                color: const Color(0xFFF9FAFF), // Soft light blue-grey background
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(top: 70, left: 24, right: 24, bottom: 120),
                  child: Column(
                    children: [
                      // Ücretli İzin
                      _buildLeaveCard(
                        title: 'Ücretli İzin (Gün)',
                        subtitle: 'Maaşınızdan kesinti\nyapılmaz.',
                        selectedDays: _ucretliGun,
                        remainingDays: _maxUcretli - _ucretliGun,
                        icon: Icons.park_rounded,
                        iconColor: const Color(0xFF16A34A),
                        stripColor: const Color(0xFF22C55E),
                        onAdd: () {
                          if (_ucretliGun < _maxUcretli) {
                            setState(() => _ucretliGun++);
                            _notifyChanges();
                          }
                        },
                        onRemove: () {
                          if (_ucretliGun > 0) {
                            setState(() => _ucretliGun--);
                            _notifyChanges();
                          }
                        },
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Ücretsiz İzin
                      _buildLeaveCard(
                        title: 'Ücretsiz İzin (Gün)',
                        subtitle: 'Günlük ₺${widget.unpaidLeaveRate.toStringAsFixed(0)} kesinti\nuygulanır.',
                        selectedDays: _ucretsizGun,
                        remainingDays: _maxUcretsiz - _ucretsizGun,
                        icon: Icons.airplanemode_active,
                        iconColor: const Color(0xFF5A44E4),
                        stripColor: const Color(0xFF5A44E4),
                        onAdd: () {
                          if (_ucretsizGun < _maxUcretsiz) {
                            setState(() => _ucretsizGun++);
                            _notifyChanges();
                          }
                        },
                        onRemove: () {
                          if (_ucretsizGun > 0) {
                            setState(() => _ucretsizGun--);
                            _notifyChanges();
                          }
                        },
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Hesaplanan Kesinti
                      _buildCalculatorCard(totalDeduction),
                      
                      const SizedBox(height: 32),
                      
                      // Son Talepler Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Son İzin Talepleriniz',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                          ),
                          GestureDetector(
                            onTap: _showAllRequests,
                            child: const Row(
                              children: [
                                Text(
                                  'Tümü',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF4C3AE3)),
                                ),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_forward, color: Color(0xFF4C3AE3), size: 16),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      
                      // Liste Elemanları (son 3)
                      ..._leaveRequests.take(3).map((request) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _buildRequestItem(
                          request,
                          onDelete: () => _cancelRequest(request),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),
          
          // Sabit Buton
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.only(left: 24, right: 24, bottom: 30, top: 20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [const Color(0xFFF9FAFF), const Color(0xFFF9FAFF).withValues(alpha: 0.0)],
                )
              ),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _createLeaveRequest,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF382FE0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 10,
                    shadowColor: const Color(0xFF382FE0).withValues(alpha: 0.4),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                        child: const Icon(Icons.add, color: Color(0xFF382FE0), size: 16),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Yeni İzin Talebi Oluştur',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaveCard({
    required String title,
    required String subtitle,
    required int selectedDays,
    required int remainingDays,
    required IconData icon,
    required Color iconColor,
    required Color stripColor,
    required VoidCallback onAdd,
    required VoidCallback onRemove,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Colored Strip
              Container(
                width: 6,
                color: stripColor,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 20.0),
                  child: Row(
                    children: [
                      // Soft Shadow Icon
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: iconColor.withValues(alpha: 0.25),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ]
                        ),
                        child: Icon(icon, color: iconColor, size: 28),
                      ),
                      const SizedBox(width: 20),
                      // Texts
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              subtitle,
                              style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), height: 1.4),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Remaining Days
                      Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            remainingDays.toString(),
                            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: stripColor, height: 1.0),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Kalan Gün',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      // Stepper
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
                          ]
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: onRemove,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                                child: Icon(Icons.remove, size: 14, color: Color(0xFF64748B)),
                              ),
                            ),
                            Text(
                              selectedDays.toString(),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                            ),
                            GestureDetector(
                              onTap: onAdd,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 4),
                                child: Icon(Icons.add, size: 14, color: Color(0xFF64748B)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCalculatorCard(double totalDeduction) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Background Faint Calculator Icon
          Positioned(
            right: -10,
            bottom: 20,
            child: Icon(Icons.calculate_outlined, size: 110, color: Colors.grey.withValues(alpha: 0.15)),
          ),
          
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 3D-like Calculator Icon
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7A6CF0), Color(0xFF4330D1)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF4330D1).withValues(alpha: 0.4),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        )
                      ]
                    ),
                    child: const Column(
                      children: [
                        Row(
                          children: [
                            Text('+', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(width: 8),
                            Text('-', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                        Row(
                          children: [
                            Text('×', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                            SizedBox(width: 8),
                            Text('=', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ],
                        ),
                      ],
                    )
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HESAPLANAN KESİNTİ',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF7B879D), letterSpacing: 1.0),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '- ₺${totalDeduction.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: Color(0xFF382FE0), letterSpacing: -1),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '$_ucretsizGun Gün Ücretsiz İzin',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF7B879D)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Info Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF5F3FF), // Light purple bg
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Color(0xFF5A4CDE), shape: BoxShape.circle),
                      child: const Icon(Icons.info_outline, color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Seçtiğiniz ücretsiz izin gün sayısına göre maaşınızdan kesinti uygulanacaktır.',
                        style: TextStyle(fontSize: 12, color: const Color(0xFF475569).withValues(alpha: 0.9), height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRequestItem(LeaveRequest request, {VoidCallback? onDelete}) {
    final DateFormat formatter = DateFormat('dd.MM.yyyy');
    final isApproved = request.status == 'Onaylandı';
    final statusColor = isApproved ? const Color(0xFF10B981) : const Color(0xFFF59E0B);
    final statusBgColor = isApproved ? const Color(0xFFECFDF5) : const Color(0xFFFEF3C7);
    final duration = request.endDate.difference(request.startDate).inDays + 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEEDFC),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.beach_access_rounded, color: Color(0xFF5A4CDE), size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.title,
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(Icons.calendar_today_outlined, size: 11, color: Color(0xFF94A3B8)),
                          const SizedBox(width: 4),
                          Text(
                            '${formatter.format(request.startDate)} – ${formatter.format(request.endDate)}',
                            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusBgColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6, height: 6,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        request.status,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Footer bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
              border: Border(top: BorderSide(color: Colors.grey.shade100)),
            ),
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded, size: 14, color: Color(0xFF64748B)),
                const SizedBox(width: 6),
                Text(
                  '$duration gün izin',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                ),
                const Spacer(),
                if (onDelete != null)
                  GestureDetector(
                    onTap: () async {
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          title: const Text('İzni İptal Et', style: TextStyle(fontWeight: FontWeight.bold)),
                          content: const Text('Bu izin talebini iptal etmek istediğinizden emin misiniz?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Vazgeç', style: TextStyle(color: Color(0xFF64748B))),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text('İptal Et', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true) onDelete();
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cancel_outlined, size: 14, color: Colors.red.shade400),
                          const SizedBox(width: 4),
                          Text('İptal Et', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade400)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Custom Date Range Picker ───────────────────────────────────────────────

class _CustomDateRangePicker extends StatefulWidget {
  const _CustomDateRangePicker();

  @override
  State<_CustomDateRangePicker> createState() => _CustomDateRangePickerState();
}

class _CustomDateRangePickerState extends State<_CustomDateRangePicker> {
  static const Color _accent = Color(0xFF382FE0);
  static const List<String> _aylar = [
    '', 'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
    'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
  ];
  static const List<String> _gunler = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  late DateTime _displayMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _displayMonth = DateTime(DateTime.now().year, DateTime.now().month);
  }

  void _prevMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month - 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _displayMonth = DateTime(_displayMonth.year, _displayMonth.month + 1);
    });
  }

  void _onDayTap(DateTime day) {
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        _startDate = day;
        _endDate = null;
      } else {
        if (day.isBefore(_startDate!)) {
          _endDate = _startDate;
          _startDate = day;
        } else {
          _endDate = day;
        }
      }
    });
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  bool _isStart(DateTime day) =>
      _startDate != null && _isSameDay(day, _startDate!);
  bool _isEnd(DateTime day) =>
      _endDate != null && _isSameDay(day, _endDate!);
  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isToday(DateTime day) => _isSameDay(day, DateTime.now());
  bool _isPast(DateTime day) {
    final today = DateTime.now();
    return day.isBefore(DateTime(today.year, today.month, today.day));
  }

  List<Widget> _buildDays() {
    final firstDay = DateTime(_displayMonth.year, _displayMonth.month, 1);
    // Monday=1 ... Sunday=7 => offset 0-6 where Monday=0
    int startOffset = firstDay.weekday - 1; // weekday: Mon=1
    final daysInMonth = DateUtils.getDaysInMonth(_displayMonth.year, _displayMonth.month);

    List<Widget> cells = [];

    // Empty cells before first day
    for (int i = 0; i < startOffset; i++) {
      cells.add(const SizedBox());
    }

    for (int d = 1; d <= daysInMonth; d++) {
      final day = DateTime(_displayMonth.year, _displayMonth.month, d);
      final isStart = _isStart(day);
      final isEnd = _isEnd(day);
      final inRange = _isInRange(day);
      final isSelected = isStart || isEnd;
      final isPast = _isPast(day);
      final isToday = _isToday(day);

      cells.add(
        GestureDetector(
          onTap: () => _onDayTap(day),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 3),
            decoration: BoxDecoration(
              color: isSelected
                  ? _accent
                  : inRange
                      ? _accent.withValues(alpha: 0.12)
                      : Colors.transparent,
              borderRadius: isStart && _endDate != null
                  ? const BorderRadius.horizontal(left: Radius.circular(20))
                  : isEnd
                      ? const BorderRadius.horizontal(right: Radius.circular(20))
                      : inRange
                          ? BorderRadius.zero
                          : BorderRadius.circular(20),
            ),
            child: Center(
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isSelected ? _accent : Colors.transparent,
                  shape: BoxShape.circle,
                  border: isToday && !isSelected
                      ? Border.all(color: _accent, width: 1.5)
                      : null,
                ),
                child: Center(
                  child: Text(
                    '$d',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected || isToday
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : inRange
                              ? _accent
                              : isToday
                                  ? _accent
                                  : const Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return cells;
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return '—';
    return '${dt.day} ${_aylar[dt.month]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final canSave = _startDate != null && _endDate != null;
    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          // Handle bar
          const SizedBox(height: 12),
          Container(
            width: 40, height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('İzin Tarihi Seçin',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500)),
                      SizedBox(height: 4),
                      Text('Tarih aralığını belirleyin',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Selected range display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 8, height: 8, decoration: const BoxDecoration(color: _accent, shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text('Başlangıç', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        Text(_formatDate(_startDate),
                            style: TextStyle(
                              color: _startDate != null ? Colors.white : Colors.white38,
                              fontSize: 14, fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white12),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(width: 8, height: 8, decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.4), shape: BoxShape.circle)),
                          const SizedBox(width: 8),
                          const Text('Bitiş', style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 4),
                        Text(_formatDate(_endDate),
                            style: TextStyle(
                              color: _endDate != null ? Colors.white : Colors.white38,
                              fontSize: 14, fontWeight: FontWeight.bold,
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Calendar
          Expanded(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  // Month navigator
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                    child: Row(
                      children: [
                        GestureDetector(
                          onTap: _prevMonth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.chevron_left, size: 20, color: Color(0xFF1E293B)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '${_aylar[_displayMonth.month]} ${_displayMonth.year}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E293B),
                            ),
                          ),
                        ),
                        GestureDetector(
                          onTap: _nextMonth,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.chevron_right, size: 20, color: Color(0xFF1E293B)),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Day headers
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: _gunler.map((g) => Expanded(
                        child: Center(
                          child: Text(g, style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                          )),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Day grid
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: GridView.count(
                        crossAxisCount: 7,
                        physics: const NeverScrollableScrollPhysics(),
                        children: _buildDays(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Save button
          Padding(
            padding: EdgeInsets.fromLTRB(24, 0, 24, MediaQuery.of(context).padding.bottom + 16),
            child: SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: canSave
                    ? () => Navigator.pop(context, DateTimeRange(start: _startDate!, end: _endDate!))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: canSave ? _accent : Colors.white.withValues(alpha: 0.1),
                  foregroundColor: Colors.white,
                  elevation: canSave ? 8 : 0,
                  shadowColor: _accent.withValues(alpha: 0.4),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Text(
                  canSave ? 'Kaydet' : 'Tarih aralığı seçin',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: canSave ? Colors.white : Colors.white38,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

