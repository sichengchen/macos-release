#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${GITHUB_REPOSITORY:?}" "${GITHUB_OUTPUT:?}" "${PUBLISH_TOKEN:?}"

# Source tags can be created before publication finishes. Use a published
# release as the baseline so an incomplete publication cannot cause a skip.
version=$(GH_TOKEN="$PUBLISH_TOKEN" gh api --paginate --slurp \
  "repos/$GITHUB_REPOSITORY/releases?per_page=100" | jq -r --arg prefix "$APP_ID-v" '
    [
      .[][] | select(.draft == false and .prerelease == false)
      | .tag_name | select(startswith($prefix)) | ltrimstr($prefix)
      | select(test("^(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)\\.(0|[1-9][0-9]*)$"))
    ]
    | max_by(split(".") | map(tonumber)) // empty
  ')

if [[ -z "$version" ]]; then
  echo "No published stable release for $APP_ID. Preparing the first patch release."
  printf 'changed=true\n' >> "$GITHUB_OUTPUT"
  exit 0
fi

status=$(gh api "repos/$SOURCE_REPO/compare/v$version...$BUILD_BRANCH" --jq .status)
case "$status" in
  ahead)
    printf 'changed=true\n' >> "$GITHUB_OUTPUT"
    ;;
  identical)
    echo "$BUILD_BRANCH is already released at v$version."
    printf 'changed=false\n' >> "$GITHUB_OUTPUT"
    ;;
  *)
    echo "::error::Expected $BUILD_BRANCH to contain the released source tag v$version."
    exit 1
    ;;
esac
