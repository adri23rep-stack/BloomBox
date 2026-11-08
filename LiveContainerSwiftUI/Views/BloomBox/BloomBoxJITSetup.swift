import SwiftUI
import UniformTypeIdentifiers

struct BloomBoxJITSetup: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var provider = JITEnablerType.SideJITServer.rawValue
    @ObservedObject private var session = LiveBoardJITSession.shared
    @ObservedObject private var pairing = ManzanaOnDevicePairing.shared
    @AppStorage("BloomBoxJITRemotePort", store: LCUtils.appGroupUserDefault) private var remotePortOverride = ""
    // Same explicit opt-in exposed under LiveContainer Developer Settings.
    // Never turn this on automatically: it affects all private guest containers.
    @AppStorage("LCSharePrivateDataWithLiveProcess") private var sharePrivateDataWithLiveProcess = false
    @State private var importing = false
    @State private var hasPairing = (try? BloomBoxJITPairingStorage().load()) != nil
    @AppStorage("BloomBoxJITSyncWithSideStore", store: LCUtils.appGroupUserDefault)
    private var automaticPairing = true
    // Preserve current users' working JIT on upgrade. Turning this OFF
    // disables automatic and explicit Built-in JIT requests on future launches.
    @AppStorage("BloomBoxJITMainEnabled", store: LCUtils.appGroupUserDefault)
    private var mainJITEnabled = true
    // Experimental UI-only rehearsal for GIF/video recording. Never writes to
    // pairing files, VPN, JIT provider, private data access or JIT preferences.
    @AppStorage("BloomBoxJITDemoUnconfigured", store: LCUtils.appGroupUserDefault)
    private var demoUnconfigured = false
    @State private var demoSwitchOn = false
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    @Environment(\.scenePhase) private var scenePhase
    @State private var syncMessage: String?
    @State private var lastPairingVerified: Date?

    private var englishUI: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }

    private func words(_ spanish: String, _ english: String) -> String {
        englishUI ? english : spanish
    }
    // Only the preview switch is fictional; the real state is never changed
    // during the recording simulation.
    private var pairingSwitch: Binding<Bool> {
        Binding(
            get: { demoUnconfigured ? false : automaticPairing },
            set: { if !demoUnconfigured { automaticPairing = $0 } }
        )
    }

    private var activationSwitch: Binding<Bool> {
        Binding(
            get: {
                demoUnconfigured ? demoSwitchOn :
                    (mainJITEnabled && provider == JITEnablerType.BuiltIn.rawValue)
            },
            set: { enabled in
                if demoUnconfigured {
                    demoSwitchOn = enabled
                } else {
                    mainJITEnabled = enabled
                    if enabled { provider = JITEnablerType.BuiltIn.rawValue }
                }
            }
        )
    }

    let embedded: Bool

    init(embedded: Bool = false) {
        self.embedded = embedded
    }

    var body: some View {
        Group {
            if demoUnconfigured {
                // A fully interactive rehearsal of the normal onboarding flow.
                // The real controls below are not reached while rehearsing.
                BloomBoxJITRecordingFlow(englishUI: englishUI) {
                    demoUnconfigured = false
                    dismiss()
                }
            } else if embedded {
                if #available(iOS 16.0, *) {
                    jitForm.scrollContentBackground(.hidden).navigationTitle("JIT")
                } else {
                    jitForm.navigationTitle("JIT")
                }
            } else {
                NavigationView {
                    jitForm
                        .navigationTitle("JIT setup")
                        .toolbar {
                            ToolbarItem(placement: .confirmationAction) {
                                Button("Done") { dismiss() }
                            }
                        }
                }.navigationViewStyle(.stack)
            }
        }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data], onCompletion: importPairing)
        .onAppear { refreshPairing() }
        .onChange(of: demoUnconfigured) { enabled in
            if enabled { demoSwitchOn = false }
            refreshPairing()
        }
        .onChange(of: automaticPairing) { _ in refreshPairing() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { refreshPairing() }
        }
        .onChange(of: pairing.phase) { phase in
            guard !demoUnconfigured else { return }
            guard case .paired = phase else { return }
            hasPairing = true
            refreshPairing()
            provider = JITEnablerType.BuiltIn.rawValue
            session.message = "Pairing saved. Keep LocalDevVPN connected, then tap Prepare device."
        }
    }

    // The everyday screen only needs one pairing switch, its real status and a
    // route to every existing expert control. None of those settings are removed.
    private var jitForm: some View {
        Form {
            if demoUnconfigured {
                Section {
                    Label(words("Modo demostración · sin configurar", "Demo mode · not configured"),
                          systemImage: "video.badge.waveform")
                        .foregroundStyle(.orange)
                    Text(words(
                        "Solo se está simulando el primer uso para grabar las instrucciones. El pairing, la VPN y el JIT reales no cambiaron.",
                        "First-time setup is simulated for recording only. Your actual pairing, VPN and JIT are unchanged."
                    ))
                    .font(.footnote)
                    Button {
                        demoUnconfigured = false
                        demoSwitchOn = false
                        refreshPairing()
                    } label: {
                        Label(words("Salir de simulación", "Exit demo mode"),
                              systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.exit")
                }
            }

            Section {
                Toggle(isOn: activationSwitch) {
                    Label(words("Activar JIT", "Enable JIT"), systemImage: "bolt.fill")
                }
                .accessibilityIdentifier("bloombox.jit.mainEnabled")

                if demoUnconfigured {
                    Label(
                        demoSwitchOn
                            ? words("Configuración pendiente · asistente próximamente", "Setup pending · wizard coming soon")
                            : words("JIT sin configurar (simulación)", "JIT not configured (demo)"),
                        systemImage: "exclamationmark.triangle.fill"
                    )
                    .foregroundStyle(.orange)
                    Text(words(
                        "Aquí mostraremos el asistente con tu GIF. Aún no hay activación real en este modo.",
                        "The setup wizard will appear here with your GIF. This demo never activates JIT."
                    ))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                } else {
                    Label(
                        mainJITEnabled && provider == JITEnablerType.BuiltIn.rawValue
                            ? words("JIT permitido para próximos lanzamientos", "JIT enabled for upcoming launches")
                            : words("JIT integrado desactivado", "Built-in JIT is off"),
                        systemImage: mainJITEnabled && provider == JITEnablerType.BuiltIn.rawValue
                            ? "checkmark.circle.fill" : "circle"
                    )
                    .foregroundStyle(mainJITEnabled && provider == JITEnablerType.BuiltIn.rawValue ? .green : .secondary)
                    Text(words(
                        "Al encenderlo se selecciona Built-in JIT. Se activa para cada app al iniciarla con JIT; este switch no confirma memoria JIT en un juego abierto.",
                        "Turning it on selects Built-in JIT. JIT activates when a guest launches with JIT; this switch does not confirm JIT memory in an already-open game."
                    ))
                    .font(.footnote).foregroundStyle(.secondary)
                }
            } header: {
                Text(words("Activación", "Activation"))
            }

            Section {
                Toggle(isOn: pairingSwitch) {
                    Label(words("Emparejamiento automático", "Automatic pairing"),
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("bloombox.jit.automaticPairing")
                .disabled(demoUnconfigured)

                Label(
                    demoUnconfigured
                        ? words("Pairing pendiente (simulación)", "Pairing pending (demo)")
                        : hasPairing
                            ? words("Archivo de emparejamiento disponible", "Pairing file available")
                            : words("Falta el archivo de emparejamiento", "Pairing file missing"),
                    systemImage: !demoUnconfigured && hasPairing ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(!demoUnconfigured && hasPairing ? .green : .orange)

                if !demoUnconfigured, let syncMessage {
                    Text(syncMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if demoUnconfigured {
                    Text(words("El pairing original está protegido; la simulación no ejecuta comprobaciones ni preparaciones reales.",
                               "Your pairing is protected; the demo performs no real pairing or preparation."))
                        .font(.footnote).foregroundStyle(.secondary)
                } else if provider == JITEnablerType.BuiltIn.rawValue && mainJITEnabled {
                    if hasPairing {
                        Button {
                            perform("prepare")
                        } label: {
                            Label(words("Preparar dispositivo", "Prepare device"),
                                  systemImage: "bolt.shield.fill")
                        }
                        .disabled(session.busy)
                    } else {
                        Text(words(
                            "Si SideStore no comparte su archivo, impórtalo desde Opciones avanzadas.",
                            "If SideStore cannot share its file, import it from Advanced options."
                        ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                } else if !demoUnconfigured && !mainJITEnabled {
                    Text(words("Activa JIT arriba para preparar el dispositivo y usar el JIT integrado en tus apps.",
                               "Enable JIT above to prepare the device and use built-in JIT in your apps."))
                        .font(.footnote).foregroundStyle(.secondary)
                } else if !demoUnconfigured {
                    Text(words("Hay otro proveedor de JIT seleccionado.",
                               "Another JIT provider is currently selected."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(words("Usar JIT integrado", "Use built-in JIT")) {
                        provider = JITEnablerType.BuiltIn.rawValue
                        mainJITEnabled = true
                    }
                }
                if !demoUnconfigured && session.busy {
                    HStack {
                        ProgressView()
                        Text(words("Preparando…", "Preparing…"))
                        Spacer()
                        Button(words("Cancelar", "Cancel")) { session.cancel() }
                    }
                }
            } header: {
                Text(words("JIT integrado", "Built-in JIT"))
            } footer: {
                Text(words(
                    "Activado: BloomBox busca un pairing actualizado de SideStore antes de iniciar JIT. Si no puede acceder al archivo, conserva el actual. Apagado: usa el pairing instalado manualmente.",
                    "On: BloomBox checks for an updated SideStore pairing before JIT starts. If the file is inaccessible, it preserves the existing record. Off: use your manually imported pairing."
                ))
            }

            if !demoUnconfigured && provider == JITEnablerType.BuiltIn.rawValue {
                Section {
                    connectionFeedback
                }
            }

            Section {
                NavigationLink {
                    advancedJITForm
                        .navigationTitle(words("Opciones avanzadas", "Advanced options"))
                } label: {
                    Label(words("Opciones avanzadas", "Advanced options"),
                          systemImage: "slider.horizontal.3")
                }
                .accessibilityIdentifier("bloombox.jit.advancedOptions")
            }
        }
    }

    private func refreshPairing() {
        // Demo never runs actual synchronization, even when the screen appears
        // or returns to foreground. It is a visual rehearsal only.
        if demoUnconfigured {
            syncMessage = nil
            return
        }
        let result = BloomBoxJITPairingSync.synchronize()
        hasPairing = (try? BloomBoxJITPairingStorage().load()) != nil
        lastPairingVerified = LCUtils.appGroupUserDefault.object(forKey: BloomBoxJITPairingSync.lastVerifiedKey) as? Date
        switch result {
        case .disabled:
            syncMessage = words("Sincronización desactivada.", "Synchronization is off.")
        case .synchronized:
            syncMessage = words("Pairing de SideStore sincronizado.", "SideStore pairing synchronized.")
        case .alreadyCurrent:
            syncMessage = words("Pairing verificado: coincide con SideStore.", "Verified: pairing matches SideStore.")
        case .olderSource:
            syncMessage = words("SideStore tiene una copia anterior; se conserva tu pairing actual.", "SideStore has an older copy; your current pairing is preserved.")
        case .invalidSource:
            syncMessage = words("El archivo encontrado no es un pairing remoto válido. No se reemplazó nada.", "The found file is not a valid remote pairing record. Nothing was replaced.")
        case .unreadableSource:
            syncMessage = words("BloomBox encontró un archivo, pero no pudo leerlo. Revisa los permisos.", "BloomBox found a file but could not read it. Check permissions.")
        case .unavailable:
            syncMessage = automaticPairing
                ? words("No se encontró un pairing compartido de SideStore. Se conserva el archivo actual.",
                        "No shared SideStore pairing was found. Your existing file is preserved.")
                : nil
        }
    }

    private var advancedJITForm: some View {
        Form {
                Section("JIT method") {
                    providerChooser
                    Button("Use built-in JIT") {
                        provider = JITEnablerType.BuiltIn.rawValue
                    }
                }
                if provider == JITEnablerType.BuiltIn.rawValue {
                    Section {
                        Button {
                            refreshPairing()
                        } label: {
                            Label(words("Comprobar sincronización", "Check pairing synchronization"),
                                  systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(!automaticPairing)
                        .accessibilityIdentifier("bloombox.jit.checkPairingSync")

                        if let lastPairingVerified {
                            HStack {
                                Text(words("Última coincidencia verificada", "Last verified match"))
                                Spacer(minLength: 8)
                                Text(lastPairingVerified.formatted(date: .abbreviated, time: .shortened))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                        } else {
                            Text(words("Aún no se ha podido confirmar la coincidencia con SideStore.",
                                       "No matching SideStore pairing has been confirmed yet."))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        if let syncMessage {
                            Text(syncMessage)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text(words("Comprobar no borra el pairing guardado ni reinicia el JIT. Si detecta una versión más reciente y válida de SideStore, la sincroniza.",
                                   "Checking does not erase saved pairing or restart JIT. A newer valid SideStore record is synchronized when found."))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text(words("Diagnóstico de pairing", "Pairing diagnostics"))
                    }
                    if ManzanaOnDevicePairing.isSupported {
                        Section("Pair on this iPhone (iOS 27)") {
                            Text("One-time setup. BloomBox acts like a local computer so your iPhone can pair with it without a PC. Wi-Fi and Local Network permission are required.")
                                .font(.footnote)
                            Text("1. Tap Start pairing.\n2. Open iPhone Settings → Privacy & Security → Developer Mode.\n3. Tap Pair with BloomBox and enter the code shown here (also in a notification).\n4. Return to BloomBox.")
                                .font(.footnote)
                            switch pairing.phase {
                            case .idle:
                                Button("Start pairing with BloomBox") { pairing.start() }
                            case .waiting:
                                Label("Waiting for iOS to connect…", systemImage: "antenna.radiowaves.left.and.right")
                                Button("Cancel pairing", role: .cancel) { pairing.cancel() }
                            case .pin(let code):
                                Text(code).font(.system(size: 34, weight: .bold, design: .monospaced))
                                    .textSelection(.enabled).accessibilityLabel("Pairing code \(code)")
                                Button("Cancel pairing", role: .cancel) { pairing.cancel() }
                            case .paired:
                                Label("Paired with this iPhone", systemImage: "checkmark.shield.fill")
                                    .foregroundStyle(.green)
                                Button("Pair again") { pairing.reset(); pairing.start() }
                            case .failed(let reason):
                                Label(reason, systemImage: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange).font(.footnote)
                                Button("Retry pairing") { pairing.reset(); pairing.start() }
                            }
                            if pairing.backgroundLimited && pairing.active {
                                Text("iOS limited background time for this installation. Open Settings right away before BloomBox is suspended.")
                                    .font(.footnote).foregroundStyle(.orange)
                            }
                            Button("Open iPhone Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                    }
                    Section("One-time setup") {
                        Label(hasPairing ? "Pairing file imported" : "Pairing file needed", systemImage: hasPairing ? "checkmark.circle" : "doc.badge.plus")
                        Button(hasPairing ? "Replace pairing file" : "Import remote pairing file") { importing = true }
                        if hasPairing {
                            Button("Remove pairing file", role: .destructive) {
                                do { try BloomBoxJITPairingStorage().remove(); hasPairing = false; session.message = "Pairing file removed." }
                                catch { session.message = error.localizedDescription }
                            }
                        }
                        Text("Enable Developer Mode in Settings. Connect your existing LocalDevVPN before Prepare device or Launch with JIT; SideStore can keep using the same VPN. The first launch may download a developer disk image.")
                        Label(LCUtils.bloomBoxCanDebug() ? "Debugging permission available" : "Re-signing required: debugging permission missing", systemImage: LCUtils.bloomBoxCanDebug() ? "checkmark.shield" : "exclamationmark.shield")
                        Text("JIT applies only to guests installed inside BloomBox, not other iPhone apps. It runs through LiveProcess, and some guest engines need a matching iOS 27 JIT script. Keep extensions when updating.").foregroundStyle(.secondary)
                    }
                    Section("Datos privados de las apps") {
                        Toggle("Permitir datos privados en LiveProcess", isOn: $sharePrivateDataWithLiveProcess)
                            .accessibilityIdentifier("bloombox.jit.sharePrivateData")
                        Text("Husk y otras apps privadas necesitan este permiso para usar Built-in JIT. Es un permiso GLOBAL para las apps privadas de BloomBox, no solo Husk. No lo activaremos automáticamente.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !sharePrivateDataWithLiveProcess {
                            Label("Las apps privadas no podrán iniciar con Built-in JIT. Puedes mantener el permiso apagado y elegir StikDebug u otro proveedor externo.", systemImage: "lock.shield")
                                .font(.footnote).foregroundStyle(.orange)
                        }
                    }
                    Section("Connection check") {
                        HStack {
                            Text("Remote Pairing port")
                            Spacer()
                            TextField("Auto", text: $remotePortOverride)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 110)
                        }
                        Text("Leave blank for automatic detection. If JIT times out on port 49152, find the current port under SideStore > Settings > Experimental Features > Network Discovery > local > Remote Pairing and enter it here. This is not the pairing PIN.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        connectionActions
                        connectionFeedback
                    }
                    Section("Launch") {
                        Text("Touch and hold an app, or open its console options, and choose Launch with JIT. BloomBox prepares the device and connects its helper automatically. Errors appear in the launch window.")
                    }
                } else {
                    externalProviderHelp
                }
                if provider != JITEnablerType.BuiltIn.rawValue && !session.message.isEmpty { Section { Text(session.message) } }
                Section { NavigationLink("JIT-less setup and diagnostics") { LCJITLessDiagnoseView() } }
        }
    }

    private var externalProviderHelp: some View {
        Section("External provider") {
            Text("Configure pairing and the required connection in your selected provider, then choose Launch with JIT on an app.")
            NavigationLink("Provider settings") { LCSettingsView() }
        }
    }

    private var providerChooser: some View {
        Picker("Enable JIT using", selection: $provider) {
            ForEach(JITEnablerType.allCases) { available in
                Text(available.displayName).tag(available.rawValue)
            }
        }
    }

    private func importPairing(_ result: Result<URL, Error>) {
        do {
            let selected = try result.get()
            try LiveBoardBuiltInJIT.importPairing(selected)
            hasPairing = true
            session.message = "Pairing file imported. Connect LocalDevVPN, then launch an app with JIT."
        } catch {
            session.message = error.localizedDescription
        }
    }

    /// Pairing controls and feedback are kept separate from the provider form.
    @ViewBuilder private var connectionActions: some View {
        HStack(spacing: 12) {
            Button("Prepare device") { perform("prepare") }
            Button("Reset developer disk image cache") { perform("reset") }
        }
        .disabled(session.busy || !hasPairing)
        if session.busy {
            HStack {
                ProgressView("Working…")
                Button("Cancel") { session.cancel() }
            }
        }
    }

    @ViewBuilder private var connectionFeedback: some View {
        if let completed = session.success {
            Label(completed ? "Completed" : "Could not complete",
                  systemImage: completed ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .foregroundStyle(completed ? Color.green : Color.orange)
        }
        if !session.message.isEmpty {
            Text(session.message).font(.footnote).textSelection(.enabled)
                .accessibilityIdentifier("jit.status")
        }
    }

    private func perform(_ operation: String) { session.start(operation) }
}

// Source alias for host modules; pairing/JIT credentials keep their old saved IDs.
typealias LiveBoardJITSetup = BloomBoxJITSetup


/// Rehearsal of the complete JIT onboarding, intended to record an animated
/// tutorial before the real GIF is available. All inputs here are local SwiftUI
/// @State: no user defaults, credentials, VPN, pairing service, debugger,
/// application settings or real caches are changed.
private struct BloomBoxJITRecordingFlow: View {
    let englishUI: Bool
    let exit: () -> Void
    @State private var activated = false
    @State private var automaticPairing = true
    @State private var paired = false
    @State private var vpnReady = false
    @State private var prepared = false
    @State private var preparing = false
    @State private var pairingStarted = false
    @State private var pairingCodeVisible = false
    @State private var privateDataAllowed = false
    @State private var remotePort = ""
    @State private var selectedProvider = JITEnablerType.BuiltIn.rawValue
    @State private var showWizard = false
    @State private var showImporter = false
    @State private var step = 0
    @State private var feedback = ""
    @State private var preparationStep = ""

    private func tr(_ es: String, _ en: String) -> String {
        englishUI ? en : es
    }

    private var pairingLabel: String {
        paired ? tr("Emparejamiento listo", "Pairing ready")
               : tr("Emparejamiento pendiente", "Pairing required")
    }
    private var readyForLaunch: Bool { paired && vpnReady && prepared && activated }
    private var controlColor: Color { readyForLaunch ? .green : .orange }

    var body: some View {
        NavigationView {
            Form {
                Section {
                    HStack {
                        Image(systemName: "bolt.shield.fill")
                            .foregroundStyle(.orange)
                        Text(tr("Configuración de JIT", "JIT setup"))
                            .font(.headline)
                        Spacer(minLength: 8)
                        Text(tr("PRUEBA", "DEMO"))
                            .font(.caption2.bold())
                            .foregroundStyle(.orange)
                    }
                    Text(tr("Recorrido para grabar las instrucciones. Todos los botones funcionan en esta vista sin tocar tu JIT real.",
                            "Interactive tutorial rehearsal. All controls work here without changing your real JIT."))
                        .font(.footnote).foregroundStyle(.secondary)
                    Button(tr("Reiniciar recorrido", "Restart walkthrough")) {
                        reset()
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.restart")
                }
                Section {
                    Toggle(isOn: Binding(
                        get: { activated },
                        set: { enabled in
                            activated = enabled
                            if enabled && !readyForLaunch {
                                step = paired ? (vpnReady ? 3 : 2) : 0
                                showWizard = true
                            }
                        }
                    )) {
                        Label(tr("Activar JIT", "Enable JIT"), systemImage: "bolt.fill")
                    }
                    .tint(.orange)
                    .accessibilityIdentifier("bloombox.jit.demo.activate")

                    Label(readyForLaunch
                          ? tr("Listo para iniciar aplicaciones con JIT", "Ready to launch apps with JIT")
                          : activated
                            ? tr("Completa los pasos de configuración", "Complete setup steps")
                            : tr("JIT sin configurar", "JIT not configured"),
                          systemImage: readyForLaunch ? "checkmark.circle.fill" : "circle.dotted")
                        .foregroundStyle(controlColor)

                    Button {
                        step = readyForLaunch ? 4 : (paired ? (vpnReady ? 3 : 2) : 0)
                        showWizard = true
                    } label: {
                        Label(readyForLaunch
                              ? tr("Ver pasos de configuración", "Review setup steps")
                              : tr("Configurar JIT paso a paso", "Set up JIT step by step"),
                              systemImage: "list.number")
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.setupGuide")
                } header: {
                    Text(tr("Activación", "Activation"))
                }

                Section {
                    Toggle(isOn: $automaticPairing) {
                        Label(tr("Emparejamiento automático", "Automatic pairing"),
                              systemImage: "arrow.triangle.2.circlepath")
                    }
                    .tint(.orange)
                    .accessibilityIdentifier("bloombox.jit.demo.automaticPairing")

                    Label(pairingLabel, systemImage: paired
                          ? "checkmark.shield.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(paired ? .green : .orange)

                    if !paired {
                        Button {
                            step = 1
                            showWizard = true
                        } label: {
                            Label(tr("Emparejar en este iPhone", "Pair on this iPhone"),
                                  systemImage: "iphone.gen3.radiowaves.left.and.right")
                        }
                        Button {
                            showImporter = true
                        } label: {
                            Label(tr("Importar pairing", "Import pairing"),
                                  systemImage: "doc.badge.plus")
                        }
                    }
                } header: {
                    Text(tr("Emparejamiento", "Pairing"))
                }

                Section {
                    Label(vpnReady ? tr("LocalDevVPN conectada", "LocalDevVPN connected")
                          : tr("Conectar LocalDevVPN", "Connect LocalDevVPN"),
                          systemImage: vpnReady ? "checkmark.circle.fill" : "network")
                        .foregroundStyle(vpnReady ? .green : .orange)
                    Button(vpnReady ? tr("Comprobar VPN otra vez", "Check VPN again")
                                    : tr("Comprobar conexión VPN", "Check VPN connection")) {
                        // An intentional simulated confirmation, never a network probe.
                        vpnReady = true
                        feedback = tr("VPN verificada para esta demostración.", "VPN checked in this rehearsal.")
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.vpn")

                    Button {
                        startPreparation()
                    } label: {
                        Label(tr("Preparar dispositivo", "Prepare device"),
                              systemImage: "bolt.shield.fill")
                    }
                    .disabled(!paired || !vpnReady || preparing)
                    .accessibilityIdentifier("bloombox.jit.demo.prepare")

                    if preparing { ProgressView(preparationStep) }
                    if prepared {
                        Label(tr("Dispositivo preparado", "Device prepared"),
                              systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                    if !feedback.isEmpty {
                        Text(feedback).font(.footnote).foregroundStyle(.secondary)
                    }
                } header: {
                    Text(tr("Preparación", "Preparation"))
                }

                Section {
                    NavigationLink {
                        advancedScreen
                    } label: {
                        Label(tr("Opciones avanzadas", "Advanced options"),
                              systemImage: "slider.horizontal.3")
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.advanced")
                }
                Section {
                    Button(role: .cancel) {
                        exit()
                    } label: {
                        Label(tr("Salir y restaurar JIT real", "Exit and restore real JIT"),
                              systemImage: "arrow.uturn.backward")
                    }
                    .accessibilityIdentifier("bloombox.jit.demo.exit")
                } footer: {
                    Text(tr("Al salir, todos los valores de esta grabación se descartan. No se modifica SideStore, pairing, VPN, RAM+ ni JIT.",
                            "Recording values are discarded on exit. SideStore, pairing, VPN, RAM+ and JIT remain unchanged."))
                }
            }
            .navigationTitle(tr("JIT integrado", "Built-in JIT"))
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showWizard) {
                NavigationView {
                    wizardScreen
                        .navigationTitle(tr("Configurar JIT", "Set up JIT"))
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .cancellationAction) {
                                Button(tr("Cerrar", "Close")) { showWizard = false }
                            }
                        }
                }
                .navigationViewStyle(.stack)
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.data]) { result in
                // The iOS file picker is real; we neither read nor store the
                // selected file. It is only a visual import step in the demo.
                if case .success = result {
                    paired = true
                    feedback = tr("Pairing importado (solo demostración).",
                                  "Pairing imported (demo only).")
                    if showWizard { step = 2 }
                }
            }
        }
        .navigationViewStyle(.stack)
    }

    @ViewBuilder
    private var wizardScreen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text(tr("PASO \(min(step + 1, 5)) DE 5",
                            "STEP \(min(step + 1, 5)) OF 5"))
                        .font(.caption.bold()).foregroundStyle(.secondary)
                    Spacer()
                    Label(tr("Grabación", "Recording"), systemImage: "video")
                        .font(.caption).foregroundStyle(.orange)
                }
                HStack(spacing: 5) {
                    ForEach(0..<5, id: \.self) { index in
                        Capsule()
                            .fill(index <= step ? Color.orange : Color.gray.opacity(0.2))
                            .frame(height: 4)
                    }
                }

                switch step {
                case 0: welcomeStep
                case 1: pairingStep
                case 2: vpnStep
                case 3: prepareStep
                default: finishedStep
                }

                HStack(spacing: 12) {
                    if step > 0 {
                        Button(tr("Atrás", "Back")) {
                            step -= 1
                        }.buttonStyle(.bordered)
                    }
                    Spacer()
                    if step == 0 {
                        Button(tr("Continuar", "Continue")) { step = 1 }
                            .buttonStyle(.borderedProminent)
                    } else if step == 1 && paired {
                        Button(tr("Siguiente", "Next")) { step = 2 }
                            .buttonStyle(.borderedProminent)
                    } else if step == 2 && vpnReady {
                        Button(tr("Siguiente", "Next")) { step = 3 }
                            .buttonStyle(.borderedProminent)
                    } else if step == 3 && prepared {
                        Button(tr("Siguiente", "Next")) { step = 4 }
                            .buttonStyle(.borderedProminent)
                    } else if step == 4 {
                        Button(tr("Finalizar", "Finish")) {
                            activated = true
                            showWizard = false
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .padding(22)
        }
        .accessibilityIdentifier("bloombox.jit.demo.wizard")
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 15) {
            Image(systemName: "bolt.shield.fill")
                .font(.system(size: 52)).foregroundStyle(.orange)
            Text(tr("Bienvenido al JIT integrado", "Welcome to built-in JIT"))
                .font(.title2.bold())
            Text(tr("Vamos a configurar lo necesario para iniciar juegos con JIT: emparejamiento, LocalDevVPN y preparación del dispositivo.",
                    "Set up everything needed to launch games with JIT: pairing, LocalDevVPN and device preparation."))
            Label(tr("Modo tutorial: no cambia tu configuración real.", "Tutorial mode: real settings are untouched."),
                  systemImage: "info.circle")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var pairingStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(tr("Emparejar el iPhone", "Pair your iPhone"), systemImage: "iphone")
                .font(.title2.bold())
            Text(tr("1. Inicia el emparejamiento en BloomBox.\n2. Abre Ajustes → Privacidad y seguridad → Modo desarrollador.\n3. Selecciona emparejar con BloomBox e introduce el código mostrado.\n4. Vuelve a BloomBox para continuar.",
                    "1. Start pairing in BloomBox.\n2. Open Settings → Privacy & Security → Developer Mode.\n3. Select pair with BloomBox and enter the displayed code.\n4. Return to BloomBox."))
                .font(.body)
            if paired {
                Label(tr("Emparejamiento completado", "Pairing completed"),
                      systemImage: "checkmark.shield.fill")
                    .foregroundStyle(.green)
                Button(tr("Repetir emparejamiento", "Pair again")) {
                    paired = false
                    pairingStarted = false
                    pairingCodeVisible = false
                    prepared = false
                }
            } else {
                Button {
                    pairingStarted = true
                    pairingCodeVisible = true
                } label: {
                    Label(tr("Iniciar emparejamiento", "Start pairing"),
                          systemImage: "antenna.radiowaves.left.and.right")
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("bloombox.jit.demo.startPairing")
                if pairingStarted {
                    Label(tr("Esperando al iPhone…", "Waiting for your iPhone…"),
                          systemImage: "antenna.radiowaves.left.and.right")
                    if pairingCodeVisible {
                        Text("123456")
                            .font(.system(size: 36, weight: .bold, design: .monospaced))
                            .frame(maxWidth: .infinity)
                        Text(tr("Código de ejemplo para la grabación; no se puede usar para emparejar realmente.",
                                "Example code for recording only; it cannot actually pair the device."))
                            .font(.caption).foregroundStyle(.secondary)
                        Button(tr("Abrir Ajustes del iPhone", "Open iPhone Settings")) {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .buttonStyle(.bordered)
                        Button {
                            paired = true
                            pairingStarted = false
                            pairingCodeVisible = false
                        } label: {
                            Label(tr("Confirmar emparejamiento", "Confirm pairing"),
                                  systemImage: "checkmark.shield.fill")
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityIdentifier("bloombox.jit.demo.confirmPairing")
                    }
                }
                Button(tr("Importar archivo de pairing", "Import pairing file")) {
                    showImporter = true
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var vpnStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("LocalDevVPN", systemImage: "network")
                .font(.title2.bold())
            Text(tr("Activa LocalDevVPN en tu iPhone. Mantén Modo desarrollador activo y regresa a BloomBox cuando la VPN esté conectada.",
                    "Connect LocalDevVPN on your iPhone. Keep Developer Mode on and return to BloomBox when the VPN is connected."))
            Label(vpnReady ? tr("VPN conectada", "VPN connected")
                           : tr("Esperando conexión VPN", "Waiting for VPN"),
                  systemImage: vpnReady ? "checkmark.circle.fill" : "wifi")
                .foregroundStyle(vpnReady ? .green : .orange)
            Button {
                vpnReady = true
            } label: {
                Label(tr("Ya conecté la VPN", "I connected the VPN"),
                      systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .accessibilityIdentifier("bloombox.jit.demo.confirmVPN")
            Text(tr("En la demostración este botón confirma el paso visualmente; no verifica la red real.",
                    "In this rehearsal the button advances the visuals; it does not test the actual network."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var prepareStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(tr("Preparar el dispositivo", "Prepare device"),
                  systemImage: "bolt.shield.fill")
                .font(.title2.bold())
            Text(tr("Con el pairing y LocalDevVPN listos, BloomBox prepara los servicios de depuración antes de iniciar una app.",
                    "With pairing and LocalDevVPN ready, BloomBox prepares debug services before a guest launches."))
            if preparing {
                ProgressView(preparationStep)
                    .padding(.vertical, 6)
            } else if prepared {
                Label(tr("Preparación completada", "Preparation completed"),
                      systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
            Button {
                startPreparation()
            } label: {
                Label(prepared ? tr("Preparar de nuevo", "Prepare again")
                               : tr("Preparar dispositivo", "Prepare device"),
                      systemImage: "bolt.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(preparing || !paired || !vpnReady)
            .accessibilityIdentifier("bloombox.jit.demo.wizard.prepare")
            Text(tr("La animación de conexión es solo para grabar el tutorial. No se ejecuta el depurador real.",
                    "Connection progress is for recording the tutorial; no real debugger is run."))
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var finishedStep: some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(.green)
            Text(tr("¡JIT configurado!", "JIT is configured!"))
                .font(.title2.bold())
            Text(tr("Ya puedes abrir un juego compatible desde BloomBox o GameBox y usar «Iniciar con JIT».",
                    "Now launch a compatible game from BloomBox or GameBox using Launch with JIT."))
            Label(tr("Pairing", "Pairing"), systemImage: "checkmark.shield.fill")
                .foregroundStyle(.green)
            Label("LocalDevVPN", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Label(tr("Dispositivo preparado", "Device prepared"),
                  systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(tr("Finalizar solo termina el recorrido de grabación; la activación real de JIT se comprueba al iniciar cada app.",
                    "Finish ends the recording walkthrough only; actual JIT is verified when launching each guest."))
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var advancedScreen: some View {
        Form {
            Section(tr("Método JIT", "JIT method")) {
                Picker(tr("Activar JIT con", "Enable JIT using"), selection: $selectedProvider) {
                    ForEach(JITEnablerType.allCases) { item in
                        Text(item.displayName).tag(item.rawValue)
                    }
                }
                Button(tr("Usar JIT integrado", "Use built-in JIT")) {
                    selectedProvider = JITEnablerType.BuiltIn.rawValue
                }
            }
            Section(tr("Emparejamiento", "Pairing")) {
                Label(pairingLabel, systemImage: paired ? "checkmark.circle" : "doc.badge.plus")
                    .foregroundStyle(paired ? .green : .orange)
                Button(tr("Emparejar en este iPhone", "Pair on this iPhone")) {
                    step = 1
                    showWizard = true
                }
                Button(paired ? tr("Reemplazar pairing", "Replace pairing")
                              : tr("Importar pairing remoto", "Import remote pairing")) {
                    showImporter = true
                }
                if paired {
                    Button(tr("Quitar pairing", "Remove pairing"), role: .destructive) {
                        paired = false
                        prepared = false
                        feedback = tr("Pairing de prueba eliminado.", "Demo pairing removed.")
                    }
                }
                Button(tr("Comprobar sincronización", "Check pairing synchronization")) {
                    feedback = paired
                        ? tr("Pairing de demostración disponible.", "Demo pairing available.")
                        : tr("No hay pairing configurado todavía.", "No pairing configured yet.")
                }
            }
            Section(tr("Conexión", "Connection")) {
                HStack {
                    Text(tr("Puerto de emparejamiento", "Pairing port"))
                    Spacer()
                    TextField(tr("Automático", "Auto"), text: $remotePort)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 120)
                }
                Label(vpnReady ? tr("VPN conectada", "VPN connected")
                               : tr("VPN sin comprobar", "VPN not checked"),
                      systemImage: vpnReady ? "checkmark.circle.fill" : "network")
                Button(tr("Comprobar VPN", "Check VPN")) { vpnReady = true }
                Button(tr("Preparar dispositivo", "Prepare device")) {
                    startPreparation()
                }
                .disabled(!paired || !vpnReady || preparing)
                Button(tr("Restablecer caché DDI", "Reset DDI cache")) {
                    prepared = false
                    feedback = tr("Caché DDI de prueba restablecida.", "Demo DDI cache reset.")
                }
                if preparing { ProgressView(preparationStep) }
                if prepared { Label(tr("Listo", "Ready"), systemImage: "checkmark.circle.fill") }
            }
            Section(tr("Permisos", "Permissions")) {
                Toggle(tr("Permitir datos privados en LiveProcess", "Allow private data in LiveProcess"),
                       isOn: $privateDataAllowed)
                Text(tr("Esta opción es solo de demostración; el permiso global real sigue intacto.",
                        "Demo only; the real global permission remains unchanged."))
                    .font(.footnote).foregroundStyle(.secondary)
            }
            Section(tr("Diagnóstico e historial", "Diagnostics & history")) {
                NavigationLink {
                    demoDiagnostics
                } label: {
                    Label(tr("Ver registros JIT", "View JIT logs"),
                          systemImage: "doc.text.magnifyingglass")
                }
                if !feedback.isEmpty {
                    Text(feedback).font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle(tr("Opciones avanzadas", "Advanced options"))
    }

    private var demoDiagnostics: some View {
        Form {
            Section(tr("Diagnóstico", "Diagnostics")) {
                Label(paired ? tr("Pairing disponible", "Pairing available")
                             : tr("Pairing pendiente", "Pairing missing"),
                      systemImage: paired ? "checkmark.circle.fill" : "circle")
                Label(vpnReady ? tr("VPN conectada", "VPN connected")
                               : tr("VPN pendiente", "VPN missing"),
                      systemImage: vpnReady ? "checkmark.circle.fill" : "circle")
                Label(prepared ? tr("DDI preparado", "DDI ready")
                               : tr("DDI pendiente", "DDI not prepared"),
                      systemImage: prepared ? "checkmark.circle.fill" : "circle")
            }
            Section(tr("Registro del recorrido", "Walkthrough log")) {
                Text(prepared
                    ? tr("checkingReachability\ncheckingDDI\nready\nPreparación completada.",
                         "checkingReachability\ncheckingDDI\nready\nPreparation completed.")
                    : tr("Esperando preparación del dispositivo.", "Waiting for device preparation."))
                    .font(.system(.footnote, design: .monospaced))
            }
            Text(tr("Registro ilustrativo, no es un log real del depurador.",
                    "Illustrative log only, not a real debugger log."))
                .font(.caption).foregroundStyle(.secondary)
        }
        .navigationTitle(tr("Diagnósticos JIT", "JIT diagnostics"))
    }

    private func reset() {
        activated = false
        automaticPairing = true
        paired = false
        vpnReady = false
        prepared = false
        preparing = false
        pairingStarted = false
        pairingCodeVisible = false
        privateDataAllowed = false
        remotePort = ""
        selectedProvider = JITEnablerType.BuiltIn.rawValue
        step = 0
        feedback = ""
        preparationStep = ""
        showWizard = false
    }

    private func startPreparation() {
        guard paired, vpnReady, !preparing else { return }
        preparing = true
        prepared = false
        Task { @MainActor in
            preparationStep = tr("Conectando depurador…", "Connecting debugger…")
            try? await Task.sleep(nanoseconds: 950_000_000)
            preparationStep = tr("Comprobando DDI…", "Checking DDI…")
            try? await Task.sleep(nanoseconds: 950_000_000)
            preparationStep = tr("Preparando JIT…", "Preparing JIT…")
            try? await Task.sleep(nanoseconds: 950_000_000)
            prepared = true
            preparing = false
            feedback = tr("Preparación de prueba completada.", "Demo preparation complete.")
        }
    }
}
