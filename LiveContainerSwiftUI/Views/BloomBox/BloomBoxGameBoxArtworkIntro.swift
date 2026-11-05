import SwiftUI

/// Short, default-enabled wallpaper warmup presentation. The icon entrance
/// follows BloomBox Alive's offset/scale/opacity spring wave. It is not a
/// network engine and never changes the selected application or its scroll.
@available(iOS 16.0, *)
struct BloomBoxGameBoxArtworkIntro: View {
    let icons: [UIImage]
    let reduceMotion: Bool
    let safeMode: Bool
    let onSkip: () -> Void
    let onEnableGraphics: () -> Void

    @State private var iconsLifted = false

    private var waveIcons: [UIImage] {
        Array(icons.prefix(5))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.34).ignoresSafeArea()
            VStack(spacing: 13) {
                HStack(spacing: 7) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 12, weight: .bold))
                    Text("GAMEBOX")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .tracking(1.6)
                    Text("V2")
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.16), in: Capsule())
                }
                .foregroundStyle(.white.opacity(0.90))

                HStack(alignment: .center, spacing: 9) {
                    ForEach(0..<5, id: \.self) { slot in
                        Group {
                            if slot < waveIcons.count {
                                Image(uiImage: waveIcons[slot])
                                    .resizable()
                                    .scaledToFit()
                            } else {
                                Image(systemName: "gamecontroller.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .padding(9)
                                    .foregroundStyle(.white.opacity(0.54))
                            }
                        }
                        .frame(width: 46, height: 46)
                        .background(.white.opacity(0.09),
                                    in: RoundedRectangle(cornerRadius: 12))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .scaleEffect(reduceMotion ? 1 : (iconsLifted ? 1 : 0.70),
                                     anchor: .bottom)
                        .offset(y: reduceMotion ? 0 : (iconsLifted ? -7 : 11))
                        .opacity(reduceMotion ? 1 : (iconsLifted ? 1 : 0.38))
                        .animation(
                            reduceMotion ? nil :
                                .spring(response: 0.55, dampingFraction: 0.62)
                                    .repeatForever(autoreverses: true)
                                    .delay(Double(slot) * 0.13),
                            value: iconsLifted
                        )
                    }
                }
                .frame(height: 60)
                .accessibilityHidden(true)

                Text(BloomBoxGameBoxL10n.t(safeMode ? "Modo seguro: fondos pausados" : "Preparando fondos de los juegos…"))
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
                if safeMode {
                    Text("GameBox protegió la interfaz tras una interrupción. Reactiva los fondos cuando quieras probarlos.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 16) {
                        Button("Activar fondos", action: onEnableGraphics)
                            .font(.system(size: 12, weight: .semibold))
                            .buttonStyle(.borderedProminent)
                        Button("Seguir en SAFE", action: onSkip)
                            .font(.system(size: 11))
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.73))
                    }
                } else {
                    HStack(spacing: 8) {
                        ProgressView().tint(.white.opacity(0.85)).scaleEffect(0.75)
                        Text("Usando catálogo y carátulas disponibles")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.63))
                        Button("Saltar", action: onSkip)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.85))
                            .padding(.leading, 5)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 17)
            .frame(maxWidth: 360)
            .background {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .opacity(0.74)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(.white.opacity(0.20), lineWidth: 0.85)
            }
            .shadow(color: .black.opacity(0.26), radius: 24, y: 10)
            .padding(.horizontal, 20)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("bloombox.gamebox.wallpaper-intro")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { iconsLifted = true }
        .onDisappear { iconsLifted = false }
    }
}
