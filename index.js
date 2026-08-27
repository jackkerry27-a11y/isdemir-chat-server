const express = require('express');
const http = require('http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*", // Geli┼ştirme ortam─▒ i├ğin t├╝m k├Âkenlere izin veriyoruz
  }
});

// Kullan─▒c─▒ durumlar─▒n─▒ haf─▒zada tutuyoruz (Ba─şl─▒ olan kullan─▒c─▒lar)
// Map yap─▒s─▒: { userId: { socketId, isOnline, lastSeen, profileData } }
const connectedUsers = new Map();

// Zorunlu G├╝ncelleme (Force Update) i├ğin API
app.get('/version', (req, res) => {
  res.json({
    latestVersion: 4, // Uygulama s├╝r├╝m├╝ bu say─▒dan k├╝├ğ├╝kse g├╝ncellemeyi zorlar
    downloadUrl: "https://github.com/jackkerry27-a11y/isdemir-chat-server/releases/download/v4.0/app-release.apk" // Dogrudan GitHub Releases
  });
});

io.on('connection', (socket) => {
  console.log(`Yeni bir ba─şlant─▒: ${socket.id}`);

  // 1. Kullan─▒c─▒ sisteme giri┼ş yapt─▒─ş─▒nda
  socket.on('user_connected', (userData) => {
    const userId = userData.userId;
    
    connectedUsers.set(userId, {
      socketId: socket.id,
      isOnline: true,
      lastSeen: new Date(),
      ...userData
    });

    console.log(`Kullan─▒c─▒ aktif: ${userData.name} (${userId})`);
    io.emit('online_users_update', Array.from(connectedUsers.values()));
  });

  // 2. Mesaj g├Ânderme olay─▒
  socket.on('send_message', (messageData) => {
    console.log(`Mesaj: ${messageData.senderId} -> ${messageData.receiverId}: ${messageData.content}`);
    
    // Mesaj─▒ g├Ânderenin kendisine de yank─▒la (kendi ekran─▒nda g├Ârebilmesi i├ğin ya da lokal id ile y├Ânetebilir)
    // Ama genelde client bunu kendisi halleder.

    const receiver = connectedUsers.get(messageData.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('receive_message', messageData);
    } else {
      console.log(`Al─▒c─▒ ${messageData.receiverId} ├ğevrimd─▒┼ş─▒.`);
    }
  });

  // 3. "Yaz─▒yor..." durumu
  socket.on('typing', (data) => {
    const receiver = connectedUsers.get(data.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('typing_status', data);
    }
  });

  // 4. Ba─şlant─▒ kesildi─şinde
  socket.on('disconnect', () => {
    console.log(`Ba─şlant─▒ koptu: ${socket.id}`);
    
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
      
      console.log(`Kullan─▒c─▒ ├ğevrimd─▒┼ş─▒: ${user.name}`);
      io.emit('online_users_update', Array.from(connectedUsers.values()));
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Sunucu http://localhost:${PORT} ├╝zerinde ├ğal─▒┼ş─▒yor`);
});
