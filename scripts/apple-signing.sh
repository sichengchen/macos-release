#!/bin/bash

prepare_apple_signing() {
  : "${RELEASE_WORK:?}" "${APPLE_TEAM_ID:?}" "${APPLE_API_ISSUER:?}" "${APPLE_API_KEY_ID:?}"
  : "${MACOS_CERTIFICATE:?}" "${MACOS_CERTIFICATE_PASSWORD:?}" "${APPLE_API_KEY_BASE64:?}"
  [[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ && "$APPLE_API_KEY_ID" =~ ^[A-Za-z0-9]+$ ]]
  keychain="$RELEASE_WORK/signing.keychain-db"
  notary_key="$RELEASE_WORK/AuthKey.p8"
  local cert="$RELEASE_WORK/identities.p12" password
  password=$(uuidgen)
  trap 'security delete-keychain "$keychain" >/dev/null 2>&1 || true
        rm -f -- "$RELEASE_WORK/identities.p12" "$notary_key"' EXIT

  printf '%s' "$MACOS_CERTIFICATE" | base64 -D > "$cert"
  printf '%s' "$APPLE_API_KEY_BASE64" | base64 -D > "$notary_key"
  unset MACOS_CERTIFICATE APPLE_API_KEY_BASE64
  security create-keychain -p "$password" "$keychain"
  security set-keychain-settings -lut 7200 "$keychain"
  security unlock-keychain -p "$password" "$keychain"
  security import "$cert" -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/pkgbuild
  unset MACOS_CERTIFICATE_PASSWORD
  rm -f -- "$cert"
  security list-keychains -d user -s "$keychain"
  security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain"
  app_identity=$(security find-identity -v -p codesigning "$keychain" |
    awk -v team="$APPLE_TEAM_ID" '$0 ~ /Developer ID Application:/ && index($0, "(" team ")") {print $2; exit}')
  test -n "$app_identity"
}

find_installer_identity() {
  installer_identity=$(security find-identity -v -p basic "$keychain" |
    awk -v team="$APPLE_TEAM_ID" '$0 ~ /Developer ID Installer:/ && index($0, "(" team ")") {print $2; exit}')
  test -n "$installer_identity"
}

sign_code() {
  codesign --force --sign "$app_identity" --keychain "$keychain" \
    --options runtime --timestamp "$1"
  codesign -dv --verbose=2 "$1" 2>&1 | grep -Fx "TeamIdentifier=$APPLE_TEAM_ID"
}

notarize() {
  local input="$1" ticket_target="$2" result="$RELEASE_WORK/notary-result.json"
  xcrun notarytool submit "$input" --issuer "$APPLE_API_ISSUER" --key-id "$APPLE_API_KEY_ID" \
    --key "$notary_key" --wait --output-format json > "$result"
  jq -e '.status == "Accepted"' "$result" > /dev/null
  xcrun stapler staple "$ticket_target"
  xcrun stapler validate "$ticket_target"
}
