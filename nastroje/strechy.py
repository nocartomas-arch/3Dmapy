"""Barvy střech podle ortofota ČÚZK -> assets/satelit.json ({'b': {id budovy: {'rc': [r, g, b]}}}).

Pro každou budovu z data*/building.parquet vezme pixely ortofota uvnitř půdorysu (zmenšeného o okraj, kvůli
posunu snímku a okapům), vyhodí stíny a zeleň (stromy přes střechu) a medián přepočte do tónu mapy.
Hodí se pro malé, detailní mapy (vesnice, čtvrť); u velkého města je ortofoto obří.

  python nastroje/strechy.py            # stáhne ortofoto (build/orto_strechy.jpg) a zapíše assets/satelit.json
  python nastroje/strechy.py --kontrola # navíc build/strechy_kontrola.png (ortofoto | naměřené barvy)
"""
import colorsys, glob, json, math, os, sys, urllib.request
sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
import numpy as np, pandas as pd, shapely
from PIL import Image, ImageDraw
from geo import bbox_lonlat

MPP = 0.15                      # rozlišení stahovaného ortofota v metrech na pixel
OKRAJ = 0.8                     # o kolik metrů zmenšit půdorys
OUT = 'assets/satelit.json'
ORTO = 'build/orto_strechy.jpg'

lon0, lon1, lat0, lat1 = bbox_lonlat(100.0)
mx = (lon1 - lon0) * 111320 * math.cos(math.radians((lat0 + lat1) / 2)); my = (lat1 - lat0) * 111320
W, H = int(mx / MPP), int(my / MPP)
if not os.path.exists(ORTO):
    # WMS má limit velikosti obrázku -> po dlaždicích 2000 px
    img = Image.new('RGB', (W, H)); T = 2000
    for ty in range(0, H, T):
        for tx in range(0, W, T):
            w, h = min(T, W - tx), min(T, H - ty)
            a0 = lon0 + (lon1 - lon0) * tx / W; a1 = lon0 + (lon1 - lon0) * (tx + w) / W
            b1 = lat1 - (lat1 - lat0) * ty / H; b0 = lat1 - (lat1 - lat0) * (ty + h) / H
            url = ('https://ags.cuzk.gov.cz/arcgis1/services/ORTOFOTO/MapServer/WMSServer?SERVICE=WMS&VERSION=1.3.0'
                   f'&REQUEST=GetMap&LAYERS=0&STYLES=&CRS=EPSG:4326&BBOX={b0},{a0},{b1},{a1}&WIDTH={w}&HEIGHT={h}&FORMAT=image/jpeg')
            img.paste(Image.open(urllib.request.urlopen(url, timeout=180)), (tx, ty))
            print('ortofoto', tx, ty, flush=True)
    img.save(ORTO, quality=92)
orto = np.asarray(Image.open(ORTO).convert('RGB')).astype(float)

def px(lon, lat):
    return (lon - lon0) / (lon1 - lon0) * W, (lat1 - lat) / (lat1 - lat0) * H

M_LON = 111320 * math.cos(math.radians((lat0 + lat1) / 2))
bld = pd.concat([pd.read_parquet(f) for f in sorted(glob.glob('data*/building.parquet'))]).drop_duplicates('id')
out, kontrola = {}, []
for _, r in bld.iterrows():
    g = shapely.from_wkb(r.geometry)
    # zmenšit v metrech: přes lokální měřítko
    gm = shapely.affinity.scale(g, M_LON, 111320, origin=(0, 0)).buffer(-OKRAJ)
    if gm.is_empty or gm.area < 6: continue
    g = shapely.affinity.scale(gm, 1 / M_LON, 1 / 111320, origin=(0, 0))
    polys = list(g.geoms) if g.geom_type == 'MultiPolygon' else [g]
    x0, y0 = px(g.bounds[0], g.bounds[3]); x1, y1 = px(g.bounds[2], g.bounds[1])
    if x1 < 0 or y1 < 0 or x0 >= W or y0 >= H: continue
    ix0, iy0, ix1, iy1 = max(0, int(x0)), max(0, int(y0)), min(W, int(x1) + 1), min(H, int(y1) + 1)
    if ix1 - ix0 < 2 or iy1 - iy0 < 2: continue
    m = Image.new('L', (ix1 - ix0, iy1 - iy0)); d = ImageDraw.Draw(m)
    for p in polys:
        d.polygon([(a - ix0, b - iy0) for a, b in (px(*c) for c in p.exterior.coords)], fill=1)
    sel = orto[iy0:iy1, ix0:ix1][np.asarray(m, bool)]
    if len(sel) < 30: continue
    lum = sel.mean(1)
    ok = (lum > 45) & ~((sel[:, 1] > sel[:, 0] + 6) & (sel[:, 1] > sel[:, 2]))   # bez stínů a bez zeleně stromů
    if ok.sum() < 0.35 * len(sel): continue                                         # střecha skoro celá pod stromem/ve stínu
    c = np.median(sel[ok], 0)
    # do tónu mapy: snímek je světlejší a vybledlejší než paleta střech
    # v HSV: sytost ×1,7 (pálené tašky mají v paletě sytost ~0,7, na snímku ~0,4), jas ×0,9; šedé (plech, eternit) nechat šedé
    h, sat, val = colorsys.rgb_to_hsv(*(c / 255))
    if sat > 0.12: sat = min(0.85, sat * 1.7)
    c = np.array(colorsys.hsv_to_rgb(h, sat, val * 0.9)) * 255
    out[r.id] = {'rc': [int(v) for v in c]}
    kontrola.append((polys, c))
old = json.load(open(OUT)) if os.path.exists(OUT) else {'b': {}, 'lu': {}, 'zones': []}
for k, v in out.items(): old['b'][k] = {**old['b'].get(k, {}), **v}
json.dump(old, open(OUT, 'w'), separators=(',', ':'))
print('střech z ortofota', len(out), 'z budov', len(bld))

if '--kontrola' in sys.argv:
    o = Image.open(ORTO).convert('RGB'); k = o.copy(); d = ImageDraw.Draw(k)
    for polys, c in kontrola:
        for p in polys: d.polygon([px(*q) for q in p.exterior.coords], fill=tuple(int(v) for v in c), outline=(0, 0, 0))
    s = Image.new('RGB', (W * 2 + 10, H), (20, 20, 20)); s.paste(o, (0, 0)); s.paste(k, (W + 10, 0))
    s.save('build/strechy_kontrola.png'); print('build/strechy_kontrola.png')
