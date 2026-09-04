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
  Function(List<dynamic>)? onShipsUpdated;
  Function(List<dynamic>)? onRadioUsersUpdated;
  Function(dynamic)? onRadioIncomingTalk;
  Function(dynamic)? onRadioAudioBroadcast;
  Function(dynamic)? onRadioTalkEnded;

  Map<String, dynamic>? activeRadioJoinData;
  String? _savedName;
  String? _savedAvatarUrl;

  void connect(String userId, String name, String? avatarUrl) {
    currentUserId = userId;
    _savedName = name;
    _savedAvatarUrl = avatarUrl;
    
    if (socket != null && socket!.connected) {
      socket!.emit('user_connected', {
        'userId': userId,
        'name': name,
        'avatarUrl': avatarUrl,
      });
      return;
    }

    socket = IO.io(serverUrl, <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket!.connect();

    socket!.onConnect((_) {
      print('Socket.io Sunucusuna bağlanıldı');
      socket!.emit('user_connected', {
        'userId': currentUserId ?? userId,
        'name': _savedName ?? name,
        'avatarUrl': _savedAvatarUrl ?? avatarUrl,
      });
      socket!.emit('request_ships_update');

      // Telsiz ekranında bulunuluyorsa odaya katılımı anında ilet
      if (activeRadioJoinData != null) {
        print('[SocketService] Telsiz kanalına otomatik bağlanılıyor: ${activeRadioJoinData!['channel']}');
        socket!.emit('radio_join', activeRadioJoinData);
      }
    });

    socket!.on('ships_update', (data) {
      if (data != null && data['ships'] != null) {
        final List<dynamic> shipList = data['ships'];
        if (onShipsUpdated != null) {
          onShipsUpdated!(shipList);
        }
      }
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

    // Telsiz Dinleyicileri
    socket!.on('radio_users_update', (data) {
      if (data != null && data['users'] != null) {
        final List<dynamic> users = List.from(data['users']);
        if (onRadioUsersUpdated != null) {
          onRadioUsersUpdated!(users);
        }
      }
    });

    socket!.on('radio_incoming_talk', (data) {
      if (onRadioIncomingTalk != null) {
        onRadioIncomingTalk!(data);
      }
    });

    socket!.on('radio_audio_broadcast', (data) {
      if (onRadioAudioBroadcast != null) {
        onRadioAudioBroadcast!(data);
      }
    });

    socket!.on('radio_talk_ended', (data) {
      if (onRadioTalkEnded != null) {
        onRadioTalkEnded!(data);
      }
    });

    socket!.onDisconnect((_) => print('Socket.io bağlantısı koptu'));
  }

  void joinRadio({
    required String userId,
    required String name,
    required String jobTitle,
    String? avatarUrl,
    String channel = '1',
  }) {
    activeRadioJoinData = {
      'userId': userId,
      'name': name,
      'jobTitle': jobTitle,
      'avatarUrl': avatarUrl,
      'channel': channel,
    };

    if (socket != null && socket!.connected) {
      socket!.emit('radio_join', activeRadioJoinData);
    } else {
      if (socket == null) {
        connect(userId, name, avatarUrl);
      } else if (!socket!.connected) {
        socket!.connect();
      }
    }
  }

  void requestRadioUsers({String channel = '1'}) {
    if (socket != null && socket!.connected) {
      socket!.emit('radio_get_users', {'channel': channel});
    }
  }

  void leaveRadio({required String userId, String channel = '1'}) {
    activeRadioJoinData = null;
    if (socket != null && socket!.connected) {
      socket!.emit('radio_leave', {
        'userId': userId,
        'channel': channel,
      });
    }
  }

  void startRadioTalk({required String userId, required String name, String channel = '1'}) {
    if (socket != null && socket!.connected) {
      socket!.emit('radio_start_talk', {
        'userId': userId,
        'name': name,
        'channel': channel,
      });
    }
  }

  void sendRadioAudioChunk({
    required String userId,
    required String name,
    required String audioBase64,
    String channel = '1',
  }) {
    if (socket != null && socket!.connected) {
      socket!.emit('radio_audio_chunk', {
        'userId': userId,
        'name': name,
        'audioBase64': audioBase64,
        'channel': channel,
      });
    }
  }

  void endRadioTalk({required String userId, required String name, String channel = '1'}) {
    if (socket != null && socket!.connected) {
      socket!.emit('radio_end_talk', {
        'userId': userId,
        'name': name,
        'channel': channel,
      });
    }
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

  void requestShipsUpdate() {
    if (socket != null && socket!.connected) {
      socket!.emit('request_ships_update');
    }
  }

  void disconnect() {
    if (socket != null) {
      socket!.disconnect();
    }
  }
}
