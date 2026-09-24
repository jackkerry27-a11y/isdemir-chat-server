import 'dart:io';
import 'package:flutter/services.dart';

class RadioBackgroundService {
  static const MethodChannel _channel = MethodChannel('com.isdemir.app/radio_service');

  /// Telsiz için arka plan Foreground Servisini başlat (Bildirim panelinde kalır, uyumaz)
  static Future<void> startService({required String channelName, required String freq}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('startService', {
        'channelName': channelName,
        'freq': freq,
      });
    } catch (e) {
      // Sessiz hata yakalama
    }
  }

  /// Telsiz kapatıldığında Foreground Servisini durdur
  static Future<void> stopService() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('stopService');
    } catch (e) {
      // Sessiz hata yakalama
    }
  }

  /// Arka plan bildirim metnini dinamik güncelle (Örn: konuşan kişi değiştiğinde)
  static Future<void> updateNotification({required String title, required String text}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'title': title,
        'text': text,
      });
    } catch (e) {
      // Sessiz hata yakalama
    }
  }
}
