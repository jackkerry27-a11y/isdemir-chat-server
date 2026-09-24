import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:avatar_glow/avatar_glow.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';
import '../utils/radio_sound_effects.dart';
import '../utils/agora_telsiz_service.dart';
import '../utils/radio_background_service.dart';
import '../utils/push_service.dart';
import '../widgets/vip_gate.dart';

class TelsizScreen extends StatefulWidget {
  final UserModel user;
  final String? initialChannel;

  const TelsizScreen({super.key, required this.user, this.initialChannel});

  @override
  State<TelsizScreen> createState() => _TelsizScreenState();
}

class _TelsizScreenState extends State<TelsizScreen> with TickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final AgoraTelsizService _agoraService = AgoraTelsizService();
  final Map<int, String> _speakerNames = {};
  bool _isAgoraConnected = false;

  String _currentChannel = '1';
  bool _isTransmitting = false; // Kullanıcı basıp konuşuyor mu?
  bool _isReceiving = false; // Biri şu an telsizden konuşuyor mu?
  bool _isToggleMode = false; // true = Dokun-Konuş, false = Basılı Tut (PTT)
  String? _currentTalkerName; // Konuşan kişinin adı
  List<dynamic> _activeRadioUsers = [];

  // Ses Spektrumu (VU Metre) & Donanımsal Ses Tuşu
  int _liveAudioVolume = 0; // 0 - 255 Agora ses genliği
  bool _isHardwareKeyPttEnabled = true;
  bool _isVolumeKeyPressed = false;

  late AnimationController _pulseController;
  late AnimationController _waveController;
  Timer? _transmitTimer;
  int _transmitSeconds = 0;

  bool _isCheckingVip = true;
  bool _isVip = false;

  // Frekans Kanalları
  final Map<String, Map<String, String>> _channels = {
    '1': {'name': 'İSDEMİR SAHA', 'freq': '148.550 MHz', 'code': 'TAC-1'},
    '2': {'name': 'LİMAN GÜVENLİK', 'freq': '156.800 MHz', 'code': 'VHF-16'},
    '3': {'name': 'RIHTIM & VİNÇ', 'freq': '162.025 MHz', 'code': 'OPS-3'},
  };

  @override
  void initState() {
    super.initState();
    if (widget.initialChannel != null && _channels.containsKey(widget.initialChannel)) {
      _currentChannel = widget.initialChannel!;
    }
    _verifyVipAccess();
    RadioSoundEffects.init();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    // Donanımsal Ses Kısma Tuşunu Telsiz Mandalı (PTT) olarak dinle
    ServicesBinding.instance.keyboard.addHandler(_handleKeyEvent);

    _initSocketListeners();
    _initAgoraService();
    _joinChannel(_currentChannel);
  }

  bool _handleKeyEvent(KeyEvent event) {
    if (!_isHardwareKeyPttEnabled) return false;

    // Ses kısma tuşu (Volume Down) veya Kulaklık PTT butonu
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown ||
        event.logicalKey == LogicalKeyboardKey.headsetHook) {
      if (event is KeyDownEvent) {
        if (!_isVolumeKeyPressed) {
          _isVolumeKeyPressed = true;
          if (!_isTransmitting) {
            _startTalking();
          }
        }
        return true; // Sistem sesini kısmasını engelle
      } else if (event is KeyUpEvent) {
        _isVolumeKeyPressed = false;
        if (_isTransmitting) {
          _stopTalking();
        }
        return true;
      }
    }
    return false;
  }

  Future<void> _verifyVipAccess() async {
    if (widget.user.isVip) {
      _isVip = true;
      _isCheckingVip = false;
      if (mounted) setState(() {});
    }

    final isVip = await VipGate.checkVipStatus(user: widget.user);
    if (mounted) {
      setState(() {
        _isVip = isVip;
        _isCheckingVip = false;
      });
    }
  }

  bool _isPoweringOff = false;

  void _powerOffRadio() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF14181B),
        title: Text('Telsizi Kapat', style: GoogleFonts.orbitron(color: Colors.white, fontSize: 16)),
        content: const Text(
          'Telsiz arka plan dinleme servisini ve frekans bağlantısını tamamen kapatmak istiyor musunuz?',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('İptal')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Telsizi Kapat', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      _isPoweringOff = true;
      await _agoraService.leaveChannel();
      await RadioBackgroundService.stopService();
      _socketService.leaveRadio(userId: widget.user.id, channel: _currentChannel);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Telsiz tamamen kapatıldı.')),
        );
      }
    }
  }

  // --- VIP PERSONEL ÇAĞIR / DAVET ET MODALI ---
  void _showInviteVipDialog() async {
    RadioSoundEffects.playSquelchIn();
    HapticFeedback.mediumImpact();

    final prefs = await SharedPreferences.getInstance();
    final myCihazId = prefs.getString('cihaz_id');

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF14191D),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final channelData = _channels[_currentChannel]!;

        return Container(
          padding: const EdgeInsets.all(20),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
                    ),
                    child: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF59E0B), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VIP PERSONEL ÇAĞIR (İNTİKAL)',
                          style: GoogleFonts.orbitron(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1,
                          ),
                        ),
                        Text(
                          'Kanal: ${channelData['name']} (${channelData['freq']})',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF00FF66),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.04),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline_rounded, color: Colors.white54, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Sadece VIP personeller telsize davet edilebilir. Çağrılan personelin telefonuna üst bildirim düşer ve dokunduğu anda doğrudan bu frekansa bağlanır.',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('personeller')
                      .where('is_vip', isEqualTo: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Color(0xFF00FF66)),
                      );
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Kayıtlı VIP personel bulunamadı.',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                        ),
                      );
                    }

                    final docs = snapshot.data!.docs.where((d) {
                      final data = d.data() as Map<String, dynamic>;
                      final cId = data['cihaz_id']?.toString();
                      return cId != null && cId.isNotEmpty && cId != myCihazId;
                    }).toList();

                    if (docs.isEmpty) {
                      return Center(
                        child: Text(
                          'Kendinizden başka aktif VIP personel bulunmuyor.',
                          style: GoogleFonts.inter(color: Colors.white54, fontSize: 13),
                        ),
                      );
                    }

                    return ListView.separated(
                      itemCount: docs.length,
                      separatorBuilder: (c, i) => const Divider(color: Colors.white10, height: 1),
                      itemBuilder: (context, index) {
                        final data = docs[index].data() as Map<String, dynamic>;
                        final name = data['ad_soyad'] ?? 'VIP Personel';
                        final meslek = data['meslek'] ?? 'İsdemir Personeli';
                        final targetCihazId = data['cihaz_id']?.toString();

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            child: Text(
                              name.isNotEmpty ? name[0].toUpperCase() : 'V',
                              style: GoogleFonts.orbitron(
                                color: const Color(0xFFFBBF24),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: GoogleFonts.inter(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                                ),
                                child: Text(
                                  'VIP',
                                  style: GoogleFonts.orbitron(
                                    color: const Color(0xFFFBBF24),
                                    fontSize: 8.5,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            meslek,
                            style: GoogleFonts.inter(color: Colors.white54, fontSize: 12),
                          ),
                          trailing: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF00FF66),
                              foregroundColor: Colors.black,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            icon: const Icon(Icons.ring_volume_rounded, size: 14),
                            label: Text(
                              'Çağır',
                              style: GoogleFonts.orbitron(fontSize: 11, fontWeight: FontWeight.bold),
                            ),
                            onPressed: () async {
                              Navigator.pop(ctx);
                              RadioSoundEffects.playTacticalCallAlert();
                              HapticFeedback.heavyImpact();

                              final myName = widget.user.fullName.isNotEmpty
                                  ? widget.user.fullName
                                  : 'Taktik Personel';

                              final messenger = ScaffoldMessenger.of(context);

                              await PushService.sendPushNotification(
                                title: '📻 [TELSİZ ÇAĞRISI] $myName',
                                content: '${channelData['name']} (${channelData['freq']}) frekansında acil telsiz görüşmesi bekleniyor. Konuşmak için dokunun!',
                                targetCihazId: targetCihazId,
                                isVipOnly: true,
                                additionalData: {
                                  'type': 'telsiz_channel',
                                  'channel': _currentChannel,
                                  'inviterName': myName,
                                },
                              );

                              if (mounted) {
                                messenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: const Color(0xFF14191D),
                                    content: Row(
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Color(0xFF00FF66)),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            '$name personeline acil telsiz çağrısı bildirimi gönderildi!',
                                            style: const TextStyle(color: Colors.white),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              }
                            },
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    ServicesBinding.instance.keyboard.removeHandler(_handleKeyEvent);
    _pulseController.dispose();
    _waveController.dispose();
    _transmitTimer?.cancel();
    if (_isPoweringOff) {
      _agoraService.leaveChannel();
      RadioBackgroundService.stopService();
      _socketService.leaveRadio(
        userId: widget.user.id,
        channel: _currentChannel,
      );
      _socketService.onRadioUsersUpdated = null;
      _socketService.onRadioIncomingTalk = null;
      _socketService.onRadioAudioBroadcast = null;
      _socketService.onRadioTalkEnded = null;
    }
    super.dispose();
  }

  void _initSocketListeners() {
    _socketService.onRadioUsersUpdated = (users) {
      for (var u in users) {
        final uidStr = u['userId']?.toString() ?? '';
        final uid = (uidStr.hashCode.abs() % 900000000) + 100000;
        _speakerNames[uid] = u['name'] ?? 'Taktik Personel';
      }
      if (mounted) {
        setState(() {
          _activeRadioUsers = users;
        });
      }
    };

    _socketService.onRadioIncomingTalk = (data) {
      if (_isPoweringOff || _isTransmitting) return;
      final name = data['name'] ?? 'Bilinmeyen Personel';
      _isReceiving = true;
      _currentTalkerName = name;
      RadioSoundEffects.playSquelchIn();
      final channelData = _channels[_currentChannel]!;
      RadioBackgroundService.updateNotification(
        title: '🎙️ $name Konuşuyor...',
        text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
      );
      if (mounted) {
        setState(() {});
      }
    };

    _socketService.onRadioTalkEnded = (data) {
      if (_isPoweringOff || _isTransmitting) return;
      _isReceiving = false;
      _currentTalkerName = null;
      RadioSoundEffects.playRogerBeep();
      final channelData = _channels[_currentChannel]!;
      RadioBackgroundService.updateNotification(
        title: '📻 İSDEMİR Telsiz Dinleniyor',
        text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
      );
      if (mounted) {
        setState(() {});
      }
    };
  }

  Future<void> _initAgoraService() async {
    _agoraService.onConnectionChanged = (isConnected, channel) {
      if (mounted) {
        setState(() {
          _isAgoraConnected = isConnected;
        });
      }
    };

    _agoraService.onRemoteSpeakerSpeaking = (remoteUid, volume) {
      if (_isPoweringOff || _isTransmitting) return;
      final name = _speakerNames[remoteUid] ?? 'Telsiz Personeli';
      if (!_isReceiving) {
        RadioSoundEffects.playSquelchIn();
      }
      _isReceiving = true;
      _currentTalkerName = name;
      final channelData = _channels[_currentChannel]!;
      RadioBackgroundService.updateNotification(
        title: '🎙️ $name Konuşuyor...',
        text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
      );
      if (mounted) {
        setState(() {});
      }
    };

    _agoraService.onAudioVolumeChanged = (volume, isLocal) {
      if (!mounted) return;
      if (_liveAudioVolume != volume) {
        setState(() {
          _liveAudioVolume = volume;
        });
      }
    };

    _agoraService.onRemoteSpeakerStopped = () {
      if (_isPoweringOff || _isTransmitting) return;
      if (_isReceiving) {
        RadioSoundEffects.playRogerBeep();
      }
      _isReceiving = false;
      _currentTalkerName = null;
      _liveAudioVolume = 0;
      final channelData = _channels[_currentChannel]!;
      RadioBackgroundService.updateNotification(
        title: '📻 İSDEMİR Telsiz Dinleniyor',
        text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
      );
      if (mounted) {
        setState(() {});
      }
    };

    await _agoraService.joinRadioChannel(
      channelCode: _currentChannel,
      userId: widget.user.id,
    );

    final channelData = _channels[_currentChannel]!;
    RadioBackgroundService.startService(
      channelName: channelData['name']!,
      freq: channelData['freq']!,
    );
  }

  void _joinChannel(String channel) {
    _socketService.joinRadio(
      userId: widget.user.id,
      name: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Taktik Personel',
      jobTitle: widget.user.jobTitle,
      avatarUrl: widget.user.photoPath,
      channel: channel,
    );
    _socketService.requestRadioUsers(channel: channel);
  }

  void _changeChannel(String newChannel) {
    if (_currentChannel == newChannel) return;
    HapticFeedback.mediumImpact();
    RadioSoundEffects.playSquelchTail();

    _socketService.leaveRadio(
      userId: widget.user.id,
      channel: _currentChannel,
    );

    setState(() {
      _currentChannel = newChannel;
      _activeRadioUsers = [];
    });

    _joinChannel(newChannel);
    _agoraService.joinRadioChannel(
      channelCode: newChannel,
      userId: widget.user.id,
    );

    final channelData = _channels[newChannel]!;
    RadioBackgroundService.startService(
      channelName: channelData['name']!,
      freq: channelData['freq']!,
    );
  }

  // --- BAS-KONUŞ (PTT) MOTORU ---

  Future<void> _startTalking() async {
    if (_isTransmitting) return;

    // 1. SIFIR GECİKME: UI hemen aktifleşsin
    setState(() {
      _isTransmitting = true;
      _transmitSeconds = 0;
    });

    HapticFeedback.heavyImpact();
    RadioSoundEffects.playSquelchIn();

    // 2. Agora Canlı Mikrofon Yayını Aç (Gerçek zamanlı HD telsiz akışı)
    await _agoraService.startTalking();

    // 3. Sunucuya da yayına başladığımızı anons et
    _socketService.startRadioTalk(
      userId: widget.user.id,
      name: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Taktik Personel',
      channel: _currentChannel,
    );

    _transmitTimer?.cancel();
    _transmitTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _transmitSeconds++;
        });
      }
    });

    // 4. Kapalı veya kilitli telefonları uyandırmak için anons push bildirimi gönder
    final channelData = _channels[_currentChannel]!;
    RadioBackgroundService.updateNotification(
      title: '🔴 Mandal Basıldı (Yayındasınız)',
      text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
    );

    PushService.sendPushNotification(
      title: '📻 [TELSİZ ANONS] ${widget.user.fullName.isNotEmpty ? widget.user.fullName : "Taktik Personel"}',
      content: '${channelData['name']} (${channelData['freq']}) üzerinden canlı telsiz konuşması yapılıyor!',
      isVipOnly: true, // Sadece VIP üyeler telsiz konuşma bildirimini görebilir
      additionalData: {
        'type': 'telsiz_channel',
        'channel': _currentChannel,
      },
    );
  }

  Future<void> _stopTalking() async {
    if (!_isTransmitting) return;

    HapticFeedback.mediumImpact();
    _transmitTimer?.cancel();

    setState(() {
      _isTransmitting = false;
      _liveAudioVolume = 0;
    });

    // 1. Agora Mikrofonunu Kapat
    await _agoraService.stopTalking();

    // 2. Sunucuya yayının bittiğini anons et
    _socketService.endRadioTalk(
      userId: widget.user.id,
      name: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Taktik Personel',
      channel: _currentChannel,
    );

    final channelData = _channels[_currentChannel]!;
    RadioBackgroundService.updateNotification(
      title: '📻 İSDEMİR Telsiz Dinleniyor',
      text: 'Kanal: ${channelData['name']} (${channelData['freq']})',
    );

    // 3. Roger Beep
    RadioSoundEffects.playRogerBeep();
  }


  @override
  Widget build(BuildContext context) {
    if (_isCheckingVip) {
      return const Scaffold(
        backgroundColor: Color(0xFF080B0E),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF00FF66)),
        ),
      );
    }

    if (!_isVip) {
      return VipRestrictedView(
        user: widget.user,
        onAuthorized: () {
          setState(() {
            _isVip = true;
          });
        },
        onBack: () => Navigator.pop(context),
      );
    }

    final channelData = _channels[_currentChannel]!;

    return Scaffold(
      backgroundColor: const Color(0xFF080B0E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0E1318),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: const Color(0xFF1B242C), height: 1),
        ),
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white12),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF00FF66), size: 16),
          ),
          onPressed: () {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.radio_rounded, color: Color(0xFF00FF66)),
                    SizedBox(width: 10),
                    Expanded(child: Text('📻 Telsiz arka planda aktif. Ekran kapalıyken de dinleniyor.')),
                  ],
                ),
                backgroundColor: Color(0xFF14191D),
                duration: Duration(seconds: 4),
              ),
            );
          },
        ),
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: _isAgoraConnected ? const Color(0xFF00FF66) : const Color(0xFFFFB300),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (_isAgoraConnected ? const Color(0xFF00FF66) : const Color(0xFFFFB300)).withValues(alpha: 0.8),
                            blurRadius: 6,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'İSDEMİR TAKTİK TELSİZ',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [Color(0xFFF59E0B), Color(0xFFD97706)]),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      'VIP',
                      style: GoogleFonts.orbitron(color: Colors.black, fontSize: 8, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.shield_outlined, color: Color(0xFF00FF66), size: 10),
                  const SizedBox(width: 4),
                  Text(
                    'MIL-SPEC // AES-256',
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF00FF66).withValues(alpha: 0.75),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFF59E0B), size: 21),
            tooltip: 'VIP Personel Davet Et',
            onPressed: _showInviteVipDialog,
          ),
          IconButton(
            icon: const Icon(Icons.power_settings_new_rounded, color: Color(0xFFFF4D4D), size: 21),
            tooltip: 'Telsizi Kapat',
            onPressed: _powerOffRadio,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),

            // 1. ASKERİ OLED TELSİZ HUD EKRANI
            _buildTacticalHeader(channelData)
                .animate()
                .fadeIn(duration: 350.ms)
                .slideY(begin: -0.05, end: 0),

            const SizedBox(height: 10),

            // 2. KANAL SEÇİM PANELİ (FREKANS KANALLARI)
            _buildChannelSelector()
                .animate()
                .fadeIn(duration: 400.ms, delay: 100.ms),

            const SizedBox(height: 10),

            // 3. CANLI TAKTİK RADAR / FREKANTAKİ OPERATÖRLER
            _buildActivePersonnelSection()
                .animate()
                .fadeIn(duration: 400.ms, delay: 150.ms),

            const Spacer(),

            // 4. CANLI SES SPEKTRUMU / 28-BAND EQUALIZER
            _buildAudioWaveform(),

            const SizedBox(height: 12),

            // 5. HAVACILIK TİPİ MOD SEÇİCİ (BASILI TUT / DOKUN-KONUŞ)
            _buildModeSelector(),

            const SizedBox(height: 8),

            // 5.1 DONANIMSAL SES TUŞU PTT BİLGİ VE AYAR ROZETİ
            _buildHardwareKeyPttBadge(),

            const SizedBox(height: 12),

            // 6. KONSANTRİK 3D TİTANYUM PTT BUTONU (AVATAR GLOW)
            _buildPttButton()
                .animate()
                .fadeIn(duration: 500.ms, delay: 200.ms)
                .scale(begin: const Offset(0.92, 0.92), end: const Offset(1, 1)),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }

  // --- RF SİNYAL GÖSTERGESİ (5 KADEMELİ LED) ---
  Widget _buildSignalMeter() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(5, (index) {
        final isLit = index < 4;
        return Container(
          width: 3.2,
          height: 4.5 + (index * 2.8),
          margin: const EdgeInsets.only(right: 2),
          decoration: BoxDecoration(
            color: isLit
                ? (_isTransmitting ? const Color(0xFFFF2A55) : const Color(0xFF00FF66))
                : Colors.white12,
            borderRadius: BorderRadius.circular(1),
            boxShadow: isLit
                ? [
                    BoxShadow(
                      color: (_isTransmitting ? const Color(0xFFFF2A55) : const Color(0xFF00FF66)).withValues(alpha: 0.6),
                      blurRadius: 3,
                    ),
                  ]
                : null,
          ),
        );
      }),
    );
  }

  // --- 1. ASKERİ OLED TELSİZ HUD GÖVDE PANELİ ---
  Widget _buildTacticalHeader(Map<String, String> channelData) {
    final borderColor = _isTransmitting
        ? const Color(0xFFFF2A55)
        : (_isReceiving ? const Color(0xFF00FF66) : const Color(0xFF1E2832));

    final freqParts = channelData['freq']!.split(' ');
    final freqDigits = freqParts.isNotEmpty ? freqParts[0] : '148.550';
    final freqUnit = freqParts.length > 1 ? freqParts[1] : 'MHz';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1318),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          if (_isTransmitting)
            BoxShadow(color: const Color(0xFFFF2A55).withValues(alpha: 0.25), blurRadius: 20, spreadRadius: 1)
          else if (_isReceiving)
            BoxShadow(color: const Color(0xFF00FF66).withValues(alpha: 0.2), blurRadius: 20, spreadRadius: 1)
          else
            BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 12),
        ],
      ),
      child: Column(
        children: [
          // Telemetri Üst Barı
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  _buildSignalMeter(),
                  const SizedBox(width: 6),
                  Text(
                    '-72 dBm',
                    style: GoogleFonts.orbitron(
                      color: Colors.white54,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF00FF66).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.tag_rounded, color: Color(0xFF00FF66), size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${channelData['code']} • CH-0$_currentChannel',
                      style: GoogleFonts.orbitron(
                        color: const Color(0xFF00FF66),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _isTransmitting
                      ? const Color(0xFFFF2A55).withValues(alpha: 0.2)
                      : (_isReceiving ? const Color(0xFF00FF66).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: _isTransmitting
                        ? const Color(0xFFFF2A55)
                        : (_isReceiving ? const Color(0xFF00FF66) : Colors.white12),
                  ),
                ),
                child: Text(
                  _isTransmitting ? '🔴 TX YAYINDA' : (_isReceiving ? '🟢 RX ALINIYOR' : '⚪ BEKLEMEDE'),
                  style: GoogleFonts.orbitron(
                    color: _isTransmitting
                        ? const Color(0xFFFF2A55)
                        : (_isReceiving ? const Color(0xFF00FF66) : Colors.white60),
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Ana Frekans Göstergesi (Büyük OLED Yazı)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                freqDigits,
                style: GoogleFonts.orbitron(
                  color: Colors.white,
                  fontSize: 38,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3,
                  shadows: [
                    BoxShadow(
                      color: (_isTransmitting ? const Color(0xFFFF2A55) : const Color(0xFF00FF66)).withValues(alpha: 0.35),
                      blurRadius: 14,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                freqUnit,
                style: GoogleFonts.orbitron(
                  color: const Color(0xFF00FF66),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),

          const SizedBox(height: 2),

          Text(
            channelData['name']!.toUpperCase(),
            style: GoogleFonts.orbitron(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.5,
            ),
          ),

          const SizedBox(height: 10),

          // Agora Canlı Akış ve Şifreleme Durumu
          InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              _initAgoraService();
            },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: _isAgoraConnected ? const Color(0xFF00FF66) : const Color(0xFFF59E0B),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_isAgoraConnected ? const Color(0xFF00FF66) : const Color(0xFFF59E0B)).withValues(alpha: 0.8),
                          blurRadius: 5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Text(
                    _isAgoraConnected ? 'AGORA RTC HD CANLI FREKANS • 0ms' : 'FREKANS YENİDEN BAĞLANIYOR... (Dokun)',
                    style: GoogleFonts.orbitron(
                      color: _isAgoraConnected ? const Color(0xFF00FF66) : const Color(0xFFF59E0B),
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.white10,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '48kHz',
                      style: GoogleFonts.orbitron(color: Colors.white54, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Gelen Ses Yayını Canlı HUD Uyarı Bandı
          if (_isReceiving && _currentTalkerName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF00FF66).withValues(alpha: 0.25),
                    const Color(0xFF00E5FF).withValues(alpha: 0.15),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFF00FF66), width: 1.2),
                boxShadow: [
                  BoxShadow(color: const Color(0xFF00FF66).withValues(alpha: 0.3), blurRadius: 10),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.record_voice_over_rounded, color: Color(0xFF00FF66), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentTalkerName',
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'ANONS GEÇİYOR...',
                    style: GoogleFonts.orbitron(color: const Color(0xFF00FF66), fontSize: 10.5, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. ASKERİ KANAL SEÇİM BUTONLARI (TACTICAL SELECTOR) ---
  Widget _buildChannelSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: _channels.keys.map((key) {
          final item = _channels[key]!;
          final isSelected = _currentChannel == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () => _changeChannel(key),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF16222A) : const Color(0xFF0E1318),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF00FF66) : const Color(0xFF1E2832),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF00FF66).withValues(alpha: 0.25),
                            blurRadius: 10,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFF00FF66) : Colors.white24,
                        shape: BoxShape.circle,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: const Color(0xFF00FF66).withValues(alpha: 0.8),
                                  blurRadius: 4,
                                ),
                              ]
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${item['code']} • ${item['name']}',
                          style: GoogleFonts.orbitron(
                            fontSize: 11,
                            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.white60,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          item['freq']!,
                          style: GoogleFonts.orbitron(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: isSelected ? const Color(0xFF00FF66) : Colors.white38,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // --- 3. CANLI TAKTİK RADAR & AKTİF OPERATÖR PANELİ ---
  Widget _buildActivePersonnelSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1318),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF1E2832)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Color(0xFF00FF66),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: Color(0xFF00FF66), blurRadius: 6),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'OPERATÖRLER (${_activeRadioUsers.length})',
                    style: GoogleFonts.orbitron(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF66), size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Yenile',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _socketService.requestRadioUsers(channel: _currentChannel);
                    },
                  ),
                ],
              ),
              InkWell(
                onTap: _showInviteVipDialog,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFFF59E0B).withValues(alpha: 0.25),
                        const Color(0xFFD97706).withValues(alpha: 0.25),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_add_alt_1_rounded, color: Color(0xFFFBBF24), size: 13),
                      const SizedBox(width: 5),
                      Text(
                        '+ VIP ÇAĞIR',
                        style: GoogleFonts.orbitron(
                          color: const Color(0xFFFBBF24),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_activeRadioUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar_rounded, color: Colors.white30, size: 15),
                  const SizedBox(width: 8),
                  Text(
                    'Frekans dinleniyor. Başka operatör yok.',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 44,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _activeRadioUsers.length,
                itemBuilder: (context, index) {
                  final u = _activeRadioUsers[index];
                  final name = (u['name'] ?? 'Personel').toString();
                  final uId = (u['userId'] ?? '').toString();
                  final myId = widget.user.id;
                  final isMe = uId == myId ||
                      uId == '${widget.user.firstName}_${widget.user.lastName}' ||
                      name == widget.user.fullName;
                  final isTalking = _currentTalkerName != null &&
                      (_currentTalkerName == name || (isMe && _isTransmitting));
                  final avatarUrl = u['avatarUrl'] as String?;

                  return Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isTalking
                          ? const Color(0xFFFF2A55).withValues(alpha: 0.2)
                          : (isMe ? const Color(0xFF00FF66).withValues(alpha: 0.12) : const Color(0xFF14191E)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isTalking
                            ? const Color(0xFFFF2A55)
                            : (isMe ? const Color(0xFF00FF66) : const Color(0xFF222B34)),
                        width: isTalking ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isTalking
                              ? const Color(0xFFFF2A55)
                              : (isMe ? const Color(0xFF00FF66) : const Color(0xFF2E3842)),
                          backgroundImage: SocketService.getAvatarProvider(avatarUrl),
                          child: avatarUrl == null
                              ? Icon(
                                  isTalking ? Icons.record_voice_over_rounded : Icons.person,
                                  color: Colors.black,
                                  size: 13,
                                )
                              : null,
                        ),
                        const SizedBox(width: 7),
                        Text(
                          isMe ? '$name (Ben)' : name,
                          style: GoogleFonts.inter(
                            color: isTalking
                                ? const Color(0xFFFF2A55)
                                : (isMe ? const Color(0xFF00FF66) : Colors.white),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isTalking) ...[
                          const SizedBox(width: 5),
                          const Icon(Icons.mic, color: Color(0xFFFF2A55), size: 13),
                        ],
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

  // --- 4. CANLI SES SPEKTRUMU / GERÇEK ZAMANLI DİNAMİK VU METRE ---
  Widget _buildAudioWaveform() {
    final isActive = _isTransmitting || _isReceiving;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        // Agora ses seviyesi (0-255) normalize faktörü (0.05 - 1.0)
        final volNorm = (_liveAudioVolume / 140.0).clamp(0.0, 1.0);
        final effectiveVol = isActive ? (volNorm > 0.05 ? volNorm : 0.12) : 0.0;
        final isLoud = effectiveVol > 0.65;
        final isPeak = effectiveVol > 0.88;

        // Anlık dB hesaplaması
        final dbDisplay = isActive
            ? (effectiveVol > 0.08 ? '-${((1.0 - effectiveVol) * 36).round()} dB' : '-42 dB')
            : 'SQUELCH';

        return Container(
          height: 70,
          margin: const EdgeInsets.symmetric(horizontal: 18),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: const Color(0xFF0C1014),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? (_isTransmitting
                      ? (isPeak ? const Color(0xFFFF2A55) : const Color(0xFFFFB300))
                      : const Color(0xFF00FF66))
                  : const Color(0xFF1B242C),
              width: isActive ? 1.5 : 1.0,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: (_isTransmitting
                              ? (isPeak ? const Color(0xFFFF2A55) : const Color(0xFFFFB300))
                              : const Color(0xFF00FF66))
                          .withValues(alpha: 0.25),
                      blurRadius: 10,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Column(
            children: [
              // Üst Durum Çubuğu (dB Değeri, Peak LED, Durum Rozeti)
              Row(
                children: [
                  Text(
                    isActive ? (_isTransmitting ? 'TX MIC VU METRE' : 'RX GELEN SES') : 'RF STANDBY',
                    style: GoogleFonts.orbitron(
                      color: isActive
                          ? (_isTransmitting ? const Color(0xFFFF2A55) : const Color(0xFF00FF66))
                          : Colors.white38,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const Spacer(),
                  // Peak Clip LED
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isPeak ? const Color(0xFFFF2A55) : const Color(0xFF222B34),
                      shape: BoxShape.circle,
                      boxShadow: isPeak
                          ? [
                              BoxShadow(
                                color: const Color(0xFFFF2A55).withValues(alpha: 0.9),
                                blurRadius: 6,
                                spreadRadius: 1.5,
                              )
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    'PEAK',
                    style: GoogleFonts.orbitron(
                      color: isPeak ? const Color(0xFFFF2A55) : Colors.white24,
                      fontSize: 7.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Anlık dB göstergesi
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      dbDisplay,
                      style: GoogleFonts.orbitron(
                        color: isPeak
                            ? const Color(0xFFFF2A55)
                            : (isLoud ? const Color(0xFFFFB300) : const Color(0xFF00FF66)),
                        fontSize: 8,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Dalga Çubukları (28 Spektrum Bandı)
              Expanded(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(28, (index) {
                    double height = 4.0;
                    Color barColor = const Color(0xFF1E2832);

                    if (isActive) {
                      // Çan eğrisi (Gaussian) dağılımı: Merkez konuşma frekansları daha yüksek zıplar
                      final dist = (index - 13.5).abs() / 14.0;
                      final bell = exp(-dist * dist * 3.2);

                      // Canlı Agora ses genliği + harmonik hareket
                      final wavePhase = (_waveController.value * 2 * pi * 2) + (index * 0.45);
                      final harmonic = 0.65 + 0.35 * sin(wavePhase);

                      height = 5.0 + (effectiveVol * bell * 36.0 * harmonic);
                      height = height.clamp(4.0, 42.0);

                      // Renk gradyanı: Yeşil -> Sarı -> Kırmızı Peak
                      if (_isTransmitting) {
                        if (effectiveVol > 0.85 && bell > 0.6) {
                          barColor = const Color(0xFFFF2A55);
                        } else if (effectiveVol > 0.55 && bell > 0.4) {
                          barColor = const Color(0xFFFFB300);
                        } else {
                          barColor = const Color(0xFF00FF66);
                        }
                      } else {
                        // RX dinleme modu
                        if (effectiveVol > 0.8) {
                          barColor = const Color(0xFF00E5FF);
                        } else {
                          barColor = const Color(0xFF00FF66);
                        }
                      }
                    } else {
                      // Boşta iken organik RF taşıyıcı hışırtı dalgalanması
                      final idlePhase = (_waveController.value * 2 * pi) + (index * 0.3);
                      height = 3.5 + 2.5 * (0.5 + 0.5 * sin(idlePhase));
                      barColor = const Color(0xFF1B242C);
                    }

                    return Container(
                      width: 3.8,
                      height: height,
                      decoration: BoxDecoration(
                        color: barColor,
                        borderRadius: BorderRadius.circular(2),
                        boxShadow: isActive && effectiveVol > 0.15
                            ? [
                                BoxShadow(
                                  color: barColor.withValues(alpha: 0.6),
                                  blurRadius: 3,
                                )
                              ]
                            : null,
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // --- 5. HAVACILIK TİPİ MOD SEÇİCİ ---
  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF0E1318),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF1E2832)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isTransmitting) _stopTalking();
                setState(() => _isToggleMode = false);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: !_isToggleMode ? const Color(0xFF00FF66).withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: !_isToggleMode ? const Color(0xFF00FF66) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.touch_app_rounded,
                        size: 13,
                        color: !_isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'BASILI TUT (PTT)',
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: !_isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_isTransmitting) _stopTalking();
                setState(() => _isToggleMode = true);
              },
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _isToggleMode ? const Color(0xFF00FF66).withValues(alpha: 0.16) : Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _isToggleMode ? const Color(0xFF00FF66) : Colors.transparent,
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.mic_rounded,
                        size: 13,
                        color: _isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'DOKUN-KONUŞ (VOX)',
                        style: GoogleFonts.orbitron(
                          fontSize: 9.5,
                          fontWeight: FontWeight.w900,
                          color: _isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 5.1 DONANIMSAL SES TUŞU PTT ROZETİ ---
  Widget _buildHardwareKeyPttBadge() {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() {
          _isHardwareKeyPttEnabled = !_isHardwareKeyPttEnabled;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 48),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: _isHardwareKeyPttEnabled
              ? const Color(0xFF00FF66).withValues(alpha: 0.08)
              : const Color(0xFF0E1318),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isHardwareKeyPttEnabled
                ? const Color(0xFF00FF66).withValues(alpha: 0.4)
                : const Color(0xFF1E2832),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isHardwareKeyPttEnabled ? Icons.volume_down_rounded : Icons.volume_mute_rounded,
              size: 14,
              color: _isHardwareKeyPttEnabled ? const Color(0xFF00FF66) : Colors.white38,
            ),
            const SizedBox(width: 6),
            Text(
              'SES KISMA TUŞU // PTT MANDAL',
              style: GoogleFonts.orbitron(
                color: _isHardwareKeyPttEnabled ? const Color(0xFF00FF66) : Colors.white38,
                fontSize: 8.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
              decoration: BoxDecoration(
                color: _isHardwareKeyPttEnabled
                    ? const Color(0xFF00FF66).withValues(alpha: 0.2)
                    : Colors.white10,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                _isHardwareKeyPttEnabled ? 'AKTİF' : 'KAPALI',
                style: GoogleFonts.orbitron(
                  color: _isHardwareKeyPttEnabled ? const Color(0xFF00FF66) : Colors.white38,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- 6. 3D KONSANTRİK TİTANYUM PTT BUTONU (AVATAR GLOW) ---
  Widget _buildPttButton() {
    final glowColor = _isTransmitting
        ? const Color(0xFFFF2A55)
        : (_isReceiving ? const Color(0xFF00FF66) : const Color(0xFF00E5FF).withValues(alpha: 0.2));

    return Column(
      children: [
        AvatarGlow(
          animate: _isTransmitting || _isReceiving,
          glowColor: glowColor,
          glowRadiusFactor: _isTransmitting ? 0.45 : 0.3,
          duration: const Duration(milliseconds: 1400),
          repeat: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              if (_isToggleMode) {
                if (_isTransmitting) {
                  _stopTalking();
                } else {
                  _startTalking();
                }
              } else {
                if (!_isTransmitting) {
                  _startTalking();
                  Future.delayed(const Duration(milliseconds: 2000), () {
                    if (mounted && _isTransmitting && !_isToggleMode) {
                      _stopTalking();
                    }
                  });
                } else {
                  _stopTalking();
                }
              }
            },
            onLongPressStart: (_) {
              if (!_isToggleMode && !_isTransmitting) {
                _startTalking();
              }
            },
            onLongPressEnd: (_) {
              if (!_isToggleMode && _isTransmitting) {
                _stopTalking();
              }
            },
            child: Container(
              width: 175,
              height: 175,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const RadialGradient(
                  colors: [Color(0xFF222C36), Color(0xFF0C1014)],
                  radius: 0.9,
                ),
                border: Border.all(
                  color: _isTransmitting
                      ? const Color(0xFFFF2A55)
                      : (_isReceiving ? const Color(0xFF00FF66) : const Color(0xFF2A3744)),
                  width: 3.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isTransmitting ? const Color(0xFFFF2A55) : const Color(0xFF00FF66)).withValues(
                      alpha: _isTransmitting ? 0.6 : (_isReceiving ? 0.4 : 0.15),
                    ),
                    blurRadius: _isTransmitting ? 32 : 18,
                    spreadRadius: _isTransmitting ? 4 : 1,
                  ),
                ],
              ),
              child: Center(
                // İkinci Halka: Yivli Alaşım
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _isTransmitting
                          ? const Color(0xFFFF2A55).withValues(alpha: 0.5)
                          : (_isReceiving ? const Color(0xFF00FF66).withValues(alpha: 0.5) : Colors.white12),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    // İç Çekirdek Buton
                    child: Container(
                      width: 125,
                      height: 125,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: _isTransmitting
                              ? [const Color(0xFFFF2A55), const Color(0xFF990022)]
                              : [const Color(0xFF1E2730), const Color(0xFF0D1216)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.6),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isTransmitting ? Icons.mic : Icons.mic_none_rounded,
                            color: _isTransmitting ? Colors.white : const Color(0xFF00FF66),
                            size: 46,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            _isTransmitting
                                ? 'YAYINDA ($_transmitSeconds s)'
                                : (_isToggleMode ? 'DOKUN KONUŞ' : 'BAS - KONUŞ'),
                            style: GoogleFonts.orbitron(
                              color: _isTransmitting ? Colors.white : const Color(0xFF00FF66),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _isTransmitting
              ? (_isToggleMode ? 'YAYINI DURDURMAK İÇİN DOKUNUN' : 'KONUŞMAYI BİTİRMEK İÇİN MANDALI BIRAKIN')
              : (_isToggleMode ? 'YAYINA BAŞLAMAK İÇİN DOKUNUN' : 'KONUŞMAK İÇİN MANDALI BASILI TUTUN'),
          style: GoogleFonts.orbitron(
            color: _isTransmitting ? const Color(0xFFFF2A55) : Colors.white54,
            fontSize: 9.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}

