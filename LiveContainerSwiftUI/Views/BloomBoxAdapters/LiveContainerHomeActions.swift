import Foundation

/// The only Home action bridge allowed to resolve saved BloomBox app keys into
/// mutable LiveContainer models. The View asks for actions using the stable keys
/// and retains its existing preflight, confirmation and JIT warning behavior.
@MainActor
struct LiveContainerHomeActions {
    private let byKey: [String: LCAppModel]
    private let openNormally: (LCAppModel) -> Void
    private let openWithJIT: ((LCAppModel) -> Void)?
    private let showSettings: (LCAppModel) -> Void
    private let removeApp: (LCAppModel) -> Void

    init(guests: [LCAppModel],
         open: @escaping (LCAppModel) -> Void,
         openJIT: ((LCAppModel) -> Void)?,
         manage: @escaping (LCAppModel) -> Void,
         uninstall: @escaping (LCAppModel) -> Void) {
        byKey = LiveContainerHomeAdapter.searchModelsByKey(guests)
        openNormally = open
        openWithJIT = openJIT
        showSettings = manage
        removeApp = uninstall
    }

    /// A missing guest after uninstall/reconciliation cannot trigger another
    /// guest's action. JIT falls back to normal only if no JIT handler exists,
    /// preserving the legacy host callback semantics.
    /// Keep the exact selected guest when two installations share a legacy
    /// key. Unknown or stale keys never resolve to a different guest.
    private func resolve(_ key: String, selected: LCAppModel?) -> LCAppModel? {
        if let selected, LiveContainerHomeAdapter.key(selected) == key {
            return selected
        }
        return byKey[key]
    }

    @discardableResult
    func perform(_ command: BloomBoxHomeGuestCommand, selected: LCAppModel? = nil) -> Bool {
        switch command {
        case let .open(key, jit):
            guard let app = resolve(key, selected: selected) else { return false }
            if jit, let openWithJIT {
                openWithJIT(app)
            } else {
                openNormally(app)
            }
        case let .manage(key):
            guard let app = resolve(key, selected: selected) else { return false }
            showSettings(app)
        case let .uninstall(key):
            guard let app = resolve(key, selected: selected) else { return false }
            removeApp(app)
        }
        return true
    }
}
