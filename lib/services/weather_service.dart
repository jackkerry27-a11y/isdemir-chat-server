import 'dart:convert';
import 'package:http/http.dart' as http;

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
    // We can map this to weather icons if needed, 
    // or return a material icon representation string.
    return 'sunny';
  }
}

class WeatherService {
  // Payas, Hatay coordinates
  static const double lat = 36.7583;
  static const double lon = 36.2167;
  
  static WeatherData? _cachedData;
  static DateTime? _lastFetchTime;

  static Future<WeatherData?> getCurrentWeather() async {
    // Cache for 10 minutes to avoid hitting the API too often
    if (_cachedData != null && _lastFetchTime != null) {
      if (DateTime.now().difference(_lastFetchTime!).inMinutes < 10) {
        return _cachedData;
      }
    }

    try {
      final weatherUrl = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,visibility&hourly=weather_code&timezone=Europe%2FIstanbul');
      final marineUrl = Uri.parse('https://marine-api.open-meteo.com/v1/marine?latitude=$lat&longitude=$lon&current=wave_height');
      
      final weatherResponse = await http.get(weatherUrl).timeout(const Duration(seconds: 5));
      
      // Also fetch marine data for wave height
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
    
    // Return cached data if available, even if expired, on error
    return _cachedData;
  }
}
