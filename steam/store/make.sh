#!/bin/sh
# Rifà le immagini della pagina Steam: le prove scrivono i PNG grezzi in
# build/steam, questo script li mette in steam/store (le foto e gli sfondi
# grandi in JPEG, così il repository resta leggero). Da lanciare dalla radice
# del progetto, su macOS (usa i caratteri di sistema e sips).
set -e
cd "$(dirname "$0")/../.."

flutter test tool/render/steam_achievements_render_test.dart
flutter test tool/render/steam_art_render_test.dart
flutter test tool/render/steam_screenshots_render_test.dart

jpeg() { sips -s format jpeg -s formatOptions 90 "$1" --out "$2" >/dev/null; }

rm -rf steam/store/art steam/store/screenshots
mkdir -p steam/store/art steam/store/screenshots/en steam/store/screenshots/it

for f in build/steam/art/*; do
  name=$(basename "$f" .png)
  case "$name" in
    # Grandi e senza trasparenza: JPEG.
    library_hero_*|page_background_*|main_capsule_*) jpeg "$f" "steam/store/art/$name.jpg" ;;
    *) cp "$f" steam/store/art/ ;;
  esac
done

for lang in en it; do
  for f in build/steam/screenshots/$lang/*.png; do
    jpeg "$f" "steam/store/screenshots/$lang/$(basename "$f" .png).jpg"
  done
done
du -sh steam/store/art steam/store/screenshots
