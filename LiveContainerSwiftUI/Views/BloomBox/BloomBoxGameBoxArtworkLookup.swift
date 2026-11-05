// BloomBox GameBox v2 — strictly bounded, attribution-friendly online artwork.
// Network requests resolve only the selected game. Installed app identities,
// containers, signing data and guest files are never transmitted.
import Foundation
import UIKit
import ImageIO

@MainActor
enum BloomBoxGameBoxArtworkLookup {
    struct Result {
        let image: UIImage
        let sourceURL: URL
        let provider: String
    }

    private struct SteamSearch: Decodable {
        let items: [SteamItem]?
    }
    private struct SteamItem: Decodable {
        let id: Int
        let name: String
        let type: String?
    }
    private struct SteamDetails: Decodable {
        let success: Bool
        let data: SteamGameDetails?
    }
    private struct SteamGameDetails: Decodable {
        let name: String
        let header_image: String?
    }
    private struct WikipediaResponse: Decodable {
        let query: WikipediaPages?
    }
    private struct WikipediaPages: Decodable {
        let pages: [String: WikipediaPage]
    }
    private struct WikipediaPage: Decodable {
        let title: String?
        let pageimage: String?
        let thumbnail: WikipediaThumbnail?
    }
    private struct WikipediaThumbnail: Decodable {
        let source: String
    }
    private struct CommonsResponse: Decodable {
        let query: CommonsPages?
    }
    private struct CommonsPages: Decodable {
        let pages: [String: CommonsFile]
    }
    private struct CommonsFile: Decodable {
        let title: String
        let imageinfo: [CommonsImage]?
    }
    private struct CommonsImage: Decodable {
        let thumburl: String?
        let descriptionurl: String?
        let mime: String?
        let width: Int?
        let height: Int?
    }

    // Emulator applications are *not* the game running inside them. Prefer a
    // free-license illustration of their platform, never a random game cover.
    private static func emulatorTopic(_ raw: String) -> String? {
        let name = normalize(raw)
        let terms: [(String, String)] = [
            ("dolphinios", "Nintendo GameCube"),
            ("dolphin emulator", "Nintendo GameCube"),
            ("melocafe", "Wii U"),
            ("cemu", "Wii U"),
            ("melonx", "Nintendo Switch"),
            ("melonnx", "Nintendo Switch"),
            ("melon nx", "Nintendo Switch"),
            ("lemonx", "Nintendo Switch"),
            ("lemon nx", "Nintendo Switch"),
            ("yuzu", "Nintendo Switch"),
            ("ryujinx", "Nintendo Switch"),
            ("sudachi", "Nintendo Switch"),
            ("vita3k", "PlayStation Vita"),
            ("vita3kios", "PlayStation Vita"),
            ("ppsspp", "PlayStation Portable"),
            ("retroarch", "Video game console"),
            ("delta emulator", "Nintendo DS"),
            ("delta", "Nintendo DS"),
            ("melon ds", "Nintendo DS"),
            ("melonds", "Nintendo DS"),
            ("folium", "Nintendo 3DS"),
            ("mgba", "Game Boy Advance"),
            ("provenance emulator", "Video game console")
        ]
        for (term, article) in terms {
            if name == term { return article }
            // Short names such as "Delta" also name unrelated PC games.
            // Do not accidentally assign a Nintendo DS wallpaper to Delta Force.
            if term.count >= 6 && name.hasPrefix(term + " ") { return article }
        }
        return nil
    }

    private static let excludedAppWords: [String] = [
        "youtube", "sidestore", "takopi", "nikaview", "tweakstore",
        "appstore", "settings", "instalar", "bloombox", "discord",
        "spotify", "instagram", "safari", "files", "browser", "music",
        // Husk runs Android apps; it is not Minecraft Dungeons.
        "husk"
    ]

    static func supported(_ title: String) -> Bool {
        emulatorTopic(title) != nil || gameQuery(title) != nil
    }

    // Trusted, strictly validated metadata overrides heuristic name
    // searches. The remote feed cannot provide URLs, only curated topics.
    static func find(_ rawTitle: String, rule: BloomBoxWallpaperRule?) async -> Result? {
        if let rule {
            // Hand-curated public-domain artwork first. Never let a keyword
            // search replace a source that an editor already verified.
            if let direct = rule.vettedArtworkURL,
               let origin = rule.sourceURL.flatMap(URL.init(string:)) {
                if let rendered = await image(from: direct,
                                              permittedHosts: ["upload.wikimedia.org"]) {
                    return Result(image: rendered, sourceURL: origin,
                                  provider: "Curated Wikimedia Commons")
                }
                BloomBoxCrashJournal.shared.record("gamebox.wallpaper.curated_image.unavailable")
            }
            // If a curated image is removed upstream, retain the conservative
            // console-topic fallback; never use an arbitrary image URL.
            switch rule.provider {
            case "wikipedia": return await wikipediaArtwork(for: rule.query)
            case "steam": return await steamArtwork(for: rule.query)
            default: return nil
            }
        }
        return await find(rawTitle)
    }

    static func find(_ rawTitle: String) async -> Result? {
        if let article = emulatorTopic(rawTitle) {
            return await wikipediaArtwork(for: article)
        }
        guard let name = gameQuery(rawTitle) else { return nil }
        return await steamArtwork(for: name)
    }

    private static func gameQuery(_ raw: String) -> String? {
        let full = normalize(raw)
        if excludedAppWords.contains(where: { full == $0 || full.hasPrefix($0 + " ") }) {
            return nil
        }
        // Known port/launcher aliases, never fuzzy-matched against a
        // potentially unrelated game. Update only when identity is certain.
        if full == "rdr" || full.hasPrefix("rdr iosvizor") { return "Red Dead Redemption" }
        if full == "rdr2" || full.hasPrefix("rdr 2 ") { return "Red Dead Redemption 2" }
        if full == "gta5" || full.hasPrefix("gta 5 ") { return "Grand Theft Auto V" }

        let title = raw.components(separatedBy: " - ").first ?? raw
        let cleaned = title
            .replacingOccurrences(of: "(iOS Port)", with: "", options: .caseInsensitive)
            .replacingOccurrences(of: "[Port]", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let key = normalize(cleaned)
        guard key.count >= 4, key.count <= 65,
              key.rangeOfCharacter(from: .letters) != nil,
              !excludedAppWords.contains(where: { key == $0 || key.hasPrefix($0 + " ") }),
              !key.contains("emulator") else {
            return nil
        }
        return cleaned
    }

    private static func normalize(_ input: String) -> String {
        input.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func steamArtwork(for title: String) async -> Result? {
        var components = URLComponents(string: "https://store.steampowered.com/api/storesearch/")
        components?.queryItems = [
            URLQueryItem(name: "term", value: title),
            URLQueryItem(name: "l", value: "english"),
            URLQueryItem(name: "cc", value: "us")
        ]
        guard let url = components?.url,
              let data = await json(from: url, host: "store.steampowered.com"),
              let result = try? JSONDecoder().decode(SteamSearch.self, from: data) else { return nil }
        let exact = result.items?.first {
            $0.id > 0 && $0.id < 50_000_000 &&
            ($0.type == nil || $0.type == "app") &&
            normalize($0.name) == normalize(title)
        }
        guard let match = exact else {
            BloomBoxCrashJournal.shared.record("gamebox.wallpaper.steam.no_exact_title")
            return nil
        }
        let sourceURL = URL(string: "https://store.steampowered.com/app/\(match.id)")!

        // Prefer a widescreen hero; a missing hero is normal for older games.
        if let hero = URL(string: "https://shared.steamstatic.com/store_item_assets/steam/apps/\(match.id)/library_hero.jpg"),
           let image = await image(from: hero, permittedHosts: [
                "shared.steamstatic.com", "shared.fastly.steamstatic.com",
                "shared.cloudflare.steamstatic.com", "cdn.cloudflare.steamstatic.com"
           ]) {
            return Result(image: image, sourceURL: sourceURL, provider: "Steam")
        }

        var details = URLComponents(string: "https://store.steampowered.com/api/appdetails")
        details?.queryItems = [
            URLQueryItem(name: "appids", value: String(match.id)),
            URLQueryItem(name: "filters", value: "basic"),
            URLQueryItem(name: "l", value: "english")
        ]
        guard let detailsURL = details?.url,
              let detailsData = await json(from: detailsURL, host: "store.steampowered.com"),
              let response = try? JSONDecoder().decode([String: SteamDetails].self, from: detailsData),
              let listing = response[String(match.id)], listing.success,
              let game = listing.data, normalize(game.name) == normalize(title),
              let imageString = game.header_image, let imageURL = URL(string: imageString),
              let image = await image(from: imageURL, permittedHosts: [
                "shared.steamstatic.com", "cdn.cloudflare.steamstatic.com",
                "cdn.akamai.steamstatic.com", "shared.fastly.steamstatic.com"
              ]) else { return nil }
        return Result(image: image, sourceURL: sourceURL, provider: "Steam")
    }

    private static func wikipediaArtwork(for article: String) async -> Result? {
        var components = URLComponents(string: "https://en.wikipedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "redirects", value: "1"),
            URLQueryItem(name: "prop", value: "pageimages"),
            URLQueryItem(name: "titles", value: article),
            URLQueryItem(name: "pithumbsize", value: "1400"),
            URLQueryItem(name: "pilicense", value: "free"),
            URLQueryItem(name: "piprop", value: "thumbnail|name")
        ]
        if let endpoint = components?.url,
           let data = await json(from: endpoint, host: "en.wikipedia.org"),
           let pages = try? JSONDecoder().decode(WikipediaResponse.self, from: data).query?.pages,
           let page = pages.values.first(where: { $0.thumbnail != nil }),
           let source = page.thumbnail?.source,
           let url = URL(string: source),
           let rendered = await image(from: url, permittedHosts: ["upload.wikimedia.org"]) {
            let wikiFile = page.pageimage ?? ""
            let attribution = URLComponents(string: "https://commons.wikimedia.org/wiki/File:" +
                                            wikiFile.replacingOccurrences(of: " ", with: "_"))?.url
            let articleURL = URLComponents(string: "https://en.wikipedia.org/wiki/" +
                                           article.replacingOccurrences(of: " ", with: "_"))?.url
            if let source = attribution ?? articleURL {
                return Result(image: rendered, sourceURL: source, provider: "Wikimedia")
            }
        }
        BloomBoxCrashJournal.shared.record("gamebox.wallpaper.wikipedia.no_free_thumbnail")
        // PageImages with pilicense=free may have no thumbnail even for a
        // valid console article. Search Commons File namespace for the
        // *curated* console name, never an arbitrary installed app name.
        return await commonsConsoleArtwork(for: article)
    }

    private static func commonsConsoleArtwork(for platform: String) async -> Result? {
        var components = URLComponents(string: "https://commons.wikimedia.org/w/api.php")
        components?.queryItems = [
            URLQueryItem(name: "action", value: "query"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "generator", value: "search"),
            URLQueryItem(name: "gsrsearch", value: platform + " console"),
            URLQueryItem(name: "gsrnamespace", value: "6"),
            URLQueryItem(name: "gsrlimit", value: "8"),
            URLQueryItem(name: "prop", value: "imageinfo"),
            URLQueryItem(name: "iiprop", value: "url|mime|size"),
            URLQueryItem(name: "iiurlwidth", value: "1400")
        ]
        guard let endpoint = components?.url,
              let data = await json(from: endpoint, host: "commons.wikimedia.org"),
              let pages = try? JSONDecoder().decode(CommonsResponse.self, from: data).query?.pages else {
            BloomBoxCrashJournal.shared.record("gamebox.wallpaper.commons_search.unavailable")
            return nil
        }

        let platformName = normalize(platform)
        let excluded = ["logo", "icon", "screenshot", "gameplay", "cover", "controller",
                        "cartridge", "box art", "case", "advertisement", "advert",
                        "diagram", "manual", "emulator"]
        // Use only verifiable console photo candidates. Never grab a random
        // game's screenshot or a misleading logo.
        let candidates = pages.values.filter { item in
            let name = normalize(item.title)
            guard name.contains(platformName), !excluded.contains(where: name.contains),
                  let detail = item.imageinfo?.first,
                  ["image/jpeg", "image/png", "image/webp"].contains(detail.mime ?? ""),
                  (detail.width ?? 0) >= 650, (detail.height ?? 0) >= 350 else { return false }
            return true
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        for item in candidates.prefix(3) {
            guard !Task.isCancelled else { return nil }
            guard let detail = item.imageinfo?.first,
                  let imagePath = detail.thumburl, let url = URL(string: imagePath),
                  let source = detail.descriptionurl.flatMap(URL.init(string:)),
                  source.scheme == "https", source.host == "commons.wikimedia.org" else { continue }
            if let bitmap = await image(from: url, permittedHosts: ["upload.wikimedia.org"]) {
                return Result(image: bitmap, sourceURL: source, provider: "Wikimedia Commons")
            }
        }
        BloomBoxCrashJournal.shared.record("gamebox.wallpaper.commons_search.no_photo")
        return nil
    }

    private static func json(from url: URL, host: String) async -> Data? {
        guard url.scheme == "https", url.host == host else { return nil }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 12)
        request.setValue("BloomBox-GameBox/2.0 (https://github.com/adri23rep-stack/BloomBox)", forHTTPHeaderField: "User-Agent")
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard !Task.isCancelled else { return nil }
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode), http.url?.host == host,
                  data.count > 0, data.count <= 500_000 else {
                let service = host == "store.steampowered.com" ? "steam" :
                    (host == "en.wikipedia.org" ? "wikipedia" : "commons")
                BloomBoxCrashJournal.shared.record("gamebox.wallpaper." + service + ".http_failed")
                return nil
            }
            return data
        } catch {
            BloomBoxCrashJournal.shared.record("gamebox.wallpaper.metadata.network_error")
            return nil
        }
    }

    private static func image(from url: URL, permittedHosts: [String]) async -> UIImage? {
        guard url.scheme == "https", let host = url.host,
              permittedHosts.contains(host) else { return nil }
        var request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        request.setValue("BloomBox-GameBox/2.0 (https://github.com/adri23rep-stack/BloomBox)", forHTTPHeaderField: "User-Agent")
        do {
            // Download to a temporary file instead of buffering a remote image
            // entirely in SwiftUI's main process memory.
            let (local, response) = try await URLSession.shared.download(for: request)
            guard !Task.isCancelled, let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode),
                  let finalHost = http.url?.host, permittedHosts.contains(finalHost),
                  let mime = http.mimeType?.lowercased(),
                  ["image/jpeg", "image/png", "image/webp"].contains(mime),
                  http.expectedContentLength <= 12 * 1024 * 1024 else { return nil }
            let size = (try? FileManager.default.attributesOfItem(atPath: local.path)[.size] as? NSNumber)?.intValue ?? 0
            guard size > 0, size <= 12 * 1024 * 1024,
                  let source = CGImageSourceCreateWithURL(local as CFURL, nil) else { return nil }
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 1400,
                kCGImageSourceShouldCacheImmediately: true
            ]
            guard let bitmap = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
                return nil
            }
            return UIImage(cgImage: bitmap)
        } catch {
            return nil
        }
    }
}
