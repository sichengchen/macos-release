#!/bin/bash

signing_error() {
  # The app signer redirects raw tool output to a private runner log.
  printf '::error::%s\n' "$1" >&3
  exit 1
}

prepare_apple_signing() {
  : "${RELEASE_WORK:?}"
  local setting
  for setting in APPLE_TEAM_ID APPLE_API_ISSUER APPLE_API_KEY_ID MACOS_CERTIFICATE \
    MACOS_CERTIFICATE_PASSWORD APPLE_API_KEY_BASE64; do
    [[ -n "${!setting:-}" ]] || signing_error "The release environment is missing $setting."
  done
  [[ "$APPLE_TEAM_ID" =~ ^[A-Z0-9]{10}$ ]] ||
    signing_error 'APPLE_TEAM_ID must be the 10-character Apple Developer Team ID.'
  [[ "$APPLE_API_KEY_ID" =~ ^[A-Za-z0-9]+$ ]] ||
    signing_error 'APPLE_API_KEY_ID must be the Key ID, without AuthKey_ or the .p8 suffix.'
  keychain="$RELEASE_WORK/signing.keychain-db"
  notary_key="$RELEASE_WORK/AuthKey.p8"
  local cert="$RELEASE_WORK/identities.p12" password
  password=$(uuidgen)
  trap 'security delete-keychain "$keychain" >/dev/null 2>&1 || true
        rm -f -- "$RELEASE_WORK/identities.p12" "$notary_key"' EXIT

  printf '%s' "$MACOS_CERTIFICATE" | base64 -D > "$cert" ||
    signing_error 'MACOS_CERTIFICATE could not be decoded as Base64.'
  printf '%s' "$APPLE_API_KEY_BASE64" | base64 -D > "$notary_key" ||
    signing_error 'APPLE_API_KEY_BASE64 could not be decoded as Base64.'
  unset MACOS_CERTIFICATE APPLE_API_KEY_BASE64
  if ! security create-keychain -p "$password" "$keychain" ||
     ! security set-keychain-settings -lut 7200 "$keychain" ||
     ! security unlock-keychain -p "$password" "$keychain"; then
    signing_error 'The runner could not initialize the temporary signing keychain.'
  fi
  security import "$cert" -f pkcs12 -k "$keychain" -P "$MACOS_CERTIFICATE_PASSWORD" \
    -T /usr/bin/codesign -T /usr/bin/pkgbuild ||
    signing_error 'The Developer ID .p12 could not be imported. Check the export and MACOS_CERTIFICATE_PASSWORD.'
  unset MACOS_CERTIFICATE_PASSWORD
  rm -f -- "$cert"
  if ! security list-keychains -d user -s "$keychain" ||
     ! security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$password" "$keychain"; then
    signing_error 'The runner could not authorize access to the imported signing keys.'
  fi
  app_identity=$(security find-identity -v -p codesigning "$keychain" |
    awk -v team="$APPLE_TEAM_ID" '$0 ~ /Developer ID Application:/ && index($0, "(" team ")") {print $2; exit}')
  [[ -n "$app_identity" ]] ||
    signing_error 'No valid Developer ID Application identity for APPLE_TEAM_ID. Export the certificate with its private key.'
}

find_installer_identity() {
  installer_identity=$(security find-identity -v -p basic "$keychain" |
    awk -v team="$APPLE_TEAM_ID" '$0 ~ /Developer ID Installer:/ && index($0, "(" team ")") {print $2; exit}')
  [[ -n "$installer_identity" ]] ||
    signing_error 'No valid Developer ID Installer identity for APPLE_TEAM_ID. Export the certificate with its private key.'
}

sign_code() {
  codesign --force --sign "$app_identity" --keychain "$keychain" \
    --options runtime --timestamp "$1"
  codesign -dv --verbose=2 "$1" 2>&1 | grep -Fx "TeamIdentifier=$APPLE_TEAM_ID"
}

notarize() {
  local input="$1" ticket_target="$2" kind="$3" result="$RELEASE_WORK/notary-result.json"
  xcrun notarytool submit "$input" --issuer "$APPLE_API_ISSUER" --key-id "$APPLE_API_KEY_ID" \
    --key "$notary_key" --wait --output-format json > "$result" ||
    signing_error "Apple notarization did not complete for the $kind."
  jq -e '.status == "Accepted"' "$result" > /dev/null ||
    signing_error "Apple did not accept the $kind for notarization."
  printf 'Apple accepted the %s for notarization.\n' "$kind" >&3

  local attempt
  for attempt in 1 2 3; do
    if xcrun stapler staple "$ticket_target"; then
      xcrun stapler validate "$ticket_target" ||
        signing_error "The stapled $kind ticket could not be validated."
      return
    fi
    if [[ "$attempt" != 3 ]]; then
      sleep 8
    fi
  done
  signing_error "The Apple notarization ticket could not be stapled to the $kind."
}
