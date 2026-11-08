import SwiftUI

/// Search UI without guest runtime types. Installed guests are represented
/// by stable keys and their names; the caller owns launching and app icons.
struct BloomBoxHomeSearchEntry: Identifiable, Equatable {
    let key: String
    let title: String
    let isHidden: Bool
    var id: String { key }
}

struct BloomBoxHomeSearchPanel<Icon: View, Context: View>: View {
    @Binding var query: String
    let height: CGFloat
    let entries: [BloomBoxHomeSearchEntry]
    let englishUI: Bool
    let onLaunch: (String) -> Void
    let onClose: () -> Void
    let icon: (String) -> Icon
    let contextMenu: (String) -> Context

    @FocusState private var focused: Bool

    init(
        query: Binding<String>,
        height: CGFloat,
        entries: [BloomBoxHomeSearchEntry],
        englishUI: Bool,
        onLaunch: @escaping (String) -> Void,
        onClose: @escaping () -> Void,
        @ViewBuilder icon: @escaping (String) -> Icon,
        @ViewBuilder contextMenu: @escaping (String) -> Context
    ) {
        self._query = query
        self.height = height
        self.entries = entries
        self.englishUI = englishUI
        self.onLaunch = onLaunch
        self.onClose = onClose
        self.icon = icon
        self.contextMenu = contextMenu
    }

    private func dismiss() {
        focused = false
        onClose()
    }

    private func open(_ entry: BloomBoxHomeSearchEntry) {
        dismiss()
        onLaunch(entry.key)
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.12)
                .contentShape(Rectangle())
                .onTapGesture(perform: dismiss)
            VStack(spacing: 16) {
                searchBar
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    suggestions
                } else {
                    results
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { DispatchQueue.main.async { focused = true } }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, dismiss)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 21))
                    .foregroundStyle(.white.opacity(0.75))
                TextField(englishUI ? "Search Apps" : "Buscar apps", text: $query)
                    .font(.system(size: 22))
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                    .submitLabel(.search)
                    .focused($focused)
                    .accessibilityIdentifier("home.search.field")
                    .onSubmit {
                        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                           let first = entries.first { open(first) }
                    }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.white.opacity(0.65))
                    }
                    .accessibilityLabel(englishUI ? "Clear search" : "Borrar búsqueda")
                }
            }
            .padding(.horizontal, 18)
            .frame(height: 58)
            .liveBoardGlass(radius: 28)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .medium))
                    .frame(width: 48, height: 48)
            }
            .liveBoardGlass(radius: 24)
            .accessibilityLabel(englishUI ? "Done" : "Listo")
            .accessibilityIdentifier("home.search.done")
        }
    }

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(englishUI ? "Suggestions" : "Sugerencias")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(0.65))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 4),
                      spacing: 18) {
                ForEach(Array(entries.prefix(8))) { entry in
                    Button { open(entry) } label: {
                        VStack(spacing: 6) {
                            icon(entry.key)
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            Text(BloomBoxL10n.t(entry.title))
                                .font(.system(size: 12))
                                .lineLimit(1)
                        }
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(entry.key) }
                }
            }
        }
        .padding(18)
        .liveBoardGlass(radius: 30, interactive: false)
    }

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(entries) { entry in
                    Button { open(entry) } label: {
                        HStack(spacing: 14) {
                            icon(entry.key)
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                            Text(BloomBoxL10n.t(entry.title))
                                .font(.system(size: 17))
                                .lineLimit(1)
                            Spacer()
                            if entry.isHidden {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(entry.key) }
                }
                if entries.isEmpty {
                    Text(englishUI ? "No Results" : "Sin resultados")
                        .foregroundStyle(.white.opacity(0.65))
                        .padding(24)
                }
            }
        }
        .frame(height: min(380, height * 0.48, CGFloat(max(1, entries.count)) * 66))
        .liveBoardGlass(radius: 30, interactive: false)
    }
}
