import ActivityKit
import Combine
import Foundation
import UserNotifications

/// Watches SideStore's published widget snapshot. No private SideStore database edits,
/// no JIT and no background polling: iOS starts a scheduled Live Activity at T-8h.
@available(iOS 16.2, *)
@MainActor
final class ManzanaExpiryReminderCenter: ObservableObject {
    static let shared = ManzanaExpiryReminderCenter()
    static let reminderHours: TimeInterval = 8 * 60 * 60
    private static let enabledKey = "ManzanaSideStoreExpiryRemindersEnabled"
    private static let notificationPrefix = "manzana.expiry."
    @Published private(set) var status = "Todavía no se han consultado las fechas de SideStore."
    @Published private(set) var nearestExpiration: Date?
    @Published private(set) var appCount = 0
    @Published private(set) var snapshotDate: Date?
    @Published private(set) var enabled: Bool
    @Published private(set) var demoMessage = "Prueba la Isla Dinámica sin esperar al vencimiento de SideStore."
    @Published private(set) var demonstrationActive = false
    private var refreshing = false

    private init() {
        enabled = LCUtils.appGroupUserDefault.bool(forKey: Self.enabledKey)
        demonstrationActive = Activity<ManzanaExpiryAttributes>.activities.contains { $0.attributes.source == "Manzana-demo" }
    }

    func startDemo() async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            demoMessage = "Las Actividades en vivo están desactivadas. Actívalas en Ajustes → BloomBox → Actividades en vivo."
            demonstrationActive = false
            return
        }
        await stopDemo(silent: true)
        do {
            let expiry = Date().addingTimeInterval(180)
            let state = ManzanaExpiryAttributes.ContentState(
                expiresAt: expiry, earliestAppName: "Prueba de BloomBox", expiringAppCount: 1
            )
            _ = try Activity<ManzanaExpiryAttributes>.request(
                attributes: ManzanaExpiryAttributes(source: "Manzana-demo"),
                content: ActivityContent(state: state, staleDate: expiry),
                pushType: nil
            )
            demonstrationActive = true
            demoMessage = "Prueba activa durante 3 minutos. Sal de BloomBox para comprobar la Isla Dinámica; mantén pulsada la isla para expandirla."
        } catch {
            demonstrationActive = false
            demoMessage = "No se pudo iniciar la prueba: \(error.localizedDescription)"
        }
    }

    func stopDemo(silent: Bool = false) async {
        for activity in Activity<ManzanaExpiryAttributes>.activities where
            activity.attributes.source == "Manzana-demo" {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        demonstrationActive = false
        if !silent { demoMessage = "Prueba detenida; los recordatorios reales no se modificaron." }
    }

    func setEnabled(_ newValue: Bool) {
        enabled = newValue
        LCUtils.appGroupUserDefault.set(newValue, forKey: Self.enabledKey)
        Task { await synchronize() }
    }

    /// SideStore itself publishes this Codable JSON to its signing App Group.
    /// Date is encoded by JSONEncoder as seconds since the Apple reference date.
    private struct SideStoreSnapshot: Decodable {
        struct App: Decodable {
            let name: String
            let bundleIdentifier: String
            let expirationDate: Date
        }
        let activeApps: [App]
        let lastUpdated: Date
    }

    private func readSnapshot() -> SideStoreSnapshot? {
        guard let groupID = LCSharedUtils.appGroupID(),
              let directory = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
        else { return nil }
        let file = directory.appendingPathComponent("widget_data.json")
        guard let bytes = try? Data(contentsOf: file) else { return nil }
        return try? JSONDecoder().decode(SideStoreSnapshot.self, from: bytes)
    }

    func synchronize() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }

        guard enabled else {
            status = "Recordatorios desactivados."
            nearestExpiration = nil
            await clearScheduledReminders()
            return
        }

        guard let snapshot = readSnapshot() else {
            status = "SideStore aún no ha publicado widget_data.json en el App Group compartido. Abre SideStore, actualiza su información y vuelve a BloomBox."
            // Preserve existing reminders when the snapshot is temporarily unavailable.
            return
        }
        snapshotDate = snapshot.lastUpdated
        let now = Date()
        let upcoming = snapshot.activeApps.filter { $0.expirationDate > now }
            .sorted { $0.expirationDate < $1.expirationDate }

        guard let first = upcoming.first else {
            nearestExpiration = nil
            appCount = 0
            status = "SideStore no muestra aplicaciones activas con caducidad futura."
            await clearScheduledReminders()
            return
        }

        nearestExpiration = first.expirationDate
        appCount = upcoming.filter { $0.expirationDate <= first.expirationDate.addingTimeInterval(Self.reminderHours) }.count
        let targetState = ManzanaExpiryAttributes.ContentState(
            expiresAt: first.expirationDate,
            earliestAppName: first.name,
            expiringAppCount: appCount
        )
        let start = first.expirationDate.addingTimeInterval(-Self.reminderHours)
        let current = Activity<ManzanaExpiryAttributes>.activities

        // A refresh may move the expiration. Never leave an old pending countdown
        // running against an obsolete profile expiration date.
        var matchingActivity = false
        for activity in current where activity.attributes.source == "SideStore" {
            let currentState = activity.content.state
            if activity.attributes.source == "SideStore" &&
                currentState.expiresAt == targetState.expiresAt &&
                currentState.expiringAppCount == targetState.expiringAppCount {
                matchingActivity = true
            } else {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }

        var activityAvailable = ActivityAuthorizationInfo().areActivitiesEnabled
        if activityAvailable && !matchingActivity {
            do {
                let content = ActivityContent(state: targetState, staleDate: first.expirationDate)
                if start <= now {
                    _ = try Activity<ManzanaExpiryAttributes>.request(
                        attributes: ManzanaExpiryAttributes(source: "SideStore"),
                        content: content, pushType: nil
                    )
                } else if #available(iOS 26.0, *) {
                    // The OS will start this even if BloomBox is no longer open.
                    _ = try Activity<ManzanaExpiryAttributes>.request(
                        attributes: ManzanaExpiryAttributes(source: "SideStore"),
                        content: content,
                        pushType: nil,
                        style: .standard,
                        alertConfiguration: AlertConfiguration(
                            title: "BloomBox · SideStore",
                            body: "Quedan 8 horas para renovar tus apps.",
                            sound: .default
                        ),
                        start: start
                    )
                } else {
                    activityAvailable = false
                }
            } catch {
                activityAvailable = false
                status = "No se pudo programar la Isla Dinámica: \(error.localizedDescription)"
            }
        }

        // Local alerts cover the one-hour milestone and offer a fallback
        // when Live Activities are disabled or the iOS version is older.
        await configureNotifications(expiry: first.expirationDate, appName: first.name,
                                     includeEightHour: !activityAvailable)
        if activityAvailable {
            status = start > now
                ? "Isla Dinámica programada para las últimas 8 horas."
                : "Cuenta regresiva activa para la caducidad de SideStore."
        } else if !status.hasPrefix("No se pudo programar") {
            status = "Notificaciones programadas; Live Activities no disponibles."
        }
    }

    private func configureNotifications(expiry: Date, appName: String, includeEightHour: Bool) async {
        let center = UNUserNotificationCenter.current()
        let permission = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
        let ids = [Self.notificationPrefix + "8h", Self.notificationPrefix + "1h"]
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard permission else { return }

        let now = Date()
        let events: [(String, TimeInterval)] = includeEightHour
            ? [("8h", Self.reminderHours), ("1h", 3600)]
            : [("1h", 3600)]
        for (identifier, offset) in events {
            let intended = expiry.addingTimeInterval(-offset)
            guard intended > now else { continue }
            let content = UNMutableNotificationContent()
            content.title = "🍎 BloomBox · SideStore"
            content.body = identifier == "8h"
                ? "Quedan 8 horas para que caduque \(appName). Abre SideStore y renueva."
                : "¡Última hora! Refresca tus aplicaciones en SideStore."
            content.sound = .default
            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second], from: intended
            )
            center.add(UNNotificationRequest(
                identifier: Self.notificationPrefix + identifier,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            )) { error in
                if let error { NSLog("[BloomBox expiry] Could not schedule reminder: %@", error.localizedDescription) }
            }
        }
    }

    private func clearScheduledReminders() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.notificationPrefix + "8h", Self.notificationPrefix + "1h"]
        )
        for activity in Activity<ManzanaExpiryAttributes>.activities where
            activity.attributes.source == "SideStore" {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}
