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
    @State private var selectedLauncher = "hybrid"

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
                    isPreview: isPreview, isWizardPage: true, isEditing: false,
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
            case 4:
                BloomBoxWizardThemeChoiceView(
                    selectedID: $selectedTheme, accentHex: accentHex,
                    isPreview: isPreview,
                    onBack: { forward(to: 3) },
                    onFinish: { forward(to: 5) }
                )
            default:
                BloomBoxWizardLauncherChoiceView(
                    selection: $selectedLauncher, accentHex: accentHex,
                    onBack: { forward(to: 4) },
                    onFinish: {
                        if !isPreview {
                            // Save the theme and profile before the launcher mode.
                            // Pre-existing installs are not changed by wizard previews.
                            let defaults = LiveContainerPreferencesAdapter.defaults
                            defaults.set(selectedTheme, forKey: BloomBoxBundledThemes.chosenKey)
                            BloomBoxProfileStore.finishInitialSetup(
                                name: name, accentHex: accentHex, image: photo)
                            BloomBoxLaunchPreferences.setPreferredMode(
                                selectedLauncher, profileID: BloomBoxUserProfile.primaryID,
                                defaults: defaults)
                            defaults.set(
                                BloomBoxLaunchPreferences.runtimeMode(for: selectedLauncher),
                                forKey: BloomBoxLaunchPreferences.sessionKey)
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
    let isEditing: Bool
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
                                 ? (isEditing ? "Edita tu perfil" : "Elige tu foto de perfil y tu color favorito")
                                 : (isEditing ? "Edit your profile" : "Choose your profile photo and favorite color"))
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

                        if isEditing && photo != nil {
                            Button {
                                photo = nil
                            } label: {
                                Label(spanish ? "Quitar foto" : "Remove photo", systemImage: "person.crop.circle.badge.xmark")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(ink.opacity(0.70))
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("bloombox.profiles.edit.removePhoto")
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
                                         : (isEditing
                                             ? (spanish ? "Guardar cambios" : "Save changes")
                                             : (spanish ? "Crear perfil" : "Create profile")))
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
    @State private var editingProfile: BloomBoxUserProfile?
    @State private var editName = ""
    @State private var editAccent = BloomBoxProfileStore.palette[0]
    @State private var editPhoto: UIImage?
    @State private var pendingDeletion: BloomBoxUserProfile?
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
                    profileRow(profile)
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
                isPreview: false, isWizardPage: false, isEditing: false,
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
        .fullScreenCover(item: $editingProfile) { original in
            BloomBoxProfileEditorView(
                name: $editName, accentHex: $editAccent, photo: $editPhoto,
                isPreview: false, isWizardPage: false, isEditing: true,
                onBack: { editingProfile = nil },
                onContinue: {
                    let updated = BloomBoxProfileStore.edit(
                        id: original.id, name: editName, accentHex: editAccent,
                        image: editPhoto)
                    editingProfile = nil
                    reload()
                    if let updated, updated.id == activeID {
                        playProfileIntro(updated)
                    }
                }
            )
            .preferredColorScheme(BloomBoxWizardSystemAppearance.current)
        }
        .alert(item: $pendingDeletion) { profile in
            Alert(
                title: Text(spanish ? "¿Eliminar perfil?" : "Delete profile?"),
                message: Text(spanish
                    ? "Se eliminará «\(profile.name)» de BloomBox y su foto. Los contenedores y datos de sus apps NO se borrarán. Esta acción no se puede deshacer desde aquí."
                    : "«\(profile.name)» and its picture will be removed from BloomBox. Guest app containers and data will NOT be deleted. This action can't be undone here."),
                primaryButton: .destructive(
                    Text(spanish ? "Eliminar perfil" : "Delete profile")
                ) {
                    let wasActive = BloomBoxProfileStore.active.id == profile.id
                    if BloomBoxProfileStore.delete(id: profile.id) {
                        reload()
                        if wasActive {
                            playProfileIntro(BloomBoxProfileStore.active)
                        }
                    }
                },
                secondaryButton: .cancel(Text(spanish ? "Cancelar" : "Cancel"))
            )
        }
    }

    private func profileRow(_ profile: BloomBoxUserProfile) -> some View {
        HStack(spacing: 0) {
            Button {
                if activeID != profile.id {
                    BloomBoxProfileStore.activate(profile.id)
                    reload()
                    playProfileIntro(profile)
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            } label: {
                HStack(spacing: 15) {
                    BloomBoxProfileAvatar(profile: profile, size: 62)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(profile.id == BloomBoxUserProfile.primaryID
                             ? (spanish ? "Contenedores originales" : "Original containers")
                             : (spanish ? "Contenedores separados" : "Separate containers"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 5)
                    Image(systemName: activeID == profile.id
                          ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(BloomBoxWizardPalette.color(profile.accentHex))
                }
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("bloombox.profiles.select.\(profile.id)")

            Menu {
                Button {
                    beginEditing(profile)
                } label: {
                    Label(spanish ? "Editar perfil" : "Edit profile", systemImage: "pencil")
                }
                if profile.id != BloomBoxUserProfile.primaryID {
                    Button(role: .destructive) {
                        pendingDeletion = profile
                    } label: {
                        Label(spanish ? "Eliminar perfil" : "Delete profile",
                              systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 43, height: 62)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel(spanish ? "Opciones de \(profile.name)" : "Options for \(profile.name)")
            .accessibilityIdentifier("bloombox.profiles.options.\(profile.id)")
        }
        .padding(14)
        .background(Color.secondary.opacity(activeID == profile.id ? 0.13 : 0.06),
                    in: RoundedRectangle(cornerRadius: 24))
    }

    private func beginEditing(_ profile: BloomBoxUserProfile) {
        editName = profile.name
        editAccent = profile.accentHex
        editPhoto = BloomBoxProfileStore.photo(for: profile)
        editingProfile = profile
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


/// Last onboarding page: choose the actual first-run experience.
/// Hybrid is recommended for new profiles and works without an attached controller.
struct BloomBoxWizardLauncherChoiceView: View {
    @Binding var selection: String
    let accentHex: String
    let onBack: () -> Void
    let onFinish: () -> Void

    @Environment(\.colorScheme) private var scheme
    @AppStorage("BloomBoxPreferredLanguage", store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"

    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    private var tint: Color { BloomBoxWizardPalette.color(accentHex) }
    private var ink: Color {
        scheme == .dark ? .white : Color(red: 0.14, green: 0.13, blue: 0.22)
    }

    var body: some View {
        ZStack {
            (scheme == .dark ? Color(red: 0.042, green: 0.045, blue: 0.063) :
             Color(red: 0.977, green: 0.973, blue: 0.985))
                .ignoresSafeArea()
            RadialGradient(colors: [tint.opacity(0.16), .clear],
                           center: .topLeading, startRadius: 12, endRadius: 620)
                .ignoresSafeArea()
            BloomBoxWizardAmbientSymbols(isDark: scheme == .dark, accentHex: accentHex)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            ScrollView {
                VStack(alignment: .leading, spacing: 21) {
                    Label(english ? "YOUR EXPERIENCE" : "TU EXPERIENCIA",
                          systemImage: "gamecontroller.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(tint)
                    Text(english ? "How do you want to use BloomBox?" :
                         "¿Cómo quieres usar BloomBox?")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(english ? "You can change this at any time. Your apps and profiles stay intact." :
                         "Puedes cambiarlo cuando quieras. Tus apps y perfiles se conservan.")
                        .font(.subheadline)
                        .foregroundStyle(ink.opacity(0.68))

                    option("hybrid", symbol: "square.on.square",
                           title: "Híbrido", englishTitle: "Hybrid",
                           detail: "Escritorio iOS y GameBox automático para juegos compatibles.",
                           englishDetail: "iOS Home with automatic GameBox for compatible games.",
                           recommended: true)
                    option("ios", symbol: "square.grid.3x3.fill",
                           title: "Launcher iOS", englishTitle: "iOS Home",
                           detail: "Escritorio, widgets y Dock. GameBox a un toque.",
                           englishDetail: "Home Screen, widgets and Dock. GameBox one tap away.")
                    option("gamebox", symbol: "gamecontroller.fill",
                           title: "GameBox", englishTitle: "GameBox",
                           detail: "Inicia directamente en tu biblioteca de juegos.",
                           englishDetail: "Start directly in your game library.")

                    HStack(spacing: 12) {
                        Button(action: onBack) {
                            Label(english ? "Back" : "Atrás", systemImage: "chevron.left")
                                .frame(maxWidth: .infinity)
                                .frame(height: 53)
                                .background(ink.opacity(0.09),
                                            in: RoundedRectangle(cornerRadius: 17))
                        }
                        Button(action: onFinish) {
                            HStack {
                                Text(english ? "Start BloomBox" : "Iniciar BloomBox")
                                Image(systemName: "arrow.right")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 53)
                            .foregroundStyle(BloomBoxProfileTheme.ink(for: accentHex))
                            .background(tint, in: RoundedRectangle(cornerRadius: 17))
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .buttonStyle(.plain)
                    .foregroundStyle(ink)
                    .padding(.top, 8)
                }
                .padding(.horizontal, 22)
                .padding(.top, 44)
                .padding(.bottom, 36)
            }
        }
        .accessibilityIdentifier("bloombox.wizard.launcher")
    }

    private func option(_ id: String, symbol: String, title: String,
                        englishTitle: String, detail: String, englishDetail: String,
                        recommended: Bool = false) -> some View {
        let chosen = selection == id
        return Button {
            withAnimation(.easeInOut(duration: 0.18)) { selection = id }
            UISelectionFeedbackGenerator().selectionChanged()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(tint)
                    .frame(width: 53, height: 53)
                    .background(tint.opacity(0.14), in: RoundedRectangle(cornerRadius: 15))
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(english ? englishTitle : title)
                            .font(.headline)
                        if recommended {
                            Text(english ? "RECOMMENDED" : "RECOMENDADO")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(BloomBoxProfileTheme.ink(for: accentHex))
                                .padding(.horizontal, 7).padding(.vertical, 4)
                                .background(tint, in: Capsule())
                        }
                    }
                    Text(english ? englishDetail : detail)
                        .font(.caption)
                        .foregroundStyle(ink.opacity(0.69))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 4)
                Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(chosen ? tint : ink.opacity(0.40))
                    .font(.title3)
            }
            .foregroundStyle(ink)
            .padding(15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(chosen ? 0.14 : 0.055),
                        in: RoundedRectangle(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22)
                    .strokeBorder(chosen ? tint.opacity(0.80) : ink.opacity(0.11),
                                  lineWidth: chosen ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .accessibilityIdentifier("bloombox.wizard.launcher." + id)
    }
}
