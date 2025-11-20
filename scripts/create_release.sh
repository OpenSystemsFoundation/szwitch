#!/bin/bash
set -e

# Configuration
APP_NAME="Szwitch"
VERSION=${1:-"1.0.0"}
BUILD_DIR=".build/release"
APP_BUNDLE="$APP_NAME.app"
DIST_DIR="dist"
DMG_NAME="$APP_NAME-$VERSION.dmg"
ZIP_NAME="$APP_NAME-$VERSION.zip"

echo "🚀 Creating release for $APP_NAME v$VERSION"

# Step 1: Generate icons if they don't exist
if [ ! -f "AppIcon.icns" ]; then
    echo "📦 Generating app icons..."
    swift scripts/create_icon.swift
fi

# Step 2: Build the app
echo "🔨 Building app..."
./scripts/build_app.sh

# Step 3: Create distribution directory
echo "📁 Creating distribution directory..."
rm -rf "$DIST_DIR"
mkdir -p "$DIST_DIR"

# Step 4: Create DMG installer (recommended for macOS)
echo "💿 Creating DMG installer..."
# Create temporary directory for DMG contents
DMG_TEMP="$DIST_DIR/dmg_temp"
mkdir -p "$DMG_TEMP"

# Copy app to temp directory
cp -R "$APP_BUNDLE" "$DMG_TEMP/"

# Create Applications symlink for easy installation
ln -s /Applications "$DMG_TEMP/Applications"

# Create the DMG
hdiutil create -volname "$APP_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov -format UDZO \
    "$DIST_DIR/$DMG_NAME"

# Clean up temp directory
rm -rf "$DMG_TEMP"

echo "✅ DMG created: $DIST_DIR/$DMG_NAME"

# Step 5: Create ZIP archive (alternative distribution method)
echo "📦 Creating ZIP archive..."
cd "$APP_BUNDLE/.." && zip -r "$DIST_DIR/$ZIP_NAME" "$APP_NAME.app" > /dev/null && cd -

echo "✅ ZIP created: $DIST_DIR/$ZIP_NAME"

# Step 6: Calculate checksums
echo "🔐 Calculating checksums..."
cd "$DIST_DIR"
shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
shasum -a 256 "$ZIP_NAME" > "$ZIP_NAME.sha256"
cd -

echo ""
echo "✨ Release artifacts created in $DIST_DIR/:"
ls -lh "$DIST_DIR"

echo ""
echo "📋 Next steps:"
echo "1. Test the installer: open $DIST_DIR/$DMG_NAME"
echo "2. Create a GitHub release:"
echo "   gh release create v$VERSION $DIST_DIR/$DMG_NAME $DIST_DIR/$ZIP_NAME \\"
echo "     --title \"$APP_NAME v$VERSION\" \\"
echo "     --notes \"Release notes here\""
echo ""
echo "3. Or upload manually:"
echo "   - Go to https://github.com/OpenSystemsFoundation/szwitch/releases/new"
echo "   - Tag: v$VERSION"
echo "   - Upload: $DMG_NAME, $ZIP_NAME, and their .sha256 files"
