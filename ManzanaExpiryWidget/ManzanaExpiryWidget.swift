import ActivityKit
import SwiftUI
import WidgetKit

@main
struct ManzanaExpiryWidgetBundle: WidgetBundle {
    var body: some Widget {
        ManzanaExpiryLiveActivity()
    }
}

@available(iOSApplicationExtension 16.2, *)
struct ManzanaExpiryLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ManzanaExpiryAttributes.self) { context in
            HStack(spacing: 12) {
                Image(systemName: "apple.logo").font(.title2).foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Manzana · SideStore").font(.headline)
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
                    Label("Manzana", systemImage: "apple.logo").font(.headline)
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
