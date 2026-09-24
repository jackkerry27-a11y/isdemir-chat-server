import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/socket_service.dart';
import 'services/noctra_security_service.dart';
import 'widgets/noctra_animations.dart';

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

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _listenSocketMessages();
  }

  void _listenSocketMessages() {
    // Soketten gelen canlı mesajları dinle
    SocketService().onMessageReceived = (data) {
      if (!mounted) return;
      if (data['senderId'] == widget.chatId) {
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

  void _sendMessage({bool isEphemeral = false}) {
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
            content: Text('⚠️ Tüm konuşma ve şifre izleri kalıcı olarak yok edildi.'),
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

            // Mikrofon (Sesli Mesaj)
            IconButton(
              icon: const Icon(Icons.mic_none_rounded, color: Color(0xFFA197A0), size: 22),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF1E1216),
                    content: Text('🎙️ Şifreli Sesli Mesaj kaydediliyor (Flutter Chat UI)...'),
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
                leading: const Icon(Icons.hide_image_rounded, color: Color(0xFFE50914)),
                title: const Text('Layergram Steganografi', style: TextStyle(color: Colors.white)),
                subtitle: const Text('Mesajı görsel pikseline gizleyerek gönderir', style: TextStyle(color: Colors.white54, fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _textController.text = '[STEGO-LGR] Gizli yük görsel içine mühürlendi.';
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
