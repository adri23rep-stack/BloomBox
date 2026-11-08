import Foundation
import SwiftUI
import UIKit
import CryptoKit
import Network
import UserNotifications

/// Foreground-driven update checks. iOS does not promise background checks or
/// permit bypassing signing/installation confirmations.
@MainActor
final class BloomBoxAutoUpdate: ObservableObject {
    static let shared = BloomBoxAutoUpdate()

    static let automaticKey = "BloomBoxAutoUpdateAutomatic"
    static let wifiOnlyKey = "BloomBoxAutoUpdateWiFiOnly"
    static let notificationsKey = "BloomBoxAutoUpdateNotifications"
    static let betaKey = "BloomBoxAutoUpdateBetas"

    @Published private(set) var status = ""
    @Published private(set) var busy = false
    @Published private(set) var wifiAvailable = false
    @Published private(set) var offeredTag: String?
    @Published private(set) var decision: BloomBoxAutoUpdatePolicy.Decision = .none

    private let defaults = LCUtils.appGroupUserDefault
    private let monitor = NWPathMonitor()
    private var currentAsset: BloomBoxRAMRelease.Asset?
    private let checkInterval: TimeInterval = 6 * 60 * 60

    private init() {
        defaults.register(defaults: [
            Self.automaticKey: true, Self.wifiOnlyKey: true,
            Self.notificationsKey: true, Self.betaKey: false
        ])
        status = localized("Comprobación pendiente", "Waiting to check")
        monitor.pathUpdateHandler = { [weak self] path in
            let usable = path.status == .satisfied && path.usesInterfaceType(.wifi)
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.wifiAvailable = usable
                if usable { await self.installAutomaticallyIfPossible() }
            }
        }
        monitor.start(queue: DispatchQueue(label: "bloombox.autoupdate.network"))
    }

    private func localized(_ spanish: String, _ english: String) -> String {
        BloomBoxL10n.isEnglish ? english : spanish
    }

    private var automatic: Bool { defaults.bool(forKey: Self.automaticKey) }
    private var wifiOnly: Bool { defaults.bool(forKey: Self.wifiOnlyKey) }
    private var notices: Bool { defaults.bool(forKey: Self.notificationsKey) }

    private var installedTag: String? {
        // Never compare against CFBundleShortVersionString: it belongs to LiveContainer.
        Bundle.main.object(forInfoDictionaryKey: "BloomBoxReleaseTag") as? String
    }

    func checkIfDue(force: Bool = false) async {
        guard UIApplication.shared.applicationState == .active, !busy else { return }
        let last = defaults.object(forKey: "BloomBoxAutoUpdateLastCheck") as? Date ?? .distantPast
        if !force && Date().timeIntervalSince(last) < checkInterval { return }
        busy = true
        status = localized("Buscando actualizaciones…", "Checking for updates…")
        defer { busy = false }
        do {
            var request = URLRequest(url: BloomBoxRAMRelease.latestAPI)
            request.timeoutInterval = 25
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw BloomBoxRAMRelease.Failure(message: "GitHub did not return a valid release response.")
            }
            // This parser rejects drafts/betas, missing digests and unexpected hosts.
            let asset = try BloomBoxRAMRelease.select(json: data)
            currentAsset = asset
            offeredTag = asset.tag
            decision = BloomBoxAutoUpdatePolicy.decision(installedTag: installedTag, availableTag: asset.tag)
            defaults.set(Date(), forKey: "BloomBoxAutoUpdateLastCheck")
            switch decision {
            case .none:
                status = localized("BloomBox está actualizado o es una compilación más reciente.",
                                   "BloomBox is up to date or is a newer build.")
                if installedTag == asset.tag {
                    defaults.removeObject(forKey: "BloomBoxAutoUpdateAttemptedTag")
                }
            case .offerOnly:
                status = localized("Última versión estable: \(asset.tag). Esta instalación no tiene una versión BloomBox verificable; actualiza manualmente.",
                                   "Latest stable: \(asset.tag). This build has no verified BloomBox version; update manually.")
                notifyOnce(tag: asset.tag)
            case .eligible:
                status = localized("Actualización disponible: \(asset.tag)", "Update available: \(asset.tag)")
                notifyOnce(tag: asset.tag)
            }
        } catch {
            status = localized("No se pudo comprobar: ", "Could not check: ") + error.localizedDescription
            return
        }
        // Release the check lock before starting the installer.
        busy = false
        await installAutomaticallyIfPossible()
    }

    private func installAutomaticallyIfPossible() async {
        guard !busy, automatic, decision == .eligible,
              UIApplication.shared.applicationState == .active,
              let asset = currentAsset,
              defaults.string(forKey: "BloomBoxAutoUpdateAttemptedTag") != asset.tag else { return }
        await install(forceRetry: false)
    }

    func install(forceRetry: Bool = false) async {
        guard !busy, decision == .eligible, let asset = currentAsset else { return }
        guard !wifiOnly || wifiAvailable else {
            status = localized("Esperando una conexión Wi-Fi para descargar.",
                               "Waiting for Wi-Fi before downloading.")
            return
        }
        guard forceRetry || defaults.string(forKey: "BloomBoxAutoUpdateAttemptedTag") != asset.tag else {
            status = localized("Ya se intentó instalar esta versión. Usa Reintentar si es necesario.",
                               "This version was already attempted. Use Retry if needed.")
            return
        }
        busy = true
        defer { busy = false }
        do {
            status = localized("Descargando y verificando \(asset.tag)…", "Downloading and verifying \(asset.tag)…")
            let (download, response) = try await URLSession.shared.download(from: asset.url)
            defer { try? FileManager.default.removeItem(at: download) }
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw BloomBoxRAMRelease.Failure(message: "Download failed.")
            }
            let measured = (try FileManager.default.attributesOfItem(atPath: download.path)[.size] as? NSNumber)?.int64Value ?? -1
            guard measured == asset.size else {
                throw BloomBoxRAMRelease.Failure(message: "Downloaded IPA size does not match the GitHub release.")
            }
            let handle = try FileHandle(forReadingFrom: download)
            defer { try? handle.close() }
            var hasher = SHA256()
            while let chunk = try handle.read(upToCount: 1024 * 1024), !chunk.isEmpty {
                hasher.update(data: chunk)
            }
            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == asset.digest else {
                throw BloomBoxRAMRelease.Failure(message: "Downloaded IPA SHA-256 does not match the official release.")
            }

            let info = try BloomBoxArchive.inspectIPA(download)
            let installed = Bundle.main.bundleIdentifier ?? ""
            let sourceID = info["bundle"] as? String ?? ""
            let sourceVersion = info["version"] as? String ?? ""
            let sourceBuild = info["build"] as? String ?? ""
            let existing = Set(((try? FileManager.default.contentsOfDirectory(
                atPath: Bundle.main.builtInPlugInsURL?.path ?? "")) ?? []).filter { $0.hasSuffix(".appex") })
            let candidate = Set(info["extensions"] as? [String] ?? [])
            guard BloomBoxRAMRelease.compatibleIdentity(installed: installed, sourceBundle: sourceID),
                  !sourceVersion.isEmpty, !sourceBuild.isEmpty,
                  BloomBoxRAMRelease.preservesExtensions(installed: existing, candidate: candidate),
                  let deepLink = BloomBoxAutoUpdatePolicy.installURL(for: asset.url) else {
                throw BloomBoxRAMRelease.Failure(message: "This IPA does not preserve the installed identity and extensions.")
            }
            // SideStore downloads the official URL again and signs it. We cannot
            // guarantee a silent install or that its signing preserves RAM+.
            status = localized("IPA verificada. Abriendo SideStore para firmar e instalar…",
                               "IPA verified. Opening SideStore to sign and install…")
            defaults.set(asset.tag, forKey: "BloomBoxAutoUpdateAttemptedTag")
            UIApplication.shared.open(deepLink, options: [:]) { [weak self] opened in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.status = opened
                        ? self.localized("Solicitud enviada a SideStore. Al volver, comprueba RAM+ y JIT.",
                                         "Sent to SideStore. Check RAM+ and JIT after returning.")
                        : self.localized("No se pudo abrir SideStore. Reintenta desde Actualizaciones.",
                                         "Could not open SideStore. Retry from Updates.")
                }
            }
        } catch {
            status = localized("Instalación no iniciada: ", "Installation not started: ") + error.localizedDescription
        }
    }

    private func notifyOnce(tag: String) {
        guard notices, defaults.string(forKey: "BloomBoxAutoUpdateNotifiedTag") != tag else { return }
        UNUserNotificationCenter.current().getNotificationSettings { [weak self] settings in
            guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else { return }
            Task { @MainActor [weak self] in
                guard let self,
                      self.defaults.string(forKey: "BloomBoxAutoUpdateNotifiedTag") != tag else { return }
                let content = UNMutableNotificationContent()
                content.title = "BloomBox \(tag)"
                content.body = self.localized("Hay una nueva actualización disponible.",
                                              "A new update is available.")
                content.sound = .default
                let request = UNNotificationRequest(
                    identifier: "bloombox.autoupdate.\(tag)", content: content,
                    trigger: UNTimeIntervalNotificationTrigger(timeInterval: 5, repeats: false))
                UNUserNotificationCenter.current().add(request) { error in
                    if error == nil {
                        Task { @MainActor [weak self] in
                            self?.defaults.set(tag, forKey: "BloomBoxAutoUpdateNotifiedTag")
                        }
                    }
                }
            }
        }
    }

    func requestNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    var canInstall: Bool { decision == .eligible && !busy }
    var canRetry: Bool {
        guard let tag = offeredTag else { return false }
        return canInstall && defaults.string(forKey: "BloomBoxAutoUpdateAttemptedTag") == tag
    }
}

struct BloomBoxAutoUpdateSettingsView: View {
    @ObservedObject private var updater = BloomBoxAutoUpdate.shared
    @AppStorage(BloomBoxAutoUpdate.automaticKey, store: LCUtils.appGroupUserDefault)
    private var automatic = true
    @AppStorage(BloomBoxAutoUpdate.wifiOnlyKey, store: LCUtils.appGroupUserDefault)
    private var wifiOnly = true
    @AppStorage(BloomBoxAutoUpdate.notificationsKey, store: LCUtils.appGroupUserDefault)
    private var notifications = true

    private var english: Bool { BloomBoxL10n.isEnglish }

    var body: some View {
        Form {
            Section {
                LabeledContent(english ? "Installed BloomBox version" : "Versión instalada de BloomBox",
                               value: Bundle.main.object(forInfoDictionaryKey: "BloomBoxReleaseTag") as? String ?? "Legacy / Dev")
                if let tag = updater.offeredTag {
                    LabeledContent(english ? "Latest stable release" : "Última versión estable", value: tag)
                }
                Label(updater.status, systemImage: "arrow.triangle.2.circlepath")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button {
                    Task { await updater.checkIfDue(force: true) }
                } label: {
                    Label(english ? "Check now" : "Buscar ahora", systemImage: "magnifyingglass")
                }
                .disabled(updater.busy)
            } header: {
                Text("BloomBox AutoUpdate")
            }

            Section {
                Toggle(english ? "Automatic updates" : "Actualizaciones automáticas", isOn: $automatic)
                Toggle(english ? "Download only on Wi-Fi" : "Descargar solo por Wi-Fi", isOn: $wifiOnly)
                Toggle(english ? "New version notifications" : "Notificar nuevas versiones", isOn: $notifications)
                if notifications {
                    Button(english ? "Allow iOS notifications" : "Permitir notificaciones de iOS") {
                        updater.requestNotifications()
                    }
                }
                Label(english ? "Beta versions: Off" : "Versiones beta: Desactivadas",
                      systemImage: "checkmark.shield")
                    .foregroundStyle(.secondary)
            } footer: {
                Text(english
                     ? "Checks occur when BloomBox is open. Downloads use Wi-Fi when required. SideStore and iOS may still ask you to confirm signing or installation."
                     : "Se comprueba al abrir BloomBox. Las descargas respetan Wi-Fi. SideStore y iOS todavía pueden pedir confirmación de firma o instalación.")
            }

            Section {
                if updater.canInstall {
                    Button {
                        Task { await updater.install(forceRetry: updater.canRetry) }
                    } label: {
                        Label(updater.canRetry
                              ? (english ? "Retry installation" : "Reintentar instalación")
                              : (english ? "Install with SideStore" : "Instalar con SideStore"),
                              systemImage: "square.and.arrow.down")
                    }
                }
                if updater.decision == .offerOnly {
                    Link(english ? "Review official release" : "Revisar release oficial",
                         destination: URL(string: "https://github.com/adri23rep-stack/BloomBox/releases/latest")!)
                }
                Label(english ? "Updating over the current app should preserve data, but only the signer can confirm permissions and identity."
                              : "Instala encima de la app actual para conservar datos. La firma debe mantener la identidad y los permisos.",
                      systemImage: "exclamationmark.shield")
                    .font(.footnote)
            }
        }
        .navigationTitle("AutoUpdate")
        .navigationBarTitleDisplayMode(.inline)
        .task { await updater.checkIfDue(force: true) }
        .onChange(of: automatic) { enabled in
            if enabled { Task { await updater.checkIfDue(force: true) } }
        }
    }
}
