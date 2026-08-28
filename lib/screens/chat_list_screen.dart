import 'package:flutter/material.dart';
import 'dart:io';
import '../models/user_model.dart';
import 'chat_detail_screen.dart';
import '../utils/socket_service.dart';

class ChatListScreen extends StatefulWidget {
  final UserModel user;
  const ChatListScreen({super.key, required this.user});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String _selectedFilter = 'Tümü';
  List<Map<String, dynamic>> _chats = [];

  @override
  void initState() {
    super.initState();
    _loadOnlineUsers(SocketService().onlineUsers);
    
    SocketService().onOnlineUsersUpdated = (users) {
      if (mounted) {
        setState(() {
          _loadOnlineUsers(users);
        });
      }
    };
  }

  void _loadOnlineUsers(List<dynamic> users) {
    // Kendi kullanıcımızı listeden çıkaralım
    String currentUserId = '${widget.user.firstName}_${widget.user.lastName}'.toLowerCase().replaceAll(' ', '_');
    
    _chats = users
        .where((u) => u['userId'] != currentUserId)
        .map((u) => {
              'userId': u['userId'],
              'name': u['name'],
              'message': 'Aktif, yazmak için dokunun...',
              'time': 'Şimdi',
              'unread': 0,
              'isOnline': true,
              'avatar': u['avatarUrl'], // Yerel dosya yolu olabilir
            })
        .toList()
        .cast<Map<String, dynamic>>();
  }

  @override
  Widget build(BuildContext context) {
    // Filtreleme işlemi
    List<Map<String, dynamic>> filteredChats = _chats;
    if (_selectedFilter == 'Okunmamış') {
      filteredChats = _chats.where((chat) => (chat['unread'] ?? 0) > 0).toList();
    }

    // Toplam okunmamış sayısı
    int totalUnread = _chats.where((c) => (c['unread'] ?? 0) > 0).length;

    return Scaffold(
      backgroundColor: const Color(0xFF4338CA), // Ana Kırmızı
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Kırmızı Header Kısmı
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Mesajlar',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.only(left: 28),
                        child: Text(
                          'Bağlantıda kalın, hızlı iletişimde olun.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Stack(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: Colors.grey[200],
                        backgroundImage: widget.user.photoPath != null ? FileImage(File(widget.user.photoPath!)) : null,
                        child: widget.user.photoPath == null ? const Icon(Icons.person, color: Color(0xFF4338CA)) : null,
                      ),
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
                ],
              ),
            ),
            const SizedBox(height: 10),
            // Beyaz İçerik Alanı
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
                    const SizedBox(height: 20),
                    // Arama Çubuğu
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 45,
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Kişi, grup veya mesaj ara...',
                                  hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
                                  prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            height: 45,
                            width: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.filter_list, color: Colors.grey[700]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Çipler (Tümü, Okunmamış)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: [
                          _buildFilterChip('Tümü', _chats.length),
                          const SizedBox(width: 10),
                          _buildFilterChip('Okunmamış', totalUnread),
                          const Spacer(),
                          Container(
                            height: 35,
                            width: 35,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.add, color: Colors.black54, size: 20),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    // Mesaj Listesi
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 10, bottom: 20),
                        itemCount: filteredChats.length,
                        itemBuilder: (context, index) {
                          final chat = filteredChats[index];
                          return _buildChatItem(chat, context);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int count) {
    bool isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF4338CA) : Colors.grey[100],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.white : Colors.grey[300],
                  shape: BoxShape.circle,
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    color: isSelected ? const Color(0xFF4338CA) : Colors.black54,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatItem(Map<String, dynamic> chat, BuildContext context) {
    bool isGroup = chat['isGroup'] == true;
    bool isSystem = chat['isSystem'] == true;
    
    return InkWell(
      onTap: () {
        if (!isGroup && !isSystem) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ChatDetailScreen(
                userId: chat['userId'] ?? '',
                userName: chat['name'],
                userAvatar: chat['avatar'],
                isOnline: chat['isOnline'],
              ),
            ),
          );
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: isGroup || isSystem ? const Color(0xFF4338CA) : Colors.grey[200],
                  backgroundImage: SocketService.getAvatarProvider(chat['avatar']?.toString()),
                  child: (isGroup)
                      ? const Icon(Icons.people, color: Colors.white)
                      : (isSystem ? const Icon(Icons.notifications, color: Colors.white) : 
                        (SocketService.getAvatarProvider(chat['avatar']?.toString()) == null ? const Icon(Icons.person, color: Colors.grey) : null)),
                ),
                if (!isGroup && !isSystem)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: chat['isOnline'] ? Colors.greenAccent[400] : Colors.grey[400],
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  )
              ],
            ),
            const SizedBox(width: 15),
            // İsim ve Mesaj
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    chat['name'],
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat['message'],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: chat['unread'] > 0 ? Colors.black87 : Colors.grey[500],
                      fontWeight: chat['unread'] > 0 ? FontWeight.w600 : FontWeight.normal,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            // Zaman ve Bildirim
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  chat['time'],
                  style: TextStyle(
                    color: chat['unread'] > 0 ? const Color(0xFF4338CA) : Colors.grey[400],
                    fontSize: 12,
                    fontWeight: chat['unread'] > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                const SizedBox(height: 6),
                if (chat['unread'] > 0)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: const BoxDecoration(
                      color: Color(0xFF4338CA),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      chat['unread'].toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
