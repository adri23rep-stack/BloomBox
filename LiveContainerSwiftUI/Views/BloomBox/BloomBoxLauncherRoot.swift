import SwiftUI

/// BloomBox's own mode host. LiveContainer stays mounted for guest/JIT/signing.
struct BloomBoxLauncherRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "ios"
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault) private var language = "system"
    @State private var ready = false
    @State private var showModeSheet = false
    @State private var showDestination = false
    @State private var showDiagnostics = false
    @State private var showRecoveryNotice = false

    private var locale: Locale {
        Locale(identifier: language == "system" ? (Locale.preferredLanguages.first ?? "en") : language)
    }

    var body: some View {
        Group {
            if ready {
                LCAppListView(openInterface: { showModeSheet = true })
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .environment(\.locale, locale)
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showModeSheet) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        launcherOption(title: "iOS Home", detail: "Escritorio, apps y widgets.",
                                       icon: "square.grid.3x3.fill", value: "ios")
                        if #available(iOS 16.0, *) {
                            launcherOption(title: "GameBox v2", detail: "Interfaz de consola con carátulas, fondos y cristal.",
                                           icon: "gamecontroller.fill", value: "gamebox")
                        }
                        launcherOption(title: "Espacio reservado", detail: "Listo para una futura función.",
                                       icon: "square.dashed", value: "reserved")
                        NavigationLink(destination: BloomBoxDiagnosticsView()) {
                            Label("Diagnósticos y recuperación", systemImage: "waveform.path.ecg")
                                .font(.headline)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        Text("El escritorio es el inicio predeterminado de BloomBox.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle("Interface")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showModeSheet = false }
                    }
                }
            }
            .navigationViewStyle(.stack)
            .environment(\.locale, locale)
        }
        .sheet(isPresented: $showDestination, onDismiss: {
            sharedModel.selectedTab = .apps
        }) {
            VStack(spacing: 0) {
                HStack { Spacer(); Button("Done") { showDestination = false }.padding() }
                destinationContent
            }
        }
        .sheet(isPresented: $showDiagnostics) {
            NavigationView {
                BloomBoxDiagnosticsView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Listo") { showDiagnostics = false }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
        .alert("GameBox recuperado", isPresented: $showRecoveryNotice) {
            Button("Ver registro") { showDiagnostics = true }
            Button("Seguir en inicio", role: .cancel) { }
        } message: {
            Text("La sesión anterior terminó mientras GameBox estaba abierto. BloomBox inició en el escritorio para evitar un ciclo de cierres. Guardamos los últimos pasos para investigar.")
        }
        .onChange(of: sharedModel.selectedTab) { tab in
            if tab == .apps {
                showDestination = false
            } else {
                showDestination = true
            }
        }
        .onAppear {
            if !BloomBoxLauncherSession.restored {
                mode = BloomBoxLaunchPreferences.resetForNewProcess(
                    defaults: LCUtils.appGroupUserDefault)
                BloomBoxLauncherSession.restored = true
            }
            ready = true
            showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
        }
    }

    @ViewBuilder private var destinationContent: some View {
        switch sharedModel.selectedTab {
        case .apps: EmptyView()
        case .settings: LCSettingsView()
        case .sources: LCSourcesView()
        case .tweaks: LCTweaksView()
        }
    }

    private func launcherOption(title: String, detail: String, icon: String, value: String) -> some View {
        Button {
            mode = value
            showModeSheet = false
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title).frame(width: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(title).font(.headline)
                    Text(detail).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: mode == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.blue)
            }
            .padding(20)
            .background(Color.white.opacity(mode == value ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(mode == value ? .isSelected : [])
    }
}

@MainActor private enum BloomBoxLauncherSession {
    static var restored = false
}

// Source compatibility for the existing LiveContainer host.
typealias LiveBoardRootView = BloomBoxLauncherRootView
