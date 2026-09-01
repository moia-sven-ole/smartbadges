#!/bin/bash

# Exit on error
set -e

echo "=== Building SmartBadges ==="

# Define target paths
APP_NAME="SmartBadges"
APP_BUNDLE="${APP_NAME}.app"
MACOS_DIR="${APP_BUNDLE}/Contents/MacOS"
RESOURCES_DIR="${APP_BUNDLE}/Contents/Resources"

echo "Creating App Bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

echo "Compiling Swift source files..."
# Find all swift files in src/
SWIFT_FILES=$(find src -name "*.swift")

if [ -z "$SWIFT_FILES" ]; then
    echo "Error: No Swift files found in src/ directory!"
    exit 1
fi

swiftc -O \
    -sdk "$(xcrun --show-sdk-path -sdk macosx)" \
    -target arm64-apple-macos13.0 \
    -o "${MACOS_DIR}/${APP_NAME}" \
    $SWIFT_FILES

# Generate AppIcon.icns if the source image exists
if [ -f "src/AppIcon.jpg" ]; then
    echo "Creating AppIcon.icns from src/AppIcon.jpg..."
    mkdir -p SmartBadges.iconset
    sips -s format png -z 16 16     src/AppIcon.jpg --out SmartBadges.iconset/icon_16x16.png > /dev/null 2>&1
    sips -s format png -z 32 32     src/AppIcon.jpg --out SmartBadges.iconset/icon_16x16@2x.png > /dev/null 2>&1
    sips -s format png -z 32 32     src/AppIcon.jpg --out SmartBadges.iconset/icon_32x32.png > /dev/null 2>&1
    sips -s format png -z 64 64     src/AppIcon.jpg --out SmartBadges.iconset/icon_32x32@2x.png > /dev/null 2>&1
    sips -s format png -z 128 128   src/AppIcon.jpg --out SmartBadges.iconset/icon_128x128.png > /dev/null 2>&1
    sips -s format png -z 256 256   src/AppIcon.jpg --out SmartBadges.iconset/icon_128x128@2x.png > /dev/null 2>&1
    sips -s format png -z 256 256   src/AppIcon.jpg --out SmartBadges.iconset/icon_256x256.png > /dev/null 2>&1
    sips -s format png -z 512 512   src/AppIcon.jpg --out SmartBadges.iconset/icon_256x256@2x.png > /dev/null 2>&1
    sips -s format png -z 512 512   src/AppIcon.jpg --out SmartBadges.iconset/icon_512x512.png > /dev/null 2>&1
    sips -s format png -z 1024 1024 src/AppIcon.jpg --out SmartBadges.iconset/icon_512x512@2x.png > /dev/null 2>&1
    
    iconutil -c icns SmartBadges.iconset -o "${RESOURCES_DIR}/AppIcon.icns"
    rm -rf SmartBadges.iconset
    echo "AppIcon.icns created and packaged!"
fi

echo "Copying Info.plist..."
cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"

# Ensure stable code-signing certificate exists in login keychain
if ! security find-certificate -c "SmartBadgesDev" >/dev/null 2>&1; then
    echo "Creating a stable local developer certificate to preserve accessibility permissions..."
    cat <<EOF > codesign.cnf
[ req ]
default_bits = 2048
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[ dn ]
CN = SmartBadgesDev

[ v3_req ]
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
EOF

    openssl req -x509 -config codesign.cnf -days 3650 -out codesign_cert.pem -keyout codesign_key.pem -newkey rsa:2048 -nodes > /dev/null 2>&1
    openssl pkcs12 -export -out codesign_identity.p12 -inkey codesign_key.pem -in codesign_cert.pem -passout pass:1234 > /dev/null 2>&1
    # Target default login keychain robustly across macOS versions
    KEYCHAIN="$(security default-keychain | tr -d '"' | xargs)"
    [ -z "$KEYCHAIN" ] && KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"
    security import codesign_identity.p12 -k "$KEYCHAIN" -P "1234" -A -T /usr/bin/codesign > /dev/null 2>&1
    rm codesign.cnf codesign_cert.pem codesign_key.pem codesign_identity.p12
fi

echo "Code signing the App Bundle with stable developer certificate..."
codesign --force --deep --sign "SmartBadgesDev" "${APP_BUNDLE}"

echo "Updating macOS Launch Services icon cache..."
/System/Library/Frameworks/CoreServices.framework/Versions/A/Frameworks/LaunchServices.framework/Versions/A/Support/lsregister -f "${APP_BUNDLE}" || true
touch "${APP_BUNDLE}"

echo "=== Build Complete: ${APP_BUNDLE} created successfully! ==="
echo "You can launch the app by running: open ${APP_BUNDLE}"
