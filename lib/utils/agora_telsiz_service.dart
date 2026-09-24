import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:agora_token_generator/agora_token_generator.dart';
import 'package:record/record.dart';

class AgoraTelsizService {
  static final AgoraTelsizService _instance = AgoraTelsizService._internal();
  factory AgoraTelsizService() => _instance;
  AgoraTelsizService._internal();

  // Agora Kimlik Bilgileri
  static const String appId = '09c9ccec7dae48f4850dc402a2e9d425';
  static const String appCertificate = '016ffd4bc32749dfbe6dcf1de14be540';

  RtcEngine? _engine;
  bool _isInitialized = false;
  String? _currentChannel;
  int _localUid = 0;
  bool _isLocalTalking = false;
  bool _isJoining = false;
  ConnectionStateType _connectionState = ConnectionStateType.connectionStateDisconnected;

  // Callback Dinleyicileri
  Function(bool isConnected, String? channel)? onConnectionChanged;
  Function(int remoteUid, int volume)? onRemoteSpeakerSpeaking;
  Function()? onRemoteSpeakerStopped;
  Function(int volume, bool isLocal)? onAudioVolumeChanged;
  Function(int remoteUid)? onUserJoined;
  Function(int remoteUid)? onUserOffline;

  Timer? _silenceTimer;
  bool _isRemoteSpeaking = false;

  bool get isInitialized => _isInitialized;
  String? get currentChannel => _currentChannel;
  bool get isLocalTalking => _isLocalTalking;
  int get localUid => _localUid;
  bool get isConnected => _connectionState == ConnectionStateType.connectionStateConnected;

  /// Agora RTC Motorunu Başlat (Communication Modu - Telsiz için En Stabil ve Hızlı Mod)
  Future<bool> init() async {
    if (_isInitialized && _engine != null) return true;

    try {
      // 1. Mikrofon İzni Kontrolü
      try {
        await AudioRecorder().hasPermission();
      } catch (e) {
        debugPrint('[AgoraTelsiz] Mikrofon izin kontrolü: $e');
      }

      // 2. Eski engine varsa önce temizle
      if (_engine != null) {
        try {
          await _engine!.leaveChannel();
          await _engine!.release();
        } catch (_) {}
        _engine = null;
      }

      // 3. Yeni RTC Engine Başlat
      debugPrint('[AgoraTelsiz] Adım 1: createAgoraRtcEngine...');
      _engine = createAgoraRtcEngine();

      debugPrint('[AgoraTelsiz] Adım 2: initialize (appId: $appId)...');
      await _engine!.initialize(const RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileCommunication,
      ));

      _registerEventHandlers();

      debugPrint('[AgoraTelsiz] Adım 3: enableAudio...');
      try {
        await _engine!.enableAudio();
      } catch (e) {
        debugPrint('[AgoraTelsiz] enableAudio atlandı: $e');
      }

      debugPrint('[AgoraTelsiz] Adım 4: setAudioProfile...');
      try {
        await _engine!.setAudioProfile(
          profile: AudioProfileType.audioProfileSpeechStandard,
          scenario: AudioScenarioType.audioScenarioDefault,
        );
      } catch (e) {
        debugPrint('[AgoraTelsiz] setAudioProfile atlandı: $e');
      }

      debugPrint('[AgoraTelsiz] Adım 5: setDefaultAudioRouteToSpeakerphone...');
      try {
        await _engine!.setDefaultAudioRouteToSpeakerphone(true);
      } catch (e) {
        debugPrint('[AgoraTelsiz] setDefaultAudioRouteToSpeakerphone atlandı: $e');
      }

      debugPrint('[AgoraTelsiz] Adım 6: enableAudioVolumeIndication...');
      try {
        await _engine!.enableAudioVolumeIndication(
          interval: 200,
          smooth: 3,
          reportVad: true,
        );
      } catch (e) {
        debugPrint('[AgoraTelsiz] enableAudioVolumeIndication atlandı: $e');
      }

      debugPrint('[AgoraTelsiz] Adım 7: setParameters (keep.audiosession)...');
      try {
        await _engine!.setParameters('{"che.audio.keep.audiosession": true}');
      } catch (e) {
        debugPrint('[AgoraTelsiz] setParameters atlandı: $e');
      }

      // Adım 8: Askeri Telsiz Taktik Bandpass Ekolayzır (300 Hz - 3000 Hz)
      // Düşük frekans uğultularını ve yüksek frekans cızırtılarını keser,
      // 1kHz - 2kHz vokal telsiz bandını öne çıkarır.
      try {
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand31, bandGain: -15);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand62, bandGain: -15);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand125, bandGain: -10);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand250, bandGain: -4);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand500, bandGain: 3);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand1k, bandGain: 6);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand2k, bandGain: 5);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand4k, bandGain: -8);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand8k, bandGain: -15);
        await _engine!.setLocalVoiceEqualization(bandFrequency: AudioEqualizationBandFrequency.audioEqualizationBand16k, bandGain: -15);
        debugPrint('[AgoraTelsiz] Askeri Taktik Bandpass Ekolayzır Aktif.');
      } catch (e) {
        debugPrint('[AgoraTelsiz] Voice equalization atlandı: $e');
      }

      _isInitialized = true;
      debugPrint('[AgoraTelsiz] Başarıyla başlatıldı (Communication Profili).');
      return true;
    } catch (e, stack) {
      debugPrint('[AgoraTelsiz] Başlatma kritik hata: $e\n$stack');
      _isInitialized = false;
      return false;
    }
  }

  void _registerEventHandlers() {
    if (_engine == null) return;

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
          debugPrint('[AgoraTelsiz] Bağlantı Durumu: $state (Sebep: $reason)');
          _connectionState = state;
          if (state == ConnectionStateType.connectionStateConnected) {
            _currentChannel = connection.channelId;
            _isJoining = false;
            onConnectionChanged?.call(true, _currentChannel);
            // Kanala ilk bağlanınca varsayılan olarak mikrofonu sessize al
            _engine?.muteLocalAudioStream(true);
          } else if (state == ConnectionStateType.connectionStateDisconnected || state == ConnectionStateType.connectionStateFailed) {
            _currentChannel = null;
            _isJoining = false;
            onConnectionChanged?.call(false, null);
          }
        },
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint('[AgoraTelsiz] Kanala Başarıyla Katıldı: ${connection.channelId}');
          _currentChannel = connection.channelId;
          _isJoining = false;
          onConnectionChanged?.call(true, _currentChannel);
          _engine?.muteLocalAudioStream(true);
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          debugPrint('[AgoraTelsiz] Kanaldan Ayrıldı: ${connection.channelId}');
          _currentChannel = null;
          _isJoining = false;
          onConnectionChanged?.call(false, null);
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint('[AgoraTelsiz] Yeni Kullanıcı Geldi: $remoteUid');
          onUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          debugPrint('[AgoraTelsiz] Kullanıcı Ayrıldı: $remoteUid');
          onUserOffline?.call(remoteUid);
        },
        onAudioVolumeIndication: (RtcConnection connection, List<AudioVolumeInfo> speakers, int totalVolume, int speakerNumber) {
          AudioVolumeInfo? activeRemoteSpeaker;
          int localVol = 0;

          for (var speaker in speakers) {
            final uid = speaker.uid ?? 0;
            final vol = speaker.volume ?? 0;
            if (uid == 0 || uid == _localUid) {
              localVol = vol;
            } else if (vol > 4) {
              activeRemoteSpeaker = speaker;
            }
          }

          if (_isLocalTalking) {
            onAudioVolumeChanged?.call(localVol, true);
          } else if (activeRemoteSpeaker != null) {
            onAudioVolumeChanged?.call(activeRemoteSpeaker.volume ?? 0, false);
          } else {
            onAudioVolumeChanged?.call(0, false);
          }

          if (activeRemoteSpeaker != null) {
            _silenceTimer?.cancel();
            _isRemoteSpeaking = true;
            onRemoteSpeakerSpeaking?.call(activeRemoteSpeaker.uid ?? 0, activeRemoteSpeaker.volume ?? 0);
          } else if (_isRemoteSpeaking) {
            _silenceTimer?.cancel();
            _silenceTimer = Timer(const Duration(milliseconds: 600), () {
              _isRemoteSpeaking = false;
              onRemoteSpeakerStopped?.call();
            });
          }
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint('[AgoraTelsiz HATA]: $err - $msg');
          if (err == ErrorCodeType.errJoinChannelRejected) {
            _isJoining = false;
          }
        },
      ),
    );
  }

  /// Belirtilen telsiz frekans kanalına bağlan
  Future<void> joinRadioChannel({required String channelCode, required String userId}) async {
    final formattedChannel = 'isdemir_radio_$channelCode';

    // Eğer zaten bu kanala bağlıysak tekrar bağlanma isteği atma
    if (_connectionState == ConnectionStateType.connectionStateConnected && _currentChannel == formattedChannel) {
      debugPrint('[AgoraTelsiz] Zaten bu kanala bağlı: $formattedChannel');
      onConnectionChanged?.call(true, _currentChannel);
      return;
    }

    if (_isJoining) {
      debugPrint('[AgoraTelsiz] Zaten bir kanala bağlanma işlemi devam ediyor, bekleniyor...');
      return;
    }
    _isJoining = true;

    if (!_isInitialized || _engine == null) {
      final success = await init();
      if (!success) {
        _isJoining = false;
        return;
      }
    }

    _localUid = (userId.hashCode.abs() % 900000000) + 100000;

    // Kanal Token'ını dinamik üret
    String token = '';
    try {
      token = RtcTokenBuilder.buildTokenWithUid(
        appId: appId,
        appCertificate: appCertificate,
        channelName: formattedChannel,
        uid: _localUid,
        tokenExpireSeconds: 86400, // 24 saat geçerli
      );
    } catch (e) {
      debugPrint('[AgoraTelsiz] Token üretim hatası: $e');
    }

    try {
      // Eğer başka kanaldaysak önce ayrıl
      if (_connectionState != ConnectionStateType.connectionStateDisconnected) {
        await _engine?.leaveChannel();
        await Future.delayed(const Duration(milliseconds: 150));
      }

      debugPrint('[AgoraTelsiz] joinChannel çağrılıyor: $formattedChannel, uid: $_localUid, tokenVar: ${token.isNotEmpty}');
      await _engine?.joinChannel(
        token: token,
        channelId: formattedChannel,
        uid: _localUid,
        options: const ChannelMediaOptions(
          autoSubscribeAudio: true,
          publishMicrophoneTrack: true, // Track aktif ama başlangıçta muted
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
        ),
      );
      debugPrint('[AgoraTelsiz] joinChannel çağrısı gönderildi.');
      try {
        await _engine?.muteLocalAudioStream(true);
      } catch (_) {}
    } catch (e) {
      _isJoining = false;
      debugPrint('[AgoraTelsiz] Kanala katılma hatası: $e');
    }
  }

  /// Mandalı Bas: Mikrofonu canlı yayına aç (Sıfır gecikmeli ses akışı)
  Future<void> startTalking() async {
    if (_engine == null || _isLocalTalking) return;
    _isLocalTalking = true;
    try {
      await _engine!.muteLocalAudioStream(false);
      debugPrint('[AgoraTelsiz] Mandal BASILDI: Mikrofon AÇIK.');
    } catch (e) {
      debugPrint('[AgoraTelsiz] startTalking hatası: $e');
    }
  }

  /// Mandalı Bırak: Mikrofonu anında sustur
  Future<void> stopTalking() async {
    if (_engine == null || !_isLocalTalking) return;
    _isLocalTalking = false;
    try {
      await _engine!.muteLocalAudioStream(true);
      debugPrint('[AgoraTelsiz] Mandal BIRAKILDI: Mikrofon SESSİZ.');
    } catch (e) {
      debugPrint('[AgoraTelsiz] stopTalking hatası: $e');
    }
  }

  /// Kanaldan Ayrıl
  Future<void> leaveChannel() async {
    try {
      _silenceTimer?.cancel();
      _isJoining = false;
      _connectionState = ConnectionStateType.connectionStateDisconnected;
      await _engine?.muteLocalAudioStream(true);
      await _engine?.leaveChannel();
      _currentChannel = null;
      _isLocalTalking = false;
    } catch (e) {
      debugPrint('[AgoraTelsiz] leaveChannel hatası: $e');
    }
  }

  /// Servisi Kapat
  Future<void> dispose() async {
    try {
      _silenceTimer?.cancel();
      _isJoining = false;
      await _engine?.leaveChannel();
      await _engine?.release();
      _engine = null;
      _isInitialized = false;
      _currentChannel = null;
      _connectionState = ConnectionStateType.connectionStateDisconnected;
    } catch (e) {
      debugPrint('[AgoraTelsiz] dispose hatası: $e');
    }
  }
}
