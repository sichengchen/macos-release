# macOS releases

This repository runs Developer ID signing and Apple notarization for maintainer-approved macOS builds. Each app repository compiles and tests its own code. The release workflow runs here on a standard macOS runner and keeps the Apple credentials in one place.

## Configure once

Create the `macOS Release` Actions environment here. Restrict deployments to the `main` branch. If you add required reviewers, make sure someone can approve a run started by the maintainer. The workflow checks the repository and branch before running.

| Environment setting | Kind | Value |
| --- | --- | --- |
| `APPLE_TEAM_ID` | Variable | Team ID for both Developer ID identities |
| `APPLE_API_ISSUER` | Variable | App Store Connect API issuer ID |
| `APPLE_API_KEY_ID` | Variable | App Store Connect API key ID |
| `MACOS_CERTIFICATE` | Secret | Base64 of a password-protected `.p12` containing the Developer ID Application and Installer identities with both private keys |
| `MACOS_CERTIFICATE_PASSWORD` | Secret | Password for the `.p12` |
| `APPLE_API_KEY_BASE64` | Secret | Base64 of the App Store Connect `.p8` key |
| `RELEASE_APP_CLIENT_ID` | Variable | GitHub App client ID |
| `RELEASE_APP_PRIVATE_KEY` | Secret | GitHub App private key PEM |

Install the GitHub App only on the source repos it needs to release and, for public Homebrew distribution, `sichengchen/homebrew-tap`. Give it Actions read and write to start app builds, and Contents read and write to tag their commits. Actions read is sufficient when supplying a completed build run ID. The workflow issues separate tokens for build dispatch, artifact retrieval, and tagging. Each token is scoped to the target repository.

## Cut a release

1. From this repository's [Actions tab](https://github.com/sichengchen/macos-release/actions), run **Sign and notarize macOS release** on `main`. Enter the app profile ID and select a version bump.
2. Leave the run ID blank to start the app's build and wait for it automatically. Supply a successful run ID to reuse that build. A new build can commit the version bump to the source branch.
3. Leave **Publish** off to check signing and notarization. Turn it on to tag the build commit in the source repository and upload the installer as a public Release asset in this repository under `<app-id>-v<version>`. For profiles with a cask renderer, the workflow updates Homebrew from that public asset.

The signer verifies the build's repository, workflow, branch, result, and commit before opening its artifact. It uses reviewed packaging inputs from this repo and keeps private files and diagnostics on the runner.

### Weekly eipgam releases

The signing workflow runs every Monday at 9:00 a.m. Eastern. It publishes a
patch release and updates Homebrew when eipgam’s `main` has commits beyond
the source tag for its latest published stable release. If the tag is
already at `main`, the workflow skips the build and signing jobs. A first
scheduled run with no prior release uses the source’s standard patch bump.

Manual dispatch remains available with the existing app, bump, run ID,
and publishing options.

## Add an app

Read the [setup-macos-release skill](.agents/skills/setup-macos-release/SKILL.md) for the artifact contract, workflow verification, and signing and packaging requirements. Register each app in [`apps/<app-id>/profile.json`](apps/). The profile names the source repository, trusted build workflow, release branch, and asset filename. Its sibling `sign.sh` performs the app-specific signing and packaging.
