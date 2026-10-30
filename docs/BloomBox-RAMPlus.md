# RAM+ experimental integration

RAM+ now has two independent states: a user request to enable the Apple capability,
and validation of the currently installed signature. A server approval never marks
the running process as entitled. Reinstallation is still required.

## Flow

1. In Modules → RAM+, request the permission. BloomBox records an expiring request
   for its exact installed bundle identifier and signing team. LiveProcess is
   included only when its separate identifier and matching team can be verified.
2. Open the bundled SideStore's My Apps screen. Its normal App ID lookup provides
   a current authenticated Developer Services request. Only that exact HTTPS
   endpoint is observed; the original response is passed through unchanged.
3. Within the SideStore process, RAM+ uses the current request headers in memory
   to read the selected App ID and all its existing capabilities, patch only
   Increased Memory Limit, then read it back. Credentials/headers are never
   written to preferences, files, or logs by this integration. Redirects are refused.
4. Apple approval is reported separately. Reinstall BloomBox using SideStore,
   keeping extensions and app data, and re-open RAM+ to validate the installed
   entitlement and provisioning profile. A normal refresh may retain an old profile.

Missing or mismatched teams, unknown App IDs, incomplete capability lists, failed
HTTP responses, missing readback confirmation, cancellation, and expiry all fail
closed. A file lock prevents parallel mutation attempts across SideStore processes.
A submitted request whose response is lost is reported as uncertain, never retried
automatically. Cancellation cannot undo a request already received by Apple.

The request expires after five minutes. If SideStore requires authentication, sign
in there and request RAM+ again after signing in if the first request has expired.
The manual GetMoreRam route remains available as a fallback.

## References

This implementation uses the same Developer Services capability operation as
[GetMoreRam](https://github.com/hugeBlack/GetMoreRam) and
[StosSign](https://github.com/stossy11/StosSign). The existing bundled SideStore
performs authentication; no separate authentication implementation is included.
The exact App ID lookup format is grounded in
[SideSign](https://github.com/SideStore/SideSign).

## Validation

CI covers entitlement/profile validation and the portal request planner: exact
HTTPS endpoint, team/App ID matching, preserving existing capability settings and
relationships, missing capability details, server errors, and approved/disabled
readback. An iPhone test is required to verify Apple's live response format and
SideStore's URL loading path. Compilation alone does not establish live activation.

## Resigning caveat (SideStore free accounts)

An App ID enabled on Apple's server is **not** the installed process permission.
As of October 2026, SideStore/SideSign has an unresolved upstream report
[SideStore#1616](https://github.com/SideStore/SideStore/issues/1616) where a
free-team reinstall drops the Increased Memory Limit entitlement. A proposed
[SideSign#4](https://github.com/SideStore/SideSign/pull/4) adds a v1 capability
request but is not a confirmed fix for the bundled SideStore nightly.

The BloomBox unsigned IPA explicitly requests
`com.apple.developer.kernel.increased-memory-limit=true` in both the main
executable and LiveProcess source entitlements. CI checks the **actual IPA**
executables and fails if the requests disappear during packaging. This does not
guarantee that the signer preserves them: after reinstalling, the RAM+ screen
checks the installed process entitlement and provisioning profile separately.
If either fails, the UI must not claim success. Keep the IPA and its extensions
when reinstalling; do not delete app data just to retry.

A v1 PATCH may return HTTP 204 with an empty body. This is accepted **only**
as an acknowledgement: BloomBox then fetches the App ID again and requires an
enabled Increased Memory Limit capability before reporting server approval.
Unknown or failed readbacks are never promoted to success.

## Device-test checklist

1. Before requesting, record the main app's RAM+, profile, and LiveProcess states
   from Modules -> RAM+. Never paste account tokens or provisioning profiles.
2. Trigger the permission request, then open the bundled SideStore's My Apps page
   within five minutes using the team which signed BloomBox.
3. Distinguish account mismatch, expired request, explicit Apple denial, uncertain
   submission, and approved server-side App ID.
4. After approval, **reinstall** from the IPA (not merely Refresh All), preserving
   extensions and data. Open RAM+ again; the process and profile must both pass.
5. Test an invited emulator inside the primary process and, separately, in
   LiveProcess mode if used. Do not infer a guest's JIT state from RAM+.
6. If SideStore drops the signed entitlement, investigate the upstream SideSign
   signer or preserve the manual Xcode/GetMoreRam route; do not override the
   validation screen or label the feature active.

## Incomplete capability list diagnostic (2026-10-29)

An iOS 27 report reached the authenticated SideStore read stage but Apple's
relationship `meta.paging.total` disagreed with the count in
`relationships.bundleIdCapabilities.data`. This is not a Wi-Fi/LTE problem and
is not proof that Apple accepted RAM+. In the first implementation the nested
query requested at most 50 capabilities; this patch requests up to 200. A
mismatch still blocks **all writes** and now reports the counts and whether
another page exists. The message contains no Apple ID, tokens or bundle IDs.
If the new limit does not resolve the mismatch, use the counts to implement a
verified pagination read rather than dropping the safety guard or clearing
other Apple capabilities. The provisioning profile is unchanged until a new
signing/install step actually includes RAM+.
