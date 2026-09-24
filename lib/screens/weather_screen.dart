import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/weather_service.dart';

class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  State<WeatherScreen> createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> with SingleTickerProviderStateMixin {
  WeatherData? _weatherData;
  bool _isLoading = true;
  DateTime _lastUpdateTime = DateTime.now();
  late AnimationController _waveController;
  int _selectedDayForHourly = 0;
  int? _expandedWeeklyDayIndex;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
    _fetchWeather();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
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

  IconData _getWeatherIcon(int code, {bool isNight = false}) {
    if (code == 0) return isNight ? Icons.nightlight_round : Icons.wb_sunny_rounded;
    if (code >= 1 && code <= 3) return isNight ? Icons.nights_stay_rounded : Icons.cloud_rounded;
    if (code == 45 || code == 48) return Icons.foggy;
    if (code >= 51 && code <= 65) return Icons.water_drop_rounded;
    if (code >= 71 && code <= 75) return Icons.ac_unit_rounded;
    if (code >= 80 && code <= 82) return Icons.shower_rounded;
    if (code >= 95) return Icons.thunderstorm_rounded;
    return Icons.cloud_rounded;
  }

  Color _getWeatherColor(int code, {bool isNight = false}) {
    if (code == 0) return isNight ? const Color(0xFF93C5FD) : const Color(0xFFFFD700);
    if (code >= 51 && code <= 82) return const Color(0xFF38BDF8);
    if (code >= 95) return const Color(0xFFFBBF24);
    return Colors.white70;
  }

  String _getTimeAgo() {
    final diff = DateTime.now().difference(_lastUpdateTime);
    if (diff.inMinutes == 0) return 'şimdi';
    return '${diff.inMinutes} dk önce';
  }

  String _getWeekdayName(DateTime date) {
    final today = DateTime.now();
    if (date.year == today.year && date.month == today.month && date.day == today.day) {
      return 'Bugün';
    }
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    return days[(date.weekday - 1) % 7];
  }

  @override
  Widget build(BuildContext context) {
    const pageBgColor = Color(0xFF080B11);

    return Scaffold(
      backgroundColor: pageBgColor,
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D121E),
        elevation: 0,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Padding(
            padding: const EdgeInsets.all(10.0),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF161D2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF28354D)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
            ),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'İSDEMİR LİMAN METEOROLOJİ',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 13.5,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 5,
                        height: 5,
                        decoration: const BoxDecoration(
                          color: Color(0xFF34D399),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'CANLI',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF34D399),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              'Payas / İskenderun Rıhtım Sahası • Güncelleme: ${_getTimeAgo()}',
              style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Yenile',
            icon: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: const Color(0xFF161D2E),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF28354D)),
              ),
              child: const Icon(Icons.refresh_rounded, color: Color(0xFF38BDF8), size: 18),
            ),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchWeather();
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: const CircularProgressIndicator(
                      color: Color(0xFF8B5CF6),
                      strokeWidth: 2.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'WeatherNext 3 AI Yörünge Verileri Alınıyor...',
                    style: GoogleFonts.orbitron(
                      fontSize: 12,
                      letterSpacing: 1.0,
                      color: const Color(0xFFCBD5E1),
                    ),
                  ),
                ],
              ),
            )
          : RefreshIndicator(
              color: const Color(0xFF8B5CF6),
              backgroundColor: const Color(0xFF121624),
              onRefresh: _fetchWeather,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 12),

                    // 0. WeatherNext 3 AI DeepMind Kokpit Başlığı
                    _buildWeatherNext3Banner(),

                    const SizedBox(height: 12),

                    // 1. Hero Hava Durumu Kartı (Ana Merkez)
                    _buildHeroWeatherCard(),

                    const SizedBox(height: 14),

                    // 1.1 WeatherNext 3 AI Saha & Vardiya Brifingi
                    _buildWeatherNext3AiAdvisoryCard(),

                    const SizedBox(height: 20),

                    // 2. 24 Saatlik Tahmin Şeridi (Apple Horizon Slider + Gün Seçici)
                    _buildHourlyForecastSection(),

                    const SizedBox(height: 22),

                    // 3. İSDEMİR Rıhtım & Vinç Güvenlik Kokpiti
                    _buildPortSafetySection(),

                    const SizedBox(height: 22),

                    // 4. Liman Operasyon Parametreleri (Canlı Dalga İle)
                    _buildMarineDataGrid(),

                    const SizedBox(height: 22),

                    // 5. Gün Doğumu & Gün Batımı Güneş Yayı
                    _buildSunArcSection(),

                    const SizedBox(height: 22),

                    // 6. 7 Günlük Haftalık Tahmin Çubukları & Açılır Saatlik Detay
                    _buildWeeklyForecastSection(),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
    );
  }

  // 0. WeatherNext 3 AI Telemetry Banner (Google DeepMind)
  Widget _buildWeatherNext3Banner() {
    final data = _weatherData;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF200F3B),
            Color(0xFF0F172A),
            Color(0xFF081C2E),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: const Color(0xFF8B5CF6).withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.16),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF38BDF8)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'WEATHERNEXT 3',
                            style: GoogleFonts.orbitron(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF10B981), width: 0.8),
                            ),
                            child: Text(
                              'AI NEURAL CORE',
                              style: GoogleFonts.orbitron(
                                fontSize: 8.5,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF34D399),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Google DeepMind High-Resolution Atmospheric Engine',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFFC4B5FD),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF34D399).withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF10B981),
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '0-Lag',
                      style: GoogleFonts.orbitron(
                        fontSize: 9.5,
                        color: const Color(0xFF34D399),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  const Color(0xFF8B5CF6).withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildWn3Badge(Icons.grid_4x4_rounded, '5 km Neural Grid'),
                const SizedBox(width: 8),
                _buildWn3Badge(Icons.satellite_alt_rounded, 'Ham Uydu Beslemesi'),
                const SizedBox(width: 8),
                _buildWn3Badge(Icons.height_rounded, '100m Vinç İrtifası'),
                const SizedBox(width: 8),
                _buildWn3Badge(Icons.verified_rounded, '%${data?.aiConfidence ?? 98.8} AI Güven'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWn3Badge(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFA78BFA)),
          const SizedBox(width: 5),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: const Color(0xFFE2E8F0),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // 1. Hero Hava Durumu Kartı (Merkez Ekran)
  Widget _buildHeroWeatherCard() {
    final data = _weatherData;
    final isDay = data?.isDay ?? true;
    final code = data?.weatherCode ?? 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(22),
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: isDay
              ? [const Color(0xFF7F1D1D), const Color(0xFF281119), const Color(0xFF131724)]
              : [const Color(0xFF1E293B), const Color(0xFF0F172A), const Color(0xFF0A0F1D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: (isDay ? const Color(0xFFE50914) : const Color(0xFF38BDF8)).withValues(alpha: 0.2),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: (isDay ? const Color(0xFFE50914) : const Color(0xFF38BDF8)).withValues(alpha: 0.4),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isDay ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: isDay ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'İSDEMİR LİMAN SAHASI',
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Text(
                  isDay ? '☀️ Gündüz Vardiyası' : '🌙 Gece Vardiyası',
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ),
            ],
          ),

          const SizedBox(height: 18),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data != null ? '${data.temperature.round()}' : '--',
                        style: GoogleFonts.inter(
                          fontSize: 66,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          height: 1.0,
                          letterSpacing: -2,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6.0),
                        child: Text(
                          '°C',
                          style: GoogleFonts.inter(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: isDay ? const Color(0xFFF87171) : const Color(0xFF38BDF8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    data?.getWeatherDescription() ?? 'Telemetri okunuyor...',
                    style: GoogleFonts.inter(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Hissedilen ${data != null ? '${data.apparentTemperature.round()}°' : '--'}',
                        style: GoogleFonts.inter(fontSize: 12.5, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          data?.getWindCompassDirection() ?? '',
                          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // Büyük Holografik İkon
              Container(
                width: 95,
                height: 95,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      (isDay ? Colors.amber : const Color(0xFF38BDF8)).withValues(alpha: 0.25),
                      Colors.transparent,
                    ],
                  ),
                  border: Border.all(
                    color: (isDay ? Colors.amber : const Color(0xFF38BDF8)).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _getWeatherIcon(code, isNight: !isDay),
                  color: _getWeatherColor(code, isNight: !isDay),
                  size: 58,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),
          const Divider(color: Color(0xFF334155), thickness: 0.8, height: 1),
          const SizedBox(height: 14),

          // Alt İstatistikler
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeroSubStat(Icons.water_drop_outlined, 'Nem', '%${data?.humidity ?? '--'}'),
              _buildHeroSubStat(Icons.air_rounded, 'Rüzgar', '${data?.windSpeed ?? '--'} km/s'),
              _buildHeroSubStat(Icons.visibility_outlined, 'Görüş', '${((data?.visibility ?? 0) / 1000).toStringAsFixed(1)} km'),
              _buildHeroSubStat(Icons.wb_iridescent_rounded, 'UV', data != null ? data.uvIndex.toStringAsFixed(1) : '--'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSubStat(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF94A3B8), size: 16),
        const SizedBox(width: 5),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.inter(color: const Color(0xFF94A3B8), fontSize: 10)),
            Text(value, style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  // 1.1 WeatherNext 3 AI Saha & Vardiya Brifingi
  Widget _buildWeatherNext3AiAdvisoryCard() {
    final data = _weatherData;
    final advisory = data?.aiAdvisory ?? '';
    if (advisory.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.35), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF38BDF8).withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.psychology_rounded, color: Color(0xFF38BDF8), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WeatherNext 3 AI • Saha Brifingi',
                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DeepMind Entegre',
                  style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFFC4B5FD), fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            advisory,
            style: GoogleFonts.inter(
              fontSize: 12.5,
              color: const Color(0xFFCBD5E1),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }

  // 2. 24 Saatlik Tahmin Şeridi (Apple Horizon Slider + Gün Seçici)
  Widget _buildHourlyForecastSection() {
    final dailyList = _weatherData?.dailyForecasts ?? [];
    List<HourlyForecast> list = [];

    if (_selectedDayForHourly == 0) {
      list = _weatherData?.hourlyForecasts ?? [];
    } else if (_selectedDayForHourly < dailyList.length) {
      list = dailyList[_selectedDayForHourly].hourlyForecasts;
    }

    if (list.isEmpty && dailyList.isNotEmpty) {
      list = dailyList[0].hourlyForecasts;
    }

    if (list.isEmpty) return const SizedBox.shrink();

    String selectedDayTitle = 'Bugün';
    if (_selectedDayForHourly < dailyList.length) {
      selectedDayTitle = _getWeekdayName(dailyList[_selectedDayForHourly].date);
      if (_selectedDayForHourly == 0) selectedDayTitle = 'Bugün';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Başlık & Günlük Rüzgar/Yağış Özeti
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.schedule_rounded, color: Color(0xFF38BDF8), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Saatlik Hava & Rüzgar Seyri',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.4)),
                ),
                child: Text(
                  selectedDayTitle,
                  style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.bold, color: const Color(0xFF38BDF8)),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 10),

        // 7 Gün Hızlı Seçici Filtre Çubukları (Chips)
        if (dailyList.isNotEmpty)
          SizedBox(
            height: 38,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: dailyList.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = dailyList[index];
                final isSelected = _selectedDayForHourly == index;
                final dayLabel = index == 0 ? 'Bugün' : _getWeekdayName(d.date);

                return GestureDetector(
                  onTap: () {
                    setState(() => _selectedDayForHourly = index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF8B5CF6) : const Color(0xFF131826),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? const Color(0xFFA78BFA) : const Color(0xFF242C3F),
                        width: 1.0,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: const Color(0xFF8B5CF6).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              )
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (d.rainProbability >= 20) ...[
                          const Icon(Icons.water_drop_rounded, size: 11, color: Color(0xFF38BDF8)),
                          const SizedBox(width: 4),
                        ],
                        Text(
                          dayLabel,
                          style: GoogleFonts.inter(
                            fontSize: 11.5,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                          ),
                        ),
                        if (d.rainProbability >= 20) ...[
                          const SizedBox(width: 4),
                          Text(
                            '%${d.rainProbability}',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white70 : const Color(0xFF38BDF8),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

        const SizedBox(height: 12),

        // Saatlik Kartlar Şeridi (Yağmur Olasılığı & 10m/100m Rüzgar Vurgulu)
        SizedBox(
          height: 158,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final item = list[index];
              final isNow = _selectedDayForHourly == 0 && index == 0;
              final hourStr = isNow
                  ? 'Şimdi'
                  : '${item.time.hour.toString().padLeft(2, '0')}:00';
              final isNight = item.time.hour < 6 || item.time.hour >= 20;
              final hasRain = item.rainProbability >= 20;

              return Container(
                width: 86,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                decoration: BoxDecoration(
                  color: isNow
                      ? const Color(0xFF261238)
                      : (hasRain ? const Color(0xFF0C1F33) : const Color(0xFF101524)),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isNow
                        ? const Color(0xFF8B5CF6)
                        : (hasRain ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : const Color(0xFF1E283D)),
                    width: (isNow || hasRain) ? 1.4 : 1.0,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Saat
                    Text(
                      hourStr,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: isNow ? FontWeight.w800 : FontWeight.w600,
                        color: isNow ? const Color(0xFFA78BFA) : Colors.white70,
                      ),
                    ),

                    // İkon & Sıcaklık
                    Icon(
                      _getWeatherIcon(item.weatherCode, isNight: isNight),
                      color: _getWeatherColor(item.weatherCode, isNight: isNight),
                      size: 22,
                    ),
                    Text(
                      '${item.temperature.round()}°',
                      style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                    ),

                    // Yağmur Olasılığı Rozeti
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: item.rainProbability >= 40
                            ? const Color(0xFF0284C7).withValues(alpha: 0.35)
                            : (item.rainProbability > 0
                                ? const Color(0xFF38BDF8).withValues(alpha: 0.15)
                                : Colors.transparent),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            size: 10,
                            color: item.rainProbability > 0 ? const Color(0xFF38BDF8) : const Color(0xFF64748B),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            '%${item.rainProbability}',
                            style: GoogleFonts.inter(
                              fontSize: 9.5,
                              fontWeight: item.rainProbability >= 40 ? FontWeight.w800 : FontWeight.w600,
                              color: item.rainProbability > 0 ? const Color(0xFF7DD3FC) : const Color(0xFF64748B),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Rüzgar ve 100m Vinç İrtifası
                    Text(
                      '${item.windSpeed100m.round()}k (100m)',
                      style: GoogleFonts.inter(
                        fontSize: 8.5,
                        color: item.windSpeed100m >= 30.0 ? const Color(0xFFEF4444) : const Color(0xFFFBBF24),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // 3. İSDEMİR Rıhtım & Vinç Güvenlik Kokpiti
  Widget _buildPortSafetySection() {
    final data = _weatherData;
    final wind = data?.windSpeed ?? 0.0;
    final wave = data?.waveHeight ?? 0.0;
    final isDanger = wind >= 35.0 || wave >= 1.5;
    final isWarning = !isDanger && (wind >= 20.0 || wave >= 0.8);

    final statusColor = isDanger
        ? const Color(0xFFEF4444)
        : (isWarning ? const Color(0xFFF59E0B) : const Color(0xFF10B981));

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.4), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: statusColor.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.anchor_rounded, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'İSDEMİR Rıhtım & Vinç Emniyeti',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusColor.withValues(alpha: 0.5)),
                ),
                child: Text(
                  isDanger ? 'Fırtına' : (isWarning ? 'Dikkat' : 'Güvenli'),
                  style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w800, color: statusColor),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Text(
            data?.getPortSafetyStatus() ?? 'Veriler analiz ediliyor...',
            style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            isDanger
                ? 'Rüzgar hızı veya dalga boyu kritik eşiğin üstünde. Vinç kaldırma operasyonlarında ve gemi bağlamada yüksek tedbir alınız.'
                : (isWarning
                    ? 'Rüzgar hamleleri 20 km/s üzerinde. Ağır tonajlı vinç operasyonlarında yük salınımına dikkat ediniz.'
                    : 'Rüzgar ve deniz koşulları liman, rıhtım ve vinç operasyonları için standart güvenlik sınırları dahilindedir.'),
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8), height: 1.4),
          ),

          const SizedBox(height: 18),
          const Divider(color: Color(0xFF1E293B), thickness: 1, height: 1),
          const SizedBox(height: 14),

          // Rüzgar Pusulası ve Hamle Detayı
          Row(
            children: [
              // Pusula Kadranı
              SizedBox(
                width: 54,
                height: 54,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF334155), width: 1.5),
                        color: const Color(0xFF080C16),
                      ),
                    ),
                    Transform.rotate(
                      angle: (data?.windDirection ?? 0.0) * (math.pi / 180.0),
                      child: const Icon(Icons.navigation_rounded, color: Color(0xFF38BDF8), size: 28),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rüzgar Yönü: ${data?.getWindCompassDirection() ?? '--'} (${data?.windDirection.round() ?? 0}°)',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ortalama: ${data?.windSpeed ?? 0} km/s • Hamle: ${data?.windGusts ?? 0} km/s',
                      style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF94A3B8)),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── WeatherNext 3 Çift Katmanlı Rüzgar Sensörü (10m vs 100m Vinç) ──
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF080C16),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.height_rounded, color: Color(0xFFA78BFA), size: 16),
                        const SizedBox(width: 6),
                        Text(
                          'WeatherNext 3 Yüksek İrtifa Modeli',
                          style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.bold, color: const Color(0xFFC4B5FD)),
                        ),
                      ],
                    ),
                    Text(
                      '5km Izgara',
                      style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF131929),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Zemin Rüzgarı (10m)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                            const SizedBox(height: 2),
                            Text('${data?.windSpeed ?? 0} km/s', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                            Text('Hamle: ${data?.windGusts ?? 0} km/s', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B))),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF20132B),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Kule & Vinç İrtifası (100m)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFDE68A), fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text('${data?.windSpeed100m ?? 0} km/s', style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w800, color: const Color(0xFFFBBF24))),
                            Text('Hamle: ${data?.windGusts100m ?? 0} km/s', style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFFFDE68A))),
                          ],
                        ),
                      ),
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

  // 4. Liman Verileri Grid (Canlı Deniz Dalgası İle)
  Widget _buildMarineDataGrid() {
    final data = _weatherData;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics_outlined, color: Color(0xFF38BDF8), size: 18),
              const SizedBox(width: 8),
              Text(
                'Liman Operasyon Parametreleri',
                style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 12),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.25,
            children: [
              // Canlı Dalgalanan Deniz Dalgası Kartı
              _buildAnimatedWaveCard(
                title: 'Dalga Boyu',
                value: data != null ? '${data.waveHeight} m' : '--',
                subtitle: data != null && data.waveHeight < 0.5 ? 'Sakin Deniz' : 'Orta Dalgalı',
              ),
              _buildStaticStatCard(
                icon: Icons.compress_rounded,
                title: 'Yüzey Basıncı',
                value: data != null ? '${data.surfacePressure.toStringAsFixed(1)} hPa' : '--',
                subtitle: 'Barometrik Seviye',
                color: const Color(0xFF38BDF8),
              ),
              _buildStaticStatCard(
                icon: Icons.wb_sunny_rounded,
                title: 'Güneş Radyasyonu',
                value: data != null ? '${data.solarRadiation.round()} W/m²' : '--',
                subtitle: 'DeepMind Solar Model',
                color: const Color(0xFFF59E0B),
              ),
              _buildStaticStatCard(
                icon: Icons.air_rounded,
                title: 'Rüzgar Hamlesi',
                value: data != null ? '${data.windGusts} km/s' : '--',
                subtitle: '10m Zemin Esintisi',
                color: const Color(0xFFEF4444),
              ),
              _buildStaticStatCard(
                icon: Icons.visibility_rounded,
                title: 'Görüş Mesafesi',
                value: data != null ? '${(data.visibility / 1000).toStringAsFixed(1)} km' : '--',
                subtitle: 'Rıhtım ve Açık Deniz',
                color: const Color(0xFF60A5FA),
              ),
              _buildStaticStatCard(
                icon: Icons.water_drop_rounded,
                title: 'Bağıl Nem',
                value: data != null ? '%${data.humidity}' : '--',
                subtitle: 'Yoğuşma İndeksi',
                color: const Color(0xFF10B981),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedWaveCard({
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            // Canlı Akışkan Dalga
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 48,
              child: AnimatedBuilder(
                animation: _waveController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: LiveWavePainter(
                      color: const Color(0xFF0284C7),
                      progress: _waveController.value,
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.waves_rounded, color: Color(0xFF38BDF8), size: 18),
                      ),
                      Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
                    ],
                  ),
                  const Spacer(),
                  Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
                  const SizedBox(height: 2),
                  Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticStatCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              Text(subtitle, style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8))),
            ],
          ),
          const Spacer(),
          Text(title, style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8))),
          const SizedBox(height: 2),
          Text(value, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
        ],
      ),
    );
  }

  // 5. Gün Doğumu & Gün Batımı Güneş Yayı (Sun Arc Tracker)
  Widget _buildSunArcSection() {
    final data = _weatherData;
    final sunrise = data?.sunrise;
    final sunset = data?.sunset;

    final sunriseStr = sunrise != null ? '${sunrise.hour.toString().padLeft(2, '0')}:${sunrise.minute.toString().padLeft(2, '0')}' : '06:07';
    final sunsetStr = sunset != null ? '${sunset.hour.toString().padLeft(2, '0')}:${sunset.minute.toString().padLeft(2, '0')}' : '19:01';

    double progress = 0.5;
    if (sunrise != null && sunset != null) {
      final now = DateTime.now();
      if (now.isBefore(sunrise)) {
        progress = 0.0;
      } else if (now.isAfter(sunset)) {
        progress = 1.0;
      } else {
        final totalMinutes = sunset.difference(sunrise).inMinutes;
        final elapsedMinutes = now.difference(sunrise).inMinutes;
        progress = (elapsedMinutes / totalMinutes).clamp(0.0, 1.0);
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_twilight_rounded, color: Color(0xFFF59E0B), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    'Güneş Yayı & Aydınlık Takibi',
                    style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              Text(
                progress >= 1.0 ? 'Gece Vakti' : (progress <= 0.0 ? 'Şafak Vakti' : 'Gün Işığı'),
                style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w600, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),

          const SizedBox(height: 16),

          SizedBox(
            height: 90,
            width: double.infinity,
            child: CustomPaint(
              painter: SunArcPainter(progress: progress),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('GÜN DOĞUMU', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(sunriseStr, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('GÜN BATIMI', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(sunsetStr, style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 6. 7 Günlük Haftalık Tahmin Çubukları (WeatherNext 3 AI Engine)
  Widget _buildWeeklyForecastSection() {
    final list = _weatherData?.dailyForecasts ?? [];
    if (list.isEmpty) return const SizedBox.shrink();

    double lowestMin = 50.0;
    double highestMax = -20.0;
    for (var d in list) {
      if (d.minTemp < lowestMin) lowestMin = d.minTemp;
      if (d.maxTemp > highestMax) highestMax = d.maxTemp;
    }
    final range = (highestMax - lowestMin).clamp(1.0, 100.0);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1524),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.calendar_month_rounded, color: Color(0xFFA78BFA), size: 18),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '7 Günlük Hava Durumu Tahmini',
                        style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Text(
                        'WeatherNext 3 AI • 5km Hassas Izgara',
                        style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFC4B5FD)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'DeepMind AI',
                  style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFA78BFA)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: list.length,
            separatorBuilder: (context, index) => const Divider(color: Color(0xFF1E293B), height: 16),
            itemBuilder: (context, index) {
              final item = list[index];
              final dayName = _getWeekdayName(item.date);
              final isExpanded = _expandedWeeklyDayIndex == index;

              final startRatio = ((item.minTemp - lowestMin) / range).clamp(0.0, 1.0);
              final barRatio = ((item.maxTemp - item.minTemp) / range).clamp(0.1, 1.0);

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (_expandedWeeklyDayIndex == index) {
                      _expandedWeeklyDayIndex = null;
                    } else {
                      _expandedWeeklyDayIndex = index;
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                  decoration: BoxDecoration(
                    color: isExpanded ? const Color(0xFF1B112B) : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isExpanded ? Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)) : null,
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 84,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      dayName,
                                      style: GoogleFonts.inter(
                                        fontSize: 13,
                                        fontWeight: index == 0 ? FontWeight.bold : FontWeight.w600,
                                        color: index == 0 ? const Color(0xFF38BDF8) : Colors.white,
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Icon(
                                      isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                      size: 16,
                                      color: isExpanded ? const Color(0xFFA78BFA) : const Color(0xFF64748B),
                                    ),
                                  ],
                                ),
                                Text(
                                  item.conditionText,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            _getWeatherIcon(item.weatherCode),
                            color: _getWeatherColor(item.weatherCode),
                            size: 22,
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${item.minTemp.round()}°',
                              textAlign: TextAlign.right,
                              style: GoogleFonts.inter(fontSize: 13, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Renkli Termometre Çubuğu
                          Expanded(
                            child: SizedBox(
                              height: 6,
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final totalWidth = constraints.maxWidth;
                                  final startPadding = totalWidth * startRatio;
                                  final barWidth = totalWidth * barRatio;

                                  return Stack(
                                    children: [
                                      Container(
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF1E293B),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                      Positioned(
                                        left: startPadding,
                                        width: barWidth.clamp(12.0, totalWidth),
                                        top: 0,
                                        bottom: 0,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFF38BDF8), Color(0xFFF59E0B), Color(0xFFEF4444)],
                                            ),
                                            borderRadius: BorderRadius.circular(3),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 28,
                            child: Text(
                              '${item.maxTemp.round()}°',
                              style: GoogleFonts.inter(fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      // Günlük WeatherNext 3 Ekstra Telemetrisi (Yağış, 100m Rüzgar, AI Güven)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          if (item.rainProbability > 0) ...[
                            Row(
                              children: [
                                const Icon(Icons.water_drop_rounded, size: 11, color: Color(0xFF38BDF8)),
                                const SizedBox(width: 2),
                                Text('%${item.rainProbability} yağış', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF38BDF8))),
                              ],
                            ),
                            const SizedBox(width: 10),
                          ],
                          Row(
                            children: [
                              const Icon(Icons.height_rounded, size: 11, color: Color(0xFFF59E0B)),
                              const SizedBox(width: 2),
                              Text('${item.windSpeed100mMax.round()} km/s (100m)', style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFFFDE68A))),
                            ],
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5CF6).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '%${item.aiConfidence} Güven',
                              style: GoogleFonts.inter(fontSize: 9, color: const Color(0xFFA78BFA), fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),

                      // ── 🕒 Açılır Saatlik Yağmur & Rüzgar Detay Paneli ──
                      if (isExpanded) ...[
                        const SizedBox(height: 12),
                        _buildInlineHourlyDetailCard(item, index, dayName),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // 🕒 7 Günlük Tabloda Açılan Saatlik Yağmur ve Rüzgar Seyir Kartı
  Widget _buildInlineHourlyDetailCard(DailyForecast dayItem, int dayIndex, String dayName) {
    final hourlyList = dayItem.hourlyForecasts;

    // Zirve yağış ve rüzgar saatlerini analiz et
    HourlyForecast? peakRainHour;
    HourlyForecast? peakWindHour;
    for (var h in hourlyList) {
      if (peakRainHour == null || h.rainProbability > peakRainHour.rainProbability) {
        peakRainHour = h;
      }
      if (peakWindHour == null || h.windSpeed100m > peakWindHour.windSpeed100m) {
        peakWindHour = h;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080C16),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.access_time_filled_rounded, color: Color(0xFF38BDF8), size: 14),
                  const SizedBox(width: 6),
                  Text(
                    '$dayName Günü 24 Saatlik Dağılım',
                    style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ],
              ),
              InkWell(
                onTap: () {
                  setState(() => _selectedDayForHourly = dayIndex);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_upward_rounded, size: 10, color: Color(0xFFA78BFA)),
                      const SizedBox(width: 2),
                      Text(
                        'Şeritte İncele',
                        style: GoogleFonts.inter(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFFA78BFA)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Özet Bilgi Şeridi
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131929),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.water_drop_rounded, size: 13, color: Color(0xFF38BDF8)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          (peakRainHour != null && peakRainHour.rainProbability > 0)
                              ? 'Zirve Yağış: ${peakRainHour.time.hour.toString().padLeft(2, '0')}:00 (%${peakRainHour.rainProbability})'
                              : 'Gün boyu yağış beklenmiyor (%0)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF93C5FD), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF261818),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.air_rounded, size: 13, color: Color(0xFFFBBF24)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          peakWindHour != null
                              ? 'Zirve Vinç: ${peakWindHour.time.hour.toString().padLeft(2, '0')}:00 (${peakWindHour.windSpeed100m.round()} km/s)'
                              : 'Sakin Rüzgar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFFFDE68A), fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // 24 Saatlik Yatay Kartlar
          if (hourlyList.isNotEmpty)
            SizedBox(
              height: 120,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: hourlyList.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final h = hourlyList[index];
                  final isRainy = h.rainProbability >= 25;
                  final hourStr = '${h.time.hour.toString().padLeft(2, '0')}:00';
                  final isNight = h.time.hour < 6 || h.time.hour >= 20;

                  return Container(
                    width: 68,
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    decoration: BoxDecoration(
                      color: isRainy ? const Color(0xFF0C243B) : const Color(0xFF131929),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isRainy ? const Color(0xFF0284C7) : const Color(0xFF242F46),
                        width: isRainy ? 1.2 : 0.8,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          hourStr,
                          style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white70),
                        ),
                        Icon(
                          _getWeatherIcon(h.weatherCode, isNight: isNight),
                          size: 16,
                          color: _getWeatherColor(h.weatherCode, isNight: isNight),
                        ),
                        Text(
                          '${h.temperature.round()}°',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        // Yağmur
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.water_drop_rounded,
                              size: 9,
                              color: h.rainProbability > 0 ? const Color(0xFF38BDF8) : const Color(0xFF475569),
                            ),
                            Text(
                              '%${h.rainProbability}',
                              style: GoogleFonts.inter(
                                fontSize: 9,
                                fontWeight: isRainy ? FontWeight.bold : FontWeight.normal,
                                color: h.rainProbability > 0 ? const Color(0xFF7DD3FC) : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        // Rüzgar 100m vinç
                        Text(
                          '${h.windSpeed100m.round()}k (100m)',
                          style: GoogleFonts.inter(fontSize: 7.5, color: const Color(0xFFFBBF24), fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                'Bu gün için saatlik tahmin verisi hazırlanıyor...',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF64748B)),
              ),
            ),
        ],
      ),
    );
  }
}

// 🌊 Canlı 60 FPS Dalgalanan Akışkan Deniz Çizicisi
class LiveWavePainter extends CustomPainter {
  final Color color;
  final double progress;

  LiveWavePainter({required this.color, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final shift = progress * 2 * math.pi;

    // 1. Arka Dalga (Yarı saydam)
    final backPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final backPath = Path();
    backPath.moveTo(0, size.height);
    for (double x = 0; x <= size.width; x += 3) {
      final y = size.height * 0.55 + 5 * math.sin((x / size.width) * 3 * math.pi + shift);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(size.width, size.height);
    backPath.lineTo(0, size.height);
    backPath.close();
    canvas.drawPath(backPath, backPaint);

    // 2. Ön Dalga (Canlı tepe çizgisi)
    final frontPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.05)],
      ).createShader(Rect.fromLTRB(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final frontPath = Path();
    final fillPath = Path();
    fillPath.moveTo(0, size.height);

    for (double x = 0; x <= size.width; x += 3) {
      final y = size.height * 0.45 + 7 * math.sin((x / size.width) * 4 * math.pi - shift);
      if (x == 0) {
        frontPath.moveTo(x, y);
      } else {
        frontPath.lineTo(x, y);
      }
      fillPath.lineTo(x, y);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.lineTo(0, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant LiveWavePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

// 🌅 Kavisli Güneş Yayı Çizicisi (Sun Arc Painter)
class SunArcPainter extends CustomPainter {
  final double progress;

  SunArcPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final arcPaint = Paint()
      ..color = const Color(0xFF28354D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final rect = Rect.fromLTWH(20, 10, size.width - 40, (size.height - 20) * 2);
    // Yarım daire yay (pi to 2*pi)
    canvas.drawArc(rect, math.pi, math.pi, false, arcPaint);

    // Güneş pozisyonu
    final currentAngle = math.pi + (progress * math.pi);
    final radiusX = (size.width - 40) / 2;
    final radiusY = (size.height - 20);
    final centerX = size.width / 2;
    final centerY = size.height - 10;

    final sunX = centerX + radiusX * math.cos(currentAngle);
    final sunY = centerY + radiusY * math.sin(currentAngle);

    // Güneş Işıltısı
    final glowPaint = Paint()
      ..color = const Color(0xFFFBBF24).withValues(alpha: 0.35)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawCircle(Offset(sunX, sunY), 12, glowPaint);

    // Güneş Çekirdeği
    final sunPaint = Paint()..color = const Color(0xFFFBBF24);
    canvas.drawCircle(Offset(sunX, sunY), 6, sunPaint);
  }

  @override
  bool shouldRepaint(covariant SunArcPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
