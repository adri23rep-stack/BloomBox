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
