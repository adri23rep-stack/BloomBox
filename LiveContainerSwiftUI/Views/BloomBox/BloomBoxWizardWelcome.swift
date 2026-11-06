import SwiftUI
import UIKit

/// The first screen of BloomBox's first-run wizard.
/// Preview mode is a visual/configuration test: it never resets app data or wizard completion.
struct BloomBoxWizardWelcomeView: View {
    let isPreview: Bool
    let accentHex: String
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var preferredLanguage = "system"
    @State private var showEnglishGreeting = true

    private let choices = BloomBoxWizardLanguage.allCases

    private var dark: Bool { colorScheme == .dark }
    private var mainInk: Color { dark ? Color.white : Color(red: 0.13, green: 0.12, blue: 0.19) }
    private var accent: Color { BloomBoxWizardPalette.color(accentHex) }
    private var index: Int { choices.firstIndex(where: { $0.rawValue == preferredLanguage }) ?? 1 }
    private var selected: BloomBoxWizardLanguage { choices[index] }
    private var isSpanish: Bool {
        switch selected {
        case .spanish: return true
        case .english: return false
        case .automatic: return (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es")
        }
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                (dark ? Color(red: 0.043, green: 0.045, blue: 0.065)
                      : Color(red: 0.977, green: 0.973, blue: 0.985))
                    .ignoresSafeArea()

                RadialGradient(colors: [accent.opacity(dark ? 0.15 : 0.095), .clear],
                               center: .topTrailing, startRadius: 6, endRadius: 500)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                BloomBoxWizardAmbientSymbols(isDark: dark, accentHex: accentHex)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                VStack(spacing: 0) {
                    HStack {
                        Label("BloomBox", systemImage: "sparkle")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .foregroundStyle(mainInk.opacity(0.77))
                        Spacer()
                        Text("01 / 02")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                            .foregroundStyle(mainInk.opacity(0.45))
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 22)

                    Spacer(minLength: 26)

                    VStack(spacing: 15) {
                        ZStack {
                            if showEnglishGreeting {
                                Text("Welcome")
                                    .id("welcome")
                                    .transition(.opacity.combined(with: .offset(y: -9)))
                            } else {
                                Text("Bienvenido")
                                    .id("bienvenido")
                                    .transition(.opacity.combined(with: .offset(y: 9)))
                            }
                        }
                        .font(.system(size: min(proxy.size.width * 0.115, 53),
                                      weight: .heavy, design: .rounded))
                        .foregroundStyle(mainInk)
                        .frame(height: 73)
                        .accessibilityIdentifier("bloombox.wizard.greeting")

                        Text(isSpanish ? "Un espacio hecho para ti." : "A space made for you.")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(mainInk.opacity(0.57))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)

                    Spacer(minLength: 35)

                    VStack(spacing: 18) {
                        Text(isSpanish ? "ELIGE TU IDIOMA" : "CHOOSE YOUR LANGUAGE")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(mainInk.opacity(0.46))

                        languageWheel

                        Text(isSpanish ? "Desliza para cambiarlo" : "Swipe to change")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(mainInk.opacity(0.43))
                    }
                    .padding(.bottom, 20)

                    Spacer(minLength: 30)

                    VStack(spacing: 14) {
                        Button(action: onFinish) {
                            HStack(spacing: 10) {
                                Text(isSpanish ? "Continuar" : "Continue")
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 14, weight: .bold))
                            }
                            .font(.system(size: 17, weight: .bold, design: .rounded))
                            .foregroundStyle(accentHex == "E5B83F" ? Color.black : Color.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 58)
                            .background(
                                LinearGradient(colors: [accent, accent.opacity(0.85)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("bloombox.wizard.continue")

                        if isPreview {
                            Button(isSpanish ? "Cerrar prueba" : "Close preview", action: onFinish)
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(mainInk.opacity(0.65))
                                .frame(minHeight: 30)
                                .accessibilityIdentifier("bloombox.wizard.preview.close")
                        } else {
                            Text(isSpanish ? "Podrás cambiar el idioma después en Experimentos."
                                           : "You can change your language later in Experiments.")
                                .font(.system(size: 11, weight: .regular, design: .rounded))
                                .foregroundStyle(mainInk.opacity(0.48))
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 27)
                    .padding(.bottom, max(16, proxy.safeAreaInsets.bottom == 0 ? 23 : 8))
                }
            }
        }
        .task {
            guard !reduceMotion else { return }
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: 3_000_000_000)
                } catch {
                    break
                }
                withAnimation(.easeInOut(duration: 0.5)) {
                    showEnglishGreeting.toggle()
                }
            }
        }
    }

    private var languageWheel: some View {
        VStack(spacing: 4) {
            wheelRow(for: choices[(index + choices.count - 1) % choices.count], offset: -1)
            wheelRow(for: selected, offset: 0)
            wheelRow(for: choices[(index + 1) % choices.count], offset: 1)
        }
        .frame(width: 286, height: 208)
        .padding(.vertical, 7)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(mainInk.opacity(dark ? 0.055 : 0.035))
                .overlay {
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .strokeBorder(mainInk.opacity(0.055), lineWidth: 1)
                }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 13)
                .onEnded { gesture in
                    if gesture.translation.height < -22 {
                        select(choices[(index + 1) % choices.count])
                    } else if gesture.translation.height > 22 {
                        select(choices[(index + choices.count - 1) % choices.count])
                    }
                }
        )
        .accessibilityIdentifier("bloombox.wizard.language.carousel")
    }

    private func wheelRow(for language: BloomBoxWizardLanguage, offset: Int) -> some View {
        Button {
            select(language)
        } label: {
            Text(language.title)
                .font(.system(size: offset == 0 ? 23 : 18,
                              weight: offset == 0 ? .heavy : .medium,
                              design: .rounded))
                .foregroundStyle(offset == 0 ? (accentHex == "E5B83F" ? Color.black : Color.white)
                                                 : mainInk.opacity(0.34))
                .frame(width: offset == 0 ? 254 : 232, height: offset == 0 ? 66 : 49)
                .background {
                    if offset == 0 {
                        RoundedRectangle(cornerRadius: 21, style: .continuous)
                            .fill(accent)
                    }
                }
                .scaleEffect(offset == 0 ? 1 : 0.95)
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(offset == 0 ? .isSelected : [])
        .accessibilityIdentifier("bloombox.wizard.language.\(language.rawValue)")
    }

    private func select(_ language: BloomBoxWizardLanguage) {
        guard preferredLanguage != language.rawValue else { return }
        withAnimation(.spring(response: 0.36, dampingFraction: 0.79)) {
            preferredLanguage = language.rawValue
        }
        UISelectionFeedbackGenerator().selectionChanged()
    }
}

private enum BloomBoxWizardLanguage: String, CaseIterable {
    case english = "en"
    case automatic = "system"
    case spanish = "es"

    var title: String {
        switch self {
        case .english: return "English"
        case .automatic: return "Automático"
        case .spanish: return "Español"
        }
    }
}

/// Reads the device's appearance rather than inheriting BloomBox's dark launcher.
enum BloomBoxWizardSystemAppearance {
    static var current: ColorScheme {
        UIScreen.main.traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    static var preview: ColorScheme {
        switch LiveContainerPreferencesAdapter.defaults.string(forKey: "BloomBoxWizardPreviewAppearanceV1") {
        case "light": return .light
        case "dark": return .dark
        default: return current
        }
    }
}

/// All decorations are drawn in code, not bundled pictures or emoji.
private struct BloomBoxWizardAmbientSymbols: View {
    let isDark: Bool
    let accentHex: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0, paused: reduceMotion)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                let color = BloomBoxWizardPalette.color(accentHex)
                for i in 0..<49 {
                    let xSeed = CGFloat((i * 47 + 29) % 103) / 103
                    let ySeed = CGFloat((i * 71 + 11) % 101) / 101
                    let sizeOfSymbol = CGFloat(5 + ((i * 11) % 9))
                    let phase = Double(i) * 1.413
                    let horizontalSpeed = Double(3 + (i * 5) % 8) * (i.isMultiple(of: 2) ? 1.0 : -1.0)
                    let verticalSpeed = Double(2 + (i * 3) % 6) * (i.isMultiple(of: 3) ? 1.0 : -1.0)
                    let x = wrapped(
                        xSeed * (size.width + 48)
                        + (reduceMotion ? 0 : CGFloat(time * horizontalSpeed + sin(time * 0.24 + phase) * 18)),
                        max: size.width + 48
                    ) - 24
                    let y = wrapped(
                        ySeed * (size.height + 48)
                        + (reduceMotion ? 0 : CGFloat(time * verticalSpeed + cos(time * 0.18 + phase) * 15)),
                        max: size.height + 48
                    ) - 24

                    var drawing = context
                    drawing.translateBy(x: x, y: y)
                    drawing.rotate(by: .degrees(reduceMotion ? 0 : sin(time * 0.13 + phase) * 13))
                    let kind = i % 8
                    let opacity = (isDark ? 0.09 : 0.10) + Double(i % 4) * 0.017
                    let tint = color.opacity(opacity)
                    drawing.stroke(path(for: kind, radius: sizeOfSymbol),
                                   with: .color(tint), style: StrokeStyle(lineWidth: 1.15, lineCap: .round, lineJoin: .round))
                    if kind == 0 {
                        let eyeRadius = max(0.75, sizeOfSymbol * 0.08)
                        for dx in [-sizeOfSymbol * 0.18, sizeOfSymbol * 0.18] {
                            drawing.fill(Path(ellipseIn: CGRect(x: dx - eyeRadius,
                                                               y: -eyeRadius,
                                                               width: eyeRadius * 2,
                                                               height: eyeRadius * 2.5)),
                                         with: .color(tint))
                        }
                    }
                }
            }
        }
    }

    private func wrapped(_ value: CGFloat, max limit: CGFloat) -> CGFloat {
        let remainder = value.truncatingRemainder(dividingBy: limit)
        return remainder >= 0 ? remainder : remainder + limit
    }

    private func path(for kind: Int, radius r: CGFloat) -> Path {
        var path = Path()
        switch kind {
        case 0: // little Mario-like star, with two simple eyes drawn above
            for point in 0..<10 {
                let angle = Double(point) * .pi / 5 - .pi / 2
                let length = point.isMultiple(of: 2) ? r : r * 0.53
                let p = CGPoint(x: CGFloat(cos(angle)) * length,
                                y: CGFloat(sin(angle)) * length)
                if point == 0 { path.move(to: p) } else { path.addLine(to: p) }
            }
            path.closeSubpath()
        case 1: // coin
            path.addEllipse(in: CGRect(x: -r * 0.7, y: -r, width: r * 1.4, height: r * 2))
            path.move(to: CGPoint(x: 0, y: -r * 0.55))
            path.addLine(to: CGPoint(x: 0, y: r * 0.55))
        case 2: // circle
            path.addEllipse(in: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r))
        case 3: // X
            path.move(to: CGPoint(x: -r, y: -r))
            path.addLine(to: CGPoint(x: r, y: r))
            path.move(to: CGPoint(x: r, y: -r))
            path.addLine(to: CGPoint(x: -r, y: r))
        case 4: // square
            path.addRoundedRect(in: CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r),
                                cornerSize: CGSize(width: 2, height: 2))
        case 5: // triangle
            path.move(to: CGPoint(x: 0, y: -r))
            path.addLine(to: CGPoint(x: r, y: r))
            path.addLine(to: CGPoint(x: -r, y: r))
            path.closeSubpath()
        case 6: // tiny apple silhouette and leaf
            path.move(to: CGPoint(x: 0, y: -r * 0.48))
            path.addCurve(to: CGPoint(x: -r * 0.75, y: -r * 0.3),
                          control1: CGPoint(x: -r * 0.24, y: -r * 0.92),
                          control2: CGPoint(x: -r * 0.91, y: -r * 0.69))
            path.addCurve(to: CGPoint(x: -r * 0.32, y: r * 0.86),
                          control1: CGPoint(x: -r * 1.1, y: r * 0.16),
                          control2: CGPoint(x: -r * 0.64, y: r * 0.91))
            path.addQuadCurve(to: CGPoint(x: r * 0.34, y: r * 0.86),
                              control: CGPoint(x: 0, y: r * 0.65))
            path.addCurve(to: CGPoint(x: r * 0.75, y: -r * 0.3),
                          control1: CGPoint(x: r * 0.64, y: r * 0.91),
                          control2: CGPoint(x: r * 1.08, y: r * 0.16))
            path.addCurve(to: CGPoint(x: 0, y: -r * 0.48),
                          control1: CGPoint(x: r * 0.89, y: -r * 0.69),
                          control2: CGPoint(x: r * 0.24, y: -r * 0.92))
            path.move(to: CGPoint(x: 0, y: -r * 0.6))
            path.addQuadCurve(to: CGPoint(x: r * 0.55, y: -r * 0.96),
                              control: CGPoint(x: r * 0.13, y: -r * 1.12))
        default: // little Android robot
            path.move(to: CGPoint(x: -r * 0.78, y: 0))
            path.addQuadCurve(to: CGPoint(x: r * 0.78, y: 0),
                              control: CGPoint(x: 0, y: -r * 1.42))
            path.addLine(to: CGPoint(x: r * 0.78, y: r * 0.65))
            path.addLine(to: CGPoint(x: -r * 0.78, y: r * 0.65))
            path.closeSubpath()
            path.move(to: CGPoint(x: -r * 0.85, y: -r))
            path.addLine(to: CGPoint(x: -r * 0.55, y: -r * 0.62))
            path.move(to: CGPoint(x: r * 0.85, y: -r))
            path.addLine(to: CGPoint(x: r * 0.55, y: -r * 0.62))
        }
        return path
    }
}
