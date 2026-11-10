#!/usr/bin/env bash
# Fetches the Xray core for bundling.
#   tool/fetch_core.sh linux [64|arm64-v8a]   -> ./core (xray, geoip.dat, geosite.dat)
#   tool/fetch_core.sh macos [64|arm64-v8a]   -> ./core
#   tool/fetch_core.sh android                -> android/app/libs/libXray.aar + android/app/src/main/assets/core/*.dat
#   tool/fetch_core.sh ios                    -> ios/Frameworks/LibXray.xcframework
# Android/iOS need Go + gomobile (libXray is built from source).
set -euo pipefail
cd "$(dirname "$0")/.."

target="${1:-linux}"
arch="${2:-64}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
gh="https://github.com/XTLS/Xray-core/releases/latest/download"

geo() {
  mkdir -p "$1"
  curl -fsSL -o "$1/geoip.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geoip.dat
  curl -fsSL -o "$1/geosite.dat" https://github.com/Loyalsoldier/v2ray-rules-dat/releases/latest/download/geosite.dat
}

case "$target" in
  linux|macos)
    os=$([ "$target" = linux ] && echo linux || echo macos)
    curl -fsSL -o "$tmp/x.zip" "$gh/Xray-$os-$arch.zip"
    mkdir -p core
    unzip -o -q "$tmp/x.zip" xray geoip.dat geosite.dat -d core
    chmod +x core/xray
    core/xray version | head -n1
    ;;
  android|ios)
    command -v go >/dev/null || { echo "Go is required to build libXray" >&2; exit 1; }
    git clone --depth 1 https://github.com/XTLS/libXray.git "$tmp/libXray"
    (cd "$tmp/libXray" && python3 build/main.py "$([ "$target" = ios ] && echo apple || echo android)" $([ "$target" = ios ] && echo gomobile))
    if [ "$target" = android ]; then
      mkdir -p android/app/libs
      cp "$tmp"/libXray/libXray.aar android/app/libs/
      geo android/app/src/main/assets/core
    else
      mkdir -p ios/Frameworks
      xcf="$(find "$tmp/libXray" -maxdepth 3 -name LibXray.xcframework -type d | head -n1)"
      [ -n "$xcf" ] || { echo "LibXray.xcframework was not produced" >&2; exit 1; }
      cp -R "$xcf" ios/Frameworks/
      geo ios/PacketTunnel/Resources
    fi
    ;;
  *) echo "unknown target: $target" >&2; exit 2 ;;
esac
