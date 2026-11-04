import Foundation

/// Pure guest indexing policy. The caller supplies stable keys; this layer
/// never stores data or requires any particular LiveContainer version.
enum BloomBoxHomeGuestIndex {
    static func keys<Guest>(
        _ guests: [Guest], key: (Guest) -> String,
        isEmbeddedSigner: (Guest) -> Bool
    ) -> [String] {
        guests.filter { !isEmbeddedSigner($0) }.map(key)
    }

    static func firstByKey<Guest>(
        _ guests: [Guest], key: (Guest) -> String,
        isEmbeddedSigner: (Guest) -> Bool
    ) -> [String: Guest] {
        var result: [String: Guest] = [:]
        for guest in guests where !isEmbeddedSigner(guest) {
            let stable = key(guest)
            if result[stable] == nil { result[stable] = guest }
        }
        return result
    }
}
