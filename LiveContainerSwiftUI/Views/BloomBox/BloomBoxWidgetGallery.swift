import SwiftUI

/// BloomBox's own widget picker. Existing saved widget order and page
/// selection callbacks continue to work with older desktop configurations.
struct BloomBoxWidgetGallery: View {
    var pageSelection: Set<String>? = nil
    var onToggle: ((String) -> Void)? = nil

    @Environment(\.dismiss) private var dismiss
    @AppStorage("ManzanaWidgetOrder", store: LCUtils.appGroupUserDefault)
    private var savedOrder = "clock,photo,notes"
    @AppStorage("ManzanaNote", store: LCUtils.appGroupUserDefault)
    private var note = ""
    @State private var pageKinds = Set<String>()
    @State private var photo: UIImage?

    private struct Choice: Identifiable {
        var id: String
        var title: String
        var symbol: String
        var description: String
    }

    private let choices: [Choice] = [
        .init(id: "clock", title: "Reloj", symbol: "clock.fill",
              description: "Hora y fecha actualizadas automáticamente"),
        .init(id: "photo", title: "Fotos", symbol: "photo.on.rectangle",
              description: "Tu imagen favorita en el escritorio"),
        .init(id: "notes", title: "Notas", symbol: "note.text",
              description: "Un recordatorio siempre a la vista")
    ]

    private var installed: Set<String> {
        if pageSelection != nil { return pageKinds }
        return Set(BloomBoxWidgetGalleryPolicy.decode(savedOrder))
    }

    private var photoURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/widget-photo.jpg")
    }

    var body: some View {
        NavigationView {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 16) {
                    Text("Elige qué widgets mostrar en esta página. Después puedes mantener pulsado uno para moverlo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 4)

                    ForEach(choices) { choice in
                        widgetCard(choice)
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Widgets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            pageKinds = pageSelection ?? []
            photo = UIImage(contentsOfFile: photoURL.path)
        }
        .accessibilityIdentifier("bloombox.widgets.gallery")
    }

    private func widgetCard(_ choice: Choice) -> some View {
        let active = installed.contains(choice.id)
        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: choice.symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 36, height: 36)
                    .foregroundStyle(active ? Color.green : Color.primary)
                VStack(alignment: .leading, spacing: 3) {
                    Text(choice.title).font(.headline)
                    Text(choice.description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                if active {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .accessibilityLabel("Añadido")
                }
            }

            preview(choice.id)
                .frame(maxWidth: .infinity)
                .frame(height: 118)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .clipped()

            Button {
                toggle(choice.id)
                UISelectionFeedbackGenerator().selectionChanged()
            } label: {
                Label(active ? "Quitar widget" : "Añadir widget",
                      systemImage: active ? "minus.circle.fill" : "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(active ? Color.gray : Color.accentColor)
            .accessibilityIdentifier("bloombox.widget." + choice.id)
        }
        .padding(16)
        .background(Color(uiColor: .secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }

    @ViewBuilder
    private func preview(_ kind: String) -> some View {
        switch kind {
        case "clock":
            TimelineView(.periodic(from: .now, by: 60)) { context in
                VStack(spacing: 5) {
                    Text(context.date, format: .dateTime.hour().minute())
                        .font(.system(size: 38, weight: .light, design: .rounded))
                    Text(context.date, format: .dateTime.weekday(.wide).day().month(.wide))
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        case "photo":
            if let photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 118)
                    .clipped()
            } else {
                Label("Tus recuerdos", systemImage: "photo.on.rectangle.angled")
                    .font(.title3)
            }
        default:
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "note.text").font(.title3)
                Text(note.isEmpty ? "Escribe algo para recordar…" : note)
                    .font(.subheadline)
                    .lineLimit(3)
            }
            .padding(14)
        }
    }

    private func toggle(_ kind: String) {
        guard BloomBoxWidgetGalleryPolicy.allowed.contains(kind) else { return }
        if let onToggle {
            if pageKinds.contains(kind) { pageKinds.remove(kind) }
            else { pageKinds.insert(kind) }
            onToggle(kind)
        } else {
            savedOrder = BloomBoxWidgetGalleryPolicy.toggle(kind, in: savedOrder)
        }
    }
}

// Keeps older SwiftUI call sites compatible during the visual migration.
typealias ManzanaWidgetGallery = BloomBoxWidgetGallery
