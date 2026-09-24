import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Desteklenen Gizlilik ve Şifreleme Protokolleri
enum NoctraProtocol {
  simplex, // Sıfır kullanıcı kimliği (Zero-Metadata / Anonymous Session)
  nyxChat, // P2P doğrudan iletişim & Panic Wipe & Özelleştirilebilir kendini imha
  layergram, // Delete-after-read & Görsel içi steganografik şifreleme
  flutterChatUi, // Zengin medya balonları ve anlık durum akışı
}

/// Mesaj Durumu
enum MessageSecurityState {
  encrypted, // Kilitli, şifrelenmiş (1x açılmamış)
  decrypting, // Çözülme aşamasında (animasyon oynatılıyor)
  viewed, // Çözüldü, geri sayım başladı
  burned, // İmha edildi, kalıcı olarak yok oldu
  normal, // Standart şifreli metin
}

class NoctraMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderAvatar;
  final String content;
  final String time;
  final bool isMe;
  final bool isEphemeral; // 1x Tek görüntülemelik mi?
  final int burnDurationSeconds; // Kaç saniyede imha olacak?
  MessageSecurityState state;
  int remainingSeconds;
  final bool isAudio;
  final String? audioDuration;
  final bool isSteganographic;

  NoctraMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderAvatar,
    required this.content,
    required this.time,
    required this.isMe,
    this.isEphemeral = false,
    this.burnDurationSeconds = 10,
    this.state = MessageSecurityState.normal,
    this.remainingSeconds = 10,
    this.isAudio = false,
    this.audioDuration,
    this.isSteganographic = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'senderId': senderId,
        'senderName': senderName,
        'senderAvatar': senderAvatar,
        'content': state == MessageSecurityState.burned ? '[Silindi]' : content,
        'time': time,
        'isMe': isMe,
        'isEphemeral': isEphemeral,
        'burnDurationSeconds': burnDurationSeconds,
        'state': state.name,
        'remainingSeconds': remainingSeconds,
        'isAudio': isAudio,
        'audioDuration': audioDuration,
        'isSteganographic': isSteganographic,
      };

  factory NoctraMessage.fromJson(Map<String, dynamic> json) => NoctraMessage(
        id: json['id'] ?? '',
        senderId: json['senderId'] ?? '',
        senderName: json['senderName'] ?? '',
        senderAvatar: json['senderAvatar'],
        content: json['content'] ?? '',
        time: json['time'] ?? '',
        isMe: json['isMe'] ?? false,
        isEphemeral: json['isEphemeral'] ?? false,
        burnDurationSeconds: json['burnDurationSeconds'] ?? 10,
        state: MessageSecurityState.values.firstWhere(
          (e) => e.name == json['state'],
          orElse: () => MessageSecurityState.normal,
        ),
        remainingSeconds: json['remainingSeconds'] ?? 10,
        isAudio: json['isAudio'] ?? false,
        audioDuration: json['audioDuration'],
        isSteganographic: json['isSteganographic'] ?? false,
      );
}

class NoctraSecurityService {
  static final NoctraSecurityService _instance = NoctraSecurityService._internal();
  factory NoctraSecurityService() => _instance;
  NoctraSecurityService._internal();

  NoctraProtocol activeProtocol = NoctraProtocol.nyxChat;
  bool isAnonymousSession = false;
  String? anonymousAlias;
  String? sessionFingerprint;

  /// SimpleX Chat: Anonim / İz Bırakmayan Oturum Başlat
  void startSimpleXAnonymousSession() {
    isAnonymousSession = true;
    final random = Random();
    final hexDigits = List.generate(8, (_) => random.nextInt(16).toRadixString(16)).join().toUpperCase();
    anonymousAlias = 'Hayalet_$hexDigits';
    sessionFingerprint = 'SX-${List.generate(16, (_) => random.nextInt(16).toRadixString(16)).join().toUpperCase()}';
    activeProtocol = NoctraProtocol.simplex;
  }

  /// NyxChat: PANIC WIPE (Acil Tüm Verileri ve Kripto Anahtarlarını Kalıcı Olarak Temizle)
  Future<void> triggerPanicWipe() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith('noctra_')).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
    isAnonymousSession = false;
    anonymousAlias = null;
    sessionFingerprint = null;
    debugPrint('[NOCTRA PANIC WIPE] Bütün yerel şifreli veriler ve oturum izleri başarıyla imha edildi.');
  }

  /// Layergram: Steganografi Simülasyonu (Gizli Metni Görsele Gömer)
  String encodeSteganography(String secretText, String imagePlaceholder) {
    final base64Payload = base64Encode(utf8.encode(secretText));
    return 'STEGO://$imagePlaceholder?payload=$base64Payload';
  }

  String? decodeSteganography(String stegoData) {
    if (!stegoData.startsWith('STEGO://')) return null;
    try {
      final uri = Uri.parse(stegoData);
      final payload = uri.queryParameters['payload'];
      if (payload != null) {
        return utf8.decode(base64Decode(payload));
      }
    } catch (e) {
      debugPrint('Stego decode hatası: $e');
    }
    return null;
  }

  /// Varsayılan Demo Konuşmaları (Ekran görüntüsündeki gibi)
  List<Map<String, dynamic>> getDefaultChatList() {
    return [
      {
        'id': 'c_karanlik',
        'name': 'Karanlık',
        'lastMessage': '• Şifreli mesaj',
        'time': '23:41',
        'unread': 1,
        'isOnline': true,
        'isEncrypted': true,
        'avatar': 'assets/images/dock_worker_3d.png',
        'protocol': 'NyxChat (P2P + 1x Burn)',
      },
      {
        'id': 'c_golge',
        'name': 'Gölge',
        'lastMessage': 'Görüntülendi ve silindi.',
        'time': '22:17',
        'unread': 0,
        'isOnline': false,
        'isEncrypted': true,
        'avatar': null,
        'protocol': 'Layergram (Delete-after-read)',
      },
      {
        'id': 'c_mira',
        'name': 'Mira',
        'lastMessage': '• Sesli mesaj',
        'time': '21:03',
        'unread': 0,
        'isOnline': true,
        'isEncrypted': false,
        'isAudio': true,
        'avatar': null,
        'protocol': 'Flutter Chat UI',
      },
      {
        'id': 'c_zero',
        'name': 'Zero',
        'lastMessage': '• 1 yeni mesaj',
        'time': '19:27',
        'unread': 1,
        'isOnline': false,
        'isEncrypted': true,
        'avatar': null,
        'protocol': 'SimpleX (Zero-Metadata)',
      },
      {
        'id': 'c_siyah',
        'name': 'Siyah',
        'lastMessage': 'Tamam.',
        'time': 'Dün',
        'unread': 0,
        'isOnline': false,
        'isEncrypted': false,
        'avatar': null,
        'protocol': 'NyxChat',
      },
    ];
  }
}
