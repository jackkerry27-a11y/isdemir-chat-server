import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../main.dart';

class SocketService {
  // Singleton pattern
  static final SocketService _instance = SocketService._internal();
  factory SocketService() => _instance;
  SocketService._internal();

  IO.Socket? socket;
  List<dynamic> onlineUsers = [];
  String? currentUserId;
  static const String serverUrl = 'https://isdemir-chat-server.onrender.com';
  
  static ImageProvider? getAvatarProvider(String? avatarUrl) {
    if (avatarUrl == null || avatarUrl.isEmpty) return null;
    try {
      if (avatarUrl.startsWith('http')) {
        return NetworkImage(avatarUrl);
      } else if (avatarUrl.startsWith('base64:')) {
        return MemoryImage(base64Decode(avatarUrl.substring(7)));
      } else {
        final file = File(avatarUrl);
        if (file.existsSync()) {
          return FileImage(file);
        } else {
          return null;
        }
      }
    } catch (e) {
      return null;
    }
  }
  
  // Callbackler
  Function(List<dynamic>)? onOnlineUsersUpdated;
  Function(dynamic)? onMessageReceived;
  Function(dynamic)? onTypingStatusReceived;

  void connect(String userId, String name, String? avatarUrl) {
    currentUserId = userId;
    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('Socket.io Sunucusuna bağlanıldı');
      socket!.emit('user_connected', {
        'userId': userId,
        'name': name,
        'avatarUrl': avatarUrl,
      });
    });

    socket!.on('online_users_update', (data) {
      onlineUsers = List.from(data);
      if (onOnlineUsersUpdated != null) {
        onOnlineUsersUpdated!(onlineUsers);
      }
    });

    socket!.on('receive_message', (data) {
      if (onMessageReceived != null) {
        onMessageReceived!(data);
      }
      if (globalMessengerKey.currentContext != null && data['senderId'] != currentUserId) {
        final screenHeight = MediaQuery.of(globalMessengerKey.currentContext!).size.height;
        globalMessengerKey.currentState!.showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.message, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(child: Text('Yeni Mesaj: ${data['content']}')),
              ],
            ),
            backgroundColor: const Color(0xFF4338CA),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: EdgeInsets.only(
              bottom: screenHeight - 150, // Üstte görünmesi için
              left: 10, 
              right: 10
            ),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'KAPAT',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );
      }
    });

    socket!.on('typing_status', (data) {
      if (onTypingStatusReceived != null) {
        onTypingStatusReceived!(data);
      }
    });

    socket!.onDisconnect((_) => print('Socket.io bağlantısı koptu'));
  }

  void sendMessage(String senderId, String receiverId, String content) {
    if (socket != null && socket!.connected) {
      final messageData = {
        'senderId': senderId,
        'receiverId': receiverId,
        'content': content,
        'timestamp': DateTime.now().toIso8601String(),
      };
      socket!.emit('send_message', messageData);
    }
  }

  void sendTypingStatus(String senderId, String receiverId, bool isTyping) {
    if (socket != null && socket!.connected) {
      socket!.emit('typing', {
        'senderId': senderId,
        'receiverId': receiverId,
        'isTyping': isTyping,
      });
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
    }
  }
}
