import SwiftUI

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
                            Text("Apple aprobó el App ID, pero eso NO confirma la firma instalada. Vuelve a instalar la IPA con SideStore, conservando las extensiones; un simple refresco puede mantener el perfil anterior.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if ram.activationStatus == "uncertain" {
                            Text("No se pudo confirmar la respuesta de Apple después de enviar la solicitud. Comprueba el App ID antes de repetirla para evitar modificaciones duplicadas.")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                        if ram.activationPending {
                            ProgressView("Solicitud en curso…")
                            Button("Volver a SideStore", action: openSideStore)
                            Button("Cancelar solicitud", role: .cancel) { ram.cancelActivation() }
                        } else {
                            Button("Solicitar permiso con SideStore") { activate() }
                                .buttonStyle(.borderedProminent)
                                .disabled(ram.validation.confirmed)
                                .accessibilityIdentifier("bloombox.ram.requestPermission")
                        }
                        Text("Cuando Apple lo confirme, reinstala BloomBox desde SideStore conservando las extensiones y sin borrar la app. Vuelve aquí para verificar que la firma instalada incluye el permiso.")
                        Button("Abrir SideStore para reinstalar", action: openSideStore)
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
        .onAppear { ram.refresh(); showWarning = ram.needsAttention }
        .onChange(of: scenePhase) { if $0 == .active { ram.refresh() } }
        .onReceive(statusTimer) { _ in if scenePhase == .active && ram.activationPending { ram.refresh() } }
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
