#!/bin/bash
set -euo pipefail
umask 077

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${RELEASE_WORK:?}"
version=$(jq -er .version "$RELEASE_WORK/input/release.json")
asset=$(release_asset "$version")

# Keep private tool output on the runner. App signers may report stage names on fd 3.
exec 3>&1
if ! bash "$APP_DIR/sign.sh" "$version" "$RELEASE_WORK/$asset" > "$RELEASE_WORK/signing.log" 2>&1; then
  echo '::error::Signing failed. Check the reported stage and Apple release configuration.' >&3
  exit 1
fi
test -s "$RELEASE_WORK/$asset"
