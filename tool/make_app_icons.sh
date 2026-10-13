#!/bin/sh
# Ridisegna l'icona dell'app e la taglia in tutte le misure che iOS chiede.
# L'icona non deve avere trasparenze: Apple rifiuta quelle che ne hanno.
set -e
cd "$(dirname "$0")/.."
ICON_OUT=build/app_icon.png flutter test tool/app_icon_test.dart
# Passare dal JPEG (alla massima qualità) è il modo più semplice per
# togliere il canale alfa con i soli strumenti di macOS.
sips -s format jpeg -s formatOptions 100 build/app_icon.png --out build/app_icon.jpg >/dev/null
sips -s format png build/app_icon.jpg --out build/app_icon.png >/dev/null
SET=ios/Runner/Assets.xcassets/AppIcon.appiconset
for entry in 20x20@1x:20 20x20@2x:40 20x20@3x:60 29x29@1x:29 29x29@2x:58 29x29@3x:87 \
             40x40@1x:40 40x40@2x:80 40x40@3x:120 60x60@2x:120 60x60@3x:180 \
             76x76@1x:76 76x76@2x:152 83.5x83.5@2x:167 1024x1024@1x:1024; do
  name=${entry%%:*}
  size=${entry##*:}
  sips -z "$size" "$size" build/app_icon.png --out "$SET/Icon-App-$name.png" >/dev/null
done
echo "Icone aggiornate in $SET"
