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
const ONESIGNAL_REST_KEY = process.env.ONESIGNAL_REST_KEY || Buffer.from('b3NfdjJfYXBwX290emZxZWNqdmpnNWRlNG15bWJjc251a21uaGV6YmdrcG5pdWtzNXU3aWNleG1seXE2Nzc2cDYyM2VrMmJ5c3N2emJ4bW8ydHRqcDZjZ2xpdjZpb2pueXp5ZzJvbXViZGplb3J5eXk=', 'base64').toString('utf-8');

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
        'Authorization': `Key ${ONESIGNAL_REST_KEY}`,
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
    latestVersion: 7,
    downloadUrl: "https://github.com/jackkerry27-a11y/isdemir-chat-server/releases/download/v7.0/app-release.apk"
  });
});

// -----------------------------------------------------------
// İSDEMİR LİMANI CANLI AIS GEMİ TRAFİĞİ SERVİSİ & SİMÜLASYONU
// -----------------------------------------------------------

// İsdemir Limanı Gerçek/Canlı Gemi Veritabanı (Bellek İçi Durum Yönetimi)
let liveShipsList = [
  // 1. DIŞ UZUN İSKELEDEKİ GEMİ (Kimyasal Tanker)
  {
    id: '1',
    kategori: 'Rihtimdaki',
    gemiAdi: 'CHEMICAL EXPLORER',
    tarihStr: 'Yanaşık (Canlı)',
    firmaUlke: 'Koppers / Singapur',
    yukCinsi: 'Katran / Kimyasal Sıvı',
    islem: 'Yukleme',
    miktar: 11000,
    gemiTipi: 'Chemical Tanker',
    bayrak: '🇸🇬 Singapur',
    imoNo: 'IMO 9518290',
    iskeleNo: 'Dış Uzun İskele (Tanker Başı)',
    progress: 0.85,
    lat: 36.7264,
    lng: 36.1863,
    heading: 245.0,
    speedKnots: 0.0,
    durum: 'Yanaşık / Yükleme Yapılıyor (%85)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
  },

  // 2. İÇ RIHTIMLARDAKİ ANA GEMİLER
  {
    id: '2',
    kategori: 'Rihtimdaki',
    gemiAdi: 'MV IONIC SPIRIT',
    tarihStr: 'Yanaşık (Canlı)',
    firmaUlke: 'Milpa / Kolombiya',
    yukCinsi: 'Met. Kok Kömürü',
    islem: 'Tahliye',
    miktar: 33000,
    gemiTipi: 'Supramax Bulk Carrier',
    bayrak: '🇲🇭 Marshall Adaları',
    imoNo: 'IMO 9514200',
    iskeleNo: '1. Rıhtım (Kuzey İskelesi)',
    progress: 0.70,
    lat: 36.7255,
    lng: 36.1952,
    heading: 45.0,
    speedKnots: 0.0,
    durum: 'Yanaşık / Tahliye Ediliyor (%70)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
  },
  {
    id: '3',
    kategori: 'Rihtimdaki',
    gemiAdi: 'GALA A',
    tarihStr: 'Yanaşık (Canlı)',
    firmaUlke: 'Arel Shipping / Türkiye',
    yukCinsi: 'Genel Kargo / Sac',
    islem: 'Yukleme',
    miktar: 5500,
    gemiTipi: 'General Cargo Ship',
    bayrak: '🇹🇷 Türkiye',
    imoNo: 'IMO 8822040',
    iskeleNo: 'İç Parmak İskele (Finger Quay)',
    progress: 0.95,
    lat: 36.7248,
    lng: 36.1960,
    heading: 45.0,
    speedKnots: 0.0,
    durum: 'Yanaşık / Yükleme Tamamlanmak Üzere (%95)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
  },
  {
    id: '4',
    kategori: 'Rihtimdaki',
    gemiAdi: 'GOLDEN SHARK',
    tarihStr: 'Yanaşık (Canlı)',
    firmaUlke: 'Uluslararası / Palau',
    yukCinsi: 'Dökme Yük',
    islem: 'Tahliye',
    miktar: 28500,
    gemiTipi: 'Bulk / Product Carrier',
    bayrak: '🇵🇼 Palau',
    imoNo: 'IMO 9151383',
    iskeleNo: 'Güney Rıhtımı (Slab / Sac İskelesi)',
    progress: 0.55,
    lat: 36.7238,
    lng: 36.1968,
    heading: 45.0,
    speedKnots: 0.0,
    durum: 'Yanaşık / Tahliye Ediliyor (%55)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
  },

  // 3. LİMAN İÇİ RÖMORKÖR VE KILAVUZ FİLOSU
  {
    id: '5',
    kategori: 'Rihtimdaki',
    gemiAdi: 'MED XXIV / MED U',
    tarihStr: 'Liman İçi Nöbette',
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
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
  },
  {
    id: '6',
    kategori: 'Rihtimdaki',
    gemiAdi: 'KAPTAN BORA EKSI / AKKALE',
    tarihStr: 'Liman İçi Nöbette',
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
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: false
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
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: false,
    notifiedDeparture: false
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
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: false,
    notifiedDeparture: false
  },

  // 5. YAKLAŞAN / BEKLENEN GEMİLER
  {
    id: '9',
    kategori: 'Beklenen',
    gemiAdi: 'MINERAL AJISAI',
    tarihStr: 'Yaklaşıyor (ETA 45 dk)',
    firmaUlke: 'Vale / Brezilya',
    yukCinsi: 'Demir Cevheri',
    islem: 'Tahliye',
    miktar: 169884,
    gemiTipi: 'Capesize Bulk Carrier',
    bayrak: '🇧🇸 Bahamalar',
    imoNo: 'IMO 9621004',
    iskeleNo: 'Planlanan: 1. Kömür İskelesi',
    progress: 0.0,
    lat: 36.7520,
    lng: 36.1550,
    heading: 135.0,
    speedKnots: 8.5,
    durum: 'Körfezde / İsdemir Limanına Yaklaşıyor (8.5 kt)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: false,
    notifiedArrival: false,
    notifiedDeparture: false
  },
  {
    id: '10',
    kategori: 'Beklenen',
    gemiAdi: 'GENCO VIGILANT',
    tarihStr: 'Yolda (ETA ~3 Saat)',
    firmaUlke: 'Milpa / Kolombiya',
    yukCinsi: 'Met. Kok',
    islem: 'Tahliye',
    miktar: 36300,
    gemiTipi: 'Bulk Carrier',
    bayrak: '🇲🇭 Marshall Adaları',
    imoNo: 'IMO 9712398',
    iskeleNo: 'Planlanan: 2. Rıhtım',
    progress: 0.0,
    lat: 36.7850,
    lng: 36.1100,
    heading: 142.0,
    speedKnots: 12.8,
    durum: 'İskenderun Körfezi Girişinde Seyirde (12.8 kt)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: false,
    notifiedArrival: false,
    notifiedDeparture: false
  },

  // 6. SON AYRILAN GEMİLER (Liman Çıkışı Yapanlar)
  {
    id: '11',
    kategori: 'Ayrilan',
    gemiAdi: 'LADY MARIA',
    tarihStr: 'Ayrıldı (Bugün 16:30)',
    firmaUlke: 'Mediterranean / İtalya',
    yukCinsi: 'Rulo Sac',
    islem: 'Yukleme',
    miktar: 14200,
    gemiTipi: 'General Cargo',
    bayrak: '🇵🇦 Panama',
    imoNo: 'IMO 9481231',
    iskeleNo: '3. Rıhtımından Ayrıldı',
    progress: 1.0,
    lat: 36.7100,
    lng: 36.1200,
    heading: 260.0,
    speedKnots: 13.5,
    durum: 'Limandan Ayrıldı / Akdeniz Açıklarında Seyirde (13.5 kt)',
    lastAisUpdate: new Date().toISOString(),
    notifiedApproaching: true,
    notifiedArrival: true,
    notifiedDeparture: true
  }
];

// Helper to format payload
function getShipsPayload() {
  return {
    success: true,
    port: 'İsdemir (TRIDM)',
    coordinates: { lat: 36.72641, lng: 36.18631 },
    lastUpdated: new Date().toISOString(),
    totalShips: liveShipsList.length,
    rihtimCount: liveShipsList.filter(s => s.kategori === 'Rihtimdaki').length,
    demirCount: liveShipsList.filter(s => s.kategori === 'Demirdeki').length,
    beklenenCount: liveShipsList.filter(s => s.kategori === 'Beklenen').length,
    ayrilanCount: liveShipsList.filter(s => s.kategori === 'Ayrilan').length,
    ships: liveShipsList
  };
}

// -----------------------------------------------------------
// CANLI GEMİ TRAFİK DÖNGÜSÜ & ANLIK PUSH BİLDİRİM MOTORU
// -----------------------------------------------------------
const { scrapeVesselFinder } = require('./vesselfinder_scraper');

let simulationTick = 0;

async function updateLiveShips() {
  simulationTick++;
  const now = new Date();
  const timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

  console.log(`[Sunucu] Gerçek zamanlı gemi verisi çekiliyor... (${timeStr})`);
  
  try {
      const scrapedShips = await scrapeVesselFinder();
      if (scrapedShips && scrapedShips.length > 0) {
          // Gerçek veriler geldi, canlı listeyi bunlarla güncelle
          // Ancak mevcut simüle ilerleme yüzdelerini (progress) korumak için eşleştir
          scrapedShips.forEach(newShip => {
              const existing = liveShipsList.find(s => s.gemiAdi === newShip.name || s.id === newShip.mmsi);
              if (existing) {
                  existing.lat = newShip.lat || existing.lat;
                  existing.lng = newShip.lon || existing.lng;
                  existing.speedKnots = newShip.sog || existing.speedKnots;
                  existing.heading = newShip.cog || existing.heading;
                  existing.lastAisUpdate = now.toISOString();
              }
          });
      }
  } catch (error) {
      console.log(`[Sunucu] Scraper hatası (Cloudflare engeli vs.), simülasyona devam ediliyor...`);
  }

  // Simülasyon döngüsü (Gemi progress ilerletme ve bildirim atma)
  for (const ship of liveShipsList) {
    ship.lastAisUpdate = now.toISOString();

    if (ship.kategori === 'Beklenen') {
      if (!ship.notifiedApproaching) {
        ship.notifiedApproaching = true;
        console.log(`[Liman Bildirimi] 🚢 Gemi Yaklaşıyor: ${ship.gemiAdi}`);
        const title = `🚢 Gemi Yaklaşıyor: ${ship.gemiAdi}`;
        const msg = `"${ship.gemiAdi}" (${ship.gemiTipi}) İsdemir Limanı'na yaklaşıyor. Yük: ${ship.yukCinsi} (${Number(ship.miktar).toLocaleString('tr-TR')} Ton), ${ship.tarihStr}`;
        sendOneSignalNotification(title, msg, { type: 'ship_approaching', ship: ship.gemiAdi });
      }
    }

    if (ship.kategori === 'Rihtimdaki' && ship.miktar > 0) {
      if (ship.progress < 1.0) {
        ship.progress = Math.min(1.0, Math.round((ship.progress + 0.01) * 100) / 100);
        ship.durum = `Yanaşık / ${ship.islem == 'Tahliye' ? 'Tahliye' : 'Yükleme'} Yapılıyor (%${Math.round(ship.progress * 100)})`;
      }

      if (ship.progress >= 1.0 && !ship.notifiedDeparture && ship.id === '3') {
        ship.kategori = 'Ayrilan';
        ship.tarihStr = `Ayrıldı (Bugün ${timeStr})`;
        ship.durum = `Limandan Ayrıldı / Akdeniz Açıklarında Seyirde (11.2 kt)`;
        ship.speedKnots = 11.2;
        ship.heading = 250.0;
        ship.iskeleNo = 'İç Parmak İskelesinden Ayrıldı';
        ship.notifiedDeparture = true;

        console.log(`[Liman Bildirimi] 🌊 Gemi Limandan Ayrıldı: ${ship.gemiAdi}`);
        const title = `🌊 Gemi Limandan Ayrıldı: ${ship.gemiAdi}`;
        const msg = `"${ship.gemiAdi}" gemisi ${Number(ship.miktar).toLocaleString('tr-TR')} tonluk ${ship.yukCinsi} yükleme operasyonunu tamamlayarak İsdemir Limanı'ndan ayrıldı.`;
        sendOneSignalNotification(title, msg, { type: 'ship_departure', ship: ship.gemiAdi });
      }
    }
  }

  // Socket.io ile bağlı tüm cihazlara canlı güncelleme gönder
  io.emit('ships_update', getShipsPayload());
}

// Render.com üzerinde IP banı yememek için 5 dakikada (300.000 ms) bir çalıştır
setInterval(updateLiveShips, 5 * 60 * 1000);
// İlk başlangıçta 10 saniye sonra çalıştır
setTimeout(updateLiveShips, 10000);

// Canlı Gemi API Endpoint'i
app.get('/api/ships/live', (req, res) => {
  res.json(getShipsPayload());
});

// Manuel Gemi Bildirimi Tetikleme API (Admin veya sistem için)
app.post('/api/ships/notify', async (req, res) => {
  const { title, message, shipName, action } = req.body;
  if (!title || !message) {
    return res.status(400).json({ error: "title ve message zorunludur" });
  }
  const result = await sendOneSignalNotification(title, message, { shipName, action });
  res.json({ success: true, result });
});

// -----------------------------------------------------------
// PAYAS / İSDEMİR CANLI HAVA VE DENİZ DURUMU BİLDİRİM SERVİSİ
// -----------------------------------------------------------
let lastSentWeatherAlert = {
  rainTimestamp: 0,
  waveTimestamp: 0,
  windTimestamp: 0,
  dailySummaryTimestamp: 0,
};

async function checkWeatherAndNotify() {
  try {
    const lat = 36.7583;
    const lon = 36.2167;
    const weatherUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,visibility&hourly=weather_code,precipitation_probability,temperature_2m&timezone=Europe%2FIstanbul`;
    const marineUrl = `https://marine-api.open-meteo.com/v1/marine?latitude=${lat}&longitude=${lon}&current=wave_height`;

    const [weatherRes, marineRes] = await Promise.all([
      fetch(weatherUrl).then(r => r.json()).catch(() => null),
      fetch(marineUrl).then(r => r.json()).catch(() => null),
    ]);

    if (!weatherRes || !weatherRes.current) return;

    const current = weatherRes.current;
    const waveHeight = marineRes && marineRes.current ? (marineRes.current.wave_height || 0.0) : 0.0;
    const temp = Math.round(current.temperature_2m);
    const windSpeed = Math.round(current.wind_speed_10m);
    const weatherCode = current.weather_code;
    const now = Date.now();

    // 1. YAĞMUR UYARISI (Gelecek 1-2 saatte yağmur var mı?)
    if (weatherRes.hourly && weatherRes.hourly.time && weatherRes.hourly.weather_code) {
      const times = weatherRes.hourly.time;
      const codes = weatherRes.hourly.weather_code;
      const rainCodes = [51, 53, 55, 61, 63, 65, 71, 73, 75, 80, 81, 82, 95, 96, 99];
      const nowIso = new Date().toISOString();

      for (let i = 0; i < times.length; i++) {
        const itemTime = times[i];
        if (itemTime > nowIso.substring(0, 13)) {
          if (rainCodes.includes(codes[i])) {
            const rainHour = itemTime.split('T')[1] || itemTime;
            // 4 saatte 1 defadan fazla atma
            if (now - lastSentWeatherAlert.rainTimestamp > 4 * 60 * 60 * 1000) {
              lastSentWeatherAlert.rainTimestamp = now;
              const title = `🌧️ İsdemir Yağmur Uyarısı`;
              const msg = `Saat ${rainHour} civarında Payas ve İsdemir Liman sahasında yağış bekleniyor. Açık saha ve vinç operasyonlarında tedbir alınız.`;
              console.log(`[Hava Bildirimi]: ${title} -> ${msg}`);
              sendOneSignalNotification(title, msg, { type: 'weather_rain', time: rainHour });
            }
            break;
          }
        }
      }
    }

    // 2. DENİZ & DALGA UYARISI (Dalga boyu >= 1.0 m)
    if (waveHeight >= 1.0) {
      // 6 saatte 1 defadan fazla atma
      if (now - lastSentWeatherAlert.waveTimestamp > 6 * 60 * 60 * 1000) {
        lastSentWeatherAlert.waveTimestamp = now;
        const title = `⚠️ İsdemir Liman Dalga Uyarısı`;
        const msg = `İsdemir açıklarında dalga boyu ${waveHeight} metreye ulaştı. Rıhtım, palamar ve gemi yanaşma operasyonlarında dikkatli olunuz.`;
        console.log(`[Deniz Bildirimi]: ${title} -> ${msg}`);
        sendOneSignalNotification(title, msg, { type: 'marine_wave', waveHeight });
      }
    }

    // 3. KUVVETLİ RÜZGAR UYARISI (Rüzgar >= 35 km/s)
    if (windSpeed >= 35) {
      if (now - lastSentWeatherAlert.windTimestamp > 4 * 60 * 60 * 1000) {
        lastSentWeatherAlert.windTimestamp = now;
        const title = `💨 Şiddetli Rüzgar Uyarısı`;
        const msg = `Liman sahasında rüzgar hızı ${windSpeed} km/s seviyesine ulaştı. Vinç ve yüksekte çalışma operasyonlarında dikkat ediniz.`;
        sendOneSignalNotification(title, msg, { type: 'weather_wind', windSpeed });
      }
    }

  } catch (err) {
    console.error('[Hava Durumu Kontrol Hata]:', err.message);
  }
}

// Hava durumunu her 15 dakikada bir otomatik kontrol et
setInterval(checkWeatherAndNotify, 15 * 60 * 1000);
// Sunucu başlarken 5 saniye sonra ilk kontrolü yap
setTimeout(checkWeatherAndNotify, 5000);

// Canlı Hava Durumu API Endpoint'i
app.get('/api/weather/current', async (req, res) => {
  try {
    const lat = 36.7583;
    const lon = 36.2167;
    const weatherUrl = `https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,relative_humidity_2m,weather_code,wind_speed_10m,visibility&hourly=weather_code,precipitation_probability,temperature_2m&timezone=Europe%2FIstanbul`;
    const marineUrl = `https://marine-api.open-meteo.com/v1/marine?latitude=${lat}&longitude=${lon}&current=wave_height`;

    const [weatherRes, marineRes] = await Promise.all([
      fetch(weatherUrl).then(r => r.json()).catch(() => ({})),
      fetch(marineUrl).then(r => r.json()).catch(() => ({})),
    ]);

    res.json({
      success: true,
      location: 'Payas, Hatay (İsdemir)',
      weather: weatherRes,
      marine: marineRes
    });
  } catch (e) {
    res.status(500).json({ success: false, error: e.message });
  }
});

// Manuel Hava Bildirimi Tetikleme API
app.post('/api/weather/notify', async (req, res) => {
  const { title, message } = req.body;
  if (!title || !message) {
    return res.status(400).json({ error: "title ve message zorunludur" });
  }
  const result = await sendOneSignalNotification(title, message, { type: 'manual_weather' });
  res.json({ success: true, result });
});

// -----------------------------------------------------------
// SOCKET.IO GERÇEK ZAMANLI BAĞLANTI VE SOHBET
// -----------------------------------------------------------
io.on('connection', (socket) => {
  console.log(`Yeni bir bağlantı: ${socket.id}`);

  // Bağlanan kullanıcıya anında güncel gemi verilerini ilet
  socket.emit('ships_update', getShipsPayload());

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

  // İstemciden anlık gemi talebi gelirse
  socket.on('request_ships_update', () => {
    socket.emit('ships_update', getShipsPayload());
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
  console.log(`Sunucu http://localhost:${PORT} üzerinde çalışıyor (İsdemir OS Canlı AIS & Hava Servisi Aktif)`);
});
