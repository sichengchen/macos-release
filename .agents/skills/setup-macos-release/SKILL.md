---
name: setup-macos-release
description: Set up or migrate a macOS app's GitHub Actions release workflow to the shared sichengchen/macos-release signing and notarization repo. Use for new app integrations, release artifact handoffs, and Homebrew cask publishing from the shared workflow.
---

Read the [release repo README](../../../README.md) for current environment settings and the Eau release procedure. Use the local checkout at `~/src/macos-release` when available.

1. Inspect the app's existing release workflow, versioning, signing entitlements, architecture, package format, and release asset URLs. Keep app-specific compilation and tests in the app repo. Preserve the app's release version, tag scheme, and update/install behavior.
2. Have a trusted build workflow on `main` upload a run-attempt-scoped artifact named `macos-release-app-<run_attempt>` with `app.zip` (created by `ditto -c -k --norsrc --keepParent`) and `release.json` with the exact built commit as `sha` and release version as `version`. Use ad hoc signing for checks if the app requires it. For an installer script, include a copy for comparison with the reviewed release-repo copy. The source repo needs no Apple credentials.
3. Add an explicit app profile in the release repo. Start with [the workflow](../../../.github/workflows/release-macos.yml), [Eau's artifact checks](../../../scripts/fetch-eau.sh), and [the shared Apple signing functions](../../../scripts/apple-signing.sh). Check repository, workflow identity, branch, successful run, artifact name, and commit before opening the archive. If preparation makes a version bump commit, verify its relationship to the run and that it is on the trusted branch.
4. Treat the downloaded app as data. Keep entitlements, installer scripts, packaging code, and allowed bundle IDs under review in the release repo. Sign nested code before the app using the required entitlements, then package, notarize, staple, and verify. Eau's allowlist assumes no archive symlinks. Framework-based apps such as Electron may require validated internal symlinks and per-target entitlements. Use Developer ID Installer for a `.pkg` and the app identity for executable code.
5. Keep private artifacts and raw tool logs off public run outputs. Scope GitHub App tokens to the repo and permissions required by each step. Publish to the app's repo only when requested. Update a public tap only for an asset users can download from a public release. Coordinate the cutover after a signing check.
6. Run `actionlint`, check shell syntax, and verify the source handoff paths. Try the central signing workflow with publishing off after the maintainer configures credentials. Treat tag creation, public releases, tap updates, and credential changes as separate requested operations.

Use a top-level dispatch in the release repo to access its environment secrets. A cross-repository `workflow_call` runs under the caller's context and does not provide the shared repo's secrets.
