import SwiftUI
import CryptoKit

/// BloomBox's native News desktop. No guest execution or installer state lives
/// on this page. The old Manzana widget-page entry point is retained as an alias.
struct BloomBoxNewsPage: View {
    let openSettings: () -> Void
    var openGameBox: () -> Void = {}
    var gameNames: [String: String] = [:]
    var singleWidget: String? = nil

    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var locale: Locale {
        Locale(identifier: preferredLanguage == "system"
               ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage)
    }
    private var english: Bool { locale.languageCode == "en" }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("BloomBox").font(.largeTitle.bold())
                        Text(english ? "News and desktop" : "Novedades y escritorio")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: openSettings) {
                        Image(systemName: "paintbrush.pointed.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .background(.thinMaterial, in: Circle())
                    }
                    .accessibilityLabel(english ? "Customize Home" : "Personalizar escritorio")
                    .accessibilityIdentifier("bloombox.news.settings")
                }
                BloomBoxProfileSwitcherWidget()
                BloomBoxGameBoxNewsWidget(onOpen: openGameBox, gameNames: gameNames)
                BloomBoxRemoteNewsSection()
            }
            .padding(.horizontal, 22)
            .padding(.top, 12)
            .padding(.bottom, 24)
        }
    }
}

// Temporary source-compatibility shim only; all new calls use BloomBoxNewsPage.
typealias ManzanaDesktopView = BloomBoxNewsPage

/// News shortcut stays on iOS Home and makes GameBox visible even when
/// the optional floating control has been hidden. Only reads saved titles.
private struct BloomBoxGameBoxNewsWidget: View {
    let onOpen: () -> Void
    let gameNames: [String: String]

    @AppStorage(BloomBoxProfileStore.activeKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var activeProfileID = BloomBoxUserProfile.primaryID
    @AppStorage(BloomBoxProfileStore.profilesKey,
                store: LiveContainerPreferencesAdapter.defaults)
    private var profiles = Data()
    @AppStorage("BloomBoxPreferredLanguage",
                store: LiveContainerPreferencesAdapter.defaults)
    private var language = "system"
    @AppStorage("BloomBoxGameBoxV2Favorites",
                store: LiveContainerPreferencesAdapter.defaults)
    private var favoritesJSON = "[]"
    @AppStorage("BloomBoxGameBoxRecentRevisionV1",
                store: LiveContainerPreferencesAdapter.defaults)
    private var recentRevision = ""

    private var english: Bool {
        language == "en" || (language == "system" &&
            (Locale.preferredLanguages.first ?? "en").lowercased().hasPrefix("en"))
    }
    private var tint: Color {
        BloomBoxProfileTheme.color(activeID: activeProfileID, profilesData: profiles)
    }
    private var favorites: [String] {
        BloomBoxHomeAppPolicy.favorites(from: favoritesJSON)
            .compactMap { gameNames[$0] }
    }
    private var recentlyPlayed: [String] {
        _ = recentRevision // refresh when the game list changes
        return BloomBoxLaunchPreferences.recentGames(
            profileID: activeProfileID, defaults: LiveContainerPreferencesAdapter.defaults)
    }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 12) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(tint)
                        .frame(width: 45, height: 45)
                        .background(tint.opacity(0.14),
                                    in: RoundedRectangle(cornerRadius: 14))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GameBox").font(.headline)
                        Text(english ? "Your games, one tap away" : "Tus juegos, a un toque")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.title2)
                        .foregroundStyle(tint)
                }
                if let last = recentlyPlayed.first {
                    Label((english ? "Recently played: " : "Último juego: ") + last,
                          systemImage: "clock.arrow.circlepath")
                        .font(.caption)
                        .lineLimit(1)
                }
                if !favorites.isEmpty {
                    Label((english ? "Favorites: " : "Favoritos: ") +
                          favorites.prefix(2).joined(separator: " · "),
                          systemImage: "star.fill")
                        .font(.caption)
                        .lineLimit(1)
                        .foregroundStyle(tint)
                }
            }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial,
                        in: RoundedRectangle(cornerRadius: 25, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 25, style: .continuous)
                    .strokeBorder(tint.opacity(0.38), lineWidth: 1.1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("bloombox.news.gamebox")
        .accessibilityLabel(english ? "Open GameBox" : "Abrir GameBox")
    }
}

// MARK: - Read-only remote news. No HTML, scripts, or execution paths.
private struct BloomBoxNewsFeed: Decodable {
    let posts: [BloomBoxNewsPost]
}
private struct BloomBoxNewsPost: Decodable, Identifiable {
    let id: String
    let title: String
    let text: String
    let media: String?
}

private struct BloomBoxRemoteNewsSection: View {
    @AppStorage("BloomBoxNewsFeedURL", store: LCUtils.appGroupUserDefault)
    private var feedAddress = ""
    @AppStorage("BloomBoxPreferredLanguage", store: LCUtils.appGroupUserDefault)
    private var preferredLanguage = "system"
    private var english: Bool { (preferredLanguage == "system" ? (Locale.preferredLanguages.first ?? "en") : preferredLanguage).lowercased().hasPrefix("en") }
    private var defaultFeed: String { "https://raw.githubusercontent.com/adri23rep-stack/BloomBox-Catalog/main/news/\(english ? "en" : "es").json" }
    // Earlier builds persisted the old built-in feed URL. Treat that legacy
    // default as automatic so upgrades use BloomBox-Catalog and its locale feeds.
    // Preserve any genuinely custom HTTPS news source selected by the user.
    private var activeFeed: String {
        let saved = feedAddress.trimmingCharacters(in: .whitespacesAndNewlines)
        if saved.isEmpty || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/feature/bloombox-2-ui-foundation-20261031/remote/news.json" || saved == "https://raw.githubusercontent.com/adri23rep-stack/BloomBox/main/remote/news.json" {
            return defaultFeed
        }
        return saved
    }
    @State private var posts: [BloomBoxNewsPost] = []
    @State private var loading = false
    @State private var error: String?
    @State private var editingFeed = false
    @State private var feedDraft = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack {
                Label(english ? "BloomBox News" : "Novedades de BloomBox", systemImage: "newspaper.fill")
                    .font(.headline)
                Spacer()
                Button { Task { await refresh() } } label: {
                    Image(systemName: "arrow.clockwise")
                }.disabled(loading).accessibilityLabel("Actualizar novedades")
                Button { feedDraft = activeFeed; editingFeed = true } label: {
                    Image(systemName: "link")
                }.accessibilityLabel("Cambiar fuente de noticias")
            }
            if loading && posts.isEmpty { ProgressView("Cargando novedades…") }
            if let error, posts.isEmpty {
                Text(error).font(.caption).foregroundStyle(.secondary)
            }
            ForEach(Array(posts.prefix(12))) { post in
                VStack(alignment: .leading, spacing: 11) {
                    Text(post.title).font(.headline)
                    Text(post.text).font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    if let media = post.media, let url = URL(string: media),
                       url.scheme?.lowercased() == "https" {
                        BloomBoxRemoteNewsImage(url: url)
                            .frame(height: 210)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 15))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(17)
                .background(.ultraThinMaterial,
                            in: RoundedRectangle(cornerRadius: 22))
            }
        }
        .task(id: activeFeed) { await refresh() }
        .alert("Fuente de novedades", isPresented: $editingFeed) {
            TextField("Enlace HTTPS a JSON", text: $feedDraft)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Guardar") {
                let input = feedDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard let url = URL(string: input),
                      url.scheme?.lowercased() == "https" else {
                    error = "Usa un enlace HTTPS válido."
                    return
                }
                feedAddress = url.absoluteString
            }
            Button("Cancelar", role: .cancel) {}
        } message: {
            Text("Puedes modificar las noticias desde cualquier archivo JSON remoto, sin reinstalar BloomBox.")
        }
        .accessibilityIdentifier("bloombox.news.remote")
    }

    @MainActor private func refresh() async {
        guard let url = URL(string: activeFeed), url.scheme?.lowercased() == "https" else {
            error = "La fuente debe ser HTTPS."; return
        }
        loading = true
        defer { loading = false }
        do {
            var request = URLRequest(url: url)
            request.cachePolicy = .reloadIgnoringLocalCacheData
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count <= 256_000 else { throw BloomBoxMotionMedia.failure("La lista de noticias no está disponible.") }
            let decoded = try JSONDecoder().decode(BloomBoxNewsFeed.self, from: data)
            posts = Array(decoded.posts.prefix(12))
            error = nil
        } catch {
            self.error = english ? "Could not load news. Tap refresh to try again." : "No se pudieron cargar las noticias. Desliza o toca actualizar para intentar otra vez."
        }
    }
}

private struct BloomBoxRemoteNewsImage: View {
    let url: URL
    @State private var gifFile: URL?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        Group {
            if url.pathExtension.lowercased() == "gif" {
                if let gifFile {
                    BloomBoxAnimatedWallpaper(url: gifFile, fit: false,
                                             paused: scenePhase != .active,
                                             clearBackground: true)
                } else {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .task(id: url) {
            gifFile = nil
            guard url.pathExtension.lowercased() == "gif",
                  BloomBoxNewsCachePolicy.isHTTPS(url) else { return }
            let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("BloomBoxNewsGIF", isDirectory: true)
            let filename = SHA256.hash(data: Data(url.absoluteString.utf8))
                .map { String(format: "%02x", $0) }.joined() + ".gif"
            let target = directory.appendingPathComponent(filename)
            var staging: URL?
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                if FileManager.default.fileExists(atPath: target.path) {
                    if (try? BloomBoxMotionMedia.gifFrames(target)) != nil {
                        gifFile = target
                    } else {
                        try? FileManager.default.removeItem(at: target)
                    }
                }
                let (data, response) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled, let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      data.count > 0, data.count <= 10 * 1_024 * 1_024 else { return }
                let temp = directory.appendingPathComponent(UUID().uuidString + ".gif")
                staging = temp
                try data.write(to: temp, options: .atomic)
                _ = try BloomBoxMotionMedia.gifFrames(temp)
                guard !Task.isCancelled else { try? FileManager.default.removeItem(at: temp); return }
                if FileManager.default.fileExists(atPath: target.path) {
                    try FileManager.default.removeItem(at: target)
                }
                try FileManager.default.moveItem(at: temp, to: target)
                staging = nil
                gifFile = target
                _ = try? BloomBoxNewsCachePolicy.prune(in: directory, keeping: target)
            } catch {
                if let staging { try? FileManager.default.removeItem(at: staging) }
                // A previously downloaded valid image remains visible offline.
            }
        }
    }
}

