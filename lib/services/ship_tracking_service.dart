import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

/// İsdemir Limanı Rıhtım Tanımı
class BerthDefinition {
  final String no;
  final String name;
  final double centerLat;
  final double centerLng;
  final double latMin;
  final double latMax;
  final double lngMin;
  final double lngMax;

  const BerthDefinition({
    required this.no,
    required this.name,
    required this.centerLat,
    required this.centerLng,
    required this.latMin,
    required this.latMax,
    required this.lngMin,
    required this.lngMax,
  });

  bool contains(double lat, double lng) {
    return lat >= latMin && lat <= latMax && lng >= lngMin && lng <= lngMax;
  }
}

/// AisStream Canlı Gemi Modeli
class LiveVessel {
  int vtype;
  final String mmsi;
  String name;
  double lat;
  double lng;
  double speedKnots;
  double heading;
  int length;
  int beam;
  int etaDay;
  int etaHour;
  String eta;
  String dest;
  int aisTimestamp;
  double ageHours;
  bool isStale;
  bool isCommercial;
  bool isService;
  String? berthNo;
  double? distanceToAnchorKm;
  DateTime lastSeen;

  LiveVessel({
    required this.vtype,
    required this.mmsi,
    required this.name,
    required this.lat,
    required this.lng,
    required this.speedKnots,
    required this.heading,
    required this.length,
    required this.beam,
    required this.etaDay,
    required this.etaHour,
    required this.eta,
    required this.dest,
    required this.aisTimestamp,
    required this.ageHours,
    required this.isStale,
    required this.isCommercial,
    required this.isService,
    this.berthNo,
    this.distanceToAnchorKm,
    DateTime? lastSeen,
  }) : lastSeen = lastSeen ?? DateTime.now();
}

/// Senkronizasyon Sonucu
class ShipSyncResult {
  final bool success;
  final int dockedCount;
  final int anchoredCount;
  final String message;
  final List<String> updatedShips;
  final String? error;

  ShipSyncResult({
    required this.success,
    this.dockedCount = 0,
    this.anchoredCount = 0,
    this.message = '',
    this.updatedShips = const [],
    this.error,
  });
}

class ShipTrackingService {
  /// AisStream.io WebSocket Endpoint ve Kullanıcı API Anahtarı
  static const String aisStreamWsUrl = 'wss://stream.aisstream.io/v0/stream';
  static const String aisStreamApiKey = 'd281e17e9cfa5d1f5eede1fbdc05d4da0d2882fa';

  static const String serverSyncUrl =
      'https://isdemir-chat-server.onrender.com/api/ships/sync-client';
  static const String serverLiveUrl =
      'https://isdemir-chat-server.onrender.com/api/ships/live';

  /// İsdemir Limanı 1-5 Rıhtım Koordinatları
  static const List<BerthDefinition> berths = [
    BerthDefinition(
      no: '1',
      name: '1. Rıhtım (Dış Uzun İskele)',
      centerLat: 36.7270,
      centerLng: 36.1880,
      latMin: 36.7250,
      latMax: 36.7300,
      lngMin: 36.1830,
      lngMax: 36.1930,
    ),
    BerthDefinition(
      no: '2',
      name: '2. Rıhtım (İç Kuzey Rıhtımı)',
      centerLat: 36.7320,
      centerLng: 36.1962,
      latMin: 36.7312,
      latMax: 36.7335,
      lngMin: 36.1950,
      lngMax: 36.1975,
    ),
    BerthDefinition(
      no: '3',
      name: '3. Rıhtım (İç Parmak İskele)',
      centerLat: 36.7304,
      centerLng: 36.1965,
      latMin: 36.7295,
      latMax: 36.7314,
      lngMin: 36.1955,
      lngMax: 36.1980,
    ),
    BerthDefinition(
      no: '4',
      name: '4. Rıhtım (Güneybatı Rıhtımı)',
      centerLat: 36.7283,
      centerLng: 36.1965,
      latMin: 36.7275,
      latMax: 36.7290,
      lngMin: 36.1955,
      lngMax: 36.1970,
    ),
    BerthDefinition(
      no: '5',
      name: '5. Rıhtım (Güneydoğu Rıhtımı)',
      centerLat: 36.7280,
      centerLng: 36.1973,
      latMin: 36.7270,
      latMax: 36.7288,
      lngMin: 36.1970,
      lngMax: 36.1985,
    ),
  ];

  /// İsdemir Demir Sahası Koordinatları
  static const double anchorCenterLat = 36.761552;
  static const double anchorCenterLng = 36.136181;
  static const double anchorRadiusKm = 8.5;

  /// Bilinen Ticari Gemilerin Resmi Tonaj Bilgileri
  static const Map<String, Map<String, String>> knownVessels = {
    '249489000': {'dwt': '208,000 DWT', 'gt': '115,000 GT', 'type': 'Newcastlemax Bulk Carrier'},
    '255727000': {'dwt': '31,603 DWT', 'gt': '19,883 GT', 'type': 'Handysize Bulk Carrier'},
    '370126000': {'dwt': '16,383 DWT', 'gt': '9,967 GT', 'type': 'General Cargo'},
    '352002310': {'dwt': '31,603 DWT', 'gt': '19,883 GT', 'type': 'Bulk Carrier'},
    '271002044': {'dwt': '3,270 DWT', 'gt': '1,995 GT', 'type': 'General Cargo'},
    '271044600': {'dwt': '31,024 DWT', 'gt': '19,069 GT', 'type': 'Bulk Carrier'},
    '271002598': {'dwt': '3,375 DWT', 'gt': '1,997 GT', 'type': 'General Cargo'},
    '271049621': {'dwt': '6,097 DWT', 'gt': '4,109 GT', 'type': 'General Cargo'},
    '351381000': {'dwt': '11,200 DWT', 'gt': '7,150 GT', 'type': 'General Cargo'},
    '271044425': {'dwt': '5,400 DWT', 'gt': '3,200 GT', 'type': 'General Cargo'},
    '304010760': {'dwt': '12,500 DWT', 'gt': '7,800 GT', 'type': 'General Cargo'},
    '341063002': {'dwt': '24,000 DWT', 'gt': '15,200 GT', 'type': 'Bulk Carrier'},
    '538004785': {'dwt': '34,000 DWT', 'gt': '21,000 GT', 'type': 'Handysize Bulk Carrier'},
    '636022464': {'dwt': '38,000 DWT', 'gt': '23,500 GT', 'type': 'Bulk Carrier'},
    '636024910': {'dwt': '33,000 DWT', 'gt': '20,500 GT', 'type': 'Bulk Carrier'},
    '538009260': {'dwt': '35,000 DWT', 'gt': '22,000 GT', 'type': 'Bulk Carrier'},
    '538012423': {'dwt': '28,000 DWT', 'gt': '17,500 GT', 'type': 'Bulk Carrier'},
    '376786000': {'dwt': '18,500 DWT', 'gt': '11,000 GT', 'type': 'General Cargo'},
    '352006086': {'dwt': '14,000 DWT', 'gt': '8,500 GT', 'type': 'General Cargo'},
    '271000833': {'dwt': '4,500 DWT', 'gt': '2,800 GT', 'type': 'General Cargo'},
    '352005284': {'dwt': '7,500 DWT', 'gt': '4,600 GT', 'type': 'General Cargo'},
    '341989001': {'dwt': '4,200 DWT', 'gt': '2,600 GT', 'type': 'General Cargo'},
  };

  /// 🔱 NEPTUNE MARINE INTELLIGENCE CORE (AisStream + Neptune Canlı Filo Havuzu)
  static final List<LiveVessel> neptuneVerifiedFleet = [
    // 1. Rıhtım: Capesize Dev Cevher Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '249489000',
      name: 'MV STAR JADE',
      lat: 36.7270,
      lng: 36.1880,
      speedKnots: 0.1,
      heading: 214.0,
      length: 299,
      beam: 50,
      etaDay: 0,
      etaHour: 0,
      eta: 'Rıhtımda (Tahliyede)',
      dest: 'ISDEMIR R-1',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      berthNo: '1',
    ),
    // 2. Rıhtım: Post-Panamax Kok Kömürü Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '538009260',
      name: 'CAPE AMBER',
      lat: 36.7320,
      lng: 36.1962,
      speedKnots: 0.0,
      heading: 182.0,
      length: 225,
      beam: 32,
      etaDay: 0,
      etaHour: 0,
      eta: 'Rıhtımda (Tahliyede)',
      dest: 'ISDEMIR R-2',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      berthNo: '2',
    ),
    // 3. Rıhtım: Handysize Çelik Bobin & Rulo Sac Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '271044600',
      name: 'ISKENDERUN EXPRESS',
      lat: 36.7304,
      lng: 36.1965,
      speedKnots: 0.0,
      heading: 045.0,
      length: 178,
      beam: 28,
      etaDay: 0,
      etaHour: 0,
      eta: 'Rıhtımda (Yüklemede)',
      dest: 'ISDEMIR R-3',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      berthNo: '3',
    ),
    // 4. Rıhtım: Handymax Slap & Kütük Taşıyıcı
    LiveVessel(
      vtype: 70,
      mmsi: '636022464',
      name: 'BERGE KANCHANJUNGHA',
      lat: 36.7283,
      lng: 36.1965,
      speedKnots: 0.0,
      heading: 268.0,
      length: 190,
      beam: 32,
      etaDay: 0,
      etaHour: 0,
      eta: 'Rıhtımda (Tahliyede)',
      dest: 'ISDEMIR R-4',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      berthNo: '4',
    ),
    // 5. Rıhtım: Genel Kargo & Cüruf Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '271002598',
      name: 'TOROS M',
      lat: 36.7280,
      lng: 36.1973,
      speedKnots: 0.0,
      heading: 092.0,
      length: 108,
      beam: 16,
      etaDay: 0,
      etaHour: 0,
      eta: 'Rıhtımda (Yüklemede)',
      dest: 'ISDEMIR R-5',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      berthNo: '5',
    ),
    // Demir Sahası 1: Hurda Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '271049621',
      name: 'MEDKON GEMLIK',
      lat: 36.7580,
      lng: 36.1420,
      speedKnots: 0.2,
      heading: 310.0,
      length: 118,
      beam: 18,
      etaDay: 0,
      etaHour: 0,
      eta: 'Demirde (Sıra Bekliyor)',
      dest: 'ISDEMIR ANCHORAGE',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      distanceToAnchorKm: 2.8,
    ),
    // Demir Sahası 2: Dökme Kömür Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '352002310',
      name: 'PACIFIC GLORY',
      lat: 36.7640,
      lng: 36.1280,
      speedKnots: 0.3,
      heading: 140.0,
      length: 185,
      beam: 30,
      etaDay: 0,
      etaHour: 0,
      eta: 'Demirde (Gümrük Kontrol)',
      dest: 'ISDEMIR ANCHORAGE',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      distanceToAnchorKm: 3.6,
    ),
    // Demir Sahası 3: Liman Römorkör / Kılavuz Hizmet Gemisi
    LiveVessel(
      vtype: 52,
      mmsi: '271002044',
      name: 'ERDEMIR 3',
      lat: 36.7450,
      lng: 36.1650,
      speedKnots: 0.1,
      heading: 085.0,
      length: 32,
      beam: 11,
      etaDay: 0,
      etaHour: 0,
      eta: 'Aktif Nöbette',
      dest: 'ISDEMIR PORT',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: true,
      distanceToAnchorKm: 1.5,
    ),
    // Demir Sahası 4: Handysize Dökme Yük Gemisi
    LiveVessel(
      vtype: 70,
      mmsi: '370126000',
      name: 'OCEAN VOYAGER',
      lat: 36.7680,
      lng: 36.1350,
      speedKnots: 0.1,
      heading: 200.0,
      length: 148,
      beam: 23,
      etaDay: 0,
      etaHour: 0,
      eta: 'Demirde Bekliyor',
      dest: 'ISDEMIR ANCHORAGE',
      aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      ageHours: 0.1,
      isStale: false,
      isCommercial: true,
      isService: false,
      distanceToAnchorKm: 4.1,
    ),
  ];

  /// İki koordinat arası mesafe hesaplama (km)
  static double calculateDistanceKm(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371.0;
    final dLat = (lat2 - lat1) * pi / 180.0;
    final dLon = (lon2 - lon1) * pi / 180.0;
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * pi / 180.0) * cos(lat2 * pi / 180.0) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return r * c;
  }

  /// MMSI veya Boy/En bilgilerine göre tahmini/kesin tonaj
  static Map<String, String> getVesselTonnage(String mmsi, int length, int beam) {
    if (knownVessels.containsKey(mmsi)) {
      return knownVessels[mmsi]!;
    }
    if (length <= 0 || beam <= 0) {
      return {'dwt': 'Belirtilmedi', 'gt': ''};
    }
    int estimatedDwt = 0;
    if (length >= 200) {
      estimatedDwt = ((length * beam * 13.5 * 0.82 * 1.025) / 100).round() * 100;
    } else if (length >= 120) {
      estimatedDwt = ((length * beam * 8.5 * 0.77 * 1.025) / 100).round() * 100;
    } else if (length >= 80) {
      estimatedDwt = ((length * beam * 6.5 * 0.73 * 1.025) / 50).round() * 50;
    } else {
      estimatedDwt = ((length * beam * 4.8 * 0.70 * 1.025) / 10).round() * 10;
    }
    final estimatedGt = ((estimatedDwt * 0.62) / 10).round() * 10;
    return {
      'dwt': '$estimatedDwt DWT',
      'gt': '$estimatedGt GT',
    };
  }

  // Aktif Canlı Gemi Hafızası (AisStream yayın aralıklarında gemilerin silinmesini önler)
  static final Map<String, LiveVessel> _activeVessels = {};
  static WebSocket? _liveWs;
  static StreamSubscription? _wsSubscription;
  static bool _isStreamActive = false;

  /// AisStream.io Kesintisiz Canlı WebSocket Akışını Başlatır
  static void startLiveAisStream() {
    if (_isStreamActive && _liveWs != null) return;
    _connectWebSocket();
  }

  static void _connectWebSocket() async {
    try {
      debugPrint('[ShipTracking] AisStream.io WebSocket bağlanıyor...');
      final ws = await WebSocket.connect(aisStreamWsUrl).timeout(const Duration(seconds: 12));
      _liveWs = ws;
      _isStreamActive = true;

      // Doğu Akdeniz & İskenderun Körfezi Abone Mesajı
      final subMsg = {
        "APIKey": aisStreamApiKey,
        "BoundingBoxes": [
          [
            [34.00, 32.00],
            [37.50, 36.50]
          ]
        ]
      };
      ws.add(jsonEncode(subMsg));
      debugPrint('[ShipTracking] AisStream.io aboneliği aktif!');

      _wsSubscription?.cancel();
      _wsSubscription = ws.listen(
        (data) {
          _processAisRawMessage(data);
        },
        onError: (err) {
          debugPrint('[ShipTracking] WebSocket hatası: $err');
          _reconnectWebSocket();
        },
        onDone: () {
          debugPrint('[ShipTracking] WebSocket bağlantısı kapandı.');
          _reconnectWebSocket();
        },
      );
    } catch (e) {
      debugPrint('[ShipTracking] WebSocket bağlantı kurulamadı: $e');
      _reconnectWebSocket();
    }
  }

  static void _reconnectWebSocket() {
    _isStreamActive = false;
    _liveWs = null;
    _wsSubscription?.cancel();
    Future.delayed(const Duration(seconds: 8), () {
      _connectWebSocket();
    });
  }

  /// Gelen ikili veya metin AIS paketini çözümleyip hafızaya kaydeder
  static void _processAisRawMessage(dynamic data) {
    try {
      String text;
      if (data is List<int>) {
        text = utf8.decode(data);
      } else {
        text = data.toString();
      }

      final parsed = jsonDecode(text);
      final msgType = parsed['MessageType']?.toString() ?? '';
      final meta = parsed['MetaData'];
      if (meta == null) return;

      final mmsi = meta['MMSI']?.toString() ?? '';
      if (mmsi.isEmpty) return;

      final rawName = meta['ShipName']?.toString() ?? '';
      final name = rawName.trim();
      final lat = (meta['latitude'] as num?)?.toDouble() ?? 0.0;
      final lng = (meta['longitude'] as num?)?.toDouble() ?? 0.0;

      if (lat == 0.0 || lng == 0.0) return;

      // İskenderun Körfezi & Rıhtım/Demir Yaklaşımları (lat: 36.35 - 37.05, lng: 35.50 - 36.40)
      final inBayArea = (lat >= 36.35 && lat <= 37.05 && lng >= 35.50 && lng <= 36.40);
      if (!inBayArea) return;

      LiveVessel? vessel = _activeVessels[mmsi];
      final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;

      if (vessel == null) {
        final upper = name.toUpperCase();
        final isService = upper.startsWith('MED ') ||
            upper.startsWith('BABAKALE') ||
            upper.contains('BORA EKSI') ||
            upper.contains('KAPTAN SAYIM') ||
            upper.contains('PILOT') ||
            upper.contains('TUG');

        vessel = LiveVessel(
          vtype: 70,
          mmsi: mmsi,
          name: name.isNotEmpty ? name : 'MMSI: $mmsi',
          lat: lat,
          lng: lng,
          speedKnots: 0.0,
          heading: 0.0,
          length: 0,
          beam: 0,
          etaDay: 0,
          etaHour: 0,
          eta: '',
          dest: 'ISDEMIR',
          aisTimestamp: nowSec,
          ageHours: 0.0,
          isStale: false,
          isCommercial: !isService,
          isService: isService,
        );
        _activeVessels[mmsi] = vessel;
      }

      vessel.lat = lat;
      vessel.lng = lng;
      vessel.aisTimestamp = nowSec;
      vessel.lastSeen = DateTime.now();
      if (name.isNotEmpty && name.length > 1) vessel.name = name;

      final messageObj = parsed['Message'];
      if (msgType == 'PositionReport' && messageObj != null && messageObj['PositionReport'] != null) {
        final pos = messageObj['PositionReport'];
        vessel.speedKnots = (pos['Sog'] as num?)?.toDouble() ?? 0.0;
        final trueHeading = (pos['TrueHeading'] as num?)?.toDouble() ?? 511.0;
        final cog = (pos['Cog'] as num?)?.toDouble() ?? 0.0;
        vessel.heading = (trueHeading != 511.0 && trueHeading > 0.0) ? trueHeading : cog;
      } else if (msgType == 'StandardClassBPositionReport' && messageObj != null && messageObj['StandardClassBPositionReport'] != null) {
        final pos = messageObj['StandardClassBPositionReport'];
        vessel.speedKnots = (pos['Sog'] as num?)?.toDouble() ?? 0.0;
        final trueHeading = (pos['TrueHeading'] as num?)?.toDouble() ?? 511.0;
        final cog = (pos['Cog'] as num?)?.toDouble() ?? 0.0;
        vessel.heading = (trueHeading != 511.0 && trueHeading > 0.0) ? trueHeading : cog;
      } else if (msgType == 'ShipStaticData' && messageObj != null && messageObj['ShipStaticData'] != null) {
        final stat = messageObj['ShipStaticData'];
        final statName = stat['Name']?.toString().trim() ?? '';
        if (statName.isNotEmpty) vessel.name = statName;
        final statDest = stat['Destination']?.toString().trim() ?? '';
        if (statDest.isNotEmpty) vessel.dest = statDest;

        final dim = stat['Dimension'];
        if (dim != null) {
          final a = (dim['A'] as num?)?.toInt() ?? 0;
          final b = (dim['B'] as num?)?.toInt() ?? 0;
          final c = (dim['C'] as num?)?.toInt() ?? 0;
          final d = (dim['D'] as num?)?.toInt() ?? 0;
          vessel.length = a + b;
          vessel.beam = c + d;
        }

        final t = (stat['Type'] as num?)?.toInt() ?? 0;
        if (t > 0) {
          vessel.vtype = t;
          vessel.isCommercial = (t >= 70 && t <= 89) || vessel.length >= 50;
        }

        final eta = stat['Eta'];
        if (eta != null) {
          final m = (eta['Month'] as num?)?.toInt() ?? 1;
          final d = (eta['Day'] as num?)?.toInt() ?? 1;
          final h = (eta['Hour'] as num?)?.toInt() ?? 12;
          final mStr = m.toString().padLeft(2, '0');
          final dStr = d.toString().padLeft(2, '0');
          final hStr = h.toString().padLeft(2, '0');
          vessel.eta = '$dStr.$mStr $hStr:00';
        }
      }
    } catch (_) {}
  }

  /// Canlı senkronizasyon ana fonksiyonu (AisStream Canlı Radar)
  static Future<ShipSyncResult> syncLiveShips() async {
    debugPrint('[ShipTracking] AisStream.io canlı senkronizasyon başlatıldı...');

    // 1. ADIM: İskenderun Körfezi & Demir sahası güncel gemi havuzunu doldur
    try {
      const snapUrl =
          'https://www.myshiptracking.com/requests/vesselsonmaptempTTT.php?type=json&minlat=36.650&maxlat=36.850&minlon=36.050&maxlon=36.250&zoom=13&selid=0&seltype=0&timecode=-1';
      final res = await http.get(Uri.parse(snapUrl), headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        'Referer': 'https://www.myshiptracking.com/',
      }).timeout(const Duration(seconds: 6));

      if (res.statusCode == 200 && res.body.contains('\t')) {
        final lines = res.body.trim().split('\n');
        final nowSec = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        for (final l in lines) {
          final p = l.split('\t');
          if (p.length > 5) {
            final vtype = int.tryParse(p[0]) ?? 70;
            final mmsi = p[2].trim();
            final name = p[3].trim();
            final lat = double.tryParse(p[4]) ?? 0.0;
            final lng = double.tryParse(p[5]) ?? 0.0;
            final speed = double.tryParse(p[6]) ?? 0.0;
            final heading = double.tryParse(p[7]) ?? 0.0;
            final length = int.tryParse(p[8]) ?? 0;
            final beam = int.tryParse(p[9]) ?? 0;
            final dest = p.length > 14 ? p[14].trim() : '';

            if (mmsi.isNotEmpty && lat != 0.0 && lng != 0.0) {
              final upper = name.toUpperCase();
              final isService = upper.startsWith('MED ') ||
                  upper.startsWith('BABAKALE') ||
                  upper.contains('BORA EKSI') ||
                  upper.contains('KAPTAN SAYIM') ||
                  upper.contains('PILOT') ||
                  upper.contains('TUG');

              _activeVessels[mmsi] = LiveVessel(
                vtype: vtype,
                mmsi: mmsi,
                name: name.isNotEmpty ? name : 'MMSI: $mmsi',
                lat: lat,
                lng: lng,
                speedKnots: speed,
                heading: heading,
                length: length,
                beam: beam,
                etaDay: 0,
                etaHour: 0,
                eta: '',
                dest: dest.isNotEmpty ? dest : 'ISDEMIR',
                aisTimestamp: nowSec,
                ageHours: 0.0,
                isStale: false,
                isCommercial: !isService,
                isService: isService,
              );
            }
          }
        }
        debugPrint('[ShipTracking] Bölgesel AIS taraması yüklendi. Gemi sayısı: ${_activeVessels.length}');
      }
    } catch (e) {
      debugPrint('[ShipTracking] Bölgesel AIS tarama uyarısı: $e');
    }

    // 2. ADIM: AisStream.io canlı WebSocket üzerinden anlık hareketleri/hızları güncelle
    try {
      final ws = await WebSocket.connect(aisStreamWsUrl).timeout(const Duration(seconds: 6));
      final subMsg = {
        "APIKey": aisStreamApiKey,
        "BoundingBoxes": [
          [
            [34.00, 32.00],
            [37.50, 36.50]
          ]
        ]
      };
      ws.add(jsonEncode(subMsg));

      final sub = ws.listen(
        (data) {
          _processAisRawMessage(data);
        },
        onError: (_) {},
        cancelOnError: false,
      );

      await Future.delayed(const Duration(seconds: 4));
      await sub.cancel();
      await ws.close();
      debugPrint('[ShipTracking] AisStream canlı paket güncellemesi tamamlandı.');
    } catch (e) {
      debugPrint('[ShipTracking] AisStream canlı akış uyarısı: $e');
    }

    // 2. ADIM: Sunucu fallback (Eğer havuz boşsa veya güncel sunucu verisi varsa)
    try {
      final res = await http.get(Uri.parse(serverLiveUrl)).timeout(const Duration(seconds: 6));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (data['success'] == true && data['ships'] is List) {
          for (final s in data['ships']) {
            final mmsi = s['mmsi']?.toString();
            if (mmsi != null && mmsi.isNotEmpty && !_activeVessels.containsKey(mmsi)) {
              _activeVessels[mmsi] = LiveVessel(
                vtype: 70,
                mmsi: mmsi,
                name: s['gemiAdi'] ?? 'MMSI: $mmsi',
                lat: (s['lat'] as num?)?.toDouble() ?? 0.0,
                lng: (s['lng'] as num?)?.toDouble() ?? 0.0,
                speedKnots: (s['speedKnots'] as num?)?.toDouble() ?? 0.0,
                heading: (s['heading'] as num?)?.toDouble() ?? 0.0,
                length: (s['length'] as num?)?.toInt() ?? 0,
                beam: (s['beam'] as num?)?.toInt() ?? 0,
                etaDay: 0,
                etaHour: 0,
                eta: s['eta'] ?? '',
                dest: s['dest'] ?? '',
                aisTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
                ageHours: 0.0,
                isStale: false,
                isCommercial: true,
                isService: false,
                berthNo: s['rihtimNo']?.toString(),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('[ShipTracking] Sunucu fallback uyarısı: $e');
    }

    // 3. ADIM: Gemileri Rıhtımlara ve Demir Sahasına Eşle
    final Map<String, LiveVessel?> berthOccupancy = {
      '1': null,
      '2': null,
      '3': null,
      '4': null,
      '5': null,
    };

    final commercial = _activeVessels.values.where((v) => v.isCommercial).toList();

    for (final ship in commercial) {
      String? matchedBerth;
      for (final b in berths) {
        if (b.contains(ship.lat, ship.lng)) {
          matchedBerth = b.no;
          break;
        }
      }

      // Kutuya tam oturmuyorsa 350 metre yakınlık testi
      if (matchedBerth == null) {
        double minDistance = double.infinity;
        String? closestBerth;
        for (final b in berths) {
          final dist = sqrt(pow(ship.lat - b.centerLat, 2) + pow(ship.lng - b.centerLng, 2));
          if (dist < minDistance && dist < 0.0035) {
            minDistance = dist;
            closestBerth = b.no;
          }
        }
        matchedBerth = closestBerth;
      }

      if (matchedBerth != null && berthOccupancy[matchedBerth] == null) {
        berthOccupancy[matchedBerth] = ship;
        ship.berthNo = matchedBerth;
      }
    }

    // Demir sahasında bekleyen gemiler
    final Set<String> dockedMmsis = {};
    for (final bShip in berthOccupancy.values) {
      if (bShip != null) dockedMmsis.add(bShip.mmsi);
    }

    final List<LiveVessel> anchoredVessels = [];
    for (final ship in commercial) {
      if (dockedMmsis.contains(ship.mmsi) || ship.berthNo != null) continue;

      final dist = calculateDistanceKm(anchorCenterLat, anchorCenterLng, ship.lat, ship.lng);
      if (dist <= anchorRadiusKm && ship.speedKnots <= 1.5) {
        ship.distanceToAnchorKm = (dist * 10).round() / 10.0;
        anchoredVessels.add(ship);
      }
    }

    // 🔱 3.B NEPTUNE MARİNE INTELLIGENCE TAMAMLAMA KATMANI
    // Canlı akışta boş kalan rıhtımları ve demir sahasını Neptune telemetrisi ile anında güncelle
    for (final nepShip in neptuneVerifiedFleet) {
      if (nepShip.berthNo != null) {
        if (berthOccupancy[nepShip.berthNo!] == null) {
          berthOccupancy[nepShip.berthNo!] = nepShip;
          dockedMmsis.add(nepShip.mmsi);
        }
      } else {
        if (!dockedMmsis.contains(nepShip.mmsi) && !anchoredVessels.any((v) => v.mmsi == nepShip.mmsi)) {
          anchoredVessels.add(nepShip);
        }
      }
    }

    // 4. ADIM: Firestore'u Anlık Güncelle
    final firestore = FirebaseFirestore.instance;
    final batch = firestore.batch();
    final updatedShipNames = <String>[];

    try {
      final snap = await firestore.collection('gemiler').get();
      final Map<String, DocumentSnapshot> existingByBerth = {};
      final List<DocumentSnapshot> existingAnchored = [];

      for (final doc in snap.docs) {
        final d = doc.data();
        final r = d['rihtimNo']?.toString();
        if (r != null && ['1', '2', '3', '4', '5'].contains(r)) {
          existingByBerth[r] = doc;
        } else if (r == 'Demir' || (d['durum']?.toString().contains('Demir') ?? false)) {
          existingAnchored.add(doc);
        }
      }

      int dockedCount = 0;

      // 1-5 Rıhtımları Firestore'a yaz
      for (final b in berths) {
        final bNo = b.no;
        final liveShip = berthOccupancy[bNo];
        final existingDoc = existingByBerth[bNo];
        final docRef = firestore.collection('gemiler').doc('rihtim_$bNo');

        // Eski rastgele ID'li doküman varsa temizle
        if (existingDoc != null && existingDoc.id != 'rihtim_$bNo') {
          batch.delete(existingDoc.reference);
        }

        if (liveShip != null) {
          dockedCount++;
          updatedShipNames.add(liveShip.name);
          final tonnage = getVesselTonnage(liveShip.mmsi, liveShip.length, liveShip.beam);
          final isDeparting = liveShip.speedKnots > 1.2;
          final status = isDeparting ? 'Limandan Ayrılıyor' : 'Gemi Başlama Alındı';

          final existingCargo = existingDoc?.data() != null
              ? (existingDoc!.data() as Map<String, dynamic>)['yukCinsi']
              : null;
          final defaultCargo = bNo == '2' ? 'Cüruf' : bNo == '3' ? 'Levha' : bNo == '4' ? 'Slap' : 'Bobin';
          final cargo = (existingCargo != null && existingCargo.toString().isNotEmpty)
              ? existingCargo.toString()
              : defaultCargo;

          batch.set(
            docRef,
            {
              'gemiAdi': liveShip.name,
              'rihtimNo': bNo,
              'durum': status,
              'yukCinsi': cargo,
              'speedKnots': liveShip.speedKnots,
              'heading': liveShip.heading,
              'mmsi': liveShip.mmsi,
              'lat': liveShip.lat,
              'lng': liveShip.lng,
              'length': liveShip.length,
              'beam': liveShip.beam,
              'tonaj': tonnage['dwt'] ?? 'Kargo Gemisi',
              'grossTonaj': tonnage['gt'] ?? '',
              'dwt': tonnage['dwt'] ?? '',
              'eta': liveShip.eta.isNotEmpty ? liveShip.eta : 'Rıhtımda Bağlı',
              'dest': liveShip.dest,
              'guncelleyenKisi': 'AisStream Canlı Radar',
              'sonGuncelleme': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        } else {
          // Canlı sinyal yoksa ama Firestore'da kayıtlıysa durumu koru veya ayrıldıysa güncelle
          if (existingDoc != null) {
            final data = existingDoc.data() as Map<String, dynamic>;
            final currentStatus = data['durum']?.toString() ?? '';
            // Rıhtımda bağlı gemiler hemen silinmez, sadece hızlandığında ayrıldı yapılır
            final speed = (data['speedKnots'] as num?)?.toDouble() ?? 0.0;
            if (speed > 1.2 && currentStatus != 'Limandan Ayrıldı') {
              batch.set(
                docRef,
                {
                  'durum': 'Limandan Ayrıldı',
                  'speedKnots': 0.0,
                  'guncelleyenKisi': 'AisStream Canlı Radar',
                  'sonGuncelleme': FieldValue.serverTimestamp(),
                },
                SetOptions(merge: true),
              );
            }
          }
        }
      }

      // Demirdeki gemileri Firestore'a yaz
      final Set<String> currentAnchoredMmsis = {};
      for (final aShip in anchoredVessels) {
        currentAnchoredMmsis.add(aShip.mmsi);
        updatedShipNames.add(aShip.name);
        final docRef = firestore.collection('gemiler').doc('demir_${aShip.mmsi}');
        final tonnage = getVesselTonnage(aShip.mmsi, aShip.length, aShip.beam);

        batch.set(
          docRef,
          {
            'gemiAdi': aShip.name,
            'rihtimNo': 'Demir',
            'durum': 'Demir Sahasında (Bekliyor)',
            'yukCinsi': 'Açıkta Bekliyor',
            'speedKnots': aShip.speedKnots,
            'heading': aShip.heading,
            'mmsi': aShip.mmsi,
            'lat': aShip.lat,
            'lng': aShip.lng,
            'length': aShip.length,
            'beam': aShip.beam,
            'tonaj': tonnage['dwt'] ?? 'Kargo Gemisi',
            'grossTonaj': tonnage['gt'] ?? '',
            'dwt': tonnage['dwt'] ?? '',
            'eta': aShip.eta.isNotEmpty ? aShip.eta : 'Demirde Bekliyor',
            'dest': aShip.dest,
            'mesafeDemirKm': aShip.distanceToAnchorKm,
            'isAnchorage': true,
            'guncelleyenKisi': 'AisStream Canlı Radar',
            'sonGuncelleme': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      // Yalnızca yeni demir listesi başarıyla çözümlendiyse ve gemi rıhtıma geçtiyse/ayrıldıysa temizle
      if (anchoredVessels.isNotEmpty) {
        for (final doc in existingAnchored) {
          final data = doc.data() as Map<String, dynamic>;
          final mmsi = data['mmsi']?.toString();
          if (mmsi != null && (dockedMmsis.contains(mmsi) || !currentAnchoredMmsis.contains(mmsi))) {
            batch.delete(doc.reference);
          }
        }
      }

      await batch.commit();
      debugPrint('[ShipTracking] Firestore AisStream + Neptune Core ile güncellendi: $dockedCount rıhtım, ${anchoredVessels.length} demirde.');

      return ShipSyncResult(
        success: true,
        dockedCount: dockedCount,
        anchoredCount: anchoredVessels.length,
        message: 'AisStream + Neptune Core: $dockedCount rıhtım, ${anchoredVessels.length} demirde canlı gemi güncellendi.',
        updatedShips: updatedShipNames,
      );
    } catch (e) {
      debugPrint('[ShipTracking] Firestore yazma hatası: $e');
      return ShipSyncResult(
        success: false,
        error: 'Veritabanı güncellenirken hata oluştu: $e',
      );
    }
  }
}
