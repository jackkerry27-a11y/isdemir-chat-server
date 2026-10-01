import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/socket_service.dart';
import 'services/noctra_security_service.dart';
import 'widgets/noctra_animations.dart';
import 'services/noctra_ai_service.dart';
import 'widgets/noctra_ai_widgets.dart';

class NoctraChatDetailScreen extends StatefulWidget {
  final String chatId;
  final String chatName;
  final String? chatAvatar;
  final String? currentAlias;
  final bool isOnline;
  final String protocolName;

  const NoctraChatDetailScreen({
    super.key,
    required this.chatId,
    required this.chatName,
    this.chatAvatar,
    this.currentAlias,
    required this.isOnline,
    this.protocolName = 'NyxChat (P2P + 1x Burn)',
  });

  @override
  State<NoctraChatDetailScreen> createState() => _NoctraChatDetailScreenState();
}

class _NoctraChatDetailScreenState extends State<NoctraChatDetailScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final NoctraSecurityService _securityService = NoctraSecurityService();

  List<NoctraMessage> _messages = [];
  Timer? _burnTimer;
  
  // 🧠 NOCTRA AI STATE
  bool _isCamouflageActive = false;
  CamouflageTheme _selectedCamouflageTheme = CamouflageTheme.routineShift;
  bool _isSentinelThreatActive = false;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenSocketMessages();
  }

  void _listenSocketMessages() {
    // Çift taraflı Nükleer Panic Wipe olayını dinle
    SocketService().onPanicWipeReceived = (wipeData) {
      if (!mounted) return;
      if (wipeData['senderId'] == widget.chatId) {
        _handleRemotePanicWipe();
      }
    };

    // Soketten gelen canlı mesajları dinle
    SocketService().onMessageReceived = (data) {
      if (!mounted) return;
      if (data['senderId'] == widget.chatId) {
        // Eğer gelen mesaj nükleer panic wipe ise
        if (data['content'] == '__NOCTRA_PANIC_WIPE__' || data['isPanicWipe'] == true) {
          _handleRemotePanicWipe();
          return;
        }
        final isEphemeral = data['isEphemeral'] == true;
        final newMsg = NoctraMessage(
          id: data['timestamp'] ?? 'msg_${DateTime.now().millisecondsSinceEpoch}',
          senderId: widget.chatId,
          senderName: widget.chatName,
          content: data['content'] ?? '',
          time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
          isMe: false,
          isEphemeral: isEphemeral,
          burnDurationSeconds: 10,
          remainingSeconds: 10,
          state: isEphemeral ? MessageSecurityState.encrypted : MessageSecurityState.normal,
        );

        setState(() {
          _messages.add(newMsg);
        });
        _saveMessages();
        _scrollToBottom();
      }
    };
  }

  Future<void> _loadMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = SocketService().currentUserId ?? 'user';
      final savedJson = prefs.getString('noctra_chat_${myId}_${widget.chatId}');
      if (savedJson != null && savedJson.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedJson);
        setState(() {
          _messages = decoded.map((item) => NoctraMessage.fromJson(item)).toList();
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint('Noctra mesajları yüklenirken hata: $e');
    }
  }

  Future<void> _saveMessages() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final myId = SocketService().currentUserId ?? 'user';
      final jsonList = _messages.map((m) => m.toJson()).toList();
      await prefs.setString('noctra_chat_${myId}_${widget.chatId}', jsonEncode(jsonList));

      // Konuşmalar listesi için son mesajı kaydet
      if (_messages.isNotEmpty) {
        final last = _messages.last;
        await prefs.setString('noctra_last_${myId}_${widget.chatId}', jsonEncode({
          'content': last.isEphemeral ? '🔥 1x Şifreli mesaj' : last.content,
          'time': last.time,
        }));
      }
    } catch (e) {
      debugPrint('Noctra mesajları kaydedilirken hata: $e');
    }
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _burnTimer?.cancel();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Mesajı Aç butonuna basıldığında Çözülme Hologramını Başlat (Ekran 4)
  void _startDecryption(NoctraMessage message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.88),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: DecryptionHologramWidget(
            onDecrypted: () {
              Navigator.of(context).pop();
              _onMessageDecrypted(message);
            },
          ),
        );
      },
    );
  }

  /// Çözülme bittiğinde mesajı göster ve 10 saniyelik imha sayacını başlat
  void _onMessageDecrypted(NoctraMessage message) {
    setState(() {
      message.state = MessageSecurityState.viewed;
      message.remainingSeconds = message.burnDurationSeconds;
    });

    _burnTimer?.cancel();
    _burnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (message.remainingSeconds > 1) {
          message.remainingSeconds--;
        } else {
          // Süre doldu, kalıcı olarak yak/imha et (Ekran 5)
          message.state = MessageSecurityState.burned;
          timer.cancel();
          _showBurnedHourglassDialog();
        }
      });
    });
  }

  /// Ekran 5: Kum Saati İmha Ekranı Dialogu
  void _showBurnedHourglassDialog() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24),
          child: BurnedMessageHourglassWidget(
            onDismiss: () => Navigator.of(context).pop(),
          ),
        );
      },
    );
  }

  // 🎭 SEMANTİK KAMUFLAJ İLE GÖNDER
  void _sendCamouflagedMessage(String secretText) {
    if (secretText.trim().isEmpty) return;
    final payload = NoctraAiService().generateCamouflage(secretText, _selectedCamouflageTheme);
    final packed = payload.pack();

    final myId = SocketService().currentUserId ?? 'user';
    final myName = widget.currentAlias ?? SocketService().savedName ?? 'Gölge';

    SocketService().sendMessage(
      myId,
      widget.chatId,
      packed,
      senderName: myName,
      isEphemeral: false,
    );

    final newMsg = NoctraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myId,
      senderName: myName,
      content: packed,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      isMe: true,
      isCamouflaged: true,
      state: MessageSecurityState.normal,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
    });
    _saveMessages();
    _scrollToBottom();
  }

  // 🎙️ AURA-VOICE İLE GÖNDER
  void _sendAuraVoiceMessage(String voicePath, AuraVoiceProfile profile, String duration) {
    final myId = SocketService().currentUserId ?? 'user';
    final myName = widget.currentAlias ?? SocketService().savedName ?? 'Gölge';
    final content = '[AURA_VOICE::${profile.name}::$duration]';

    SocketService().sendMessage(
      myId,
      widget.chatId,
      content,
      senderName: myName,
      isEphemeral: false,
    );

    final newMsg = NoctraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myId,
      senderName: myName,
      content: content,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      isMe: true,
      isAudio: true,
      audioDuration: duration,
      voiceProfile: profile.name,
      state: MessageSecurityState.normal,
    );

    setState(() {
      _messages.add(newMsg);
    });
    _saveMessages();
    _scrollToBottom();
  }

  // 🖼️ NÖRAL STEGANOGRAFİ İLE GÖNDER
  void _sendStegoMessage(String coverId, String secretText) {
    final myId = SocketService().currentUserId ?? 'user';
    final myName = widget.currentAlias ?? SocketService().savedName ?? 'Gölge';
    final packed = NoctraAiService().packStegoPayload(coverId, secretText);

    SocketService().sendMessage(
      myId,
      widget.chatId,
      packed,
      senderName: myName,
      isEphemeral: false,
    );

    final newMsg = NoctraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myId,
      senderName: myName,
      content: packed,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      isMe: true,
      isSteganographic: true,
      stegoCoverId: coverId,
      state: MessageSecurityState.normal,
    );

    setState(() {
      _messages.add(newMsg);
    });
    _saveMessages();
    _scrollToBottom();
  }

  void _sendMessage({bool isEphemeral = false}) {
    if (_isCamouflageActive && !isEphemeral) {
      _sendCamouflagedMessage(_textController.text.trim());
      return;
    }
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    final myId = SocketService().currentUserId ?? 'user';
    final myName = widget.currentAlias ?? SocketService().savedName ?? 'Gölge';

    // Gerçek API: Socket.io üzerinden karşı tarafa anlık ilet
    SocketService().sendMessage(
      myId,
      widget.chatId,
      text,
      senderName: myName,
      isEphemeral: isEphemeral,
    );

    final newMsg = NoctraMessage(
      id: 'msg_${DateTime.now().millisecondsSinceEpoch}',
      senderId: myId,
      senderName: myName,
      content: text,
      time: '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
      isMe: true,
      isEphemeral: isEphemeral,
      state: MessageSecurityState.normal,
    );

    setState(() {
      _messages.add(newMsg);
      _textController.clear();
    });
    _saveMessages();
    _scrollToBottom();
  }

  /// Karşı Taraf Panic Wipe Tetiklediğinde İki Taraflı Anında İmha Et
  Future<void> _handleRemotePanicWipe() async {
    final prefs = await SharedPreferences.getInstance();
    final myId = SocketService().currentUserId ?? 'user';
    await prefs.remove('noctra_chat_${myId}_${widget.chatId}');
    await prefs.remove('noctra_last_${myId}_${widget.chatId}');
    await _securityService.triggerPanicWipe();

    if (!mounted) return;
    setState(() {
      _messages.clear();
    });

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF14070A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
            side: const BorderSide(color: Color(0xFFE50914), width: 1.8),
          ),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'ÇİFT TARAFLI PANIC WIPE',
                  style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          content: Text(
            'Karşı taraf NyxChat Nükleer Panic Wipe protokolü tetikledi.\n\nBu sohbete ait tüm mesajlar, şifreleme anahtarları ve yerel kayıtlar iki taraflı olarak kalıcı biçimde yok edildi.',
            style: GoogleFonts.inter(color: const Color(0xFFD6C8CF), fontSize: 13, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE50914),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('ANLAŞILDI (ÇIKIŞ YAP)', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  /// NyxChat Panik Temizle
  Future<void> _handlePanicWipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF140D10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE50914), width: 1.5),
        ),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFE50914)),
            const SizedBox(width: 8),
            Text('NyxChat Panic Wipe', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Tüm mesajlar, yerel şifreleme anahtarları ve konuşma izleri kalıcı olarak cihazdan ve bellekten yok edilecek. Onaylıyor musunuz?',
          style: GoogleFonts.inter(color: const Color(0xFFC0B8BE)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE50914)),
            child: const Text('HEMEN İMHA ET', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      final myId = SocketService().currentUserId ?? 'user';

      // 1. Çift taraflı yok et: Karşı tarafa anında nükleer imha sinyali gönder!
      SocketService().sendPanicWipe(senderId: myId, receiverId: widget.chatId);

      // 2. Kendi cihazındaki tüm yerel verileri imha et
      await prefs.remove('noctra_chat_${myId}_${widget.chatId}');
      await prefs.remove('noctra_last_${myId}_${widget.chatId}');
      await _securityService.triggerPanicWipe();

      setState(() {
        _messages.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF8B0000),
            content: Text('⚠️ Çift taraflı Panic Wipe uygulandı: Karşı taraf ve cihazınızdaki tüm izler yok edildi.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF09060A),
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          // Atmosferik Koyu Kırmızı Arka Plan Işıması
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFE50914).withValues(alpha: 0.08),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Ana İçerik
          Column(
            children: [
              // Güvenlik Bildirim Bannerı
              _buildSecurityBanner(),

              // Mesaj Listesi
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final message = _messages[index];
                    return _buildMessageBubble(message);
                  },
                ),
              ),

              // Alt Giriş Barı (Input bar)
              _buildInputBar(),
            ],
          ),

          // 👁️ Visual Sentinel AI: Omuz Dikizleme Tehdit Katmanı
          if (_isSentinelThreatActive)
            SentinelThreatOverlay(
              onDismissThreat: () {
                setState(() => _isSentinelThreatActive = false);
              },
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF0F0B10),
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
        onPressed: () => Navigator.of(context).pop(),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          // Avatar
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.6), width: 1.5),
              color: const Color(0xFF191116),
              image: SocketService.getAvatarProvider(widget.chatAvatar) != null
                  ? DecorationImage(
                      image: SocketService.getAvatarProvider(widget.chatAvatar)!,
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: SocketService.getAvatarProvider(widget.chatAvatar) == null
                ? const Center(
                    child: Icon(Icons.person_outline_rounded, color: Colors.white, size: 24),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.chatName,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: widget.isOnline ? const Color(0xFF00FF66) : const Color(0xFF71717A),
                      boxShadow: widget.isOnline
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00FF66).withValues(alpha: 0.8),
                                blurRadius: 6,
                              ),
                            ]
                          : null,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    widget.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: const Color(0xFFA1A1AA),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
      actions: [
        // 👁️ Sentinel AI Rozeti
        IconButton(
          tooltip: 'Sentinel AI Gözetleme Kalkanı (Test Et)',
          icon: Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
              border: Border.all(color: const Color(0xFF00E5FF).withValues(alpha: 0.6)),
            ),
            child: const Icon(Icons.remove_red_eye_outlined, color: Color(0xFF00E5FF), size: 16),
          ),
          onPressed: () {
            setState(() => _isSentinelThreatActive = !_isSentinelThreatActive);
          },
        ),
        IconButton(
          icon: const Icon(Icons.call_outlined, color: Colors.white, size: 22),
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                backgroundColor: Color(0xFF1A1218),
                content: Text('🔒 Uçtan Uca Şifreli Sesli Çağrı (NyxChat P2P) başlatılıyor...'),
              ),
            );
          },
        ),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
          color: const Color(0xFF170F14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
          ),
          onSelected: (value) {
            if (value == 'panic') {
              _handlePanicWipe();
            } else if (value == 'hourglass') {
              _showBurnedHourglassDialog();
            } else if (value == 'protocol') {
              _showProtocolInfoDialog();
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'panic',
              child: Row(
                children: [
                  Icon(Icons.delete_forever_rounded, color: Color(0xFFE50914), size: 20),
                  SizedBox(width: 10),
                  Text('NyxChat Panik Temizle', style: TextStyle(color: Color(0xFFFF5252))),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'hourglass',
              child: Row(
                children: [
                  Icon(Icons.hourglass_bottom_rounded, color: Colors.amber, size: 20),
                  SizedBox(width: 10),
                  Text('İmha Görselini İncele', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'protocol',
              child: Row(
                children: [
                  Icon(Icons.shield_outlined, color: Colors.white70, size: 20),
                  SizedBox(width: 10),
                  Text('Protokol Detayları', style: TextStyle(color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSecurityBanner() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF140D12).withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: const Color(0xFFE50914).withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Color(0xFFE50914), size: 16),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Bu konuşmadaki mesajlar şifrelenmiştir.\nMesajlar yalnızca alıcı tarafından görülebilir.',
              style: GoogleFonts.inter(
                fontSize: 11,
                color: const Color(0xFFB3ABB2),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(NoctraMessage message) {
    // 1. Kilitli Tek Görüntülemelik Mesaj (Ekran 3)
    if (message.isEphemeral && message.state == MessageSecurityState.encrypted) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF160E13),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFFE50914).withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFE50914).withValues(alpha: 0.12),
              blurRadius: 16,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Color(0xFFE50914), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Şifreli Mesaj',
                        style: GoogleFonts.outfit(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Bu mesaj yalnızca bir kez görüntülenebilir.',
                        style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFF9E929B)),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE50914).withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '1x',
                    style: GoogleFonts.outfit(
                      color: const Color(0xFFE50914),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Mesajı Aç Butonu
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => _startDecryption(message),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF261217),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: Color(0xFFE50914), width: 1),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  'Mesajı Aç',
                  style: GoogleFonts.outfit(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                message.time,
                style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF756A72)),
              ),
            ),
          ],
        ),
      );
    }

    // 2. Çözülmüş ve Geri Sayım Yapan Mesaj
    if (message.state == MessageSecurityState.viewed) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF211116),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFFF3B30), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_open_rounded, color: Color(0xFFFF3B30), size: 18),
                const SizedBox(width: 8),
                Text(
                  'İmha Sayacı: ${message.remainingSeconds}s',
                  style: GoogleFonts.outfit(
                    color: const Color(0xFFFF3B30),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              message.content,
              style: GoogleFonts.inter(fontSize: 14, color: Colors.white, height: 1.4),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: message.remainingSeconds / message.burnDurationSeconds,
              backgroundColor: Colors.white12,
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFE50914)),
              minHeight: 4,
            ),
          ],
        ),
      );
    }

    // 3. Kalıcı Olarak Silinmiş / İmha Edilmiş Mesaj (Ekran 5)
    if (message.state == MessageSecurityState.burned) {
      return Container(
        margin: const EdgeInsets.only(bottom: 16, right: 40),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF100A0D),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_empty_rounded, color: Color(0xFF8B0000), size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Mesaj görüntülendi ve kalıcı olarak silindi.',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: const Color(0xFF8A7E86),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // 4. SEMANTİK KAMUFLAJ BALONU
    final camPayload = CamouflagePayload.unpack(message.content);
    if (camPayload != null || message.isCamouflaged) {
      final payload = camPayload ?? CamouflagePayload(
        theme: _selectedCamouflageTheme,
        decoyText: message.content,
        secretText: message.content,
      );
      final isMe = message.isMe;
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: EdgeInsets.only(bottom: 12, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF130E14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFF00E5FF).withValues(alpha: 0.4),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF00E5FF).withValues(alpha: 0.1),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.masks_rounded, color: Color(0xFF00E5FF), size: 13),
                        const SizedBox(width: 4),
                        Text(
                          'AI Semantik Kamuflaj',
                          style: GoogleFonts.outfit(
                            color: const Color(0xFF00E5FF),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(message.time, style: GoogleFonts.inter(fontSize: 10, color: Colors.white38)),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                payload.decoyText,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.95),
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 34,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SemanticDeMaskModal(
                        payload: payload,
                        onReMask: () {},
                      ),
                    );
                  },
                  icon: const Icon(Icons.fingerprint_rounded, size: 15),
                  label: const Text('NÖRAL DEŞİFRE ET', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF261217),
                    foregroundColor: const Color(0xFFFF5252),
                    elevation: 0,
                    side: const BorderSide(color: Color(0xFFE50914), width: 1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 5. NÖRAL STEGANOGRAFİ GÖRSEL BALONU
    final stegoData = NoctraAiService().unpackStegoPayload(message.content);
    if (stegoData != null || message.isSteganographic) {
      final isMe = message.isMe;
      final coverId = stegoData?['coverId'] ?? message.stegoCoverId ?? 'dock_pier';
      final secret = stegoData?['secret'] ?? 'Gizli veri çözülemedi';
      final cover = NoctraAiService().availableStegoCovers.firstWhere(
        (c) => c.id == coverId,
        orElse: () => NoctraAiService().availableStegoCovers.first,
      );

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 250,
          margin: EdgeInsets.only(bottom: 12, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF140D12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: cover.accentColor.withValues(alpha: 0.5), width: 1.2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 100,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: cover.accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Icon(cover.icon, size: 44, color: cover.accentColor),
                ),
              ),
              const SizedBox(height: 8),
              Text(cover.title, style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
              Text('Görsel piksellerine gömülü gizli veri', style: GoogleFonts.inter(color: Colors.white54, fontSize: 11)),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 32,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF120C10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: cover.accentColor)),
                        title: Row(
                          children: [
                            Icon(Icons.qr_code_scanner_rounded, color: cover.accentColor),
                            const SizedBox(width: 8),
                            Text('Nöral Stego Taraması', style: GoogleFonts.outfit(color: Colors.white, fontSize: 16)),
                          ],
                        ),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Piksel artıklarından çıkarılan veri:', style: GoogleFonts.inter(color: Colors.white60, fontSize: 12)),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E0A10),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0xFFE50914)),
                              ),
                              child: Text(secret, style: GoogleFonts.jetBrainsMono(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Kapat')),
                        ],
                      ),
                    );
                  },
                  icon: const Icon(Icons.search_rounded, size: 14),
                  label: const Text('PİKSELİ TARA & ÇÖZ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(backgroundColor: cover.accentColor, foregroundColor: Colors.black),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 6. AURA-VOICE SESLİ MESAJ BALONU
    if (message.isAudio || message.content.startsWith('[AURA_VOICE::')) {
      final isMe = message.isMe;
      final dur = message.audioDuration ?? '00:08';
      final prof = message.voiceProfile ?? 'ghostFrequency';

      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          width: 240,
          margin: EdgeInsets.only(bottom: 12, left: isMe ? 40 : 0, right: isMe ? 0 : 40),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF160E14),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE50914).withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFFE50914)),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Aura-Voice AI', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                        Text('Biyometri Sıfırlandı • $dur', style: GoogleFonts.inter(color: Colors.white54, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('🎭 Profil: $prof', style: GoogleFonts.inter(color: const Color(0xFF00E5FF), fontSize: 10)),
              ),
            ],
          ),
        ),
      );
    }

    // 4. Normal Balon (Giden veya Gelen)
    final isMe = message.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          bottom: 12,
          left: isMe ? 50 : 0,
          right: isMe ? 0 : 50,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF1E1216) : const Color(0xFF150E12),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isMe ? 20 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 20),
          ),
          border: Border.all(
            color: isMe
                ? const Color(0xFFE50914).withValues(alpha: 0.35)
                : Colors.white.withValues(alpha: 0.06),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.95),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  message.time,
                  style: GoogleFonts.inter(fontSize: 10, color: const Color(0xFF7B7077)),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all_rounded, color: Color(0xFFE50914), size: 14),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F0B10),
        border: Border(
          top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Ataç / Steganografi butonu
            IconButton(
              icon: const Icon(Icons.attach_file_rounded, color: Color(0xFFA197A0), size: 22),
              onPressed: _showAttachmentMenu,
            ),

            // Metin Alanı
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF181015),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: TextField(
                  controller: _textController,
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Mesajını yaz...',
                    hintStyle: GoogleFonts.inter(color: const Color(0xFF6E646C), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),

            // 🎭 Semantik Kamuflaj Hızlı Butonu
            IconButton(
              tooltip: 'Semantik Kamuflaj AI',
              icon: Icon(
                Icons.masks_rounded,
                color: _isCamouflageActive ? const Color(0xFF00E5FF) : const Color(0xFFA197A0),
                size: 22,
              ),
              onPressed: () {
                setState(() => _isCamouflageActive = !_isCamouflageActive);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFF120C10),
                    content: Text(
                      _isCamouflageActive
                          ? '🎭 Semantik Kamuflaj Aktif: Mesajlar masum gündelik sohbete dönüştürülecek.'
                          : '🔓 Standart Şifreli Moda Dönüldü.',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                );
              },
            ),

            // 🎙️ Aura-Voice AI Mikrofon
            IconButton(
              tooltip: 'Aura-Voice Nöral Ses Maskeleme',
              icon: const Icon(Icons.graphic_eq_rounded, color: Color(0xFFE50914), size: 22),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: Colors.transparent,
                  builder: (ctx) => AuraVoiceModal(
                    onSendVoice: (path, prof, dur) {
                      _sendAuraVoiceMessage(path, prof, dur);
                    },
                  ),
                );
              },
            ),

            // Kırmızı Gönder Butonu
            GestureDetector(
              onTap: () => _sendMessage(),
              onLongPress: () {
                // Uzun basınca 1x Kendini İmha Eden Mesaj gönderir!
                _sendMessage(isEphemeral: true);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF8B0000),
                    content: Text('🔥 1x Tek Görüntülemelik Şifreli Mesaj gönderildi!'),
                  ),
                );
              },
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFFE50914), Color(0xFF990000)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFE50914).withValues(alpha: 0.5),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF140D12),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Güvenli Eklenti Gönder',
                style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.hide_image_rounded, color: Color(0xFF00E5FF)),
                title: const Text('Nöral Steganografi (Görsele Veri Göm)', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Mesajı fabrika görselinin piksel katmanına gizler', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    backgroundColor: Colors.transparent,
                    isScrollControlled: true,
                    builder: (ctx) => NeuralStegoComposerModal(
                      onSendStego: (coverId, secret) {
                        _sendStegoMessage(coverId, secret);
                      },
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.masks_rounded, color: Color(0xFFE50914)),
                title: const Text('Semantik Kamuflaj AI (Temayı Değiştir)', style: TextStyle(color: Colors.white)),
                subtitle: Text('Aktif Tema: ${_selectedCamouflageTheme.name}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _isCamouflageActive = true;
                    // Döngüsel tema değişimi
                    final nextIndex = (_selectedCamouflageTheme.index + 1) % CamouflageTheme.values.length;
                    _selectedCamouflageTheme = CamouflageTheme.values[nextIndex];
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: const Color(0xFF140D12),
                      content: Text('🎭 Kamuflaj Teması: ${_selectedCamouflageTheme.name} olarak ayarlandı.'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_outlined, color: Colors.amber),
                title: const Text('1x Tek Görüntülemelik Mesaj', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Okunduktan sonra hemen silinir (NyxChat)', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _sendMessage(isEphemeral: true);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showProtocolInfoDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF140D12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFFE50914), width: 1.2),
        ),
        title: Text('Aktif Güvenlik Mimarisi', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _protocolItem('NyxChat', 'P2P Doğrudan Uçtan Uca İletişim & Panik Silme'),
            _protocolItem('Layergram', 'Delete-After-Read & Steganografi Desteği'),
            _protocolItem('SimpleX', 'Sıfır Kullanıcı ID & Anonim Oturum Anahtarları'),
            _protocolItem('Flutter Chat UI', 'Dinamik Zengin Medya & Balon Akışı'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat', style: TextStyle(color: Color(0xFFE50914))),
          ),
        ],
      ),
    );
  }

  Widget _protocolItem(String name, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• $name', style: const TextStyle(color: Color(0xFFE50914), fontWeight: FontWeight.bold)),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}
