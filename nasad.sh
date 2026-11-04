#!/bin/sh
# Nahraje hotový web města do jeho repa (větev gh-pages): ./nasad.sh kraluv-dvur
# Repo: nocartomas-arch/mapa-<slug>, adresa: https://nocartomas-arch.github.io/mapa-<slug>/
set -e
cd "$(dirname "$0")"
S=$1; W=mesta/$S/site; G=mesta/$S/pages.git
[ -f "$W/index.html" ] || { echo "chybí $W/index.html – město ještě není postavené"; exit 1; }
rm -f "$W/CNAME"; touch "$W/.nojekyll"
[ -d "$G" ] || git --git-dir="$G" --work-tree="$W" init -q -b gh-pages
git --git-dir="$G" --work-tree="$W" add -A
git --git-dir="$G" --work-tree="$W" -c user.name=Claude -c user.email=noreply@anthropic.com commit -q -m "Web mapy $S" || true
git --git-dir="$G" -c http.postBuffer=524288000 push -q -f "https://github.com/nocartomas-arch/mapa-$S.git" gh-pages
echo "nahráno: https://github.com/nocartomas-arch/mapa-$S (gh-pages)"
