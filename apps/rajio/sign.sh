#!/bin/bash
set -euo pipefail
umask 077

: "${RELEASE_WORK:?}"
app_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/apple-signing.sh
source "$app_dir/../../scripts/apple-signing.sh"

version="${1:?Expected version}"
dmg="${2:?Expected output DMG path}"
app="$RELEASE_WORK/Rajio.app"
bundle_id=com.scchan.rajio
frameworks="$app/Contents/Frameworks"

echo 'Validating the universal Rajio app.' >&3
python3 "$app_dir/extract-app.py" "$RELEASE_WORK/input/app.zip" "$app"
plist="$app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" == "$bundle_id" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "$version" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" == Rajio ]]
lipo "$app/Contents/MacOS/Rajio" -verify_arch arm64 x86_64
codesign --verify --deep --strict "$app"

echo 'Importing the Developer ID Application identity.' >&3
prepare_apple_signing

# RELEASE_WORK is private. Give the app and DMG standard distribution permissions.
umask 022

sign_app() {
  local target="$1" expected_id="$2"
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$target/Contents/Info.plist")" == "$expected_id" ]]
  codesign --force --sign "$app_identity" --keychain "$keychain" --options runtime --timestamp \
    --entitlements "$app_dir/entitlements.plist" "$target"
}

echo 'Signing and notarizing Rajio and its Electron helpers.' >&3
# Sign Mach-O files and enclosing bundles in depth-first order. Match only
# regular files so framework symlinks do not cause a second signing pass.
targets="$RELEASE_WORK/signing-targets"
find -d "$app" \( -type d \( -name '*.framework' -o -name '*.app' \) \
  -o -type f \( -perm -0100 -o -name '*.dylib' -o -name '*.node' \) \) -print0 > "$targets"
while IFS= read -r -d '' target; do
  case "$target" in
    "$app") sign_app "$target" "$bundle_id" ;;
    "$frameworks/Rajio Helper.app") sign_app "$target" "$bundle_id.helper" ;;
    "$frameworks/Rajio Helper (GPU).app") sign_app "$target" "$bundle_id.helper.GPU" ;;
    "$frameworks/Rajio Helper (Plugin).app") sign_app "$target" "$bundle_id.helper.Plugin" ;;
    "$frameworks/Rajio Helper (Renderer).app") sign_app "$target" "$bundle_id.helper.Renderer" ;;
    *.app) signing_error 'Unexpected nested app bundle in Rajio.' ;;
    *.framework) sign_code "$target" ;;
    *)
      kind=$(file -b "$target")
      if [[ "$kind" == Mach-O* ]]; then
        sign_code "$target"
      fi
      ;;
  esac
done < "$targets"

codesign --verify --deep --strict --verbose=2 "$app"
archive="$RELEASE_WORK/signed-app.zip"
ditto -c -k --norsrc --keepParent "$app" "$archive"
notarize "$archive" "$app"
spctl --assess --type execute "$app"

echo 'Building, signing, and notarizing the Homebrew disk image.' >&3
staging="$RELEASE_WORK/dmg-root"
mkdir "$staging"
ditto "$app" "$staging/Rajio.app"
ln -s /Applications "$staging/Applications"
hdiutil create -volname Rajio -srcfolder "$staging" -fs HFS+ -format UDZO "$dmg"
codesign --sign "$app_identity" --keychain "$keychain" --timestamp "$dmg"
codesign --verify "$dmg"
notarize "$dmg" "$dmg"

echo 'Verifying the app inside the notarized disk image.' >&3
mount="$RELEASE_WORK/dmg-mount"
mkdir "$mount"
(
  hdiutil attach "$dmg" -readonly -nobrowse -mountpoint "$mount"
  trap 'hdiutil detach "$mount"' EXIT
  codesign --verify --deep --strict "$mount/Rajio.app"
  xcrun stapler validate "$mount/Rajio.app"
)
echo 'Rajio signature and notarization verified.' >&3
