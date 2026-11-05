#!/bin/bash
# @brief Archive only the iPhone app, validate deployment metadata, and package for sideload signing.
# @note Run serially after all native hosts exist. No signing identity or publication is used.
set -euo pipefail
cd "$(dirname "$0")/.."
source Scripts/preserve-build-path.sh
OUT="$PWD/build/ios15-ipa"
mkdir -p "$OUT" artifacts
for required in \
  build/AppleRuntime/iphoneos/lib/libTVAppleRuntime.a \
  build/AppleRuntime/iphoneos/Resources/JavaHost/host.jar \
  build/ApplePython/iphoneos/Frameworks/Python.framework/Python \
  build/NodeMobile/NodeMobile.xcframework/ios-arm64/NodeMobile.framework/NodeMobile; do
  test -f "$required" || { echo "Missing required runtime: $required" >&2; exit 1; }
done
bash Scripts/check-java-host.sh build/AppleRuntime/iphoneos/Resources/JavaHost/host.jar
python3 Scripts/make-iphone-project.py
xcodegen generate --spec .ios15-project.generated.yml
# Preserve existing results when invoked locally; cloud runners start with a fresh archive.
preserve_build_path "$OUT/TVBox-iOS.xcarchive" "$OUT/Payload" "$OUT/Yingxia-iPhone-iOS15-unsigned.ipa"
xcodebuild -project TVBox-iPhone.xcodeproj -scheme TVBox-iOS \
  -configuration Release -sdk iphoneos -destination 'generic/platform=iOS' \
  -derivedDataPath "$OUT/DerivedData" -archivePath "$OUT/TVBox-iOS.xcarchive" \
  archive ARCHS=arm64 ONLY_ACTIVE_ARCH=YES IPHONEOS_DEPLOYMENT_TARGET=15.0 \
  TARGETED_DEVICE_FAMILY=1 CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY= DEVELOPMENT_TEAM= ICLOUD_ENTITLEMENTS= \
  2>&1 | tee artifacts/ios15-archive.log
APP="$OUT/TVBox-iOS.xcarchive/Products/Applications/TVBox-iOS.app"
python3 Scripts/check-ios15-app.py "$APP" | tee artifacts/ios15-binary-report.json
EXECUTABLE="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$APP/Info.plist")"
xcrun nm -gU "$APP/$EXECUTABLE" > artifacts/ios15-exported-symbols.txt
grep ' _JIMAGE_Open$' artifacts/ios15-exported-symbols.txt >/dev/null ||
  { echo 'Java runtime entry points were stripped' >&2; exit 1; }
mkdir -p "$OUT/Payload"
ditto "$APP" "$OUT/Payload/TVBox-iOS.app"
ditto -c -k --keepParent "$OUT/Payload" "$OUT/Yingxia-iPhone-iOS15-unsigned.ipa"
(cd "$OUT" && shasum -a 256 Yingxia-iPhone-iOS15-unsigned.ipa > Yingxia-iPhone-iOS15-unsigned.ipa.sha256)
echo "Unsigned IPA: $OUT/Yingxia-iPhone-iOS15-unsigned.ipa"
