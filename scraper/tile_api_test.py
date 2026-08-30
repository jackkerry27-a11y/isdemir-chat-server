"""
MarineTraffic Tile API Test - İsdemir Port
Tile coordinates for lat:36.727, lon:36.205 at various zoom levels
"""
import sys
import math
import json

# Force UTF-8 output
sys.stdout.reconfigure(encoding='utf-8')

def lat_lon_to_tile(lat, lon, zoom):
    """Convert lat/lon to tile XY coordinates"""
    n = 2 ** zoom
    x = int((lon + 180.0) / 360.0 * n)
    lat_rad = math.radians(lat)
    y = int((1.0 - math.asinh(math.tan(lat_rad)) / math.pi) / 2.0 * n)
    return x, y

# İsdemir coordinates
LAT, LON = 36.727, 36.205

print("="*60)
print("MarineTraffic Tile API - Isdemir Port Test")
print("="*60)

# Calculate tile coordinates for different zoom levels
for zoom in [13, 14, 15]:
    tx, ty = lat_lon_to_tile(LAT, LON, zoom)
    print(f"  Zoom {zoom}: X={tx}, Y={ty}")

print()

try:
    import requests
    
    # Try multiple tile endpoints with proper headers
    session = requests.Session()
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/javascript, */*; q=0.01',
        'Accept-Language': 'en-US,en;q=0.9',
        'X-Requested-With': 'XMLHttpRequest',
        'Referer': 'https://www.marinetraffic.com/en/ais/home/centerx:36.205/centery:36.727/zoom:15',
        'Origin': 'https://www.marinetraffic.com',
    })
    
    # First visit homepage to get cookies
    print("[1] Ana sayfa ziyaret ediliyor (cookie almak icin)...")
    try:
        r = session.get('https://www.marinetraffic.com/', timeout=10)
        print(f"    Status: {r.status_code}, Cookies: {list(r.cookies.keys())}")
    except Exception as e:
        print(f"    Hata: {e}")
    
    # Try tile API endpoints
    zoom15_x, zoom15_y = lat_lon_to_tile(LAT, LON, 15)
    zoom14_x, zoom14_y = lat_lon_to_tile(LAT, LON, 14)
    zoom13_x, zoom13_y = lat_lon_to_tile(LAT, LON, 13)
    
    endpoints = [
        f"https://www.marinetraffic.com/getData/get_data_json_4/z:15/X:{zoom15_x}/Y:{zoom15_y}/station:0",
        f"https://www.marinetraffic.com/getData/get_data_json_4/z:14/X:{zoom14_x}/Y:{zoom14_y}/station:0",
        f"https://www.marinetraffic.com/getData/get_data_json_4/z:13/X:{zoom13_x}/Y:{zoom13_y}/station:0",
        # Alternative format
        f"https://www.marinetraffic.com/getData/get_data_json_4/z:15/X:{zoom15_x}/Y:{zoom15_y}/minlat:36.695/maxlat:36.755/minlon:36.160/maxlon:36.230",
    ]
    
    print("\n[2] Tile API endpoint'leri deneniyor...")
    for url in endpoints:
        try:
            print(f"\n  URL: {url[:80]}")
            r = session.get(url, timeout=15)
            print(f"  Status: {r.status_code}")
            print(f"  Content-Type: {r.headers.get('Content-Type', 'unknown')}")
            print(f"  Response length: {len(r.text)} chars")
            print(f"  Response (first 500): {r.text[:500]}")
            
            # Try to parse as JSON
            if r.status_code == 200 and len(r.text) > 10:
                try:
                    data = r.json()
                    print(f"  JSON type: {type(data)}")
                    if isinstance(data, dict):
                        print(f"  JSON keys: {list(data.keys())[:10]}")
                        if 'data' in data:
                            vessels = data['data']
                            print(f"  ** {len(vessels)} GEMI BULUNDU! **")
                            for v in vessels[:5]:
                                print(f"     {v}")
                    elif isinstance(data, list):
                        print(f"  {len(data)} item listesi")
                        for item in data[:3]:
                            print(f"    {item}")
                except:
                    pass
                    
        except Exception as e:
            print(f"  Hata: {e}")
    
    # Try with bounding box parameters
    print("\n[3] Bounding box API deneniyor...")
    bbox_endpoints = [
        "https://www.marinetraffic.com/getData/get_data_json_4/z:13/X:{}/Y:{}/minlat:36.65/maxlat:36.80/minlon:36.10/maxlon:36.30/station:0".format(zoom13_x, zoom13_y),
        "https://www.marinetraffic.com/en/getData/get_data_json_4?minlat=36.695&maxlat=36.755&minlon=36.160&maxlon=36.230",
    ]
    
    for url in bbox_endpoints:
        try:
            print(f"\n  URL: {url[:100]}")
            r = session.get(url, timeout=15)
            print(f"  Status: {r.status_code}, Length: {len(r.text)}")
            print(f"  Response: {r.text[:400]}")
        except Exception as e:
            print(f"  Hata: {e}")

except ImportError:
    print("requests yuklu degil, pip install requests")

print("\n" + "="*60)
print("TEST TAMAMLANDI")
print("="*60)
