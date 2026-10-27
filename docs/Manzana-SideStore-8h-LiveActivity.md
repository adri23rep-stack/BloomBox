# Manzana · SideStore expiry countdown (8 hours)

Experimental feature branch, merged on top of the successful iOS 27 pairing/JIT branch.

## Activation

1. Install the **LiveContainer+SideStore.ipa** build, keeping *all* app extensions.
2. Open SideStore once so it publishes its `widget_data.json` snapshot in the App Group.
3. Open Manzana > Settings > **Caducidad · Isla Dinámica (8 horas)**.
4. Enable **Contador de caducidad**, and allow notifications / Live Activities.
5. Manzana schedules a Live Activity for exactly **8 hours before** the earliest active SideStore app expiry, and a local notification at the **1-hour** mark.
6. Opening Manzana again after renewing applications re-reads the snapshot, cancels the old countdown and schedules the new one.

Only apps tracked by SideStore's published `WidgetDataSnapshot.activeApps` are considered. Guest apps installed *inside* Manzana that aren't managed by SideStore are not added.

On iOS 26+ ActivityKit supports **scheduled Live Activities** with an alert. The system can start them when Manzana is in the background. Apple can still suppress a Live Activity if Live Activities are disabled, the user has dismissed it, or system limits apply. A Live Activity can run for up to eight hours.

On iOS earlier than 26, scheduled Live Activities are not supported by this integration; local notification reminders provide a fallback.

## Code

- `ManzanaExpiryWidget/`: ActivityKit attributes and WidgetKit Dynamic Island extension.
- `LiveContainerSwiftUI/Views/ManzanaExpiryReminderCenter.swift`: decodes SideStore's Codable JSON; schedules/cancels activities; handles notifications. No JIT required.
- `LiveContainerSwiftUI/Views/ManzanaExpiryReminderSettings.swift`: opt-in and status.
- `LiveContainer/Info.plist` enables Live Activities.

## Limitations / verification

- Data must be published by the SideStore version installed and accessible via **the same signed App Group** as Manzana. If absent, the settings screen explains this and **does not invent an expiry date**.
- SideStore app renewal may change expiry times; open Manzana after renewal to sync.
- A working build does not confirm iOS has granted Live Activities or that the extension survives SideStore signing. Test the widget in the IPA on a real iPhone 14 Pro.
- The extension uses `livecontainer://` to open Manzana; a dedicated deep link into SideStore can be added later.
- SideStore and LocalDevVPN continue unchanged. This feature never refreshes signatures automatically.
- Keep the iOS 27 pairing/JIT branch as base and main untouched until validation.
