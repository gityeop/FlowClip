#!/bin/bash
set -e

# Configuration
SCHEME="Maccy"
PRODUCT_NAME="FlowClip"
BUNDLE_ID="com.gityeop.FlowClip"
NOTARY_PROFILE="FlowClip-Notary"
ARCHIVE_PATH="./build/${PRODUCT_NAME}.xcarchive"
EXPORT_PATH="./build/Export"
APP_PATH="${EXPORT_PATH}/${PRODUCT_NAME}.app"
ZIP_PATH="./build/${PRODUCT_NAME}.zip"

# clean
rm -rf build

echo "🚀 Building and Archiving ${PRODUCT_NAME}..."
xcodebuild archive \
  -scheme "$SCHEME" \
  -configuration Release \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  PRODUCT_BUNDLE_IDENTIFIER="$BUNDLE_ID" \
  CODE_SIGN_STYLE="Manual" \
  PROVISIONING_PROFILE_SPECIFIER="" \
  DEVELOPMENT_TEAM="79Q5RV23F9" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO

echo "📦 Exporting Archive..."
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportOptionsPlist export_options.plist \
  -exportPath "$EXPORT_PATH"

echo "🤐 Zipping for Notarization..."
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "📝 Submitting for Notarization (this might take a while)..."
xcrun notarytool submit "$ZIP_PATH" \
  --keychain-profile "$NOTARY_PROFILE" \
  --wait

echo "✅ Stapling Ticket..."
xcrun stapler staple "$APP_PATH"

echo "🎉 Notarization Complete!"
echo "Signed and Notarized App: $APP_PATH"
echo "Notarized Zip: $ZIP_PATH"
