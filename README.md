# macOS releases

This repository runs Developer ID signing and Apple notarization for maintainer-approved macOS builds. Each app repository compiles and tests its own code. The release workflow runs here on a standard macOS runner and keeps the Apple credentials in one place.

## Configure once

Create the `macOS Release` Actions environment here. Restrict deployments to the `main` branch. If you add required reviewers, make sure someone can approve a run started by the maintainer. The workflow is manual and checks the repository and branch before running.

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

Install the GitHub App only on the source repos it needs to release and, for public Homebrew distribution, `sichengchen/homebrew-tap`. Give it Actions read and Contents write. The workflow issues an Actions/Contents read token for artifact retrieval and a separate Contents write token for publishing. Each token is scoped to the target repository.

## Cut a release

1. Run the preparation workflow on the app's release branch. Wait for the build and tests to pass, then copy its run ID.
2. From this repository's [Actions tab](https://github.com/sichengchen/macos-release/actions), run **Sign and notarize macOS release** on `main`. Enter the app profile ID and the build run ID. Leave **publish** off to check signing and notarization.
3. Enable **publish** to create the release tag at the build commit and publish the stapled package to the source repository. Public, downloadable packages can also be published to the Homebrew tap.

The signer verifies the build's repository, workflow, branch, result, and commit before opening its artifact. It uses reviewed packaging inputs from this repo and keeps private files and diagnostics on the runner.

## Add an app

Read the [setup-macos-release skill](.agents/skills/setup-macos-release/SKILL.md) for the artifact contract, workflow verification, and signing and packaging requirements. Register each app in [`apps/<app-id>/profile.json`](apps/). The profile names the source repository, trusted build workflow, release branch, and asset filename. Its sibling `sign.sh` performs the app-specific signing and packaging.
