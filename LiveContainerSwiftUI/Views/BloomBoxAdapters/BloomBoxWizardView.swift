// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (c) 2026 adri23rep-stack (original BloomBox material only).
import SwiftUI
import PhotosUI

/// Visual, resumable setup. No credential, certificate or pairing secret is copied
/// into the Wizard; its two setup buttons open the real existing modules.
@available(iOS 16.0, *)
struct BloomBoxWizardView: View {
    let mode: BloomBoxWizardMode
    let onDone: () -> Void

    @EnvironmentObject private var sharedModel: SharedModel
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var language = "system"
    @ObservedObject private var ram = BloomBoxRAMPlus.shared
    @State private var page = 0
    @State private var profileCount = 1
    @State private var name1 = ""
    @State private var name2 = ""
    @State private var chosenTheme = "KirbyPink"
    @State private var photoOne: PhotosPickerItem?
    @State private var photoTwo: PhotosPickerItem?
    @State private var photoRevision = 0
    @State private var showJIT = false
    @State private var showRAM = false
    @State private var errorMessage: String?
    @State private var jitRefresh = 0

    private let defaults = LCUtils.appGroupUserDefault
    private var english: Bool {
        language == "en" || (language == "system"
            && (Locale.preferredLanguages.first ?? "es").lowercased().hasPrefix("en"))
    }
    private func t(_ spanish: String, _ englishText: String) -> String {
        english ? englishText : spanish
    }
    private var allGuests: [LCAppModel] { sharedModel.apps + sharedModel.hiddenApps }
    private var paired: Bool { _ = jitRefresh; return BloomBoxJITPairingStorage().hasRecord }
    private var jitReady: Bool { paired && LCUtils.bloomBoxCanDebug() }

    var body: some View {
        ZStack {
            wallpaperBackground
            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    Group {
                        if mode == .update {
                            updateScreen
                        } else {
                            switch page {
                            case 0: welcomeScreen
                            case 1: profileScreen
                            case 2: featureScreen
                            case 3: desktopScreen
                            case 4: themeScreen
                            default: setupScreen
                            }
                        }
                    }
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 22)
                    .padding(.top, 28)
                    .padding(.bottom, 20)
                    .id(mode == .update ? -1 : page)
                    .transition(.opacity.combined(with: .offset(x: 10)))
                }
                footer
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .environment(\.locale, Locale(identifier: english ? "en" : "es_MX"))
        .sheet(isPresented: $showJIT, onDismiss: { jitRefresh += 1 }) {
            BloomBoxJITSetup()
        }
        .sheet(isPresented: $showRAM, onDismiss: { ram.refresh() }) {
            NavigationView {
                BloomBoxRAMPlusView(openSideStore: {
                    // Prefer the same bundled SideStore used by the existing RAM+
                    // module; an external URL cannot open an in-app guest.
                    if UserDefaults.sideStoreExist() {
                        LCUtils.openSideStore()
                    } else if let url = URL(string: "sidestore://") {
                        UIApplication.shared.open(url)
                    }
                })
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(t("Listo", "Done")) { showRAM = false }
                    }
                }
            }
            .navigationViewStyle(.stack)
        }
        .alert(t("No se pudo completar", "Could not complete"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .onAppear {
            guard mode != .update else { return }
            page = mode == .replay ? 0 : max(0, min(5, defaults.integer(forKey: BloomBoxWizardGate.stepKey)))
            profileCount = mode == .replay ? BloomBoxProfiles.count : (defaults.integer(forKey: BloomBoxWizardGate.countKey) == 2 ? 2 : 1)
            name1 = BloomBoxProfiles.name(1)
            name2 = BloomBoxProfiles.name(2)
            chosenTheme = defaults.string(forKey: BloomBoxBundledThemes.chosenKey) ?? "KirbyPink"
            ram.refresh()
        }
    }

    @ViewBuilder private var wallpaperBackground: some View {
        GeometryReader { geometry in
            if let url = BloomBoxBundledThemes.previewURL(for: "KirbyPink"),
               let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .blur(radius: 32)
                    .clipped()
            } else {
                LinearGradient(colors: [.pink, .purple, .black],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .ignoresSafeArea()
        Color(red: 0.10, green: 0.07, blue: 0.16).opacity(0.76).ignoresSafeArea()
    }

    private var header: some View {
        VStack(spacing: 17) {
            HStack(spacing: 9) {
                Image(systemName: "square.stack.3d.up.fill")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(.pink)
                Text("BloomBox").font(.system(size: 24, weight: .black, design: .rounded))
                Spacer()
                Text(mode == .update ? t("Novedades", "What's new") :
                    "\(page + 1) / 6")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.8))
            }
            if mode != .update {
                HStack(spacing: 5) {
                    ForEach(0..<6, id: \.self) { index in
                        Capsule()
                            .fill(index <= page ? Color.pink : Color.white.opacity(0.22))
                            .frame(height: 5)
                    }
                }
                .accessibilityLabel(t("Paso \(page + 1) de 6", "Step \(page + 1) of 6"))
            }
        }
        .padding(.horizontal, 23)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    private var footer: some View {
        HStack(spacing: 14) {
            if mode != .update && page > 0 {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) { page -= 1 }
                    if mode == .firstRun { defaults.set(page, forKey: BloomBoxWizardGate.stepKey) }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.headline.weight(.bold))
                        .frame(width: 56, height: 54)
                        .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                }
                .accessibilityLabel(t("Atrás", "Back"))
            }
            Button {
                if mode == .update || page == 5 {
                    finish()
                } else {
                    withAnimation(.easeInOut(duration: 0.22)) { page += 1 }
                    if mode == .firstRun { defaults.set(page, forKey: BloomBoxWizardGate.stepKey) }
                }
            } label: {
                HStack(spacing: 10) {
                    Spacer()
                    Text(mode == .update ? t("Explorar BloomBox", "Explore BloomBox")
                         : page == 5 ? t("Entrar a BloomBox", "Enter BloomBox")
                         : t("Continuar", "Continue"))
                        .font(.headline.weight(.bold))
                    Image(systemName: (mode == .update || page == 5)
                          ? "checkmark" : "arrow.right")
                    Spacer()
                }
                .frame(height: 54)
                .background(Color.pink, in: RoundedRectangle(cornerRadius: 18))
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 22)
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(.ultraThinMaterial)
    }

    private var welcomeScreen: some View {
        VStack(spacing: 19) {
            TimelineView(.periodic(from: .now, by: 2.8)) { context in
                Text(Int(context.date.timeIntervalSince1970 / 2.8) % 2 == 0
                    ? "¡Bienvenido a BloomBox!" : "Welcome to BloomBox!")
                    .font(.system(size: 38, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.72)
                    .frame(maxWidth: .infinity)
            }
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 76))
                .foregroundStyle(.pink, .white.opacity(0.85))
                .padding(.vertical, 25)
            Text(t("Un escritorio hecho a tu manera. Juegos, widgets y herramientas especiales, todo en un lugar.",
                   "Your desktop, your way. Games, widgets and powerful tools in one place."))
                .multilineTextAlignment(.center)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.9))
            VStack(alignment: .leading, spacing: 12) {
                Text("IDIOMA / LANGUAGE")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(.white.opacity(0.7))
                HStack(spacing: 10) {
                    languageButton("es", label: "Español", flag: "🇲🇽")
                    languageButton("en", label: "English", flag: "🇺🇸")
                }
            }
            .padding(.top, 18)
        }
    }

    private func languageButton(_ value: String, label: String, flag: String) -> some View {
        Button { language = value } label: {
            HStack(spacing: 7) {
                Text(flag)
                Text(label).font(.subheadline.weight(.bold))
                Spacer(minLength: 0)
                if (language == "system" ? english == (value == "en") : language == value) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.pink)
                }
            }
            .padding(13)
            .background(.white.opacity(0.12),
                        in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    private var profileScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle(t("Tu espacio, tus reglas", "Make it yours"),
                         subtitle: t("Crea tu perfil. Puedes usar dos espacios con datos distintos en cada app instalada dentro de BloomBox.",
                                     "Create your profile. Two spaces give each installed guest app separate data."))
            HStack(spacing: 10) {
                profileCountCard(1, icon: "person.crop.circle", label: t("1 perfil", "1 profile"),
                                 caption: t("El de siempre", "Original data"))
                profileCountCard(2, icon: "person.2.crop.square.stack", label: t("2 perfiles", "2 profiles"),
                                 caption: t("Datos separados", "Separate data"))
            }
            profileEditor(1, name: $name1, selection: $photoOne)
            if profileCount == 2 {
                profileEditor(2, name: $name2, selection: $photoTwo)
            }
            Label(t("El segundo perfil crea contenedores de LiveContainer para las apps invitadas. No duplica las apps ni modifica los datos del primero.",
                    "Profile 2 creates LiveContainer data containers for guest apps. It does not duplicate apps or overwrite profile 1."),
                  systemImage: "lock.shield")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.8))
        }
    }

    private func profileCountCard(_ count: Int, icon: String, label: String, caption: String) -> some View {
        Button {
            profileCount = count
            defaults.set(count, forKey: BloomBoxWizardGate.countKey)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title2).foregroundStyle(.pink)
                Text(label).font(.headline)
                Text(caption).font(.caption).foregroundStyle(.white.opacity(0.75))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(15)
            .background(.white.opacity(profileCount == count ? 0.22 : 0.08),
                        in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18)
                .stroke(profileCount == count ? .pink : .clear, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private func profileEditor(_ number: Int, name: Binding<String>,
                               selection: Binding<PhotosPickerItem?>) -> some View {
        HStack(spacing: 16) {
            PhotosPicker(selection: selection, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    avatar(number).id(photoRevision)
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .padding(6)
                        .background(.pink, in: Circle())
                }
            }
            .onChange(of: selection.wrappedValue) { newValue in
                importPhoto(newValue, index: number)
            }
            VStack(alignment: .leading, spacing: 7) {
                Text(number == 1 ? t("Tu nombre", "Your name")
                    : t("Segundo usuario", "Second user")).font(.caption.weight(.medium))
                TextField(number == 1 ? "Player 1" : "Player 2", text: name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .padding(12)
                    .background(.white.opacity(0.12),
                                in: RoundedRectangle(cornerRadius: 12))
                    .onChange(of: name.wrappedValue) { value in
                        BloomBoxProfiles.setName(value, for: number)
                    }
                Text(t("Toca la foto para cambiarla", "Tap the picture to change it"))
                    .font(.caption2).foregroundStyle(.white.opacity(0.6))
            }
        }
        .padding(14)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    @ViewBuilder private func avatar(_ number: Int) -> some View {
        if let image = UIImage(contentsOfFile: BloomBoxProfiles.photoURL(for: number).path) {
            Image(uiImage: image).resizable().scaledToFill()
                .frame(width: 76, height: 76).clipShape(Circle())
        } else {
            Image(systemName: "person.crop.circle.fill")
                .resizable().scaledToFit()
                .foregroundStyle(.white.opacity(0.75))
                .frame(width: 76, height: 76)
        }
    }

    private func importPhoto(_ photo: PhotosPickerItem?, index: Int) {
        guard let photo else { return }
        Task {
            do {
                guard let data = try await photo.loadTransferable(type: Data.self) else { return }
                try BloomBoxProfiles.storePhoto(data, for: index)
                photoRevision += 1
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private var featureScreen: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionTitle(t("Conoce lo mejor de BloomBox", "Discover BloomBox"),
                         subtitle: t("Las herramientas más poderosas, sin salir de tu escritorio.",
                                     "The best tools, right on your desktop."))
            feature("bolt.fill", title: "JIT",
                    subtitle: t("Ayuda a ejecutar emuladores y juegos compatibles. Puedes preparar tu iPhone desde la app.",
                                "Helps compatible emulators and games run. Pair your iPhone from the app."),
                    tint: .yellow)
            feature("memorychip.fill", title: "RAM+",
                    subtitle: t("Más memoria para apps compatibles cuando Apple concede el permiso y la app se reinstala firmada.",
                                "More memory for supported apps after Apple grants the entitlement and the signed app is reinstalled."),
                    tint: .mint)
            feature("bell.badge.fill", title: t("Avisos de caducidad", "Expiry reminders"),
                    subtitle: t("Recibe avisos antes de que venzan las apps firmadas con SideStore.",
                                "Get reminders before SideStore-signed apps expire."),
                    tint: .orange)
            feature("square.grid.3x3.fill", title: t("Tiendas y módulos", "Stores and modules"),
                    subtitle: t("Instala, organiza y configura tus apps desde BloomBox.",
                                "Install, organize and configure your apps in BloomBox."),
                    tint: .pink)
        }
    }

    private func feature(_ icon: String, title: String, subtitle: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(tint)
                .frame(width: 51, height: 51)
                .background(tint.opacity(0.17), in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.headline)
                Text(subtitle).font(.subheadline)
                    .foregroundStyle(.white.opacity(0.78))
            }
            Spacer(minLength: 0)
        }
        .padding(15)
        .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 20))
    }

    private var desktopScreen: some View {
        VStack(spacing: 22) {
            sectionTitle(t("Un escritorio que cobra vida", "A desktop that comes alive"),
                         subtitle: t("Mueve tus apps, organiza carpetas y añade widgets animados.",
                                     "Move apps, arrange folders and add animated widgets."))
            miniDesktop
            feature("square.on.square", title: t("Widgets libres", "Freeform widgets"),
                    subtitle: t("Relojes, notas, fotos y animaciones en tus páginas.",
                                "Clocks, notes, pictures and animations on your pages."),
                    tint: .pink)
            feature("hand.draw.fill", title: t("Tú decides", "It's your call"),
                    subtitle: t("Arrastra, personaliza el Dock y cambia de fondo cuando quieras.",
                                "Drag things around, customize the Dock and change wallpapers anytime."),
                    tint: .mint)
        }
    }

    private var miniDesktop: some View {
        VStack(spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("09:41").font(.system(size: 30, weight: .light, design: .rounded))
                    Text(t("Miércoles", "Wednesday")).font(.caption.weight(.semibold))
                    Text(t("Día perfecto para jugar", "A great day to play"))
                        .font(.system(size: 9)).opacity(0.8)
                }
                .frame(maxWidth: .infinity, minHeight: 89, alignment: .leading)
                .padding(13)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 17))
                VStack(spacing: 6) {
                    Image(systemName: "sun.max.fill")
                        .font(.title2).foregroundStyle(.yellow)
                    Text("24°").font(.title3.weight(.semibold))
                    Text(t("Soleado", "Sunny")).font(.system(size: 9))
                }
                .frame(width: 88, height: 115)
                .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 17))
            }
            HStack(spacing: 18) {
                miniApp("gamecontroller.fill", .purple, "Juegos")
                miniApp("square.grid.2x2.fill", .pink, "Apps")
                miniApp("bolt.fill", .orange, "JIT")
                miniApp("gearshape.fill", .gray, "Ajustes")
            }
            .padding(.vertical, 12)
            HStack(spacing: 20) {
                miniApp("safari.fill", .cyan, "Web")
                miniApp("photo.fill", .mint, "Fotos")
                miniApp("music.note", .pink, "Música")
                miniApp("folder.fill", .yellow, "Archivos")
            }
            .padding(10)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 23))
        }
        .padding(20)
        .background(
            LinearGradient(colors: [Color.pink.opacity(0.72), .purple.opacity(0.65)],
                           startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 28))
        .overlay(RoundedRectangle(cornerRadius: 28)
            .stroke(.white.opacity(0.22), lineWidth: 1))
        .accessibilityLabel(t("Vista previa ilustrada del escritorio y widgets",
                              "Illustrated preview of the desktop and widgets"))
    }

    private func miniApp(_ icon: String, _ color: Color, _ caption: String) -> some View {
        VStack(spacing: 5) {
            Image(systemName: icon).font(.title3)
                .frame(width: 47, height: 47)
                .background(color.opacity(0.78), in: RoundedRectangle(cornerRadius: 12))
            Text(caption).font(.system(size: 9)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var themeScreen: some View {
        VStack(alignment: .leading, spacing: 19) {
            sectionTitle(t("Elige tu estilo", "Choose your style"),
                         subtitle: t("Puedes cambiarlo después en la tienda de temas.",
                                     "You can change it later in the theme store."))
            ForEach(BloomBoxBundledThemes.presets) { theme in
                Button {
                    chosenTheme = theme.id
                    defaults.set(theme.id, forKey: BloomBoxBundledThemes.chosenKey)
                } label: {
                    HStack(spacing: 15) {
                        if let url = BloomBoxBundledThemes.previewURL(for: theme.id),
                           let image = UIImage(contentsOfFile: url.path) {
                            Image(uiImage: image).resizable().scaledToFill()
                                .frame(width: 100, height: 105)
                                .clipShape(RoundedRectangle(cornerRadius: 17))
                        } else {
                            Image(systemName: "paintpalette.fill")
                                .frame(width: 100, height: 105)
                        }
                        VStack(alignment: .leading, spacing: 7) {
                            Text(theme.title).font(.title3.weight(.bold))
                            Text(theme.isDefault
                                 ? t("Rosa · Predeterminado", "Pink · Default")
                                 : t("Amarillo · Alternativo", "Yellow · Alternative"))
                                .font(.caption).foregroundStyle(.white.opacity(0.72))
                        }
                        Spacer(minLength: 0)
                        Image(systemName: chosenTheme == theme.id
                              ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(chosenTheme == theme.id ? .pink : .white)
                            .font(.title2)
                    }
                    .padding(12)
                    .background(.white.opacity(chosenTheme == theme.id ? 0.20 : 0.09),
                                in: RoundedRectangle(cornerRadius: 22))
                    .overlay(RoundedRectangle(cornerRadius: 22)
                        .stroke(chosenTheme == theme.id ? .pink : .clear, lineWidth: 2))
                }
                .buttonStyle(.plain)
            }
            Text(t("Tu elección se aplicará al primer escritorio. Nunca reemplazaremos un escritorio personalizado durante una actualización.",
                   "Your choice applies to a new desktop only. Existing customized desktops are never replaced during updates."))
                .font(.footnote).foregroundStyle(.white.opacity(0.7))
        }
    }

    private var setupScreen: some View {
        VStack(alignment: .leading, spacing: 19) {
            sectionTitle(t("Dos ajustes antes de empezar", "Two things before you start"),
                         subtitle: t("Comprueba JIT y RAM+. Si ya están preparados, no necesitas repetirlos.",
                                     "Check JIT and RAM+. If they're ready, there's nothing to redo."))
            setupCard(icon: "bolt.fill", title: "JIT",
                      status: jitReady ? t("Emparejamiento guardado y permiso de depuración disponible",
                                          "Pairing saved and debugging allowed")
                          : paired ? t("Emparejamiento guardado; revisa el permiso de depuración",
                                       "Pairing saved; check debugging permission")
                          : t("Falta configurar el emparejamiento", "Pairing is not configured"),
                      ready: jitReady,
                      detail: t("El emparejamiento se conserva al actualizar. JIT se aplica a cada app compatible al abrirla.",
                                "Pairing survives updates. JIT is enabled per compatible guest when launched."),
                      action: t("Configurar JIT", "Set up JIT")) { showJIT = true }
            setupCard(icon: "memorychip.fill", title: "RAM+",
                      status: ram.validation.confirmed
                          ? t("RAM+ verificada en esta instalación", "RAM+ verified in this installation")
                          : ram.status,
                      ready: ram.validation.confirmed,
                      detail: t("Si Apple concede RAM+, BloomBox deberá reinstalarse encima conservando datos. NO abras BloomBox hasta que SideStore termine de instalar.",
                                "If Apple grants RAM+, BloomBox must reinstall over this copy and preserve data. DO NOT open BloomBox until SideStore finishes installing."),
                      action: t("Activar / comprobar RAM+", "Enable / check RAM+")) {
                ram.refresh()
                showRAM = true
            }
            if !jitReady || !ram.validation.confirmed {
                Label(t("Puedes continuar con las funciones disponibles y completar lo pendiente desde Módulos. No se activará nada sin tu permiso.",
                        "You can continue with available features and finish setup in Modules. Nothing is enabled without your permission."),
                      systemImage: "info.circle")
                    .font(.footnote).foregroundStyle(.white.opacity(0.74))
            }
        }
    }

    private func setupCard(icon: String, title: String, status: String, ready: Bool,
                           detail: String, action: String, onTap: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 10) {
                Image(systemName: icon).foregroundStyle(ready ? .green : .pink)
                Text(title).font(.title3.weight(.bold))
                Spacer()
                Image(systemName: ready ? "checkmark.seal.fill" : "exclamationmark.circle.fill")
                    .foregroundStyle(ready ? .green : .orange)
            }
            Text(status).font(.headline)
            Text(detail).font(.footnote).foregroundStyle(.white.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)
            if !ready {
                Button(action, action: onTap)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(13)
                    .background(.pink.opacity(0.86),
                                in: RoundedRectangle(cornerRadius: 13))
            }
        }
        .padding(17)
        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 20))
    }

    private var updateScreen: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionTitle(t("¡BloomBox se actualizó!", "BloomBox just got better!"),
                         subtitle: t("Estas son las novedades de esta compilación.",
                                     "Here's what's new in this build."))
            Image(systemName: "sparkles.tv")
                .font(.system(size: 70))
                .foregroundStyle(.pink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 25)
            feature("person.2.fill", title: t("Perfiles", "Profiles"),
                    subtitle: t("Cambia de usuario con contenedores separados para tus apps.",
                                "Switch users with isolated guest-app containers."), tint: .pink)
            feature("paintpalette.fill", title: t("Tus temas favoritos", "Your favorite themes"),
                    subtitle: t("Kirby Pink y Yellow Bowser disponibles en la tienda.",
                                "Kirby Pink and Yellow Bowser are in the theme store."), tint: .yellow)
            feature("bolt.shield.fill", title: t("JIT y RAM+ a la vista", "JIT and RAM+ at a glance"),
                    subtitle: t("Comprueba fácilmente su estado desde los módulos.",
                                "Check their status in Modules."), tint: .mint)
            Text(t("Tu perfil, tus datos y tu escritorio se conservaron.",
                   "Your profile, data and desktop were preserved."))
                .font(.footnote).foregroundStyle(.white.opacity(0.8))
        }
    }

    private func sectionTitle(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title).font(.system(size: 31, weight: .black, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(subtitle).font(.subheadline)
                .foregroundStyle(.white.opacity(0.81))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func finish() {
        if mode != .update {
            BloomBoxProfiles.setName(name1, for: 1)
            if profileCount == 2 { BloomBoxProfiles.setName(name2, for: 2) }
            do {
                try BloomBoxProfiles.setCount(profileCount, guests: allGuests)
            } catch {
                errorMessage = error.localizedDescription
                return
            }
            defaults.set(chosenTheme, forKey: BloomBoxBundledThemes.chosenKey)
        }
        BloomBoxWizardGate.finish()
        onDone()
    }
}

/// Available from Settings even after onboarding is finished.
@available(iOS 16.0, *)
struct BloomBoxProfileSettingsView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @State private var selected = BloomBoxProfiles.active
    @State private var total = BloomBoxProfiles.count
    @State private var nameOne = BloomBoxProfiles.name(1)
    @State private var nameTwo = BloomBoxProfiles.name(2)
    @State private var photoOne: PhotosPickerItem?
    @State private var photoTwo: PhotosPickerItem?
    @State private var imageRevision = 0
    @State private var errorMessage: String?
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault) private var language = "system"

    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "es").lowercased().hasPrefix("en"))
    }
    private func t(_ es: String, _ en: String) -> String { english ? en : es }
    private var guests: [LCAppModel] { sharedModel.apps + sharedModel.hiddenApps }

    var body: some View {
        Form {
            Section {
                Picker(t("Cantidad de perfiles", "Number of profiles"), selection: $total) {
                    Text("1").tag(1)
                    Text("2").tag(2)
                }
                .pickerStyle(.segmented)
                .onChange(of: total) { value in
                    do {
                        try BloomBoxProfiles.setCount(value, guests: guests)
                        selected = BloomBoxProfiles.active
                    } catch {
                        total = BloomBoxProfiles.count
                        errorMessage = error.localizedDescription
                    }
                }
            } footer: {
                Text(t("El segundo perfil utiliza nuevos contenedores de LiveContainer. Volver a uno no borra sus datos.",
                       "The second profile uses separate LiveContainer containers. Going back to one does not erase them."))
            }
            Section(t("Perfil activo", "Active profile")) {
                profileRow(1, name: $nameOne, picker: $photoOne)
                if total == 2 {
                    profileRow(2, name: $nameTwo, picker: $photoTwo)
                }
            }
            Section {
                Text(t("Cambia de perfil antes de abrir tus apps. Las que ya estén abiertas deben cerrarse y abrirse otra vez para usar el otro contenedor.",
                       "Switch profiles before opening apps. Running guests must be closed and reopened to use the other container."))
                    .font(.footnote)
            }
        }
        .navigationTitle(t("Perfiles de BloomBox", "BloomBox Profiles"))
        .alert(t("Error de perfil", "Profile error"), isPresented: Binding(
            get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private func profileRow(_ index: Int, name: Binding<String>,
                            picker: Binding<PhotosPickerItem?>) -> some View {
        HStack(spacing: 12) {
            PhotosPicker(selection: picker, matching: .images) {
                Group {
                    if let image = UIImage(contentsOfFile: BloomBoxProfiles.photoURL(for: index).path) {
                        Image(uiImage: image).resizable().scaledToFill()
                            .frame(width: 48, height: 48).clipShape(Circle())
                    } else {
                        Image(systemName: "person.crop.circle.fill").font(.system(size: 44))
                    }
                }
                .id(imageRevision)
            }
            .onChange(of: picker.wrappedValue) { item in
                guard let item else { return }
                Task {
                    do {
                        guard let data = try await item.loadTransferable(type: Data.self) else { return }
                        try BloomBoxProfiles.storePhoto(data, for: index)
                        imageRevision += 1
                    } catch { errorMessage = error.localizedDescription }
                }
            }
            VStack(alignment: .leading, spacing: 4) {
                TextField(index == 1 ? "Player 1" : "Player 2", text: name)
                    .onChange(of: name.wrappedValue) { BloomBoxProfiles.setName($0, for: index) }
                Text(index == selected ? t("En uso", "Active") : t("Disponible", "Available"))
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if selected == index {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Button(t("Usar", "Use")) {
                    do {
                        try BloomBoxProfiles.select(index, guests: guests)
                        selected = BloomBoxProfiles.active
                    } catch { errorMessage = error.localizedDescription }
                }
                .buttonStyle(.bordered)
            }
        }
    }
}
