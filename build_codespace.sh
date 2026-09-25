#!/bin/bash
set -e
echo "=== Installing dependencies ==="
sudo apt-get update -qq
sudo apt-get install -y -qq clang zip curl

# Install ldid
curl -sL https://github.com/ProcursusTeam/ldid/releases/latest/download/ldid_linux_x86_64 -o /usr/local/bin/ldid
chmod +x /usr/local/bin/ldid

# Download iOS SDK
echo "=== Downloading iOS SDK ==="
mkdir -p /opt/ios-sdk
curl -sL "https://github.com/nicspecZw/iPhoneOS-SDKs/releases/download/17.5/iPhoneOS17.5.sdk.tar.xz" -o /tmp/sdk.tar.xz || \
curl -sL "https://github.com/nicspecZw/iPhoneOS-SDKs/releases/download/16.5/iPhoneOS16.5.sdk.tar.xz" -o /tmp/sdk.tar.xz || \
curl -sL "https://github.com/theos/sdks/raw/master/iPhoneOS14.5.sdk.tar.xz" -o /tmp/sdk.tar.xz

tar xf /tmp/sdk.tar.xz -C /opt/ios-sdk/ 2>/dev/null || true
SDK=$(ls -d /opt/ios-sdk/iPhoneOS*.sdk 2>/dev/null | head -1)
echo "SDK: $SDK"

if [ -z "$SDK" ]; then
    echo "ERROR: No SDK found, listing /opt/ios-sdk/"
    ls -la /opt/ios-sdk/
    exit 1
fi

echo "=== Compiling ==="
OBJS=()

compile_file() {
    local src="$1"
    if [ ! -f "$src" ]; then echo "Skip: $src"; return; fi
    local obj="${src//\//_}.o"
    echo "CC $src"
    clang -target arm64-apple-ios15.0 -isysroot "$SDK" -fobjc-arc -Wno-everything \
      -I. -I./kexploit -I./kpf -I./utils -I./compat \
      -I./XPF/src -I./XPF/external/ChOma/include -I./XPF/external/ChOma/src \
      -c "$src" -o "$obj" 2>&1 || true
    [ -f "$obj" ] && OBJS+=("$obj")
}

SOURCES=(
    "main.m" "AppDelegate.m" "ZEXInjectorVC.m" "ZEXFileService.m"
    "MCMBridge.m" "MCMFilzaIntegration.m" "sandbox_escape.m" "apfs_own.m"
    "kexploit/kexploit_opa334.m" "kexploit/krw.m" "kexploit/kutils.m"
    "kexploit/offsets.m" "kexploit/vnode.m" "kpf/patchfinder.m"
    "utils/file.c" "utils/hexdump.c" "utils/process.c"
)

for f in "${SOURCES[@]}"; do compile_file "$f"; done

# XPF
if [ -d "XPF/src" ]; then
    for f in XPF/src/*.c; do [ -f "$f" ] && compile_file "$f"; done
fi
if [ -d "XPF/external/ChOma/src" ]; then
    for f in XPF/external/ChOma/src/*.c; do [ -f "$f" ] && compile_file "$f"; done
fi

echo "=== Linking ==="
clang -target arm64-apple-ios15.0 -isysroot "$SDK" \
  -Wl,-w \
  -framework UIKit -framework Foundation -framework CoreFoundation \
  -framework Security -framework QuartzCore -framework AVFoundation \
  -framework AudioToolbox -framework ImageIO -framework CoreGraphics \
  -lz -o ZEXInjector "${OBJS[@]}" 2>&1 || {
    echo "Linker failed, trying with fuse-ld=lld..."
    clang -target arm64-apple-ios15.0 -isysroot "$SDK" \
      -fuse-ld=lld -Wl,-w \
      -framework UIKit -framework Foundation -framework CoreFoundation \
      -framework Security -framework QuartzCore -framework AVFoundation \
      -framework AudioToolbox -framework ImageIO -framework CoreGraphics \
      -lz -o ZEXInjector "${OBJS[@]}"
  }

echo "=== Packaging IPA ==="
mkdir -p Payload/ZEXInjector.app
cp ZEXInjector Payload/ZEXInjector.app/
cp Info.plist Payload/ZEXInjector.app/ 2>/dev/null || true
[ -d Resources ] && cp -R Resources/. Payload/ZEXInjector.app/ 2>/dev/null || true

ldid -Sentitlements.plist Payload/ZEXInjector.app/ZEXInjector 2>/dev/null || ldid -S Payload/ZEXInjector.app/ZEXInjector 2>/dev/null || true

zip -qry ZEX-FREE.ipa Payload
ls -lh ZEX-FREE.ipa
echo "=== BUILD COMPLETE ==="