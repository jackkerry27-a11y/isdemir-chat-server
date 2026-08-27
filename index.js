const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*", // Geliştirme ortamı için tüm kökenlere izin veriyoruz
  }
});

// Kullanıcı durumlarını hafızada tutuyoruz (Bağlı olan kullanıcılar)
// Map yapısı: { userId: { socketId, isOnline, lastSeen, profileData } }
const connectedUsers = new Map();

// Zorunlu Güncelleme (Force Update) için API
app.get('/version', (req, res) => {
  res.json({
    latestVersion: 4, // Uygulama sürümü bu sayıdan küçükse güncellemeyi zorlar
    downloadUrl: "https://mirror.ghproxy.com/https://github.com/jackkerry27-a11y/isdemir-chat-server/releases/download/v4.0/app-release.apk" // CDN Hızlandırılmış Link
  });
});

io.on('connection', (socket) => {
  console.log(`Yeni bir bağlantı: ${socket.id}`);

  // 1. Kullanıcı sisteme giriş yaptığında
  socket.on('user_connected', (userData) => {
    const userId = userData.userId;
    
    connectedUsers.set(userId, {
      socketId: socket.id,
      isOnline: true,
      lastSeen: new Date(),
      ...userData
    });

    console.log(`Kullanıcı aktif: ${userData.name} (${userId})`);
    io.emit('online_users_update', Array.from(connectedUsers.values()));
  });

  // 2. Mesaj gönderme olayı
  socket.on('send_message', (messageData) => {
    console.log(`Mesaj: ${messageData.senderId} -> ${messageData.receiverId}: ${messageData.content}`);
    
    // Mesajı gönderenin kendisine de yankıla (kendi ekranında görebilmesi için ya da lokal id ile yönetebilir)
    // Ama genelde client bunu kendisi halleder.

    const receiver = connectedUsers.get(messageData.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('receive_message', messageData);
    } else {
      console.log(`Alıcı ${messageData.receiverId} çevrimdışı.`);
    }
  });

  // 3. "Yazıyor..." durumu
  socket.on('typing', (data) => {
    const receiver = connectedUsers.get(data.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('typing_status', data);
    }
  });

  // 4. Bağlantı kesildiğinde
  socket.on('disconnect', () => {
    console.log(`Bağlantı koptu: ${socket.id}`);
    
    let disconnectedUserId = null;
    for (const [userId, user] of connectedUsers.entries()) {
      if (user.socketId === socket.id) {
        disconnectedUserId = userId;
        break;
      }
    }

    if (disconnectedUserId) {
      const user = connectedUsers.get(disconnectedUserId);
      user.isOnline = false;
      user.lastSeen = new Date();
      connectedUsers.set(disconnectedUserId, user);
      
      console.log(`Kullanıcı çevrimdışı: ${user.name}`);
      io.emit('online_users_update', Array.from(connectedUsers.values()));
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Sunucu http://localhost:${PORT} üzerinde çalışıyor`);
});
