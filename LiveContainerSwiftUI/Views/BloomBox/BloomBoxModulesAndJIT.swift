import SwiftUI
import CryptoKit
import PhotosUI
import UniformTypeIdentifiers

// BloomBox-owned Modules, JIT and Connectivity screens. Keeping them separate
// from Home reduces Xcode type-check load and isolates future UI rewrites.

struct BloomBoxThemesIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [
                    Color(red: 0.35, green: 0.18, blue: 0.70),
                    Color(red: 0.55, green: 0.30, blue: 0.89),
                    Color(red: 0.21, green: 0.51, blue: 0.86)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(Color.white.opacity(0.20))
                .frame(width: size * 0.44, height: size * 0.46)
                .rotationEffect(.degrees(-18))
                .offset(x: -size * 0.075, y: size * 0.045)
            RoundedRectangle(cornerRadius: size * 0.10, style: .continuous)
                .fill(LinearGradient(colors: [
                    .white.opacity(0.96),
                    Color(red: 0.83, green: 0.84, blue: 1)
                ], startPoint: .topLeading, endPoint: .bottomTrailing))
                .frame(width: size * 0.43, height: size * 0.46)
                .rotationEffect(.degrees(10))
                .offset(x: size * 0.085, y: -size * 0.025)
                .overlay {
                    Image(systemName: "sparkles")
                        .font(.system(size: size * 0.23, weight: .semibold))
                        .foregroundStyle(Color(red: 0.48, green: 0.27, blue: 0.79))
                        .offset(x: size * 0.09, y: -size * 0.02)
                }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Temas")
    }
}

struct BloomBoxModulesIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.29, green: 0.48, blue: 1),
                             Color(red: 0.27, green: 0.18, blue: 0.85),
                             Color(red: 0.42, green: 0.23, blue: 0.91)],
                    startPoint: .topLeading, endPoint: .bottomTrailing))
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: size * 0.47, weight: .medium))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.38), radius: size * 0.08)
        }
        .frame(width: size, height: size)
        .overlay {
            RoundedRectangle(cornerRadius: size * 0.23, style: .continuous)
                .strokeBorder(.white.opacity(0.32), lineWidth: 1.1)
        }
        .accessibilityLabel("Módulos de BloomBox")
    }
}

struct BloomBoxModulesPanel: View {
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var englishUI: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    @AppStorage("BloomBoxRAMPlusExperimentalControls", store: LCUtils.appGroupUserDefault)
    private var ramExperimentalControlsEnabled = false
    @AppStorage("BloomBoxJITTryMeloNXScriptForOtherAppsV2", store: LCUtils.appGroupUserDefault)
    private var melonScriptCrossAppEnabled = false
    @AppStorage("BloomBoxJITUseLegacyLaunchUI", store: LCUtils.appGroupUserDefault)
    private var legacyJITUI = false
    @AppStorage(BloomBoxProfileStore.activeKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeActiveID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey, store: LiveContainerPreferencesAdapter.defaults)
    private var themeProfilesData = Data()
    private var profileAccent: Color {
        BloomBoxProfileTheme.color(activeID: themeActiveID, profilesData: themeProfilesData)
    }
    @State private var showWizardPreview = false
    @State private var showJITDemo = false
    @AppStorage("BloomBoxJITDemoUnconfigured", store: LCUtils.appGroupUserDefault)
    private var jitDemoUnconfigured = false
    @AppStorage("BloomBoxWizardPreviewAppearanceV1", store: LCUtils.appGroupUserDefault)
    private var wizardPreviewAppearance = "system"

    enum Destination { case jit, desktop, interface, wallpaper, apps, settings, tweaks, sidestore }
    enum Module: String, CaseIterable, Identifiable {
        case ram, jit, desktop, connectivity, privacy, autoupdate, experimental
        var id: String { rawValue }

        var title: String {
            switch self {
            case .ram: return "RAM+"
            case .jit: return "JIT"
            case .desktop: return "Escritorio"
            case .connectivity: return "Conectividad"
            case .privacy: return "Privacidad"
            case .autoupdate: return "AutoUpdate"
            case .experimental: return "Experimental"
            }
        }
        var subtitle: String {
            switch self {
            case .ram: return "Memoria ampliada"
            case .jit: return "Setup y proveedores"
            case .desktop: return "Personalización"
            case .connectivity: return "Internet y red"
            case .privacy: return "Aislamiento y permisos"
            case .autoupdate: return "Actualizaciones de BloomBox"
            case .experimental: return "Funciones avanzadas"
            }
        }
        var symbol: String {
            switch self {
            case .ram: return "cpu"
            case .jit: return "bolt.fill"
            case .desktop: return "display"
            case .connectivity: return "wifi"
            case .privacy: return "shield.lefthalf.filled"
            case .autoupdate: return "arrow.triangle.2.circlepath.circle.fill"
            case .experimental: return "flask.fill"
            }
        }
        var tint: Color {
            switch self {
            case .ram: return Color(red: 0.80, green: 0.48, blue: 1)
            case .jit: return Color(red: 1, green: 0.73, blue: 0.43)
            case .desktop: return Color(red: 0.31, green: 0.78, blue: 1)
            case .connectivity: return Color(red: 0.35, green: 0.92, blue: 0.68)
            case .privacy: return Color(red: 1, green: 0.48, blue: 0.75)
            case .autoupdate: return Color(red: 0.30, green: 0.68, blue: 1)
            case .experimental: return Color(red: 0.72, green: 0.45, blue: 1)
            }
        }
    }

    let apps: [LCAppModel]
    let onSelect: (Destination) -> Void
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var ramPlus = BloomBoxRAMPlus.shared
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    private var columns: [GridItem] {
        dynamicTypeSize.isAccessibilitySize
            ? [GridItem(.flexible(), spacing: 12)]
            : [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 23) {
                    HStack(spacing: 16) {
                        BloomBoxModulesIcon(size: 55)
                            .shadow(color: profileAccent.opacity(0.32), radius: 18)
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Módulos")
                                .font(.system(size: 31, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Tu centro de control, sin menús escondidos")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .padding(.top, 16)
                    HStack(spacing: 10) {
                        Label("\(Module.allCases.count) herramientas", systemImage: "square.grid.2x2.fill")
                            .foregroundStyle(.white.opacity(0.72))
                        Spacer()
                        Label(ramPlus.validation.confirmed ? "RAM+ activa" :
                              (ramPlus.needsAttention ? "Revisar RAM+" : "RAM+ sin confirmar"),
                              systemImage: ramPlus.validation.confirmed ? "checkmark.shield.fill" : "cpu")
                            .foregroundStyle(ramPlus.validation.confirmed ? Color.green : Color.white.opacity(0.78))
                    }
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 3)
                    .accessibilityElement(children: .combine)
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Module.allCases) { module in
                            NavigationLink(destination: detail(for: module)) {
                                tile(module)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.modules.\(module.rawValue)")
                        }
                    }
                    Button { onSelect(.settings) } label: {
                        moduleShortcut(englishUI ? "LiveContainer Settings" : "Ajustes de LiveContainer",
                                       subtitle: englishUI ? "App and container preferences" : "Configuración de apps y contenedores",
                                       symbol: "gearshape.fill", color: .gray)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bloombox.modules.livecontainer.settings")
                    Text("Accesos directos a funciones reales. JIT y RAM+ conservan sus comprobaciones y permisos originales.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.66))
                        .padding(.horizontal, 4)
                }
                .padding(18)
            }
            .background(moduleBackdrop)
            .foregroundStyle(.white)
            .tint(profileAccent)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }.font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .navigationViewStyle(.stack)
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: $showWizardPreview) {
            BloomBoxWizardFlowView(isPreview: true) {
                showWizardPreview = false
            }
            .preferredColorScheme(BloomBoxWizardSystemAppearance.preview)
        }
    }

    private func tile(_ module: Module) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: module.symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(module.tint)
                .frame(width: 49, height: 49)
                .background(module.tint.opacity(0.18),
                            in: RoundedRectangle(cornerRadius: 14))
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(BloomBoxL10n.t(module.title))
                    .font(.system(size: 17, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.80)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.65))
            }
            Text(BloomBoxL10n.t(module.subtitle))
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.72))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(minHeight: 154)
        .background {
            // Transparent color surfaces, intentionally no Liquid Glass.
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(red: 0.105, green: 0.12, blue: 0.18).opacity(0.88))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(LinearGradient(colors: [profileAccent.opacity(0.16),
                                                      module.tint.opacity(0.12), .clear],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(LinearGradient(colors: [profileAccent.opacity(0.48), module.tint.opacity(0.32)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(BloomBoxL10n.t(module.title)). \(BloomBoxL10n.t(module.subtitle))")
    }

    @ViewBuilder private func detail(for module: Module) -> some View {
        switch module {
        case .ram:
            ramDetail
        case .jit:
            BloomBoxJITControlPanel(apps: apps)
        case .desktop:
            desktopDetail
        case .connectivity:
            BloomBoxConnectivityModule(apps: apps)
        case .autoupdate:
            BloomBoxAutoUpdateSettingsView()
        case .privacy, .experimental:
            moduleDetail(module)
        }
    }

    private var moduleBackdrop: some View {
        BloomBoxProfileThemeBackdrop()
    }

    private var desktopDetail: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Label(englishUI ? "Home Screen" : "Escritorio", systemImage: "display")
                    .font(.title2.bold())
                Text(englishUI
                     ? "Wallpapers, widgets, pages and icons in one place. Apps, stores and JIT have their own shortcuts."
                     : "Fondos, widgets, páginas e iconos reunidos en un solo lugar. Las apps, las tiendas y JIT tienen sus propios accesos.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.7))
                Button { onSelect(.desktop) } label: {
                    moduleShortcut(englishUI ? "Customize Home" : "Personalizar escritorio",
                                   subtitle: englishUI ? "Wallpapers, widgets, pages & icons" : "Fondos, widgets, páginas e iconos",
                                   symbol: "paintbrush.pointed.fill", color: .pink)
                }
                Button { onSelect(.interface) } label: {
                    moduleShortcut(englishUI ? "Interface options" : "Opciones de interfaz",
                                   subtitle: englishUI ? "Home screen appearance" : "Apariencia del inicio",
                                   symbol: "slider.horizontal.3", color: .cyan)
                }
            }
            .buttonStyle(.plain)
            .padding(22)
        }
        .background(moduleBackdrop)
        .foregroundStyle(.white)
        .navigationTitle("Escritorio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func moduleShortcut(_ title: String, subtitle: String, symbol: String, color: Color) -> some View {
        HStack(spacing: 16) {
            Image(systemName: symbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 53, height: 53)
                .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 5) {
                Text(BloomBoxL10n.t(title)).font(.headline)
                Text(BloomBoxL10n.t(subtitle)).font(.footnote).foregroundStyle(.white.opacity(0.65))
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption.bold()).foregroundStyle(.white.opacity(0.55))
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.18).opacity(0.9), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).strokeBorder(color.opacity(0.38)))
    }

    private var ramDetail: some View {
        BloomBoxRAMPlusView { onSelect(.sidestore) }
    }

    private func moduleDetail(_ module: Module) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
            Label(LocalizedStringKey(module.title), systemImage: module.symbol)
                .font(.title2.bold())
                Text(BloomBoxL10n.t(detailDescription(module)))
                    .font(.body)
                    .foregroundStyle(.secondary)
            Button {
                switch module {
                case .jit: onSelect(.jit)
                case .desktop: onSelect(.desktop)
                case .connectivity, .privacy: onSelect(.apps)
                case .experimental: onSelect(.settings)
                case .ram: break
                }
            } label: {
                Label(BloomBoxL10n.t(detailButton(module)), systemImage: "arrow.up.right.square")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("bloombox.modules.\(module.rawValue).open")
            if module == .experimental {
                VStack(alignment: .leading, spacing: 12) {
                    Label("Experimentos · Funciones avanzadas", systemImage: "flask.fill")
                        .font(.headline)
                    Picker("Idioma de BloomBox", selection: $preferredLanguage) {
                        Text("Automático (iPhone)").tag("system")
                        Text("Español").tag("es")
                        Text("English").tag("en")
                    }
                    .accessibilityIdentifier("bloombox.experiments.language.picker")
                    Text("Elige el idioma de BloomBox y sus noticias. Automático usa el idioma del iPhone; no modifica el idioma del sistema.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    Picker("Aspecto de prueba del wizard", selection: $wizardPreviewAppearance) {
                        Text("Automático (iPhone)").tag("system")
                        Text("Claro · blanco suave").tag("light")
                        Text("Oscuro · negro").tag("dark")
                    }
                    .accessibilityIdentifier("bloombox.experiments.wizard.appearance")
                    Text("Solo cambia el aspecto del wizard de prueba. No altera el modo claro/oscuro del iPhone.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        showWizardPreview = true
                    } label: {
                        Label("Simular primer arranque del wizard", systemImage: "sparkles.rectangle.stack")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.wizard.preview")
                    Text("Reproduce las dos pantallas. No borra perfiles, contenedores, apps ni fotos; tampoco reinicia el primer arranque. El idioma seleccionado sí se guarda.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        BloomBoxProfileManagementView()
                    } label: {
                        Label("Perfiles · crear y cambiar", systemImage: "person.2.crop.square.stack")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.profiles.open")
                    Text("El primer perfil conserva sus contenedores. Los perfiles nuevos crean un contenedor aislado por app cuando la abres.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    NavigationLink {
                        LCStorageManagementView()
                    } label: {
                        Label("Almacenamiento · BloomBox, SideStore y apps", systemImage: "externaldrive.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.storage.open")
                    Text("Mide el espacio utilizado por las apps invitadas, SideStore y BloomBox. Permite identificar datos, cachés y archivos temporales sin borrarlos.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Divider()
                    Button {
                        // This only controls the onboarding rehearsal screen.
                        // Do not clear pairing, disable JIT, change provider or touch VPN.
                        jitDemoUnconfigured = true
                        showJITDemo = true
                    } label: {
                        Label(englishUI ? "Preview JIT first-time setup" : "Simular JIT sin activar",
                              systemImage: "video.badge.waveform")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.jit.demo")
                    Text(englishUI
                         ? "Opens the new JIT screen as if setup were missing, ready for your tutorial video. Does not change the real pairing, JIT, VPN or app settings. Use 'Exit demo mode' to restore the real view."
                         : "Abre la nueva pantalla JIT como si todavía no estuviera configurada para grabar tu video. No cambia el pairing, JIT ni VPN reales. Pulsa «Salir de simulación» para volver a la vista normal.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Divider()
                    Toggle("Usar pantalla JIT anterior", isOn: $legacyJITUI)
                        .tint(.purple)
                        .accessibilityIdentifier("bloombox.experiments.jitLegacyUI.toggle")
                    Text("Desactivado: aviso flotante que se hace bolita mientras se activa el JIT. Activado: regresa a la pantalla completa de mensajes. No cambia el método de activación ni los scripts.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Divider()
                    Toggle("Probar script JIT de MeloNX en otras apps", isOn: $melonScriptCrossAppEnabled)
                        .tint(Color(red: 0.72, green: 0.45, blue: 1))
                        .accessibilityIdentifier("bloombox.experiments.melonScriptCrossApp.toggle")
                    Text("Interruptor maestro de seguridad: permite las pruebas de script solo en las apps que selecciones abajo. No cambia el JIT de MeloNX ni activa JIT en todas las apps.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    NavigationLink {
                        BloomBoxJITGuestControlsView(apps: apps)
                    } label: {
                        Label("Pruebas avanzadas del script MeloNX", systemImage: "flask.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .accessibilityIdentifier("bloombox.experiments.jitApps.open")
                    Text("Los interruptores habituales están en Módulos > JIT. Aquí se conserva la prueba experimental del script MeloNX en otras apps.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if melonScriptCrossAppEnabled {
                        Label("La prueba solo se aplicará a las apps seleccionadas. Un motor incompatible puede quedarse congelado o cerrarse.", systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    Divider()
                    Toggle("Habilitar botones RAM+ para pruebas", isOn: $ramExperimentalControlsEnabled)
                        .tint(Color(red: 0.72, green: 0.45, blue: 1))
                        .accessibilityIdentifier("bloombox.experiments.ramControls.toggle")
                    Text("Permite volver a abrir los controles de reinstalación cuando RAM+ ya está activa. No desactiva RAM+, no solicita permisos a Apple ni reinstala nada al encender el interruptor.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    if ramExperimentalControlsEnabled {
                        Text("La reinstalación real podría perder RAM+ si la nueva firma no conserva el permiso. Comprueba tu firma antes de instalar.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                        NavigationLink {
                            BloomBoxRAMPlusView { onSelect(.sidestore) }
                        } label: {
                            Label("Abrir controles de RAM+", systemImage: "cpu")
                        }
                        .accessibilityIdentifier("bloombox.experiments.ramControls.open")
                    }
                }
                Button("Abrir Tweak Store") { onSelect(.tweaks) }
                    .buttonStyle(.bordered)
            }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .background(moduleBackdrop)
        .navigationTitle(LocalizedStringKey(module.title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showJITDemo, onDismiss: {
            // No persistent "unconfigured" state after the recording closes.
            jitDemoUnconfigured = false
        }) {
            LiveBoardJITSetup()
        }
    }

    private func detailDescription(_ module: Module) -> String {
        switch module {
        case .jit: return "Accede a los proveedores JIT y a su configuración existente."
        case .desktop: return "Abre los controles de escritorio: apariencia, widgets, páginas y personalización."
        case .connectivity: return "El acceso a internet se configura por aplicación desde su administración. No se cambia la conectividad de todo el iPhone."
        case .privacy: return "Revisa las opciones de aislamiento disponibles en cada aplicación instalada. Estas funciones no modifican permisos de iOS."
        case .experimental: return "Consulta las herramientas y opciones avanzadas que ya están disponibles en BloomBox."
        case .ram: return ""
        }
    }

    private func detailButton(_ module: Module) -> String {
        switch module {
        case .jit: return "Configurar JIT"
        case .desktop: return "Abrir controles del escritorio"
        case .connectivity, .privacy: return "Administrar aplicaciones"
        case .experimental: return "Abrir ajustes avanzados"
        case .ram: return ""
        }
    }
}


struct BloomBoxModulesSheetBackground: ViewModifier {
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 16.4, *) {
            content.presentationBackground(.clear)
        } else {
            content
        }
    }
}

/// Self-contained destination: later move its NavigationLink from Experimental to
/// Modules > JIT without migrating stored choices or changing the launch coordinator.
/// Built-in JIT control surface: every guest has independent launch settings.
private struct BloomBoxJITControlPanel: View {
    let apps: [LCAppModel]
    @State private var search = ""
    @State private var importing = false
    @State private var target: LCAppModel?
    @State private var scriptError: String?
    @State private var logAppName: String?
    @State private var logRecordID: UUID?
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault)
    private var provider = JITEnablerType.SideJITServer.rawValue

    private var installed: [LCAppModel] {
        var ids = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            !app.appInfo.relativeBundlePath.isEmpty &&
            ids.insert(app.appInfo.relativeBundlePath).inserted
        }.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }
    private var visible: [LCAppModel] {
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        return q.isEmpty ? installed : installed.filter {
            $0.displayName.localizedCaseInsensitiveContains(q) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(q)
        }
    }
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Label("JIT", systemImage: "bolt.fill").font(.title2.bold()).foregroundStyle(.orange)
                NavigationLink {
                    LiveBoardJITSetup(embedded: true)
                } label: {
                    HStack(spacing: 13) {
                        Image(systemName: "bolt.shield.fill")
                            .font(.title2).foregroundStyle(.orange)
                            .frame(width: 48, height: 48)
                            .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Habilitar JIT").font(.headline)
                            Text("Pairing, LocalDevVPN y conexión")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(14).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bloombox.modules.jit.enable")
                NavigationLink {
                    BloomBoxJITLogHistoryView()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "text.book.closed.fill")
                            .foregroundStyle(.purple)
                            .frame(width: 40, height: 40)
                            .background(Color.purple.opacity(0.15), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Historial de JIT").font(.headline)
                            Text("Logs completos de activaciones y fallos")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                    .padding(14).background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 17))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("bloombox.modules.jit.history")

                HStack {
                    Text("JIT por aplicación").font(.headline)
                    Spacer()
                    Text(String(installed.count) + " apps").font(.caption).foregroundStyle(.secondary)
                }
                Text("Encendido: solicita JIT al abrir. Apagado: abre sin JIT. Universal por defecto excepto MeloNX 2.6. Mantén presionada una app para importar scripts o consultar sus logs.")
                    .font(.footnote).foregroundStyle(.secondary)
                if provider != JITEnablerType.BuiltIn.rawValue {
                    Label("Para scripts integrados, elige Built-in JIT en Habilitar JIT.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.orange)
                }
                TextField("Buscar aplicación", text: $search)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .padding(12).background(Color.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 12))
                ForEach(visible, id: \.appInfo.relativeBundlePath) { app in
                    BloomBoxJITSwitchRow(
                        app: app,
                        importScript: { target = app; importing = true },
                        viewLatestLog: {
                            logRecordID = BloomBoxJITLogStore.shared.attempts.first {
                                $0.appName.caseInsensitiveCompare(app.displayName) == .orderedSame
                            }?.id
                            logAppName = app.displayName
                        },
                        viewLogHistory: {
                            logRecordID = nil
                            logAppName = app.displayName
                        })

                }
                if visible.isEmpty {
                    Text("No hay aplicaciones que coincidan.").foregroundStyle(.secondary)
                }
                Text("Se aplica al próximo lanzamiento. Algunos emuladores requieren scripts propios; evita ejecutarlos si el iPhone se está calentando.")
                    .font(.caption).foregroundStyle(.orange)
            }.padding(18)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).ignoresSafeArea())
        .navigationTitle("JIT").navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { logAppName != nil },
            set: { if !$0 { logAppName = nil; logRecordID = nil } })) {
            NavigationView {
                Group {
                    if let recordID = logRecordID {
                        BloomBoxJITLogDetailView(recordID: recordID)
                    } else {
                        BloomBoxJITLogHistoryView(appName: logAppName)
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Listo") { logAppName = nil; logRecordID = nil }
                    }
                }
            }.navigationViewStyle(.stack)
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.javaScript], allowsMultipleSelection: false) { result in
            let app = target
            target = nil
            guard let app else { return }
            do {
                guard let url = try result.get().first else { return }
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                guard url.pathExtension.lowercased() == "js" else {
                    throw NSError(domain: "BloomBoxJIT", code: 1, userInfo: [NSLocalizedDescriptionKey: "Elige un archivo .js."])
                }
                let data = try Data(contentsOf: url)
                guard !data.isEmpty, data.count <= 512 * 1024,
                      String(data: data, encoding: .utf8) != nil else {
                    throw NSError(domain: "BloomBoxJIT", code: 2, userInfo: [NSLocalizedDescriptionKey: "El script debe ser UTF-8 y tener máximo 512 KB."])
                }
                app.jitLaunchScriptJs = data.base64EncodedString()
            } catch {
                scriptError = error.localizedDescription
            }
        }
        .alert("No se pudo importar el script", isPresented: Binding(
            get: { scriptError != nil },
            set: { if !$0 { scriptError = nil } })) {
            Button("Aceptar") { scriptError = nil }
        } message: { Text(scriptError ?? "") }
    }
}

private struct BloomBoxJITSwitchRow: View {
    @ObservedObject var app: LCAppModel
    let importScript: () -> Void
    let viewLatestLog: () -> Void
    let viewLogHistory: () -> Void
    @State private var enabled: Bool
    init(app: LCAppModel, importScript: @escaping () -> Void,
         viewLatestLog: @escaping () -> Void, viewLogHistory: @escaping () -> Void) {
        self.app = app
        self.importScript = importScript
        self.viewLatestLog = viewLatestLog
        self.viewLogHistory = viewLogHistory
        let mode = BloomBoxJITGuestPolicy.mode(
            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
        let guest = Bundle(path: app.appInfo.bundlePath())
        let melon = BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: guest?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
        _enabled = State(initialValue: BloomBoxJITGuestPolicy.wantsJIT(
            automatic: app.appInfo.isJITNeeded || app.appInfo.is32bit || melon,
            forced: nil, mode: mode))
    }
    private var specialMeloNX: Bool {
        let guest = Bundle(path: app.appInfo.bundlePath())
        return BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: guest?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "app.fill").foregroundStyle(.purple)
                .frame(width: 40, height: 40)
                .background(Color.purple.opacity(0.16), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName).font(.subheadline.weight(.semibold)).lineLimit(1)
                Text(LocalizedStringKey(app.jitLaunchScriptJs?.isEmpty == false ? "Script personalizado" :
                     specialMeloNX ? "Script propio de MeloNX" : "Universal JIT"))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Toggle("JIT " + app.displayName, isOn: $enabled).labelsHidden().tint(.orange)
                .onChange(of: enabled) { on in
                    BloomBoxJITGuestPolicy.setMode(on ? .enabled : .disabled,
                        for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
                }
                .accessibilityIdentifier("bloombox.modules.jit.app.toggle")
        }
        .padding(14)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 16))
        .contentShape(Rectangle())
        .contextMenu {
            Menu {
                Button {
                    app.uiOrientationLock = .Disabled
                } label: {
                    Label("Automático", systemImage: app.uiOrientationLock == .Disabled ? "checkmark" : "iphone")
                }
                Button {
                    app.uiOrientationLock = .Landscape
                } label: {
                    Label("Horizontal", systemImage: app.uiOrientationLock == .Landscape ? "checkmark" : "rectangle")
                }
                Button {
                    app.uiOrientationLock = .Portrait
                } label: {
                    Label("Vertical", systemImage: app.uiOrientationLock == .Portrait ? "checkmark" : "iphone")
                }
            } label: {
                Label("Orientación al iniciar", systemImage: "rotate-cw")
            }
            Button { viewLatestLog() } label: {
                Label("Ver último log JIT", systemImage: "doc.text.magnifyingglass")
            }
            Button { viewLogHistory() } label: {
                Label("Ver historial JIT", systemImage: "clock.arrow.circlepath")
            }
            Divider()
            Button { importScript() } label: {
                Label("Importar script JIT (.js)", systemImage: "doc.badge.plus")
            }
            if app.jitLaunchScriptJs?.isEmpty == false {
                Button { app.jitLaunchScriptJs = nil } label: {
                    Label("Restaurar script predeterminado", systemImage: "arrow.counterclockwise")
                }
            }
        }
    }
}

struct BloomBoxJITGuestControlsView: View {
    let apps: [LCAppModel]
    @State private var searchText = ""
    @AppStorage("BloomBoxJITTryMeloNXScriptForOtherAppsV2", store: LCUtils.appGroupUserDefault)
    private var scriptExperimentEnabled = false
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault)
    private var provider = JITEnablerType.SideJITServer.rawValue

    private var installedApps: [LCAppModel] {
        var seen = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            !app.appInfo.relativeBundlePath.isEmpty &&
            seen.insert(app.appInfo.relativeBundlePath).inserted
        }.sorted {
            $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    private var visibleApps: [LCAppModel] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return installedApps }
        return installedApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(query) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "bolt.badge.clock")
                        .font(.title2)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("JIT por aplicación").font(.title2.bold())
                        Text("Preparación del futuro módulo JIT")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
                Text("Automático respeta la configuración original. Activado solicita JIT; Desactivado impide solicitarlo. Cambia el siguiente lanzamiento, no cierra apps abiertas.")
                    .font(.footnote).foregroundStyle(.secondary)
                if provider != JITEnablerType.BuiltIn.rawValue {
                    Label("El script experimental de MeloNX solo funciona con Built-in JIT. El control JIT por app también puede afectar otros proveedores.", systemImage: "info.circle")
                        .font(.footnote).foregroundStyle(.orange)
                }
                if !scriptExperimentEnabled {
                    Label("Pruebas con script MeloNX desactivadas globalmente. Puedes preparar las selecciones, pero no se aplicarán hasta encender el interruptor anterior.", systemImage: "lock.shield")
                        .font(.footnote).foregroundStyle(.secondary)
                }
                TextField("Buscar aplicación", text: $searchText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityIdentifier("bloombox.experiments.jitApps.search")
                if visibleApps.isEmpty {
                    Text("No hay aplicaciones que coincidan con tu búsqueda.")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 18)
                }
                ForEach(visibleApps, id: \.appInfo.relativeBundlePath) { app in
                    BloomBoxJITGuestExperimentRow(
                        app: app,
                        isBuiltIn: provider == JITEnablerType.BuiltIn.rawValue,
                        experimentEnabled: scriptExperimentEnabled)
                }
                Text("Esto es experimental: un script no crea compatibilidad JIT por sí solo. Si falla, vuelve a Automático y desmarca la prueba MeloNX.")
                    .font(.footnote).foregroundStyle(.orange)
            }
            .padding(18)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).ignoresSafeArea())
        .navigationTitle("JIT por app")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BloomBoxJITGuestExperimentRow: View {
    @ObservedObject var app: LCAppModel
    let isBuiltIn: Bool
    let experimentEnabled: Bool
    @State private var jitMode: BloomBoxJITGuestPolicy.Mode
    @State private var tryMeloScript: Bool

    init(app: LCAppModel, isBuiltIn: Bool, experimentEnabled: Bool) {
        self.app = app
        self.isBuiltIn = isBuiltIn
        self.experimentEnabled = experimentEnabled
        let defaults = LCUtils.appGroupUserDefault
        _jitMode = State(initialValue: BloomBoxJITGuestPolicy.mode(
            for: app.appInfo.relativeBundlePath, defaults: defaults))
        _tryMeloScript = State(initialValue: BloomBoxJITGuestPolicy.isExperimentSelected(
            for: app.appInfo.relativeBundlePath, defaults: defaults))
    }

    private var isMeloNX26: Bool {
        let bundle = Bundle(path: app.appInfo.bundlePath())
        return BloomBoxMeloNXProfile.matches(
            bundleID: app.bundleIdentifier,
            version: bundle?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)
    }

    private var hasCustomScript: Bool { app.jitLaunchScriptJs?.isEmpty == false }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "app.fill")
                    .font(.title2).foregroundStyle(.purple)
                    .frame(width: 40, height: 40)
                    .background(Color.purple.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                VStack(alignment: .leading, spacing: 3) {
                    Text(app.displayName).font(.headline)
                    Text(app.bundleIdentifier)
                        .font(.caption2).foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Spacer(minLength: 0)
            }
            Picker("JIT al abrir", selection: $jitMode) {
                ForEach(BloomBoxJITGuestPolicy.Mode.allCases, id: \.self) { mode in
                    Text(LocalizedStringKey(mode.title)).tag(mode)
                }
            }
            .tint(.orange)
            .onChange(of: jitMode) { newMode in
                BloomBoxJITGuestPolicy.setMode(newMode,
                    for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
            }
            .accessibilityIdentifier("bloombox.experiments.jitApps.mode")
            if isMeloNX26 {
                Label("MeloNX 2.6 tiene su perfil automático original.", systemImage: "checkmark.shield")
                    .font(.caption).foregroundStyle(.green)
            } else {
                Toggle("Probar script de MeloNX 2.6", isOn: $tryMeloScript)
                    .tint(.purple)
                    .disabled(hasCustomScript)
                    .onChange(of: tryMeloScript) { selected in
                        BloomBoxJITGuestPolicy.setExperimentSelected(selected,
                            for: app.appInfo.relativeBundlePath, defaults: LCUtils.appGroupUserDefault)
                    }
                    .accessibilityIdentifier("bloombox.experiments.jitApps.melonScript")
                if hasCustomScript {
                    Text("Esta app tiene un script propio; se respeta su prioridad.")
                        .font(.caption).foregroundStyle(.secondary)
                } else if tryMeloScript && experimentEnabled && isBuiltIn && jitMode != .disabled {
                    Text("El script se intentará en el próximo lanzamiento con JIT.")
                        .font(.caption).foregroundStyle(.orange)
                } else if tryMeloScript {
                    Text("Selección guardada; requiere JIT integrado, experimento maestro activo y JIT no desactivado.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if jitMode == .disabled {
                Text("JIT desactivado para esta app. «Launch with JIT» mostrará un aviso.")
                    .font(.caption).foregroundStyle(.orange)
            } else if jitMode == .enabled {
                Text("Se solicitará JIT al abrirla, pero esto no garantiza compatibilidad.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(15)
        .background(Color.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(Color.white.opacity(0.10)))
    }
}

/// Uses the same app property as the established per-app Internet switch.
/// Turning Internet on means networkBlocked=false; turning it off means true.
private struct BloomBoxConnectivityModule: View {
    let apps: [LCAppModel]
    @State private var search = ""
    @State private var notice: String?
    @State private var changedCount = 0

    private var availableApps: [LCAppModel] {
        var seen = Set<String>()
        return apps.filter { app in
            !(app.appInfo is BuiltInSideStoreAppInfo) &&
            seen.insert(liveBoardAppKey(app)).inserted
        }.sorted {
            $0.appInfo.displayName().localizedCaseInsensitiveCompare($1.appInfo.displayName()) == .orderedAscending
        }
    }

    private var filteredApps: [LCAppModel] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableApps }
        return availableApps.filter {
            $0.appInfo.displayName().localizedCaseInsensitiveContains(query) ||
            $0.bundleIdentifier.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "wifi").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Internet por aplicación").font(.title3.bold())
                        Text("Encendido: tiene Internet · Apagado: bloqueado")
                            .font(.footnote).foregroundStyle(.white.opacity(0.7))
                    }
                }
                TextField("Buscar app", text: $search)
                    .padding(12)
                    .background(Color.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                    .autocorrectionDisabled()
                    .accessibilityIdentifier("bloombox.modules.connectivity.search")

                if let notice {
                    Label(notice, systemImage: "checkmark.circle")
                        .foregroundStyle(.green)
                        .font(.footnote)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
                }

                if availableApps.isEmpty {
                    Label("No hay aplicaciones invitadas instaladas.", systemImage: "square.stack")
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(14)
                } else if filteredApps.isEmpty {
                    Text("No se encontraron aplicaciones.")
                        .foregroundStyle(.secondary)
                        .padding(14)
                } else {
                    ForEach(filteredApps, id: \.self) { app in
                        BloomBoxConnectivityRow(app: app) { allowed in
                            changedCount += 1
                            notice = allowed
                                ? "«\(app.appInfo.displayName())» volverá a tener Internet después de reiniciar BloomBox."
                                : "«\(app.appInfo.displayName())» tendrá Internet bloqueado después de reiniciar BloomBox."
                            UINotificationFeedbackGenerator().notificationOccurred(.success)
                        }
                    }
                }

                if changedCount > 0 {
                    Label("Hay cambios pendientes de aplicar: cierra BloomBox desde el selector de apps y vuelve a abrirlo.", systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                Text("Este ajuste se aplica a las apps invitadas dentro de BloomBox, no a todo iOS. El filtro es experimental y algunas conexiones, incluidas las de iCloud, pueden continuar. Los cambios requieren cerrar y volver a abrir BloomBox.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.64))
            }
            .padding(20)
        }
        .background(Color(red: 0.055, green: 0.065, blue: 0.13).opacity(0.87).ignoresSafeArea())
        .foregroundStyle(.white)
        .navigationTitle("Conectividad")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BloomBoxConnectivityRow: View {
    @ObservedObject var app: LCAppModel
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 12) {
            LiveBoardIconImage(app: app, dark: false)
                .frame(width: 47, height: 47)
                .clipShape(RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 3) {
                Text(app.appInfo.displayName())
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                if app.isAppRunning {
                    Text("Cierra la app para cambiar el acceso")
                        .font(.caption2).foregroundStyle(.orange)
                } else if app.isSigningInProgress {
                    Text("Firma en curso")
                        .font(.caption2).foregroundStyle(.orange)
                } else {
                    Label(LocalizedStringKey(app.uiNetworkBlocked ? "Internet bloqueado" : "Internet permitido"),
                          systemImage: app.uiNetworkBlocked ? "wifi.slash" : "wifi")
                        .font(.caption2)
                        .foregroundStyle(app.uiNetworkBlocked ? Color.orange : Color.green)
                }
            }
            Spacer(minLength: 4)
            Toggle(BloomBoxL10n.isEnglish ? "Internet access for \(app.appInfo.displayName())" : "Internet de \(app.appInfo.displayName())", isOn: Binding(
                get: { !app.uiNetworkBlocked },
                set: { allowed in
                    guard !app.isAppRunning && !app.isSigningInProgress else { return }
                    app.uiNetworkBlocked = !allowed
                    onChange(allowed)
                }
            ))
            .labelsHidden()
            .tint(.green)
            .disabled(app.isAppRunning || app.isSigningInProgress)
            .accessibilityIdentifier("bloombox.modules.connectivity.\(liveBoardAppKey(app))")
        }
        .padding(13)
        .background(Color(white: 0.18).opacity(0.9), in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18)
            .strokeBorder(app.uiNetworkBlocked ? Color.orange.opacity(0.35) : Color.white.opacity(0.12)))
    }
}

