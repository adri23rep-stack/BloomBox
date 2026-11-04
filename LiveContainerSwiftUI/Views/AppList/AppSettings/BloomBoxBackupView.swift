import SwiftUI
import UniformTypeIdentifiers

struct BloomBoxBackupView: View {
    @ObservedObject var model: LCAppModel
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var busy = false
    @State private var status = ""
    @State private var exportWarning = false
    @State private var choosingBackup = false
    @State private var sharing = false
    @State private var exportURL: URL?
    @State private var prepared: BloomBoxAppBackup.Prepared?
    @State private var notice: String?

    var body: some View {
        Form {
            Section {
                Text(model.displayName).font(.headline)
                Text("Guarda archivos, ajustes y partidas de todos los perfiles de esta app. Instala primero la misma app en BloomBox para restaurar la copia.")
                    .font(.footnote).foregroundStyle(.secondary)
                Button { exportWarning = true } label: {
                    Label("Exportar datos de la app", systemImage: "square.and.arrow.up")
                }.disabled(busy || model.uiContainers.isEmpty || model.isAppRunning || model.isSigningInProgress)
                Button { choosingBackup = true } label: {
                    Label("Importar copia de datos", systemImage: "square.and.arrow.down")
                }.disabled(busy || model.isAppRunning || model.isSigningInProgress)
            }
            if busy {
                Section { HStack { ProgressView(); Text(status) } }
            }
            if let prepared {
                Section("Copia lista para restaurar") {
                    Text("\(prepared.manifest.profiles.count) perfiles · versión \(prepared.manifest.appVersion)")
                    Text(prepared.manifest.created, style: .date)
                    Text("Se crearán perfiles nuevos y se activará el principal de la copia. Tus perfiles actuales se conservarán. Los datos compartidos recuperados quedarán separados de otras apps.")
                        .font(.footnote)
                    ForEach(prepared.manifest.warnings, id: \.self) { Text($0).font(.footnote).foregroundStyle(.secondary) }
                    Button("Restaurar esta copia") { Task { await restoreBackup() } }.disabled(busy)
                    Button("Cancelar", role: .cancel) { clearPrepared() }.disabled(busy)
                }
            }
            Section("Qué se puede recuperar") {
                Text("Incluye los datos locales, grupos compartidos identificables y credenciales accesibles. iCloud, compras, claves protegidas, archivos externos y sesiones que dependan de un servidor pueden requerir recuperación o inicio de sesión aparte.")
                Text("Cierra la app y otras apps que compartan sus datos antes de exportar o importar. Mantén BloomBox abierto hasta terminar.")
                Text("La copia contiene información privada y no lleva contraseña. Guárdala en un lugar seguro.")
            }.font(.footnote).foregroundStyle(.secondary)
        }
        .navigationTitle("Copia de datos")
        .navigationBarBackButtonHidden(busy)
        .interactiveDismissDisabled(busy)
        .alert("Exportar información privada", isPresented: $exportWarning) {
            Button("Exportar") { Task { await exportBackup() } }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("La copia incluirá archivos y credenciales que BloomBox pueda leer. No tiene contraseña. Compártela únicamente con personas de confianza.")
        }
        .alert("Copia de datos", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
            Button("Aceptar", role: .cancel) { notice = nil }
        } message: { Text(notice ?? "") }
        .fileImporter(isPresented: $choosingBackup, allowedContentTypes: [.data, .zip]) { result in
            switch result {
            case .success(let url): Task { await prepareBackup(url) }
            case .failure(let error): notice = error.localizedDescription
            }
        }
        .sheet(isPresented: $sharing, onDismiss: clearExport) {
            if let exportURL { ActivityViewController(activityItems: [exportURL]) }
        }
        .onDisappear {
            if !busy && !sharing { clearPrepared(); clearExport() }
        }
    }
    @MainActor private func begin(_ message: String) throws {
        try BloomBoxAppBackup.require(!busy && !model.isDataBackupInProgress && !model.isAppRunning && !model.isSigningInProgress,
                                       "Cierra la app y espera a que terminen sus operaciones.")
        for container in model.uiContainers {
            try BloomBoxAppBackup.require(LCSharedUtils.getContainerUsingLCScheme(withFolderName: container.folderName) == nil,
                                           "Cierra todos los perfiles de la app antes de continuar.")
            try BloomBoxAppBackup.require(container.storageBookMark == nil || container.resolvedContainerURL != nil,
                                           "Un perfil externo no está disponible. Reconecta su ubicación antes de continuar.")
        }
        busy = true
        model.isDataBackupInProgress = true
        status = message
    }
    @MainActor private func end() { busy = false; model.isDataBackupInProgress = false }
    @MainActor private func exportBackup() async {
        do { try begin("Preparando copia…") } catch { notice = error.localizedDescription; return }
        defer { end() }
        do {
            clearExport()
            let sources = model.uiContainers.map { container -> BloomBoxAppBackup.Source in
                container.loadName()
                return .init(url: container.containerURL, folder: container.folderName,
                             profile: .init(name: container.name, isolatedGroups: container.isolateAppGroup,
                                            spoofIDFV: container.spoofIdentifierForVendor, idfv: container.spoofedIdentifier))
            }
            let bundle = Bundle(path: model.appInfo.bundlePath())
            let request = BloomBoxAppBackup.ExportRequest(bundleID: model.bundleIdentifier,
                appVersion: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Desconocida",
                executable: bundle?.executablePath, sources: sources,
                defaultProfile: model.uiContainers.firstIndex { $0.folderName == model.uiDefaultDataFolder } ?? 0,
                groupRoot: LCSharedUtils.appGroupPath() == nil ? LCPath.appGroupPath : LCPath.lcGroupAppGroupPath)
            exportURL = try await Task.detached(priority: .utility) { try BloomBoxAppBackup.export(request) }.value
            sharing = true
        } catch { notice = error.localizedDescription }
    }
    @MainActor private func prepareBackup(_ url: URL) async {
        do { try begin("Revisando copia…") } catch { notice = error.localizedDescription; return }
        defer { end() }
        do {
            clearPrepared()
            let bundleID = model.bundleIdentifier
            let capacity = freeGroups().count
            prepared = try await Task.detached(priority: .utility) {
                try BloomBoxAppBackup.prepare(url, bundleID: bundleID, capacity: capacity)
            }.value
        } catch { notice = error.localizedDescription }
    }
    @MainActor private func restoreBackup() async {
        guard let prepared else { return }
        do { try begin("Restaurando datos…") } catch { notice = error.localizedDescription; return }
        defer { end(); clearPrepared() }
        do {
            let groups = Array(freeGroups().prefix(prepared.manifest.profiles.count))
            try BloomBoxAppBackup.require(groups.count == prepared.manifest.profiles.count, "No quedan suficientes perfiles libres.")
            let root = model.uiIsShared ? LCPath.lcGroupDataPath : LCPath.dataPath
            let teamID = LCSharedUtils.teamIdentifier() ?? ""
            let result = try await Task.detached(priority: .utility) {
                try BloomBoxAppBackup.restore(prepared, dataRoot: root, groupIDs: groups, teamID: teamID)
            }.value
            let containers = zip(result.folders, result.profiles).map { folder, profile in
                let container = LCContainer(folderName: folder, name: profile.name, isShared: model.uiIsShared)
                container.loadName()
                return container
            }
            model.uiContainers.append(contentsOf: containers)
            model.appInfo.containers = model.uiContainers
            let selected = containers[result.defaultProfile]
            model.uiDefaultDataFolder = selected.folderName
            model.appInfo.dataUUID = selected.folderName
            model.uiSelectedContainer = selected
            if !model.uiIsShared { sharedModel.appDataFolderNames.append(contentsOf: result.folders) }
            notice = "Datos restaurados. El perfil recuperado ya está seleccionado. Tus perfiles anteriores siguen disponibles en Ajustes de la app.\n\n" + result.warnings.joined(separator: "\n\n")
        } catch { notice = error.localizedDescription }
    }
    private func freeGroups() -> [Int] {
        let used = Set(model.uiContainers.map(\.keychainGroupId))
        return (0..<SharedModel.keychainAccessGroupCount).filter { !used.contains($0) }
    }
    private func clearPrepared() {
        if let prepared { BloomBoxAppBackup.removeWorkspace(prepared.root) }
        prepared = nil
    }
    private func clearExport() {
        if let exportURL { BloomBoxAppBackup.removeWorkspace(exportURL.deletingLastPathComponent()) }
        exportURL = nil
    }
}
