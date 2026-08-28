import 'dart:ui';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  WeatherData? _weatherData;
  bool _isLoading = true;
  DateTime _lastUpdateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _fetchWeather();
  }

  Future<void> _fetchWeather() async {
    final data = await WeatherService.getCurrentWeather();
    if (mounted) {
      setState(() {
        _weatherData = data;
        _isLoading = false;
        _lastUpdateTime = DateTime.now();
      });
    }
  }

  IconData _getWeatherIcon(int code) {
    if (code == 0) return Icons.wb_sunny_rounded;
    if (code >= 1 && code <= 3) return Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 65) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 75) return Icons.ac_unit_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  Color _getWeatherColor(int code) {
    if (code == 0) return const Color(0xFFFFD700);
    return Colors.white;
  }

  String _getTimeAgo() {
    final diff = DateTime.now().difference(_lastUpdateTime);
    if (diff.inMinutes == 0) return 'şimdi';
    return '${diff.inMinutes} dk önce';
  }

  @override
  Widget build(BuildContext context) {
    final topBgColor = const Color(0xFF0F172A); // Koyu Lacivert arka plan
    final pageBgColor = const Color(0xFFF8F9FE); // Beyaz sayfa arka planı

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        title: const Text('Hava Durumu', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
        backgroundColor: topBgColor,
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: topBgColor))
          : RefreshIndicator(
              onRefresh: _fetchWeather,
              child: Stack(
                children: [
                  // Üst kısımdaki koyu lacivert arka plan (AppBardan taşıyor)
                  Container(
                    height: 120,
                    width: double.infinity,
                    color: topBgColor,
                  ),
                  
                  SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hero Hava Durumu Kartı
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          padding: const EdgeInsets.all(24),
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(32),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E3A8A), Color(0xFF2563EB), Color(0xFF3B82F6)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(color: const Color(0xFF2563EB).withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 10)),
                            ],
                          ),
                          child: Stack(
                            children: [
                              // Arka plan bulut efekti
                              Positioned(
                                right: -30,
                                top: -10,
                                child: Icon(Icons.cloud, size: 140, color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              Positioned(
                                right: 40,
                                bottom: -20,
                                child: Icon(Icons.cloud, size: 100, color: Colors.white.withValues(alpha: 0.15)),
                              ),
                              
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Hatay, Payas',
                                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'İsdemir Liman Bölgesi',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withValues(alpha: 0.7)),
                                  ),
                                  const SizedBox(height: 32),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Hava İkonu
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(alpha: 0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          _weatherData != null ? _getWeatherIcon(_weatherData!.weatherCode) : Icons.wb_sunny_rounded,
                                          color: _weatherData != null ? _getWeatherColor(_weatherData!.weatherCode) : Colors.amber,
                                          size: 64,
                                        ),
                                      ),
                                      // Derece ve Durum
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            _weatherData != null ? '${_weatherData!.temperature.round()}°' : '--°',
                                            style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w900, color: Colors.white, height: 1.0),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _weatherData?.getWeatherDescription() ?? 'Yükleniyor...',
                                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Liman Operasyonları Başlığı
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  boxShadow: [
                                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))
                                  ]
                                ),
                                child: const Icon(Icons.anchor_rounded, color: Color(0xFF1E293B), size: 18),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Liman Operasyon Verileri',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Color(0xFF1E293B)),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Operasyon Kartları (Grid)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: GridView.count(
                            crossAxisCount: 2,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.85,
                            children: [
                              _buildDataCard(
                                icon: Icons.waves_rounded,
                                iconBgColor: const Color(0xFFE0F2FE),
                                iconColor: const Color(0xFF0284C7),
                                title: 'Dalga Boyu',
                                value: _weatherData != null ? '${_weatherData!.waveHeight} m' : '--',
                                waveColor: const Color(0xFF3B82F6),
                              ),
                              _buildDataCard(
                                icon: Icons.cloudy_snowing,
                                iconBgColor: const Color(0xFFDCFCE7),
                                iconColor: const Color(0xFF16A34A),
                                title: 'Görüş Mesafesi',
                                value: _weatherData != null ? '${(_weatherData!.visibility / 1000).toStringAsFixed(1)} km' : '--',
                                waveColor: const Color(0xFF10B981),
                              ),
                              _buildDataCard(
                                icon: Icons.air_rounded,
                                iconBgColor: const Color(0xFFF3E8FF),
                                iconColor: const Color(0xFF9333EA),
                                title: 'Rüzgar',
                                value: _weatherData != null ? '${_weatherData!.windSpeed} km/s' : '--',
                                waveColor: const Color(0xFF8B5CF6),
                              ),
                              _buildDataCard(
                                icon: Icons.water_drop_rounded,
                                iconBgColor: const Color(0xFFE0F2FE),
                                iconColor: const Color(0xFF0284C7),
                                title: 'Nem Oranı',
                                value: _weatherData != null ? '%${_weatherData!.humidity}' : '--',
                                waveColor: const Color(0xFF0EA5E9),
                              ),
                            ],
                          ),
                        ),
                        
                        const SizedBox(height: 32),
                        
                        // Alt Bilgi Kutusu
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9), // Slate 100
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF3B82F6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.info_outline, color: Colors.white, size: 14),
                                ),
                                const SizedBox(width: 12),
                                const Expanded(
                                  child: Text(
                                    'Veriler anlık olarak güncellenmektedir.',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF475569)),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      'Son güncelleme: ${_getTimeAgo()}',
                                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF3B82F6)),
                                    ),
                                    const SizedBox(width: 4),
                                    const Icon(Icons.access_time, color: Color(0xFF3B82F6), size: 12),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDataCard({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String title,
    required String value,
    required Color waveColor,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Dalga Grafiği
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 40,
              child: CustomPaint(
                painter: WavePainter(waveColor),
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: iconBgColor,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icon, color: iconColor, size: 24),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1), size: 20),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    title,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 10), // Grafiğin üstünde boşluk
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Özel Dalga (Sine Wave) Çizici
class WavePainter extends CustomPainter {
  final Color color;

  WavePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final path = Path();
    
    // Basit bir sinüs dalgası
    for (double i = 0; i <= size.width; i++) {
      double y = size.height / 2 + 5 * math.sin((i / size.width) * 4 * math.pi);
      if (i == 0) {
        path.moveTo(i, y);
      } else {
        path.lineTo(i, y);
      }
    }

    // Çizginin altını dolduracak yarı saydam gradyan
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.15), color.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final fillPath = Path.from(path);
    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WavePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
