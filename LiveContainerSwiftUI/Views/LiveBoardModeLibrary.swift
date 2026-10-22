import Foundation

struct LiveBoardModeLibrary: Codable, Equatable {
    var categories = ["Games", "Ports", "Tools"]
    var assignments: [String: String] = [:]
    var hidden: Set<String> = []
    mutating func addCategory(_ value: String) -> Bool {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name.count <= 30,
              !(["Library", "Favorites", "All"] + categories).contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) else { return false }
        categories.append(name); return true
    }
    mutating func removeCategory(_ name: String) {
        categories.removeAll { $0 == name }; assignments = assignments.filter { $0.value != name }
    }
}
