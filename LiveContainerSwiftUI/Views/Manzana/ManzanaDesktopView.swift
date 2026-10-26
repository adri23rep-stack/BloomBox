import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

struct ManzanaDesktopView: View {
    let openSettings: () -> Void
    @AppStorage("ManzanaWidgetOrder", store: LCUtils.appGroupUserDefault) private var savedOrder = "clock,photo,notes"
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault) private var note = ""
    @State private var files = false
    @State private var editingNote = false
    @State private var choosingPhoto = false
    @State private var photo: UIImage?
    @State private var error: String?
    private let available = ["clock", "photo", "notes"]
    private var order: [String] {
        var seen = Set<String>()
        return savedOrder.split(separator: ",").map(String.init).filter { available.contains($0) && seen.insert($0).inserted }
    }
    private var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Manzana", isDirectory: true).appendingPathComponent("widget-photo.jpg")
    }
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Manzana").font(.largeTitle.bold())
                        Text("Tu escritorio").font(.subheadline).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu {
                        ForEach(available, id: \.self) { id in
                            Button(order.contains(id) ? "Ocultar \(title(id))" : "Añadir \(title(id))") { toggle(id) }
                        }
                        Button("Ajustes del escritorio", systemImage: "gearshape") { openSettings() }
                    } label: { Image(systemName: "slider.horizontal.3").frame(width: 44, height: 44) }
                    .accessibilityLabel("Organizar widgets y ajustes")
                }
                Button { files = true } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "folder.fill").font(.largeTitle).foregroundStyle(.cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Archivos").font(.headline)
                            Text("Documentos, carpetas y papelera").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                    }.padding(20).frame(maxWidth: .infinity).liveBoardGlass(radius: 24)
                }.buttonStyle(.plain)
                ForEach(order, id: \.self) { id in
                    widget(id)
                        .contextMenu {
                            Button("Mover arriba", systemImage: "arrow.up") { move(id, offset: -1) }.disabled(order.first == id)
                            Button("Mover abajo", systemImage: "arrow.down") { move(id, offset: 1) }.disabled(order.last == id)
                            Button("Ocultar", systemImage: "eye.slash") { toggle(id) }
                        }
                        .onDrag { NSItemProvider(object: ("manzana-widget:" + id) as NSString) }
                        .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                            guard let item = providers.first else { return false }
                            _ = item.loadObject(ofClass: String.self) { value, _ in
                                guard let value, value.hasPrefix("manzana-widget:") else { return }
                                let source = String(value.dropFirst("manzana-widget:".count))
                                DispatchQueue.main.async { move(source, before: id) }
                            }
                            return true
                        }
                }
                if order.isEmpty { Text("Añade widgets desde el botón de ajustes.").font(.subheadline).foregroundStyle(.secondary) }
            }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 24)
        }
        .onAppear { photo = UIImage(contentsOfFile: photoURL.path) }
        .sheet(isPresented: $files) { ManzanaFilesView() }
        .sheet(isPresented: $editingNote) { noteEditor }
        .sheet(isPresented: $choosingPhoto) {
            ManzanaPhotoPicker { image in
                choosingPhoto = false
                guard let image else { return }
                savePhoto(image)
            }
        }
        .alert("Foto del widget", isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } })) {
            Button("Aceptar") { error = nil }
        } message: { Text(error ?? "") }
    }
    @ViewBuilder private func widget(_ id: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title(id)).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Image(systemName: "line.3.horizontal").foregroundStyle(.secondary).accessibilityHidden(true)
            }
            switch id {
            case "clock":
                TimelineView(.periodic(from: .now, by: 60)) { context in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(context.date, format: .dateTime.hour().minute()).font(.system(size: 46, weight: .light, design: .rounded)).minimumScaleFactor(0.6).lineLimit(1)
                        Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide)).font(.subheadline)
                    }
                }
            case "photo":
                Button { choosingPhoto = true } label: {
                    Group {
                        if let photo {
                            Image(uiImage: photo).resizable().scaledToFill()
                        } else {
                            VStack(spacing: 12) { Image(systemName: "photo.badge.plus").font(.largeTitle); Text("Elegir foto").font(.subheadline) }.frame(maxWidth: .infinity)
                        }
                    }
                    .frame(height: 170).frame(maxWidth: .infinity)
                    .clipped().clipShape(RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityLabel("Cambiar foto del widget")
            default:
                Button { editingNote = true } label: {
                    Text(note.isEmpty ? "Toca para escribir una nota…" : note)
                        .font(.body).lineLimit(5).frame(maxWidth: .infinity, minHeight: 70, alignment: .topLeading)
                }.buttonStyle(.plain).accessibilityLabel("Editar nota: " + (note.isEmpty ? "Vacía" : note))
            }
        }
        .padding(20).frame(maxWidth: .infinity, alignment: .leading).liveBoardGlass(radius: 24)
    }
    private var noteEditor: some View {
        NavigationView {
            TextEditor(text: $note).padding()
                .onChange(of: note) { value in if value.count > 10000 { note = String(value.prefix(10000)) } }
                .navigationTitle("Notas").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Listo") { editingNote = false } } }
        }.navigationViewStyle(.stack)
    }
    private func title(_ id: String) -> String { id == "clock" ? "Reloj" : (id == "photo" ? "Fotos" : "Notas") }
    private func toggle(_ id: String) {
        var values = order
        if values.contains(id) { values.removeAll { $0 == id } } else { values.append(id) }
        savedOrder = values.joined(separator: ",")
    }
    private func move(_ id: String, offset: Int) {
        var values = order
        guard let index = values.firstIndex(of: id), values.indices.contains(index + offset) else { return }
        values.swapAt(index, index + offset); savedOrder = values.joined(separator: ",")
    }
    private func move(_ id: String, before target: String) {
        guard id != target, order.contains(id), order.contains(target) else { return }
        var values = order.filter { $0 != id }
        guard let index = values.firstIndex(of: target) else { return }
        values.insert(id, at: index); savedOrder = values.joined(separator: ",")
    }
    private func savePhoto(_ image: UIImage) {
        let scale = min(1, 1200 / max(image.size.width, image.size.height))
        let size = CGSize(width: max(1, image.size.width * scale), height: max(1, image.size.height * scale))
        let format = UIGraphicsImageRendererFormat(); format.scale = 1
        let reduced = UIGraphicsImageRenderer(size: size, format: format).image { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        do {
            guard let data = reduced.jpegData(compressionQuality: 0.88) else { throw CocoaError(.fileWriteUnknown) }
            try FileManager.default.createDirectory(at: photoURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: photoURL, options: .atomic)
            photo = reduced
        } catch { self.error = error.localizedDescription }
    }
}

/// Standalone widget selector. Uses the same persistent order as the original
/// ManzanaDesktopView; no visual changes to the Home or its existing controls.
struct ManzanaWidgetGallery: View {
    @Environment(\.presentationMode) private var presentationMode
    @AppStorage("ManzanaWidgetOrder", store: LCUtils.appGroupUserDefault)
    private var savedOrder = "clock,photo,notes"
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault)
    private var note = ""
    @State private var photo: UIImage?
    private let available = ["clock", "photo", "notes"]

    private var order: [String] {
        var seen = Set<String>()
        return savedOrder.split(separator: ",").map(String.init)
            .filter { available.contains($0) && seen.insert($0).inserted }
    }
    private var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Manzana", isDirectory: true)
            .appendingPathComponent("widget-photo.jpg")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Elige los widgets que aparecerán en tu página de Manzana.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(available, id: \.self) { id in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 12) {
                                Label(title(id), systemImage: symbol(id))
                                    .font(.headline)
                                Spacer()
                                if order.contains(id) {
                                    Label("Añadido", systemImage: "checkmark.circle.fill")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.green)
                                }
                            }
                            preview(id)
                                .frame(maxWidth: .infinity)
                                .frame(height: 125)
                                .background(.ultraThinMaterial,
                                            in: RoundedRectangle(cornerRadius: 19))
                            Button {
                                toggle(id)
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                Label(order.contains(id) ? "Quitar widget" : "Añadir widget",
                                      systemImage: order.contains(id) ? "minus.circle" : "plus.circle.fill")
                                    .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(order.contains(id) ? .gray : .accentColor)
                        }
                        .padding(16)
                        .background(Color(uiColor: .secondarySystemGroupedBackground),
                                    in: RoundedRectangle(cornerRadius: 23))
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Añadir widget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { presentationMode.wrappedValue.dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear { photo = UIImage(contentsOfFile: photoURL.path) }
        .accessibilityIdentifier("manzana.widgets.gallery")
    }

    private func title(_ id: String) -> String {
        switch id {
        case "clock": return "Reloj"
        case "photo": return "Fotos"
        default: return "Notas"
        }
    }
    private func symbol(_ id: String) -> String {
        switch id {
        case "clock": return "clock.fill"
        case "photo": return "photo.fill"
        default: return "note.text"
        }
    }

    @ViewBuilder private func preview(_ id: String) -> some View {
        switch id {
        case "clock":
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 4) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 39, weight: .light, design: .rounded))
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption)
                }
            }
        case "photo":
            if let photo {
                Image(uiImage: photo)
                    .resizable().scaledToFill()
                    .frame(height: 125).clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 19))
            } else {
                Label("Tus recuerdos", systemImage: "photo.on.rectangle.angled")
                    .font(.title3)
            }
        default:
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: "note.text").font(.title3)
                Text(note.isEmpty ? "Escribe lo que quieras recordar…" : note)
                    .font(.subheadline).lineLimit(3)
            }
            .padding(12)
        }
    }

    private func toggle(_ id: String) {
        guard available.contains(id) else { return }
        var values = order
        if values.contains(id) {
            values.removeAll { $0 == id }
        } else {
            values.append(id)
        }
        savedOrder = values.joined(separator: ",")
    }
}

private struct ManzanaPhotoPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(completion) }
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration(); config.filter = .images; config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}
    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        let completion: (UIImage?) -> Void
        init(_ completion: @escaping (UIImage?) -> Void) { self.completion = completion }
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            guard let provider = results.first?.itemProvider else { completion(nil); return }
            provider.loadObject(ofClass: UIImage.self) { image, _ in DispatchQueue.main.async { self.completion(image as? UIImage) } }
        }
    }
}
