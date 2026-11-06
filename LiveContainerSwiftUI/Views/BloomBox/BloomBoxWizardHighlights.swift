import SwiftUI

/// Short, animated feature tour between profile creation and setup.
/// All graphics are native SF Symbols and shapes, with no remote artwork.
struct BloomBoxWizardHighlightsView: View {
    let accentHex: String
    let onBack: () -> Void
    let onNext: () -> Void

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
            RadialGradient(colors: [accent.opacity(0.16), .clear],
                           center: .topLeading, startRadius: 0, endRadius: 470)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            BloomBoxWizardAmbientSymbols(isDark: scheme == .dark, accentHex: accentHex)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            VStack(spacing: 14) {
                HStack {
                    Label("BloomBox", systemImage: "sparkle")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Spacer()
                    Text("03 / 05")
                        .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                }
                .foregroundStyle(ink.opacity(0.7))
                .padding(.horizontal, 28)
                .padding(.top, 20)

                Spacer(minLength: 3)

                VStack(spacing: 9) {
                    Text(spanish ? "Todo en un solo lugar" : "Everything in one place")
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                        .multilineTextAlignment(.center)
                    Text(spanish ? "Estas son algunas de las cosas que hacen especial a BloomBox."
                                 : "Here's what makes BloomBox yours.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(ink.opacity(0.61))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 25)

                VStack(spacing: 12) {
                    featureCard(symbol: "square.grid.2x2.fill",
                                title: spanish ? "Tu escritorio" : "Your home",
                                detail: spanish ? "Widgets vivos, temas y fondos animados" : "Living widgets, themes and animated wallpapers",
                                color: accent, index: 0)
                    featureCard(symbol: "gamecontroller.fill",
                                title: "GameBox",
                                detail: spanish ? "Tus juegos, controles y portadas" : "Games, controllers and artwork",
                                color: Color(red: 0.31, green: 0.65, blue: 0.90), index: 1)
                    featureCard(symbol: "cpu.fill",
                                title: "RAM+",
                                detail: spanish ? "Permiso de memoria ampliada para apps compatibles"
                                                : "Increased memory limit for compatible apps",
                                color: Color(red: 0.65, green: 0.44, blue: 0.91), index: 2)
                    featureCard(symbol: "bolt.fill",
                                title: "JIT",
                                detail: spanish ? "Acelera apps compatibles cuando se activa"
                                                : "Unlocks JIT for supported apps when enabled",
                                color: Color(red: 0.97, green: 0.64, blue: 0.22), index: 3)
                    featureCard(symbol: "person.2.fill",
                                title: spanish ? "Tus perfiles" : "Your profiles",
                                detail: spanish ? "Un espacio de datos distinto por persona"
                                                : "Separate app data for each person",
                                color: Color(red: 0.32, green: 0.72, blue: 0.60), index: 4)
                }
                .padding(.horizontal, 25)

                Spacer(minLength: 4)

                HStack(spacing: 12) {
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(ink)
                            .frame(width: 60, height: 54)
                            .background(ink.opacity(0.08), in: RoundedRectangle(cornerRadius: 18))
                    }
                    .accessibilityLabel(spanish ? "Atrás" : "Back")

                    Button(action: onNext) {
                        HStack(spacing: 9) {
                            Text(spanish ? "Preparar mi iPhone" : "Set up my iPhone")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(accentHex == "E5B83F" ? Color.black : .white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(accent, in: RoundedRectangle(cornerRadius: 18))
                    }
                    .accessibilityIdentifier("bloombox.wizard.highlights.next")
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 25)
                .padding(.bottom, 22)
            }
        }
        .onAppear { appeared = true }
    }

    private func featureCard(symbol: String, title: String, detail: String,
                             color: Color, index: Int) -> some View {
        HStack(spacing: 15) {
            Image(systemName: symbol)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 53, height: 53)
                .background(color.opacity(0.13), in: RoundedRectangle(cornerRadius: 17))
                .rotationEffect(.degrees(appeared && !reduceMotion ? 0 : -5))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundStyle(ink)
                Text(detail)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(ink.opacity(0.60))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "sparkle")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color.opacity(0.55))
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ink.opacity(scheme == .dark ? 0.06 : 0.035),
                    in: RoundedRectangle(cornerRadius: 23, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 23)
            .strokeBorder(color.opacity(0.16), lineWidth: 1))
        .offset(y: appeared || reduceMotion ? 0 : CGFloat(12 + index * 3))
        .opacity(appeared ? 1 : 0.15)
        .animation(reduceMotion ? nil : .spring(response: 0.48, dampingFraction: 0.78)
            .delay(Double(index) * 0.08), value: appeared)
    }
}

/// Live checks with a direct route to the existing RAM+ and JIT setup screens.
/// Pairing is not the same as a successful JIT attach, so it never claims JIT is active.
struct BloomBoxWizardValidationView: View {
    let accentHex: String
    let isPreview: Bool
    let onBack: () -> Void
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var ram = BloomBoxRAMPlus.shared
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @AppStorage("LCJITEnablerType", store: LiveContainerPreferencesAdapter.defaults)
    private var jitProvider = 0
    @State private var hasPairing = false
    @State private var showRAM = false
    @State private var showJIT = false

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
    private var ramVerified: Bool { ram.validation.confirmed }
    private var jitConfigured: Bool {
        jitProvider == JITEnablerType.BuiltIn.rawValue && hasPairing
    }

    var body: some View {
        ZStack {
            background.ignoresSafeArea()
            RadialGradient(colors: [accent.opacity(0.16), .clear],
                           center: .top, startRadius: 0, endRadius: 510)
                .ignoresSafeArea()

            BloomBoxWizardAmbientSymbols(isDark: scheme == .dark, accentHex: accentHex)
                .ignoresSafeArea()
                .accessibilityHidden(true)
                .allowsHitTesting(false)

            ScrollView {
                VStack(spacing: 19) {
                    HStack {
                        Label("BloomBox", systemImage: "sparkle")
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                        Spacer()
                        Text("04 / 05")
                            .font(.system(size: 12, weight: .medium, design: .rounded).monospacedDigit())
                    }
                    .foregroundStyle(ink.opacity(0.70))
                    .padding(.top, 20)

                    VStack(spacing: 10) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 36, weight: .medium))
                            .foregroundStyle(accent)
                            .frame(width: 85, height: 85)
                            .background(accent.opacity(0.13), in: Circle())

                        Text(spanish ? "Prepara BloomBox" : "Prepare BloomBox")
                            .font(.system(size: 29, weight: .heavy, design: .rounded))
                            .foregroundStyle(ink)
                        Text(spanish
                             ? "Dos funciones importantes. Revisaremos qué está listo y te ayudaremos con lo que falte."
                             : "Two important features. We'll check what's ready and help you set up the rest.")
                            .font(.system(size: 14, design: .rounded))
                            .foregroundStyle(ink.opacity(0.63))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 8)

                    statusCard(
                        symbol: "cpu.fill", title: "RAM+",
                        description: spanish
                            ? "Aumenta el límite de memoria que iOS permite a las apps compatibles."
                            : "Raises iOS memory limits for compatible apps.",
                        status: ramVerified
                            ? (spanish ? "Permiso confirmado en esta instalación"
                                       : "Permission confirmed in this installation")
                            : (spanish ? ram.status : "Permission not confirmed"),
                        good: ramVerified,
                        buttonTitle: ramVerified
                            ? (spanish ? "Ver detalles" : "View details")
                            : (spanish ? "Configurar RAM+" : "Set up RAM+"),
                        tint: Color(red: 0.68, green: 0.49, blue: 0.96)
                    ) {
                        if !isPreview { showRAM = true }
                    }

                    statusCard(
                        symbol: "bolt.shield.fill", title: "JIT",
                        description: spanish
                            ? "Permite iniciar con JIT las apps compatibles cuando lo necesitan."
                            : "Enables JIT when compatible guest apps need it.",
                        status: jitConfigured
                            ? (spanish ? "Emparejado: falta confirmar JIT al abrir una app"
                                       : "Paired: confirm JIT on a guest launch")
                            : (spanish ? "Configuración o emparejamiento pendiente"
                                       : "Setup or pairing needed"),
                        good: jitConfigured,
                        buttonTitle: spanish ? "Configurar JIT" : "Set up JIT",
                        tint: Color(red: 0.99, green: 0.67, blue: 0.28)
                    ) {
                        if !isPreview { showJIT = true }
                    }

                    Label(spanish
                          ? "JIT requiere Modo desarrollador y LocalDevVPN. Tener el emparejamiento guardado no garantiza una activación correcta."
                          : "JIT needs Developer Mode and LocalDevVPN. Saved pairing does not guarantee a successful JIT launch.",
                          systemImage: "info.circle")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(ink.opacity(0.63))
                        .fixedSize(horizontal: false, vertical: true)

                    if isPreview {
                        Label(spanish ? "Simulación: no solicitaremos permisos ni modificaremos perfiles."
                                      : "Preview: no permission requests or profile changes.",
                              systemImage: "eye")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(ink.opacity(0.68))
                    }

                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(ink)
                                .frame(width: 60, height: 56)
                                .background(ink.opacity(0.09), in: RoundedRectangle(cornerRadius: 18))
                        }
                        .accessibilityLabel(spanish ? "Atrás" : "Back")

                        Button(action: onFinish) {
                            HStack(spacing: 8) {
                                Text(isPreview
                                     ? (spanish ? "Cerrar prueba" : "Close preview")
                                     : (spanish ? "Empezar a usar BloomBox" : "Start using BloomBox"))
                                Image(systemName: "arrow.right")
                            }
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(accentHex == "E5B83F" ? .black : .white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(accent, in: RoundedRectangle(cornerRadius: 18))
                        }
                        .accessibilityIdentifier("bloombox.wizard.validation.finish")
                    }
                    .buttonStyle(.plain)

                    if !isPreview && (!ramVerified || !jitConfigured) {
                        Text(spanish
                             ? "Puedes terminar la configuración después en Módulos. Nunca desinstales BloomBox para activar RAM+."
                             : "You can finish setup later in Modules. Never uninstall BloomBox to enable RAM+.")
                            .font(.system(size: 11, design: .rounded))
                            .foregroundStyle(ink.opacity(0.57))
                            .multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: 500)
                .padding(.horizontal, 26)
                .padding(.bottom, 30)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear(perform: refresh)
        .onChange(of: scenePhase) { phase in
            if phase == .active { refresh() }
        }
        .sheet(isPresented: $showRAM, onDismiss: refresh) {
            NavigationView {
                BloomBoxRAMPlusView {
                    if let url = URL(string: "sidestore://") {
                        UIApplication.shared.open(url)
                    }
                }
                .navigationTitle("RAM+")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(spanish ? "Listo" : "Done") { showRAM = false }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .sheet(isPresented: $showJIT, onDismiss: refresh) {
            BloomBoxJITSetup()
        }
    }

    private func refresh() {
        ram.refresh()
        hasPairing = BloomBoxJITPairingStorage().hasRecord
    }

    private func statusCard(symbol: String, title: String, description: String,
                            status: String, good: Bool, buttonTitle: String,
                            tint: Color, action: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 15) {
                Image(systemName: symbol)
                    .font(.system(size: 27, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 61, height: 61)
                    .background(tint.opacity(0.15),
                                in: RoundedRectangle(cornerRadius: 20))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.system(size: 22, weight: .heavy, design: .rounded))
                        .foregroundStyle(ink)
                    Text(description)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(ink.opacity(0.59))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: good ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(good ? .green : .orange)
                Text(status)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(ink.opacity(0.81))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Button(action: action) {
                HStack {
                    Text(buttonTitle)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                }
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(tint)
                .padding(.horizontal, 16)
                .frame(height: 43)
                .background(tint.opacity(0.12),
                            in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(isPreview)
            .opacity(isPreview ? 0.55 : 1)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ink.opacity(scheme == .dark ? 0.067 : 0.035),
                    in: RoundedRectangle(cornerRadius: 26))
        .overlay(RoundedRectangle(cornerRadius: 26)
            .strokeBorder(tint.opacity(0.20), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}
