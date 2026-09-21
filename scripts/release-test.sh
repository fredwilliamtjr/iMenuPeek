#!/bin/zsh
# Build an ad-hoc signed, NOT notarized Universal test DMG. Does not publish.
set -euo pipefail
VERSION="${1:?usage: release-test.sh <x.y.z-beta.n>}"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+-beta\.[0-9]+$' ]] || {
  print -u2 -- 'Use a beta version such as 0.3.0-beta.1'; exit 2
}
ROOT="${0:A:h:h}"
cd "$ROOT"
[[ -z "$(git status --porcelain)" ]] || { print -u2 -- 'Commit changes before packaging a reproducible release.'; exit 2; }
NUMERIC_VERSION="${VERSION%%-*}"
SOURCE_COMMIT="$(git rev-parse HEAD)"
BUILD_NUMBER="$(git rev-list --count HEAD)"
OUTPUT="$ROOT/build/test-release/$VERSION"
DMG="$OUTPUT/MenuMate-$VERSION-universal.dmg"
[[ ! -e "$DMG" ]] || { print -u2 -- "Artifact already exists: $DMG"; exit 2; }
mkdir -p "$OUTPUT"
make gen
xcodebuild -project MenuMate.xcodeproj -scheme MenuMate -configuration Release \
  -derivedDataPath "$ROOT/build" -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM='' \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  MARKETING_VERSION="$NUMERIC_VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" build
APP="$ROOT/build/Build/Products/Release/MenuMate.app"
EXT="$APP/Contents/PlugIns/FinderExtension.appex"
/usr/bin/lipo -verify_arch arm64 x86_64 "$APP/Contents/MacOS/MenuMate"
/usr/bin/lipo -verify_arch arm64 x86_64 "$EXT/Contents/MacOS/FinderExtension"
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/codesign -dvv "$APP" 2>&1 | /usr/bin/grep -q 'Signature=adhoc'
/usr/bin/codesign -dvv "$EXT" 2>&1 | /usr/bin/grep -q 'Signature=adhoc'
[[ "$(/usr/libexec/PlistBuddy -c 'Print :SUEnableAutomaticChecks' "$APP/Contents/Info.plist")" == false ]]

STAGE="$(mktemp -d "$OUTPUT/stage.XXXXXXXX")"
trap '/bin/rm -rf -- "$STAGE"' EXIT
/usr/bin/ditto "$APP" "$STAGE/MenuMate.app"
ln -s /Applications "$STAGE/Applications"
cp docs/INSTALL-TEST.md "$STAGE/INSTALL.md"
cp LICENSE "$STAGE/LICENSE.txt"
{
  print -r -- "MenuMate $VERSION"
  print -r -- "Source: $SOURCE_COMMIT"
  print -r -- "Bundle version: $NUMERIC_VERSION ($BUILD_NUMBER)"
  print -r -- 'Architectures: arm64 + x86_64; minimum macOS 13'
  print -r -- 'Signature: ad-hoc; Apple notarization: NO; automatic updates: disabled'
  xcodebuild -version
} > "$OUTPUT/BUILD-INFO.txt"
cp "$OUTPUT/BUILD-INFO.txt" "$STAGE/BUILD-INFO.txt"
cp docs/INSTALL-TEST.md "$OUTPUT/INSTALL.md"
/usr/bin/hdiutil create -volname "MenuMate $VERSION" -srcfolder "$STAGE" -format UDZO "$DMG"
/usr/bin/hdiutil verify "$DMG"
(cd "$OUTPUT" && /usr/bin/shasum -a 256 "${DMG:t}" BUILD-INFO.txt INSTALL.md > SHA256SUMS.txt)
print -r -- "Test release ready: $OUTPUT"
