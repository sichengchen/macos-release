#!/bin/bash
set -euo pipefail
umask 077

: "${RELEASE_WORK:?}"
app_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/apple-signing.sh
source "$app_dir/../../scripts/apple-signing.sh"

version="${1:?Expected version}"
output="${2:?Expected output ZIP path}"
bundle_id=com.sichengchen.eipgam
zip="$RELEASE_WORK/input/app.zip"
app="$RELEASE_WORK/eipgam.app"

echo 'Validating the universal eipgam app.' >&3
python3 - "$zip" <<'PY'
import stat
import sys
import zipfile

root = "eipgam.app/Contents/"
executables = {root + "MacOS/eipgam"}
resources = {root + "Resources/" + name for name in (
    "Assets.car", "eipgam.icns", "LICENSE", "THIRD_PARTY_NOTICES",
)}
required = executables | resources | {root + "Info.plist", root + "_CodeSignature/CodeResources"}
directories = {"eipgam.app/", root, root + "MacOS/", root + "Resources/", root + "_CodeSignature/"}

seen = set()
with zipfile.ZipFile(sys.argv[1]) as archive:
    for entry in archive.infolist():
        name = entry.orig_filename
        mode = entry.external_attr >> 16
        if (name in seen or (name not in required and name not in directories)
                or (name in required and not stat.S_ISREG(mode))
                or (name in directories and not stat.S_ISDIR(mode))):
            raise SystemExit("Unexpected entry in eipgam app archive")
        seen.add(name)
if not required <= seen:
    raise SystemExit("Incomplete eipgam app archive")
PY

ditto -x -k "$zip" "$RELEASE_WORK"
plist="$app/Contents/Info.plist"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" == "$bundle_id" ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$plist")" == eipgam ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")" == "$version" ]]
for arch in arm64 x86_64; do
  lipo "$app/Contents/MacOS/eipgam" -verify_arch "$arch"
done
codesign --verify --deep --strict "$app"

echo 'Signing the eipgam app with Developer ID.' >&3
prepare_apple_signing
sign_code "$app"
codesign --verify --deep --strict "$app"

echo 'Notarizing and stapling the eipgam app.' >&3
archive="$RELEASE_WORK/signed-app.zip"
ditto -c -k --norsrc --keepParent "$app" "$archive"
notarize "$archive" "$app" app
spctl --assess --type execute "$app" ||
  signing_error 'Gatekeeper did not accept the notarized app.'

# Distribute the stapled app and verify the ticket survives the final ZIP.
ditto -c -k --norsrc --keepParent "$app" "$output"
check_dir="$RELEASE_WORK/check"
mkdir "$check_dir"
ditto -x -k "$output" "$check_dir"
codesign --verify --deep --strict "$check_dir/eipgam.app"
xcrun stapler validate "$check_dir/eipgam.app"
echo 'eipgam signature and notarization verified.' >&3
