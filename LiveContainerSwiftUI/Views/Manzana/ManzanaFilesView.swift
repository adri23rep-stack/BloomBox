import SwiftUI
import UniformTypeIdentifiers
import QuickLook

@MainActor
final class ManzanaFilesModel: ObservableObject {
    @Published var entries: [URL] = []
    @Published var folder: URL?
    @Published var error: String?
    @Published var busy = false
    private(set) var store: ManzanaFileStore?
    init() {
        do {
            let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let store = try ManzanaFileStore(root: documents.appendingPathComponent("Manzana Files", isDirectory: true))
            self.store = store
            folder = store.root
            reload()
        } catch { self.error = error.localizedDescription }
    }
    var isTrash: Bool { folder?.lastPathComponent == ".Trash" }
    func reload() {
        guard let store, let folder else { return }
        do { entries = try store.contents(folder) } catch { self.error = error.localizedDescription }
    }
    func run(_ action: (ManzanaFileStore) throws -> Void) {
        guard let store else { return }
        do { try action(store); reload() } catch { self.error = error.localizedDescription }
    }
    func open(_ url: URL) {
        guard let store else { return }
        do { folder = try store.checked(url); reload() } catch { self.error = error.localizedDescription }
    }
    func importFiles(_ urls: [URL]) {
        guard let store, let folder, !busy else { return }
        busy = true
        Task {
            let failures = await Task.detached(priority: .userInitiated) {
                var failures: [String] = []
                for url in urls {
                    let access = url.startAccessingSecurityScopedResource()
                    defer { if access { url.stopAccessingSecurityScopedResource() } }
                    var coordinationError: NSError?
                    NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { readable in
                        do { try store.importFile(readable, into: folder) }
                        catch { failures.append("\(url.lastPathComponent): \(error.localizedDescription)") }
                    }
                    if let coordinationError { failures.append(coordinationError.localizedDescription) }
                }
                return failures
            }.value
            busy = false
            reload()
            if !failures.isEmpty { error = failures.joined(separator: "\n") }
        }
    }
}

struct ManzanaFileSelection: Identifiable { let id = UUID(); let url: URL }

struct ManzanaFilesView: View {
    @StateObject private var model = ManzanaFilesModel()
    @Environment(\.dismiss) private var dismiss
    @State private var importing = false
    @State private var newFolder = false
    @State private var name = ""
    @State private var renaming: URL?
    @State private var preview: ManzanaFileSelection?
    @State private var sharing: ManzanaFileSelection?
    @State private var search = ""

    var body: some View {
        NavigationView {
            List {
                if model.busy { ProgressView("Importando archivos…") }
                if model.entries.isEmpty && !model.busy {
                    Text(model.isTrash ? "La papelera está vacía." : "Importa documentos o crea tu primera carpeta.").foregroundStyle(.secondary)
                }
                ForEach(model.entries.filter { search.isEmpty || $0.lastPathComponent.localizedCaseInsensitiveContains(search) }, id: \.path) { url in
                    fileRow(url)
                }
            }
            .disabled(model.busy)
            .searchable(text: $search, prompt: "Buscar en esta carpeta")
            .navigationTitle(model.isTrash ? "Papelera" : (model.folder == model.store?.root ? "Archivos" : model.folder?.lastPathComponent ?? "Archivos"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let folder = model.folder, folder != model.store?.root {
                        Button { search = ""; model.open(folder.deletingLastPathComponent()) } label: { Label("Volver", systemImage: "chevron.left") }.disabled(model.busy)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) { Button("Inicio") { dismiss() }.disabled(model.busy) }
                ToolbarItemGroup(placement: .bottomBar) {
                    if !model.isTrash {
                        Button { importing = true } label: { Label("Importar", systemImage: "square.and.arrow.down") }.disabled(model.busy)
                        Spacer()
                        Button { name = ""; newFolder = true } label: { Label("Carpeta", systemImage: "folder.badge.plus") }.disabled(model.busy)
                        Spacer()
                        Button {
                            model.run { store in model.open(try store.trashFolder()) }
                        } label: { Label("Papelera", systemImage: "trash") }.disabled(model.busy)
                    } else { Text("Los archivos se restauran en la carpeta principal.").font(.caption) }
                }
            }
        }
        .navigationViewStyle(.stack)
        .interactiveDismissDisabled(model.busy)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls): model.importFiles(urls)
            case .failure(let error): model.error = error.localizedDescription
            }
        }
        .alert("Nueva carpeta", isPresented: $newFolder) {
            TextField("Nombre", text: $name)
            Button("Crear") { if let folder = model.folder { model.run { try $0.createFolder(name, in: folder) } } }
            Button("Cancelar", role: .cancel) {}
        }
        .alert("Renombrar", isPresented: Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })) {
            TextField("Nombre", text: $name)
            Button("Guardar") { if let url = renaming { model.run { try $0.rename(url, to: name) } }; renaming = nil }
            Button("Cancelar", role: .cancel) { renaming = nil }
        }
        .alert("Archivos", isPresented: Binding(get: { model.error != nil }, set: { if !$0 { model.error = nil } })) {
            Button("Aceptar") { model.error = nil }
        } message: { Text(model.error ?? "") }
        .sheet(item: $preview) { ManzanaFilePreview(url: $0.url) }
        .sheet(item: $sharing) { ManzanaShareFile(url: $0.url) }
    }
    private func fileRow(_ url: URL) -> some View {
        let directory = (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
        return Button {
            if model.isTrash { return }
            if directory { search = ""; model.open(url) }
            else { preview = ManzanaFileSelection(url: url) }
        } label: {
            Label(url.lastPathComponent, systemImage: directory ? "folder.fill" : "doc.fill")
                .foregroundStyle(directory ? Color.blue : Color.primary)
                .padding(.vertical, 5)
        }
        .contextMenu {
            if model.isTrash {
                Button("Restaurar", systemImage: "arrow.uturn.backward") { model.run { try $0.restore(url) } }
            } else {
                if !directory {
                    Button("Compartir / Exportar", systemImage: "square.and.arrow.up") { sharing = ManzanaFileSelection(url: url) }
                }
                Button("Renombrar", systemImage: "pencil") { name = url.lastPathComponent; renaming = url }
                Button("Mover a papelera", systemImage: "trash", role: .destructive) { model.run { try $0.moveToTrash(url) } }
            }
        }
    }
}

private struct ManzanaShareFile: UIViewControllerRepresentable {
    let url: URL
    func makeUIViewController(context: Context) -> UIActivityViewController { UIActivityViewController(activityItems: [url], applicationActivities: nil) }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
private struct ManzanaFilePreview: UIViewControllerRepresentable {
    let url: URL
    func makeCoordinator() -> Coordinator { Coordinator(url) }
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController(); controller.dataSource = context.coordinator; return controller
    }
    func updateUIViewController(_ controller: QLPreviewController, context: Context) {}
    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        init(_ url: URL) { self.url = url }
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem { url as NSURL }
    }
}
