# macOS releases

This repository runs Developer ID signing and Apple notarization for maintainer-approved macOS builds. Each app repository compiles and tests its own code. The release workflow runs here on a standard macOS runner and keeps the Apple credentials in one place.

## Configure once

Create the `apple-release` Actions environment here. Restrict deployments to the `main` branch. If you add required reviewers, make sure someone can approve a run started by the maintainer. The workflow is manual and checks the repository and branch before running.

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

## Cut an Eau release

1. On Eau's `main`, run **Prepare macOS release**. Choose a version bump, or **current** to retry a version committed by an earlier preparation. Wait for the successful artifact upload and copy the run ID.
2. In this repo, run [**Sign and notarize macOS release**](https://github.com/sichengchen/macos-release/actions/workflows/release-macos.yml) from `main` with that run ID. Leave **publish** off for an Apple signing and notarization check. An accepted check retains no public artifact.
3. Run with **publish** enabled to create the tag at the build commit and publish the stapled installer in Eau Releases. An existing tag must resolve to the same commit. The workflow never replaces an existing release asset.
4. The workflow updates the public tap only when the source repo is public. Eau currently publishes to its private GitHub Releases. If the tap job fails for a public release, rerun that failed job.

The signing run checks the source repository, workflow path, dispatched branch, completion status, and artifact commit ancestry. It treats the app archive as data and uses the reviewed installer script in this repo. The public run displays release progress and its inputs. It keeps app files, raw logs, and notarization responses on the runner. Store or share private diagnostics only through a private channel.

## Add another app

Use the [setup-macos-release skill](.agents/skills/setup-macos-release/SKILL.md) for the build artifact contract, repo checks, and package-specific integration. Eau is the first integration. Rajio's universal DMG will need its own signing and packaging profile.
