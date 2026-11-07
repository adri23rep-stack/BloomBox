import SwiftUI
import UIKit


// MARK: - Shared profile-driven appearance for BloomBox screens

/// Reads the same active profile and favorite color selected in the wizard.
/// No parallel theme preference is introduced, so switching/editing profiles
/// immediately updates every screen that uses this palette.
enum BloomBoxProfileTheme {
    static let fallbackHex = "F064A7" // Kirby pink for profiles not yet configured

    static func hex(activeID: String, profilesData: Data) -> String {
        guard let profiles = try? JSONDecoder().decode([BloomBoxUserProfile].self, from: profilesData),
              !profiles.isEmpty else { return fallbackHex }
        let profile = profiles.first(where: { $0.id == activeID })
            ?? profiles.first(where: { $0.id == BloomBoxUserProfile.primaryID })
        let saved = profile?.accentHex.uppercased() ?? fallbackHex
        return BloomBoxProfileStore.palette.contains(saved) ? saved : fallbackHex
    }

    static func color(activeID: String, profilesData: Data) -> Color {
        BloomBoxWizardPalette.color(hex(activeID: activeID, profilesData: profilesData))
    }

    static func ink(for hex: String) -> Color {
        // Keep text/icon contrast legible on the bright Yellow Bowser accent.
        hex == "E5B83F" ? Color.black : Color.white
    }
}

/// Same hand-drawn, softly floating symbols used throughout the first-run wizard.
/// Pure decoration: never captures taps and respects Reduce Motion through the
/// existing BloomBoxWizardAmbientSymbols implementation.
struct BloomBoxProfileThemeBackdrop: View {
    @AppStorage(BloomBoxProfileStore.activeKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var activeID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var profilesData = Data()
    @Environment(\.colorScheme) private var scheme

    private var hex: String {
        BloomBoxProfileTheme.hex(activeID: activeID, profilesData: profilesData)
    }

    var body: some View {
        let tint = BloomBoxWizardPalette.color(hex)
        let dark = scheme == .dark
        return ZStack {
            (dark ? Color(red: 0.055, green: 0.055, blue: 0.095)
                  : Color(red: 0.975, green: 0.970, blue: 0.983))
            RadialGradient(
                colors: [tint.opacity(dark ? 0.23 : 0.15), .clear],
                center: .topLeading, startRadius: 12, endRadius: 590
            )
            RadialGradient(
                colors: [tint.opacity(dark ? 0.09 : 0.07), .clear],
                center: .bottomTrailing, startRadius: 20, endRadius: 460
            )
            BloomBoxWizardAmbientSymbols(isDark: dark, accentHex: hex)
                .opacity(dark ? 0.90 : 0.75)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Profile image used by the launcher greeting and the News profile switcher.
struct BloomBoxProfileAvatar: View {
    let profile: BloomBoxUserProfile
    let size: CGFloat
    @AppStorage(BloomBoxProfileStore.revisionKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var profileRevision = ""

    private var accent: Color { BloomBoxWizardPalette.color(profile.accentHex) }

    var body: some View {
        ZStack {
            Circle().fill(accent.opacity(0.24))
            if let photo = BloomBoxProfileStore.photo(for: profile) {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size - 7, height: size - 7)
                    .clipShape(Circle())
            } else {
                Image(systemName: "person.crop.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(accent)
                    .padding(8)
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(accent.opacity(0.88), lineWidth: 2))
        .id(profileRevision)
        .accessibilityHidden(true)
    }
}

/// Brief non-interactive greeting each time BloomBox comes to the foreground,
/// and again when the user selects a different profile.
struct BloomBoxActiveProfileIntro: View {
    let profile: BloomBoxUserProfile
    let onFinished: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @State private var showName = false
    @State private var visible = true

    private var spanish: Bool {
        language == "es" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es"))
    }
    private var accent: Color { BloomBoxWizardPalette.color(profile.accentHex) }

    var body: some View {
        HStack(spacing: 12) {
            BloomBoxProfileAvatar(profile: profile, size: 54)
                .shadow(color: accent.opacity(0.30), radius: 12)
            if showName || reduceMotion {
                VStack(alignment: .leading, spacing: 2) {
                    Text(spanish ? "Bienvenido" : "Welcome")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                    Text(profile.name)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .transition(.opacity.combined(with: .offset(x: -15)))
            }
        }
        .frame(width: showName || reduceMotion ? 273 : 60,
               height: 65, alignment: .leading)
        .padding(.horizontal, 9)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(accent.opacity(0.47), lineWidth: 1.2))
        .shadow(color: accent.opacity(0.16), radius: 17, y: 5)
        .opacity(visible ? 1 : 0)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel((spanish ? "Perfil activo: " : "Active profile: ") + profile.name)
        .allowsHitTesting(false)
        .task {
            if !reduceMotion {
                try? await Task.sleep(nanoseconds: 140_000_000)
                guard !Task.isCancelled else { return }
                withAnimation(.spring(response: 0.56, dampingFraction: 0.80)) {
                    showName = true
                }
            }
            do {
                try await Task.sleep(nanoseconds: 1_650_000_000)
            } catch { return }
            withAnimation(.easeOut(duration: 0.30)) { visible = false }
            do {
                try await Task.sleep(nanoseconds: 350_000_000)
            } catch { return }
            onFinished()
        }
    }
}

/// Replaces the clock in the News panel. The active profile only changes on
/// an explicit tap; LiveContainer's profile adapter selects app data on launch.
struct BloomBoxProfileSwitcherWidget: View {
    let onProfileSelected: () -> Void

    init(onProfileSelected: @escaping () -> Void = {}) {
        self.onProfileSelected = onProfileSelected
    }

    @AppStorage(BloomBoxProfileStore.activeKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var activeID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var profilesData = Data()
    @AppStorage("BloomBoxPreferredLanguage",
                store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"

    @State private var showManage = false

    private var spanish: Bool {
        language == "es" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("es"))
    }
    private var profiles: [BloomBoxUserProfile] {
        guard let decoded = try? JSONDecoder().decode([BloomBoxUserProfile].self,
                                                     from: profilesData),
              !decoded.isEmpty else { return [.initial] }
        return decoded.contains(where: { $0.id == BloomBoxUserProfile.primaryID })
            ? decoded : [.initial] + decoded
    }
    private var current: BloomBoxUserProfile {
        profiles.first(where: { $0.id == activeID }) ?? profiles[0]
    }
    private var tint: Color { BloomBoxWizardPalette.color(current.accentHex) }
    private var count: Int { max(4, profiles.count + 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack {
                Label(spanish ? "Perfiles" : "Profiles", systemImage: "person.crop.circle")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button { showManage = true } label: {
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 33, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(spanish ? "Administrar perfiles" : "Manage profiles")
                .accessibilityIdentifier("bloombox.news.profiles.manage")
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<count, id: \.self) { index in
                        if index < profiles.count {
                            let profile = profiles[index]
                            profileButton(profile)
                        } else if index == profiles.count {
                            Button { showManage = true } label: {
                                VStack(spacing: 6) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 21, weight: .medium))
                                        .foregroundStyle(.secondary)
                                        .frame(width: 54, height: 54)
                                        .overlay(Circle().strokeBorder(
                                            Color.primary.opacity(0.25), lineWidth: 3))
                                    Text(spanish ? "Nuevo" : "New")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                .frame(width: 56)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.news.profiles.add")
                        } else {
                            VStack(spacing: 6) {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(0.13), lineWidth: 5)
                                    .frame(width: 54, height: 54)
                                Text(" ")
                                    .font(.caption2)
                            }
                            .frame(width: 56)
                            .accessibilityHidden(true)
                        }
                    }
                }
                .padding(.vertical, 3)
                .padding(.horizontal, 2)
            }

            HStack(spacing: 9) {
                Circle()
                    .fill(tint)
                    .frame(width: 8, height: 8)
                Text(current.name)
                    .font(.system(size: 21, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Spacer()
                Text(spanish ? "Perfil activo" : "Active profile")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tint)
            }
        }
        .padding(17)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liveBoardGlass(radius: 26)
        .accessibilityIdentifier("bloombox.news.profiles")
        .sheet(isPresented: $showManage) {
            NavigationView {
                BloomBoxProfileManagementView()
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button(spanish ? "Listo" : "Done") {
                                showManage = false
                            }
                        }
                    }
            }
            .navigationViewStyle(.stack)
        }
    }

    private func profileButton(_ profile: BloomBoxUserProfile) -> some View {
        let selected = current.id == profile.id
        let color = BloomBoxWizardPalette.color(profile.accentHex)
        return Button {
            guard !selected else { return }
            BloomBoxProfileStore.activate(profile.id)
            UISelectionFeedbackGenerator().selectionChanged()
            onProfileSelected()
        } label: {
            VStack(spacing: 6) {
                BloomBoxProfileAvatar(profile: profile, size: 47)
                    .padding(3)
                    .overlay(Circle().strokeBorder(
                        selected ? color : Color.primary.opacity(0.12),
                        lineWidth: selected ? 3 : 1))
                    .shadow(color: selected ? color.opacity(0.35) : .clear, radius: 10)
                    .scaleEffect(selected ? 1.05 : 1)
                Text(profile.name)
                    .font(.caption2.weight(selected ? .semibold : .regular))
                    .foregroundStyle(selected ? color : .secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.32, dampingFraction: 0.75), value: selected)
        .accessibilityLabel(profile.name)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("bloombox.news.profiles.select." + profile.id)
    }
}
