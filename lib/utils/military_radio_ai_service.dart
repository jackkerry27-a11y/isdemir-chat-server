import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'socket_service.dart';
import 'radio_sound_effects.dart';

/// 🪖 Askeri Taktik Telsiz Anons Şablonu
class TacticalBroadcastPreset {
  final String id;
  final String callSign;
  final String title;
  final String message;
  final IconData icon;
  final Color badgeColor;

  const TacticalBroadcastPreset({
    required this.id,
    required this.callSign,
    required this.title,
    required this.message,
    required this.icon,
    required this.badgeColor,
  });
}

/// 📝 Canlı Taktik Altyazı Kaydı
class TacticalRadioTranscript {
  final String id;
  final String speakerName;
  final String callSign;
  final String channelCode;
  final String text;
  final String time;
  final double confidence;
  final bool isEmergency;

  TacticalRadioTranscript({
    required this.id,
    required this.speakerName,
    required this.callSign,
    required this.channelCode,
    required this.text,
    required this.time,
    this.confidence = 0.98,
    this.isEmergency = false,
  });
}

/// 🧠 ASKERİ TAKTİK TELSİZ AI & SES SERVİSİ
class MilitaryRadioAiService {
  static final MilitaryRadioAiService _instance = MilitaryRadioAiService._internal();
  factory MilitaryRadioAiService() => _instance;
  MilitaryRadioAiService._internal();

  bool isMilSpecModeActive = true;
  String currentProfile = 'commando'; // 'commando', 'motorola', 'airborne'
  int squelchLevelDb = -34; // dB

  final List<TacticalRadioTranscript> recentTranscripts = [];
  Function(TacticalRadioTranscript)? onNewTranscript;

  // Hazır Askeri / Taktik Operasyon Şablonları
  final List<TacticalBroadcastPreset> presets = const [
    TacticalBroadcastPreset(
      id: 'p_komando',
      callSign: 'KOMANDO-1',
      title: 'Taktik Tim Devriyesi',
      message: 'Komando-1 Merkez, 1 No\'lu Kok Fabrikası ve çevre sahası tarandı. Emniyet tam, devriye pozisyonuna geçiliyor, tamam!',
      icon: Icons.military_tech_rounded,
      badgeColor: Color(0xFF00FF66),
    ),
    TacticalBroadcastPreset(
      id: 'p_emergency',
      callSign: 'İSG-ALARM',
      title: 'Kırmızı Kod & Tahliye',
      message: 'Dikkat tüm saha unsurları! 2. Yüksek Fırın çevresinde gaz kaçağı alarmı. Personel derhal toplanma bölgesine çekilsin, tamam!',
      icon: Icons.warning_amber_rounded,
      badgeColor: Color(0xFFFF2A2A),
    ),
    TacticalBroadcastPreset(
      id: 'p_bozkurt',
      callSign: 'BOZKURT-9',
      title: 'Liman Yaklaşım Koridoru',
      message: 'Bozkurt-9 konuşuyor: İskenderun Liman yaklaşım koridoru açık. Tüm telsiz kanalları dinlemede kalsın, tamam!',
      icon: Icons.radar_rounded,
      badgeColor: Color(0xFF00E5FF),
    ),
    TacticalBroadcastPreset(
      id: 'p_crane',
      callSign: 'VİNÇ-OPERASYON',
      title: 'Ağır Yük Transferi',
      message: 'Vinç Operatörü: 4 No\'lu portal vinç kanca kontrolü tamamlandı. 80 tonluk slab transferi başladı, saha serbest, tamam!',
      icon: Icons.precision_manufacturing_rounded,
      badgeColor: Color(0xFFFFB300),
    ),
    TacticalBroadcastPreset(
      id: 'p_sihhiye',
      callSign: 'SIHHİYE-TİM',
      title: 'Medikal Acil Durum',
      message: 'Sıhhiye Timi intikal etti. Haddehane revir ambulansı hazır, ilk müdahale hattı emniyete alındı, tamam!',
      icon: Icons.medical_services_rounded,
      badgeColor: Color(0xFFE040FB),
    ),
  ];

  /// Yeni konuşma geldiğinde simüle edilmiş canlı altyazı ve İSG kelime analizi yap
  void processIncomingSpeech({
    required String speakerName,
    required String channelCode,
    String? rawText,
  }) {
    final now = DateTime.now();
    final timeStr = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    // Rastgele askeri çağrı kodları
    final callSigns = ['BARS-1', 'BOZKURT-3', 'KOMANDO-2', 'MERKEZ', 'SAHA-TİM'];
    final randomCallSign = callSigns[Random().nextInt(callSigns.length)];

    String text = rawText ?? '';
    if (text.isEmpty) {
      final samplePhrases = [
        '3. Rıhtım ambar kontrolü sağlandı, mandal serbest, tamam!',
        'Haddehane 2. hat soğutma suyu debisi nominal seviyede, tamam.',
        'Manevra motorları devrede, palamar botu iskelede bekliyor, tamam!',
        'Vardiya teslim tutanağı onaylandı, tüm frekanslar dinlemede, tamam.',
        'Kule 4 çevresinde görüş net, telsiz modülasyonu kristal temizlikte, tamam.',
      ];
      text = samplePhrases[Random().nextInt(samplePhrases.length)];
    }

    final isEmergency = text.toUpperCase().contains('ACİL') ||
        text.toUpperCase().contains('ALARM') ||
        text.toUpperCase().contains('GAZ') ||
        text.toUpperCase().contains('YANGIN') ||
        text.toUpperCase().contains('DURDUR') ||
        text.toUpperCase().contains('KIRMIZI');

    final transcript = TacticalRadioTranscript(
      id: 'tr_${now.millisecondsSinceEpoch}',
      speakerName: speakerName,
      callSign: randomCallSign,
      channelCode: channelCode,
      text: text,
      time: timeStr,
      confidence: 0.98,
      isEmergency: isEmergency,
    );

    recentTranscripts.insert(0, transcript);
    if (recentTranscripts.length > 25) {
      recentTranscripts.removeLast();
    }

    onNewTranscript?.call(transcript);
  }

  /// Taktik Askeri Anonsu Tüm Kanala Yayınla
  Future<void> broadcastTacticalAnnouncement({
    required String userId,
    required String inviterName,
    required String channel,
    required TacticalBroadcastPreset preset,
  }) async {
    // 1. Askeri Squelch sesi
    await RadioSoundEffects.playSquelchIn();

    // 2. Altyazıya ekle
    processIncomingSpeech(
      speakerName: '$inviterName (${preset.callSign})',
      channelCode: channel,
      rawText: preset.message,
    );

    // 3. Socket.io üzerinden tüm frekanstaki personellere anons ilet
    SocketService().startRadioTalk(
      userId: userId,
      name: '$inviterName [${preset.callSign}]',
      channel: channel,
    );

    // 1.8 saniye sonra Roger Beep ile kapat
    Future.delayed(const Duration(milliseconds: 1800), () async {
      SocketService().endRadioTalk(
        userId: userId,
        name: inviterName,
        channel: channel,
      );
      await RadioSoundEffects.playRogerBeep();
    });
  }

  /// Özel Askeri Taktik Anons Yayınla
  Future<void> broadcastCustomTacticalAnnouncement({
    required String userId,
    required String inviterName,
    required String channel,
    required String callSign,
    required String customMessage,
  }) async {
    // Mesaj sonu askeri telsiz kuralına göre "tamam!" ile bitmeli
    var formattedMsg = customMessage.trim();
    if (!formattedMsg.toLowerCase().endsWith('tamam!') && !formattedMsg.toLowerCase().endsWith('tamam.')) {
      formattedMsg = '$formattedMsg, tamam!';
    }

    await RadioSoundEffects.playSquelchIn();

    processIncomingSpeech(
      speakerName: '$inviterName ($callSign)',
      channelCode: channel,
      rawText: formattedMsg,
    );

    SocketService().startRadioTalk(
      userId: userId,
      name: '$inviterName [$callSign]',
      channel: channel,
    );

    Future.delayed(const Duration(milliseconds: 2000), () async {
      SocketService().endRadioTalk(
        userId: userId,
        name: inviterName,
        channel: channel,
      );
      await RadioSoundEffects.playRogerBeep();
    });
  }
}
