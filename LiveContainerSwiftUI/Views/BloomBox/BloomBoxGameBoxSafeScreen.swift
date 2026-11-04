import SwiftUI
import UIKit

/// Deliberately simple fallback. No landscape request, motion wallpaper,
/// custom artwork decoder, view-aligned scroll tracking, or host code.
@available(iOS 16.0, *)
struct BloomBoxGameBoxSafeScreen: View {
    let entries: [BloomBoxGameBoxEntry]
    let launch: (String) -> Void
    let launchWithJIT: (String) -> Void
    let manage: (String) -> Void
    let exit: () -> Void
    let retryFull: () -> Void

    @State private var selectedKey: String?
    private var selected: BloomBoxGameBoxEntry? {
        entries.first(where: { $0.id == selectedKey }) ?? entries.first
    }

    var body: some View {
        GeometryReader { frame in
            let compact = frame.size.width > frame.size.height
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.title2)
                        .foregroundStyle(.cyan)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("GAMEBOX V2").font(.headline.bold())
                        Text("Modo seguro · sin fondos animados")
                            .font(.caption).foregroundStyle(.white.opacity(0.65))
                    }
                    Spacer()
                    Button("Escritorio", action: exit)
                        .buttonStyle(.bordered)
                    Button("Probar interfaz completa", action: retryFull)
                        .buttonStyle(.borderedProminent)
                }
                .font(.caption)
                Divider().overlay(.white.opacity(0.1))
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: compact ? 112 : 90),
                                                  spacing: 15)], spacing: 18) {
                        ForEach(entries) { entry in
                            Button {
                                selectedKey = entry.id
                                UISelectionFeedbackGenerator().selectionChanged()
                            } label: {
                                VStack(spacing: 8) {
                                    ZStack(alignment: .topTrailing) {
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(Color.white.opacity(0.08))
                                        if let image = entry.icon {
                                            Image(uiImage: image)
                                                .resizable().scaledToFit()
                                                .padding(7)
                                        } else {
                                            Image(systemName: "app.fill")
                                                .resizable().scaledToFit()
                                                .padding(24)
                                                .foregroundStyle(.white.opacity(0.5))
                                        }
                                        if entry.requiresJIT {
                                            Image(systemName: "bolt.fill")
                                                .font(.caption.bold())
                                                .foregroundStyle(.yellow)
                                                .padding(7)
                                        }
                                    }
                                    .aspectRatio(1, contentMode: .fit)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 20)
                                            .strokeBorder(selected?.id == entry.id ?
                                                Color.cyan : Color.white.opacity(0.12),
                                                lineWidth: selected?.id == entry.id ? 2 : 1)
                                    }
                                    Text(entry.name)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(.white)
                                        .lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.gamebox.safe." + entry.id)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if let app = selected {
                    HStack {
                        Text(app.name)
                            .font(.headline).lineLimit(1)
                        Spacer(minLength: 4)
                        Button("Ajustes") { manage(app.id) }
                            .buttonStyle(.bordered)
                        Button("JIT") { launchWithJIT(app.id) }
                            .buttonStyle(.bordered)
                        Button {
                            launch(app.id)
                        } label: {
                            Label("Jugar", systemImage: "play.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .font(.caption)
                } else {
                    Text("No hay aplicaciones instaladas.")
                        .font(.subheadline)
                }
            }
            .padding(compact ? 18 : 13)
        }
        .background(Color(red: 0.04, green: 0.07, blue: 0.13).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear {
            if selectedKey == nil { selectedKey = entries.first?.id }
            LiveContainerPreferencesAdapter.defaults.set(
                "safe-visible", forKey: BloomBoxGameBoxRecoveryPolicy.stageKey)
        }
        .accessibilityIdentifier("bloombox.gamebox.safe-mode")
    }
}
