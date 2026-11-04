#!/bin/sh
# Postaví postupně víc měst: ./stavba_mest.sh jilove-u-prahy varnsdorf
cd "$(dirname "$0")"
for s in "$@"; do
  ./mesto.sh "$s" && echo "=== START $s $(date +%H:%M)" && ./postav.sh > "mesta/$s/postav.log" 2>&1 && echo "=== HOTOVO $s $(date +%H:%M)" || echo "=== CHYBA $s $(date +%H:%M) (mesta/$s/postav.log)"
done
