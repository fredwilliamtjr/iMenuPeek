#!/bin/zsh
# Versão final do iMenuPeek (padrão da família Peek): dist/iMenuPeek.app, dist/iMenuPeek.dmg,
# dist/iMenuPeek.zip e dist/SHA256SUMS.txt. Universal (arm64 + x86_64), assinatura ad-hoc, sem notarização.
# Uso: zsh scripts/build_release.sh 0.1.0
set -euo pipefail
VERSION="${1:?uso: build_release.sh <x.y.z>}"
[[ "$VERSION" =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]] || { print -u2 -- 'Use uma versão no formato x.y.z (ex.: 0.1.0)'; exit 2; }
ROOT="${0:A:h:h}"
cd "$ROOT"
[[ -z "$(git status --porcelain)" ]] || { print -u2 -- 'Faça o commit antes de gerar a versão (build reproduzível).'; exit 2; }
BUILD_NUMBER="$(git rev-list --count HEAD)"

make gen
xcodebuild -project iMenuPeek.xcodeproj -scheme iMenuPeek -configuration Release \
  -derivedDataPath "$ROOT/build" -destination 'generic/platform=macOS' \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- DEVELOPMENT_TEAM='' \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" build

APP="$ROOT/build/Build/Products/Release/iMenuPeek.app"
EXT="$APP/Contents/PlugIns/FinderExtension.appex"
# lipo do Xcode 27 aceita uma arquitetura por -verify_arch
for arch in arm64 x86_64; do
  /usr/bin/lipo "$APP/Contents/MacOS/iMenuPeek" -verify_arch "$arch"
  /usr/bin/lipo "$EXT/Contents/MacOS/FinderExtension" -verify_arch "$arch"
done
/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" == "$VERSION" ]]
# sem Sparkle: nada de feed de atualização nem framework embutido
! /usr/libexec/PlistBuddy -c 'Print :SUFeedURL' "$APP/Contents/Info.plist" >/dev/null 2>&1
[[ ! -e "$APP/Contents/Frameworks/Sparkle.framework" ]]

DIST="$ROOT/dist"
rm -rf "$DIST"
mkdir -p "$DIST/dmg"
/usr/bin/ditto "$APP" "$DIST/iMenuPeek.app"
/usr/bin/ditto "$APP" "$DIST/dmg/iMenuPeek.app"
ln -s /Applications "$DIST/dmg/Applications"
/usr/bin/hdiutil create -volname "iMenuPeek" -srcfolder "$DIST/dmg" -format UDZO "$DIST/iMenuPeek.dmg"
/usr/bin/hdiutil verify "$DIST/iMenuPeek.dmg"
rm -rf "$DIST/dmg"
(cd "$DIST" && /usr/bin/ditto -c -k --keepParent iMenuPeek.app iMenuPeek.zip \
  && /usr/bin/shasum -a 256 iMenuPeek.dmg iMenuPeek.zip > SHA256SUMS.txt)
print -r -- "Versão $VERSION ($BUILD_NUMBER) pronta em $DIST"
