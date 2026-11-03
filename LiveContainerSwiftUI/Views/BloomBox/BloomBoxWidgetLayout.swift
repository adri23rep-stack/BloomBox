import Foundation

// Portable widget layout and saved widget schema. Field names stay unchanged.

struct BloomBoxPlacedWidget: Codable, Equatable, Identifiable {
    var id: String = UUID().uuidString
    var kind: String
    var slot: Int
    var columns: Int
    var rows: Int
    var mediaName: String? = nil
    var fill: Bool = true
    var glass: Bool = true
    /// Optional launcher key selected by the user. Nil keeps legacy tap behavior.
    /// Old saved widget JSON decodes without this key.
    var tapActionKey: String? = nil
    /// Optional: old layouts continue to decode with their original clock.
    var clockStyle: String? = nil
    var clockTint: String? = nil
    var clock24Hour: Bool? = nil
    var pixelGlow: Double? = nil
    var pixelAnimatedBar: Bool? = nil
}

enum BloomBoxWidgetGrid {
    static func cells(slot: Int, columns: Int, rows: Int) -> Set<Int>? {
        let x = slot % 4, y = slot / 4
        guard slot >= 0, slot < 24, columns >= 1, columns <= 4,
              rows >= 1, rows <= 4, x + columns <= 4, y + rows <= 6 else { return nil }
        return Set((0..<rows).flatMap { row in (0..<columns).map { slot + row * 4 + $0 } })
    }
    static func firstAvailable(columns: Int, rows: Int, occupied: Set<Int>) -> Int? {
        (0..<24).first { slot in
            guard let area = cells(slot: slot, columns: columns, rows: rows) else { return false }
            return area.isDisjoint(with: occupied)
        }
    }
}

/// Pure state changes for the iOS Home widget grid. Rendering, animation
/// and guest execution remain outside this engine.
enum BloomBoxWidgetPlacement {
    struct Result: Equatable {
        let pages: [Int: [BloomBoxPlacedWidget]]
        let page: Int
        let slot: Int
    }

    static func occupied(_ widgets: [BloomBoxPlacedWidget], excluding excluded: String? = nil) -> Set<Int> {
        widgets.reduce(into: Set<Int>()) { positions, widget in
            guard widget.id != excluded else { return }
            positions.formUnion(BloomBoxWidgetGrid.cells(
                slot: widget.slot, columns: widget.columns, rows: widget.rows
            ) ?? [])
        }
    }

    /// Chooses an existing *visible* Home page, preferring the selected page.
    /// This avoids allocating a new page for each widget during deletion or
    /// restoration while leaving hidden pages and their content untouched.
    static func freePosition(
        columns: Int, rows: Int,
        preferredPage: Int,
        visiblePages: [Int],
        in pages: [Int: [BloomBoxPlacedWidget]]
    ) -> (page: Int, slot: Int)? {
        guard BloomBoxWidgetGrid.cells(slot: 0, columns: columns, rows: rows) != nil else {
            return nil
        }
        var seen = Set<Int>()
        let candidates = ([preferredPage] + visiblePages).filter {
            $0 >= 0 && visiblePages.contains($0) && seen.insert($0).inserted
        }
        for page in candidates {
            let occupiedSlots = occupied(pages[page] ?? [])
            if let slot = BloomBoxWidgetGrid.firstAvailable(
                columns: columns, rows: rows, occupied: occupiedSlots
            ) {
                return (page, slot)
            }
        }
        return nil
    }

    private static func existing(_ id: String, in pages: [Int: [BloomBoxPlacedWidget]])
        -> (page: Int, widget: BloomBoxPlacedWidget)? {
        for page in pages.keys.sorted() {
            if let widget = pages[page]?.first(where: { $0.id == id }) {
                return (page, widget)
            }
        }
        return nil
    }

    static func move(
        _ id: String,
        to target: Int,
        requestedSlot: Int?,
        in pages: [Int: [BloomBoxPlacedWidget]]
    ) -> Result? {
        guard target >= 0, let source = existing(id, in: pages) else { return nil }
        let taken = occupied(pages[target] ?? [], excluding: id)
        let requestedValid = requestedSlot.flatMap { slot -> Int? in
            guard let area = BloomBoxWidgetGrid.cells(
                slot: slot, columns: source.widget.columns, rows: source.widget.rows
            ), area.isDisjoint(with: taken) else { return nil }
            return slot
        }
        // Retain the original slot when moving within the same page.
        let keepPrevious = source.page == target
            ? BloomBoxWidgetGrid.cells(
                slot: source.widget.slot, columns: source.widget.columns, rows: source.widget.rows
            ).flatMap { $0.isDisjoint(with: taken) ? source.widget.slot : nil }
            : nil
        guard let chosen = requestedValid ?? keepPrevious ??
            BloomBoxWidgetGrid.firstAvailable(
                columns: source.widget.columns, rows: source.widget.rows, occupied: taken
            ) else { return nil }

        var next = pages
        // An old duplicate widget ID must not survive a move.
        for key in next.keys {
            next[key]?.removeAll { $0.id == id }
        }
        var widget = source.widget
        widget.slot = chosen
        next[target, default: []].append(widget)
        return Result(pages: next, page: target, slot: chosen)
    }

    static func resize(
        _ id: String, columns: Int, rows: Int,
        in pages: [Int: [BloomBoxPlacedWidget]]
    ) -> Result? {
        guard let source = existing(id, in: pages) else { return nil }
        let taken = occupied(pages[source.page] ?? [], excluding: id)
        let validAtOldPosition = BloomBoxWidgetGrid.cells(
            slot: source.widget.slot, columns: columns, rows: rows
        ).flatMap { $0.isDisjoint(with: taken) ? source.widget.slot : nil }
        guard let chosen = validAtOldPosition ?? BloomBoxWidgetGrid.firstAvailable(
            columns: columns, rows: rows, occupied: taken
        ) else { return nil }

        var next = pages
        for key in next.keys { next[key]?.removeAll { $0.id == id } }
        var resized = source.widget
        resized.columns = columns
        resized.rows = rows
        resized.slot = chosen
        next[source.page, default: []].append(resized)
        return Result(pages: next, page: source.page, slot: chosen)
    }
}
