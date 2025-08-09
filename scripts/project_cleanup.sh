#!/usr/bin/env bash
set -euo pipefail
# Sorayomi project workspace cleanup script
# Removes local build/generated artifacts that should not be committed.

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

echo "[cleanup] Removing Flutter/Dart build + tool artifacts..."
rm -rf build .dart_tool .flutter-plugins .flutter-plugins-dependencies pubspec.lock_OLD 2>/dev/null || true

echo "[cleanup] Removing iOS Pods cache (will be re-installed with pod install)..."
rm -rf ios/Pods ios/Flutter/ephemeral 2>/dev/null || true

echo "[cleanup] Removing ad-hoc IPA / Payload artifacts..."
rm -rf build/ios/iphoneos/Payload build/ios/iphoneos/*.ipa *.ipa 2>/dev/null || true

echo "[cleanup] Removing stray macOS/iOS derived data (if accidentally placed inside repo)..."
rm -rf ios/DerivedData macos/DerivedData 2>/dev/null || true

# Generated code (leave if you want faster local builds, but safe to regenerate)
# Uncomment to force regeneration next build:
# find lib -name '*.g.dart' -delete
# find lib -name '*.freezed.dart' -delete
# find lib -name '*.graphql.dart' -delete

echo "[cleanup] Done. Recommended next steps:"
echo "  flutter pub get" 
echo "  (cd ios && pod install)"
