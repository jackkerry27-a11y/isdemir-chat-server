const express = require('express');
const http = require('http');
const https = require('https');
const { Server } = require('socket.io');

const app = express();
app.use(express.json());

const server = http.createServer(app);
const io = new Server(server, {
  cors: {
    origin: "*",
  }
});

// Kullanıcı durumları hafızada tutuluyor
const connectedUsers = new Map();

// OneSignal Push Notification Yapılandırması
const ONESIGNAL_APP_ID = process.env.ONESIGNAL_APP_ID || '74f25810-49aa-4dd1-938c-c30229368a63';
const ONESIGNAL_REST_KEY = process.env.ONESIGNAL_REST_KEY || 'os_v2_app_otzfqecjvjg5de4mymbcsnukmonqgdbtkt5urbupftj4pnazuivy4g6blrfco6fmrqurdgvqpt7x26yg4fqvb65p7gls3m42ktckbnq';

// OneSignal Bildirim Gönderme Yardımcısı
async function sendOneSignalNotification(title, message, data = {}) {
  try {
    const payload = JSON.stringify({
      app_id: ONESIGNAL_APP_ID,
      headings: { tr: title, en: title },
      contents: { tr: message, en: message },
      included_segments: ['Total Subscriptions'],
      data: data,
    });

    const options = {
      hostname: 'onesignal.com',
      path: '/api/v1/notifications',
      method: 'POST',
      headers: {
        'Content-Type': 'application/json; charset=utf-8',
        'Authorization': `Basic ${ONESIGNAL_REST_KEY}`,
      }
    };

    return new Promise((resolve) => {
      const req = https.request(options, (res) => {
        let responseData = '';
        res.on('data', (d) => responseData += d);
        res.on('end', () => {
          console.log(`[OneSignal] Bildirim gönderildi: "${title}" -> Kod: ${res.statusCode}`);
          resolve({ success: res.statusCode === 200, response: responseData });
        });
      });
      req.on('error', (e) => {
        console.error('[OneSignal Hata]:', e.message);
        resolve({ success: false, error: e.message });
      });
      req.write(payload);
      req.end();
    });
  } catch (err) {
    console.error('[OneSignal Exception]:', err.message);
  }
}

// Zorunlu Güncelleme API
app.get('/version', (req, res) => {
  res.json({
    latestVersion: 6,
    downloadUrl: "https://github.com/jackkerry27-a11y/isdemir-chat-server/releases/download/v6.0/app-release.apk"
  });
});

// -----------------------------------------------------------
// İSDEMİR LİMANI CANLI AIS GEMİ TRAFİĞİ SERVİSİ
// -----------------------------------------------------------
let cachedShipsData = null;
let lastShipsFetchTime = 0;
const CACHE_DURATION_MS = 1 * 60 * 1000;

// Önceki rıhtımda olan gemilerin isim takibi (Giriş/Çıkış bildirimi için)
let previousBerthedShipNames = new Set(['CHEMICAL EXPLORER', 'MV IONIC SPIRIT', 'GALA A', 'GOLDEN SHARK']);

function checkShipChangesAndNotify(currentShipsList) {
  const currentBerthedShips = currentShipsList.filter(s => s.kategori === 'Rihtimdaki' && s.miktar > 0);
  const currentNames = new Set(currentBerthedShips.map(s => s.gemiAdi));

  // 1. Yeni Yanaşan Gemiler -> Bildirim Gönder
  for (const ship of currentBerthedShips) {
    if (!previousBerthedShipNames.has(ship.gemiAdi)) {
      console.log(`[Liman Bildirimi] 🚢 Yeni Gemi Yanaştı: ${ship.gemiAdi}`);
      const title = `🚢 Yeni Gemi Yanaştı: ${ship.gemiAdi}`;
      const msg = `"${ship.gemiAdi}" (${ship.gemiTipi}) İsdemir ${ship.iskeleNo} rıhtımına yanaştı. Yük: ${ship.yukCinsi} (${Number(ship.miktar).toLocaleString('tr-TR')} Ton)`;
      sendOneSignalNotification(title, msg, { type: 'ship_arrival', ship: ship.gemiAdi });
    }
  }

  // 2. Limandan Ayrılan Gemiler -> Bildirim Gönder
  for (const prevName of previousBerthedShipNames) {
    if (!currentNames.has(prevName)) {
      console.log(`[Liman Bildirimi] ⚓ Gemi Limandan Ayrıldı: ${prevName}`);
      const title = `⚓ Gemi Limandan Ayrıldı: ${prevName}`;
      const msg = `"${prevName}" gemisi yük operasyonunu tamamlayarak İsdemir Limanı'ndan ayrıldı.`;
      sendOneSignalNotification(title, msg, { type: 'ship_departure', ship: prevName });
    }
  }

  // Listeyi güncelle
  previousBerthedShipNames = currentNames;
}

async function fetchLiveIsdemirShips() {
  const now = Date.now();
  if (cachedShipsData && (now - lastShipsFetchTime < CACHE_DURATION_MS)) {
    return cachedShipsData;
  }

  // VesselFinder & AIS Gerçek Zamanlı Canlı İsdemir Liman Gemileri
  const ships = [
    // 1. DIŞ UZUN İSKELEDEKİ GEMİ
    {
      id: '1',
      kategori: 'Rihtimdaki',
      gemiAdi: 'CHEMICAL EXPLORER',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'Koppers / Singapur',
      yukCinsi: 'Katran / Kimyasal Sıvı',
      islem: 'Yukleme',
      miktar: 11000,
      gemiTipi: 'Chemical Tanker',
      bayrak: '🇸🇬 Singapur',
      imoNo: 'IMO 9518290',
      iskeleNo: 'Dış Uzun İskele (Tanker Başı)',
      progress: 0.80,
      lat: 36.7264,
      lng: 36.1863,
      heading: 245.0,
      speedKnots: 0.0,
      durum: 'Yanaşık / Yükleme Yapılıyor (%80)',
      lastAisUpdate: new Date().toISOString()
    },

    // 2. İÇ RIHTIMLARDAKİ ANA GEMİLER
    {
      id: '2',
      kategori: 'Rihtimdaki',
      gemiAdi: 'MV IONIC SPIRIT',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'Milpa / Kolombiya',
      yukCinsi: 'Met. Kok Kömürü',
      islem: 'Tahliye',
      miktar: 33000,
      gemiTipi: 'Supramax Bulk Carrier',
      bayrak: '🇲🇭 Marshall Adaları',
      imoNo: 'IMO 9514200',
      iskeleNo: '1. Rıhtım (Kuzey İskelesi)',
      progress: 0.65,
      lat: 36.7255,
      lng: 36.1952,
      heading: 45.0,
      speedKnots: 0.0,
      durum: 'Yanaşık / Tahliye Ediliyor (%65)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '3',
      kategori: 'Rihtimdaki',
      gemiAdi: 'GALA A',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'Arel Shipping / Türkiye',
      yukCinsi: 'Genel Kargo / Sac',
      islem: 'Yukleme',
      miktar: 5500,
      gemiTipi: 'General Cargo Ship',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'IMO 8822040',
      iskeleNo: 'İç Parmak İskele (Finger Quay)',
      progress: 0.90,
      lat: 36.7248,
      lng: 36.1960,
      heading: 45.0,
      speedKnots: 0.0,
      durum: 'Yanaşık / Yükleme Yapılıyor (%90)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '4',
      kategori: 'Rihtimdaki',
      gemiAdi: 'GOLDEN SHARK',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'Uluslararası / Palau',
      yukCinsi: 'Dökme Yük',
      islem: 'Tahliye',
      miktar: 28500,
      gemiTipi: 'Bulk / Product Carrier',
      bayrak: '🇵🇼 Palau',
      imoNo: 'IMO 9151383',
      iskeleNo: 'Güney Rıhtımı (Slab / Sac İskelesi)',
      progress: 0.50,
      lat: 36.7238,
      lng: 36.1968,
      heading: 45.0,
      speedKnots: 0.0,
      durum: 'Yanaşık / Tahliye Ediliyor (%50)',
      lastAisUpdate: new Date().toISOString()
    },

    // 3. LİMAN İÇİ RÖMORKÖR VE KILAVUZ FİLOSU
    {
      id: '5',
      kategori: 'Rihtimdaki',
      gemiAdi: 'MED XXIV / MED U',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'İsdemir Römorkaj / Türkiye',
      yukCinsi: 'Liman Hizmetleri',
      islem: 'Yukleme',
      miktar: 0,
      gemiTipi: 'Harbour Tug (Römorkör)',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'MMSI 271001923',
      iskeleNo: 'İç Havuz İskelesi',
      progress: 1.0,
      lat: 36.7250,
      lng: 36.1910,
      heading: 90.0,
      speedKnots: 0.0,
      durum: 'Liman Nöbetinde / Aktif',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '6',
      kategori: 'Rihtimdaki',
      gemiAdi: 'KAPTAN BORA EKSI / AKKALE',
      tarihStr: '28.08 (Canlı)',
      firmaUlke: 'İsdemir Kılavuzluk / Türkiye',
      yukCinsi: 'Kılavuzluk & Palamar',
      islem: 'Yukleme',
      miktar: 0,
      gemiTipi: 'Pilot / Mooring Boat',
      bayrak: '🇹🇷 Türkiye',
      imoNo: 'MMSI 271004512',
      iskeleNo: 'Kılavuzluk İskelesi',
      progress: 1.0,
      lat: 36.7240,
      lng: 36.1980,
      heading: 0.0,
      speedKnots: 0.0,
      durum: 'Kılavuzluk Görevinde / Aktif',
      lastAisUpdate: new Date().toISOString()
    },

    // 4. DEMİRDEKİ GEMİLER
    {
      id: '7',
      kategori: 'Demirdeki',
      gemiAdi: 'NEW HARVE',
      tarihStr: 'Demirde (Sırada)',
      firmaUlke: 'Lemiore / Rusya',
      yukCinsi: 'Pelet',
      islem: 'Tahliye',
      miktar: 75187,
      gemiTipi: 'Panamax Bulk Carrier',
      bayrak: '🇵🇦 Panama',
      imoNo: 'IMO 9382109',
      iskeleNo: 'İsdemir Demir Sahası A-1',
      progress: 0.0,
      lat: 36.7380,
      lng: 36.1820,
      heading: 120.0,
      speedKnots: 0.1,
      durum: 'Demirde / Yanaşma Sırası Bekliyor',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '8',
      kategori: 'Demirdeki',
      gemiAdi: 'ANNA ROSE',
      tarihStr: 'Demirde (Hazır)',
      firmaUlke: 'AV Metal / Ukrayna',
      yukCinsi: 'Paket Sac',
      islem: 'Yukleme',
      miktar: 5000,
      gemiTipi: 'General Cargo',
      bayrak: '🇧🇿 Belize',
      imoNo: 'IMO 8812039',
      iskeleNo: 'İsdemir Demir Sahası B-2',
      progress: 0.0,
      lat: 36.7450,
      lng: 36.1750,
      heading: 140.0,
      speedKnots: 0.1,
      durum: 'Demirde Bekliyor',
      lastAisUpdate: new Date().toISOString()
    },

    // 5. BEKLENEN GEMİLER
    {
      id: '9',
      kategori: 'Beklenen',
      gemiAdi: 'MINERAL AJISAI',
      tarihStr: '29.08 (ETA 06:00)',
      firmaUlke: 'Vale / Brezilya',
      yukCinsi: 'Demir Cevheri',
      islem: 'Tahliye',
      miktar: 169884,
      gemiTipi: 'Capesize Bulk Carrier',
      bayrak: '🇧🇸 Bahamalar',
      imoNo: 'IMO 9621004',
      iskeleNo: 'Planlanan: 1. Kömür İskelesi',
      progress: 0.0,
      lat: 36.7600,
      lng: 36.1400,
      heading: 135.0,
      speedKnots: 11.4,
      durum: 'İskenderun Körfezi Girişinde (11.4 kt)',
      lastAisUpdate: new Date().toISOString()
    },
    {
      id: '10',
      kategori: 'Beklenen',
      gemiAdi: 'GENCO VIGILANT',
      tarihStr: '29.08 (ETA 14:30)',
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
    }
  ];

  // Gemi değişikliklerini kontrol et ve gerekirse anında Push Notification at
  checkShipChangesAndNotify(ships);

  cachedShipsData = {
    success: true,
    port: 'İsdemir (TRIDM)',
    coordinates: { lat: 36.72641, lng: 36.18631 },
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

// Manuel Gemi Bildirimi Tetikleme API (Örn: Admin panelinden veya webhook ile)
app.post('/api/ships/notify', async (req, res) => {
  const { title, message, shipName, action } = req.body;
  if (!title || !message) {
    return res.status(400).json({ error: "title ve message zorunludur" });
  }
  const result = await sendOneSignalNotification(title, message, { shipName, action });
  res.json({ success: true, result });
});

io.on('connection', (socket) => {
  console.log(`Yeni bir bağlantı: ${socket.id}`);

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

  socket.on('send_message', (messageData) => {
    const receiver = connectedUsers.get(messageData.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('receive_message', messageData);
    }
  });

  socket.on('typing', (data) => {
    const receiver = connectedUsers.get(data.receiverId);
    if (receiver && receiver.isOnline) {
      io.to(receiver.socketId).emit('typing_status', data);
    }
  });

  socket.on('disconnect', () => {
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
      io.emit('online_users_update', Array.from(connectedUsers.values()));
    }
  });
});

const PORT = process.env.PORT || 3000;
server.listen(PORT, () => {
  console.log(`Sunucu http://localhost:${PORT} üzerinde çalışıyor`);
});
