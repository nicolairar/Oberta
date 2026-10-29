#!/bin/sh
# Ridisegna l'icona dell'app e la taglia in tutte le misure che iOS e Android
# chiedono. L'icona iOS non deve avere trasparenze: Apple rifiuta quelle che
# ne hanno.
set -e
cd "$(dirname "$0")/.."
ICON_OUT=build/app_icon.png ANDROID_ICON_DIR=build/android_icon flutter test tool/app_icon_test.dart
# Google Play vuole la sua a 32 bit (con il canale alfa, anche se pieno).
cp build/app_icon.png build/app_icon_rgba.png
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

# Android: l'icona intera per i telefoni prima di Android 8, i due livelli
# dell'icona adattiva (108 dp) per gli altri, la 512 per la scheda di Play.
RES=android/app/src/main/res
for entry in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
  density=${entry%%:*}
  rest=${entry#*:}
  legacy=${rest%%:*}
  layer=${rest##*:}
  sips -z "$legacy" "$legacy" build/app_icon_rgba.png --out "$RES/mipmap-$density/ic_launcher.png" >/dev/null
  sips -z "$layer" "$layer" build/android_icon/background.png --out "$RES/mipmap-$density/ic_launcher_background.png" >/dev/null
  sips -z "$layer" "$layer" build/android_icon/foreground.png --out "$RES/mipmap-$density/ic_launcher_foreground.png" >/dev/null
done
for lang in it-IT en-US; do
  mkdir -p "fastlane/metadata/android/$lang/images"
  sips -z 512 512 build/app_icon_rgba.png --out "fastlane/metadata/android/$lang/images/icon.png" >/dev/null
done
echo "Icone aggiornate in $RES e fastlane/metadata/android"
