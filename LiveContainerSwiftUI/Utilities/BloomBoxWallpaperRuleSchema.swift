import Foundation

/// Read-only metadata from BloomBox-Catalog. It may only choose a search
/// provider and an exact console/game topic. Curated, allowlisted
/// public-domain images are supported; the feed cannot supply executable
/// code, arbitrary web hosts, permissions or launch/JIT configuration.
struct BloomBoxWallpaperRuleIndex: Codable {
    let schemaVersion: Int
    let catalogID: String
    let updatedAt: String
    let rules: [BloomBoxWallpaperRule]

    static func validated(from data: Data) -> BloomBoxWallpaperRuleIndex? {
        guard !data.isEmpty, data.count <= 60_000,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              Set(root.keys) == Set(["schemaVersion", "catalogID", "updatedAt", "rules"]),
              let raw = root["rules"] as? [[String: Any]],
              !raw.isEmpty, raw.count <= 80 else { return nil }

        let required = Set(["id", "bundleIDs", "keywords", "provider", "query", "note"])
        let optional = Set(["imageURL", "sourceURL", "imageLicense"])
        for rule in raw {
            let fields = Set(rule.keys)
            guard required.isSubset(of: fields),
                  fields.isSubset(of: required.union(optional)) else { return nil }
        }

        guard let index = try? JSONDecoder().decode(BloomBoxWallpaperRuleIndex.self, from: data),
              index.schemaVersion == 1,
              index.catalogID == "bloombox.gamebox.wallpaper-rules",
              index.updatedAt.count == 10, index.updatedAt.utf8.allSatisfy({
                  ($0 >= 48 && $0 <= 57) || $0 == 45
              }),
              index.rules.count <= 80, index.rules.allSatisfy(\.isValid) else { return nil }

        let ids = index.rules.map(\.id)
        let bundles = index.rules.flatMap(\.bundleIDs)
        let words = index.rules.flatMap { $0.keywords.map(Self.normalize) }
        guard Set(ids).count == ids.count,
              Set(bundles).count == bundles.count,
              Set(words).count == words.count else { return nil }
        return index
    }

    static func normalize(_ value: String) -> String {
        value.folding(options: [.diacriticInsensitive, .caseInsensitive],
                      locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    func rule(bundleID: String?, name: String) -> BloomBoxWallpaperRule? {
        // Exact installed bundle identity is authoritative. Never match a
        // substring of a bundle identifier; forks may have unrelated content.
        if let bundleID, let exact = rules.first(where: { $0.bundleIDs.contains(bundleID) }) {
            return exact
        }
        // Keywords are complete curated aliases, NOT broad text fragments.
        // "Delta Force" must not resolve to a Delta Nintendo DS background.
        let normalized = Self.normalize(name)
        guard !normalized.isEmpty else { return nil }
        return rules.first { rule in
            rule.keywords.contains { Self.matchesAlias($0, normalizedName: normalized) }
        }
    }

    private static func matchesAlias(_ alias: String, normalizedName: String) -> Bool {
        let word = normalize(alias)
        if normalizedName == word { return true }
        // Allow only an explicit alias followed by benign version/UI labels.
        // Never use plain contains/hasPrefix for partial app-name guessing.
        guard word.count >= 5, normalizedName.hasPrefix(word + " ") else { return false }
        let tail = normalizedName.dropFirst(word.count + 1)
        let allowedSuffixes = Set(["ios", "beta", "public", "emulator", "port", "version", "release"])
        let parts = tail.split(separator: " ")
        guard !parts.isEmpty, parts.count <= 4 else { return false }
        return parts.allSatisfy { part in
            let token = String(part)
            return allowedSuffixes.contains(token) ||
                (token.count <= 5 && token.allSatisfy({ $0.isNumber })) ||
                (token.count > 1 && token.count <= 6 &&
                 token.hasPrefix("v") && token.dropFirst().allSatisfy({ $0.isNumber }))
        }
    }
}

struct BloomBoxWallpaperRule: Codable {
    let id: String
    let bundleIDs: [String]
    let keywords: [String]
    let provider: String
    let query: String
    let note: String
    let imageURL: String?
    let sourceURL: String?
    let imageLicense: String?

    /// This is deliberately not an arbitrary image URL facility. The
    /// catalog may only reference a known Commons file that has its matching
    /// attribution/license page. Future custom assets need a separately
    /// reviewed host allowlist.
    var vettedArtworkURL: URL? {
        guard provider == "wikipedia",
              imageLicense == "Public domain",
              let imageURL, let sourceURL,
              let image = URL(string: imageURL), let origin = URL(string: sourceURL),
              image.scheme == "https", image.host == "upload.wikimedia.org",
              image.user == nil, image.password == nil, image.port == nil,
              image.query == nil, image.fragment == nil,
              origin.scheme == "https", origin.host == "commons.wikimedia.org",
              origin.user == nil, origin.password == nil, origin.port == nil,
              origin.query == nil, origin.fragment == nil,
              image.path.hasPrefix("/wikipedia/commons/"),
              origin.path.hasPrefix("/wiki/File:"),
              image.lastPathComponent == String(origin.lastPathComponent.dropFirst(5)),
              ["jpg", "jpeg", "png", "webp"].contains(image.pathExtension.lowercased()),
              image.absoluteString.count <= 350,
              origin.absoluteString.count <= 350 else { return nil }
        return image
    }

    var isValid: Bool {
        let safeID = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-")
        let safeBundle = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-_")
        let safeText = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 -:'&.!+()")
        guard !id.isEmpty, id.count <= 65,
              id.unicodeScalars.allSatisfy({ safeID.contains($0) }),
              bundleIDs.count <= 12, keywords.count <= 12,
              !bundleIDs.isEmpty || !keywords.isEmpty,
              !keywords.contains(where: { $0.isEmpty || $0.count > 72 }),
              keywords.allSatisfy({ !BloomBoxWallpaperRuleIndex.normalize($0).isEmpty }),
              bundleIDs.allSatisfy({ value in
                  value.count >= 5 && value.count <= 130 && value.contains(".") &&
                  !value.hasPrefix(".") && !value.hasSuffix(".") &&
                  !value.contains("..") &&
                  value.unicodeScalars.allSatisfy({ safeBundle.contains($0) })
              }),
              note.count <= 360, !note.isEmpty,
              query.count >= 3, query.count <= 90,
              query.unicodeScalars.allSatisfy({ safeText.contains($0) })
        else { return false }

        let providerIsKnown = (provider == "wikipedia" || provider == "steam") &&
            query.count <= 70
        guard providerIsKnown else { return false }

        // All-or-nothing attribution; one malformed image cannot invalidate
        // or redirect the app to an untrusted website.
        if imageURL != nil || sourceURL != nil || imageLicense != nil {
            return vettedArtworkURL != nil
        }
        return true
    }
}
