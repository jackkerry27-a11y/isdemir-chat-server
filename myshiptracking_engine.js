const https = require('https');

const FIREBASE_API_KEY = 'AIzaSyDvf6cKildF6QwHduR9aDREoTtay609MEA';
const PROJECT_ID = 'isdemirops';

// Berths definitions based on user's hand-drawn map of Isdemir Port
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

// Demir Sahası (Anchorage Area) definition centered around user coordinates:
// Latitude: 36.761552, Longitude: 36.136181
const ANCHORAGE_ZONE = {
  name: 'İsdemir Demir Sahası (Açıkta Bekleme)',
  centerLat: 36.761552,
  centerLng: 36.136181,
  radiusKm: 3.5 // Within 3.5 km of user's anchor coordinates
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

// Mendirek & Liman Giriş-Çıkış Kapısı (Gate Checkpoint)
// Kullanıcının belirttiği koordinatlar: Latitude: 36.724951, Longitude: 36.187179
const PORT_GATE = {
  name: 'İsdemir Mendirek & Liman Kapısı',
  lat: 36.724951,
  lng: 36.187179,
  minLat: 36.7230,
  maxLat: 36.7360,
  minLng: 36.187179,
  maxLng: 36.2050
};

// Gemi liman baseni (kapı koordinatının içi) dahilinde mi?
function isInsidePort(lat, lng, berthNo = null) {
  if (berthNo) return true; // Rıhtımda bağlıysa kesinlikle içeridedir
  return lat >= PORT_GATE.minLat && lat <= PORT_GATE.maxLat && lng >= PORT_GATE.lng && lng <= PORT_GATE.maxLng;
}

// In-memory state tracking to detect departures & arrivals
const previousVesselStates = new Map(); // mmsi -> { name, speed, lat, lng, berthNo, lastSeen }
const notifiedEvents = new Set(); // To avoid spamming notifications

// İsdemir & İskenderun Limanına Gelen Ticari Gemilerin Resmi Tonaj & Özellik Kütüphanesi
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

function fetchMyShipTrackingRaw() {
  return new Promise((resolve, reject) => {
    // Expanded bbox to cover both berths 1-5 and outer anchorage area around (36.761552, 36.136181)
    const url = 'https://www.myshiptracking.com/requests/vesselsonmaptempTTT.php?type=json&minlat=36.690&maxlat=36.800&minlon=36.100&maxlon=36.230&zoom=14&selid=0&seltype=0&timecode=-1';
    
    https.get(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Referer': 'https://www.myshiptracking.com/'
      }
    }, res => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        try {
          const lines = body.split('\n');
          const vessels = [];
          
          for (const line of lines) {
            const parts = line.split('\t');
            if (parts.length > 5) {
              const vtype = parseInt(parts[0]) || 0;
              const mmsi = parts[2]?.trim();
              const name = parts[3]?.trim();
              const lat = parseFloat(parts[4]);
              const lng = parseFloat(parts[5]);
              const speedKnots = parseFloat(parts[6]) || 0;
              const heading = parseFloat(parts[7]) || 0;
              const length = parseInt(parts[8]) || 0;
              const beam = parseInt(parts[9]) || 0;
              const etaDay = parseInt(parts[10]) || 0;
              const etaHour = parseInt(parts[11]) || 0;
              const dest = parts[14]?.trim() || '';

              const aisTimestamp = parseInt(parts[13]) || 0;
              const ageHours = aisTimestamp > 0 ? (Date.now() / 1000 - aisTimestamp) / 3600 : 0;
              const isStale = ageHours > 3.0; // 3 saatten eski AIS verisi bayat kabul edilir

              let eta = '';
              if (etaDay > 0) {
                const now = new Date();
                let month = now.getMonth() + 1;
                if (etaDay < now.getDate() - 10) {
                  month = (month % 12) + 1;
                }
                const dayStr = etaDay.toString().padStart(2, '0');
                const monthStr = month.toString().padStart(2, '0');
                const hourStr = (etaHour >= 0 && etaHour <= 23 ? etaHour : 12).toString().padStart(2, '0');
                eta = `${dayStr}.${monthStr} ${hourStr}:00`;
              }

              if (mmsi && name && !isNaN(lat) && !isNaN(lng)) {
                // Determine commercial ship vs harbour tug/service boat
                const isService = name.startsWith('MED ') || name.startsWith('BABAKALE') || name.includes('BORA EKSI') || name.includes('KAPTAN SAYIM');
                const isCommercial = (vtype === 7 || vtype === 8 || vtype === 0 || length >= 50) && !isService;

                vessels.push({
                  vtype,
                  mmsi,
                  name,
                  lat,
                  lng,
                  speedKnots,
                  heading,
                  length,
                  beam,
                  etaDay,
                  etaHour,
                  eta,
                  dest,
                  aisTimestamp,
                  ageHours,
                  isStale,
                  isCommercial,
                  isService
                });
              }
            }
          }
          resolve(vessels);
        } catch (e) {
          reject(e);
        }
      });
    }).on('error', reject);
  });
}

function matchVesselsToBerths(vessels) {
  const berthStatus = {};
  BERTHS.forEach(b => {
    berthStatus[b.no] = {
      berthNo: b.no,
      berthName: b.name,
      occupied: false,
      ship: null
    };
  });

  const commercialVessels = vessels.filter(v => v.isCommercial);

  for (const ship of commercialVessels) {
    let matchedBerth = null;

    // Check exact bounding box first
    for (const b of BERTHS) {
      if (ship.lat >= b.latMin && ship.lat <= b.latMax && ship.lng >= b.lngMin && ship.lng <= b.lngMax) {
        matchedBerth = b.no;
        break;
      }
    }

    // If not in exact box, check proximity (< 300 meters)
    if (!matchedBerth) {
      let minDistance = Infinity;
      let closestBerth = null;
      for (const b of BERTHS) {
        const dist = Math.hypot(ship.lat - b.centerLat, ship.lng - b.centerLng);
        if (dist < minDistance && dist < 0.003) {
          minDistance = dist;
          closestBerth = b.no;
        }
      }
      matchedBerth = closestBerth;
    }

    if (matchedBerth && !berthStatus[matchedBerth].occupied) {
      berthStatus[matchedBerth].occupied = true;
      berthStatus[matchedBerth].ship = ship;
      ship.berthNo = matchedBerth;
    }
  }

  return berthStatus;
}

// Helper to make Firestore REST API requests
function firestoreRequest(path, method = 'GET', data = null) {
  return new Promise((resolve, reject) => {
    const urlPath = `/v1/projects/${PROJECT_ID}/databases/(default)/documents/${path}?key=${FIREBASE_API_KEY}`;
    const payload = data ? JSON.stringify(data) : null;
    
    const req = https.request({
      hostname: 'firestore.googleapis.com',
      path: urlPath,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        ...(payload ? { 'Content-Length': Buffer.byteLength(payload) } : {})
      }
    }, res => {
      let body = '';
      res.on('data', c => body += c);
      res.on('end', () => {
        try {
          const parsed = body ? JSON.parse(body) : {};
          resolve({ status: res.statusCode, data: parsed });
        } catch (e) {
          resolve({ status: res.statusCode, raw: body });
        }
      });
    });
    req.on('error', reject);
    if (payload) req.write(payload);
    req.end();
  });
}

// Fetch all existing Firestore ship records
async function getFirestoreShips() {
  try {
    const res = await firestoreRequest('gemiler');
    if (!res.data || !res.data.documents) return [];
    
    return res.data.documents.map(doc => {
      const f = doc.fields || {};
      const id = doc.name.split('/').pop();
      return {
        id,
        gemiAdi: f.gemiAdi?.stringValue || '',
        rihtimNo: f.rihtimNo?.stringValue || '',
        durum: f.durum?.stringValue || '',
        yukCinsi: f.yukCinsi?.stringValue || 'Levha',
        ekleyenKisi: f.ekleyenKisi?.stringValue || 'İsdemir',
        guncelleyenKisi: f.guncelleyenKisi?.stringValue || 'Canlı AIS',
        speedKnots: f.speedKnots?.doubleValue || f.speedKnots?.integerValue || 0.0,
        mmsi: f.mmsi?.stringValue || '',
      };
    });
  } catch (e) {
    console.error('[Firestore] Veri okuma hatası:', e.message);
    return [];
  }
}

// Update or create document in Firestore
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

  // Use patch on specific document
  return firestoreRequest(`gemiler/${docId}`, 'PATCH', { fields: firestoreFields });
}

// Main sync process called periodically
async function runMyShipTrackingSync(sendNotificationCallback = null) {
  const now = new Date();
  const timeStr = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;

  console.log(`[MyShipTracking] Canlı AIS senkronizasyonu başlatıldı (${timeStr})...`);

  try {
    const vessels = await fetchMyShipTrackingRaw();
    if (!vessels || vessels.length === 0) {
      console.log('[MyShipTracking] AIS verisi boş döndü.');
      return { success: false, reason: 'Empty vessel list' };
    }

    const berthStatus = matchVesselsToBerths(vessels);
    const existingFirestoreShips = await getFirestoreShips();

    // Map existing records by berthNo for easy comparison
    const firestoreByBerth = {};
    existingFirestoreShips.forEach(s => {
      if (s.rihtimNo) firestoreByBerth[s.rihtimNo] = s;
    });

    // İlk çalıştırmada hafızada kayıt yoksa Firestore'daki aktif rıhtım gemilerini içeride olarak başlat
    if (previousVesselStates.size === 0 && existingFirestoreShips.length > 0) {
      for (const ef of existingFirestoreShips) {
        if (ef.mmsi && ef.rihtimNo && ['1', '2', '3', '4', '5'].includes(ef.rihtimNo) && ef.durum !== 'Limandan Ayrıldı') {
          previousVesselStates.set(ef.mmsi, {
            name: ef.gemiAdi,
            isInside: true,
            lat: 36.730,
            lng: 36.195,
            berthNo: ef.rihtimNo,
            speed: ef.speedKnots,
            lastSeen: now
          });
        }
      }
    }

    const activeLiveShips = [];

    for (const berth of BERTHS) {
      const bNo = berth.no;
      const bData = berthStatus[bNo];
      const existingDoc = firestoreByBerth[bNo];

      if (bData.occupied && bData.ship) {
        const liveShip = bData.ship;
        const speed = liveShip.speedKnots;
        const isDeparting = speed > 1.2;

        let status = isDeparting ? 'Limandan Ayrılıyor' : 'Gemi Başlama Alındı';
        // Preserve operator's existing cargo type if present, or assign sensible default
        let cargoType = existingDoc?.yukCinsi || (bNo === '2' ? 'Cüruf' : bNo === '3' ? 'Levha' : bNo === '4' ? 'Slap' : 'Bobin');

        // Check if ship just departed or is moving out
        const prev = previousVesselStates.get(liveShip.mmsi);
        if (prev && prev.speed <= 0.5 && speed > 1.2) {
          const notifKey = `dep_${liveShip.mmsi}_${now.getHours()}`;
          if (!notifiedEvents.has(notifKey)) {
            notifiedEvents.add(notifKey);
            const title = `🌊 Gemi Limandan Ayrılıyor: ${liveShip.name}`;
            const msg = `"${liveShip.name}" gemisi ${bNo}. Rıhtımdan ${speed} knot hızla ayrılıyor.`;
            console.log(`[Bildirim Tetiklendi]: ${title} -> ${msg}`);
            if (sendNotificationCallback) {
              sendNotificationCallback(title, msg, { type: 'ship_departure', ship: liveShip.name, berth: bNo });
            }
          }
        }

        const docId = existingDoc ? existingDoc.id : `rihtim_${bNo}`;
        const tonnageInfo = getVesselTonnage(liveShip.mmsi, liveShip.length, liveShip.beam);

        await upsertFirestoreShip(docId, {
          gemiAdi: liveShip.name,
          rihtimNo: bNo,
          durum: status,
          yukCinsi: cargoType,
          speedKnots: speed,
          heading: liveShip.heading,
          mmsi: liveShip.mmsi,
          lat: liveShip.lat,
          lng: liveShip.lng,
          length: liveShip.length,
          beam: liveShip.beam,
          tonaj: tonnageInfo.dwt,
          grossTonaj: tonnageInfo.gt,
          dwt: tonnageInfo.dwt,
          eta: liveShip.eta || 'Rıhtımda Bağlı',
          dest: liveShip.dest,
          guncelleyenKisi: 'Liman Otomasyonu',
          sonGuncelleme: now
        });

        previousVesselStates.set(liveShip.mmsi, {
          name: liveShip.name,
          speed: speed,
          lat: liveShip.lat,
          lng: liveShip.lng,
          isInside: true,
          berthNo: bNo,
          lastSeen: now
        });

        activeLiveShips.push({
          id: docId,
          rihtimNo: bNo,
          gemiAdi: liveShip.name,
          durum: status,
          yukCinsi: cargoType,
          speedKnots: speed,
          heading: liveShip.heading,
          mmsi: liveShip.mmsi,
          lat: liveShip.lat,
          lng: liveShip.lng,
          length: liveShip.length,
          beam: liveShip.beam,
          tonaj: tonnageInfo.dwt,
          grossTonaj: tonnageInfo.gt,
          dwt: tonnageInfo.dwt,
          eta: liveShip.eta || 'Rıhtımda Bağlı',
          dest: liveShip.dest
        });
      } else {
        // Rıhtımda anlık AIS poligonunda sinyal bulunamadı
        // ANCAK: Mevcut doküman varsa (örn: LIVA IMAMOGLU 4. Rıhtım) ve 'Limandan Ayrıldı' değilse,
        // AIS sinyal körlüğü veya düşük güç sebebiyle gemi hemen silinmez; rıhtımda tutulur!
        if (existingDoc && existingDoc.durum !== 'Limandan Ayrıldı') {
          const prev = previousVesselStates.get(existingDoc.mmsi);
          const isExplicitlyDeparting = prev && prev.speed > 1.5 && (prev.lat < PORT_GATE.minLat || prev.lng < PORT_GATE.minLng);

          if (isExplicitlyDeparting) {
            const prevName = existingDoc.gemiAdi;
            if (prevName && prevName !== 'BOŞ RIHTIM') {
              const notifKey = `left_${prevName}_${now.getHours()}`;
              if (!notifiedEvents.has(notifKey)) {
                notifiedEvents.add(notifKey);
                const title = `🌊 Rıhtım Boşaldı: ${bNo}. Rıhtım`;
                const msg = `"${prevName}" gemisi ${bNo}. Rıhtımdan ayrıldı, rıhtım boşaldı.`;
                console.log(`[Bildirim Tetiklendi]: ${title} -> ${msg}`);
                if (sendNotificationCallback) {
                  sendNotificationCallback(title, msg, { type: 'berth_empty', ship: prevName, berth: bNo });
                }
              }
            }

            // Mark as Limandan Ayrıldı so berth shows as empty in Flutter
            await upsertFirestoreShip(existingDoc.id, {
              durum: 'Limandan Ayrıldı',
              speedKnots: 0.0,
              guncelleyenKisi: 'Liman Otomasyonu',
              sonGuncelleme: now
            });
          } else {
            // Gemi rıhtımda bağlı kalmaya devam ediyor
            activeLiveShips.push(existingDoc);
            berthStatus[bNo].occupied = true;
            berthStatus[bNo].ship = existingDoc;
          }
        }
      }
    }

    // Rıhtımda bağlı aktif gemilerin MMSI ve İsim kümesi
    const dockedMmsis = new Set();
    const dockedNames = new Set();
    for (const b of BERTHS) {
      const bs = berthStatus[b.no];
      if (bs && bs.occupied && bs.ship) {
        if (bs.ship.mmsi) dockedMmsis.add(bs.ship.mmsi.toString());
        const sName = (bs.ship.name || bs.ship.gemiAdi || '').toString().toUpperCase();
        if (sName) dockedNames.add(sName);
      }
    }

    // -----------------------------------------------------------
    // DEMİR SAHASINDA (AÇIKTA) BEKLEYEN GEMİLER (36.761552, 36.136181)
    // -----------------------------------------------------------
    const anchoredVessels = [];
    for (const ship of vessels) {
      if (!ship.isCommercial) continue;

      const sName = ship.name.toUpperCase();
      // Rıhtımda bağlı bir gemi ASLA demir sahasında gösterilemez!
      if (dockedMmsis.has(ship.mmsi) || dockedNames.has(sName)) {
        console.log(`[MyShipTracking] Gemi rıhtımda bağlı olduğu için demir sahasına alınmadı: ${ship.name}`);
        continue;
      }

      // 3 saatten eski bayat AIS verisi demir sahasına alınmaz!
      if (ship.isStale) {
        console.log(`[MyShipTracking] Bayat AIS koordinatı atlandı: ${ship.name} (${ship.ageHours.toFixed(1)} saat önce)`);
        continue;
      }

      if (!ship.berthNo) {
        const dist = calculateDistanceKm(ANCHORAGE_ZONE.centerLat, ANCHORAGE_ZONE.centerLng, ship.lat, ship.lng);
        // Koordinat çevresinde demirde bekleyen gemiler (hız <= 1.5 kt)
        if (dist <= ANCHORAGE_ZONE.radiusKm && ship.speedKnots <= 1.5) {
          ship.distanceToAnchorKm = Math.round(dist * 10) / 10;
          anchoredVessels.push(ship);
        }
      }
    }

    const currentAnchoredMmsis = new Set(anchoredVessels.map(s => s.mmsi));

    // Canlı demirleyen gemileri Firestore'a yaz / güncelle
    for (const aShip of anchoredVessels) {
      const docId = `demir_${aShip.mmsi}`;

      const notifKey = `anc_${aShip.mmsi}_${now.toDateString()}`;
      if (!notifiedEvents.has(notifKey)) {
        notifiedEvents.add(notifKey);
        const title = `⚓ Gemi Demir Sahasında: ${aShip.name}`;
        const msg = `"${aShip.name}" İsdemir demir sahasına (36.7615°N, 36.1361°E) ulaştı ve açıkta beklemeye geçti.`;
        console.log(`[Bildirim Tetiklendi]: ${title} -> ${msg}`);
        if (sendNotificationCallback) {
          sendNotificationCallback(title, msg, { type: 'ship_anchored', ship: aShip.name, mmsi: aShip.mmsi });
        }
      }

      const tonnageInfo = getVesselTonnage(aShip.mmsi, aShip.length, aShip.beam);

      await upsertFirestoreShip(docId, {
        gemiAdi: aShip.name,
        rihtimNo: 'Demir',
        durum: 'Demir Sahasında (Bekliyor)',
        yukCinsi: 'Açıkta Bekliyor',
        speedKnots: aShip.speedKnots,
        heading: aShip.heading,
        mmsi: aShip.mmsi,
        lat: aShip.lat,
        lng: aShip.lng,
        length: aShip.length,
        beam: aShip.beam,
        tonaj: tonnageInfo.dwt,
        grossTonaj: tonnageInfo.gt,
        dwt: tonnageInfo.dwt,
        eta: aShip.eta || 'Demirde Bekliyor',
        dest: aShip.dest,
        mesafeDemirKm: aShip.distanceToAnchorKm,
        isAnchorage: true,
        guncelleyenKisi: 'Demir Sahası Radarı',
        sonGuncelleme: now
      });

      activeLiveShips.push({
        id: docId,
        rihtimNo: 'Demir',
        gemiAdi: aShip.name,
        durum: 'Demir Sahasında (Bekliyor)',
        yukCinsi: 'Açıkta Bekliyor',
        speedKnots: aShip.speedKnots,
        heading: aShip.heading,
        mmsi: aShip.mmsi,
        lat: aShip.lat,
        lng: aShip.lng,
        length: aShip.length,
        beam: aShip.beam,
        tonaj: tonnageInfo.dwt,
        grossTonaj: tonnageInfo.gt,
        dwt: tonnageInfo.dwt,
        eta: aShip.eta || 'Demirde Bekliyor',
        dest: aShip.dest,
        mesafeDemirKm: aShip.distanceToAnchorKm,
        isAnchorage: true
      });
    }

    // Temizlik: Artık demir sahasında olmayan veya rıhtıma yanaşan eski demir_ kayıtlarını kaldır
    for (const existing of existingFirestoreShips) {
      if (existing.id && existing.id.startsWith('demir_')) {
        const mmsi = existing.mmsi?.toString();
        const gName = (existing.gemiAdi || '').toString().toUpperCase();
        if ((mmsi && dockedMmsis.has(mmsi)) || dockedNames.has(gName) || (mmsi && !currentAnchoredMmsis.has(mmsi))) {
          console.log(`[MyShipTracking] Demir sahasından ayrılan/rıhtıma yanaşan gemi kaydı siliniyor: ${existing.gemiAdi} (${existing.id})`);
          await firestoreRequest(`gemiler/${existing.id}`, 'DELETE');
        }
      }
    }

    // -----------------------------------------------------------
    // LİMAN KAPI GEÇİŞ BİLDİRİMLERİ (36.724951, 36.187179)
    // -----------------------------------------------------------
    const commercialVessels = vessels.filter(v => v.isCommercial);

    for (const ship of commercialVessels) {
      const isDocked = dockedMmsis.has(ship.mmsi) || dockedNames.has(ship.name.toUpperCase());
      const currentInside = isDocked || isInsidePort(ship.lat, ship.lng, ship.berthNo);
      const prevState = previousVesselStates.get(ship.mmsi);

      if (prevState && typeof prevState.isInside === 'boolean' && !ship.isStale) {
        // 1. ÇIKIŞ: Gemi daha önce liman içindeyken bu koordinatın dışına çıktı
        if (prevState.isInside === true && currentInside === false) {
          const notifKey = `gate_exit_${ship.mmsi}_${now.toDateString()}_${now.getHours()}`;
          if (!notifiedEvents.has(notifKey)) {
            notifiedEvents.add(notifKey);
            const title = `🌊 Gemi Limandan Ayrıldı: ${ship.name}`;
            const msg = `"${ship.name}" gemisi kontrol koordinatının (36.7249°N, 36.1871°E) dışına çıkarak İsdemir Limanı'ndan ayrıldı.`;
            console.log(`[Bildirim Tetiklendi]: ${title} -> ${msg}`);
            if (sendNotificationCallback) {
              sendNotificationCallback(title, msg, {
                type: 'ship_departure',
                ship: ship.name,
                mmsi: ship.mmsi,
                gate: '36.724951, 36.187179',
                speed: ship.speedKnots
              });
            }
          }
        }
        // 2. İÇERİ GİRİŞ: Gemi daha önce liman dışındayken bu koordinattan içeri girdi
        else if (prevState.isInside === false && currentInside === true) {
          const notifKey = `gate_entry_${ship.mmsi}_${now.toDateString()}_${now.getHours()}`;
          if (!notifiedEvents.has(notifKey)) {
            notifiedEvents.add(notifKey);
            const title = `⚓ Gemi İçeri Giriş Yaptı: ${ship.name}`;
            const msg = `"${ship.name}" gemisi kontrol koordinatını (36.7249°N, 36.1871°E) geçerek İsdemir Limanı içine giriş yaptı.`;
            console.log(`[Bildirim Tetiklendi]: ${title} -> ${msg}`);
            if (sendNotificationCallback) {
              sendNotificationCallback(title, msg, {
                type: 'ship_arrival',
                ship: ship.name,
                mmsi: ship.mmsi,
                gate: '36.724951, 36.187179',
                speed: ship.speedKnots
              });
            }
          }
        }
      }

      // Durumu sonraki çevrim için güncelle
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

    console.log(`[MyShipTracking] Canlı senkronizasyon tamamlandı: ${berthStatus ? Object.values(berthStatus).filter(b => b.occupied).length : 0} rıhtım dolu, ${anchoredVessels.length} gemi demirde bekliyor.`);
    return {
      success: true,
      timestamp: now.toISOString(),
      activeCount: activeLiveShips.length,
      dockedCount: Object.values(berthStatus).filter(b => b.occupied).length,
      anchoredCount: anchoredVessels.length,
      ships: activeLiveShips
    };
  } catch (err) {
    console.error('[MyShipTracking Hata]:', err.message);
    return { success: false, error: err.message };
  }
}

module.exports = {
  runMyShipTrackingSync,
  fetchMyShipTrackingRaw,
  matchVesselsToBerths,
  calculateDistanceKm,
  isInsidePort,
  BERTHS,
  ANCHORAGE_ZONE,
  PORT_GATE
};
