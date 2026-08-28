import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/socket_service.dart';

class ChatDetailScreen extends StatefulWidget {
  final String userId;
  final String userName;
  final String? userAvatar;
  final bool isOnline;

  const ChatDetailScreen({
    super.key,
    required this.userId,
    required this.userName,
    this.userAvatar,
    required this.isOnline,
  });

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  final TextEditingController _messageController = TextEditingController();
  bool _isTyping = false; // "yazıyor..." göstermek için (socket'ten gelince tetiklenecek)
  bool _isTypingMessage = false; // Kullanıcının mesaj yazıp yazmadığını takip etmek için

  List<Map<String, dynamic>> _messages = [];

  @override
  void initState() {
    super.initState();
    _loadMessages();
    // Gelen mesajları dinle
    SocketService().onMessageReceived = (data) {
      if (mounted && data['senderId'] == widget.userId) {
        setState(() {
          _messages.add({
            'text': data['content'],
            'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
            'isMe': false,
          });
          _saveMessages();
        });
      }
    };
  }

  Future<void> _loadMessages() async {
    final prefs = await SharedPreferences.getInstance();
    final String? messagesJson = prefs.getString('chat_${widget.userId}');
    if (messagesJson != null) {
      setState(() {
        _messages = List<Map<String, dynamic>>.from(json.decode(messagesJson));
      });
    }
  }

  Future<void> _saveMessages() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chat_${widget.userId}', json.encode(_messages));
  }

  void _deleteMessage(int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mesajı Sil'),
        content: const Text('Bu mesajı silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF4338CA)),
            onPressed: () {
              setState(() {
                _messages.removeAt(index);
                _saveMessages();
              });
              Navigator.pop(context);
            },
            child: const Text('Sil', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _sendMessage() {
    if (_messageController.text.trim().isEmpty) return;
    
    final text = _messageController.text.trim();
    final senderId = SocketService().currentUserId ?? '';
    
    // Sokete gönder
    SocketService().sendMessage(senderId, widget.userId, text);
    
    setState(() {
      _messages.add({
        'text': text,
        'time': '${DateTime.now().hour.toString().padLeft(2, '0')}:${DateTime.now().minute.toString().padLeft(2, '0')}',
        'isMe': true,
      });
      _saveMessages();
      _messageController.clear();
      _isTypingMessage = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF4338CA), // Ana kırmızı
      body: SafeArea(
        bottom: false, // klavye açıldığında sorun olmasın diye
        child: Column(
          children: [
            // Kırmızı Header (App Bar)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: SocketService.getAvatarProvider(widget.userAvatar),
                        child: SocketService.getAvatarProvider(widget.userAvatar) == null ? const Icon(Icons.person) : null,
                      ),
                      if (widget.isOnline)
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent[400],
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF4338CA), width: 2),
                            ),
                          ),
                        )
                    ],
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.userName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Row(
                          children: [
                            if (widget.isOnline)
                              Container(
                                margin: const EdgeInsets.only(right: 4),
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  color: Colors.greenAccent[400],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            Text(
                              widget.isOnline ? 'Çevrimiçi' : 'Çevrimdışı',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.call, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.videocam, color: Colors.white),
                    onPressed: () {},
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
            
            // Beyaz İçerik (Sohbet Alanı)
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    // Tarih Etiketi
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: const Text(
                        '10 Ağustos 2026',
                        style: TextStyle(color: Colors.black54, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 15),
                    
                    // Mesajlar Listesi
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          
                          // Okunmamış mesaj ayracı (sadece demo için 4. indexten önce eklendi)
                          if (index == 4) {
                            return Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 15),
                                  child: Row(
                                    children: [
                                      Expanded(child: Divider(color: Colors.red[200])),
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 10),
                                        child: Text(
                                          'Okunmamış mesaj',
                                          style: TextStyle(color: Colors.red[400], fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                      Expanded(child: Divider(color: Colors.red[200])),
                                    ],
                                  ),
                                ),
                                _buildMessageBubble(msg, index),
                              ],
                            );
                          }
                          
                          return _buildMessageBubble(msg, index);
                        },
                      ),
                    ),
                    
                    // Alt Kısım: Mesaj Yazma Alanı
                    _buildMessageInputArea(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, int index) {
    bool isMe = msg['isMe'];
    bool isFile = msg['isFile'] ?? false;
    bool isEmoji = msg['isEmoji'] ?? false;
    
    return GestureDetector(
      onLongPress: () => _deleteMessage(index),
      child: Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isEmoji)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(15),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(msg['text'], style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 4),
                  Text(msg['time'], style: TextStyle(fontSize: 10, color: Colors.grey[500])),
                ],
              ),
            )
          else if (isFile)
            Container(
              width: MediaQuery.of(context).size.width * 0.65,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5), // Kırmızımsı açık ton
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.zero,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF4338CA),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.picture_as_pdf, color: Colors.white, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg['text'],
                              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
                            ),
                            Text(
                              msg['fileSize'],
                              style: const TextStyle(fontSize: 12, color: Colors.black54),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(msg['time'], style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      const SizedBox(width: 4),
                      const Icon(Icons.done_all, size: 14, color: Color(0xFF4338CA)),
                    ],
                  )
                ],
              ),
            )
          else
            Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.75,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFFFFE5E5) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(20),
                  topRight: const Radius.circular(20),
                  bottomLeft: isMe ? const Radius.circular(20) : Radius.zero,
                  bottomRight: isMe ? Radius.zero : const Radius.circular(20),
                ),
                border: isMe ? null : Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  if (!isMe)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    )
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    msg['text'],
                    style: const TextStyle(color: Colors.black87, fontSize: 14),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        msg['time'],
                        style: TextStyle(fontSize: 10, color: Colors.grey[500]),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all, size: 14, color: Color(0xFF4338CA)),
                      ]
                    ],
                  )
                ],
              ),
            )
        ],
      ),
    ));
  }

  Widget _buildMessageInputArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFFFE5E5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.attach_file, color: Color(0xFF4338CA)),
                onPressed: () {},
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(25),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: 'Mesajınızı yazın...',
                          border: InputBorder.none,
                        ),
                        onChanged: (text) {
                          setState(() {
                            _isTypingMessage = text.trim().isNotEmpty;
                          });
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.emoji_emotions_outlined, color: Colors.grey),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                color: Color(0xFF4338CA),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: Icon(_isTypingMessage ? Icons.send : Icons.mic, color: Colors.white),
                onPressed: () {
                  if (_isTypingMessage) {
                    _sendMessage();
                  } else {
                    // Ses kaydı mantığı
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
