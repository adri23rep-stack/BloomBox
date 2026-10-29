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

    var needsAttention: Bool { requested && !validation.confirmed }
    var status: String {
        if validation.confirmed { return "Permiso confirmado en BloomBox" }
        if validation.runtimeGranted == true { return "Permiso presente; perfil sin confirmar" }
        return requested ? "Pendiente de activación" : "Permiso no confirmado"
    }

    func setRequested(_ enabled: Bool) {
        defaults.set(enabled, forKey: key)
        refresh()
    }

    func refresh() {
        requested = defaults.bool(forKey: key)
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
                Text("El switch guarda tu solicitud. iOS aplica el permiso al firmar e instalar la app; apagarlo no retira un permiso ya instalado.")
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
                GroupBox("Completar activación") {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("1. En GetMoreRam, inicia sesión con la cuenta usada para instalar BloomBox. En App IDs, selecciona el identificador de abajo y pulsa Add Increased Memory Limit.")
                        Text(Bundle.main.bundleIdentifier ?? "Identificador no disponible")
                            .font(.caption.monospaced()).textSelection(.enabled)
                        Button("Copiar identificador") { UIPasteboard.general.string = Bundle.main.bundleIdentifier }
                        Link("Abrir GetMoreRam · instrucciones e instalación", destination: URL(string: "https://github.com/hugeBlack/GetMoreRam")!)
                        Text("2. Reinstala BloomBox con SideStore conservando sus extensiones. No borres la app: conserva sus datos. Si LiveProcess tiene un App ID separado, habilita también su permiso.")
                        Button("Abrir SideStore", action: openSideStore).buttonStyle(.borderedProminent)
                        Text("3. Abre de nuevo BloomBox y comprueba el resultado. Si la firma perdió el permiso, el aviso seguirá visible.")
                        Text("La solicitud a Apple se realiza en GetMoreRam. Esta pantalla no inicia sesión ni importa las credenciales de SideStore.")
                            .font(.caption).foregroundStyle(.secondary)
                    }.font(.callout).padding(.vertical, 6)
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
        .alert("RAM+ aún no está confirmada", isPresented: $showWarning) {
            Button("Entendido", role: .cancel) { }
        } message: {
            Text("El switch está encendido, pero esta instalación no supera las validaciones. Habilita el permiso con GetMoreRam y reinstala desde SideStore. Encender el switch no aumenta la memoria por sí solo.")
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
