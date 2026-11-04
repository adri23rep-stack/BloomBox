import Foundation

/// BloomBox's own Home navigation. 0 = News, 1...N = Home, N+1 = App Library.
/// Persisted hidden-page JSON remains compatible with existing themes.
struct BloomBoxHomeNavigation: Equatable {
    let pageCount: Int
    let currentPage: Int
    let hidden: Set<Int>

    init(pageCount: Int, currentPage: Int, hiddenJSON: String) {
        let decoded = (try? JSONDecoder().decode([Int].self, from: Data(hiddenJSON.utf8))) ?? []
        self.init(pageCount: pageCount, currentPage: currentPage, hidden: Set(decoded))
    }

    private init(pageCount: Int, currentPage: Int, hidden: Set<Int>) {
        let count = max(1, pageCount)
        var valid = Set(hidden.filter { (0..<count).contains($0) })
        if valid.count == count { valid.remove(0) } // Always keep one Home page.
        self.pageCount = count
        self.currentPage = currentPage
        self.hidden = valid
    }

    var libraryPage: Int { pageCount + 1 }
    var visible: [Int] { (0..<pageCount).filter { !hidden.contains($0) } }
    var encodedHidden: String {
        guard let bytes = try? JSONEncoder().encode(hidden.sorted()),
              let text = String(data: bytes, encoding: .utf8) else { return "[]" }
        return text
    }

    var safePage: Int {
        if currentPage == 0 { return 0 }
        if currentPage == libraryPage { return libraryPage }
        let selected = currentPage - 1
        if (0..<pageCount).contains(selected), !hidden.contains(selected) {
            return currentPage
        }
        let nearest = visible.min { left, right in
            let x = abs(left - selected), y = abs(right - selected)
            return x == y ? left < right : x < y
        }
        return (nearest ?? 0) + 1
    }

    func toggledVisibility(at index: Int) -> BloomBoxHomeNavigation? {
        guard (0..<pageCount).contains(index) else { return nil }
        var next = hidden
        if next.contains(index) {
            next.remove(index)
        } else {
            guard visible.count > 1 else { return nil }
            next.insert(index)
        }
        return BloomBoxHomeNavigation(pageCount: pageCount, currentPage: currentPage, hidden: next)
    }

    func selectedFromOverview(_ index: Int) -> BloomBoxHomeNavigation? {
        guard (0..<pageCount).contains(index) else { return nil }
        var next = hidden
        next.remove(index)
        return BloomBoxHomeNavigation(pageCount: pageCount, currentPage: index + 1, hidden: next)
    }

    func removedPage(at index: Int, destinationContainsIcons: Bool,
                     newPageCount: Int) -> BloomBoxHomeNavigation? {
        guard pageCount > 1, (0..<pageCount).contains(index) else { return nil }
        var shifted = Set(hidden.compactMap { previous -> Int? in
            if previous == index { return nil }
            return previous > index ? previous - 1 : previous
        })
        let count = max(1, newPageCount)
        if destinationContainsIcons { shifted.remove(min(index, count - 1)) }
        var selected = currentPage
        if selected > index + 1 { selected -= 1 }
        else if selected == index + 1 { selected = min(index + 1, count) }
        return BloomBoxHomeNavigation(pageCount: count, currentPage: selected, hidden: shifted)
    }

    static func reindexWidgets<T>(_ old: [Int: [T]], removing index: Int)
        -> (remaining: [Int: [T]], displaced: [T]) {
        var remaining: [Int: [T]] = [:]
        for (page, items) in old where page != index {
            remaining[page > index ? page - 1 : page] = items
        }
        return (remaining, old[index] ?? [])
    }
}
