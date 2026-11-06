import SwiftUI
import UIKit

/// Final onboarding choice. Reads the actual bundled previews and only saves
/// the selection after the user finishes first-run onboarding.
struct BloomBoxWizardThemeChoiceView: View {
    @Binding var selectedID: String
    let accentHex: String
    let isPreview: Bool
    let onBack: () -> Void
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @State private var appeared = false

    private var spanish: Bool {
        language == "es" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es"))
    }
    private var ink: Color {
        scheme == .dark ? .white : Color(red: 0.13, green: 0.13, blue: 0.21)
    }
    private var accent: Color { BloomBoxWizardPalette.color(accentHex) }
    private var background: Color {
        scheme == .dark ? Color(red: 0.042, green: 0.045, blue: 0.063)
                        : Color(red: 0.977, green: 0.973, blue: 0.985)
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.19), .clear],
                           center: .top, startRadius: 0, endRadius: 560)
                .ignoresSafeArea()
                .allowsHitTesting(false)
            ScrollView {
                VStack(spacing: 20) {
                    HStack {
                        Label("BloomBox", systemImage: "sparkle")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("05 / 05")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(ink.opacity(0.70))
                    .padding(.top, 20)

                    VStack(spacing: 10) {
                        Image(systemName: "paintpalette.fill")
                            .font(.system(size: 36, weight: .semibold))
                            .foregroundStyle(accent)
                            .frame(width: 84, height: 84)
                            .background(accent.opacity(0.13), in: Circle())
                        Text(spanish ? "Elige tu tema" : "Choose your theme")
                            .font(.system(size: 30, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                        Text(spanish ? "¿Con cuál quieres empezar? Puedes cambiarlo después."
                                     : "Which one feels right? You can change it later.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(ink.opacity(0.64))
                            .multilineTextAlignment(.center)
                    }

                    VStack(spacing: 15) {
                        themeCard(id: "KirbyPink", title: "Pink Kirby",
                                  subtitle: spanish ? "Suave, rosa y divertido" : "Soft, pink and playful",
                                  tint: Color(red: 0.96, green: 0.51, blue: 0.74),
                                  defaultTheme: true, index: 0)
                        themeCard(id: "YellowBowser", title: "Yellow Bowser",
                                  subtitle: spanish ? "Amarillo, intenso y con personalidad"
                                                    : "Bold, yellow and full of personality",
                                  tint: Color(red: 0.97, green: 0.74, blue: 0.19),
                                  defaultTheme: false, index: 1)
                    }

                    if isPreview {
                        Label(spanish ? "Prueba: no cambiaremos tu tema actual."
                                      : "Preview: your current theme won't change.",
                              systemImage: "eye")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(ink.opacity(0.66))
                    }

                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(ink)
                                .frame(width: 60, height: 56)
                                .background(ink.opacity(0.08),
                                            in: RoundedRectangle(cornerRadius: 18))
                        }
                        .accessibilityLabel(spanish ? "Atrás" : "Back")
                        Button(action: onFinish) {
                            HStack(spacing: 9) {
                                Text(isPreview
                                     ? (spanish ? "Cerrar prueba" : "Close preview")
                                     : (spanish ? "Empezar con este tema" : "Start with this theme"))
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(accent, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .accessibilityIdentifier("bloombox.wizard.theme.finish")
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 5)
                }
                .frame(maxWidth: 510)
                .padding(.horizontal, 25)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear { appeared = true }
    }

    private func themeCard(id: String, title: String, subtitle: String,
                           tint: Color, defaultTheme: Bool, index: Int) -> some View {
        let chosen = selectedID == id
        return Button {
            withAnimation(.spring(response: 0.36, dampingFraction: 0.78)) {
                selectedID = id
            }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .bottomTrailing) {
                    Group {
                        if let url = BloomBoxBundledThemes.previewURL(for: id),
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                        } else {
                            LinearGradient(colors: [tint.opacity(0.9), tint.opacity(0.2)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                .overlay(Image(systemName: "sparkles")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.white.opacity(0.8)))
                        }
                    }
                    .frame(height: 155)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 17))

                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 29))
                        .symbolRenderingMode(.palette)
                        .foregroundStyle(chosen ? tint : .white, .white)
                        .padding(12)
                }
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(title)
                                .font(.system(size: 19, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                            if defaultTheme {
                                Text(spanish ? "Predeterminado" : "Default")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(tint)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(tint.opacity(0.12), in: Capsule())
                            }
                        }
                        Text(subtitle)
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(ink.opacity(0.60))
                    }
                    Spacer()
                    Image(systemName: chosen ? "checkmark.seal.fill" : "circle.dotted")
                        .font(.system(size: 24))
                        .foregroundStyle(chosen ? tint : ink.opacity(0.32))
                }
            }
            .padding(12)
            .background(ink.opacity(chosen ? 0.075 : 0.035),
                        in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24)
                .strokeBorder(chosen ? tint : ink.opacity(0.08),
                              lineWidth: chosen ? 2 : 1))
            .scaleEffect(chosen && !reduceMotion ? 1.012 : 1)
            .offset(y: appeared || reduceMotion ? 0 : CGFloat(15 + index * 7))
            .opacity(appeared ? 1 : 0.2)
            .animation(reduceMotion ? nil : .spring(response: 0.5, dampingFraction: 0.78)
                .delay(Double(index) * 0.1), value: appeared)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bloombox.wizard.theme." + id)
        .accessibilityAddTraits(chosen ? [.isSelected] : [])
    }
}
