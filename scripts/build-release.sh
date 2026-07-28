#!/bin/bash
# kupifa 配布用ビルドスクリプト(ad-hoc署名版)
#
# Release構成でユニバーサルバイナリ(Apple Silicon + Intel)をビルドし、
# ad-hoc署名を付けて dist/kupifa.dmg を生成する。
#
# 将来 Developer ID + 公証に移行する場合は、SIGN_IDENTITY を
# "Developer ID Application: ..." に変えて、dmg 作成後に
# notarytool submit + stapler staple を追加すればよい。

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="kupifa"
APP_NAME="kupifa"
SIGN_IDENTITY="-"  # ad-hoc署名
BUILD_DIR="build"
DIST_DIR="dist"
DERIVED_DATA="$BUILD_DIR/DerivedData"

echo "==> クリーンアップ"
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$DIST_DIR"

echo "==> Releaseビルド(ユニバーサルバイナリ、ad-hoc署名)"
xcodebuild \
  -project kupifa.xcodeproj \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM="" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Release/$APP_NAME.app"

echo "==> 署名を検証"
codesign --verify --deep --strict "$APP_PATH"
codesign -dv "$APP_PATH" 2>&1 | grep -E "^(Identifier|Signature)"

echo "==> dmgを作成"
DMG_ROOT="$BUILD_DIR/dmg-root"
mkdir -p "$DMG_ROOT"
cp -R "$APP_PATH" "$DMG_ROOT/"
ln -s /Applications "$DMG_ROOT/Applications"

cat > "$DMG_ROOT/はじめにお読みください.txt" <<'EOF'
【kupifa のインストール方法】

1. kupifa.app を Applications フォルダにドラッグしてください。

2. 初回起動時に「開発元を検証できないため開けません」と
   表示された場合は、以下の手順で開いてください。

   (1) 一度「完了」を押して閉じる
   (2) システム設定 → プライバシーとセキュリティ を開く
   (3) 下の方にある「"kupifa" は開発元を確認できないため…」の
       横の「このまま開く」をクリック
   (4) 確認ダイアログで「開く」を押す

   この操作は初回のみ必要です。
EOF

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$DMG_ROOT" \
  -ov -format UDZO \
  "$DIST_DIR/$APP_NAME.dmg"

echo ""
echo "==> 完成: $DIST_DIR/$APP_NAME.dmg"
du -h "$DIST_DIR/$APP_NAME.dmg"
