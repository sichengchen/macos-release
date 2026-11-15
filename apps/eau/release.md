# Release Eau

Complete the [shared signing setup](../../README.md#configure-once) first.

1. Run [**Sign and notarize macOS release**](https://github.com/sichengchen/macos-release/actions/workflows/release-macos.yml) on `main` with `app=eau`. Leave `run_id` blank and choose a bump to build automatically, or supply a successful **Prepare macOS release** run ID to reuse that artifact.
2. Leave **Publish** off for the first signing test. For a release, turn on **Publish**. The workflow creates the source version tag in the private repo and uploads the stapled installer to [public Releases](https://github.com/sichengchen/macos-release/releases) under `eau-v<version>`.
3. The cask points at the public installer. If the tap job fails, rerun the failed job after checking the GitHub App's tap permissions.


The signer requires the reviewed [installer script](postinstall) to match the copy supplied with the build artifact. Update both copies when installer behavior changes.
