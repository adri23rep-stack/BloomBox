import Foundation

struct LiveBoardConsoleLayout: Codable, Equatable {
    var iconScale: Double = 1
    var launchScale: Double = 1
    var launchX: Double = 0
    var launchY: Double = 0.72
    init() {}
    private enum CodingKeys: String, CodingKey { case iconScale, launchScale, launchX, launchY }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        iconScale = try values.decodeIfPresent(Double.self, forKey: .iconScale) ?? 1
        launchScale = try values.decodeIfPresent(Double.self, forKey: .launchScale) ?? 1
        launchX = try values.decodeIfPresent(Double.self, forKey: .launchX) ?? 0
        launchY = try values.decodeIfPresent(Double.self, forKey: .launchY) ?? 0.72
        clamp()
    }
    mutating func clamp() {
        iconScale = iconScale.isFinite ? min(2.5, max(0.65, iconScale)) : 1
        launchScale = launchScale.isFinite ? min(2, max(0.75, launchScale)) : 1
        launchX = launchX.isFinite ? min(1, max(0, launchX)) : 0
        launchY = launchY.isFinite ? min(1, max(0, launchY)) : 0.72
    }
    static func decode(_ value: String, mode: String) -> Self {
        var layout = ((try? JSONDecoder().decode([String: Self].self, from: Data(value.utf8))) ?? [:])[mode] ?? Self()
        layout.clamp(); return layout
    }
    static func save(_ layout: Self, mode: String, in value: String) -> String {
        var all = (try? JSONDecoder().decode([String: Self].self, from: Data(value.utf8))) ?? [:]
        var layout = layout; layout.clamp(); all[mode] = layout
        return String(data: (try? JSONEncoder().encode(all)) ?? Data(), encoding: .utf8) ?? "{}"
    }
}
