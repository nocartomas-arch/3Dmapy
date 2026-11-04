#!/bin/sh
# Nahraje rozcestník (složka rozcestnik/) na mapa.leweed.cz = repo 3Dmapy, větev gh-pages
set -e
cd "$(dirname "$0")"
G=mesta/rozcestnik.git
rm -rf "$G"; git --git-dir="$G" --work-tree=rozcestnik init -q -b gh-pages
git --git-dir="$G" --work-tree=rozcestnik add -A
git --git-dir="$G" --work-tree=rozcestnik -c user.name=Claude -c user.email=noreply@anthropic.com commit -q -m "Rozcestník měst"
git --git-dir="$G" push -q -f https://github.com/nocartomas-arch/3Dmapy.git gh-pages
echo "nahráno: https://mapa.leweed.cz"
