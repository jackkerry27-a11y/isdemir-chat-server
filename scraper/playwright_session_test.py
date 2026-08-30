"""
MarineTraffic - Playwright ile gercek session ile tile API yakalama
İsdemir Port: lat:36.727, lon:36.205
"""
import sys
import asyncio
import json
import math

sys.stdout.reconfigure(encoding='utf-8')

LAT_MIN, LAT_MAX = 36.695, 36.755
LON_MIN, LON_MAX = 36.160, 36.230
ISDEMIR_URL = "https://www.marinetraffic.com/en/ais/home/centerx:36.205/centery:36.727/zoom:15"

def is_in_isdemir(lat, lon):
    try:
        return LAT_MIN <= float(lat) <= LAT_MAX and LON_MIN <= float(lon) <= LON_MAX
    except:
        return False

async def run():
    from playwright.async_api import async_playwright
    
    vessel_data = []
    all_api_calls = []
    
    async with async_playwright() as p:
        print("[1] Tarayici baslatiliyor (stealth mode)...")
        
        browser = await p.chromium.launch(
            headless=True,
            args=[
                '--no-sandbox',
                '--disable-setuid-sandbox',
                '--disable-blink-features=AutomationControlled',
                '--disable-dev-shm-usage',
                '--disable-web-security',
                '--lang=en-US',
            ]
        )
        
        context = await browser.new_context(
            user_agent='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
            viewport={'width': 1920, 'height': 1080},
            locale='en-US',
            timezone_id='Europe/Istanbul',
            extra_http_headers={
                'Accept-Language': 'en-US,en;q=0.9',
                'sec-ch-ua': '"Google Chrome";v="120", "Chromium";v="120"',
                'sec-ch-ua-mobile': '?0',
                'sec-ch-ua-platform': '"Windows"',
            }
        )
        
        # Remove automation fingerprints
        await context.add_init_script("""
            Object.defineProperty(navigator, 'webdriver', {get: () => undefined});
            Object.defineProperty(navigator, 'plugins', {get: () => [1,2,3,4,5]});
            Object.defineProperty(navigator, 'languages', {get: () => ['en-US', 'en']});
            window.chrome = {runtime: {}, loadTimes: () => {}, csi: () => {}, app: {}};
            Object.defineProperty(navigator, 'maxTouchPoints', {get: () => 0});
        """)
        
        page = await context.new_page()
        
        # Capture all responses
        async def capture_response(response):
            url = response.url
            status = response.status
            
            # Look for vessel/ship data API calls
            if any(k in url for k in ['getData', 'get_data', 'getVessel', 'vessel', 'ais/data', 'ships']):
                try:
                    body = await response.text()
                    if body and len(body) > 5:
                        entry = {'url': url, 'status': status, 'body': body[:2000]}
                        all_api_calls.append(entry)
                        print(f"\n  [API HIT] {url[:90]}")
                        print(f"  Status: {status}, Len: {len(body)}")
                        print(f"  Body: {body[:300]}")
                        
                        # Try to parse vessel data
                        try:
                            data = json.loads(body)
                            if isinstance(data, dict) and 'data' in data:
                                rows = data['data'].get('rows', [])
                                if rows:
                                    print(f"  *** {len(rows)} ROWS FOUND ***")
                                    vessel_data.extend(rows)
                        except:
                            pass
                except:
                    pass
        
        page.on('response', capture_response)
        
        print("[2] MarineTraffic ana sayfa aciliyor...")
        try:
            await page.goto("https://www.marinetraffic.com/", 
                          wait_until='domcontentloaded', timeout=20000)
            await asyncio.sleep(3)
            title = await page.title()
            print(f"    Baslik: {title}")
        except Exception as e:
            print(f"    Hata: {e}")
        
        print("[3] Isdemir harita sayfasi aciliyor...")
        try:
            await page.goto(ISDEMIR_URL, wait_until='domcontentloaded', timeout=30000)
            title = await page.title()
            print(f"    Baslik: {title}")
            
            if 'Cloudflare' in title or 'Attention Required' in title:
                print("    !! Cloudflare engeli! 5 saniye bekleniyor...")
                await asyncio.sleep(5)
                title = await page.title()
                print(f"    Yeni baslik: {title}")
        except Exception as e:
            print(f"    Sayfa yukleme hatasi: {e}")
        
        print("[4] Harita yuklenmesi bekleniyor (15 saniye)...")
        await asyncio.sleep(15)
        
        # Get final title
        try:
            final_title = await page.title()
            print(f"    Final baslik: {final_title}")
        except:
            pass
        
        # Try to get cookies and manually make tile API call
        print("\n[5] Session cookies aliniyor...")
        cookies = await context.cookies()
        cookie_dict = {c['name']: c['value'] for c in cookies}
        print(f"    Cookies: {list(cookie_dict.keys())}")
        
        # Get CSRF/session tokens from page
        try:
            tokens = await page.evaluate("""
                () => {
                    return {
                        csrfToken: document.querySelector('meta[name=csrf-token]')?.content,
                        sessionId: document.cookie,
                        localStorage: Object.keys(localStorage),
                    }
                }
            """)
            print(f"    CSRF: {tokens.get('csrfToken')}")
            print(f"    LocalStorage keys: {tokens.get('localStorage', [])[:10]}")
        except Exception as e:
            print(f"    Token alma hatasi: {e}")
        
        # Manually trigger tile load by navigating
        print("\n[6] Tile API manuel tetikleniyor...")
        try:
            import math
            zoom = 15
            lat, lon = 36.727, 36.205
            n = 2 ** zoom
            tx = int((lon + 180.0) / 360.0 * n)
            lat_rad = math.radians(lat)
            ty = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
            
            tile_url = f"https://www.marinetraffic.com/getData/get_data_json_4/z:{zoom}/X:{tx}/Y:{ty}/station:0"
            print(f"    Tile URL: {tile_url}")
            
            # Make request from within the browser context (has cookies!)
            result = await page.evaluate(f"""
                async () => {{
                    try {{
                        const r = await fetch('{tile_url}', {{
                            headers: {{
                                'X-Requested-With': 'XMLHttpRequest',
                                'Accept': 'application/json',
                            }}
                        }});
                        const text = await r.text();
                        return {{ status: r.status, body: text.substring(0, 1000) }};
                    }} catch(e) {{
                        return {{ error: e.toString() }};
                    }}
                }}
            """)
            print(f"    Browser fetch sonucu: {result}")
            
            if result and result.get('body'):
                body = result['body']
                try:
                    data = json.loads(body)
                    rows = data.get('data', {}).get('rows', [])
                    area_ships = data.get('data', {}).get('areaShips', 0)
                    print(f"\n    areaShips: {area_ships}")
                    print(f"    rows count: {len(rows)}")
                    if rows:
                        print(f"    *** {len(rows)} GEMI BULUNDU! ***")
                        for row in rows[:10]:
                            print(f"      {row}")
                        vessel_data.extend(rows)
                    else:
                        print("    rows bos - gemi yok veya auth gerekli")
                except Exception as e:
                    print(f"    JSON parse hatasi: {e}, body: {body[:200]}")
                    
        except Exception as e:
            print(f"    Tile fetch hatasi: {e}")
        
        # Try clicking on map to trigger vessel loads
        print("\n[7] Haritaya tiklaniyor (vessel trigger)...")
        try:
            await page.mouse.click(960, 540)
            await asyncio.sleep(3)
        except:
            pass
        
        await browser.close()
    
    print("\n" + "="*60)
    print(f"SONUC: {len(vessel_data)} gemi verisi, {len(all_api_calls)} API cagrisi yakalandi")
    
    if vessel_data:
        print("\nBULUNAN GEMILER:")
        for v in vessel_data:
            print(f"  {v}")
        
        # Filter İsdemir area
        isdemir_vessels = []
        for v in vessel_data:
            lat = v.get('LAT') or v.get('lat') or v.get('LATITUDE')
            lon = v.get('LON') or v.get('lon') or v.get('LONGITUDE')
            if lat and lon and is_in_isdemir(lat, lon):
                isdemir_vessels.append(v)
        
        print(f"\nISDEMIR LIMANI'NDAKI GEMILER: {len(isdemir_vessels)}")
        for v in isdemir_vessels:
            print(f"  {v}")
    else:
        print("Gemi verisi alinamadi - muhtemelen auth gerekli")
    
    print("="*60)
    return vessel_data

if __name__ == "__main__":
    print("="*60)
    print("MarineTraffic Playwright Scraper - Isdemir")
    print("="*60)
    asyncio.run(run())
