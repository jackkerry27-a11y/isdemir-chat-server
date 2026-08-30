import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class WeatherData {
  final double temperature;
  final int weatherCode;
  final double windSpeed;
  final int humidity;
  final double visibility;
  final double waveHeight;
  final DateTime? nextRainTime;

  WeatherData({
    required this.temperature,
    required this.weatherCode,
    required this.windSpeed,
    required this.humidity,
    this.visibility = 10000.0,
    this.waveHeight = 0.0,
    this.nextRainTime,
  });

  String getWeatherDescription() {
    switch (weatherCode) {
      case 0: return 'Açık ve Güneşli';
      case 1:
      case 2:
      case 3: return 'Parçalı Bulutlu';
      case 45:
      case 48: return 'Sisli';
      case 51:
      case 53:
      case 55: return 'Çisenti';
      case 61:
      case 63:
      case 65: return 'Yağmurlu';
      case 71:
      case 73:
      case 75: return 'Karlı';
      case 95:
      case 96:
      case 99: return 'Gökgürültülü Fırtına';
      default: return 'Bilinmiyor';
    }
  }

  String getIconPath() {
    return 'sunny';
  }
}

class WeatherService {
  // Payas, Hatay koordinatları
  static const double lat = 36.7583;
  static const double lon = 36.2167;
  
  static WeatherData? _cachedData;
  static DateTime? _lastFetchTime;

  static Future<WeatherData?> getCurrentWeather() async {
    // 5 dakikalık önbellek
    if (_cachedData != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 5) {
        return _cachedData;
      }
    }

    try {
      final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,visibility&hourly=weather_code&timezone=Europe%2FIstanbul');
      final marineUrl = Uri.parse('https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon&current=wave_height');
      
      final weatherResponse = await http.get(weatherUrl).timeout(const Duration(seconds: 5));
      
      double wHeight = 0.0;
      try {
        final marineResponse = await http.get(marineUrl).timeout(const Duration(seconds: 3));
        if (marineResponse.statusCode == 200) {
          final mData = json.decode(marineResponse.body);
          if (mData['current'] != null && mData['current']['wave_height'] != null) {
            wHeight = (mData['current']['wave_height'] as num).toDouble();
          }
        }
      } catch (e) {
        print('Marine API Error: $e');
      }

      if (weatherResponse.statusCode == 200) {
        final data = json.decode(weatherResponse.body);
        final current = data['current'];
        
        DateTime? nextRain;
        if (data['hourly'] != null) {
          final times = data['hourly']['time'] as List;
          final codes = data['hourly']['weather_code'] as List;
          final now = DateTime.now();
          
          for (int i = 0; i < times.length; i++) {
            DateTime time = DateTime.parse(times[i]);
            if (time.isAfter(now) && time.difference(now).inHours <= 24) {
              int code = codes[i] as int;
              if ([51, 53, 55, 61, 63, 65, 71, 73, 75, 80, 81, 82, 95, 96, 99].contains(code)) {
                nextRain = time;
                break;
              }
            }
          }
        }
        
        _cachedData = WeatherData(
          temperature: (current['temperature_2m'] as num).toDouble(),
          weatherCode: current['weather_code'] as int,
          windSpeed: (current['wind_speed_10m'] as num).toDouble(),
          humidity: current['relative_humidity_2m'] as int,
          visibility: (current['visibility'] as num?)?.toDouble() ?? 10000.0,
          waveHeight: wHeight,
          nextRainTime: nextRain,
        );
        _lastFetchTime = DateTime.now();
        
        return _cachedData;
      }
    } catch (e) {
      print('Weather API Error: $e');
    }
    
    return _cachedData;
  }

  // Kritik hava ve deniz durumlarını push bildirim olarak gönderme motoru
  static Future<void> checkAndTriggerWeatherNotification() async {
    final weather = await getCurrentWeather();
    if (weather == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final nowMs = DateTime.now().millisecondsSinceEpoch;

      // 1. Yağmur Uyarısı
      if (weather.nextRainTime != null) {
        final lastRainAlert = prefs.getInt('last_weather_rain_alert') ?? 0;
        if (nowMs - lastRainAlert > 4 * 60 * 60 * 1000) {
          final timeStr = "${weather.nextRainTime!.hour.toString().padLeft(2, '0')}:00";
          final title = '🌧️ İsdemir Yağmur Uyarısı';
          final msg = 'Saat $timeStr civarında Payas ve İsdemir Liman sahasında yağış bekleniyor. Açık saha ve vinç operasyonlarında tedbir alınız.';
          await _sendPush(title, msg);
          await prefs.setInt('last_weather_rain_alert', nowMs);
        }
      }

      // 2. Deniz / Dalga Uyarısı
      if (weather.waveHeight >= 1.0) {
        final lastWaveAlert = prefs.getInt('last_weather_wave_alert') ?? 0;
        if (nowMs - lastWaveAlert > 6 * 60 * 60 * 1000) {
          final title = '⚠️ İsdemir Liman Dalga Uyarısı';
          final msg = 'İsdemir açıklarında dalga boyu ${weather.waveHeight} metreye ulaştı. Rıhtım ve gemi yanaşma operasyonlarında dikkatli olunuz.';
          await _sendPush(title, msg);
          await prefs.setInt('last_weather_wave_alert', nowMs);
        }
      }
    } catch (e) {
      print('Hava durumu push bildirimi hatası: $e');
    }
  }

  static Future<void> _sendPush(String title, String content) async {
    // 1. Render sunucumuz üzerinden güvenli bildirim gönderimi
    try {
      await http.post(
        Uri.parse('https://isdemir-chat-server.onrender.com/api/weather/notify'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': title,
          'message': content,
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}

    // 2. Yedek doğrudan OneSignal REST API
    try {
      final key = utf8.decode(base64.decode('b3NfdjJfYXBwX290emZxZWNqdmpnNWRlNG15bWJjc251a21uaGV6YmdrcG5pdWtzNXU3aWNleG1seXE2Nzc2cDYyM2VrMmJ5c3N2emJ4bW8ydHRqcDZjZ2xpdjZpb2pueXp5ZzJvbXViZGplb3J5eXk='));
      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $key',
        },
        body: json.encode({
          'app_id': '74f25810-49aa-4dd1-938c-c30229368a63',
          'headings': {'en': title, 'tr': title},
          'contents': {'en': content, 'tr': content},
          'included_segments': ['Total Subscriptions'],
        }),
      ).timeout(const Duration(seconds: 4));
    } catch (_) {}
  }
}
