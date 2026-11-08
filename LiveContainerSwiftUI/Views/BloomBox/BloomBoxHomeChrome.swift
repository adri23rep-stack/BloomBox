import SwiftUI

/// Native BloomBox Home controls. Pure presentation: Home owns user settings,
/// app launch callbacks, folder state and installed guest containers.
struct BloomBoxHomeInstallationNotice: View {
    let progress: Double
    private var amount: Double {
        progress.isFinite ? min(1, max(0, progress)) : 0
    }
    var body: some View {
        VStack {
            HStack(spacing: 12) {
                ProgressView()
                    .tint(.white)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instalando aplicación…")
                        .font(.subheadline.weight(.semibold))
                    ProgressView(value: amount, total: 1)
                        .tint(.white)
                    Text("\(Int(amount * 100)) %")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.78))
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .liveBoardGlass(radius: 22, interactive: false)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            Spacer(minLength: 0)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Instalando aplicación")
        .accessibilityValue(BloomBoxL10n.isEnglish ? "\(Int(amount * 100)) percent" : "\(Int(amount * 100)) por ciento")
    }
}

/// Only overlays the existing wallpaper; does not start a duplicate video/GIF
/// player or intercept icon taps while the Home entrance animation plays.
struct BloomBoxHomeWelcome: View {
    let message: String
    let visible: Bool
    var body: some View {
        ZStack {
            Rectangle().fill(.regularMaterial)
            Color.black.opacity(0.22)
            VStack(spacing: 12) {
                Text("BloomBox")
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .tracking(-2)
                    .shadow(color: .white.opacity(0.25), radius: 23)
                Text(LocalizedStringKey(message))
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(Color(red: 1, green: 0.87, blue: 0.38))
                    .shadow(color: .black.opacity(0.5), radius: 8, y: 3)
                    .rotationEffect(.degrees(-5))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .padding(.horizontal, 28)
            }
            .scaleEffect(visible ? 1 : 1.05)
        }
        .ignoresSafeArea()
        .opacity(visible ? 1 : 0)
        .animation(.easeInOut(duration: 0.27), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Keep Edit/Done buttons inside a shallow top toolbar, never a full-screen
/// overlay that steals touches from pages, folders and animated widgets.
struct BloomBoxHomeEditorToolbar: View {
    @Binding var exportURL: URL?
    let addWidget: () -> Void
    let customize: () -> Void
    let exportTheme: () -> Void
    let addPage: () -> Void
    let managePages: () -> Void
    let openLibrary: () -> Void
    let finish: () -> Void

    var body: some View {
        HStack {
            Menu {
                Button("Añadir widget", systemImage: "square.grid.2x2.badge.plus",
                       action: addWidget)
                Button("Personalizar", systemImage: "paintbrush", action: customize)
                Button("Exportar tema", systemImage: "square.and.arrow.up",
                       action: exportTheme)
                Button("Añadir página", systemImage: "plus", action: addPage)
                Button("Gestionar páginas", systemImage: "square.grid.2x2",
                       action: managePages)
                Button("Biblioteca de apps", systemImage: "square.grid.2x2",
                       action: openLibrary)
            } label: {
                Text("Editar")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .liveBoardGlass(radius: 18, interactive: false)
            .accessibilityIdentifier("bloombox.home.edit")
            Spacer(minLength: 12)
            Button(action: finish) {
                Text("Listo")
                    .font(.system(size: 16, weight: .semibold))
                    .padding(.horizontal, 18)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .liveBoardGlass(radius: 18, interactive: false)
            .accessibilityIdentifier("bloombox.home.done")
        }
        .padding(.horizontal, 22)
        .sheet(isPresented: Binding(
            get: { exportURL != nil },
            set: { if !$0 { exportURL = nil } }
        )) {
            if let url = exportURL { BloomBoxThemeShareSheet(fileURL: url) }
        }
    }
}
