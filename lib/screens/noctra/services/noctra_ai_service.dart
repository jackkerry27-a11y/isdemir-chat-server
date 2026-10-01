import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 🎭 1. Semantik Kamuflaj Temaları
enum CamouflageTheme {
  canteenFood,       // 🥐 Gündelik & Kahvaltı/Yemek
  routineShift,      // 🏭 İSDEMİR Rutin Vardiya & Bakım
  footballMatch,     // ⚽ Halı Saha & Spor
  shoppingGroceries, // 🛒 Market & Alışveriş
}

class CamouflagePayload {
  final CamouflageTheme theme;
  final String decoyText;
  final String secretText;

  CamouflagePayload({
    required this.theme,
    required this.decoyText,
    required this.secretText,
  });

  String pack() {
    final secretEncoded = base64Encode(utf8.encode(secretText));
    return 'STEGO_AI::${theme.name}::$decoyText::$secretEncoded';
  }

  static CamouflagePayload? unpack(String raw) {
    if (!raw.startsWith('STEGO_AI::')) return null;
    try {
      final parts = raw.split('::');
      if (parts.length >= 4) {
        final theme = CamouflageTheme.values.firstWhere(
          (t) => t.name == parts[1],
          orElse: () => CamouflageTheme.routineShift,
        );
        final decoy = parts[2];
        final secretDecoded = utf8.decode(base64Decode(parts[3]));
        return CamouflagePayload(
          theme: theme,
          decoyText: decoy,
          secretText: secretDecoded,
        );
      }
    } catch (e) {
      debugPrint('Camouflage unpack hatası: $e');
    }
    return null;
  }
}

/// 🎙️ 2. Aura-Voice Biyometrik Maskeleme Profilleri
enum AuraVoiceProfile {
  ghostFrequency,    // 👻 Hayalet Frekans (85Hz Sub-Bass Derin Ton)
  cyberSynthesizer,  // 🤖 Nöral Siber Vokoder (Sentetik Filtre)
  quantumVocoder,    // ⚡ Kuantum Formant Karıştırıcı (Biyometriyi Sıfırlar)
}

/// 👁️ 3. Visual Sentinel Gözetleme Tehdit Seviyesi
enum SentinelThreatState {
  secure,      // Güvenli (Omuz dikizleme yok)
  scanning,    // Nöral Optik Tarama Aktif
  breached,    // Tehdit / Dikizleme Algılandı (Ekran Karartıldı)
}

/// 🖼️ 4. Nöral Steganografi Taşıyıcı Görselleri
class StegoCover {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const StegoCover({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });
}

/// 🧠 NOCTRA AI MERKEZİ HİZMETİ
class NoctraAiService {
  static final NoctraAiService _instance = NoctraAiService._internal();
  factory NoctraAiService() => _instance;
  NoctraAiService._internal();

  // Sentinel AI durumu
  bool isSentinelEnabled = true;
  SentinelThreatState sentinelState = SentinelThreatState.secure;

  // Varsayılan Duress PIN (Zorlama Şifresi)
  static const String defaultDuressPin = '9999';

  final List<StegoCover> availableStegoCovers = const [
    StegoCover(
      id: 'dock_pier',
      title: 'İSDEMİR 3. İskele Dok Sahası',
      subtitle: 'Gündüz vardiyası rıhtım manzarası',
      icon: Icons.anchor_rounded,
      accentColor: Color(0xFF00E5FF),
    ),
    StegoCover(
      id: 'blast_furnace',
      title: 'Yüksek Fırın Gece Operasyonu',
      subtitle: 'Sıvı ham demir döküm hattı',
      icon: Icons.local_fire_department_rounded,
      accentColor: Color(0xFFFF5252),
    ),
    StegoCover(
      id: 'hot_strip',
      title: 'Sıcak Haddehane Bobin Deposu',
      subtitle: 'Çelik rulo istifleme alanı',
      icon: Icons.precision_manufacturing_rounded,
      accentColor: Color(0xFFFFB300),
    ),
  ];

  // ── 1. SEMANTİK KAMUFLAJ OLUŞTURUCU ──
  CamouflagePayload generateCamouflage(String secretText, CamouflageTheme theme) {
    final random = math.Random();
    String decoy;
    switch (theme) {
      case CamouflageTheme.canteenFood:
        final options = [
          'Yarın sabah fırından sıcak simit alıp geliyorum, çayı demleyin.',
          'Öğle yemeğinde mercimek çorbası ve köfte varmış, erken gidelim.',
          'Kantin fişlerini muhasebeye teslim ettim, bilginize.',
          'Akşam üzeri 4 çayında mola veriyoruz, aşağıda buluşalım.',
        ];
        decoy = options[random.nextInt(options.length)];
        break;

      case CamouflageTheme.routineShift:
        final options = [
          '2. kademe soğutma vanalarının periyodik test raporunu masana bıraktım.',
          'Gündüz vardiyası teslim tutanağını imzaladım, her şey normal.',
          'Haddehane motor yataklarının yağlama kontrolü tamamlandı.',
          'Vinç operatörünün bakım formu sisteme yüklendi, onay bekliyor.',
        ];
        decoy = options[random.nextInt(options.length)];
        break;

      case CamouflageTheme.footballMatch:
        final options = [
          'Perşembe akşamı halı saha maç kadrosunda 2 kişi eksik, kaleye kimi alıyoruz?',
          'Kramponları arabada unutmuşum, maç saat 20:00\'da değil miydi?',
          'Bu hafta maçtan sonra tatlılar kaybeden takımdan ona göre.',
          'Saha kaporasını yatırdım, yeşil yelekleri sen getirir misin?',
        ];
        decoy = options[random.nextInt(options.length)];
        break;

      case CamouflageTheme.shoppingGroceries:
        final options = [
          'Akşam eve gelirken 2 ekmek, süt ve maden suyu almayı unutma.',
          'Manavdan domates ve yeşillik aldım, başka bir eksik var mı?',
          'Market alışveriş listesini buzdolabının üstüne yapıştırdım.',
          'Hafta sonu için deterjan ve temizlik malzemesi sipariş verdim.',
        ];
        decoy = options[random.nextInt(options.length)];
        break;
    }

    return CamouflagePayload(
      theme: theme,
      decoyText: decoy,
      secretText: secretText,
    );
  }

  // ── 2. NÖRAL STEGANOGRAFİ GÖRSEL PAKETLEME ──
  String packStegoPayload(String coverId, String secretText) {
    final encodedSecret = base64Encode(utf8.encode(secretText));
    return 'STEGO_IMG::$coverId::$encodedSecret';
  }

  Map<String, String>? unpackStegoPayload(String raw) {
    if (!raw.startsWith('STEGO_IMG::')) return null;
    try {
      final parts = raw.split('::');
      if (parts.length >= 3) {
        final coverId = parts[1];
        final secret = utf8.decode(base64Decode(parts[2]));
        return {'coverId': coverId, 'secret': secret};
      }
    } catch (_) {}
    return null;
  }

  // ── 3. AURA-VOICE MODÜLASYON VERİSİ ──
  List<double> generateSpectrogramWaveform({int barCount = 24}) {
    final random = math.Random();
    return List.generate(barCount, (i) {
      final base = math.sin((i / barCount) * math.pi);
      return (base * 0.7 + random.nextDouble() * 0.3).clamp(0.15, 1.0);
    });
  }

  String getVoiceProfileDescription(AuraVoiceProfile profile) {
    switch (profile) {
      case AuraVoiceProfile.ghostFrequency:
        return '👻 Ghost Frequency (85Hz Sub-Bass • Kimlik Sıfırlandı)';
      case AuraVoiceProfile.cyberSynthesizer:
        return '🤖 Cyber Synthesizer (Nöral Siber Vokoder Tonu)';
      case AuraVoiceProfile.quantumVocoder:
        return '⚡ Quantum Vocoder (Biyometrik Formant Karıştırıcı)';
    }
  }

  // ── 4. BASKI / ŞANTAJ KORUMASI (DURESS PIN KONTROLÜ) ──
  Future<bool> isDuressPin(String pin, String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final customDuress = prefs.getString('noctra_duress_pin_$userId');
    return pin == (customDuress ?? defaultDuressPin);
  }

  // ── 5. SAHTE KASA (DECOY VAULT) İÇERİĞİ ──
  List<Map<String, dynamic>> getDecoyVaultChats() {
    return [
      {
        'id': 'decoy_1',
        'name': 'Ahmet Şef (Mekanik Bakım)',
        'lastMessage': 'Yarın sabah 08:00 filtre temizliği yapılacak, ekip hazır olsun.',
        'time': '16:42',
        'unread': 0,
        'avatar': null,
        'department': 'Haddehane Mekanik',
      },
      {
        'id': 'decoy_2',
        'name': 'Yemekhane Duyuru Hattı',
        'lastMessage': 'Perşembe menüsü: Ezogelin çorbası, Tas kebabı, Pilav ve Kemalpaşa.',
        'time': '14:15',
        'unread': 1,
        'avatar': null,
        'department': 'İdari İşler',
      },
      {
        'id': 'decoy_3',
        'name': 'İSDEMİR Halı Saha Grubu',
        'lastMessage': 'Maç saat 21:00\'e alındı, yeşil yelekleri unutmayın.',
        'time': '11:20',
        'unread': 0,
        'avatar': null,
        'department': 'Sosyal Aktivite',
      },
      {
        'id': 'decoy_4',
        'name': 'Servis Koordinasyon',
        'lastMessage': '4 no\'lu İskenderun servisi yol çalışması nedeniyle 5 dk gecikecektir.',
        'time': '07:50',
        'unread': 0,
        'avatar': null,
        'department': 'Ulaşım Hizmetleri',
      },
    ];
  }
}
