import Foundation

/// Selects the newest public stable release from this project's fixed GitHub API.
/// The app's CFBundleShortVersionString comes from upstream LiveContainer and
/// is NOT the BloomBox release tag. Do not match releases using that field.
enum BloomBoxRAMRelease {
    static let latestAPI = URL(string: "https://api.github.com/repos/adri23rep-stack/BloomBox/releases/latest")!
    static let assetName = "BloomBox-SideStore-unsigned.ipa"

    struct Asset {
        let tag: String
        let url: URL
        let digest: String
        let size: Int64
        let commitish: String?
    }

    struct Failure: LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }

    static func select(json: Data) throws -> Asset {
        guard json.count > 0 && json.count < 2 * 1024 * 1024,
              let release = (try? JSONSerialization.jsonObject(with: json)) as? [String: Any],
              release["draft"] as? Bool == false,
              release["prerelease"] as? Bool == false,
              let tag = release["tag_name"] as? String,
              tag.range(of: #"^v[0-9]+(\.[0-9]+){2}$"#, options: .regularExpression) != nil else {
            throw Failure(message: "GitHub no devolvió una release estable válida. No se reinstaló BloomBox.")
        }
        let matches = (release["assets"] as? [[String: Any]] ?? [])
            .filter { $0["name"] as? String == assetName }
        guard matches.count == 1, let item = matches.first,
              let rawDigest = item["digest"] as? String,
              rawDigest.hasPrefix("sha256:"),
              rawDigest.count == 71,
              let rawURL = item["browser_download_url"] as? String,
              let url = URL(string: rawURL),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "https",
              components.host == "github.com",
              components.port == nil,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.percentEncodedPath == "/adri23rep-stack/BloomBox/releases/download/\(tag)/\(assetName)",
              let size = item["size"] as? Int64,
              size > 0 && size < 1024 * 1024 * 1024 else {
            throw Failure(message: "La última release no tiene una IPA oficial única con URL, tamaño y SHA-256 verificables. No se instaló nada.")
        }
        let digest = String(rawDigest.dropFirst("sha256:".count))
        guard digest.utf8.allSatisfy({ (48...57).contains($0) || (65...70).contains($0) || (97...102).contains($0) }) else {
            throw Failure(message: "La suma SHA-256 publicada por GitHub no es válida.")
        }
        return Asset(tag: tag, url: url, digest: digest.lowercased(), size: size,
                     commitish: release["target_commitish"] as? String)
    }

    static func compatibleIdentity(installed: String, sourceBundle: String) -> Bool {
        !installed.isEmpty && !sourceBundle.isEmpty &&
            (installed == sourceBundle || installed.hasPrefix(sourceBundle + "."))
    }

    /// All currently installed extensions must still be present in the update.
    /// Re-signing may rewrite App Groups, so App Group string equality is not a
    /// reliable integrity check; SideStore must preserve the existing identity.
    static func preservesExtensions(installed: Set<String>, candidate: Set<String>) -> Bool {
        !installed.isEmpty && installed.isSubset(of: candidate) &&
            candidate.contains("LiveProcess.appex") && candidate.contains("LiveWidgetExtension.appex")
    }
}
