#!/usr/bin/env bash
# Resizes tool/icon/out/*.png into the Android and iOS icon sets (macOS `sips`).
set -euo pipefail
cd "$(dirname "$0")/../.."
OUT=tool/icon/out
RES=android/app/src/main/res
IOS=ios/Runner/Assets.xcassets/AppIcon.appiconset
tmp=$(mktemp -d)

# iOS: opaque PNGs (App Store rejects alpha) — round-trip through JPEG drops the channel.
sips -s format jpeg -s formatOptions 100 "$OUT/icon_1024.png" --out "$tmp/icon.jpg" >/dev/null
for f in "$IOS"/Icon-App-*.png; do
  name=$(basename "$f")
  dims=${name#Icon-App-}; dims=${dims%.png}          # e.g. 20x20@2x
  pt=${dims%%x*}; scale=${dims##*@}; scale=${scale%x}
  px=$(python3 -c "print(round($pt*$scale))")
  sips -z "$px" "$px" "$tmp/icon.jpg" --out "$tmp/i.jpg" >/dev/null
  sips -s format png "$tmp/i.jpg" --out "$f" >/dev/null
done

# Android legacy launcher icons (48 dp) and adaptive layers (108 dp).
declare -a D=(mdpi hdpi xhdpi xxhdpi xxxhdpi)
declare -a L=(48 72 96 144 192)
declare -a A=(108 162 216 324 432)
for i in "${!D[@]}"; do
  dir="$RES/mipmap-${D[$i]}"
  mkdir -p "$dir"
  sips -z "${L[$i]}" "${L[$i]}" "$OUT/icon_1024.png" --out "$dir/ic_launcher.png" >/dev/null
  sips -z "${A[$i]}" "${A[$i]}" "$OUT/foreground_432.png" --out "$dir/ic_launcher_foreground.png" >/dev/null
  sips -z "${A[$i]}" "${A[$i]}" "$OUT/monochrome_432.png" --out "$dir/ic_launcher_monochrome.png" >/dev/null
done
mkdir -p "$RES/mipmap-anydpi-v26"
cat > "$RES/mipmap-anydpi-v26/ic_launcher.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_monochrome" />
</adaptive-icon>
XML
cat > "$RES/drawable/ic_launcher_background.xml" <<'XML'
<?xml version="1.0" encoding="utf-8"?>
<shape xmlns:android="http://schemas.android.com/apk/res/android">
    <gradient android:angle="315" android:startColor="#2F5BEA" android:endColor="#1E3FB8" android:type="linear" />
</shape>
XML
rm -rf "$tmp"
echo "Icons applied."
