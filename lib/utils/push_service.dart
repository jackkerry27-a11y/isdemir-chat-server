import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:onesignal_flutter/onesignal_flutter.dart';

class PushService {
  static const String appId = '74f25810-49aa-4dd1-938c-c30229368a63';
  static const String restApiKey =
      'b3NfdjJfYXBwX290emZxZWNqdmpnNWRlNG15bWJjc251a21uaGV6YmdrcG5pdWtzNXU3aWNleG1seXE2Nzc2cDYyM2VrMmJ5c3N2emJ4bW8ydHRqcDZjZ2xpdjZpb2pueXp5ZzJvbXViZGplb3J5eXk=';

  /// Kullanıcının OneSignal üzerindeki VIP etiketini günceller.
  static void setVipTag(bool isVip) {
    try {
      OneSignal.User.addTagWithKey('is_vip', isVip ? 'true' : 'false');
    } catch (_) {}
  }

  /// Bildirimi gönderir.
  /// Gemiyle ilgili bildirimler veya isVipOnly=true olan bildirimler
  /// SADECE OneSignal üzerinde is_vip="true" etiketi olan cihazlara gönderilir!
  static Future<void> sendPushNotification({
    required String title,
    required String content,
    String? targetCihazId,
    bool isVipOnly = false,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      final key = utf8.decode(base64.decode(restApiKey));

      final Map<String, dynamic> body = {
        'app_id': appId,
        'headings': {'en': title, 'tr': title},
        'contents': {'en': content, 'tr': content},
      };

      if (additionalData != null) {
        body['data'] = additionalData;
      }

      final isVipTarget = isVipOnly ||
          (additionalData != null &&
              (additionalData['type']?.toString().startsWith('ship') ?? false)) ||
          (additionalData != null &&
              additionalData['type'] == 'telsiz_channel') ||
          title.toLowerCase().contains('telsiz') ||
          content.toLowerCase().contains('telsiz') ||
          title.toLowerCase().contains('gemi') ||
          title.toLowerCase().contains('rıhtım') ||
          title.toLowerCase().contains('posta') ||
          title.toLowerCase().contains('vip') ||
          content.toLowerCase().contains('gemi') ||
          content.toLowerCase().contains('rıhtım') ||
          content.toLowerCase().contains('posta');

      if (targetCihazId != null) {
        body['include_aliases'] = {
          'external_id': [targetCihazId]
        };
        body['target_channel'] = 'push';
      } else if (isVipTarget) {
        // 🔒 SADECE VIP KULLANICILARIN CİHAZLARINA HEDEFLENİR
        body['filters'] = [
          {'field': 'tag', 'key': 'is_vip', 'relation': '=', 'value': 'true'}
        ];
      } else {
        body['included_segments'] = ['Total Subscriptions'];
      }

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Key $key',
        },
        body: json.encode(body),
      );
    } catch (e) {
      // Sessizce hatayı yutalım ki uygulamanın akışı bozulmasın
    }
  }
}
