import Foundation

/// Reflow only Home icons covered by widget cells; never touches guest data,
/// dock entries, installed app directories or folder membership.
enum BloomBoxHomeIconReflow {
    static func apply(
        to original: BloomBoxHomeLayout,
        widgets: [Int: [BloomBoxPlacedWidget]],
        hiddenPages: Set<Int>
    ) -> BloomBoxHomeLayout {
        var result = original
        var displaced: [(from: Int, key: String)] = []

        // Collect before placing: a newly relocated icon must not be evicted
        // again later in this pass. Sorting cells also keeps ordering stable.
        for page in result.pages.indices {
            let occupied = BloomBoxWidgetPlacement.occupied(widgets[page] ?? [])
            for slot in occupied.sorted() where result.pages[page].indices.contains(slot) {
                if let key = result.pages[page][slot] {
                    result.pages[page][slot] = nil
                    displaced.append((page, key))
                }
            }
        }

        for item in displaced {
            // First try the same page to avoid shuffling the desktop. If the
            // source was hidden, still preserve its existing icon privacy.
            var candidates = [item.from]
            candidates += (0..<result.pages.count).filter {
                $0 != item.from && !hiddenPages.contains($0) && $0 > item.from
            }
            candidates += (0..<result.pages.count).filter {
                $0 != item.from && !hiddenPages.contains($0) && $0 < item.from
            }
            var placed = false
            for page in candidates {
                let blocked = BloomBoxWidgetPlacement.occupied(widgets[page] ?? [])
                if let slot = result.pages[page].indices.first(where: {
                    result.pages[page][$0] == nil && !blocked.contains($0)
                }) {
                    result.pages[page][slot] = item.key
                    placed = true
                    break
                }
            }
            if !placed {
                // A new page is always visible and subsequent displaced icons
                // reuse it rather than creating one page per icon.
                result.pages.append(Array(repeating: nil, count: BloomBoxHomeLayout.capacity))
                let page = result.pages.count - 1
                result.pages[page][0] = item.key
            }
        }
        return result
    }
}
