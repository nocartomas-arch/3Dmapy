#!/bin/sh
# vyrenderuje jeden čtverec mapy: ./render_chunk.sh 0,-1 [varianty]
# okraje s řezem zeminou se berou ze scény (strany bez souseda), všechny čtverce s průhledným pozadím
set -e
C=$1; shift; V=${*:-"autumn winter spring summer lights"}
if [ "$C" = "0,0" ]; then D=build; else D=build/c$(echo $C | tr ',' '_'); fi
G="gx0=-1646.34559672906 gy1=988.7958500237901"
for s in $V; do
  O=$D/tiles_$s
  [ -f "$O/.hotovo" ] && { echo "$s už je"; continue; }       # po restartu navázat: hotové varianty přeskočit
  if [ "$s" = lights ]; then
    node render.mjs mpp=0.2 dir=$D out=$O season=autumn mode=lights alpha=1 $G > $O.log
  else
    node render.mjs mpp=0.2 dir=$D out=$O season=$s alpha=1 $G > $O.log
  fi
  grep -c dlaždice $O.log; touch "$O/.hotovo"
done
echo HOTOVO $C
