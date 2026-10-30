import SwiftUI
import UniformTypeIdentifiers

struct LiveBoardJITSetup: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("LCJITEnablerType", store: LCUtils.appGroupUserDefault) private var provider = JITEnablerType.SideJITServer.rawValue
    @ObservedObject private var session = LiveBoardJITSession.shared
    @ObservedObject private var pairing = ManzanaOnDevicePairing.shared
    @State private var importing = false
    @State private var hasPairing = FileManager.default.fileExists(atPath: LiveBoardBuiltInJIT.pairingURL.path)
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
        .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                    do {
                        let url = try result.get()
                        try LiveBoardBuiltInJIT.importPairing(url)
                        hasPairing = true
                        session.message = "Pairing file imported. Connect LocalDevVPN, then launch an app with JIT."
                    } catch { session.message = error.localizedDescription }
                }
        .onChange(of: pairing.phase) { phase in
                if case .paired = phase {
                    hasPairing = true
                    provider = JITEnablerType.BuiltIn.rawValue
                    session.message = "Pairing saved. Keep LocalDevVPN connected, then tap Prepare device."
                }
            }
    }

    private var jitForm: some View {
        Form {
                Section("JIT method") {
                    Picker("Enable JIT using", selection: $provider) {
                        ForEach(JITEnablerType.allCases) { Text($0.displayName).tag($0.rawValue) }
                    }
                    Button("Use built-in JIT") { provider = JITEnablerType.BuiltIn.rawValue }
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
                                do { try FileManager.default.removeItem(at: LiveBoardBuiltInJIT.pairingURL); hasPairing = false; session.message = "Pairing file removed." }
                                catch { session.message = error.localizedDescription }
                            }
                        }
                        Text("Enable Developer Mode in Settings. Connect your existing LocalDevVPN before Prepare device or Launch with JIT; SideStore can keep using the same VPN. The first launch may download a developer disk image.")
                        Label(LCUtils.strataCanDebug() ? "Debugging permission available" : "Re-signing required: debugging permission missing", systemImage: LCUtils.strataCanDebug() ? "checkmark.shield" : "exclamationmark.shield")
                        Text("JIT applies only to guests installed inside BloomBox, not other iPhone apps. It runs through LiveProcess, and some guest engines need a matching iOS 27 JIT script. Keep extensions when updating.").foregroundStyle(.secondary)
                    }
                    Section("Connection check") {
                        Button("Prepare device") { perform("prepare") }.disabled(session.busy || !hasPairing)
                        Button("Reset developer disk image cache") { perform("reset") }.disabled(session.busy || !hasPairing)
                        if session.busy {
                            ProgressView("Working…")
                            Button("Cancel") { session.cancel() }
                        }
                        if let operationSucceeded = session.success {
                            Label(operationSucceeded ? "Completed" : "Could not complete", systemImage: operationSucceeded ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(operationSucceeded ? .green : .orange)
                        }
                        if !session.message.isEmpty { Text(session.message).font(.footnote).textSelection(.enabled).accessibilityIdentifier("jit.status") }
                    }
                    Section("Launch") {
                        Text("Touch and hold an app, or open its console options, and choose Launch with JIT. BloomBox prepares the device and connects its helper automatically. Errors appear in the launch window.")
                    }
                } else {
                    Section("External provider") {
                        Text("Configure pairing and the required connection in your selected provider, then choose Launch with JIT on an app.")
                        NavigationLink("Provider settings") { LCSettingsView() }
                    }
                }
                if provider != JITEnablerType.BuiltIn.rawValue && !session.message.isEmpty { Section { Text(session.message) } }
                Section { NavigationLink("JIT-less setup and diagnostics") { LCJITLessDiagnoseView() } }
        }
    }

    private func perform(_ operation: String) { session.start(operation) }
}
