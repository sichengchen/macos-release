#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${VERSION:?}" "${RUNNER_TEMP:?}" "${GITHUB_REPOSITORY:?}"
asset=$(release_asset "$VERSION")
cask="Casks/$APP_ID.rb"
if [[ -f "tap/$cask" ]]; then
  current=$(awk -F '"' '/^  version "/ {print $2; exit}' "tap/$cask")
  release_asset "$current" > /dev/null
  highest=$(printf '%s\n' "$current" "$VERSION" | sort -V | tail -1)
  if [[ "$highest" != "$VERSION" ]]; then
    echo 'The tap already has a newer version.'
    exit 0
  fi
fi
gh release download "$APP_ID-v$VERSION" --repo "$GITHUB_REPOSITORY" \
  --pattern "$asset" --dir "$RUNNER_TEMP"
sha=$(sha256sum "$RUNNER_TEMP/$asset" | awk '{print $1}')
python3 "$APP_DIR/render-cask.py" "$VERSION" "$sha" "tap/$cask"
ruby -c "tap/$cask"
git -C tap config user.name 'github-actions[bot]'
git -C tap config user.email '41898282+github-actions[bot]@users.noreply.github.com'
git -C tap add "$cask"
if ! git -C tap diff --cached --quiet; then
  git -C tap commit -m "chore(cask): update $APP_ID to v$VERSION" \
    -m 'Co-Authored-By: Sicheng Chen (bot) <gh-bot@scchan.com>'
  git -C tap push origin HEAD:main
fi
