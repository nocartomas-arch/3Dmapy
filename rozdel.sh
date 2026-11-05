#!/bin/sh
# Rozdělí příliš velký web města (GitHub Pages: max 1 GB na web) do dvou rep:
# dlaždice jedné varianty (např. winter) jdou do repa mapa-<slug>-<pripona>, tiles.json na ně ukáže plnou adresou.
#   ./rozdel.sh beroun winter zima     -> mesta/beroun/site_hlavni (pro mapa-beroun) + mesta/beroun/site_zima (pro mapa-beroun-zima)
# Soubory se nekopírují, jen pevné odkazy (hardlinky) – nezabere to místo na disku. Původní site/ zůstává beze změny.
set -e
cd "$(dirname "$0")"
slug=$1; var=$2; pr=$3
D=mesta/$slug
[ -f "$D/site/tiles.json" ] || { echo "chybí $D/site/tiles.json"; exit 1; }
rm -rf "$D/site_hlavni" "$D/site_$pr"
cp -al "$D/site" "$D/site_hlavni"
mkdir -p "$D/site_$pr/tiles"
for d in "$D"/site_hlavni/tiles/$var "$D"/site_hlavni/tiles/*/$var; do
  [ -d "$d" ] || continue
  rel=${d#$D/site_hlavni/}
  mkdir -p "$D/site_$pr/$(dirname "$rel")"
  mv "$d" "$D/site_$pr/$rel"
done
touch "$D/site_$pr/.nojekyll"
URL="https://nocartomas-arch.github.io/mapa-$slug-$pr/"
rm "$D/site_hlavni/tiles.json"   # hardlink -> nahradit novým souborem, ať se nezmění originál
.venv/bin/python - "$D/site/tiles.json" "$D/site_hlavni/tiles.json" "$var" "$URL" <<'EOF'
import json, sys
src, dst, var, url = sys.argv[1:]
t = json.load(open(src)); n = 0
def walk(o):
    global n
    if isinstance(o, dict):
        for k, v in o.items():
            if k == 'Url' and isinstance(v, str) and v.startswith('tiles/') and v.rstrip('/').endswith('/' + var):
                o[k] = url + v; n += 1
            else: walk(v)
    elif isinstance(o, list):
        for v in o: walk(v)
walk(t)
json.dump(t, open(dst, 'w'), ensure_ascii=False, separators=(',', ':'))
print('přesměrováno adres:', n)
EOF
du -shL "$D/site_hlavni" "$D/site_$pr"
