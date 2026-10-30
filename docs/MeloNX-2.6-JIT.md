# MeloNX 2.6 built-in JIT experiment

Based on BloomBox v1.3.0. No external StikDebug installation is required;
LocalDevVPN and Developer Mode remain required. Pair/import the pairing file in
Modules > JIT and choose the built-in provider. Keep all extensions when signing.

The profile matches `com.stossy11.MeloNX` and version `2.6` exactly. It automatically
requests JIT and supplies the pinned upstream script when no custom script is set.
Existing custom scripts take precedence; remove a previously imported universal
script to use this profile. Classic Mode must be off. The provider is not changed
automatically. Unknown versions receive no automatic profile.

Before connecting, LiveProcess reports its own signed get-task-allow and RAM+
values, before guest hooks load. BloomBox waits up to five seconds for this report
and blocks debugging when the permission is missing or unknown. Reports contain
only PID, timestamp and permission booleans, and are consumed after reading.
RAM+ is logged independently and is not inferred from the main app's permission.

The helper reports tunnel, debug-service and script stages. Each executable-page
preparation reply must be OK; transport success alone is not accepted. A successful
script request is not a confirmed game launch or a substitute for MeloNX's check.

## Device validation still required

1. Install the experimental IPA with the same signing identity, preserving data
   and all extensions. Connect LocalDevVPN and select built-in JIT.
2. Open MeloNX 2.6 with Classic Mode off and no custom JIT script override.
   In MeloNX choose None for its external JIT provider, so BloomBox owns activation.
3. Record LiveProcess debugging and RAM+ status, attach response, prepared pages
   and detach. Missing get-task-allow requires fixing the extension signature.
4. Confirm MeloNX itself accepts JIT, then launch a game. Close the guest fully
   and repeat, then repeat after a device reboot.
5. For E96 or ConnectionReset, retain the stage log. These errors are NOT claimed
   fixed by adding this profile. Do not share pairing files or signing credentials.

CI exercises the actual script with mocked debugger rejection, missing registers,
qualified thread IDs, disconnects and guest exits. Only physical-device testing
can establish compatibility with iOS 27 and the installed SideStore signature.
