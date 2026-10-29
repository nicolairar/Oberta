#!/bin/sh
# Rebuilds every screenshot and clip of the landing page (site/oberta/img/ and
# site/oberta/video/) in one go: renders the live app through the render tests,
# then shrinks the PNGs to web JPEGs with `sips` and cuts the promo shorts with
# AVFoundation (tool/site/web_video.swift). Nothing to install.
#
#   tool/site/refresh_media.sh            screenshots + clips
#   SKIP_VIDEO=1 tool/site/refresh_media.sh   screenshots only
#   SKIP_SHOTS=1 tool/site/refresh_media.sh   clips only
#
# The promo shorts are read from ~/Documents unless VITO / TONY point elsewhere.
set -eu
cd "$(dirname "$0")/../.."

site=site/oberta
shots=build/site_shots
vito=${VITO:-$HOME/Documents/VitoLong19201080.mp4}
tony=${TONY:-$HOME/Documents/Tony15sec19201080.mp4}

if [ -z "${SKIP_SHOTS:-}" ]; then
rm -rf "$shots"
RAW=1 DEVICE=iphone65 LANG_ONLY=it OUT="$shots/store" flutter test tool/render/store_screenshots_render_test.dart
OUT="$shots/ranked" flutter test tool/render/ranked_lobby_render_test.dart
OUT="$shots/roles" flutter test tool/render/roles_collection_render_test.dart

# Phone screenshots, 600 px wide (300 CSS px at 2x), JPEG.
jpg() {
  sips -s format jpeg -s formatOptions 70 --resampleWidth 600 "$1" --out "$site/img/$2.jpg" >/dev/null
  echo "img/$2.jpg $(($(stat -f %z "$site/img/$2.jpg") / 1024)) KB"
}
jpg "$shots/store/it/03_iphone65_night.png" notte
jpg "$shots/store/it/06_iphone65_shop.png" bottega
jpg "$shots/ranked/20_entry_393.png" classificata
jpg "$shots/roles/phone_it_1_grid.png" collezione
fi

[ -n "${SKIP_VIDEO:-}" ] && exit 0
mkdir -p "$site/video"
v="swift -suppress-warnings tool/site/web_video.swift"
# Hero: the whole Zio Vito short, no audio track.
$v clip "$vito" "$site/video/hero.mp4" --width 540 --kbps 650
$v frame "$vito" "$site/video/hero.jpg" --at 2.5 --width 540 --quality 0.6
# Section loops, 2-4 s each, cut between two scene changes of the shorts.
loop() { # name src start duration poster-at
  $v clip "$2" "$site/video/$1.mp4" --start "$3" --duration "$4" --width 360 --kbps 420
  $v frame "$2" "$site/video/$1.jpg" --at "$5" --width 360 --quality 0.6
}
loop voce "$vito" 23.0 2.3 24.0
loop voto "$tony" 7.0 4.4 10.5
loop molo "$tony" 11.9 3.0 14.0
loop look "$tony" 21.0 3.0 22.3
