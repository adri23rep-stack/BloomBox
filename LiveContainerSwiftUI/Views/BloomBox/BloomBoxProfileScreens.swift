import SwiftUI
import PhotosUI
import UIKit

/// Full first-launch wizard; preview goes through the same pages but never
/// writes profile/container metadata and never marks onboarding complete.
struct BloomBoxWizardFlowView: View {
    let isPreview: Bool
    let onFinish: () -> Void

    @State private var page = 0
    @State private var name = ""
    @State private var accentHex = BloomBoxProfileStore.active.accentHex
    @State private var photo: UIImage?
    @State private var selectedTheme = "KirbyPink"

    var body: some View {
        Group {
            switch page {
            case 0:
                BloomBoxWizardWelcomeView(
                    isPreview: isPreview, accentHex: accentHex,
                    onFinish: { forward(to: 1) },
                    onClosePreview: onFinish
                )
            case 1:
                BloomBoxProfileEditorView(
                    name: $name, accentHex: $accentHex, photo: $photo,
                    isPreview: isPreview, isWizardPage: true,
                    onBack: { forward(to: 0) },
                    onContinue: { forward(to: 2) }
                )
            case 2:
                BloomBoxWizardHighlightsView(
                    accentHex: accentHex,
                    onBack: { forward(to: 1) },
                    onNext: { forward(to: 3) }
                )
            case 3:
                BloomBoxWizardValidationView(
                    accentHex: accentHex, isPreview: isPreview,
                    onBack: { forward(to: 2) },
                    onFinish: { forward(to: 4) }
                )
            default:
                BloomBoxWizardThemeChoiceView(
                    selectedID: $selectedTheme, accentHex: accentHex,
                    isPreview: isPreview,
                    onBack: { forward(to: 3) },
                    onFinish: {
                        if !isPreview {
                            // Store the chosen theme before the home screen
                            // initializes its fresh-install layout.
                            LiveContainerPreferencesAdapter.defaults.set(
                                selectedTheme, forKey: BloomBoxBundledThemes.chosenKey)
                            BloomBoxProfileStore.finishInitialSetup(
                                name: name, accentHex: accentHex, image: photo)
                        }
                        onFinish()
                    }
                )
            }
        }
        .animation(.easeInOut(duration: 0.28), value: page)
    }

    private func forward(to newPage: Int) {
        withAnimation(.easeInOut(duration: 0.34)) { page = newPage }
    }
}

/// Shared by the wizard's second page and "Add profile" in Experiments.
struct BloomBoxProfileEditorView: View {
    @Binding var name: String
    @Binding var accentHex: String
    @Binding var photo: UIImage?
    let isPreview: Bool
    let isWizardPage: Bool
    let onBack: () -> Void
    let onContinue: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @State private var photoPickerOpen = false
    @FocusState private var nameFocused: Bool

    private var spanish: Bool {
        language == "es" || (language == "system"
                            && (Locale.preferredLanguages.first ?? "en").hasPrefix("es"))
    }
    private var dark: Bool { colorScheme == .dark }
    private var ink: Color { dark ? .white : Color(red: 0.14, green: 0.14, blue: 0.20) }
    private var accent: Color { BloomBoxWizardPalette.color(accentHex) }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                (dark ? Color(red: 0.042, green: 0.045, blue: 0.063)
                      : Color(red: 0.977, green: 0.973, blue: 0.985))
                    .ignoresSafeArea()
                RadialGradient(colors: [accent.opacity(dark ? 0.21 : 0.12), .clear],
                               center: .top, startRadius: 5,
                               endRadius: geometry.size.height * 0.8)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)

                BloomBoxWizardAmbientSymbols(isDark: dark, accentHex: accentHex)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                    .allowsHitTesting(false)

                ScrollView {
                    VStack(spacing: 22) {
                        HStack {
                            Label("BloomBox", systemImage: "sparkle")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                            Spacer()
                            Text("02 / 05")
                                .font(.system(size: 12, weight: .medium, design: .rounded)
                                        .monospacedDigit())
                        }
                        .foregroundStyle(ink.opacity(0.7))
                        .padding(.top, 18)

                        VStack(spacing: 8) {
                            Text(spanish
                                 ? "Elige tu foto de perfil y tu color favorito"
                                 : "Choose your profile photo and favorite color")
                                .font(.system(size: 27, weight: .heavy, design: .rounded))
                                .foregroundStyle(ink)
                                .multilineTextAlignment(.center)
                            Text(spanish ? "Tu espacio, tu estilo." : "Your space, your style.")
                                .font(.system(size: 15, weight: .medium, design: .rounded))
                                .foregroundStyle(ink.opacity(0.61))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.top, 5)

                        Button { photoPickerOpen = true } label: {
                            ZStack(alignment: .bottomTrailing) {
                                Circle()
                                    .fill(accent.opacity(dark ? 0.3 : 0.19))
                                    .frame(width: 162, height: 162)
                                    .overlay {
                                        Circle().stroke(accent.opacity(0.7), lineWidth: 3)
                                            .padding(4)
                                    }
                                    .overlay {
                                        if let photo {
                                            Image(uiImage: photo)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 148, height: 148)
                                                .clipShape(Circle())
                                        } else {
                                            Image(systemName: "person.crop.circle.fill")
                                                .resizable()
                                                .scaledToFit()
                                                .foregroundStyle(accent)
                                                .frame(width: 126, height: 126)
                                        }
                                    }
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 43, height: 43)
                                    .background(accent, in: Circle())
                                    .overlay(Circle().stroke(dark ? .black : .white, lineWidth: 3))
                            }
                            .frame(width: 178, height: 175)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(spanish ? "Elegir foto de perfil" : "Choose profile photo")
                        .accessibilityIdentifier("bloombox.wizard.profile.photo")
                        .sheet(isPresented: $photoPickerOpen) {
                            BloomBoxProfilePhotoPicker(image: $photo)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text(spanish ? "TU NOMBRE" : "YOUR NAME")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.55))
                            TextField(spanish ? "¿Cómo te llamas?" : "What's your name?", text: $name)
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                                .foregroundStyle(ink)
                                .textInputAutocapitalization(.words)
                                .autocorrectionDisabled()
                                .focused($nameFocused)
                                .padding(.horizontal, 17)
                                .frame(height: 54)
                                .background(ink.opacity(dark ? 0.085 : 0.045),
                                            in: RoundedRectangle(cornerRadius: 18))
                                .overlay(RoundedRectangle(cornerRadius: 18)
                                    .strokeBorder(accent.opacity(0.22), lineWidth: 1))
                                .accessibilityIdentifier("bloombox.wizard.profile.name")
                        }

                        VStack(alignment: .leading, spacing: 14) {
                            Text(spanish ? "TU COLOR FAVORITO" : "YOUR FAVORITE COLOR")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(ink.opacity(0.55))
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12),
                                                      count: 4), spacing: 17) {
                                ForEach(BloomBoxProfileStore.palette, id: \.self) { color in
                                    Button {
                                        nameFocused = false
                                        withAnimation(.spring(response: 0.28,
                                                              dampingFraction: 0.68)) {
                                            accentHex = color
                                        }
                                        UISelectionFeedbackGenerator().selectionChanged()
                                    } label: {
                                        Circle()
                                            .fill(BloomBoxWizardPalette.color(color))
                                            .frame(width: 46, height: 46)
                                            .overlay {
                                                if color == accentHex {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 17, weight: .heavy))
                                                        .foregroundStyle(color == "E5B83F"
                                                                         ? Color.black : Color.white)
                                                }
                                            }
                                            .padding(5)
                                            .overlay {
                                                Circle()
                                                    .strokeBorder(
                                                        color == accentHex
                                                            ? BloomBoxWizardPalette.color(color)
                                                            : ink.opacity(0.12),
                                                        lineWidth: color == accentHex ? 2.3 : 1)
                                            }
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("bloombox.wizard.profile.color.\(color)")
                                }
                            }
                            Text(spanish ? "Este color acompañará tu perfil y el wizard."
                                         : "This color follows your profile and the wizard.")
                                .font(.system(size: 12, weight: .regular, design: .rounded))
                                .foregroundStyle(ink.opacity(0.49))
                        }

                        if isPreview {
                            Label(spanish ? "Vista de prueba: no se guardarán perfiles ni fotos."
                                          : "Preview only: no profile or photo will be saved.",
                                  systemImage: "eye")
                                .font(.system(size: 12))
                                .foregroundStyle(ink.opacity(0.61))
                                .multilineTextAlignment(.center)
                        }

                        HStack(spacing: 12) {
                            Button(action: onBack) {
                                Image(systemName: "arrow.left")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(ink)
                                    .frame(width: 60, height: 56)
                                    .background(ink.opacity(0.09),
                                                in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            Button {
                                nameFocused = false
                                onContinue()
                            } label: {
                                HStack(spacing: 8) {
                                    Text(isWizardPage
                                         ? (spanish ? "Continuar" : "Continue")
                                         : (spanish ? "Crear perfil" : "Create profile"))
                                    Image(systemName: "arrow.right")
                                }
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(accentHex == "E5B83F" ? .black : .white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 56)
                                .background(accent, in: RoundedRectangle(cornerRadius: 18))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.wizard.profile.continue")
                        }
                        .padding(.top, 5)
                        .padding(.bottom, 24)
                    }
                    .padding(.horizontal, 28)
                    .frame(maxWidth: 500)
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

/// PHPicker gives photo access to an individual chosen image without requesting
/// full Photo Library permissions or touching the user's originals.
private struct BloomBoxProfilePhotoPicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> PHPickerViewController {
        var config = PHPickerConfiguration()
        config.filter = .images
        config.selectionLimit = 1
        let picker = PHPickerViewController(configuration: config)
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ controller: PHPickerViewController, context: Context) {}

    final class Coordinator: NSObject, PHPickerViewControllerDelegate {
        var parent: BloomBoxProfilePhotoPicker
        init(_ parent: BloomBoxProfilePhotoPicker) { self.parent = parent }

        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            guard let provider = results.first?.itemProvider,
                  provider.canLoadObject(ofClass: UIImage.self) else { return }
            _ = provider.loadObject(ofClass: UIImage.self) { value, _ in
                guard let image = value as? UIImage else { return }
                DispatchQueue.main.async { self.parent.image = image }
            }
        }
    }
}

/// Switches the active profile without replacing or deleting any guest data.
/// Secondary containers are created lazily by the launch adapter, per app.
struct BloomBoxProfileManagementView: View {
    @State private var profiles = BloomBoxProfileStore.profiles
    @State private var activeID = BloomBoxProfileStore.active.id
    @State private var creating = false
    @State private var draftName = ""
    @State private var draftAccent = BloomBoxProfileStore.palette[0]
    @State private var draftPhoto: UIImage?
    @State private var introProfile: BloomBoxUserProfile?
    @State private var introSequence = 0

    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    private var spanish: Bool {
        language == "es" || (language == "system"
                            && (Locale.preferredLanguages.first ?? "en").hasPrefix("es"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(spanish ? "Tus perfiles" : "Your profiles")
                    .font(.system(size: 29, weight: .heavy, design: .rounded))
                Text(spanish
                     ? "El primer perfil conserva los datos actuales. Los demás tendrán su propio contenedor por app."
                     : "Your first profile keeps existing app data. Other profiles get a separate container per app.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)

                ForEach(profiles) { profile in
                    Button {
                        BloomBoxProfileStore.activate(profile.id)
                        reload()
                        playProfileIntro(profile)
                        UISelectionFeedbackGenerator().selectionChanged()
                    } label: {
                        HStack(spacing: 15) {
                            ZStack {
                                Circle()
                                    .fill(BloomBoxWizardPalette.color(profile.accentHex).opacity(0.22))
                                if let image = BloomBoxProfileStore.photo(for: profile) {
                                    Image(uiImage: image)
                                        .resizable().scaledToFill().clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 25))
                                        .foregroundStyle(BloomBoxWizardPalette.color(profile.accentHex))
                                }
                            }
                            .frame(width: 62, height: 62)
                            VStack(alignment: .leading, spacing: 4) {
                                Text(profile.name)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                Text(profile.id == BloomBoxUserProfile.primaryID
                                     ? (spanish ? "Contenedores originales" : "Original containers")
                                     : (spanish ? "Contenedores separados" : "Separate containers"))
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 5)
                            Image(systemName: activeID == profile.id
                                  ? "checkmark.circle.fill" : "circle")
                                .font(.title2)
                                .foregroundStyle(BloomBoxWizardPalette.color(profile.accentHex))
                        }
                        .padding(14)
                        .background(
                            Color.secondary.opacity(activeID == profile.id ? 0.13 : 0.06),
                            in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("bloombox.profiles.select.\(profile.id)")
                }

                Button {
                    draftName = ""
                    draftAccent = BloomBoxProfileStore.palette[0]
                    draftPhoto = nil
                    creating = true
                } label: {
                    Label(spanish ? "Crear otro perfil" : "Create another profile",
                          systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("bloombox.profiles.add")

                Text(spanish
                     ? "El perfil activo se usa al abrir apps. Si alguna sigue abierta, ciérrala antes de cambiar: no se moverán sus archivos ni se reiniciará por la fuerza."
                     : "The active profile is used on the next app launch. Close any running apps before switching; their files won't be moved or force-closed.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
        }
        .navigationTitle(spanish ? "Perfiles" : "Profiles")
        .onAppear(perform: reload)
        .overlay(alignment: .top) {
            if let introProfile {
                BloomBoxActiveProfileIntro(profile: introProfile) {
                    self.introProfile = nil
                }
                .id(introSequence)
                .padding(.top, 10)
                .allowsHitTesting(false)
            }
        }
        .fullScreenCover(isPresented: $creating) {
            BloomBoxProfileEditorView(
                name: $draftName, accentHex: $draftAccent, photo: $draftPhoto,
                isPreview: false, isWizardPage: false,
                onBack: { creating = false },
                onContinue: {
                    let new = BloomBoxProfileStore.add(name: draftName,
                                                       accentHex: draftAccent,
                                                       image: draftPhoto)
                    BloomBoxProfileStore.activate(new.id)
                    reload()
                    creating = false
                    playProfileIntro(new)
                }
            )
            .preferredColorScheme(BloomBoxWizardSystemAppearance.current)
        }
    }

    private func playProfileIntro(_ profile: BloomBoxUserProfile) {
        introProfile = profile
        introSequence += 1
    }

    private func reload() {
        profiles = BloomBoxProfileStore.profiles
        activeID = BloomBoxProfileStore.active.id
    }
}
