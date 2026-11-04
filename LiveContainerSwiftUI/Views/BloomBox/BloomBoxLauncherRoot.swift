import SwiftUI

/// BloomBox's own mode host. LiveContainer stays mounted for guest/JIT/signing.
struct BloomBoxLauncherRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("LiveBoardMode", store: LCUtils.appGroupUserDefault) private var mode = "ios"
    @AppStorage("BloomBoxPrimaryLauncher", store: LCUtils.appGroupUserDefault) private var primaryLauncher = "ios"
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault) private var language = "system"
    @State private var ready = false
    @State private var showModeSheet = false
    @State private var showDestination = false
    @State private var launchGameAfterDismiss = false

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
        .sheet(isPresented: $showModeSheet, onDismiss: {
            NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil)
            if launchGameAfterDismiss {
                launchGameAfterDismiss = false
                NotificationCenter.default.post(name: Notification.Name("BloomBoxRequestGameMode"), object: nil)
            }
        }) {
            NavigationView {
                ScrollView {
                    VStack(spacing: 16) {
                        launcherOption(title: "iOS Home", detail: "Escritorio, apps y widgets.",
                                       icon: "square.grid.3x3.fill", value: "ios")
                        launcherOption(title: "GameBox", detail: "Biblioteca horizontal, RAM+ y JIT por app.",
                                       icon: "gamecontroller.fill", value: "cinematic")
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Launcher principal").font(.headline)
                            Picker("Al iniciar BloomBox", selection: $primaryLauncher) {
                                Text("iOS Home").tag("ios")
                                Text("GameBox").tag("cinematic")
                            }
                            .pickerStyle(.segmented)
                            .accessibilityIdentifier("bloombox.primaryLauncher")
                            Text("Se aplica al abrir BloomBox desde cero. El modo temporal no cambia tu selección principal.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        .padding(18)
                        .background(Color.white.opacity(0.06),
                                    in: RoundedRectangle(cornerRadius: 20))
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
            NotificationCenter.default.post(name: LiveBoardControllerInput.resumeNotification, object: nil)
        }) {
            VStack(spacing: 0) {
                HStack { Spacer(); Button("Done") { showDestination = false }.padding() }
                Group {
                    switch sharedModel.selectedTab {
                    case .sources: LCSourcesView()
                    case .tweaks: LCTweaksView()
                    case .settings: LCSettingsView()
                    case .apps: EmptyView()
                    }
                }
            }
        }
        .onChange(of: sharedModel.selectedTab) { tab in
            if tab == .apps {
                showDestination = false
            } else {
                NotificationCenter.default.post(name: LiveBoardControllerInput.pauseNotification, object: nil)
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
        }
    }

    private func launcherOption(title: String, detail: String, icon: String, value: String) -> some View {
        Button {
            if value == "cinematic" {
                // The central launch gate validates RAM+/JIT; this only requests GameBox.
                launchGameAfterDismiss = true
                showModeSheet = false
            } else {
                mode = value
            }
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
