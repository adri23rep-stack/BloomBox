import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ManzanaExpiryWidgetBundle: WidgetBundle {
    var body: some Widget {
        ManzanaExpiryLiveActivity()
        BloomBoxPairingLiveActivity()
    }
}

@available(iOSApplicationExtension 16.2, *)
struct ManzanaExpiryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ManzanaExpiryAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "apple.logo").font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("BloomBox · SideStore").font(.headline)
                    Text("Renueva tus apps antes de que caduquen")
                        .font(.caption).foregroundStyle(.secondary)
                    if context.state.expiringAppCount > 1 {
                        Text("\(context.state.expiringAppCount) aplicaciones por caducar")
                            .font(.caption2).foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 5)
                Text(context.state.expiresAt, style: .timer)
                    .monospacedDigit().font(.headline).foregroundStyle(.orange)
            }
            .padding(12)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.orange)
            .widgetURL(URL(string: "livecontainer://"))
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("BloomBox", systemImage: "apple.logo").font(.headline)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.expiresAt, style: .timer)
                        .monospacedDigit().foregroundStyle(.orange).font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text("Tus apps caducan pronto").font(.subheadline)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 5) {
                        Text(context.state.earliestAppName).font(.caption)
                            .lineLimit(1).foregroundStyle(.secondary)
                        Text("Abre SideStore y refresca las apps")
                            .font(.caption2).foregroundStyle(.orange)
                    }
                }
            } compactLeading: {
                Image(systemName: "apple.logo").foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.expiresAt, style: .timer)
                    .monospacedDigit().foregroundStyle(.orange)
                    .font(.caption2)
                    .frame(maxWidth: 74)
            } minimal: {
                Image(systemName: "clock.badge.exclamationmark").foregroundStyle(.orange)
            }
            .widgetURL(URL(string: "livecontainer://"))
            .keylineTint(.orange)
        }
    }
}

 
// A visible PIN during Settings pairing is necessary because the callback
// arrives only after the user chooses "Pair with BloomBox" in iOS Settings.
@available(iOSApplicationExtension 16.2, *)
struct BloomBoxPairingLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BloomBoxPairingAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "key.fill")
                    .font(.title2)
                    .foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("BloomBox · JIT pairing").font(.headline)
                    if let pin = context.state.pin {
                        Text(pin)
                            .font(.title2.weight(.bold).monospacedDigit())
                            .textSelection(.enabled)
                            .accessibilityLabel("Pairing code " + pin)
                    } else {
                        Text("Open Settings and choose Pair with BloomBox")
                            .font(.caption)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .activityBackgroundTint(.black)
            .activitySystemActionForegroundColor(.mint)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("BloomBox JIT", systemImage: "key.fill")
                        .font(.headline)
                }
                DynamicIslandExpandedRegion(.center) {
                    if let pin = context.state.pin {
                        Text(pin).font(.system(size: 27, weight: .bold, design: .monospaced))
                            .accessibilityLabel("Pairing code " + pin)
                    } else {
                        Text("Waiting for pairing request…").font(.subheadline)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Enter this code in iPhone Settings")
                        .font(.caption)
                }
            } compactLeading: {
                Image(systemName: "key.fill").foregroundStyle(.mint)
            } compactTrailing: {
                if let pin = context.state.pin {
                    Text(pin).font(.caption2.monospacedDigit())
                } else {
                    Image(systemName: "ellipsis").foregroundStyle(.mint)
                }
            } minimal: {
                Image(systemName: "key.fill").foregroundStyle(.mint)
            }
            .keylineTint(.mint)
        }
    }
}
