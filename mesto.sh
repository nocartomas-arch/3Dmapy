#!/bin/sh
# Přepne aktivní město. Každé město má složku mesta/<slug>/ a v kořeni repa jsou na ni jen odkazy (symlinky).
#   ./mesto.sh                 vypíše města a které je aktivní
#   ./mesto.sh beroun          přepne na Beroun (nové město: založí prázdnou složku, pak python novy_mesto.py "Beroun")
# Verzuje se jen recept města (mesto.json, mista.json, assets/dominanty.json); data, build a site jsou v .gitignore.
set -e
cd "$(dirname "$0")"
FILES="mesto.json mista.json assets/dominanty.json assets/dmp_vysky.json assets/zabaged.json"
DIRS="build site data data_all"
cur=$(cat .mesto 2>/dev/null || true)

if [ -z "$1" ]; then
  for d in mesta/*/; do s=$(basename "$d"); [ "$s" = "$cur" ] && echo "* $s" || echo "  $s"; done
  exit 0
fi
new=$1

# 1) uklidit kořen do složky aktuálního města (skutečné soubory přesunout, symlinky smazat)
if [ -n "$cur" ]; then
  mkdir -p "mesta/$cur/assets"
  for p in $FILES $DIRS data_c*; do
    [ -e "$p" ] || [ -L "$p" ] || continue
    if [ -L "$p" ]; then rm "$p"; else rm -rf "mesta/$cur/$p"; mv "$p" "mesta/$cur/$p"; fi
  done
else
  # první spuštění: co leží v kořeni, patří městu, na které přepínáme
  mkdir -p "mesta/$new/assets"
  for p in $FILES $DIRS data_c*; do
    [ -e "$p" ] && [ ! -L "$p" ] && { rm -rf "mesta/$new/$p"; mv "$p" "mesta/$new/$p"; }
  done
fi

# 2) odkazy na nové město
mkdir -p "mesta/$new/assets"
for d in $DIRS; do mkdir -p "mesta/$new/$d"; ln -sfn "mesta/$new/$d" "$d"; done
for d in mesta/"$new"/data_c*; do [ -d "$d" ] && ln -sfn "$d" "$(basename "$d")"; done
ln -sfn "mesta/$new/mesto.json" mesto.json
ln -sfn "mesta/$new/mista.json" mista.json
for f in dominanty.json dmp_vysky.json zabaged.json; do ln -sfn "../mesta/$new/assets/$f" "assets/$f"; done
echo "$new" > .mesto
echo "aktivní město: $new"
[ -f "mesta/$new/mesto.json" ] || echo "nové město – založ ho: .venv/bin/python novy_mesto.py \"Název\" --dotaz \"Název, okres X\""
