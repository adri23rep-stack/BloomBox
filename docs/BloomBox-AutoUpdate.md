# BloomBox AutoUpdate: architecture and acceptance checklist

Status: isolated feature branch. No main merge, no release.

## Default configuration

- Automatic installation handoff: ON, when safely eligible.
- Downloads restricted to Wi-Fi: ON.
- Local notifications: ON, subject to the iOS notification permission.
- Beta releases: OFF. Beta channel support is intentionally not included in this first iteration.

## Version source

BloomBox has its own BloomBoxReleaseTag in Info.plist, independent of the
inherited LiveContainer CFBundleShortVersionString (3.8.10). Development
builds are stamped development. The CI stamps a stable release number only
from an explicit version tag or a matching release commit on main.

Existing installations without an embedded BloomBox tag require a manual
upgrade first. Development builds cannot be overwritten automatically.
Never publish a release IPA without confirming its embedded version tag
matches the GitHub release tag.

## Process

1. Check the official GitHub /releases/latest when the app opens or resumes;
   reuse a cached result within the same process for up to six hours.
2. Refuse drafts, beta builds, incorrect assets or missing SHA-256.
3. Compare numeric BloomBox release tags, not LiveContainer versions.
4. Notify once per eligible release, when the user granted permission.
5. On Wi-Fi and when no guest is selected, download and verify the IPA.
6. Validate file size, SHA-256, application identity and required extensions.
7. Send the official release URL to SideStore for signing/installation.
8. After reopening, detect the installed version and permit retry if needed.

## Honest limitations

iOS does not guarantee background executions or completely silent
installation. SideStore may request confirmation and download the same asset
again. Thus the locally verified IPA is a preflight check, not a guarantee
that the signer's second download is byte-identical. Wi-Fi-only restrictions
are enforced for BloomBox's own download; SideStore controls its own
connection after handoff.

Keep the signing account, team, bundle identifier, extensions and app data.
Re-signing may change RAM+ permissions and require JIT diagnostics.

## Device acceptance tests

- Legacy / development builds never install stable releases automatically.
- Equal or newer installed versions cannot be downgraded.
- Automatic mode starts only for a strictly newer verified stable tag.
- Manual mode never launches SideStore without a user action.
- Cellular-only connection never downloads the IPA.
- Active guest or game is never interrupted for an automatic update.
- Denied notification permissions produce no notification request loop.
- Bad SHA-256, missing extensions or API failures cannot open the installer.
- Failed SideStore handoff can be retried.
- Updated app retains profiles, wallpaper, GameBox, guest containers, and
  extension registration; check RAM+ and JIT on iOS 27 hardware.
- Verify both English and Spanish settings.

## Future improvements

Progress UI, signed-file local handoff to SideStore, post-install checks,
and richer in-app release notes. Do not promise a fully unattended installer
until the signing and iOS behavior has been tested on physical devices.
