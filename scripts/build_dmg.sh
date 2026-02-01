#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/Pastelet.xcarchive"
EXPORT_PATH="$BUILD_DIR/Export"
PLIST_PATH="$DIR/ExportOptions.plist"
DMG_PATH="$BUILD_DIR/Pastelet.dmg"

# Check for create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed. Please install it using 'brew install create-dmg'."
    exit 1
fi

echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Archiving project..."
# xcodebuild archive
xcodebuild archive \
    -project "$PROJECT_ROOT/Pastelet.xcodeproj" \
    -scheme "Pastelet" \
    -archivePath "$ARCHIVE_PATH" \
    -configuration Release \
    -destination 'generic/platform=macOS' \
    -quiet

echo "Exporting archive..."
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportOptionsPlist "$PLIST_PATH" \
    -exportPath "$EXPORT_PATH" \
    -quiet

echo "Creating DMG..."
rm -f "$DMG_PATH"

create-dmg \
  --volname "Pastelet Installer" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "Pastelet.app" 175 190 \
  --hide-extension "Pastelet.app" \
  --app-drop-link 425 190 \
  "$DMG_PATH" \
  "$EXPORT_PATH/Pastelet.app"

echo "DMG created successfully: $DMG_PATH"
open "$BUILD_DIR"
