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
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    @Environment(\.scenePhase) private var scenePhase
    @State private var syncMessage: String?

    private var englishUI: Bool {
        preferredLanguage == "en" ||
        (preferredLanguage == "system" &&
         (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }

    private func words(_ spanish: String, _ english: String) -> String {
        englishUI ? english : spanish
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
            Section {
                Toggle(isOn: $automaticPairing) {
                    Label(words("Emparejamiento automático", "Automatic pairing"),
                          systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("bloombox.jit.automaticPairing")

                Label(
                    hasPairing
                        ? words("Archivo de emparejamiento disponible", "Pairing file available")
                        : words("Falta el archivo de emparejamiento", "Pairing file missing"),
                    systemImage: hasPairing ? "checkmark.shield.fill" : "exclamationmark.triangle.fill"
                )
                .foregroundStyle(hasPairing ? .green : .orange)

                if let syncMessage {
                    Text(syncMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if provider == JITEnablerType.BuiltIn.rawValue {
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
                } else {
                    Text(words("Hay otro proveedor de JIT seleccionado.",
                               "Another JIT provider is currently selected."))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Button(words("Usar JIT integrado", "Use built-in JIT")) {
                        provider = JITEnablerType.BuiltIn.rawValue
                    }
                }
                if session.busy {
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

            if provider == JITEnablerType.BuiltIn.rawValue {
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
        switch result {
        case .disabled:
            syncMessage = words("Sincronización desactivada.", "Synchronization is off.")
        case .synchronized:
            syncMessage = words("Pairing de SideStore sincronizado.", "SideStore pairing synchronized.")
        case .alreadyCurrent:
            syncMessage = words("Pairing de SideStore actualizado.", "SideStore pairing is current.")
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
