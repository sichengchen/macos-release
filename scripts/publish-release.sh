#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${RELEASE_WORK:?}" "${PUBLISH_TOKEN:?}" "${GITHUB_REPOSITORY:?}" "${GITHUB_SHA:?}"
visibility=$(GH_TOKEN="$PUBLISH_TOKEN" gh api "repos/$GITHUB_REPOSITORY" --jq .visibility)
if [[ "$visibility" != public ]]; then
  echo 'The distribution repository must be public.' >&2
  exit 1
fi
meta="$RELEASE_WORK/input/release.json"
version=$(jq -er .version "$meta")
sha=$(jq -er .sha "$meta")
tag="v$version"
public_tag="$APP_ID-$tag"
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
# Tag the source privately, then publish only the signed binary in this repo.
notes=(--notes "Signed and notarized macOS download.")
if [[ -f "$APP_DIR/release-notes.md" ]]; then
  notes=(--notes-file "$APP_DIR/release-notes.md")
fi
GH_TOKEN="$PUBLISH_TOKEN" gh release create "$public_tag" "$package" \
  --repo "$GITHUB_REPOSITORY" --target "$GITHUB_SHA" --latest=false \
  --title "$RELEASE_NAME $version" "${notes[@]}"

if [[ -f "$APP_DIR/render-cask.py" ]]; then
  printf 'public_version=%s\n' "$version" >> "$GITHUB_OUTPUT"
fi
