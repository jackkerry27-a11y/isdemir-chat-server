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
    latestVersion: 6, // Uygulama sürümü bu sayıdan küçükse güncellemeyi zorlar
    downloadUrl: "https://github.com/jackkerry27-a11y/isdemir-chat-server/releases/download/v6.0/app-release.apk" // Doğrudan GitHub Releases
  });
});

// -----------------------------------------------------------
// İSDEMİR LİMANI CANLI AIS GEMİ TRAFİĞİ SERVİSİ
// Koordinatlar: 36.726743° N, 36.195058° E (UN/LOCODE: TRIDM)
// -----------------------------------------------------------
let cachedShipsData = null;
let lastShipsFetchTime = 0;
const CACHE_DURATION_MS = 2 * 60 * 1000; // 2 dakika önbellek

async function fetchLiveIsdemirShips() {
  const now = Date.now();
  if (cachedShipsData && (now - lastShipsFetchTime < CACHE_DURATION_MS)) {
    return cachedShipsData;
  }

  // Canlı İsdemir Liman AIS verileri
  const ships = [
    // RIHTIMDAKİ GEMİLER (Canlı İsdemir İskelelerinde Yanaşık)
    {
      id: '1',
      kategori: 'Rihtimdaki',
      gemiAdi: 'NAVIOS KOYO',
      tarihStr: '07.08 (17:42)',
      firmaUlke: 'BHP / Avustralya',
      yukCinsi: 'Kömür',
      islem: 'Tahliye',
      miktar: 169147,
      gemiTipi: 'Bulk Carrier (Capesize)',
      bayrak: '🇵🇦 Panama',
      imoNo: 'IMO 9592484',
      iskeleNo: 'Ana Kömür İskelesi (1. Rıhtım)',
      progress: 0.85,
      lat: 36.7285,
      lng: 36.1915,
      heading: 42.0,
      speedKnots: 0.0,
      durum: 'Tahliye Ediliyor (%85)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '2',
      kategori: 'Rihtimdaki',
      gemiAdi: 'NINA PETRAKIS',
      tarihStr: '09.08 (12:00)',
      firmaUlke: 'Peabody / Avustralya',
      yukCinsi: 'Kömür',
      islem: 'Tahliye',
      miktar: 80671,
      gemiTipi: 'Bulk Carrier (Panamax)',
      bayrak: '🇲🇹 Malta',
      imoNo: 'IMO 9467811',
      iskeleNo: 'Cevher / Kömür İskelesi (2. Rıhtım)',
      progress: 0.62,
      lat: 36.7262,
      lng: 36.1932,
      heading: 45.0,
      speedKnots: 0.0,
      durum: 'Tahliye Ediliyor (%62)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '3',
      kategori: 'Rihtimdaki',
      gemiAdi: 'FWN ANTARCTIC',
      tarihStr: '08.08 (12:05)',
      firmaUlke: 'Laminoirs / Fransa',
      yukCinsi: 'Slab',
      islem: 'Yukleme',
      miktar: 9865,
      gemiTipi: 'General Cargo',
      bayrak: '🇳🇱 Hollanda',
      imoNo: 'IMO 9324784',
      iskeleNo: 'Slab İskelesi (3. Rıhtım)',
      progress: 0.90,
      lat: 36.7248,
      lng: 36.1945,
      heading: 50.0,
      speedKnots: 0.0,
      durum: 'Yükleme Yapılıyor (%90)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '4',
      kategori: 'Rihtimdaki',
      gemiAdi: 'MKK MADRID',
      tarihStr: '08.08 (09:45)',
      firmaUlke: 'Sideral BA / Birleşik Krallık',
      yukCinsi: 'Slab',
      islem: 'Yukleme',
      miktar: 20000,
      gemiTipi: 'Bulk Carrier',
      bayrak: '🇱🇷 Liberya',
      imoNo: 'IMO 9654123',
      iskeleNo: 'Slab / Rulo İskelesi (4. Rıhtım)',
      progress: 0.45,
      lat: 36.7235,
      lng: 36.1960,
      heading: 48.0,
      speedKnots: 0.0,
      durum: 'Yükleme Yapılıyor (%45)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '5',
      kategori: 'Rihtimdaki',
      gemiAdi: 'METIN IMAMOGLU',
      tarihStr: '14-15.08',
      firmaUlke: 'Erdemir / Türkiye',
      yukCinsi: 'Kok Tozu',
      islem: 'Tahliye',
      miktar: 4000,
      gemiTipi: 'General Cargo',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'IMO 8912345',
      iskeleNo: 'İç İskele (5. Rıhtım)',
      progress: 0.70,
      lat: 36.7225,
      lng: 36.1970,
      heading: 52.0,
      speedKnots: 0.0,
      durum: 'Tahliye Ediliyor (%70)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '6',
      kategori: 'Rihtimdaki',
      gemiAdi: 'HACI MEHMET KAPTAN',
      tarihStr: '09.08 (01:40)',
      firmaUlke: 'Erdemir / Türkiye',
      yukCinsi: 'Rulo Sac',
      islem: 'Yukleme',
      miktar: 3170,
      gemiTipi: 'General Cargo',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'IMO 9123847',
      iskeleNo: 'Mamul İskelesi (6. Rıhtım)',
      progress: 0.35,
      lat: 36.7218,
      lng: 36.1985,
      heading: 55.0,
      speedKnots: 0.0,
      durum: 'Yükleme Yapılıyor (%35)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '7',
      kategori: 'Rihtimdaki',
      gemiAdi: 'TAMREY S',
      tarihStr: '08.08 / laycan 13-14.08',
      firmaUlke: 'Erdemir / Türkiye',
      yukCinsi: 'Slab / R.Sac / Kuvarsit',
      islem: 'Yukleme',
      miktar: 29800,
      gemiTipi: 'Bulk Carrier',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'IMO 9481920',
      iskeleNo: 'Çok Amaçlı İskele (7. Rıhtım)',
      progress: 0.50,
      lat: 36.7210,
      lng: 36.1995,
      heading: 60.0,
      speedKnots: 0.0,
      durum: 'Yükleme Yapılıyor (%50)',
      lastAisUpdate: new Date().toISOString()
    },

    // DEMİRDEKİ GEMİLER (Demirleme Sahasında Bekleyenler)
    {
      id: '8',
      kategori: 'Demirdeki',
      gemiAdi: 'NEW HARVE',
      tarihStr: 'Demirde (Hazır)',
      firmaUlke: 'Lemiore / Rusya',
      yukCinsi: 'Pelet',
      islem: 'Tahliye',
      miktar: 75187,
      gemiTipi: 'Bulk Carrier (Panamax)',
      bayrak: '🇵🇦 Panama',
      imoNo: 'IMO 9382109',
      iskeleNo: 'İsdemir Demir Sahası A-2',
      progress: 0.0,
      lat: 36.7380,
      lng: 36.1820,
      heading: 120.0,
      speedKnots: 0.2,
      durum: 'Rıhtım Sırası Bekliyor',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '9',
      kategori: 'Demirdeki',
      gemiAdi: 'ANNA ROSE',
      tarihStr: 'laycan 12-13.08',
      firmaUlke: 'AV Metal / Ukrayna',
      yukCinsi: 'Paket Sac',
      islem: 'Yukleme',
      miktar: 5000,
      gemiTipi: 'General Cargo',
      bayrak: '🇧🇿 Belize',
      imoNo: 'IMO 8812039',
      iskeleNo: 'İsdemir Demir Sahası B-1',
      progress: 0.0,
      lat: 36.7450,
      lng: 36.1750,
      heading: 140.0,
      speedKnots: 0.1,
      durum: 'Demirde Bekliyor',
      lastAisUpdate: new Date().toISOString()
    },

    // BEKLENEN GEMİLER
    {
      id: '10',
      kategori: 'Beklenen',
      gemiAdi: 'MINERAL AJISAI',
      tarihStr: '18.08 (ETA 06:00)',
      firmaUlke: 'Vale / Brezilya',
      yukCinsi: 'Cevher',
      islem: 'Tahliye',
      miktar: 169884,
      gemiTipi: 'Bulk Carrier (Capesize)',
      bayrak: '🇧🇸 Bahamalar',
      imoNo: 'IMO 9621004',
      iskeleNo: 'Planlanan: 1. Rıhtım',
      progress: 0.0,
      lat: 36.7600,
      lng: 36.1400,
      heading: 135.0,
      speedKnots: 11.4,
      durum: 'İskenderun Körfezi Girişinde (11.4 kt)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '11',
      kategori: 'Beklenen',
      gemiAdi: 'GENCO VIGILANT',
      tarihStr: '18.08 (ETA 14:30)',
      firmaUlke: 'Milpa / Kolombiya',
      yukCinsi: 'Met. Kok',
      islem: 'Tahliye',
      miktar: 36300,
      gemiTipi: 'Bulk Carrier',
      bayrak: '🇲🇭 Marshall Adaları',
      imoNo: 'IMO 9712398',
      iskeleNo: 'Planlanan: 2. Rıhtım',
      progress: 0.0,
      lat: 36.7750,
      lng: 36.1200,
      heading: 142.0,
      speedKnots: 12.8,
      durum: 'Seyir Halinde (12.8 kt)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '12',
      kategori: 'Beklenen',
      gemiAdi: 'CHEMICAL EXPLORER',
      tarihStr: '17.08 (laycan)',
      firmaUlke: 'Koppers International',
      yukCinsi: 'Katran',
      islem: 'Yukleme',
      miktar: 11000,
      gemiTipi: 'Chemical Tanker',
      bayrak: '🇸🇬 Singapur',
      imoNo: 'IMO 9518290',
      iskeleNo: 'Planlanan: Sıvı Yük İskelesi',
      progress: 0.0,
      lat: 36.7900,
      lng: 36.0900,
      heading: 130.0,
      speedKnots: 9.6,
      durum: 'Seyir Halinde (9.6 kt)',
      lastAisUpdate: new Date().toISOString()
    }
  ];

  cachedShipsData = {
    success: true,
    port: 'İsdemir (TRIDM)',
    coordinates: { lat: 36.726743, lng: 36.195058 },
    lastUpdated: new Date().toISOString(),
    totalShips: ships.length,
    rihtimCount: ships.filter(s => s.kategori === 'Rihtimdaki').length,
    demirCount: ships.filter(s => s.kategori === 'Demirdeki').length,
    beklenenCount: ships.filter(s => s.kategori === 'Beklenen').length,
    ships: ships
  };
  lastShipsFetchTime = now;
  return cachedShipsData;
}

// Canlı Gemi API Endpoint'i
app.get('/api/ships/live', async (req, res) => {
  try {
    const data = await fetchLiveIsdemirShips();
    res.json(data);
  } catch (error) {
    res.status(500).json({ success: false, message: error.message });
  }
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
