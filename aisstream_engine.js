/**
 * İsdemir Limanı ve İskenderun Körfezi Canlı AIS Takip Motoru (AisStream.io)
 * Gerçek zamanlı WebSocket akışı üzerinden kesintisiz veri alır ve Firestore'u günceller.
 */

const https = require('https');

const AIS_WS_URL = 'wss://stream.aisstream.io/v0/stream';
const AIS_API_KEY = process.env.AISSTREAM_API_KEY || 'd281e17e9cfa5d1f5eede1fbdc05d4da0d2882fa';

const FIREBASE_API_KEY = 'AIzaSyDvf6cKildF6QwHduR9aDREoTtay609MEA';
const PROJECT_ID = 'isdemirops';

// 1-5 Rıhtımların Koordinatları
const BERTHS = [
  {
    no: '1',
    name: '1. Rıhtım (Dış Uzun İskele)',
    centerLat: 36.7270,
    centerLng: 36.1880,
    latMin: 36.7250,
    latMax: 36.7300,
    lngMin: 36.1830,
    lngMax: 36.1930
  },
  {
    no: '2',
    name: '2. Rıhtım (İç Kuzey Rıhtımı)',
    centerLat: 36.7320,
    centerLng: 36.1962,
    latMin: 36.7312,
    latMax: 36.7335,
    lngMin: 36.1950,
    lngMax: 36.1975
  },
  {
    no: '3',
    name: '3. Rıhtım (İç Parmak İskele)',
    centerLat: 36.7304,
    centerLng: 36.1965,
    latMin: 36.7295,
    latMax: 36.7314,
    lngMin: 36.1955,
    lngMax: 36.1980
  },
  {
    no: '4',
    name: '4. Rıhtım (Güneybatı Rıhtımı)',
    centerLat: 36.7283,
    centerLng: 36.1965,
    latMin: 36.7275,
    latMax: 36.7290,
    lngMin: 36.1955,
    lngMax: 36.1970
  },
  {
    no: '5',
    name: '5. Rıhtım (Güneydoğu Rıhtımı)',
    centerLat: 36.7280,
    centerLng: 36.1973,
    latMin: 36.7270,
    latMax: 36.7288,
    lngMin: 36.1970,
    lngMax: 36.1985
  }
];

// İsdemir Demir Sahası (Anchorage Area)
const ANCHORAGE_ZONE = {
  name: 'İsdemir Demir Sahası (Açıkta Bekleme)',
  centerLat: 36.761552,
  centerLng: 36.136181,
  radiusKm: 8.5
};

// Mendirek & Liman Giriş-Çıkış Kapısı (Gate Checkpoint)
const PORT_GATE = {
  name: 'İsdemir Mendirek & Liman Kapısı',
  lat: 36.724951,
  lng: 36.187179,
  minLat: 36.7230,
  maxLat: 36.7360,
  minLng: 36.187179,
  maxLng: 36.2050
};

function calculateDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371; // km
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLon = (lon2 - lon1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
            Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
            Math.sin(dLon / 2) * Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return R * c;
}

function isInsidePort(lat, lng, berthNo = null) {
  if (berthNo) return true;
  return lat >= PORT_GATE.minLat && lat <= PORT_GATE.maxLat && lng >= PORT_GATE.lng && lng <= PORT_GATE.maxLng;
}

// Bilinen Ticari Gemilerin Resmi Tonaj Bilgileri
const KNOWN_VESSEL_PARTICULARS = {
  '249489000': { dwt: '208,000 DWT', gt: '115,000 GT', type: 'Newcastlemax Bulk Carrier' },
  '255727000': { dwt: '31,603 DWT', gt: '19,883 GT', type: 'Handysize Bulk Carrier' },
  '370126000': { dwt: '16,383 DWT', gt: '9,967 GT', type: 'General Cargo' },
  '352002310': { dwt: '31,603 DWT', gt: '19,883 GT', type: 'Bulk Carrier' },
  '271002044': { dwt: '3,270 DWT', gt: '1,995 GT', type: 'General Cargo' },
  '271044600': { dwt: '31,024 DWT', gt: '19,069 GT', type: 'Bulk Carrier' },
  '271002598': { dwt: '3,375 DWT', gt: '1,997 GT', type: 'General Cargo' },
  '271049621': { dwt: '6,097 DWT', gt: '4,109 GT', type: 'General Cargo' },
  '351381000': { dwt: '11,200 DWT', gt: '7,150 GT', type: 'General Cargo' },
  '271044425': { dwt: '5,400 DWT', gt: '3,200 GT', type: 'General Cargo' },
  '304010760': { dwt: '12,500 DWT', gt: '7,800 GT', type: 'General Cargo' },
  '341063002': { dwt: '24,000 DWT', gt: '15,200 GT', type: 'Bulk Carrier' },
  '538004785': { dwt: '34,000 DWT', gt: '21,000 GT', type: 'Handysize Bulk Carrier' },
  '636022464': { dwt: '38,000 DWT', gt: '23,500 GT', type: 'Bulk Carrier' },
  '636024910': { dwt: '33,000 DWT', gt: '20,500 GT', type: 'Bulk Carrier' },
  '538009260': { dwt: '35,000 DWT', gt: '22,000 GT', type: 'Bulk Carrier' },
  '538012423': { dwt: '28,000 DWT', gt: '17,500 GT', type: 'Bulk Carrier' },
  '376786000': { dwt: '18,500 DWT', gt: '11,000 GT', type: 'General Cargo' },
  '352006086': { dwt: '14,000 DWT', gt: '8,500 GT', type: 'General Cargo' },
  '271000833': { dwt: '4,500 DWT', gt: '2,800 GT', type: 'General Cargo' },
  '352005284': { dwt: '7,500 DWT', gt: '4,600 GT', type: 'General Cargo' },
  '341989001': { dwt: '4,200 DWT', gt: '2,600 GT', type: 'General Cargo' },
};

function getVesselTonnage(mmsi, length, beam) {
  if (mmsi && KNOWN_VESSEL_PARTICULARS[mmsi]) {
    return KNOWN_VESSEL_PARTICULARS[mmsi];
  }
  if (!length || !beam || length <= 0 || beam <= 0) return { dwt: 'Belirtilmedi', gt: '' };
  let estimatedDwt = 0;
  if (length >= 200) {
    estimatedDwt = Math.round(length * beam * 13.5 * 0.82 * 1.025 / 100) * 100;
  } else if (length >= 120) {
    estimatedDwt = Math.round(length * beam * 8.5 * 0.77 * 1.025 / 100) * 100;
  } else if (length >= 80) {
    estimatedDwt = Math.round(length * beam * 6.5 * 0.73 * 1.025 / 50) * 50;
  } else {
    estimatedDwt = Math.round(length * beam * 4.8 * 0.70 * 1.025 / 10) * 10;
  }
  const estimatedGt = Math.round(estimatedDwt * 0.62 / 10) * 10;
  return {
    dwt: `${estimatedDwt.toLocaleString('tr-TR')} DWT`,
    gt: `${estimatedGt.toLocaleString('tr-TR')} GT`
  };
}

// Canlı hafıza havuzu
const activeVessels = new Map(); // mmsi -> Vessel object
const previousVesselStates = new Map(); // mmsi -> { name, speed, lat, lng, berthNo, lastSeen }
const notifiedEvents = new Set();
let socketConnection = null;
let isConnected = false;
let notificationCallback = null;

// Firestore REST İstemcisi
function firestoreRequest(path, method = 'GET', body = null) {
  return new Promise((resolve, reject) => {
    const url = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}?key=${FIREBASE_API_KEY}`;
    const urlObj = new URL(url);

    const options = {
      hostname: urlObj.hostname,
      path: urlObj.pathname + urlObj.search,
      method: method,
      headers: {
        'Content-Type': 'application/json',
      }
    };

    const req = https.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve(data);
          }
        } else {
          reject(new Error(`Firestore ${method} ${path} failed: ${res.statusCode} ${data}`));
        }
      });
    });

    req.on('error', (err) => reject(err));
    if (body) {
      req.write(JSON.stringify(body));
    }
    req.end();
  });
}

async function getFirestoreShips() {
  try {
    const res = await firestoreRequest('gemiler');
    if (!res || !res.documents) return [];
    return res.documents.map(doc => {
      const fields = doc.fields || {};
      const id = doc.name.split('/').pop();
      return {
        id,
        gemiAdi: fields.gemiAdi?.stringValue || '',
        rihtimNo: fields.rihtimNo?.stringValue || '',
        durum: fields.durum?.stringValue || '',
        yukCinsi: fields.yukCinsi?.stringValue || '',
        mmsi: fields.mmsi?.stringValue || '',
        speedKnots: fields.speedKnots?.doubleValue || parseFloat(fields.speedKnots?.integerValue) || 0,
      };
    });
  } catch (e) {
    console.error('[AisStream-Firestore] Veri okuma hatası:', e.message);
    return [];
  }
}

async function upsertFirestoreShip(docId, fields) {
  const firestoreFields = {};
  for (const [key, value] of Object.entries(fields)) {
    if (typeof value === 'string') {
      firestoreFields[key] = { stringValue: value };
    } else if (typeof value === 'number') {
      firestoreFields[key] = Number.isInteger(value) ? { integerValue: value.toString() } : { doubleValue: value };
    } else if (typeof value === 'boolean') {
      firestoreFields[key] = { booleanValue: value };
    } else if (value instanceof Date) {
      firestoreFields[key] = { timestampValue: value.toISOString() };
    }
  }
  return firestoreRequest(`gemiler/${docId}`, 'PATCH', { fields: firestoreFields });
}

// Rıhtım Eşleştirme Algoritması
function matchVesselsToBerths(vessels) {
  const berthStatus = {
    '1': { berth: BERTHS[0], occupied: false, ship: null },
    '2': { berth: BERTHS[1], occupied: false, ship: null },
    '3': { berth: BERTHS[2], occupied: false, ship: null },
    '4': { berth: BERTHS[3], occupied: false, ship: null },
    '5': { berth: BERTHS[4], occupied: false, ship: null }
  };

  const commercialVessels = vessels.filter(v => v.isCommercial);

  for (const ship of commercialVessels) {
    let matchedBerthNo = null;

    // 1. Kural: Bounding box içinde mi?
    for (const b of BERTHS) {
      if (ship.lat >= b.latMin && ship.lat <= b.latMax && ship.lng >= b.lngMin && ship.lng <= b.lngMax) {
        matchedBerthNo = b.no;
        break;
      }
    }

    // 2. Kural: 350 metre yakınlık testi
    if (!matchedBerthNo) {
      let minDistance = Infinity;
      let closestBerth = null;
      for (const b of BERTHS) {
        const dist = Math.sqrt(Math.pow(ship.lat - b.centerLat, 2) + Math.pow(ship.lng - b.centerLng, 2));
        if (dist < minDistance && dist < 0.0035) {
          minDistance = dist;
          closestBerth = b.no;
        }
      }
      matchedBerthNo = closestBerth;
    }

    if (matchedBerthNo && !berthStatus[matchedBerthNo].occupied) {
      berthStatus[matchedBerthNo].occupied = true;
      berthStatus[matchedBerthNo].ship = ship;
      ship.berthNo = matchedBerthNo;
    }
  }

  return berthStatus;
}

// AisStream.io WebSocket Akışını Başlatır (Kesintisiz Arkaplan Bağlantısı)
function startAisStreamEngine(onNotification = null) {
  notificationCallback = onNotification;

  console.log('[AisStream] Canlı WebSocket servisi başlatılıyor...');
  try {
    const ws = new WebSocket(AIS_WS_URL);
    socketConnection = ws;

    ws.onopen = () => {
      isConnected = true;
      console.log('[AisStream] WebSocket bağlandı. Doğu Akdeniz & İskenderun Körfezi abone olunuyor...');
      const subMsg = {
        APIKey: AIS_API_KEY,
        BoundingBoxes: [
          [
            [34.00, 32.00],
            [37.50, 36.50]
          ]
        ]
      };
      ws.send(JSON.stringify(subMsg));
    };

    ws.onmessage = (event) => {
      try {
        let raw = event.data;
        let text;
        if (typeof raw === 'string') {
          text = raw;
        } else if (Buffer.isBuffer(raw)) {
          text = raw.toString('utf8');
        } else if (raw instanceof ArrayBuffer) {
          text = Buffer.from(raw).toString('utf8');
        } else {
          text = raw.toString();
        }

        const data = JSON.parse(text);
        handleAisMessage(data);
      } catch (err) {
        // Sessiz json hatası
      }
    };

    ws.onerror = (err) => {
      console.warn('[AisStream Uyarısı]:', err.message || err);
    };

    ws.onclose = () => {
      isConnected = false;
      console.log('[AisStream] Bağlantı kapandı. 5 saniye içinde yeniden bağlanılacak...');
      setTimeout(() => startAisStreamEngine(notificationCallback), 5000);
    };
  } catch (e) {
    console.error('[AisStream Başlatma Hatası]:', e.message);
    setTimeout(() => startAisStreamEngine(notificationCallback), 10000);
  }
}

// Gelen AIS Paketini İşleme
function handleAisMessage(data) {
  const msgType = data.MessageType;
  const meta = data.MetaData;
  if (!meta) return;

  const mmsi = meta.MMSI?.toString();
  if (!mmsi) return;

  const rawName = meta.ShipName || '';
  const name = rawName.trim();
  const lat = meta.latitude || meta.Latitude;
  const lng = meta.longitude || meta.Longitude;

  if (typeof lat !== 'number' || typeof lng !== 'number') return;

  // İskenderun Körfezi & Yaklaşımları filtresi (lat: 36.35 - 37.00, lng: 35.50 - 36.35)
  const isNearIskenderun = (lat >= 36.35 && lat <= 37.05 && lng >= 35.50 && lng <= 36.40);
  if (!isNearIskenderun) return;

  let vessel = activeVessels.get(mmsi);
  if (!vessel) {
    const isService = name.startsWith('MED ') || name.startsWith('BABAKALE') || name.includes('BORA EKSI') || name.includes('KAPTAN SAYIM') || name.includes('PILOT') || name.includes('TUG');
    vessel = {
      mmsi,
      name: name || `MMSI: ${mmsi}`,
      lat,
      lng,
      speedKnots: 0.0,
      heading: 0.0,
      length: 0,
      beam: 0,
      dest: '',
      eta: '',
      vtype: 70,
      isService,
      isCommercial: !isService,
      lastSeen: new Date(),
    };
    activeVessels.set(mmsi, vessel);
  }

  vessel.lat = lat;
  vessel.lng = lng;
  vessel.lastSeen = new Date();
  if (name && name.length > 1) vessel.name = name;

  if (msgType === 'PositionReport' && data.Message?.PositionReport) {
    const pos = data.Message.PositionReport;
    vessel.speedKnots = typeof pos.Sog === 'number' ? pos.Sog : 0.0;
    vessel.heading = (pos.TrueHeading && pos.TrueHeading !== 511) ? pos.TrueHeading : (pos.Cog || 0.0);
  } else if (msgType === 'StandardClassBPositionReport' && data.Message?.StandardClassBPositionReport) {
    const pos = data.Message.StandardClassBPositionReport;
    vessel.speedKnots = typeof pos.Sog === 'number' ? pos.Sog : 0.0;
    vessel.heading = (pos.TrueHeading && pos.TrueHeading !== 511) ? pos.TrueHeading : (pos.Cog || 0.0);
  } else if (msgType === 'ShipStaticData' && data.Message?.ShipStaticData) {
    const stat = data.Message.ShipStaticData;
    if (stat.Name) vessel.name = stat.Name.trim();
    if (stat.Destination) vessel.dest = stat.Destination.trim();
    if (stat.Dimension) {
      vessel.length = (stat.Dimension.A || 0) + (stat.Dimension.B || 0);
      vessel.beam = (stat.Dimension.C || 0) + (stat.Dimension.D || 0);
    }
    if (stat.Type) {
      vessel.vtype = stat.Type;
      vessel.isCommercial = (stat.Type >= 70 && stat.Type <= 89) || vessel.length >= 50;
    }
    if (stat.Eta) {
      const m = (stat.Eta.Month || 1).toString().padStart(2, '0');
      const d = (stat.Eta.Day || 1).toString().padStart(2, '0');
      const h = (stat.Eta.Hour || 12).toString().padStart(2, '0');
      vessel.eta = `${d}.${m} ${h}:00`;
    }
  }

  // Kapı Giriş ve Çıkış Kontrolü (Arrival / Departure detection)
  checkPortGateEvents(vessel);
}

// Liman Kapısı Olay Kontrolü (OneSignal Push Bildirimleri)
function checkPortGateEvents(ship) {
  const now = new Date();
  const currentInside = isInsidePort(ship.lat, ship.lng, ship.berthNo);
  const prev = previousVesselStates.get(ship.mmsi);

  if (prev && prev.isInside !== undefined) {
    // İçeri Giriş Tespiti
    if (!prev.isInside && currentInside) {
      const notifKey = `gate_in_${ship.mmsi}_${now.toDateString()}`;
      if (!notifiedEvents.has(notifKey)) {
        notifiedEvents.add(notifKey);
        const title = `🚨 Gemi Liman İçine Girdi: ${ship.name}`;
        const msg = `"${ship.name}" gemisi kontrol koordinatını (36.7249°N, 36.1871°E) geçerek İsdemir Limanı içine giriş yaptı.`;
        console.log(`[AisStream Bildirim]: ${title} -> ${msg}`);
        if (notificationCallback) {
          notificationCallback(title, msg, {
            type: 'ship_arrival',
            ship: ship.name,
            mmsi: ship.mmsi,
            gate: '36.724951, 36.187179',
            speed: ship.speedKnots
          });
        }
      }
    }
    // Rıhtımdan / Limandan Ayrılış Tespiti
    else if (prev.isInside && !currentInside && ship.speedKnots > 1.2) {
      const notifKey = `gate_out_${ship.mmsi}_${now.toDateString()}`;
      if (!notifiedEvents.has(notifKey)) {
        notifiedEvents.add(notifKey);
        const title = `🌊 Gemi Limandan Ayrıldı: ${ship.name}`;
        const msg = `"${ship.name}" gemisi İsdemir Limanı baseninden ${ship.speedKnots} knot hızla açık denize çıkış yaptı.`;
        console.log(`[AisStream Bildirim]: ${title} -> ${msg}`);
        if (notificationCallback) {
          notificationCallback(title, msg, {
            type: 'ship_departure',
            ship: ship.name,
            mmsi: ship.mmsi,
            speed: ship.speedKnots
          });
        }
      }
    }
  }

  previousVesselStates.set(ship.mmsi, {
    name: ship.name,
    isInside: currentInside,
    lat: ship.lat,
    lng: ship.lng,
    speed: ship.speedKnots,
    berthNo: ship.berthNo || null,
    lastSeen: now
  });
}

// Senkronizasyon ve Firestore Güncelleme Fonksiyonu
async function syncVesselsToFirestore(sendNotificationCb = null) {
  if (sendNotificationCb) notificationCallback = sendNotificationCb;
  const now = new Date();

  try {
    // 1. Bölgesel AIS taraması ile demir ve rıhtım gemi havuzunu tazele
    try {
      const snapUrl = 'https://www.myshiptracking.com/requests/vesselsonmaptempTTT.php?type=json&minlat=36.650&maxlat=36.850&minlon=36.050&maxlon=36.250&zoom=13&selid=0&seltype=0&timecode=-1';
      const snapRes = await new Promise((res, rej) => {
        https.get(snapUrl, { headers: { 'User-Agent': 'Mozilla/5.0' } }, r => {
          let b = '';
          r.on('data', c => b += c);
          r.on('end', () => res(b));
        }).on('error', rej);
      });
      if (snapRes && snapRes.includes('\t')) {
        const lines = snapRes.trim().split('\n');
        for (const l of lines) {
          const p = l.split('\t');
          if (p.length > 5) {
            const mmsi = p[2]?.trim();
            const name = p[3]?.trim();
            const lat = parseFloat(p[4]);
            const lng = parseFloat(p[5]);
            const speed = parseFloat(p[6]) || 0;
            const heading = parseFloat(p[7]) || 0;
            const length = parseInt(p[8]) || 0;
            const beam = parseInt(p[9]) || 0;
            const dest = p[14]?.trim() || '';

            if (mmsi && !isNaN(lat) && !isNaN(lng)) {
              let v = activeVessels.get(mmsi);
              const upper = name.toUpperCase();
              const isService = upper.startsWith('MED ') || upper.startsWith('BABAKALE') || upper.includes('BORA EKSI') || upper.includes('KAPTAN SAYIM') || upper.includes('PILOT') || upper.includes('TUG');
              if (!v) {
                v = {
                  mmsi,
                  name: name || `MMSI: ${mmsi}`,
                  lat,
                  lng,
                  speedKnots: speed,
                  heading,
                  length,
                  beam,
                  dest: dest || 'ISDEMIR',
                  eta: '',
                  vtype: parseInt(p[0]) || 70,
                  isService,
                  isCommercial: !isService,
                  lastSeen: new Date()
                };
                activeVessels.set(mmsi, v);
              } else {
                v.lat = lat;
                v.lng = lng;
                v.speedKnots = speed;
                v.heading = heading;
                if (name && name.length > 1) v.name = name;
              }
            }
          }
        }
      }
    } catch (e) {
      console.warn('[AisStream] Bölgesel snapshot uyarısı:', e.message);
    }

    const vesselsList = Array.from(activeVessels.values());
    const existingFirestoreShips = await getFirestoreShips();

    // Rıhtımlara eşleştir
    const berthStatus = matchVesselsToBerths(vesselsList);
    const firestoreByBerth = {};
    existingFirestoreShips.forEach(s => {
      if (s.rihtimNo) firestoreByBerth[s.rihtimNo] = s;
    });

    const activeLiveShips = [];

    // 1-5 Rıhtımları Güncelle
    for (const berth of BERTHS) {
      const bNo = berth.no;
      const bData = berthStatus[bNo];
      const existingDoc = firestoreByBerth[bNo];

      if (bData.occupied && bData.ship) {
        const liveShip = bData.ship;
        const speed = liveShip.speedKnots;
        const isDeparting = speed > 1.2;
        const status = isDeparting ? 'Limandan Ayrılıyor' : 'Gemi Başlama Alındı';

        const cargoType = existingDoc?.yukCinsi || (bNo === '2' ? 'Cüruf' : bNo === '3' ? 'Levha' : bNo === '4' ? 'Slap' : 'Bobin');
        const tonnage = getVesselTonnage(liveShip.mmsi, liveShip.length, liveShip.beam);

        const shipRecord = {
          gemiAdi: liveShip.name,
          rihtimNo: bNo,
          durum: status,
          yukCinsi: cargoType,
          speedKnots: speed,
          heading: liveShip.heading || 0,
          mmsi: liveShip.mmsi,
          lat: liveShip.lat,
          lng: liveShip.lng,
          length: liveShip.length || 0,
          beam: liveShip.beam || 0,
          tonaj: tonnage.dwt || 'Kargo Gemisi',
          grossTonaj: tonnage.gt || '',
          dwt: tonnage.dwt || '',
          eta: liveShip.eta || 'Rıhtımda Bağlı',
          dest: liveShip.dest || 'ISDEMIR',
          guncelleyenKisi: 'AisStream Canlı Radar',
          sonGuncelleme: now
        };

        await upsertFirestoreShip(`rihtim_${bNo}`, shipRecord);
        activeLiveShips.push(shipRecord);
      } else {
        // Canlı rıhtım verisi yoksa ama Firestore'da doluysa kontrol et
        if (existingDoc && existingDoc.durum !== 'Limandan Ayrıldı') {
          // Gemi gerçekten ayrıldı mı?
          // Eğer aktif gemiler arasında varsa ve rıhtım dışındaysa:
          const matchingVessel = vesselsList.find(v => v.name === existingDoc.gemiAdi || v.mmsi === existingDoc.mmsi);
          if (matchingVessel && matchingVessel.speedKnots > 1.2) {
            await upsertFirestoreShip(`rihtim_${bNo}`, {
              gemiAdi: existingDoc.gemiAdi,
              rihtimNo: bNo,
              durum: 'Limandan Ayrıldı',
              speedKnots: matchingVessel.speedKnots,
              guncelleyenKisi: 'AisStream Canlı Radar',
              sonGuncelleme: now
            });
          }
        }
      }
    }

    // Demir Sahasındaki Gemileri Eşle
    const dockedMmsis = new Set(Object.values(berthStatus).filter(b => b.occupied && b.ship).map(b => b.ship.mmsi));
    const anchoredVessels = [];

    for (const ship of vesselsList) {
      if (dockedMmsis.has(ship.mmsi)) continue;
      if (ship.berthNo) continue;

      const dist = calculateDistanceKm(ANCHORAGE_ZONE.centerLat, ANCHORAGE_ZONE.centerLng, ship.lat, ship.lng);
      if (dist <= ANCHORAGE_ZONE.radiusKm && ship.speedKnots <= 1.5) {
        const tonnage = getVesselTonnage(ship.mmsi, ship.length, ship.beam);
        const anchorRecord = {
          gemiAdi: ship.name,
          rihtimNo: 'Demir',
          durum: 'Demir Sahasında (Bekliyor)',
          yukCinsi: 'Açıkta Bekliyor',
          speedKnots: ship.speedKnots,
          heading: ship.heading || 0,
          mmsi: ship.mmsi,
          lat: ship.lat,
          lng: ship.lng,
          length: ship.length || 0,
          beam: ship.beam || 0,
          tonaj: tonnage.dwt || 'Kargo Gemisi',
          grossTonaj: tonnage.gt || '',
          dwt: tonnage.dwt || '',
          eta: ship.eta || 'Demirde Bekliyor',
          dest: ship.dest || '',
          mesafeDemirKm: Math.round(dist * 10) / 10,
          isAnchorage: true,
          guncelleyenKisi: 'AisStream Canlı Radar',
          sonGuncelleme: now
        };

        await upsertFirestoreShip(`demir_${ship.mmsi}`, anchorRecord);
        anchoredVessels.push(anchorRecord);
        activeLiveShips.push(anchorRecord);
      }
    }

    // Artık demirde olmayan eski demir kayıtlarını temizle
    if (anchoredVessels.length > 0) {
      const currentAnchoredMmsis = new Set(anchoredVessels.map(s => s.mmsi));
      for (const existing of existingFirestoreShips) {
        if (existing.id && existing.id.startsWith('demir_')) {
          const mmsi = existing.mmsi?.toString();
          if (mmsi && (dockedMmsis.has(mmsi) || !currentAnchoredMmsis.has(mmsi))) {
            await firestoreRequest(`gemiler/${existing.id}`, 'DELETE');
          }
        }
      }
    }

    console.log(`[AisStream] Senkronizasyon başarılı: ${Object.values(berthStatus).filter(b => b.occupied).length} rıhtım, ${anchoredVessels.length} demirde.`);

    return {
      success: true,
      timestamp: now.toISOString(),
      activeCount: activeLiveShips.length,
      dockedCount: Object.values(berthStatus).filter(b => b.occupied).length,
      anchoredCount: anchoredVessels.length,
      ships: activeLiveShips
    };
  } catch (err) {
    console.error('[AisStream Sync Hatası]:', err.message);
    return { success: false, error: err.message };
  }
}

module.exports = {
  startAisStreamEngine,
  syncVesselsToFirestore,
  matchVesselsToBerths,
  calculateDistanceKm,
  isInsidePort,
  activeVessels,
  BERTHS,
  ANCHORAGE_ZONE,
  PORT_GATE
};
