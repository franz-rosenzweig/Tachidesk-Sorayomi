#!/bin/bash

# Script to create IPA file for Sideloadly installation
# Run this after successful flutter build ios --release --no-codesign

set -e

PROJECT_DIR="/Users/home/Documents/VS Workspaces/Tachidesk-Sorayomi"
BUILD_DIR="$PROJECT_DIR/build/ios/iphoneos"
APP_NAME="Runner.app"
IPA_NAME="Sorayomi.ipa"
OUTPUT_DIR="$PROJECT_DIR/build"

echo "🔨 Creating IPA for Sideloadly..."

# Check if the .app exists
if [ ! -d "$BUILD_DIR/$APP_NAME" ]; then
    echo "❌ Error: $BUILD_DIR/$APP_NAME not found!"
    echo "Please run: flutter build ios --release --no-codesign"
    exit 1
fi

# Create Payload directory
PAYLOAD_DIR="$OUTPUT_DIR/Payload"
rm -rf "$PAYLOAD_DIR"
mkdir -p "$PAYLOAD_DIR"

# Copy the .app bundle to Payload
echo "📦 Copying app bundle to Payload..."
cp -r "$BUILD_DIR/$APP_NAME" "$PAYLOAD_DIR/"

# Create the IPA
echo "🎁 Creating IPA file..."
cd "$OUTPUT_DIR"
zip -r "$IPA_NAME" Payload/

# Clean up
rm -rf Payload

echo "✅ IPA created successfully!"
echo "📍 Location: $OUTPUT_DIR/$IPA_NAME"
echo ""
echo "🚀 Next steps:"
echo "1. Open Sideloadly"
echo "2. Connect your iPhone via USB"
echo "3. Drag $IPA_NAME into Sideloadly"
echo "4. Enter your Apple ID credentials"
echo "5. Install to your device!"
echo ""
echo "📱 Test the new features:"
echo "   • Local device downloads (📱 icon)"
echo "   • Offline reading with fallback"
echo "   • Bulk download options"
echo "   • Multi-selection downloads"
