import SwiftUI
import GameController
import UIKit

/// BloomBox's own mode host. LiveContainer stays mounted for guest/JIT/signing.
struct BloomBoxLauncherRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var introProfile: BloomBoxUserProfile?
    @State private var introSequence = 0
    @State private var lastIntroAt = Date.distantPast
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "ios"
    @AppStorage(BloomBoxProfileStore.activeKey, store: LCUtils.appGroupUserDefault)
    private var activeProfileID = BloomBoxUserProfile.primaryID
    private var preferredExperience: String {
        BloomBoxLaunchPreferences.preferredMode(
            defaults: LCUtils.appGroupUserDefault, profileID: activeProfileID)
    }
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
    // Ask iOS to prioritize BloomBox's bottom-edge gestures. iOS controls
    // whether a second swipe is needed; never trap the user in the launcher.
    @AppStorage("BloomBoxDeferBottomSystemGestures", store: LCUtils.appGroupUserDefault)
    private var protectBottomGestures = true
    @AppStorage(BloomBoxLaunchPreferences.shortcutKey, store: LCUtils.appGroupUserDefault)
    private var showGameBoxShortcut = true

    private var locale: Locale {
        Locale(identifier: language == "system" ? (Locale.preferredLanguages.first ?? "en") : language)
    }

    var body: some View {
        if #available(iOS 16.0, *) {
            launcherContent
                .defersSystemGestures(on: protectBottomGestures ? .bottom : [])
        } else {
            launcherContent
        }
    }

    private var launcherContent: some View {
        Group {
            if ready {
                LCAppListView(openInterface: { showModeSheet = true })
                    .preferredColorScheme(.dark)
            } else {
                Color.black.ignoresSafeArea()
            }
        }
        .environment(\.locale, locale)
        .overlay(alignment: .top) {
            if let introProfile, wizardCompleted, !showFirstRunWizard {
                BloomBoxActiveProfileIntro(profile: introProfile) {
                    self.introProfile = nil
                }
                .id(introSequence)
                .padding(.top, 24)
                .zIndex(200)
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .fullScreenCover(isPresented: $showFirstRunWizard) {
            BloomBoxWizardFlowView(isPreview: false) {
                wizardCompleted = true
                showFirstRunWizard = false
                mode = BloomBoxLaunchPreferences.runtimeMode(for: preferredExperience)
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
                showProfileIntro()
            }
            .preferredColorScheme(BloomBoxWizardSystemAppearance.current)
        }
        .sheet(isPresented: $showModeSheet) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        launcherOption(
                            title: BloomBoxL10n.isEnglish ? "Hybrid · Recommended" : "Híbrido · Recomendado",
                            detail: BloomBoxL10n.isEnglish ? "iOS Home; compatible games enter GameBox automatically." : "Escritorio iOS; los juegos compatibles entran automáticamente en GameBox.",
                            icon: "square.on.square", value: "hybrid")
                        launcherOption(title: "iOS Home", detail: BloomBoxL10n.t("Escritorio, apps y widgets."),
                                       icon: "square.grid.3x3.fill", value: "ios")
                        if #available(iOS 16.0, *) {
                            launcherOption(title: "GameBox v2", detail: BloomBoxL10n.t("Interfaz de consola con carátulas, fondos y cristal."),
                                           icon: "gamecontroller.fill", value: "gamebox")
                        }
                        NavigationLink(destination: BloomBoxDiagnosticsView()) {
                            Label("Diagnósticos y recuperación", systemImage: "waveform.path.ecg")
                                .font(.headline)
                                .padding(20)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)
                        Toggle(isOn: $showGameBoxShortcut) {
                            Label(BloomBoxL10n.isEnglish ? "Show GameBox button on Home" : "Mostrar botón GameBox en el escritorio",
                                  systemImage: "gamecontroller.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Toggle(isOn: $protectBottomGestures) {
                            Label(BloomBoxL10n.isEnglish ? "Protect bottom-edge gestures" : "Proteger gestos del borde inferior",
                                  systemImage: "hand.draw.fill")
                        }
                        .tint(.cyan)
                        .padding(16)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 16))
                        Text(BloomBoxL10n.isEnglish
                             ? "Reduces accidental exits while using BloomBox. iOS may require a second swipe to go Home. You can turn this off anytime."
                             : "Evita salidas accidentales del launcher. iOS puede pedir un segundo deslizamiento para ir al inicio. Puedes desactivarlo cuando quieras.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        Text(BloomBoxL10n.isEnglish ? "Your choice is saved per profile. Existing profiles keep their iOS Home setting until you change it." : "Tu selección se guarda por perfil. Los perfiles existentes conservan su inicio iOS hasta que lo cambies.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
                .navigationTitle(BloomBoxL10n.isEnglish ? "Interface" : "Interfaz")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(BloomBoxL10n.isEnglish ? "Done" : "Listo") { showModeSheet = false }
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
                HStack { Spacer(); Button(BloomBoxL10n.isEnglish ? "Done" : "Listo") { showDestination = false }.padding() }
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
                    defaults: LCUtils.appGroupUserDefault, profileID: activeProfileID)
                BloomBoxLauncherSession.restored = true
            }
            ready = true
            if !wizardCompleted {
                showFirstRunWizard = true
            } else {
                showRecoveryNotice = BloomBoxCrashJournal.shared.previousInterrupted
                routeConnectedControllerIfAllowed()
                showProfileIntro()
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase == .active {
                showProfileIntro()
            } else if phase == .background {
                introProfile = nil
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: BloomBoxProfileStore.didActivate)) { note in
            // Resolve the ID from the notification itself. AppStorage can
            // re-render one frame later, especially when switching in GameBox.
            let id = (note.object as? String) ?? BloomBoxProfileStore.active.id
            let selection = BloomBoxLaunchPreferences.preferredMode(
                defaults: LCUtils.appGroupUserDefault, profileID: id)
            mode = BloomBoxLaunchPreferences.runtimeMode(for: selection)
            showProfileIntro(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: .GCControllerDidConnect)) { _ in
            routeConnectedControllerIfAllowed()
        }
    }

    private func showProfileIntro(force: Bool = false) {
        guard ready, wizardCompleted, !showFirstRunWizard, !showRecoveryNotice,
              !showDestination, !showModeSheet,
              UIApplication.shared.applicationState == .active else { return }
        // onAppear and scenePhase can happen together. One greeting is enough,
        // but selecting another profile must always show its own greeting.
        if !force && Date().timeIntervalSince(lastIntroAt) < 2.5 { return }
        lastIntroAt = Date()
        introSequence += 1
        introProfile = BloomBoxProfileStore.active
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
            BloomBoxLaunchPreferences.setPreferredMode(
                value, profileID: activeProfileID,
                defaults: LCUtils.appGroupUserDefault)
            mode = BloomBoxLaunchPreferences.runtimeMode(for: value)
            showModeSheet = false
        } label: {
            HStack(spacing: 16) {
                Image(systemName: icon).font(.title).frame(width: 48)
                VStack(alignment: .leading, spacing: 6) {
                    Text(BloomBoxGameBoxL10n.t(title)).font(.headline)
                    Text(BloomBoxGameBoxL10n.t(detail)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(minLength: 8)
                Image(systemName: preferredExperience == value ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(.blue)
            }
            .padding(20)
            .background(Color.white.opacity(preferredExperience == value ? 0.12 : 0.05),
                        in: RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(preferredExperience == value ? .isSelected : [])
    }
}

@MainActor private enum BloomBoxLauncherSession {
    static var restored = false
}

// Source compatibility for the existing LiveContainer host.
typealias LiveBoardRootView = BloomBoxLauncherRootView
