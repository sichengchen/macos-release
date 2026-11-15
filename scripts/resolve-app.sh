#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
printf 'owner=%s\nrepository=%s\n' "${SOURCE_REPO%%/*}" "${SOURCE_REPO#*/}" >> "$GITHUB_OUTPUT"
