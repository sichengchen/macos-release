#!/bin/bash
# Source this file from a release script, then call load_app_profile.

load_app_profile() {
  if [[ ! "${APP_ID:-}" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ ]]; then
    echo 'Enter an app ID from the apps directory.' >&2
    return 1
  fi
  local root config fields
  root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
  APP_DIR="$root/apps/$APP_ID"
  config="$APP_DIR/profile.json"
  if [[ ! -f "$config" || ! -f "$APP_DIR/sign.sh" ]]; then
    echo 'No signing profile found for that app.' >&2
    return 1
  fi
  # Validate profile values before using them in GitHub API paths or outputs.
  fields=$(jq -er '
    select(
      (.repository | test("^[A-Za-z0-9-]+/[A-Za-z0-9_.-]+$")) and
      (.name | test("^[A-Za-z0-9][A-Za-z0-9 ._-]*$")) and
      (.build_workflow | test("^\\.github/workflows/[A-Za-z0-9_-]+\\.ya?ml$")) and
      (.build_branch | test("^[A-Za-z0-9][A-Za-z0-9_.-]*$")) and
      (.asset | test("^[A-Za-z0-9_.-]+\\{version\\}[A-Za-z0-9_.-]*\\.(pkg|dmg|zip)$"))
    ) | [.repository, .name, .build_workflow, .build_branch, .asset] | @tsv
  ' "$config") || return 1
  # The scripts that source this file use these profile values.
  # shellcheck disable=SC2034
  IFS=$'\t' read -r SOURCE_REPO RELEASE_NAME BUILD_WORKFLOW BUILD_BRANCH ASSET_TEMPLATE <<< "$fields"
}

release_asset() {
  local version="$1"
  if [[ ! "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]; then
    echo 'Invalid release version.' >&2
    return 1
  fi
  printf '%s\n' "${ASSET_TEMPLATE//\{version\}/$version}"
}
