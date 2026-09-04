import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import '../models/user_model.dart';
import '../utils/socket_service.dart';
import '../utils/radio_sound_effects.dart';

class TelsizScreen extends StatefulWidget {
  final UserModel user;

  const TelsizScreen({super.key, required this.user});

  @override
  State<TelsizScreen> createState() => _TelsizScreenState();
}

class _TelsizScreenState extends State<TelsizScreen> with TickerProviderStateMixin {
  final SocketService _socketService = SocketService();
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _incomingAudioPlayer = AudioPlayer();

  String _currentChannel = '1';
  bool _isTransmitting = false; // Kullanıcı basıp konuşuyor mu?
  bool _isReceiving = false; // Biri şu an telsizden konuşuyor mu?
  bool _isToggleMode = false; // true = Dokun-Konuş, false = Basılı Tut (PTT)
  bool _isRecordingAudio = false;
  String? _currentTalkerName; // Konuşan kişinin adı
  List<dynamic> _activeRadioUsers = [];

  late AnimationController _pulseController;
  late AnimationController _waveController;
  Timer? _transmitTimer;
  int _transmitSeconds = 0;

  // Frekans Kanalları
  final Map<String, Map<String, String>> _channels = {
    '1': {'name': 'İSDEMİR SAHA', 'freq': '148.550 MHz', 'code': 'TAC-1'},
    '2': {'name': 'LİMAN GÜVENLİK', 'freq': '156.800 MHz', 'code': 'VHF-16'},
    '3': {'name': 'RIHTIM & VİNÇ', 'freq': '162.025 MHz', 'code': 'OPS-3'},
  };

  @override
  void initState() {
    super.initState();
    RadioSoundEffects.init();
    _requestMicPermissionOnLoad();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);

    _initSocketListeners();
    _joinChannel(_currentChannel);
  }

  Future<void> _requestMicPermissionOnLoad() async {
    try {
      await _audioRecorder.hasPermission();
    } catch (e) {
      debugPrint('Mikrofon izni kontrol hatası: $e');
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _waveController.dispose();
    _transmitTimer?.cancel();
    _audioRecorder.dispose();
    _incomingAudioPlayer.dispose();
    _socketService.leaveRadio(
      userId: widget.user.id,
      channel: _currentChannel,
    );
    _socketService.onRadioUsersUpdated = null;
    _socketService.onRadioIncomingTalk = null;
    _socketService.onRadioAudioBroadcast = null;
    _socketService.onRadioTalkEnded = null;
    super.dispose();
  }

  void _initSocketListeners() {
    _socketService.onRadioUsersUpdated = (users) {
      if (mounted) {
        setState(() {
          _activeRadioUsers = users;
        });
      }
    };

    _socketService.onRadioIncomingTalk = (data) {
      if (mounted) {
        setState(() {
          _isReceiving = true;
          _currentTalkerName = data['name'] ?? 'Bilinmeyen Personel';
        });
        RadioSoundEffects.playSquelchIn();
      }
    };

    _socketService.onRadioAudioBroadcast = (data) async {
      final audioBase64 = data['audioBase64'] as String?;
      if (audioBase64 != null && audioBase64.isNotEmpty) {
        try {
          final bytes = base64Decode(audioBase64);
          await _incomingAudioPlayer.stop();
          await _incomingAudioPlayer.play(BytesSource(bytes));
        } catch (e) {
          debugPrint('Audio broadcast playback error: $e');
        }
      }
    };

    _socketService.onRadioTalkEnded = (data) {
      if (mounted) {
        setState(() {
          _isReceiving = false;
          _currentTalkerName = null;
        });
        RadioSoundEffects.playRogerBeep();
      }
    };
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
  }

  // --- BAS-KONUŞ (PTT) MOTORU ---

  Future<void> _startTalking() async {
    if (_isTransmitting) return;

    // 1. SIFIR GECİKME: UI hemen aktifleşsin (Kırmızı kor, ses dalgası ve sayaç)
    setState(() {
      _isTransmitting = true;
      _transmitSeconds = 0;
    });

    HapticFeedback.heavyImpact();

    // 2. Telsiz mandal sesini çal (UI'ı bekletmeden)
    RadioSoundEffects.playSquelchIn();

    // 3. Sunucuya yayına başladığımızı anons et
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

    // 4. Mikrofon kaydını arka planda başlat (Emülatörde hata verse dahi UI asla takılmaz)
    try {
      final hasPermission = await _audioRecorder.hasPermission();
      if (hasPermission && _isTransmitting) {
        final tempDir = await getTemporaryDirectory();
        final recordPath = '${tempDir.path}/radio_stream.m4a';
        await _audioRecorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 32000,
            sampleRate: 22050,
          ),
          path: recordPath,
        );
        _isRecordingAudio = true;
      }
    } catch (e) {
      debugPrint('Mikrofon başlatma bildirimi: $e');
    }
  }

  Future<void> _stopTalking() async {
    if (!_isTransmitting) return;

    HapticFeedback.mediumImpact();
    _transmitTimer?.cancel();

    setState(() {
      _isTransmitting = false;
    });

    if (_isRecordingAudio) {
      _isRecordingAudio = false;
      try {
        final path = await _audioRecorder.stop();
        if (path != null) {
          final file = File(path);
          if (await file.exists()) {
            final bytes = await file.readAsBytes();
            if (bytes.isNotEmpty) {
              final base64Audio = base64Encode(bytes);
              _socketService.sendRadioAudioChunk(
                userId: widget.user.id,
                name: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Taktik Personel',
                audioBase64: base64Audio,
                channel: _currentChannel,
              );
            }
          }
        }
      } catch (e) {
        debugPrint('Mikrofon durdurma hatası: $e');
      }
    }

    // Yayını bitir ve Roger Beep çal
    _socketService.endRadioTalk(
      userId: widget.user.id,
      name: widget.user.fullName.isNotEmpty ? widget.user.fullName : 'Taktik Personel',
      channel: _currentChannel,
    );
    RadioSoundEffects.playRogerBeep();
  }

  @override
  Widget build(BuildContext context) {
    final channelData = _channels[_currentChannel]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0F11),
      appBar: AppBar(
        backgroundColor: const Color(0xFF14181B),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Color(0xFF00FF66), size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFF00FF66),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: const Color(0xFF00FF66).withValues(alpha: 0.8), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  'ÖZEL KUVVETLER TELSİZİ',
                  style: GoogleFonts.orbitron(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
            Text(
              'SECURE ENCRYPTED TACTICAL COMMS',
              style: GoogleFonts.orbitron(
                color: const Color(0xFF00FF66).withValues(alpha: 0.6),
                fontSize: 9,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.volume_up_rounded, color: Color(0xFF00FF66)),
            tooltip: 'Sinyal Testi (Roger Beep)',
            onPressed: () => RadioSoundEffects.playRogerBeep(),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 1. ÜST ASKERİ HUD FREKANS VE KANAL PANELİ
            _buildTacticalHeader(channelData),

            const SizedBox(height: 12),

            // 2. KANAL SEÇİM SEKMLERİ (TACTICAL CHIPS)
            _buildChannelSelector(),

            const SizedBox(height: 12),

            // 3. CANLI RADAR / AKTİF PERSONEL LİSTESİ
            _buildActivePersonnelSection(),

            const Spacer(),

            // 4. SES SPEKTRUMU / WAVEFORM GÖSTERGESİ
            _buildAudioWaveform(),

            const SizedBox(height: 12),

            // 5. MOD SEÇİCİ (BASILI TUT / DOKUN-KONUŞ)
            _buildModeSelector(),

            const SizedBox(height: 16),

            // 6. DEVASA BAS-KONUŞ (PTT) BUTONU
            _buildPttButton(),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTacticalHeader(Map<String, String> channelData) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF14191D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isTransmitting
              ? Colors.redAccent
              : (_isReceiving ? const Color(0xFF00FF66) : const Color(0xFF2A343D)),
          width: 1.5,
        ),
        boxShadow: [
          if (_isTransmitting)
            BoxShadow(color: Colors.red.withValues(alpha: 0.3), blurRadius: 16, spreadRadius: 2)
          else if (_isReceiving)
            BoxShadow(color: const Color(0xFF00FF66).withValues(alpha: 0.2), blurRadius: 16, spreadRadius: 2),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar_rounded, color: Color(0xFF00FF66), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    channelData['code']!,
                    style: GoogleFonts.orbitron(
                      color: const Color(0xFF00FF66),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _isTransmitting
                      ? Colors.red.withValues(alpha: 0.2)
                      : (_isReceiving ? const Color(0xFF00FF66).withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  _isTransmitting ? 'YAYINDA (TX)' : (_isReceiving ? 'ALINIYOR (RX)' : 'BEKLEMEDE (STANDBY)'),
                  style: GoogleFonts.orbitron(
                    color: _isTransmitting ? Colors.redAccent : (_isReceiving ? const Color(0xFF00FF66) : Colors.white54),
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            channelData['freq']!,
            style: GoogleFonts.orbitron(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              letterSpacing: 3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            channelData['name']!,
            style: GoogleFonts.inter(
              color: const Color(0xFF94A3B8),
              fontSize: 13,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          if (_isReceiving && _currentTalkerName != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00FF66).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF00FF66).withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.record_voice_over_rounded, color: Color(0xFF00FF66), size: 16),
                  const SizedBox(width: 8),
                  Text(
                    '$_currentTalkerName anons geçiyor...',
                    style: GoogleFonts.inter(color: const Color(0xFF00FF66), fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChannelSelector() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: _channels.keys.map((key) {
          final item = _channels[key]!;
          final isSelected = _currentChannel == key;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                '${item['code']} • ${item['name']}',
                style: GoogleFonts.orbitron(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.bold,
                  color: isSelected ? Colors.black : Colors.white70,
                ),
              ),
              selected: isSelected,
              selectedColor: const Color(0xFF00FF66),
              backgroundColor: const Color(0xFF1B2228),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color: isSelected ? const Color(0xFF00FF66) : const Color(0xFF2A343D),
                ),
              ),
              onSelected: (_) => _changeChannel(key),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildActivePersonnelSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF14191D).withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF232B32)),
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
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AKTİF FREKANTAKİ PERSONEL (${_activeRadioUsers.length})',
                    style: GoogleFonts.orbitron(
                      color: Colors.white70,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Color(0xFF00FF66), size: 16),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Frekans Listesini Yenile',
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      _socketService.requestRadioUsers(channel: _currentChannel);
                    },
                  ),
                ],
              ),
              Text(
                'KANAL $_currentChannel',
                style: GoogleFonts.orbitron(color: const Color(0xFF00FF66), fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_activeRadioUsers.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radio, color: Colors.white30, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    'Frekansı dinleyen başka personel yok',
                    style: GoogleFonts.inter(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            )
          else
            SizedBox(
              height: 48,
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
                          ? const Color(0xFFFF9800).withValues(alpha: 0.2)
                          : isMe
                              ? const Color(0xFF00FF66).withValues(alpha: 0.15)
                              : const Color(0xFF1E252B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isTalking
                            ? const Color(0xFFFF9800)
                            : isMe
                                ? const Color(0xFF00FF66)
                                : Colors.white12,
                        width: isTalking ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: isTalking
                              ? const Color(0xFFFF9800).withValues(alpha: 0.3)
                              : const Color(0xFF00FF66).withValues(alpha: 0.3),
                          backgroundImage: SocketService.getAvatarProvider(avatarUrl),
                          child: avatarUrl == null
                              ? Icon(
                                  isTalking ? Icons.record_voice_over_rounded : Icons.person,
                                  color: isTalking ? const Color(0xFFFF9800) : const Color(0xFF00FF66),
                                  size: 14,
                                )
                              : null,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isMe ? '$name (Ben)' : name,
                          style: TextStyle(
                            color: isTalking
                                ? const Color(0xFFFF9800)
                                : isMe
                                    ? const Color(0xFF00FF66)
                                    : Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (isTalking) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.mic, color: Color(0xFFFF9800), size: 12),
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

  Widget _buildAudioWaveform() {
    final isActive = _isTransmitting || _isReceiving;

    return AnimatedBuilder(
      animation: _waveController,
      builder: (context, child) {
        return Container(
          height: 60,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: List.generate(24, (index) {
              double height = 4;
              if (isActive) {
                final wavePhase = (_waveController.value * 2 * pi) + (index * 0.4);
                height = 8 + ((1 + (index % 4) * 0.25) * (15 + 20 * (0.5 + 0.5 * (1.0 + sin(wavePhase)))));
                height = height.clamp(6.0, 55.0);
              }
              return Container(
                width: 4,
                height: height,
                decoration: BoxDecoration(
                  color: _isTransmitting
                      ? Colors.redAccent
                      : (_isReceiving ? const Color(0xFF00FF66) : const Color(0xFF2A343D)),
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [
                    if (isActive)
                      BoxShadow(
                        color: (_isTransmitting ? Colors.redAccent : const Color(0xFF00FF66)).withValues(alpha: 0.5),
                        blurRadius: 4,
                      ),
                  ],
                ),
              );
            }),
          ),
        );
      },
    );
  }

  Widget _buildModeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 40),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFF14191D),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFF2A343D)),
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: !_isToggleMode ? const Color(0xFF00FF66).withValues(alpha: 0.18) : Colors.transparent,
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
                        'BASILI TUT',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: !_isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                          letterSpacing: 1,
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: _isToggleMode ? const Color(0xFF00FF66).withValues(alpha: 0.18) : Colors.transparent,
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
                        'DOKUN-KONUŞ',
                        style: GoogleFonts.orbitron(
                          fontSize: 10,
                          fontWeight: FontWeight.w900,
                          color: _isToggleMode ? const Color(0xFF00FF66) : Colors.white38,
                          letterSpacing: 1,
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

  Widget _buildPttButton() {
    return Column(
      children: [
        Listener(
          onPointerDown: (_) {
            if (!_isToggleMode) {
              _startTalking();
            }
          },
          onPointerUp: (_) {
            if (!_isToggleMode) {
              _stopTalking();
            }
          },
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
                // Basılı tut modunda tek tık yapılırsa 1.5 sn anons başlatıp otomatik durdurur
                if (!_isTransmitting) {
                  _startTalking();
                  Future.delayed(const Duration(milliseconds: 1500), () {
                    if (mounted && _isTransmitting && !_isToggleMode) {
                      _stopTalking();
                    }
                  });
                } else {
                  _stopTalking();
                }
              }
            },
            child: Container(
              width: 170,
              height: 170,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF14191D),
                border: Border.all(
                  color: _isTransmitting ? Colors.redAccent : const Color(0xFF00FF66),
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isTransmitting ? Colors.redAccent : const Color(0xFF00FF66)).withValues(alpha: _isTransmitting ? 0.6 : 0.25),
                    blurRadius: _isTransmitting ? 35 : 20,
                    spreadRadius: _isTransmitting ? 6 : 2,
                  ),
                ],
              ),
              child: Center(
                child: Container(
                  width: 130,
                  height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: _isTransmitting
                          ? [const Color(0xFFE50914), const Color(0xFF880000)]
                          : [const Color(0xFF1B242A), const Color(0xFF0F1518)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _isTransmitting ? Icons.mic : Icons.mic_none_rounded,
                        color: _isTransmitting ? Colors.white : const Color(0xFF00FF66),
                        size: 48,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _isTransmitting ? 'YAYINDA ($_transmitSeconds s)' : (_isToggleMode ? 'DOKUN KONUŞ' : 'BAS - KONUŞ'),
                        style: GoogleFonts.orbitron(
                          color: _isTransmitting ? Colors.white : const Color(0xFF00FF66),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          _isTransmitting
              ? (_isToggleMode ? 'DURDURMAK İÇİN DOKUNUN' : 'KONUŞMAYI BİTİRMEK İÇİN BIRAKIN')
              : (_isToggleMode ? 'KONUŞMAK İÇİN DOKUNUN' : 'KONUŞMAK İÇİN BASILI TUTUN'),
          style: GoogleFonts.orbitron(
            color: _isTransmitting ? Colors.redAccent : Colors.white54,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
