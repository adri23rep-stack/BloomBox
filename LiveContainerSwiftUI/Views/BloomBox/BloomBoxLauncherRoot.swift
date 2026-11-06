import SwiftUI
import GameController
import UIKit

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
    @State private var showFirstRunWizard = false
    @AppStorage("BloomBoxWizardInitialCompletedV1", store: LCUtils.appGroupUserDefault)
    private var wizardCompleted = false
    @AppStorage("BloomBoxAutoGameBoxOnController", store: LCUtils.appGroupUserDefault)
    private var autoGameBoxOnController = true

    private var locale: Locale {
        Locale(identifier: language == "system" ? (Locale.preferredLanguages.first ?? "en") : language)
    }

    var body: some View {
        Group {
            if ready {
                LCAppListView(openInterface: { showModeSheet = true })
                    .preferredColorScheme(.dark)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .environment(\.locale, locale)
        .fullScreenCover(isPresented: $showFirstRunWizard) {
            BloomBoxWizardFlowView(isPreview: false) {
                wizardCompleted = true
                showFirstRunWizard = false
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
            }
            .preferredColorScheme(BloomBoxWizardSystemAppearance.current)
        }
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
                        Toggle(isOn: $autoGameBoxOnController) {
                            Label("Abrir GameBox al conectar un control", systemImage: "gamecontroller.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Text("La detección funciona al usar BloomBox. iOS no permite abrirla desde cero cuando está cerrada o suspendida.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
            if !wizardCompleted {
                showFirstRunWizard = true
            } else {
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
                routeConnectedControllerIfAllowed()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            routeConnectedControllerIfAllowed()
        }
    }

    private func routeConnectedControllerIfAllowed() {
        // Do not relaunch an interrupted GameBox session or steal focus from a guest.
        guard autoGameBoxOnController, ready, wizardCompleted,
              !showFirstRunWizard, !showRecoveryNotice,
              !showDestination, !showModeSheet, mode != "gamebox",
              UIApplication.shared.applicationState == .active,
              !GCController.controllers().isEmpty else { return }
        mode = "gamebox"
        BloomBoxCrashJournal.shared.record("gamebox.controller.auto_enter")
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
                    Text(BloomBoxGameBoxL10n.t(title)).font(.headline)
                    Text(BloomBoxGameBoxL10n.t(detail)).font(.subheadline).foregroundStyle(.secondary)
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
