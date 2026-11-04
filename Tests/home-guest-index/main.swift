import Foundation

struct DemoGuest {
    let key: String
    let label: String
    let embedded: Bool
}

let items = [
    DemoGuest(key: "a", label: "first", embedded: false),
    DemoGuest(key: "signer", label: "SideStore", embedded: true),
    DemoGuest(key: "a", label: "duplicate", embedded: false),
    DemoGuest(key: "b", label: "second", embedded: false)
]
let keys = BloomBoxHomeGuestIndex.keys(
    items, key: { $0.key }, isEmbeddedSigner: { $0.embedded })
precondition(keys == ["a", "a", "b"], "Legacy guest key order must not change")
let appMap = BloomBoxHomeGuestIndex.firstByKey(
    items, key: { $0.key }, isEmbeddedSigner: { $0.embedded })
precondition(appMap.count == 2 && appMap["a"]?.label == "first" && appMap["b"]?.label == "second",
             "Desktop must ignore embedded signer and retain first duplicate")
let searchMap = BloomBoxHomeGuestIndex.firstByKey(
    items, key: { $0.key }, isEmbeddedSigner: { _ in false })
precondition(searchMap.count == 3 && searchMap["signer"]?.label == "SideStore",
             "Search mapping must retain existing embedded signer behavior")
let empty = BloomBoxHomeGuestIndex.firstByKey(
    [DemoGuest](), key: { $0.key }, isEmbeddedSigner: { $0.embedded })
precondition(empty.isEmpty, "Empty installed guest list must remain empty")
let legacy = DemoGuest(key: "manzana:sidestore", label: "stored", embedded: false)
precondition(BloomBoxHomeGuestIndex.keys([legacy], key: { $0.key },
             isEmbeddedSigner: { $0.embedded }) == ["manzana:sidestore"],
             "Persisted guest keys must remain byte-identical")
print("BloomBox guest indexing keeps order, duplicate policy and embedded app behavior.")
