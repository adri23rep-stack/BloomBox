import Foundation

/// Valid widget choices shared by Home, themes and the standalone picker.
/// Saved preferences keep the same comma-separated format as older releases.
enum BloomBoxWidgetGalleryPolicy {
    static let allowed = ["clock", "photo", "notes"]

    static func decode(_ raw: String) -> [String] {
        var seen = Set<String>()
        return raw.split(separator: ",")
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { allowed.contains($0) && seen.insert($0).inserted }
    }

    static func toggle(_ kind: String, in raw: String) -> String {
        guard allowed.contains(kind) else { return decode(raw).joined(separator: ",") }
        var selected = decode(raw)
        if selected.contains(kind) {
            selected.removeAll { $0 == kind }
        } else {
            selected.append(kind)
        }
        return selected.joined(separator: ",")
    }
}
