#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${RELEASE_WORK:?}"
meta="$RELEASE_WORK/input/release.json"
version=$(jq -er .version "$meta")
sha=$(jq -er .sha "$meta")
tag="v$version"
asset=$(release_asset "$version")
package="$RELEASE_WORK/$asset"
ref="refs/tags/$tag"
test -f "$package"

# Create the tag at the artifact's commit. A rerun can reuse exactly that tag.
refs=$(gh api "repos/$SOURCE_REPO/git/matching-refs/tags/$tag")
if jq -e --arg ref "$ref" 'any(.[]; .ref == $ref)' <<< "$refs" > /dev/null; then
  tagged_sha=$(gh api "repos/$SOURCE_REPO/commits/$tag" --jq .sha)
  if [[ "$tagged_sha" != "$sha" ]]; then
    echo "Existing release tag points at a different commit." >&2
    exit 1
  fi
else
  gh api "repos/$SOURCE_REPO/git/refs" -f ref="$ref" -f sha="$sha" > /dev/null
fi
gh release create "$tag" "$package" --repo "$SOURCE_REPO" --verify-tag \
  --generate-notes --title "$RELEASE_NAME $tag"

if [[ -f "$APP_DIR/render-cask.py" && "$(gh api "repos/$SOURCE_REPO" --jq .visibility)" == public ]]; then
  printf 'public_version=%s\n' "$version" >> "$GITHUB_OUTPUT"
fi
