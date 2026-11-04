#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
out="${1:-$PWD/dist}"
mkdir -p "$out"
out="$(cd "$out" && pwd)"
stage="$(mktemp -d /tmp/fh5-preview-patch.XXXXXX)"
package="$stage/地平线5补丁"
app="$package/地平线5补丁.app"
resources="$app/Contents/Resources"
mkdir -p "$resources" "$app/Contents/MacOS"
cp patch.sh prepare-alias.pl find-steam.sh "$resources/"
x86_64-w64-mingw32-gcc -shared -O2 -static-libgcc -Wl,--no-insert-timestamp -o "$resources/d3d12.dll" d3d12.c d3d12.def
swiftc -O Launcher.swift -o "$app/Contents/MacOS/FH5Patch"
cat > "$app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "https://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>local.fh5.previewpatch</string>
<key>CFBundleExecutable</key><string>FH5Patch</string>
<key>CFBundleName</key><string>地平线5补丁</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.2.0</string>
<key>CFBundleVersion</key><string>5</string>
<key>LSMinimumSystemVersion</key><string>27.0</string>
</dict></plist>
PLIST
xattr -cr "$app"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
cp README.md "$package/使用说明.md"
mkdir -p "$package/源码"
cp build.sh Launcher.swift patch.sh prepare-alias.pl find-steam.sh ./*.command d3d12.c d3d12.def COPYING README.md "$package/源码/"

command_dir="$package/终端版"
mkdir -p "$command_dir"
cp ./*.command patch.sh prepare-alias.pl find-steam.sh "$resources/d3d12.dll" "$command_dir/"

archive=FH5-CrossOver-Preview-Patch-Combined-1.2.0.zip
ditto -c -k --keepParent "$package" "$stage/$archive"
mv -f "$stage/$archive" "$out/$archive"
printf '%s\n' "$out/$archive"
