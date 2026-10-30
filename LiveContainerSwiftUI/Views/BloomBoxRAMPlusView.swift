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
        if validation.confirmed && reinstallStage != "confirmed" {
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
        defaults.set(value, forKey: reinstallKey)
        reinstallStage = stage
        reinstallMessage = message
        if let path { preparedIPA = path }
    }


    private func prepareIPA(_ source: URL, digest: String?, commit: String?) throws -> URL {
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
        let installedVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let installedBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? ""
        let installedExtensions = Set((try? fm.contentsOfDirectory(atPath: Bundle.main.builtInPlugInsURL?.path ?? "")) ?? [])
        let ipaExtensions = Set(ipa["extensions"] as? [String] ?? [])
        let installedGroups = Set(Bundle.main.infoDictionary?["ALTAppGroups"] as? [String] ?? [])
        let ipaGroups = Set(ipa["groups"] as? [String] ?? [])
        guard (installedID == bundle || installedID.hasPrefix(bundle + ".")),
              version == installedVersion && build == installedBuild,
              !installedExtensions.isEmpty && installedExtensions == ipaExtensions,
              installedGroups == ipaGroups,
              commit == nil || ipa["commit"] as? String == commit else {
            throw NSError(domain: "BloomBoxRAM", code: 3, userInfo: [NSLocalizedDescriptionKey: "La IPA no coincide con la identidad, versión, build, extensiones, App Groups o commit actual. No se instalará."])
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


    /// Runs once after Apple readback. Never changes version without explicit choice.
    func resumeAfterAppleApproval() async {
        guard !reinstallBusy, !validation.confirmed, requested,
              activationStatus == "approved", reinstallStage.isEmpty || reinstallStage == "approved" else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        saveReinstall("checking", "Comprobando origen y versión de la IPA…")
        do {
            guard let commit = Bundle.main.object(forInfoDictionaryKey: "BloomBoxBuildCommit") as? String,
                  commit.count == 40 else {
                saveReinstall("chooseIPA", "Esta edición experimental no identifica su compilación exacta. Selecciona su IPA original; no se instalará otra versión.")
                return
            }
            let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
            let endpoint = URL(string: "https://api.github.com/repos/adri23rep-stack/BloomBox/releases?per_page=30")!
            var req = URLRequest(url: endpoint)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 25
            let (body, response) = try await URLSession.shared.data(for: req)
            guard (response as? HTTPURLResponse)?.statusCode == 200,
                  let releases = try JSONSerialization.jsonObject(with: body) as? [[String: Any]] else {
                throw NSError(domain: "BloomBoxRAM", code: 5, userInfo: [NSLocalizedDescriptionKey: "GitHub no respondió con una lista válida de IPAs."])
            }
            let assets = releases.filter {
                ($0["draft"] as? Bool) == false && ($0["tag_name"] as? String) == "v" + version
            }.flatMap { $0["assets"] as? [[String: Any]] ?? [] }.filter {
                ($0["name"] as? String) == "BloomBox-SideStore-unsigned.ipa"
            }
            guard assets.count == 1, let asset = assets.first,
                  let sha = asset["digest"] as? String, sha.hasPrefix("sha256:"), sha.count == 71,
                  let location = asset["browser_download_url"] as? String,
                  let url = URL(string: location), url.scheme == "https",
                  url.host == "github.com",
                  url.path.hasPrefix("/adri23rep-stack/BloomBox/releases/download/"),
                  let size = asset["size"] as? Int, size > 0, size < 1024 * 1024 * 1024 else {
                saveReinstall("chooseIPA", "No se encontró una IPA pública oficial con versión y SHA-256 verificables. Elige tu IPA original o actualiza por separado.")
                return
            }
            saveReinstall("downloading", "Descargando la misma versión y variante desde GitHub…")
            let (download, result) = try await URLSession.shared.download(from: url)
            guard (result as? HTTPURLResponse)?.statusCode == 200 else {
                throw NSError(domain: "BloomBoxRAM", code: 6, userInfo: [NSLocalizedDescriptionKey: "No se pudo descargar la IPA exacta de GitHub."])
            }
            saveReinstall("preparing", "Revisando estructura e integridad de la IPA…")
            let local = try prepareIPA(download, digest: String(sha.dropFirst(7)), commit: commit)
            saveReinstall("preparing", "IPA exacta validada. Preparando SideStore…", path: local)
            // Official SideStore URI, forwarded by LCTabView / LCAppListView
            // to the bundled SideStore. The OS may terminate the host.
            var link = URLComponents()
            link.scheme = "sidestore"
            link.host = "install"
            link.queryItems = [URLQueryItem(name: "url", value: url.absoluteString)]
            guard let deeplink = link.url else {
                throw NSError(domain: "BloomBoxRAM", code: 7, userInfo: [NSLocalizedDescriptionKey: "No se pudo preparar el enlace de SideStore."])
            }
            saveReinstall("installing", "SideStore está recibiendo la IPA para firmar e instalar encima. Confirma cualquier aviso de iOS y conserva las extensiones.")
            UIApplication.shared.open(deeplink, options: [:]) { opened in
                if !opened {
                    Task { @MainActor in
                        self.saveReinstall("failed", "SideStore no pudo abrir la instalación. Comparte la IPA guardada o reintenta.")
                    }
                }
            }
        } catch {
            saveReinstall("failed", error.localizedDescription + " No se reemplazó BloomBox.")
        }
    }

    func importIPA(_ source: URL) async {
        guard !reinstallBusy, activationStatus == "approved", !validation.confirmed else { return }
        reinstallBusy = true
        defer { reinstallBusy = false }
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        do {
            guard source.pathExtension.lowercased() == "ipa" else {
                throw NSError(domain: "BloomBoxRAM", code: 4, userInfo: [NSLocalizedDescriptionKey: "Elige un archivo .ipa."])
            }
            saveReinstall("checking", "Comprobando la IPA seleccionada…")
            let checked = try prepareIPA(source, digest: nil, commit: nil)
            saveReinstall("manualReady", "IPA compatible. El origen del archivo no está autenticado: compártelo con SideStore, instala encima sin borrar la app y conserva las extensiones.", path: checked)
        } catch { saveReinstall("chooseIPA", error.localizedDescription) }
    }

    func retryReinstall() {
        guard !reinstallBusy, activationStatus == "approved" && !validation.confirmed else { return }
        saveReinstall("approved", "Buscando de nuevo la IPA de esta compilación.")
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


// MARK: - Simulación segura de reinstalación (solo lectura)
//
// No utiliza requestActivation(), resumeAfterAppleApproval(), prepareIPA(),
// UserDefaults.set, UIApplication.open ni el instalador de SideStore.
// Una prevalidación correcta NO garantiza que SideStore firme/reinstale con éxito.
private struct BloomBoxRAMDryRunCheck: Identifiable, Sendable {
    enum State: Equatable, Sendable { case pass, warning, blocked }
    let id: String
    let detail: String
    let state: State
}

private struct BloomBoxRAMDryRunExpected: Sendable {
    let bundleID: String
    let version: String
    let build: String
    let commit: String?
    let extensions: Set<String>
    let appGroups: Set<String>

    static func current() -> Self {
        let info = Bundle.main.infoDictionary ?? [:]
        let extPath = Bundle.main.builtInPlugInsURL?.path ?? ""
        let ext = Set((try? FileManager.default.contentsOfDirectory(atPath: extPath)) ?? [])
        return Self(
            bundleID: Bundle.main.bundleIdentifier ?? "",
            version: info["CFBundleShortVersionString"] as? String ?? "",
            build: info["CFBundleVersion"] as? String ?? "",
            commit: info["BloomBoxBuildCommit"] as? String,
            extensions: ext,
            appGroups: Set(info["ALTAppGroups"] as? [String] ?? [])
        )
    }
}

private struct BloomBoxRAMDryRunIPA: Sendable {
    let fileName: String
    let checksum: String
    let checks: [BloomBoxRAMDryRunCheck]
    var compatible: Bool { !checks.contains { $0.state == .blocked } }

    static func inspect(_ url: URL, expected: BloomBoxRAMDryRunExpected) throws -> Self {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard url.pathExtension.lowercased() == "ipa" else {
            throw NSError(domain: "BloomBoxRAMDryRun", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Selecciona una IPA original (.ipa)."])
        }

        // Validación del archivo real: no copiar, extraer, firmar ni instalar.
        let ipa = try BloomBoxArchive.inspectIPA(url)
        let bundle = ipa["bundle"] as? String ?? ""
        let version = ipa["version"] as? String ?? ""
        let build = ipa["build"] as? String ?? ""
        let commit = ipa["commit"] as? String
        let extensions = Set(ipa["extensions"] as? [String] ?? [])
        let groups = Set(ipa["groups"] as? [String] ?? [])

        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var sha = SHA256()
        while true {
            let bytes = handle.readData(ofLength: 1024 * 1024)
            if bytes.isEmpty { break }
            sha.update(data: bytes)
        }
        let checksum = sha.finalize().map { String(format: "%02x", $0) }.joined()
        func check(_ id: String, _ passed: Bool, _ detail: String) -> BloomBoxRAMDryRunCheck {
            .init(id: id, detail: detail, state: passed ? .pass : .blocked)
        }
        let matchingID = !bundle.isEmpty &&
            (bundle == expected.bundleID || expected.bundleID.hasPrefix(bundle + "."))
        let matchingVersion = !version.isEmpty && !build.isEmpty &&
            version == expected.version && build == expected.build
        let matchingExtensions = !expected.extensions.isEmpty && extensions == expected.extensions
        let matchingGroups = groups == expected.appGroups
        let matchingCommit = expected.commit.map { !($0.isEmpty) && commit == $0 } ?? true
        return .init(fileName: url.lastPathComponent, checksum: checksum, checks: [
            check("Identidad de BloomBox", matchingID,
                  "IPA: \(bundle.isEmpty ? "desconocida" : bundle); instalada: \(expected.bundleID)"),
            check("Versión y compilación", matchingVersion,
                  "IPA: \(version) (\(build)); instalada: \(expected.version) (\(expected.build))"),
            check("Extensiones", matchingExtensions,
                  "IPA: \(extensions.count); instaladas: \(expected.extensions.count); deben coincidir exactamente."),
            check("App Groups declarados", matchingGroups,
                  "Coincidencia: \(matchingGroups ? "sí" : "no"). Se validan los metadatos, no la firma final."),
            check("Commit de compilación", matchingCommit,
                  expected.commit == nil ? "La instalación actual no declara commit: no se puede contrastar." :
                  (matchingCommit ? "Coincide con la edición instalada." : "Diferente o ausente; no es la misma compilación."))
        ])
    }
}

struct BloomBoxRAMReinstallSimulationView: View {
    @State private var checks: [BloomBoxRAMDryRunCheck] = []
    @State private var preview: BloomBoxRAMDryRunIPA?
    @State private var showImporter = false
    @State private var scanning = false
    @State private var scanError: String?
    @State private var lastRun: Date?

    private var blocked: Bool {
        checks.contains { $0.state == .blocked }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 17) {
                Label("Simulación de reinstalación RAM+", systemImage: "checkmark.shield")
                    .font(.title2.bold())
                Text("Prueba de diagnóstico segura. No pide permisos a Apple, no descarga ni instala nada, no abre SideStore y no modifica RAM+, la firma o tus datos.")
                    .font(.callout).foregroundStyle(.secondary)

                Button {
                    runDryRun()
                } label: {
                    Label("Ejecutar simulación", systemImage: "play.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(scanning)
                .accessibilityIdentifier("bloombox.experiments.ramDryRun.start")

                Button {
                    showImporter = true
                } label: {
                    Label("Examinar IPA original (opcional)", systemImage: "doc.zipper")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(scanning)
                .accessibilityIdentifier("bloombox.experiments.ramDryRun.selectIPA")

                if scanning { ProgressView("Analizando IPA sin modificarla…") }
                if let scanError {
                    Label(scanError, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.footnote)
                }
                if let preview {
                    GroupBox("IPA examinada") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(preview.fileName).font(.subheadline.bold())
                            Text("SHA-256: " + preview.checksum)
                                .font(.caption.monospaced())
                                .textSelection(.enabled)
                            Text("Este hash identifica el archivo local; no autentica por sí solo su origen.")
                                .font(.caption).foregroundStyle(.secondary)
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                if let lastRun {
                    GroupBox("Informe de prevalidación") {
                        VStack(alignment: .leading, spacing: 15) {
                            ForEach(checks) { row in
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: symbol(for: row.state))
                                        .foregroundStyle(tint(for: row.state))
                                        .frame(width: 20)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(row.id).font(.subheadline.bold())
                                        Text(row.detail).font(.footnote).foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                    }
                    Label(blocked ? "Hay incompatibilidades: no se recomienda reinstalar." :
                          (preview == nil ? "Prevalidación parcial: falta revisar una IPA." :
                           "Prevalidación local completada; la reinstalación real no se ha probado."),
                          systemImage: blocked ? "xmark.shield" : "info.circle")
                        .foregroundStyle(blocked ? Color.orange : Color.secondary)
                        .font(.callout)
                    Text("Comprobado: \(lastRun.formatted(date: .abbreviated, time: .standard))")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Límite de la prueba: la firma nueva, la respuesta de Apple, el enlace externo, el instalador de SideStore y la conservación de los datos tras reemplazar la app solo pueden confirmarse en una reinstalación real. Ninguno se ejecuta aquí.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
            .padding(22)
        }
        .navigationTitle("Simulación RAM+")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { if lastRun == nil { runDryRun() } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let files):
                guard let url = files.first else { return }
                scanning = true
                scanError = nil
                let expected = BloomBoxRAMDryRunExpected.current()
                Task {
                    do {
                        let inspected = try await Task.detached(priority: .userInitiated) {
                            try BloomBoxRAMDryRunIPA.inspect(url, expected: expected)
                        }.value
                        preview = inspected
                    } catch {
                        preview = nil
                        scanError = error.localizedDescription
                    }
                    scanning = false
                    runDryRun()
                }
            case .failure(let error):
                preview = nil
                scanError = error.localizedDescription
                runDryRun()
            }
        }
    }

    private func runDryRun() {
        let expected = BloomBoxRAMDryRunExpected.current()
        let xml = Bundle.main.executablePath.flatMap(getExecutableEntitlementXML)
        let entitlements = xml?.data(using: .utf8).flatMap {
            (try? PropertyListSerialization.propertyList(from: $0, options: [], format: nil)) as? [String: Any]
        }
        let applicationID = entitlements?["application-identifier"] as? String
        let profileURL = Bundle.main.bundleURL.appendingPathComponent("embedded.mobileprovision")
        let profile = (try? Data(contentsOf: profileURL)).flatMap(BloomBoxRAMValidation.profile)
        let validated = BloomBoxRAMValidation.inspect(
            runtime: LCUtils.bloomBoxMemoryEntitlement()?.boolValue,
            profile: profile, applicationIdentifier: applicationID
        )
        let sideStorePresent = Bundle.main.privateFrameworksURL.map {
            FileManager.default.fileExists(atPath: $0.appendingPathComponent("SideStoreApp.framework").path)
        } == true
        var deeplink = URLComponents()
        deeplink.scheme = "sidestore"
        deeplink.host = "install"
        deeplink.queryItems = [URLQueryItem(name: "url", value: "https://github.com/adri23rep-stack/BloomBox")]
        let canConstructLink = deeplink.url != nil

        var results: [BloomBoxRAMDryRunCheck] = [
            .init(id: "RAM+ de la instalación actual",
                  detail: validated.confirmed ? "Ya está confirmada; no se cambiará." :
                    "No está completamente confirmada. La simulación NO solicita ni activa el permiso.",
                  state: validated.confirmed ? .pass : .warning),
            .init(id: "Identidad instalada",
                  detail: "\(expected.bundleID) · \(expected.version) (\(expected.build))",
                  state: !expected.bundleID.isEmpty && !expected.version.isEmpty && !expected.build.isEmpty ? .pass : .blocked),
            .init(id: "Extensiones y grupo",
                  detail: "\(expected.extensions.count) extensiones; \(expected.appGroups.count) App Groups declarados.",
                  state: expected.extensions.contains("LiveProcess.appex") ? .pass : .blocked),
            .init(id: "SideStore integrado",
                  detail: sideStorePresent ? "El framework existe. No se inicia sesión ni se intenta firmar." :
                    "No se encontró SideStoreApp.framework dentro de BloomBox.",
                  state: sideStorePresent ? .pass : .blocked),
            .init(id: "Enlace de instalación",
                  detail: canConstructLink ? "El formato sidestore://install puede construirse. NO se abre ni se comprueba recepción." :
                    "No pudo componerse un enlace válido.",
                  state: canConstructLink ? .pass : .blocked),
            .init(id: "Descarga y autenticidad remota",
                  detail: "No se descargan datos. Esta prueba no confirma si GitHub ofrece una IPA de esta compilación.",
                  state: .warning)
        ]
        if let preview {
            results.append(contentsOf: preview.checks)
            results.append(.init(id: "Integridad del archivo local",
                                 detail: "ZIP analizado y SHA-256 calculado en modo lectura; no se compara con un hash publicado.",
                                 state: .warning))
        } else {
            results.append(.init(id: "Comparación de IPA",
                                 detail: "Pendiente: selecciona la IPA original para comparar identidad, versión, build, extensiones y App Groups.",
                                 state: .warning))
        }
        results.append(.init(id: "Firma, reemplazo y datos",
                             detail: "No ejecutados. RAM+, ajustes, sesión Apple y archivos existentes permanecen intactos.",
                             state: .warning))
        checks = results
        lastRun = Date()
    }

    private func symbol(for status: BloomBoxRAMDryRunCheck.State) -> String {
        switch status {
        case .pass: return "checkmark.circle.fill"
        case .warning: return "info.circle"
        case .blocked: return "xmark.circle.fill"
        }
    }

    private func tint(for status: BloomBoxRAMDryRunCheck.State) -> Color {
        switch status {
        case .pass: return .green
        case .warning: return .orange
        case .blocked: return .red
        }
    }
}
