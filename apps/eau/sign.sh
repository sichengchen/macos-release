#!/bin/bash
set -euo pipefail
umask 077

: "${RELEASE_WORK:?}"
app_dir=$(cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=scripts/apple-signing.sh
source "$app_dir/../../scripts/apple-signing.sh"

version="${1:?Expected version}"
pkg="${2:?Expected output package path}"

echo "Validating app bundle." >&3
cmp "$app_dir/postinstall" "$RELEASE_WORK/input/postinstall"
zip="$RELEASE_WORK/input/app.zip"
app="$RELEASE_WORK/Eau.app"
python3 - "$zip" "$app" <<'PY'
import stat
import sys
import zipfile
from pathlib import Path, PurePosixPath

archive, app = sys.argv[1:]
seen = set()
with zipfile.ZipFile(archive) as bundle:
    for member in bundle.infolist():
        name = PurePosixPath(member.filename)
        key = str(name).casefold()
        if (not name.parts or name.parts[0] != Path(app).name or ".." in name.parts
                or key in seen or stat.S_ISLNK(member.external_attr >> 16)):
            raise SystemExit("Unexpected entry in app archive")
        seen.add(key)
PY
ditto -x -k "$zip" "$RELEASE_WORK"
contents="$app/Contents"
service="$contents/XPCServices/EauEngineService.xpc"
resources="$contents/Frameworks"
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$contents/Info.plist")"     == com.scchan.inputmethod.eau ]]
[[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$service/Contents/Info.plist")"     == com.scchan.inputmethod.eau.engine ]]
for info in "$contents/Info.plist" "$service/Contents/Info.plist"; do
  [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$info")" == "$version" ]]
done
[[ "$(lipo -archs "$contents/MacOS/Eau")" == arm64 ]]
[[ "$(lipo -archs "$service/Contents/MacOS/EauEngineService")" == arm64 ]]
codesign --verify --deep --strict "$app"

echo "Importing Developer ID identities." >&3
prepare_apple_signing
find_installer_identity

echo "Signing and notarizing the app." >&3
for library in "$resources"/rime-plugins/*.dylib "$resources/librime.1.dylib" \
  "$resources/libeau_mozc.dylib"; do
  test -f "$library"
  sign_code "$library"
done
sign_code "$service"
sign_code "$app"
codesign --verify --deep --strict "$app"
archive="$RELEASE_WORK/signed-app.zip"
ditto -c -k --keepParent "$app" "$archive"
notarize "$archive" "$app" app
spctl --assess --type execute "$app" ||
  signing_error 'Gatekeeper did not accept the notarized app.'

echo "Building and notarizing the installer." >&3
staging="$RELEASE_WORK/pkg"
mkdir -p "$staging/root" "$staging/scripts"
ditto "$app" "$staging/root/Eau.app"
install -m 755 "$app_dir/postinstall" "$staging/scripts/postinstall"
components="$staging/components.plist"
pkgbuild --analyze --root "$staging/root" "$components"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsRelocatable false' "$components"
/usr/libexec/PlistBuddy -c 'Set :0:BundleIsVersionChecked false' "$components"
pkgbuild --root "$staging/root" --component-plist "$components" --scripts "$staging/scripts" \
  --identifier com.scchan.eau.local-install --version "$version" \
  --install-location '/Library/Input Methods' --ownership recommended \
  --keychain "$keychain" --sign "$installer_identity" "$pkg" ||
  signing_error 'The signed installer package could not be built.'
notarize "$pkg" "$pkg" installer
spctl --assess --type install "$pkg" ||
  signing_error 'Gatekeeper did not accept the notarized installer.'
expanded="$staging/expanded"
pkgutil --expand-full "$pkg" "$expanded" ||
  signing_error 'The signed installer package could not be expanded for verification.'
if ! cmp "$staging/scripts/postinstall" "$expanded/Scripts/postinstall" ||
   ! test -x "$expanded/Scripts/postinstall"; then
  signing_error 'The installer registration script is missing or differs from the release script.'
fi
codesign --verify --deep --strict "$expanded/Payload/Eau.app" ||
  signing_error 'The app signature could not be verified in the installer payload.'
xcrun stapler validate "$expanded/Payload/Eau.app" ||
  signing_error 'The app notarization ticket could not be verified in the installer payload.'
[[ "$(/usr/sbin/installer -query RestartAction -pkg "$pkg" -target /)" == None ]] ||
  signing_error 'The installer did not report a no-restart installation.'
echo "Installer signature and notarization verified." >&3
