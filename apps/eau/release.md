# Release Eau

Complete the [shared signing setup](../../README.md#configure-once) first.

1. On Eau's `main`, run **Prepare macOS release**. Choose a version bump, or **current** to retry a version committed by an earlier preparation. Wait for the successful artifact upload and copy the run ID.
2. In this repo, run [**Sign and notarize macOS release**](https://github.com/sichengchen/macos-release/actions/workflows/release-macos.yml) from `main` with that run ID. Leave **publish** off for an Apple signing and notarization check. An accepted check retains no public artifact.
3. Run with **publish** enabled to create the tag at the build commit and publish the stapled installer in Eau Releases. An existing tag must resolve to the same commit. The workflow never replaces an existing release asset.
4. The workflow updates the public tap only when the source repo is public. Eau currently publishes to its private GitHub Releases. If the tap job fails for a public release, rerun that failed job.


The signer requires the reviewed [installer script](postinstall) to match the copy supplied with the build artifact. Update both copies when installer behavior changes.
