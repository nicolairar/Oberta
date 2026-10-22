#!/usr/bin/env bash
# Copies the Steamworks redistributable library and steam_appid.txt (480,
# Spacewar) next to a built desktop app, for local tests with Steam open.
# The SDK is not in git (its license): download steamworks_sdk_XXX.zip from
# https://partner.steamgames.com/downloads/list (free Steam login) and unzip it.
#
#   flutter build macos --debug --dart-define=STEAM=true --dart-define-from-file=config/supabase.json
#   tool/steam/install_sdk.sh <path/to/unzipped/sdk> [macos|windows|linux] [debug|release]
#
# See docs/steam.md.
set -euo pipefail
sdk="${1:?path to the unzipped Steamworks SDK (the folder containing redistributable_bin)}"
platform="${2:-macos}"
mode="${3:-debug}"
appid="${STEAM_APP_ID:-480}"
bin="$sdk/redistributable_bin"
[ -d "$bin" ] || bin="$sdk/sdk/redistributable_bin"
[ -d "$bin" ] || { echo "redistributable_bin not found under $sdk" >&2; exit 1; }
Mode="$(echo "${mode:0:1}" | tr '[:lower:]' '[:upper:]')${mode:1}"

case "$platform" in
  macos)
    products="build/macos/Build/Products/$Mode"
    app="$products/oberta.app"
    [ -d "$app" ] || { echo "$app not found: build it first with --dart-define=STEAM=true" >&2; exit 1; }
    mkdir -p "$app/Contents/Frameworks"
    cp "$bin/osx/libsteam_api.dylib" "$app/Contents/Frameworks/"
    codesign --force --sign - "$app/Contents/Frameworks/libsteam_api.dylib"
    # A sandboxed app cannot talk to the Steam client: re-sign this local
    # test build ad hoc without the App Sandbox (Steam builds ship unsandboxed).
    entitlements="$(mktemp -d)/steam.entitlements"
    cat > "$entitlements" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>com.apple.security.cs.allow-jit</key><true/>
  <key>com.apple.security.cs.disable-library-validation</key><true/>
  <key>com.apple.security.network.client</key><true/>
  <key>com.apple.security.network.server</key><true/>
</dict></plist>
PLIST
    codesign --force --sign - --entitlements "$entitlements" "$app"
    rm -f "$entitlements"
    # Steam reads steam_appid.txt from the process working directory.
    echo "$appid" > "$products/steam_appid.txt"
    echo "Run: (cd $products && ./oberta.app/Contents/MacOS/oberta)"
    ;;
  windows)
    out="build/windows/x64/runner/$Mode"
    cp "$bin/win64/steam_api64.dll" "$out/"
    echo "$appid" > "$out/steam_appid.txt"
    echo "Run: cd $out && oberta.exe"
    ;;
  linux)
    out="build/linux/x64/$mode/bundle"
    cp "$bin/linux64/libsteam_api.so" "$out/lib/"
    echo "$appid" > "$out/steam_appid.txt"
    echo "Run: cd $out && ./oberta"
    ;;
  *) echo "platform: macos | windows | linux" >&2; exit 1 ;;
esac
