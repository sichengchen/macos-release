#!/bin/bash
set -euo pipefail

# shellcheck source=scripts/app-profile.sh
source "$(dirname -- "$0")/app-profile.sh"
load_app_profile

run_id="${EXISTING_RUN_ID:-}"
if [[ -z "$run_id" ]]; then
  case "${RELEASE_BUMP:-}" in
    current|patch|minor|major) ;;
    *) echo "::error::Select a supported version bump."; exit 1 ;;
  esac
  workflow=${BUILD_WORKFLOW##*/}
  api="repos/$SOURCE_REPO/actions"
  # This API version returns the exact dispatched run, even with other builds running.
  run_id=$(jq -n --arg ref "$BUILD_BRANCH" --arg bump "$RELEASE_BUMP" \
      '{ref: $ref, inputs: {bump: $bump}}' |
    gh api -X POST -H 'X-GitHub-Api-Version: 2026-03-10' \
      "$api/workflows/$workflow/dispatches" --input - --jq .workflow_run_id)
  if [[ ! "$run_id" =~ ^[0-9]+$ ]]; then
    echo '::error::GitHub did not return a preparation run ID. Check the source workflow before retrying.'
    exit 1
  fi
  printf 'Preparation run ID: %s\n' "$run_id" >> "$GITHUB_STEP_SUMMARY"
  echo "Waiting for preparation run $run_id."
  while true; do
    result=$(gh api "$api/runs/$run_id" --jq 'if .status == "completed" then .conclusion else "" end')
    if [[ "$result" == success ]]; then break; fi
    if [[ -n "$result" ]]; then
      echo "::error::Preparation run $run_id finished with $result. See the source repository for details."
      exit 1
    fi
    sleep 15
  done
elif [[ ! "$run_id" =~ ^[0-9]+$ ]]; then
  echo '::error::Enter a numeric preparation run ID.'
  exit 1
fi

printf 'run_id=%s\n' "$run_id" >> "$GITHUB_OUTPUT"
