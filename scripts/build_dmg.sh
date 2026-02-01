#!/bin/bash
set -e

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$DIR/.."
BUILD_DIR="$PROJECT_ROOT/build"
DMG_PATH="$BUILD_DIR/Pastelet.dmg"

# 0. Check for version argument
if [ -n "$1" ]; then
    VERSION="$1"
    echo "Setting version to $VERSION..."
    # Update MARKETING_VERSION in project.pbxproj
    sed -i '' "s/MARKETING_VERSION = .*/MARKETING_VERSION = $VERSION;/g" "$PROJECT_ROOT/Pastelet.xcodeproj/project.pbxproj"
    
    # Update DMG name
    DMG_PATH="$BUILD_DIR/Pastelet-$VERSION.dmg"
else
    echo "No version specified. Using current project version."
fi

# Check for create-dmg
if ! command -v create-dmg &> /dev/null; then
    echo "Error: create-dmg is not installed. Please install it using 'brew install create-dmg'."
    exit 1
fi

echo "Cleaning build directory..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building project (Ad-Hoc)..."
# Build directly with local signing (no account required)
xcodebuild build \
    -project "$PROJECT_ROOT/Pastelet.xcodeproj" \
    -scheme "Pastelet" \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR" \
    -destination 'generic/platform=macOS' \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    PROVISIONING_PROFILE_SPECIFIER="" \
    -quiet

# Location of the built app
APP_PATH="$BUILD_DIR/Build/Products/Release/Pastelet.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: App not found at $APP_PATH"
    exit 1
fi

echo "Force signing application..."
codesign --force --deep --sign "-" "$APP_PATH"

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
  "$APP_PATH"

echo "DMG created successfully: $DMG_PATH"
open "$BUILD_DIR"
