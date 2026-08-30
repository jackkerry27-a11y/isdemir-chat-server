"""
İsdemir Liman Gemileri - MarineTraffic Scrapling Test
Koordinatlar: centerx:36.205, centery:36.727, zoom:15
"""
import json
import re
import asyncio
import sys

# İsdemir port coordinates
ISDEMIR_URL = "https://www.marinetraffic.com/en/ais/home/centerx:36.205/centery:36.727/zoom:15"
LAT_MIN, LAT_MAX = 36.695, 36.755
LON_MIN, LON_MAX = 36.160, 36.230

def is_in_isdemir(lat, lon):
    try:
        return LAT_MIN <= float(lat) <= LAT_MAX and LON_MIN <= float(lon) <= LON_MAX
    except:
        return False

# ============================================================
# METHOD 1: Direct API endpoints (fastest, no browser needed)
# ============================================================
def try_direct_api():
    print("\n[METHOD 1] MarineTraffic Tile API deneniyor...")
    from scrapling.fetchers import Fetcher
    
    fetcher = Fetcher()
    
    # MarineTraffic uses tile-based vessel data
    # Zoom 15, İsdemir area tile coordinates
    # lat 36.727, lon 36.205 → tile X:2360, Y:1586 at zoom 15
    endpoints = [
        "https://www.marinetraffic.com/getData/get_data_json_4/z:15/X:2360/Y:1586/station:0",
        "https://www.marinetraffic.com/getData/get_data_json_4/z:14/X:1180/Y:793/station:0",
        "https://www.marinetraffic.com/en/reports/vesselDetails/vessel_id:1234",
    ]
    
    headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://www.marinetraffic.com/en/ais/home',
    }
    
    for url in endpoints:
        try:
            print(f"  Deneniyor: {url[:70]}...")
            page = fetcher.get(url, headers=headers)
            if page:
                text = page.text
                if text and len(text) > 10:
                    print(f"  [YANIT] {text[:300]}")
                    return text
        except Exception as e:
            print(f"  [HATA] {e}")
    
    return None

# ============================================================
# METHOD 2: Playwright with network interception
# ============================================================
async def try_playwright_intercept():
    print("\n[METHOD 2] Playwright ile ağ istekleri yakalanıyor...")
    
    try:
        from playwright.async_api import async_playwright
        
        captured = []
        
        async with async_playwright() as p:
            browser = await p.chromium.launch(
                headless=True,
                args=[
                    '--no-sandbox',
                    '--disable-blink-features=AutomationControlled',
                    '--disable-dev-shm-usage',
                ]
            )
            
            context = await browser.new_context(
                user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 Chrome/120.0.0.0 Safari/537.36',
                viewport={'width': 1920, 'height': 1080},
            )
            
            # Remove webdriver flag
            await context.add_init_script("""
                Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
                window.chrome = {runtime: {}};
            """)
            
            page = await context.new_page()
            
            # Capture all API responses
            api_responses = []
            
            async def handle_response(response):
                url = response.url
                if any(kw in url.lower() for kw in [
                    'getdata', 'get_data', 'vessels', 'ais', 'ships',
                    'expected', 'port', 'json', 'api'
                ]):
                    try:
                        body = await response.text()
                        if body and ('{' in body or '[' in body):
                            print(f"  [API] {url[:80]}")
                            print(f"  [YANIT] {body[:200]}")
                            api_responses.append({'url': url, 'body': body})
                    except:
                        pass
            
            page.on('response', handle_response)
            
            print("  MarineTraffic İsdemir sayfası açılıyor...")
            try:
                await page.goto(ISDEMIR_URL, wait_until='networkidle', timeout=30000)
            except:
                await page.goto(ISDEMIR_URL, timeout=30000)
            
            # Wait for map to load
            await asyncio.sleep(5)
            
            print(f"  Sayfa başlığı: {await page.title()}")
            print(f"  Yakalanan API isteği: {len(api_responses)}")
            
            # Try to find vessel data in page
            vessel_data = await page.evaluate("""
                () => {
                    // Check for vessel data in global variables
                    const keys = Object.keys(window);
                    const interesting = keys.filter(k => 
                        ['vessel', 'ship', 'ais', 'map', 'fleet'].some(kw => k.toLowerCase().includes(kw))
                    );
                    return interesting.slice(0, 10);
                }
            """)
            print(f"  Global değişkenler: {vessel_data}")
            
            await browser.close()
            
            return api_responses
            
    except Exception as e:
        print(f"  [HATA] {e}")
        return []

# ============================================================
# METHOD 3: StealthyFetcher (curl_cffi based)
# ============================================================
def try_stealth():
    print("\n[METHOD 3] StealthyFetcher deneniyor...")
    try:
        from scrapling.fetchers import StealthyFetcher
        
        page = StealthyFetcher.fetch(
            ISDEMIR_URL,
            headless=True,
            network_idle=True,
            timeout=30000,
        )
        
        if page:
            text = page.text[:2000]
            print(f"  Sayfa boyutu: {len(page.text)} karakter")
            
            # Look for vessel data patterns
            for pattern in [r'MMSI.*?\d{9}', r'"shipname".*?"[A-Z ]+"', r'"LAT".*?[\d.]+']:
                matches = re.findall(pattern, text[:5000])
                if matches:
                    print(f"  [BULUNDU] {matches[:3]}")
                    return text
            
            print(f"  İlk 500 karakter: {text[:500]}")
            return text
    except Exception as e:
        print(f"  [HATA] {e}")
    return None

# ============================================================
# MAIN
# ============================================================
if __name__ == "__main__":
    print("=" * 60)
    print("İSDEMİR LİMAN GEMİ SCRAPER - MarineTraffic")
    print(f"URL: {ISDEMIR_URL}")
    print("=" * 60)
    
    result = None
    
    # Try method 1: Direct API
    result = try_direct_api()
    
    # Try method 2: Playwright intercept
    if not result:
        result = asyncio.run(try_playwright_intercept())
    
    # Try method 3: Stealth
    if not result:
        result = try_stealth()
    
    print("\n" + "=" * 60)
    if result:
        print("✅ VERİ ALINDI! Sunucu entegrasyonu yapılabilir.")
    else:
        print("❌ Veri alınamadı. MarineTraffic engelliyor.")
    print("=" * 60)
