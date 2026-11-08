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
            if embedded {
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
                Toggle(isOn: $automaticPairing) {
                    Label(words("Emparejamiento automático", "Automatic pairing"),
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("bloombox.jit.automaticPairing")

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
                            LabeledContent(
                                words("Última coincidencia verificada", "Last verified match"),
                                value: lastPairingVerified.formatted(date: .abbreviated, time: .shortened)
                            )
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
