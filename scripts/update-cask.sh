#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${VERSION:?}" "${RUNNER_TEMP:?}"
asset=$(release_asset "$VERSION")
[[ "$(gh api "repos/$SOURCE_REPO" --jq .visibility)" == public ]]
latest=$(gh api "repos/$SOURCE_REPO/releases/latest" --jq .tag_name)
if [[ "$latest" != "v$VERSION" ]]; then
  echo 'A newer release is current. Keeping the tap on that release.'
  exit 0
fi
gh release download "v$VERSION" --repo "$SOURCE_REPO" --pattern "$asset" --dir "$RUNNER_TEMP"
sha=$(sha256sum "$RUNNER_TEMP/$asset" | awk '{print $1}')
cask="Casks/$APP_ID.rb"
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
