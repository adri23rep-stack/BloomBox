import Foundation

/// Home interaction rules. Keep guest models, signing and display implementation
/// outside this file so LiveContainer can be updated independently.
enum BloomBoxHomeAppPolicy {
    static let fallbackCategories = ["Games", "Ports", "Tools"]

    static func matching<T>(
        _ apps: [T], query: String, title: (T) -> String, bundleID: (T) -> String
    ) -> [T] {
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !term.isEmpty else { return apps }
        return apps.filter {
            title($0).localizedCaseInsensitiveContains(term) ||
                bundleID($0).localizedCaseInsensitiveContains(term)
        }
    }

    static func favorites(from json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8))) ?? []
    }

    static func toggledFavorite(_ key: String, in json: String) -> String {
        guard !key.isEmpty else { return json }
        var keys = favorites(from: json)
        if keys.contains(key) {
            keys.removeAll { $0 == key }
        } else {
            keys.append(key)
        }
        return encode(keys) ?? json
    }

    static func categoryNames(from json: String) -> [String] {
        (try? JSONDecoder().decode([String].self, from: Data(json.utf8)))
            ?? fallbackCategories
    }

    static func addingCategory(_ name: String, to json: String) -> String {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty, normalized.count <= 30 else { return json }
        var names = categoryNames(from: json)
        if !names.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            names.append(normalized)
        }
        return encode(names) ?? json
    }

    static func assignedCategories(from json: String) -> [String: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(json.utf8))) ?? [:]
    }

    static func assigningCategory(_ value: String?, to key: String, in json: String) -> String {
        guard !key.isEmpty else { return json }
        var values = assignedCategories(from: json)
        values[key] = value
        return encode(values) ?? json
    }

    private static func encode<T: Encodable>(_ value: T) -> String? {
        guard let data = try? JSONEncoder().encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
