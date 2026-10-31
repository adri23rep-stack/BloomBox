import SwiftUI
import CryptoKit
import UniformTypeIdentifiers

@MainActor
final class BloomBoxRAMPlus: ObservableObject {
    static let shared = BloomBoxRAMPlus()
    private let defaults = LCUtils.appGroupUserDefault
    private let key = "BloomBoxRAMPlusRequested"
    @Published private(set) var requested = false
    @Published private(set) var validation = BloomBoxRAMValidation.inspect(runtime: nil, profile: nil, applicationIdentifier: nil)
    @Published private(set) var extensionSigned: Bool?
    @Published private(set) var available: UInt64 = 0
    @Published private(set) var checkedAt: Date?
    @Published private(set) var applicationIdentifier = ""
    @Published private(set) var activationStatus = ""
    @Published private(set) var activationMessage = ""
    private let reinstallKey = "BloomBoxRAMReinstall"
    private let experimentalControlsKey = "BloomBoxRAMPlusExperimentalControls"
    private var experimentalControlsEnabled: Bool { defaults.bool(forKey: experimentalControlsKey) }
    private var experimentalReinstall: Bool {
        experimentalControlsEnabled &&
        (defaults.dictionary(forKey: reinstallKey)?["experimental"] as? Bool == true)
    }
    @Published private(set) var reinstallStage = ""
    @Published private(set) var reinstallMessage = ""
    @Published private(set) var preparedIPA: URL?
    @Published private(set) var reinstallBusy = false
    var activationPending: Bool { ["awaitingSession", "checking", "requesting"].contains(activationStatus) }

    func requestActivation() throws {
        guard !activationPending else { return }
        guard let signature = Self.signature(Bundle.main.executablePath),
              let team = signature["com.apple.developer.team-identifier"] as? String, !team.isEmpty,
              let appIdentifier = signature["application-identifier"] as? String,
              let bundle = Bundle.main.bundleIdentifier,
              appIdentifier.hasSuffix("." + bundle),
              Bundle.main.privateFrameworksURL.map({ FileManager.default.fileExists(atPath: $0.appendingPathComponent("SideStoreApp.framework").path) }) == true else {
            throw NSError(domain: "BloomBoxRAM", code: 1, userInfo: [NSLocalizedDescriptionKey: "No se pudo identificar la cuenta de firma o falta el SideStore integrado. Reinstala la edición con SideStore."])
        }
        var bundles = [bundle]
        if let url = Bundle.main.builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex"),
           let extensionBundle = Bundle(url: url), let extensionID = extensionBundle.bundleIdentifier,
           extensionID != bundle, extensionID.hasPrefix(bundle + "."),
           let extensionSignature = Self.signature(extensionBundle.executablePath),
           extensionSignature["com.apple.developer.team-identifier"] as? String == team {
            bundles.append(extensionID)
        }
        let id = UUID().uuidString
        defaults.set(true, forKey: key)
        defaults.set(["id": id, "team": team, "bundles": bundles, "expires": Date().addingTimeInterval(300)], forKey: "BloomBoxRAMPlusRequest")
        defaults.set(["id": id, "status": "awaitingSession", "message": "Abre Mis apps en SideStore. Se usará su sesión para solicitar RAM+; si te pide iniciar sesión, hazlo allí.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        defaults.removeObject(forKey: reinstallKey)
        defaults.synchronize()
        refresh()
    }

    func cancelActivation() {
        defaults.removeObject(forKey: "BloomBoxRAMPlusRequest")
        defaults.set(["status": "cancelled", "message": "Solicitud cancelada. Si ya se envió a Apple, el permiso podría haberse aplicado; vuelve a comprobar antes de repetirla.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        defaults.synchronize()
        refresh()
    }

    var needsAttention: Bool { requested && !validation.confirmed }
    var status: String {
        if validation.confirmed { return "RAM+ confirmado en la instalación actual" }
        if validation.profileGranted == true && validation.runtimeGranted != true {
            return "El perfil tiene RAM+, pero la firma instalada no lo confirma"
        }
        if validation.runtimeGranted == true { return "Firma con RAM+; perfil sin confirmar" }
        if activationStatus == "approved" { return "Apple aprobó RAM+; falta reinstalar BloomBox" }
        if activationPending { return "Esperando confirmación de Apple" }
        return requested ? "RAM+ solicitado, aún sin confirmar" : "Permiso no confirmado"
    }

    func setRequested(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
        if !enabled && activationPending { cancelActivation() }
        refresh()
    }

    func refresh() {
        requested = defaults.bool(forKey: key)
        if let plan = defaults.dictionary(forKey: "BloomBoxRAMPlusRequest"),
           let expiry = plan["expires"] as? Date, expiry <= Date(),
           let result = defaults.dictionary(forKey: "BloomBoxRAMPlusResult"),
           let status = result["status"] as? String, ["awaitingSession", "checking", "requesting"].contains(status) {
            defaults.removeObject(forKey: "BloomBoxRAMPlusRequest")
            defaults.set(["status": "expired", "message": "La solicitud venció. Si llegó a enviarse a Apple, su resultado no está confirmado. Puedes iniciar una nueva comprobación.", "date": Date()], forKey: "BloomBoxRAMPlusResult")
        }
        let result = defaults.dictionary(forKey: "BloomBoxRAMPlusResult")
        activationStatus = result?["status"] as? String ?? ""
        activationMessage = result?["message"] as? String ?? ""
        let saved = defaults.dictionary(forKey: reinstallKey) ?? [:]
        reinstallStage = saved["stage"] as? String ?? ""
        reinstallMessage = saved["message"] as? String ?? ""
        if let path = saved["path"] as? String, FileManager.default.fileExists(atPath: path) {
            preparedIPA = URL(fileURLWithPath: path)
        } else { preparedIPA = nil }
        let signed = Self.signature(Bundle.main.executablePath)
        applicationIdentifier = signed?["application-identifier"] as? String ?? ""
        let profileURL = Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision")
        let profile = (try? Data(contentsOf: profileURL)).flatMap(BloomBoxRAMValidation.profile)
        validation = .inspect(runtime: LCUtils.bloomBoxMemoryEntitlement()?.boolValue,
                              profile: profile,
                              applicationIdentifier: applicationIdentifier.isEmpty ? nil : applicationIdentifier)
        let extensionPath = Bundle.main.builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex")
        let extensionBundle = extensionPath.flatMap { Bundle(url: $0) }
        extensionSigned = BloomBoxRAMValidation.boolean(Self.signature(extensionBundle?.executablePath)?[BloomBoxRAMValidation.entitlement])
        available = LCUtils.bloomBoxAvailableMemory()
        checkedAt = Date()
        if validation.confirmed && reinstallStage != "confirmed" && !experimentalReinstall {
            saveReinstall("confirmed", "RAM+ está activa en esta instalación.")
        } else if reinstallStage == "installing" {
            saveReinstall("verifying", "SideStore recibió la solicitud. Cuando termine, vuelve a abrir BloomBox para comprobar la firma.")
        }
    }

    private func saveReinstall(_ stage: String, _ message: String, path: URL? = nil) {
        var value = defaults.dictionary(forKey: reinstallKey) ?? [:]
        value["stage"] = stage
        value["message"] = message
        value["date"] = Date()
        if let path { value["path"] = path.path }
        else if ["checking", "review", "chooseIPA", "failed"].contains(stage) {
            value.removeValue(forKey: "path")
        }
        defaults.set(value, forKey: reinstallKey)
        reinstallStage = stage
        reinstallMessage = message
        preparedIPA = (value["path"] as? String).map { URL(fileURLWithPath: $0) }
    }


    private func prepareIPA(_ source: URL, digest: String?, expectedCommit: String?) throws -> URL {
        let fm = FileManager.default
        let dir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBoxRAMPlus", isDirectory: true)
        try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        let temporary = dir.appendingPathComponent(UUID().uuidString + ".ipa")
        try fm.copyItem(at: source, to: temporary)
        defer { try? fm.removeItem(at: temporary) }
        let handle = try FileHandle(forReadingFrom: temporary)
        defer { try? handle.close() }
        var hash = SHA256()
        while true {
            let data = handle.readData(ofLength: 1024 * 1024)
            if data.isEmpty { break }
            hash.update(data: data)
        }
        let sha = hash.finalize().map { String(format: "%02x", $0) }.joined()
        if let digest, sha.lowercased() != digest.lowercased() {
            throw NSError(domain: "BloomBoxRAM", code: 1, userInfo: [NSLocalizedDescriptionKey: "El SHA-256 descargado no coincide con el publicado."])
        }
        let ipa = try BloomBoxArchive.inspectIPA(temporary)
        guard let bundle = ipa["bundle"] as? String,
              let version = ipa["version"] as? String,
              let build = ipa["build"] as? String else {
            throw NSError(domain: "BloomBoxRAM", code: 2, userInfo: [NSLocalizedDescriptionKey: "No se pudo verificar la estructura de la IPA."])
        }
        let installedID = Bundle.main.bundleIdentifier ?? ""
        let installedExtensions = Set((try? fm.contentsOfDirectory(atPath: Bundle.main.builtInPlugInsURL?.path ?? "")) ?? [])
        let ipaExtensions = Set(ipa["extensions"] as? [String] ?? [])
        // The published release may have a different version/build/commit.
        // The app's internal version is inherited from LiveContainer (3.8.10)
        // and does NOT match BloomBox's public tag (v1.3.0).
        // SideStore reassigns Apple App Groups during signing; exact equality
        // with the *unsigned* IPA is not meaningful and previously blocked updates.
        guard BloomBoxRAMRelease.compatibleIdentity(installed: installedID, sourceBundle: bundle),
              !version.isEmpty, !build.isEmpty,
              BloomBoxRAMRelease.preservesExtensions(installed: installedExtensions, candidate: ipaExtensions),
              expectedCommit == nil || ipa["commit"] as? String == expectedCommit else {
            throw NSError(domain: "BloomBoxRAM", code: 3, userInfo: [NSLocalizedDescriptionKey: "La IPA no conserva la identidad o las extensiones instaladas, o su commit no coincide con la release. No se instalará."])
        }
        let destination = dir.appendingPathComponent("BloomBox-validada.ipa")
        if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
        try fm.moveItem(at: temporary, to: destination)
        var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
        state["sha256"] = sha
        state["version"] = version
        state["build"] = build
        defaults.set(state, forKey: reinstallKey)
        return destination
    }


    /// Uses the newest PUBLIC stable BloomBox release, never an Actions artifact
    /// or a release selected using upstream LiveContainer's internal version.
    /// A different commit needs an explicit second confirmation before downloading.
    func resumeAfterAppleApproval(confirmDifferentBuild: Bool = false) async {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (!validation.confirmed || testing), (requested || testing),
              (activationStatus == "approved" || testing),
              (reinstallStage.isEmpty || ["approved", "review", "chooseIPA"].contains(reinstallStage)) else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        saveReinstall("checking", "Buscando la release estable más reciente de BloomBox…")
        do {
            var req = URLRequest(url: BloomBoxRAMRelease.latestAPI)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 25
            let (body, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BloomBoxRAM", code: 5, userInfo: [NSLocalizedDescriptionKey: "No se pudo consultar la última release oficial de GitHub. Revisa Internet y reintenta."])
            }
            let asset = try BloomBoxRAMRelease.select(json: body)
            let installedCommit = Bundle.main.object(forInfoDictionaryKey: "BloomBoxBuildCommit") as? String ?? ""
            // Comparing to the release commit is only informational here:
            // downloaded IPA contents are independently checked against GitHub's SHA.
            let releaseCommit = asset.commitish ?? ""
            if !confirmDifferentBuild && (releaseCommit.isEmpty || installedCommit != releaseCommit) {
                saveReinstall("review", "Última versión oficial: \(asset.tag). Tu instalación tiene otra compilación (posiblemente JIT experimental). Instalar esta release podría reemplazar funciones experimentales. Revisa y confirma si quieres continuar.")
                return
            }
            saveReinstall("downloading", "Descargando BloomBox \(asset.tag) desde GitHub…")
            let (download, result) = try await URLSession.shared.download(from: asset.url)
            guard (result as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BloomBoxRAM", code: 6, userInfo: [NSLocalizedDescriptionKey: "No se pudo descargar la última IPA desde GitHub."])
            }
            let fileSize = (try FileManager.default.attributesOfItem(atPath: download.path)[.size] as? NSNumber)?.int64Value ?? -1
            guard fileSize == asset.size else {
                throw NSError(domain: "BloomBoxRAM", code: 6, userInfo: [NSLocalizedDescriptionKey: "El tamaño descargado no coincide con la release oficial. No se instalará."])
            }
            saveReinstall("preparing", "Verificando SHA-256, identidad y extensiones de BloomBox \(asset.tag)…")
            let expectedCommit = releaseCommit.count == 40 &&
                releaseCommit.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) })
                ? releaseCommit : nil
            let local = try prepareIPA(download, digest: asset.digest, expectedCommit: expectedCommit)
            var saved = defaults.dictionary(forKey: reinstallKey) ?? [:]
            saved["releaseTag"] = asset.tag
            defaults.set(saved, forKey: reinstallKey)
            saveReinstall("preparing", "BloomBox \(asset.tag) validada. Preparando la actualización con SideStore…", path: local)
            // SideStore's documented remote URL scheme will fetch the official asset
            // again. Its final signed entitlement is always checked after install.
            var link = URLComponents()
            link.scheme = "sidestore"
            link.host = "install"
            link.queryItems = [URLQueryItem(name: "url", value: asset.url.absoluteString)]
            guard let deeplink = link.url else {
                throw NSError(domain: "BloomBoxRAM", code: 7, userInfo: [NSLocalizedDescriptionKey: "No se pudo preparar el enlace de SideStore."])
            }
            saveReinstall("installing", "SideStore instalará BloomBox \(asset.tag) encima de esta app. Conserva extensiones y datos. RAM+ se comprobará después de firmar.")
            UIApplication.shared.open(deeplink, options: [:]) { opened in
                if !opened {
                    Task { @MainActor in
                        self.saveReinstall("failed", "SideStore no pudo abrir la instalación. Comparte la IPA validada o reintenta.")
                    }
                }
            }
        } catch {
            saveReinstall("failed", error.localizedDescription + " No se reemplazó BloomBox.")
        }
    }

    func importIPA(_ source: URL) async {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (activationStatus == "approved" && !validation.confirmed) || testing else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            guard source.pathExtension.lowercased() == "ipa" else {
                throw NSError(domain: "BloomBoxRAM", code: 4, userInfo: [NSLocalizedDescriptionKey: "Elige un archivo .ipa."])
            }
            saveReinstall("checking", "Comprobando la IPA seleccionada…")
            let checked = try prepareIPA(source, digest: nil, expectedCommit: nil)
            saveReinstall("manualReady", "IPA compatible. El origen del archivo no está autenticado: compártelo con SideStore, instala encima sin borrar la app y conserva las extensiones.", path: checked)
        } catch { saveReinstall("chooseIPA", error.localizedDescription) }
    }

    func retryReinstall() {
        let testing = validation.confirmed && experimentalReinstall
        guard !reinstallBusy, (activationStatus == "approved" && !validation.confirmed) || testing else { return }
        saveReinstall("approved", "Buscando de nuevo la última release estable de BloomBox.")
    }

    /// Reopens the existing reinstall controls only. No Apple request, signing,
    /// SideStore launch or file change occurs until the user chooses an action.
    func startExperimentalReinstall() {
        guard validation.confirmed, experimentalControlsEnabled, !reinstallBusy else { return }
        var state = defaults.dictionary(forKey: reinstallKey) ?? [:]
        state["experimental"] = true
        defaults.set(state, forKey: reinstallKey)
        saveReinstall("approved", "Prueba experimental: RAM+ ya está activa. Se comprobará la última release estable, sin repetir la solicitud a Apple.")
    }

    private static func signature(_ path: String?) -> [String: Any]? {
        guard let path, let xml = getExecutableEntitlementXML(path), let data = xml.data(using: .utf8) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }
}

struct BloomBoxRAMPlusView: View {
    let openSideStore: () -> Void
    @ObservedObject private var ram = BloomBoxRAMPlus.shared
    @Environment(\.scenePhase) private var scenePhase
    @State private var showWarning = false
    @State private var activationError: String?
    @State private var chooseOriginalIPA = false
    @AppStorage("BloomBoxRAMPlusExperimentalControls", store: LCUtils.appGroupUserDefault)
    private var experimentalControlsEnabled = false
    private let statusTimer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Label("Memoria ampliada", systemImage: "cpu").font(.title2.bold())
                Toggle("Solicitar RAM+", isOn: Binding(get: { ram.requested }, set: {
                    ram.setRequested($0)
                    showWarning = ram.needsAttention
                }))
                .accessibilityIdentifier("bloombox.modules.ram.activate")
                Label(ram.status, systemImage: ram.validation.confirmed ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(ram.validation.confirmed ? Color.green : Color.orange)
                if ram.needsAttention {
                    Text("El switch está encendido, pero RAM+ todavía no está confirmada. Completa la activación y vuelve a comprobar.")
                        .font(.callout).foregroundStyle(.orange)
                }
                Text("iOS aplica el permiso al firmar e instalar la app. Apagar el switch cancela una solicitud pendiente; no retira un permiso ya instalado.")
                    .font(.footnote).foregroundStyle(.secondary)
                GroupBox("Validaciones de esta instalación") {
                    VStack(alignment: .leading, spacing: 12) {
                        check("Permiso del proceso BloomBox", ram.validation.runtimeGranted)
                        check("Permiso incluido en el perfil", ram.validation.profileGranted)
                        check("Perfil vigente", ram.validation.profileCurrent)
                        check("Perfil corresponde a esta app", ram.validation.profileMatches)
                        check("Firma de LiveProcess", ram.extensionSigned)
                        Text("LiveProcess se comprueba por separado en su firma; esto no confirma su proceso en ejecución ni el permiso de cada app invitada.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 6)
                }
                GroupBox("Activar con la sesión de SideStore") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("BloomBox solicitará Increased Memory Limit para su App ID y para LiveProcess si tiene uno separado. Se conservarán los demás permisos.")
                        Text("SideStore hace el inicio de sesión. BloomBox no guarda tu contraseña ni la sesión de Apple.")
                            .font(.footnote).foregroundStyle(.secondary)
                        if !ram.activationMessage.isEmpty {
                            Label(ram.activationMessage, systemImage: ram.activationStatus == "approved" ? "checkmark.circle" : "info.circle")
                                .font(.callout)
                        }
                        if ram.activationStatus == "awaitingSession" {
                            Text("Esperando una consulta de SideStore a Apple. Abre Mis apps con la misma cuenta que firmó BloomBox. Si la sesión venció, SideStore puede pedir iniciar sesión.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        if ram.activationStatus == "approved" && !ram.validation.confirmed {
                            Text("Apple aprobó el App ID, pero aún falta firmar e instalar exactamente la misma IPA. No se actualizará a otra versión.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if !ram.reinstallStage.isEmpty {
                            Label(ram.reinstallMessage, systemImage: ram.reinstallStage == "confirmed" ? "checkmark.seal.fill" : "arrow.triangle.2.circlepath")
                                .font(.footnote)
                            Text("Etapa: " + ([
                                "checking": "Comprobando",
                                "downloading": "Descargando",
                                "preparing": "Preparando instalación",
                                "installing": "Instalando",
                                "verifying": "Verificando",
                                "chooseIPA": "Falta la IPA original",
                                "manualReady": "Preparada para SideStore",
                                "failed": "Reintento disponible",
                                "confirmed": "Verificada"
                            ][ram.reinstallStage] ?? ram.reinstallStage))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        if ram.reinstallBusy { ProgressView("Preparando reinstalación…") }
                        if ram.activationStatus == "approved" && !ram.validation.confirmed {
                            if !ram.reinstallBusy && (ram.reinstallStage.isEmpty || ram.reinstallStage == "approved" || ram.reinstallStage == "failed" || ram.reinstallStage == "verifying") {
                                Button("Reanudar instalación") {
                                    ram.retryReinstall()
                                    Task { await ram.resumeAfterAppleApproval() }
                                }.buttonStyle(.borderedProminent)
                            }
                            Button("Elegir IPA original") { chooseOriginalIPA = true }
                            if #available(iOS 16.0, *), let file = ram.preparedIPA {
                                ShareLink(item: file) {
                                    Label("Compartir IPA con SideStore", systemImage: "square.and.arrow.up")
                                }
                            }
                            Text("Si SideStore no acepta la entrega automática, guarda la IPA en Archivos, abre SideStore y selecciónala con +. Instálala encima de BloomBox, con todas sus extensiones.")
                                .font(.footnote).foregroundStyle(.secondary)
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if ram.validation.confirmed && experimentalControlsEnabled {
                            Divider()
                            Label("Controles RAM+ habilitados para pruebas", systemImage: "flask.fill")
                                .font(.subheadline.bold())
                            Text("RAM+ ya está activa. Los siguientes botones permiten volver a probar la preparación e instalación de la misma edición SIN volver a pedir el permiso a Apple. Reinstalar puede modificar la firma y perder RAM+ si SideStore no la conserva.")
                                .font(.footnote).foregroundStyle(.orange)
                            Button("Reintentar reinstalación de RAM+ (experimental)") {
                                ram.startExperimentalReinstall()
                                Task { await ram.resumeAfterAppleApproval() }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(ram.reinstallBusy)
                            .accessibilityIdentifier("bloombox.experiments.ramRetryInstall")
                            Button("Elegir IPA original") {
                                ram.startExperimentalReinstall()
                                chooseOriginalIPA = true
                            }
                            .disabled(ram.reinstallBusy)
                            if #available(iOS 16.0, *), let file = ram.preparedIPA {
                                ShareLink(item: file) {
                                    Label("Compartir IPA con SideStore", systemImage: "square.and.arrow.up")
                                }
                            }
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if ram.activationStatus == "uncertain" {
                            Text("No se pudo confirmar la respuesta de Apple después de enviar la solicitud. Comprueba el App ID antes de repetirla para evitar modificaciones duplicadas.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if ram.activationPending {
                            ProgressView("Solicitud en curso…")
                            Button("Volver a SideStore", action: openSideStore)
                            Button("Cancelar solicitud", role: .cancel) { ram.cancelActivation() }
                        } else if ram.activationStatus != "approved" && !ram.validation.confirmed {
                            Button("Activar y reinstalar") { activate() }
                                .buttonStyle(.borderedProminent)
                                .accessibilityIdentifier("bloombox.ram.requestPermission")
                        }
                        Text("La confirmación de Apple y el permiso de esta instalación se validan por separado. Nunca borres BloomBox para aplicar RAM+.")
                        if ram.activationStatus != "approved" {
                            Button("Abrir SideStore", action: openSideStore)
                        }
                        if let activationError { Text(activationError).foregroundStyle(.orange) }
                    }.font(.callout).padding(.vertical, 6)
                }
                DisclosureGroup("Alternativa manual con GetMoreRam") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Si la integración experimental no funciona, usa la misma cuenta Apple en GetMoreRam, selecciona este App ID y pulsa Add Increased Memory Limit. Después reinstala desde SideStore.")
                        Text(Bundle.main.bundleIdentifier ?? "Identificador no disponible")
                            .font(.caption.monospaced()).textSelection(.enabled)
                        Button("Copiar identificador") { UIPasteboard.general.string = Bundle.main.bundleIdentifier }
                        Link("GetMoreRam · instrucciones e instalación", destination: URL(string: "https://github.com/hugeBlack/GetMoreRam")!)
                    }.font(.footnote).padding(.top, 10)
                }
                Button("Comprobar de nuevo") { ram.refresh(); showWarning = ram.needsAttention }
                    .buttonStyle(.bordered)
                if let date = ram.checkedAt {
                    Text("Última comprobación: \(date.formatted(date: .omitted, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Memoria disponible para el proceso ahora: \(ByteCountFormatter.string(fromByteCount: Int64(clamping: ram.available), countStyle: .memory)). Cambia con el uso; no demuestra por sí sola que RAM+ esté activa ni añade RAM física.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding(22)
        }
        .navigationTitle("RAM+")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            ram.refresh()
            showWarning = ram.needsAttention
            Task { await ram.resumeAfterAppleApproval() }
        }
        .onChange(of: scenePhase) {
            if $0 == .active {
                ram.refresh()
                Task { await ram.resumeAfterAppleApproval() }
            }
        }
        .onReceive(statusTimer) { _ in if scenePhase == .active && ram.activationPending { ram.refresh() } }
        .fileImporter(isPresented: $chooseOriginalIPA, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let files):
                if let file = files.first { Task { await ram.importIPA(file) } }
            case .failure(let error):
                activationError = error.localizedDescription
            }
        }
        .alert("RAM+ aún no está confirmada", isPresented: $showWarning) {
            Button("Activar con SideStore") { activate() }
            Button("Después", role: .cancel) { }
        } message: {
            Text("El switch está encendido, pero esta instalación no supera las validaciones. Solicita el permiso con SideStore y reinstala BloomBox. Encender el switch no aumenta la memoria por sí solo.")
        }
    }

    private func activate() {
        do {
            activationError = nil
            try ram.requestActivation()
            openSideStore()
        } catch {
            activationError = error.localizedDescription
        }
    }

    private func check(_ title: String, _ value: Bool?) -> some View {
        HStack {
            Image(systemName: value == true ? "checkmark.circle.fill" : (value == false ? "xmark.circle" : "questionmark.circle"))
                .foregroundStyle(value == true ? Color.green : Color.orange)
            Text(title)
            Spacer()
            Text(value.map { $0 ? "Sí" : "No" } ?? "Sin confirmar").font(.caption)
        }.font(.footnote)
    }
}
