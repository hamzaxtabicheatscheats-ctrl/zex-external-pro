#!/bin/bash
set -e

SDK=$(xcrun --sdk iphoneos --show-sdk-path)
echo "=== iOS SDK Path: $SDK ==="

OBJS=()

compile_file() {
    local src="$1"
    local obj="${src//\//_}.o"
    echo "Compiling $src..."
    clang -arch arm64 -isysroot "$SDK" -miphoneos-version-min=15.0 -fobjc-arc -Wno-everything -I. -I./kexploit -I./compat -I./XPF/src -I./XPF/external/ChOma/include -c "$src" -o "$obj"
    OBJS+=("$obj")
}

# Compile main C/ObjC files
for f in *.m *.c; do
    [ -f "$f" ] && compile_file "$f"
done

# Compile kexploit directory files
if [ -d "kexploit" ]; then
    for f in kexploit/*.m kexploit/*.c; do
        [ -f "$f" ] && compile_file "$f"
    done
fi

# Compile XPF directory files if present
if [ -d "XPF/src" ]; then
    for f in XPF/src/*.c XPF/src/*.m; do
        [ -f "$f" ] && compile_file "$f"
    done
fi

echo "=== Linking Binary ==="
clang -arch arm64 -isysroot "$SDK" -miphoneos-version-min=15.0 \
  -Wl,-w \
  -framework UIKit -framework Foundation -framework CoreFoundation \
  -framework Security -framework QuartzCore -framework AVFoundation \
  -framework AudioToolbox -framework ImageIO -framework CoreGraphics \
  -lz \
  -o ZEXInjector \
  "${OBJS[@]}"

echo "=== Packaging IPA ==="
mkdir -p Payload/ZEXInjector.app
cp ZEXInjector Payload/ZEXInjector.app/
cp Info.plist Payload/ZEXInjector.app/ 2>/dev/null || true
if [ -d Resources ]; then
    cp -R Resources/. Payload/ZEXInjector.app/ 2>/dev/null || true
fi

if command -v ldid &> /dev/null; then
    if [ -f entitlements.plist ]; then
        ldid -Sentitlements.plist Payload/ZEXInjector.app/ZEXInjector || true
    else
        ldid -S Payload/ZEXInjector.app/ZEXInjector || true
    fi
fi

zip -qry bankai-ZEXInjector.ipa Payload
ls -lh bankai-ZEXInjector.ipa
echo "=== IPA BUILD COMPLETE ==="
