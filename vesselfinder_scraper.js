const puppeteer = require('puppeteer-extra');
const StealthPlugin = require('puppeteer-extra-plugin-stealth');
const chromium = require('@sparticuz/chromium');

puppeteer.use(StealthPlugin());

// İsdemir Limanı Koordinatları
const LAT_MIN = 36.695;
const LAT_MAX = 36.755;
const LON_MIN = 36.160;
const LON_MAX = 36.230;

function isInIsdemir(lat, lon) {
  try {
    return lat >= LAT_MIN && lat <= LAT_MAX && lon >= LON_MIN && lon <= LON_MAX;
  } catch (e) {
    return false;
  }
}

async function scrapeVesselFinder() {
  let browser = null;
  const vesselData = [];

  console.log('[Scraper] VesselFinder bot başlatılıyor...');
  
  try {
    let executablePath = null;
    try {
      if (typeof chromium.executablePath === 'function') {
        executablePath = await chromium.executablePath();
      } else if (chromium.executablePath) {
        executablePath = await chromium.executablePath;
      }
    } catch (e) {}
    
    const launchOptions = {
      headless: false,
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox',
        '--disable-dev-shm-usage',
        '--disable-gpu',
        '--single-process'
      ]
    };
    if (executablePath && typeof executablePath === 'string') {
        launchOptions.executablePath = executablePath;
    }

    browser = await puppeteer.launch(launchOptions);

    const page = await browser.newPage();
    await page.setUserAgent('Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36');


    // Request interception removed to prevent navigation aborts

    // Gelen JSON verilerini (gemiler) yakala
    page.on('response', async (response) => {
      const url = response.url();
      if (url.includes('getData') || url.includes('get_data') || url.includes('vessels') || url.includes('ships')) {
        try {
          const body = await response.text();
          if (body && body.length > 10) {
            const data = JSON.parse(body);
            let rows = [];
            if (Array.isArray(data)) rows = data;
            else if (data && data.data && data.data.rows) rows = data.data.rows;
            else if (data && data.data) rows = Array.isArray(data.data) ? data.data : [];
            
            if (rows.length > 0) {
              console.log(`[Scraper] Haritada ${rows.length} gemi yakalandı!`);
              vesselData.push(...rows);
            }
          }
        } catch (err) {}
      }
    });

    // MarineTraffic haritasında İsdemir limanına git
    const isdemirUrl = 'https://www.marinetraffic.com/en/ais/home/centerx:36.205/centery:36.727/zoom:14';
    console.log(`[Scraper] Haritaya bağlanılıyor: ${isdemirUrl}`);
    
    await page.goto(isdemirUrl, { waitUntil: 'domcontentloaded', timeout: 45000 }).catch(e => {
      console.log(`[Scraper] Goto hatası: ${e.message}`);
    });
    
    console.log('[Scraper] Sayfa yüklendi, çerezler ayarlandı. Tile API çağrılıyor...');
    await new Promise(r => setTimeout(r, 5000));

    try {
      // İsdemir limanı Z:14 için X ve Y hesaplaması: X=9731, Y=6425
      const tx = 9731, ty = 6425;
      const tileUrl = `https://www.marinetraffic.com/getData/get_data_json_4/z:14/X:${tx}/Y:${ty}/station:0`;
      
      const result = await page.evaluate(async (url) => {
          try {
              const res = await fetch(url, { headers: { 'X-Requested-With': 'XMLHttpRequest', 'Accept': 'application/json' } });
              return await res.text();
          } catch (err) {
              return null;
          }
      }, tileUrl);

      if (result && result.length > 10) {
         const data = JSON.parse(result);
         let rows = [];
         if (data && data.data && data.data.rows) rows = data.data.rows;
         
         if (rows.length > 0) {
             console.log(`[Scraper] Manuel Fetch ile ${rows.length} gemi yakalandı!`);
             vesselData.push(...rows);
         } else {
             console.log('[Scraper] Manuel Fetch boş döndü.');
         }
      }
    } catch(e) {
        console.log(`[Scraper] Manuel Fetch hatası: ${e.message}`);
    }

  } catch (error) {
    console.error('[Scraper Hata]:', error.message);
  } finally {
    // RAM'i boşaltmak için browser'ı KESİNLİKLE kapat
    if (browser) {
      console.log('[Scraper] Tarayıcı kapatılıyor ve RAM temizleniyor...');
      await browser.close().catch(()=>console.log("Kapatılamadı"));
    }
  }

  // Sadece İsdemir limanı sınırları içindeki gemileri filtrele
  const isdemirVessels = [];
  const processedMmsi = new Set(); // Aynı gemiyi 2 kez eklememek için

  for (const v of vesselData) {
    const lat = v.lat || v.LAT || v.latitude;
    const lon = v.lon || v.LON || v.longitude;
    const id = v.mmsi || v.MMSI || v.id || v.name;
    
    if (lat && lon && id && !processedMmsi.has(id)) {
      if (isInIsdemir(lat, lon)) {
        processedMmsi.add(id);
        isdemirVessels.push(v);
      }
    }
  }

  console.log(`[Scraper] İşlem tamamlandı. İsdemir bölgesinde ${isdemirVessels.length} gerçek gemi bulundu.`);
  return isdemirVessels;
}

module.exports = { scrapeVesselFinder };
