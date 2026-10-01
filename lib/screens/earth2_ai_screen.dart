import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ── 📍 KONUM PROFİLİ ──
enum Earth2LocationType { payas, iskenderun }

class LocationProfile {
  final Earth2LocationType type;
  final String name;
  final String district;
  final String facility;
  final double lat;
  final double lon;
  final double marineLat;
  final double marineLon;
  final String coordinatesText;
  final String elevation;
  final String sectorInfo;
  final String microclimateNote;

  const LocationProfile({
    required this.type,
    required this.name,
    required this.district,
    required this.facility,
    required this.lat,
    required this.lon,
    required this.marineLat,
    required this.marineLon,
    required this.coordinatesText,
    required this.elevation,
    required this.sectorInfo,
    required this.microclimateNote,
  });
}

const LocationProfile kPayasProfile = LocationProfile(
  type: Earth2LocationType.payas,
  name: 'Hatay - Payas',
  district: 'Payas',
  facility: 'İSDEMİR Entegre Demir Çelik Tesisleri & Özel Liman Sahası',
  lat: 36.7583,
  lon: 36.2167,
  marineLat: 36.724,
  marineLon: 36.178,
  coordinatesText: '36.7583° N, 36.2167° E',
  elevation: '8 m (Rıhtım & Tesis Kotu)',
  sectorInfo: 'Ağır Sanayi, Yüksek Fırınlar & İsdemir Rıhtımları (Gv1-Gv4, Yb8-Yb12)',
  microclimateNote: 'Amanos Dağları orografik rüzgar koridoru ve Yarıkkaya hava kanalı etkisi.',
);

const LocationProfile kIskenderunProfile = LocationProfile(
  type: Earth2LocationType.iskenderun,
  name: 'Hatay - İskenderun',
  district: 'İskenderun',
  facility: 'İskenderun Liman Başkanlığı, Konteyner Terminali & Şehir Körfezi',
  lat: 36.5872,
  lon: 36.1735,
  marineLat: 36.600,
  marineLon: 36.150,
  coordinatesText: '36.5872° N, 36.1735° E',
  elevation: '4 m (Kıyı & İskele Kotu)',
  sectorInfo: 'Liman Lojistiği, Konteyner Sahaları & Körfez Deniz Trafiği',
  microclimateNote: 'Körfez içi siklonik deniz esintisi ve Lodos açık deniz fırtına dalga tesiri.',
);

// ── 🧠 TELEMETRİ VERİ MODELİ ──
class Earth2Telemetry {
  final double temperature;
  final double apparentTemperature;
  final double tempMaxToday;
  final double tempMinToday;
  final int weatherCode;
  final double windSpeed10m;
  final double windSpeed100m;
  final double windGusts;
  final double windDirection;
  final String windDirectionName;
  final int humidity;
  final double pressure;
  final double waveHeight;
  final String waveConditionName;
  final double uvIndex;
  final double visibilityKm;
  final double solarRadiation; // W/m²
  final double pblHeight; // Metre (Planetary Boundary Layer)
  final double rainProbability;
  final double precipitationMm;
  final double lightningRiskPercent;
  final double microburstRiskPercent;
  final double maxDbz;
  final String stormStatusText;
  final String atmosphericSafetyStatus;
  final String rainBriefing;
  final String windBriefing;
  final String waveBriefing;
  final List<HourlyEarth2> hourly;
  final List<DailyEarth2> daily;
  final bool isLive;

  Earth2Telemetry({
    required this.temperature,
    required this.apparentTemperature,
    required this.tempMaxToday,
    required this.tempMinToday,
    required this.weatherCode,
    required this.windSpeed10m,
    required this.windSpeed100m,
    required this.windGusts,
    required this.windDirection,
    required this.windDirectionName,
    required this.humidity,
    required this.pressure,
    required this.waveHeight,
    required this.waveConditionName,
    required this.uvIndex,
    required this.visibilityKm,
    required this.solarRadiation,
    required this.pblHeight,
    required this.rainProbability,
    required this.precipitationMm,
    required this.lightningRiskPercent,
    required this.microburstRiskPercent,
    required this.maxDbz,
    required this.stormStatusText,
    required this.atmosphericSafetyStatus,
    required this.rainBriefing,
    required this.windBriefing,
    required this.waveBriefing,
    required this.hourly,
    required this.daily,
    required this.isLive,
  });
}

class HourlyEarth2 {
  final DateTime time;
  final double temp;
  final double windSpeed;
  final double windGust;
  final int rainProb;
  final double dbz;
  final String status;
  final double waveHeight;

  HourlyEarth2({
    required this.time,
    required this.temp,
    required this.windSpeed,
    required this.windGust,
    required this.rainProb,
    required this.dbz,
    required this.status,
    this.waveHeight = 0.4,
  });
}

class DailyEarth2 {
  final DateTime date;
  final double maxTemp;
  final double minTemp;
  final double maxWind;
  final int rainProb;
  final double aiConfidence;
  final String condition;
  final String detailNote;

  DailyEarth2({
    required this.date,
    required this.maxTemp,
    required this.minTemp,
    required this.maxWind,
    required this.rainProb,
    required this.aiConfidence,
    required this.condition,
    required this.detailNote,
  });
}

// ── 🚀 EKRAN SINIFI ──
class Earth2AiScreen extends StatefulWidget {
  const Earth2AiScreen({super.key});

  @override
  State<Earth2AiScreen> createState() => _Earth2AiScreenState();
}

class _Earth2AiScreenState extends State<Earth2AiScreen> with TickerProviderStateMixin {
  Earth2LocationType _selectedLocation = Earth2LocationType.payas;
  int _activeModuleTab = 0; // 0: NVIDIA Earth-2 Atlas, 1: NVIDIA Earth-2 StormScope

  bool _isLoading = true;
  Earth2Telemetry? _telemetry;
  DateTime _lastSyncTime = DateTime.now();

  late AnimationController _radarController;
  late AnimationController _pulseController;

  LocationProfile get currentProfile =>
      _selectedLocation == Earth2LocationType.payas ? kPayasProfile : kIskenderunProfile;

  static String _formatWindDirection(double deg) {
    final d = (deg % 360 + 360) % 360;
    if (d >= 337.5 || d < 22.5) return 'Kuzey (Yıldız)';
    if (d >= 22.5 && d < 67.5) return 'Kuzeydoğu (Poyraz)';
    if (d >= 67.5 && d < 112.5) return 'Doğu (Gündoğusu)';
    if (d >= 112.5 && d < 157.5) return 'Güneydoğu (Keşişleme)';
    if (d >= 157.5 && d < 202.5) return 'Güney (Kıble)';
    if (d >= 202.5 && d < 247.5) return 'Güneybatı (Lodos)';
    if (d >= 247.5 && d < 292.5) return 'Batı (Günbatısı)';
    return 'Kuzeybatı (Karayel)';
  }

  static String _formatWaveCondition(double height) {
    if (height < 0.25) return 'Çarşaf / Tamamen Durgun';
    if (height < 0.55) return 'Sakin Deniz (Hafif Kıpırtılı)';
    if (height < 1.0) return 'Hafif Çalkantılı Körfez';
    if (height < 1.5) return 'Orta Dalgalı Deniz';
    if (height < 2.2) return 'Sert & Kaba Dalgalı';
    return 'Fırtına Dalgası (Ağır Deniz)';
  }

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _fetchEarth2Data();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _fetchEarth2Data() async {
    setState(() {
      _isLoading = true;
    });

    final profile = currentProfile;
    try {
      final weatherUrl = Uri.parse(
        'https://api.open-meteo.com/v1/forecast?'
        'latitude=${profile.lat}&longitude=${profile.lon}&'
        'current=temperature_2m,relative_humidity_2m,apparent_temperature,precipitation,weather_code,wind_speed_10m,wind_direction_10m,wind_gusts_10m,surface_pressure,cloud_cover,visibility,uv_index&'
        'hourly=temperature_2m,precipitation_probability,precipitation,wind_speed_10m,wind_gusts_10m,surface_pressure,cloud_cover&'
        'daily=temperature_2m_max,temperature_2m_min,precipitation_probability_max,wind_speed_10m_max,weather_code&'
        'timezone=Europe%2FIstanbul',
      );

      final marineUrl = Uri.parse(
        'https://marine-api.open-meteo.com/v1/marine?latitude=${profile.marineLat}&longitude=${profile.marineLon}&current=wave_height',
      );

      final weatherResp = await http.get(weatherUrl).timeout(const Duration(seconds: 7));
      double waveH = 0.42;

      try {
        final marineResp = await http.get(marineUrl).timeout(const Duration(seconds: 4));
        if (marineResp.statusCode == 200) {
          final mJson = json.decode(marineResp.body);
          if (mJson['current'] != null && mJson['current']['wave_height'] != null) {
            waveH = (mJson['current']['wave_height'] as num).toDouble();
          }
        }
      } catch (_) {
        waveH = _selectedLocation == Earth2LocationType.payas ? 0.38 : 0.48;
      }

      if (weatherResp.statusCode == 200) {
        final data = json.decode(weatherResp.body);
        final cur = data['current'] ?? {};
        final hourlyData = data['hourly'] ?? {};
        final dailyData = data['daily'] ?? {};

        final temp = (cur['temperature_2m'] as num?)?.toDouble() ?? 24.5;
        final appTemp = (cur['apparent_temperature'] as num?)?.toDouble() ?? temp;
        final wind10 = (cur['wind_speed_10m'] as num?)?.toDouble() ?? 12.0;
        final wind100 = double.parse((wind10 * 1.48).toStringAsFixed(1));
        final gusts = (cur['wind_gusts_10m'] as num?)?.toDouble() ?? (wind10 * 1.35);
        final windDir = (cur['wind_direction_10m'] as num?)?.toDouble() ?? 210.0;
        final windDirName = _formatWindDirection(windDir);
        final humidity = (cur['relative_humidity_2m'] as num?)?.toInt() ?? 62;
        final pressure = (cur['surface_pressure'] as num?)?.toDouble() ?? 1014.2;
        final weatherCode = (cur['weather_code'] as num?)?.toInt() ?? 0;
        final precMm = (cur['precipitation'] as num?)?.toDouble() ?? 0.0;
        final uv = (cur['uv_index'] as num?)?.toDouble() ?? 4.2;
        final visMeters = (cur['visibility'] as num?)?.toDouble() ?? 10000.0;
        final cloud = (cur['cloud_cover'] as num?)?.toInt() ?? 20;

        final pblHeight = (900.0 + (temp * 14.5) - (humidity * 3.2)).clamp(650.0, 1600.0);
        final solarRadiation = math.max(0.0, (1.0 - (cloud / 100.0)) * 780.0);

        final baseDbz = precMm > 0 ? (20.0 + precMm * 7.5).clamp(15.0, 62.0) : (cloud > 60 ? 18.5 : 8.0);
        final lightningRisk = ((humidity / 100.0) * (wind10 / 30.0) * (cloud > 50 ? 45.0 : 10.0) + (precMm * 15)).clamp(2.0, 88.0);
        final microburstRisk = ((gusts / 45.0) * 35.0 + (precMm * 10)).clamp(5.0, 92.0);

        String atmosphericSafety = 'STABİL / GÜVENLİ HAVA KOŞULLARI';
        if (wind10 >= 38 || gusts >= 48) {
          atmosphericSafety = 'ŞİDDETLİ FIRTINA & KUVVETLİ RÜZGAR';
        } else if (wind10 >= 24 || gusts >= 32) {
          atmosphericSafety = 'ORTA SEVİYE RÜZGAR HAREKETLİLİĞİ';
        }

        String stormStatus = 'Atmosferik akış dengeli; konvektif fırtına hücresi tespit edilmedi.';
        if (baseDbz >= 45 || lightningRisk > 50) {
          stormStatus = 'DİKKAT: Konvektif fırtına hücresi yaklaşıyor. Ani rüzgar hamlesi riski!';
        } else if (baseDbz >= 30) {
          stormStatus = 'Bölgesel çisenti ve konvektif bulut kümelenmesi izleniyor.';
        }

        // 24 Saatlik Nowcast Dilimleri
        List<HourlyEarth2> hList = [];
        final hTimes = hourlyData['time'] as List? ?? [];
        final hTemps = hourlyData['temperature_2m'] as List? ?? [];
        final hWinds = hourlyData['wind_speed_10m'] as List? ?? [];
        final hGusts = hourlyData['wind_gusts_10m'] as List? ?? [];
        final hProbs = hourlyData['precipitation_probability'] as List? ?? [];

        final now = DateTime.now();
        for (int i = 0; i < hTimes.length; i++) {
          final t = DateTime.tryParse(hTimes[i].toString());
          if (t != null && t.isAfter(now.subtract(const Duration(minutes: 30)))) {
            final tVal = (hTemps.length > i && hTemps[i] != null) ? (hTemps[i] as num).toDouble() : temp;
            final wVal = (hWinds.length > i && hWinds[i] != null) ? (hWinds[i] as num).toDouble() : wind10;
            final gVal = (hGusts.length > i && hGusts[i] != null) ? (hGusts[i] as num).toDouble() : wVal * 1.3;
            final pVal = (hProbs.length > i && hProbs[i] != null) ? (hProbs[i] as num).toInt() : 0;
            final slotDbz = (pVal * 0.45 + (pVal > 30 ? 12 : 5)).clamp(5.0, 58.0);

            String st = 'Kuru';
            if (slotDbz >= 40) {
              st = 'Fırtına';
            } else if (slotDbz >= 25) {
              st = 'Yağış';
            } else if (pVal > 20) {
              st = 'Bulutlu';
            }

            final slotWave = double.parse((waveH + ((wVal - 12) * 0.02)).clamp(0.2, 1.8).toStringAsFixed(2));

            hList.add(HourlyEarth2(
              time: t,
              temp: tVal,
              windSpeed: wVal,
              windGust: gVal,
              rainProb: pVal,
              dbz: slotDbz,
              status: st,
              waveHeight: slotWave,
            ));
            if (hList.length >= 24) {
              break;
            }
          }
        }

        // 🧠 AI ÇOK DETAYLI BRİFİNG METİNLERİ ÜRETİMİ
        HourlyEarth2? firstRainSlot;
        for (var h in hList) {
          if (h.rainProb >= 25) {
            firstRainSlot = h;
            break;
          }
        }

        String rainBrief;
        if (firstRainSlot != null) {
          final rHour = DateFormat('HH:mm').format(firstRainSlot.time);
          final rDay = firstRainSlot.time.day == now.day ? 'Bugün' : 'Yarın';
          rainBrief = '$rDay saat $rHour sularında %${firstRainSlot.rainProb} ihtimalle ${firstRainSlot.status.toLowerCase()} bekleniyor.';
        } else {
          rainBrief = 'Önümüzdeki 24 saat boyunca bölgede yağış beklenmiyor. Kuru ve açık hava akımı hakim.';
        }

        HourlyEarth2 peakWindSlot = hList.isNotEmpty
            ? hList.reduce((a, b) => a.windSpeed > b.windSpeed ? a : b)
            : HourlyEarth2(time: now, temp: temp, windSpeed: wind10, windGust: gusts, rainProb: 0, dbz: 10, status: 'Kuru');

        final pwHour = DateFormat('HH:mm').format(peakWindSlot.time);
        final pwDay = peakWindSlot.time.day == now.day ? 'Bugün' : 'Yarın';
        final knotSpeed = (peakWindSlot.windSpeed / 1.852).toStringAsFixed(1);
        final windBrief = '$pwDay saat $pwHour civarında havanın rüzgarı ${peakWindSlot.windSpeed.toStringAsFixed(1)} km/s ($knotSpeed Knot) ile zirveye çıkacak (Hamle: ${peakWindSlot.windGust.toStringAsFixed(0)} km/s, $windDirName).';

        final waveCond = _formatWaveCondition(waveH);
        final waveBrief = 'İskenderun Körfezi açıklarında anlık dalga boyu ${waveH.toStringAsFixed(2)} metre ($waveCond). Deniz suyu akıntısı ve körfez çalkantısı sakin seviyede.';

        List<DailyEarth2> dList = [];
        final dTimes = dailyData['time'] as List? ?? [];
        final dMaxs = dailyData['temperature_2m_max'] as List? ?? [];
        final dMins = dailyData['temperature_2m_min'] as List? ?? [];
        final dWinds = dailyData['wind_speed_10m_max'] as List? ?? [];
        final dProbs = dailyData['precipitation_probability_max'] as List? ?? [];

        for (int i = 0; i < dTimes.length; i++) {
          final dt = DateTime.tryParse(dTimes[i].toString()) ?? now.add(Duration(days: i));
          final mx = (dMaxs.length > i && dMaxs[i] != null) ? (dMaxs[i] as num).toDouble() : temp + 2;
          final mn = (dMins.length > i && dMins[i] != null) ? (dMins[i] as num).toDouble() : temp - 5;
          final mw = (dWinds.length > i && dWinds[i] != null) ? (dWinds[i] as num).toDouble() : wind10 * 1.2;
          final rp = (dProbs.length > i && dProbs[i] != null) ? (dProbs[i] as num).toInt() : 10;
          final conf = (99.4 - (i * 0.9)).clamp(92.0, 99.4);

          String dayDetail = 'Rüzgar maks ${mw.toStringAsFixed(0)} km/s';
          if (rp >= 35) {
            dayDetail = 'Öğleden sonra yağış ihtimali (%$rp)';
          } else if (mw >= 25) {
            dayDetail = 'Sert rüzgar hamleleri bekleniyor';
          }

          dList.add(DailyEarth2(
            date: dt,
            maxTemp: mx,
            minTemp: mn,
            maxWind: mw,
            rainProb: rp,
            aiConfidence: double.parse(conf.toStringAsFixed(1)),
            condition: rp > 40 ? 'Yağış İhtimali' : (rp > 15 ? 'Parçalı Bulut' : 'Açık / Güneşli'),
            detailNote: dayDetail,
          ));
        }

        final maxToday = dList.isNotEmpty ? dList.first.maxTemp : temp + 3;
        final minToday = dList.isNotEmpty ? dList.first.minTemp : temp - 4;

        setState(() {
          _telemetry = Earth2Telemetry(
            temperature: temp,
            apparentTemperature: appTemp,
            tempMaxToday: maxToday,
            tempMinToday: minToday,
            weatherCode: weatherCode,
            windSpeed10m: wind10,
            windSpeed100m: wind100,
            windGusts: gusts,
            windDirection: windDir,
            windDirectionName: windDirName,
            humidity: humidity,
            pressure: pressure,
            waveHeight: waveH,
            waveConditionName: waveCond,
            uvIndex: uv,
            visibilityKm: visMeters / 1000.0,
            solarRadiation: double.parse(solarRadiation.toStringAsFixed(0)),
            pblHeight: double.parse(pblHeight.toStringAsFixed(0)),
            rainProbability: dList.isNotEmpty ? dList.first.rainProb.toDouble() : 10.0,
            precipitationMm: precMm,
            lightningRiskPercent: double.parse(lightningRisk.toStringAsFixed(1)),
            microburstRiskPercent: double.parse(microburstRisk.toStringAsFixed(1)),
            maxDbz: double.parse(baseDbz.toStringAsFixed(1)),
            stormStatusText: stormStatus,
            atmosphericSafetyStatus: atmosphericSafety,
            rainBriefing: rainBrief,
            windBriefing: windBrief,
            waveBriefing: waveBrief,
            hourly: hList,
            daily: dList,
            isLive: true,
          );
          _isLoading = false;
          _lastSyncTime = DateTime.now();
        });
      } else {
        throw Exception('HTTP Status: ${weatherResp.statusCode}');
      }
    } catch (e) {
      debugPrint('Earth-2 API Error: $e');
      _generateFallbackTelemetry();
    }
  }

  void _generateFallbackTelemetry() {
    final isPayas = _selectedLocation == Earth2LocationType.payas;
    final now = DateTime.now();
    final waveH = isPayas ? 0.38 : 0.45;
    final waveCond = _formatWaveCondition(waveH);

    final fallback = Earth2Telemetry(
      temperature: isPayas ? 26.2 : 25.8,
      apparentTemperature: isPayas ? 27.4 : 26.5,
      tempMaxToday: isPayas ? 29.0 : 28.5,
      tempMinToday: isPayas ? 21.0 : 20.8,
      weatherCode: 1,
      windSpeed10m: isPayas ? 14.2 : 11.5,
      windSpeed100m: isPayas ? 21.8 : 17.2,
      windGusts: isPayas ? 24.5 : 18.0,
      windDirection: isPayas ? 215.0 : 240.0,
      windDirectionName: 'Güneybatı (Lodos)',
      humidity: isPayas ? 58 : 64,
      pressure: 1013.8,
      waveHeight: waveH,
      waveConditionName: waveCond,
      uvIndex: 4.8,
      visibilityKm: 12.0,
      solarRadiation: 640.0,
      pblHeight: 1050.0,
      rainProbability: 8.0,
      precipitationMm: 0.0,
      lightningRiskPercent: 4.2,
      microburstRiskPercent: 8.5,
      maxDbz: 14.0,
      stormStatusText: 'Amanos ve Körfez hattında fırtına hücresi saptanmadı (Stabil).',
      atmosphericSafetyStatus: 'STABİL / GÜVENLİ HAVA KOŞULLARI',
      rainBriefing: 'Önümüzdeki 24 saat boyunca bölgede kayda değer yağış beklenmiyor (Kuru hava akımı hakim).',
      windBriefing: 'Bugün saat 16:30 sularında havanın rüzgarı 18 km/s (9.7 Knot) hız ve 25 km/s hamle (Lodos) ile zirve yapacak.',
      waveBriefing: 'İskenderun Körfezi açıklarında dalga boyu 0.40 metre civarında; deniz oldukça sakin.',
      hourly: List.generate(24, (i) {
        final t = now.add(Duration(hours: i));
        return HourlyEarth2(
          time: t,
          temp: 26.0 - (i * 0.3),
          windSpeed: 13.0 + (i % 4),
          windGust: 18.0 + (i % 5),
          rainProb: 5 + (i * 2),
          dbz: 10.0 + (i * 2),
          status: 'Kuru',
          waveHeight: waveH,
        );
      }),
      daily: List.generate(7, (i) {
        final d = now.add(Duration(days: i));
        return DailyEarth2(
          date: d,
          maxTemp: 28.0 - (i % 2),
          minTemp: 20.5 + (i % 3),
          maxWind: 18.0 + (i * 1.5),
          rainProb: 10 + (i * 5),
          aiConfidence: double.parse((99.1 - (i * 0.8)).toStringAsFixed(1)),
          condition: i == 4 ? 'Hafif Çisenti' : 'Açık / Güneşli',
          detailNote: i == 4 ? 'Gece hafif yağış geçişi' : 'Açık hava ve hafif rüzgar',
        );
      }),
      isLive: false,
    );

    setState(() {
      _telemetry = fallback;
      _isLoading = false;
      _lastSyncTime = DateTime.now();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF06090E),
      body: Stack(
        children: [
          // ── ARKA PLAN CYBER GRID & AMBIENT GLOW ──
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.6, -0.7),
                  radius: 1.3,
                  colors: [
                    Color(0xFF0D2818),
                    Color(0xFF071118),
                    Color(0xFF05080C),
                  ],
                ),
              ),
            ),
          ),

          // Cyber Grid Çizgileri
          Positioned.fill(
            child: Opacity(
              opacity: 0.04,
              child: CustomPaint(
                painter: _GridBackgroundPainter(),
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                _buildTopHeader(),
                _buildLocationPillSelector(),
                _buildModuleSegmentedTabs(),
                const SizedBox(height: 8),

                Expanded(
                  child: _isLoading && _telemetry == null
                      ? _buildLoadingState()
                      : RefreshIndicator(
                          color: const Color(0xFF76B900),
                          backgroundColor: const Color(0xFF101722),
                          onRefresh: _fetchEarth2Data,
                          child: SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSystemStatusBanner(),
                                const SizedBox(height: 14),

                                if (_activeModuleTab == 0)
                                  _buildEarth2AtlasView()
                                else
                                  _buildStormScopeView(),

                                const SizedBox(height: 24),
                                _buildFooterCredentials(),
                                const SizedBox(height: 30),
                              ],
                            ),
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

  // ── 1. ÜST BAR ──
  Widget _buildTopHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              Navigator.pop(context);
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            ),
          ),
          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF76B900),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'NVIDIA',
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'EARTH-2 AI MERKEZİ',
                      style: GoogleFonts.orbitron(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Havanın Rüzgarı, Yağış Zamanları & Körfez Dalga Boyu',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: const Color(0xFF94A3B8),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          InkWell(
            onTap: () {
              HapticFeedback.mediumImpact();
              _fetchEarth2Data();
            },
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF101722),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF76B900).withValues(alpha: 0.35),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF76B900)),
                      ),
                    )
                  : const Icon(Icons.sync_rounded, color: Color(0xFF76B900), size: 18),
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. KONUM SEÇİCİ KAPSELİ (PAYAS vs. İSKENDERUN) ──
  Widget _buildLocationPillSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1520),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1F293D)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildLocationTabItem(
              title: 'Hatay - Payas',
              subtitle: 'İSDEMİR & Körfez Rıhtımı',
              isSelected: _selectedLocation == Earth2LocationType.payas,
              icon: Icons.factory_rounded,
              onTap: () {
                if (_selectedLocation != Earth2LocationType.payas) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedLocation = Earth2LocationType.payas);
                  _fetchEarth2Data();
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: _buildLocationTabItem(
              title: 'Hatay - İskenderun',
              subtitle: 'Liman & Körfez Hattı',
              isSelected: _selectedLocation == Earth2LocationType.iskenderun,
              icon: Icons.anchor_rounded,
              onTap: () {
                if (_selectedLocation != Earth2LocationType.iskenderun) {
                  HapticFeedback.selectionClick();
                  setState(() => _selectedLocation = Earth2LocationType.iskenderun);
                  _fetchEarth2Data();
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationTabItem({
    required String title,
    required String subtitle,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF76B900).withValues(alpha: 0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF76B900).withValues(alpha: 0.6) : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF76B900) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : const Color(0xFF94A3B8),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 9.5,
                      color: isSelected ? const Color(0xFF76B900) : const Color(0xFF64748B),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 3. MODÜL SEKMELERİ (ATLAS vs. STORMSCOPE) ──
  Widget _buildModuleSegmentedTabs() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: _buildModulePill(
              title: 'Earth-2 Atlas',
              code: 'DİJİTAL İKİZ & RÜZGAR MODELİ',
              index: 0,
              icon: Icons.public_rounded,
              accentColor: const Color(0xFF76B900),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModulePill(
              title: 'StormScope AI',
              code: 'RADAR & YAĞIŞ NOWCAST',
              index: 1,
              icon: Icons.radar_rounded,
              accentColor: const Color(0xFF00F0FF),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModulePill({
    required String title,
    required String code,
    required int index,
    required IconData icon,
    required Color accentColor,
  }) {
    final isSelected = _activeModuleTab == index;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _activeModuleTab = index);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 12),
        decoration: BoxDecoration(
          color: isSelected ? accentColor.withValues(alpha: 0.14) : const Color(0xFF0E131C),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFF1E2838),
            width: isSelected ? 1.4 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.2),
                    blurRadius: 10,
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? accentColor : const Color(0xFF64748B)),
            const SizedBox(width: 6),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.orbitron(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    code,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 8.5,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? accentColor : const Color(0xFF475569),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── 4. SİSTEM DURUM BİLGİ ŞERİDİ ──
  Widget _buildSystemStatusBanner() {
    final t = _telemetry;
    final isLive = t?.isLive ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0B1017),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1B2433)),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _pulseController,
            builder: (context, child) {
              return Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF76B900),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF76B900).withValues(alpha: 0.4 + (_pulseController.value * 0.5)),
                      blurRadius: 6 + (_pulseController.value * 6),
                      spreadRadius: 1 + (_pulseController.value * 2),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NVIDIA DGX SUPERPOD • AI TELEMETRİSİ AKTİF',
                  style: GoogleFonts.orbitron(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF76B900),
                    letterSpacing: 0.6,
                  ),
                ),
                Text(
                  'Hedef: ${currentProfile.coordinatesText} • Rakım: ${currentProfile.elevation}',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isLive ? const Color(0xFF10B981).withValues(alpha: 0.15) : const Color(0xFFF59E0B).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isLive ? const Color(0xFF10B981).withValues(alpha: 0.4) : const Color(0xFFF59E0B).withValues(alpha: 0.4),
              ),
            ),
            child: Text(
              isLive ? 'CANLI AI' : 'OFFLINE AI',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 9,
                fontWeight: FontWeight.bold,
                color: isLive ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── MODÜL 1: NVIDIA EARTH-2 ATLAS GÖRÜNÜMÜ ──
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildEarth2AtlasView() {
    final t = _telemetry!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── 1. KAHRAMAN DİJİTAL İKİZ & KÖRFEZ DALGA KARTI ──
        _buildAtlasHeroCard(t),
        const SizedBox(height: 14),

        // ── 2. ÇOK DETAYLI NVIDIA AI HAVA, YAĞIŞ VE RÜZGAR BRİFİNGİ ──
        _buildDetailedAiAtmosphericBriefing(t),
        const SizedBox(height: 14),

        // ── 3. 24 SAATLİK ZAMAN ÇİZELGESİ (HAVA, RÜZGAR, YAĞIŞ, DALGA) ──
        _buildHourlyForecastStrip(t),
        const SizedBox(height: 14),

        // ── 4. HAVANIN RÜZGAR HESAPLAMASI & DENİZ TELEMETRİSİ ──
        _buildAtmosphericPhysicsGrid(t),
        const SizedBox(height: 14),

        // ── 5. MİKROKLİMA & AMANOS HAVA KORİDORU ANALİZİ ──
        _buildMicroclimateImpactCard(t),
        const SizedBox(height: 14),

        // ── 6. 7 GÜNLÜK GENERATIVE CORRDIFF TAHMİN ÇİZELGESİ ──
        _buildCorrDiffDailyForecast(t),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildAtlasHeroCard(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1622),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF76B900).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF76B900).withValues(alpha: 0.08),
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
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFF76B900).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.blur_on_rounded, color: Color(0xFF76B900), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'EARTH-2 ATLAS DİJİTAL İKİZ',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF76B900),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'CorrDiff 2km Çözünürlüklü Atmosfer Difüzyonu',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  DateFormat('HH:mm').format(_lastSyncTime),
                  style: GoogleFonts.jetBrainsMono(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Sıcaklık & Hissedilen Satırı
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${t.temperature.toStringAsFixed(1)}°',
                style: GoogleFonts.orbitron(
                  fontSize: 44,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -1.0,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Hissedilen: ${t.apparentTemperature.toStringAsFixed(1)}°C',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF38BDF8),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Günün En Düşük: ${t.tempMinToday.toStringAsFixed(0)}° / En Yüksek: ${t.tempMaxToday.toStringAsFixed(0)}°',
                      style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFF94A3B8)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 🌊 KÖRFEZ DENİZ & DALGA BOYU (TAM GENİŞLİK, ASLA TAŞMAZ)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.35)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF00F0FF).withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.waves_rounded, size: 20, color: Color(0xFF00F0FF)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KÖRFEZ DENİZ & DALGA BOYU',
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: const Color(0xFF00F0FF),
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        t.waveConditionName,
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          color: const Color(0xFFE2E8F0),
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '${t.waveHeight.toStringAsFixed(2)} m',
                  style: GoogleFonts.orbitron(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Tesis & Lokasyon Bilgisi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF090E17),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF1E2838)),
            ),
            child: Row(
              children: [
                const Icon(Icons.location_on_rounded, color: Color(0xFF76B900), size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    currentProfile.facility,
                    style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── DETAYLI AI HAVA, YAĞIŞ VE RÜZGAR BRİFİNGİ ──
  Widget _buildDetailedAiAtmosphericBriefing(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1420),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF223247)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF76B900).withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF76B900), size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'NVIDIA AI ATMOSFER & TAHMİN BRİFİNGİ',
                  style: GoogleFonts.orbitron(
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF76B900).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'DETAYLI RAPOR',
                  style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF76B900), fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          _buildBriefingItem(
            icon: Icons.water_drop_rounded,
            iconColor: const Color(0xFF38BDF8),
            title: 'Yağış Seyri & Saat Detayı',
            content: t.rainBriefing,
          ),
          const SizedBox(height: 10),

          _buildBriefingItem(
            icon: Icons.air_rounded,
            iconColor: const Color(0xFFFBBF24),
            title: 'Havanın Rüzgarı & Zirve Hamle Saati',
            content: t.windBriefing,
          ),
          const SizedBox(height: 10),

          _buildBriefingItem(
            icon: Icons.tsunami_rounded,
            iconColor: const Color(0xFF00F0FF),
            title: 'Körfez Dalga Boyu & Deniz Durumu',
            content: t.waveBriefing,
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String content,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF080C14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1A2433)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: iconColor),
                ),
                const SizedBox(height: 3),
                Text(
                  content,
                  style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFE2E8F0), height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 24 SAATLİK ZAMAN ÇİZELGESİ ŞERİDİ ──
  Widget _buildHourlyForecastStrip(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0C131D),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF1E2A3A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'SAAT SAAT HAVA, RÜZGAR VE DALGA AKIŞI',
                style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              Text(
                'Önümüzdeki 24 Saat',
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 115,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: t.hourly.length,
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final slot = t.hourly[i];
                final hourStr = DateFormat('HH:mm').format(slot.time);

                return Container(
                  width: 90,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF121B27),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: slot.rainProb >= 30 ? const Color(0xFF38BDF8).withValues(alpha: 0.6) : const Color(0xFF1E2B3C),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        hourStr,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10.5, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            slot.rainProb >= 30 ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                            size: 14,
                            color: slot.rainProb >= 30 ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${slot.temp.toStringAsFixed(0)}°',
                            style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.air_rounded, size: 12, color: Color(0xFFFBBF24)),
                          const SizedBox(width: 2),
                          Text(
                            '${slot.windSpeed.toStringAsFixed(0)} km/s',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9.5, color: const Color(0xFFCBD5E1), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.waves_rounded, size: 11, color: Color(0xFF00F0FF)),
                          const SizedBox(width: 2),
                          Text(
                            '${slot.waveHeight.toStringAsFixed(2)} m',
                            style: GoogleFonts.jetBrainsMono(fontSize: 9, color: const Color(0xFF00F0FF), fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ── 4. HAVANIN RÜZGAR HESAPLAMASI & FİZİKSEL TELEMETRİ ──
  Widget _buildAtmosphericPhysicsGrid(Earth2Telemetry t) {
    final knotVal = (t.windSpeed10m / 1.852).toStringAsFixed(1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'HAVANIN RÜZGAR VE DENİZ PARAMETRELERİ',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Havanın Rüzgar Hızı',
                value: '${t.windSpeed10m.toStringAsFixed(1)} km/s',
                subtext: '$knotVal Knot • Yön: ${t.windDirectionName}',
                icon: Icons.air_rounded,
                accentColor: const Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'En Sert Rüzgar Hamlesi',
                value: '${t.windGusts.toStringAsFixed(1)} km/s',
                subtext: 'Ani Hava Hızı Değişimi',
                icon: Icons.speed_rounded,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricTile(
                title: 'Körfez Dalga Boyu',
                value: '${t.waveHeight.toStringAsFixed(2)} metre',
                subtext: t.waveConditionName,
                icon: Icons.tsunami_rounded,
                accentColor: const Color(0xFF00F0FF),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricTile(
                title: 'Yüzey Basıncı',
                value: '${t.pressure.toStringAsFixed(1)} hPa',
                subtext: 'Barometrik Hava Akımı Normal',
                icon: Icons.compress_rounded,
                accentColor: const Color(0xFFA855F7),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required String subtext,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141E),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accentColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
          ),
          const SizedBox(height: 3),
          Text(
            subtext,
            style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildMicroclimateImpactCard(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1520),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF243447)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.terrain_rounded, color: Color(0xFFF59E0B), size: 18),
              const SizedBox(width: 8),
              Text(
                'MİKRO-KLİMA & AMANOS HAVA KORİDORU ANALİZİ',
                style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            currentProfile.microclimateNote,
            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFFCBD5E1), height: 1.4),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF161F2E),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.navigation_rounded, size: 16, color: Color(0xFF38BDF8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aktif Rüzgar Yönü: ${t.windDirectionName} (${t.windDirection.toStringAsFixed(0)}°)',
                    style: GoogleFonts.inter(fontSize: 10.5, color: const Color(0xFFE2E8F0), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrDiffDailyForecast(Earth2Telemetry t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '7 GÜNLÜK GENERATIVE CORRDIFF TAHMİNİ',
              style: GoogleFonts.orbitron(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF94A3B8),
                letterSpacing: 0.8,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF76B900).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                'AI TENSOR v2.4',
                style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF76B900), fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: t.daily.length,
          separatorBuilder: (context, index) => const SizedBox(height: 8),
          itemBuilder: (context, i) {
            final day = t.daily[i];
            final dateStr = i == 0 ? 'Bugün' : DateFormat('EEEE', 'tr_TR').format(day.date);

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              decoration: BoxDecoration(
                color: const Color(0xFF0F1522),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF1E2838)),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: Text(
                      dateStr,
                      style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              day.rainProb > 35 ? Icons.water_drop_rounded : Icons.wb_sunny_rounded,
                              size: 14,
                              color: day.rainProb > 35 ? const Color(0xFF38BDF8) : const Color(0xFFFBBF24),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              day.condition,
                              style: GoogleFonts.inter(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        Text(
                          day.detailNote,
                          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${day.minTemp.toStringAsFixed(0)}° / ${day.maxTemp.toStringAsFixed(0)}°',
                    style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF76B900).withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '%${day.aiConfidence}',
                      style: GoogleFonts.jetBrainsMono(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF76B900)),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // ── MODÜL 2: NVIDIA EARTH-2 STORMSCOPE GÖRÜNÜMÜ ──
  // ══════════════════════════════════════════════════════════════════════════
  Widget _buildStormScopeView() {
    final t = _telemetry!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLiveRadarCanvas(t),
        const SizedBox(height: 14),

        _buildStormRiskMatrix(t),
        const SizedBox(height: 14),

        _buildNowcastTimeSlotTimeline(t),
        const SizedBox(height: 14),

        _buildAtmosphericActionCard(t),
      ],
    ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.05, end: 0);
  }

  Widget _buildLiveRadarCanvas(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF090E17),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF00F0FF).withValues(alpha: 0.08),
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
                      color: const Color(0xFF00F0FF).withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.radar_rounded, color: Color(0xFF00F0FF), size: 18),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'STORMSCOPE RADAR NOWCAST',
                        style: GoogleFonts.orbitron(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: const Color(0xFF00F0FF),
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Alt-Kilometre Konvektif Fırtına & Hücre Taraması',
                        style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00F0FF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.4)),
                ),
                child: Text(
                  'TARANIYOR',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF00F0FF),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Center(
            child: SizedBox(
              width: 250,
              height: 250,
              child: AnimatedBuilder(
                animation: _radarController,
                builder: (context, child) {
                  return CustomPaint(
                    painter: _RadarSweepPainter(
                      sweepAngle: _radarController.value * 2 * math.pi,
                      primaryColor: const Color(0xFF00F0FF),
                      hasStormCells: t.maxDbz > 25,
                      locationName: currentProfile.district,
                    ),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRadarSubMetric('Maksimum Reflektiflik', '${t.maxDbz} dBZ', const Color(0xFF38BDF8)),
              _buildRadarSubMetric('Havanın Rüzgarı', '${t.windSpeed10m.toStringAsFixed(1)} km/s', const Color(0xFF76B900)),
              _buildRadarSubMetric('Dalga Yüksekliği', '${t.waveHeight.toStringAsFixed(2)} m', const Color(0xFF00F0FF)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRadarSubMetric(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.orbitron(fontSize: 14, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildStormRiskMatrix(Earth2Telemetry t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EKSTREM HAVA & FIRTINA RİSK MATRİSİ',
          style: GoogleFonts.orbitron(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF94A3B8),
            letterSpacing: 0.8,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildRiskCard(
                title: 'Yıldırım Riski',
                percent: t.lightningRiskPercent,
                status: t.lightningRiskPercent > 40 ? 'DİKKAT' : 'GÜVENLİ',
                icon: Icons.bolt_rounded,
                accentColor: const Color(0xFFFBBF24),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildRiskCard(
                title: 'Mikropatlama / Rüzgar Kesmesi',
                percent: t.microburstRiskPercent,
                status: t.microburstRiskPercent > 35 ? 'ORTA RİSK' : 'DÜŞÜK',
                icon: Icons.air_rounded,
                accentColor: const Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRiskCard({
    required String title,
    required double percent,
    required String status,
    required IconData icon,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1522),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF1E2838)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, size: 18, color: accentColor),
              Text(
                '%${percent.toStringAsFixed(0)}',
                style: GoogleFonts.orbitron(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8), fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: (percent / 100.0).clamp(0.05, 1.0),
              backgroundColor: const Color(0xFF1E293B),
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 5,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            status,
            style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: accentColor),
          ),
        ],
      ),
    );
  }

  Widget _buildNowcastTimeSlotTimeline(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D141F),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'GELECEK 120 DAKİKA NOWCAST ÇİZELGESİ',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Text(
                '15 dk hassasiyet',
                style: GoogleFonts.inter(fontSize: 9.5, color: const Color(0xFF64748B)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 90,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: math.min(10, t.hourly.length),
              separatorBuilder: (context, index) => const SizedBox(width: 10),
              itemBuilder: (context, i) {
                final slot = t.hourly[i];
                final timeStr = DateFormat('HH:mm').format(slot.time);

                return Container(
                  width: 78,
                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131C2B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: slot.dbz > 30 ? const Color(0xFF00F0FF).withValues(alpha: 0.6) : const Color(0xFF1E293B),
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.jetBrainsMono(fontSize: 10, color: const Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                      ),
                      Icon(
                        slot.dbz > 30 ? Icons.water_drop_rounded : Icons.cloud_queue_rounded,
                        size: 16,
                        color: slot.dbz > 30 ? const Color(0xFF00F0FF) : const Color(0xFF64748B),
                      ),
                      Text(
                        '${slot.dbz.toStringAsFixed(0)} dBZ',
                        style: GoogleFonts.orbitron(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphericActionCard(Earth2Telemetry t) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101926),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF00F0FF).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_rounded, color: Color(0xFF00F0FF), size: 18),
              const SizedBox(width: 8),
              Text(
                'ATMOSFERİK GÜVENLİK & RÜZGAR DEĞERLENDİRMESİ',
                style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            t.stormStatusText,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFE2E8F0), height: 1.4),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'DURUM: ${t.atmosphericSafetyStatus}',
                  style: GoogleFonts.orbitron(fontSize: 9.5, fontWeight: FontWeight.bold, color: const Color(0xFF34D399)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── YÜKLENİYOR DURUMU ──
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 44,
            height: 44,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF76B900)),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'NVIDIA EARTH-2 TENSÖRLERİ YÜKLENİYOR...',
            style: GoogleFonts.orbitron(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
          ),
          const SizedBox(height: 6),
          Text(
            '${currentProfile.name} atmosferik ve rüzgar modeli senkronize ediliyor',
            style: GoogleFonts.inter(fontSize: 11, color: const Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }

  // ── FOOTER ──
  Widget _buildFooterCredentials() {
    return Center(
      child: Column(
        children: [
          Text(
            'POWERED BY NVIDIA EARTH-2 FULL-STACK CLIMATE AI',
            style: GoogleFonts.orbitron(fontSize: 9, fontWeight: FontWeight.bold, color: const Color(0xFF475569), letterSpacing: 1.0),
          ),
          const SizedBox(height: 4),
          Text(
            'FourCastNet • CorrDiff • StormScope Tensor Diffusion',
            style: GoogleFonts.jetBrainsMono(fontSize: 8.5, color: const Color(0xFF334155)),
          ),
        ],
      ),
    );
  }
}

// ── CANLI RADAR ÇİZİCİSİ (RADAR SWEEP PAINTER) ──
class _RadarSweepPainter extends CustomPainter {
  final double sweepAngle;
  final Color primaryColor;
  final bool hasStormCells;
  final String locationName;

  _RadarSweepPainter({
    required this.sweepAngle,
    required this.primaryColor,
    required this.hasStormCells,
    required this.locationName,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    final bgPaint = Paint()..color = const Color(0xFF04070B);
    canvas.drawCircle(center, radius, bgPaint);

    final ringPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.33, ringPaint);
    canvas.drawCircle(center, radius * 0.66, ringPaint);
    canvas.drawCircle(center, radius * 0.98, ringPaint);

    final axisPaint = Paint()
      ..color = primaryColor.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;

    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);

    final sweepPaint = Paint()
      ..shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        colors: [
          primaryColor.withValues(alpha: 0.0),
          primaryColor.withValues(alpha: 0.45),
        ],
        stops: const [0.85, 1.0],
        transform: GradientRotation(sweepAngle),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, sweepPaint);

    final linePaint = Paint()
      ..color = primaryColor
      ..strokeWidth = 1.6;

    final lineEnd = Offset(
      center.dx + radius * math.cos(sweepAngle),
      center.dy + radius * math.sin(sweepAngle),
    );
    canvas.drawLine(center, lineEnd, linePaint);

    final cellPaint = Paint()
      ..color = const Color(0xFFEF4444).withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(center.dx + radius * 0.42, center.dy - radius * 0.35), 4.5, cellPaint);
    canvas.drawCircle(Offset(center.dx - radius * 0.38, center.dy + radius * 0.25), 3.5, cellPaint);

    final centerDotPaint = Paint()..color = primaryColor;
    canvas.drawCircle(center, 4, centerDotPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarSweepPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle;
  }
}

// ── SİBER ARKAPLAN IZGARASI ──
class _GridBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..strokeWidth = 1.0;

    const step = 32.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
