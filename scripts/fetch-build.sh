#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile
: "${SOURCE_RUN_ID:?}" "${RELEASE_WORK:?}"
[[ "$SOURCE_RUN_ID" =~ ^[0-9]+$ ]]

gh api "repos/$SOURCE_REPO/actions/runs/$SOURCE_RUN_ID" > "$RELEASE_WORK/run.json"
attempt=$(jq -er --arg repo "$SOURCE_REPO" --arg branch "$BUILD_BRANCH" \
  --arg workflow "$BUILD_WORKFLOW" '
  select(.conclusion == "success" and .event == "workflow_dispatch" and .head_branch == $branch
    and .repository.full_name == $repo and .head_repository.full_name == $repo
    and (.path | split("@")[0]) == $workflow) | .run_attempt
' "$RELEASE_WORK/run.json")
[[ "$attempt" =~ ^[0-9]+$ ]]

gh run download "$SOURCE_RUN_ID" --repo "$SOURCE_REPO" \
  --name "macos-release-app-$attempt" --dir "$RELEASE_WORK/input"

meta="$RELEASE_WORK/input/release.json"
sha=$(jq -er '.sha | strings | select(test("^[0-9a-f]{40}$"))' "$meta")
version=$(jq -er '.version | strings' "$meta")
release_asset "$version" > /dev/null
head_sha=$(jq -er '.head_sha' "$RELEASE_WORK/run.json")
if [[ "$sha" != "$head_sha" ]]; then
  # Preparation may create one version bump commit on top of the dispatched ref.
  gh api "repos/$SOURCE_REPO/commits/$sha" |
    jq -e --arg head "$head_sha" '.parents | length == 1 and .[0].sha == $head' > /dev/null
fi
gh api "repos/$SOURCE_REPO/compare/$sha...$BUILD_BRANCH" |
  jq -e '.status == "ahead" or .status == "identical"' > /dev/null
test -s "$RELEASE_WORK/input/app.zip"
