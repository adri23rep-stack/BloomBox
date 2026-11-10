// SPDX-License-Identifier: AGPL-3.0-only
// BloomBox's inert importer for the original Playnite Nintendo Switch-ish
// theme. Visual files are parsed as data, never run as WPF, scripts or plugins.
import Foundation
import SwiftUI
import ImageIO

struct BloomBoxPlayniteSwitchStyle {
    let name: String
    let accent: Color
    let background: Color
    let logo: UIImage?
    let settingsIcon: UIImage?
    let wifiIcon: UIImage?
}

/// Intentionally limited to Nintendo Switch-ish v2 and isolated from
/// BloomBox's desktop .bbtheme import/export format.
@MainActor
final class BloomBoxPlayniteSwitchThemeStore: ObservableObject {
    enum ImportError: LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case .invalid(let reason) = self { return reason }
            return nil
        }
    }

    @Published private(set) var style: BloomBoxPlayniteSwitchStyle?
    var installed: Bool { style != nil }

    private static let expectedID = "Nintendo Switch-ish_0d020ed5-0f3c-4c1a-bf9a-c983ef7d74b7"
    static let officialRelease = URL(string:
        "https://github.com/davidkgriggs/Nintendo-Switch-ish/releases/download/v2.0.0/Nintendo_Switch-ish_0d020ed5-0f3c-4c1a-bf9a-c983ef7d74b7_2_0_0.pthm")!

    nonisolated private static var libraryRoot: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BloomBox/PlayniteThemes", isDirectory: true)
    }
    nonisolated private static var installedURL: URL {
        libraryRoot.appendingPathComponent("Nintendo-Switch-ish-v2", isDirectory: true)
    }

    init() { reload() }

    func downloadOriginal() async throws {
        let (tempURL, response) = try await URLSession.shared.download(from: Self.officialRelease)
        guard let response = response as? HTTPURLResponse,
              (200...299).contains(response.statusCode) else {
            throw ImportError.invalid("No se pudo descargar el tema original de GitHub.")
        }
        try await install(from: tempURL, securityScoped: false)
    }

    func importOriginal(_ source: URL) async throws {
        guard source.pathExtension.lowercased() == "pthm" else {
            throw ImportError.invalid("Selecciona el archivo original .pthm de Nintendo Switch-ish.")
        }
        try await install(from: source, securityScoped: true)
    }

    private func install(from source: URL, securityScoped: Bool) async throws {
        let access = securityScoped && source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let copy = FileManager.default.temporaryDirectory
            .appendingPathComponent("bb-playnite-\(UUID().uuidString).pthm")
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(at: source, to: copy)
        try await Task.detached(priority: .userInitiated) {
            try Self.extractVerifiedSwitchPackage(copy)
        }.value
        reload()
        guard installed else {
            throw ImportError.invalid("El tema se guardó, pero no se pudo cargar su vista previa.")
        }
    }

    nonisolated private static func extractVerifiedSwitchPackage(_ file: URL) throws {
        let fm = FileManager.default
        let root = libraryRoot
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        let staging = root.appendingPathComponent("incoming-" + UUID().uuidString, isDirectory: true)
        defer { try? fm.removeItem(at: staging) }
        try BloomBoxArchive.unpackPlayniteTheme(source: file, destination: staging)
        guard let base = try locateThemeBase(staging) else {
            throw ImportError.invalid("No se encontró el tema Fullscreen Nintendo Switch-ish v2 en el archivo.")
        }
        let yaml = try String(contentsOf: base.appendingPathComponent("theme.yaml"), encoding: .utf8)
        let fields = parseYAML(yaml)
        guard fields["Id"] == expectedID,
              fields["Mode"]?.lowercased() == "fullscreen",
              fields["Version"] == "2.0.0",
              fm.fileExists(atPath: base.appendingPathComponent("Views/Main.xaml").path),
              fm.fileExists(atPath: base.appendingPathComponent("Constants.xaml").path) else {
            throw ImportError.invalid("El paquete no coincide con Nintendo Switch-ish Fullscreen v2.0.")
        }
        // Require an original graphic: don't accept an empty or forged manifest-only package.
        let logo = base.appendingPathComponent("Images/applogo_clean.png")
        guard fm.fileExists(atPath: logo.path),
              let image = CGImageSourceCreateWithURL(logo as CFURL, nil),
              CGImageSourceGetCount(image) > 0 else {
            throw ImportError.invalid("El tema no contiene sus recursos gráficos originales.")
        }
        guard !fm.fileExists(atPath: installedURL.path) else {
            throw ImportError.invalid("Nintendo Switch-ish ya está instalado. Elimínalo antes de volver a importarlo.")
        }
        // Move the verified data to its own permanent directory without touching Home.
        try fm.moveItem(at: base, to: installedURL)
    }

    nonisolated private static func locateThemeBase(_ root: URL) throws -> URL? {
        let fm = FileManager.default
        let candidates = [root, root.appendingPathComponent("source")]
        if let entries = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey],
                                                     options: [.skipsHiddenFiles]) {
            for entry in entries where (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                // Playnite may wrap all source files in a single top-level folder.
                if entry.lastPathComponent.hasPrefix("incoming-") { continue }
                if fm.fileExists(atPath: entry.appendingPathComponent("theme.yaml").path) {
                    return entry
                }
                let source = entry.appendingPathComponent("source")
                if fm.fileExists(atPath: source.appendingPathComponent("theme.yaml").path) {
                    return source
                }
            }
        }
        return candidates.first { fm.fileExists(atPath: $0.appendingPathComponent("theme.yaml").path) }
    }

    nonisolated private static func parseYAML(_ text: String) -> [String: String] {
        var fields: [String: String] = [:]
        for line in text.split(whereSeparator: \.isNewline) {
            let value = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let separator = value.firstIndex(of: ":") else { continue }
            let key = String(value[..<separator])
            if ["Id", "Name", "Mode", "Version", "Author"].contains(key) {
                fields[key] = String(value[value.index(after: separator)...])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "'"))
            }
        }
        return fields
    }

    private func reload() {
        guard let root = try? Self.locateThemeBase(Self.installedURL),

              let yaml = try? String(contentsOf: root.appendingPathComponent("theme.yaml"), encoding: .utf8),
              Self.parseYAML(yaml)["Id"] == Self.expectedID,
              let constants = try? String(contentsOf: root.appendingPathComponent("Constants.xaml"), encoding: .utf8) else {
            style = nil
            return
        }
        let accent = Self.color(in: constants, pattern:
            #"<Color\s+x:Key="ControlBackgroundColor">\s*(#[0-9A-Fa-f]{6,8})"#)
            ?? Color(red: 0.24, green: 0.86, blue: 0.73)
        let background = Self.color(in: constants, pattern:
            #"<SolidColorBrush\s+x:Key="MainBackgourndBrush"\s+Color="(#[0-9A-Fa-f]{6,8})""#)
            ?? Color(red: 0.18, green: 0.18, blue: 0.18)
        style = BloomBoxPlayniteSwitchStyle(
            name: "Nintendo Switch-ish",
            accent: accent,
            background: background,
            logo: Self.smallImage(root.appendingPathComponent("Images/applogo_clean.png")),
            settingsIcon: Self.smallImage(root.appendingPathComponent("Images/settings.png")),
            wifiIcon: Self.smallImage(root.appendingPathComponent("Images/wifi.png"))
        )
    }

    nonisolated private static func color(in text: String, pattern: String) -> Color? {
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges >= 2,
              let colorRange = Range(match.range(at: 1), in: text) else { return nil }
        let hex = String(text[colorRange].dropFirst())
        guard hex.count == 6 || hex.count == 8,
              let parsed = UInt64(hex, radix: 16) else { return nil }
        let red = Double((parsed >> 16) & 255) / 255.0
        let green = Double((parsed >> 8) & 255) / 255.0
        let blue = Double(parsed & 255) / 255.0
        let alpha = hex.count == 8 ? Double((parsed >> 24) & 255) / 255.0 : 1.0
        return Color(red: red, green: green, blue: blue).opacity(alpha)
    }

    nonisolated private static func smallImage(_ file: URL) -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(file as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any],
              let width = properties[kCGImagePropertyPixelWidth as String] as? Int,
              let height = properties[kCGImagePropertyPixelHeight as String] as? Int,
              width > 0, height > 0, width <= 4096, height <= 4096,
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: 200,
                kCGImageSourceCreateThumbnailWithTransform: true
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: image)
    }

    func uninstall() throws {
        try FileManager.default.removeItem(at: Self.installedURL)
        reload()
    }
}
