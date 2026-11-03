import SwiftUI
import UIKit

@MainActor enum BloomBoxOrientation {
    // Home owns its usual portrait lock. A LiveProcess guest may temporarily
    // override it, but MUST restore the previous mask when that guest exits.
    static var mask: UIInterfaceOrientationMask = .allButUpsideDown
    static var owner: UUID?
    private static var homeMask: UIInterfaceOrientationMask = .allButUpsideDown
    private static var guestMask: UIInterfaceOrientationMask?
    private static var guestAppKey: String?

    private static func updateScene(_ next: UIInterfaceOrientationMask, window: UIWindow?) {
        let changed = mask != next
        mask = next
        guard let scene = window?.windowScene else { return }
        let wrongOrientation = (next == .portrait && scene.interfaceOrientation != .portrait) ||
            (next == .landscape && !scene.interfaceOrientation.isLandscape)
        guard changed || wrongOrientation else { return }
        if #available(iOS 16.0, *) {
            window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: next)) { error in
                NSLog("BloomBox guest orientation request: %@", error.localizedDescription)
            }
        } else { UIViewController.attemptRotationToDeviceOrientation() }
    }

    static func apply(_ next: UIInterfaceOrientationMask, window: UIWindow?) {
        homeMask = next
        guard guestMask == nil else { return }
        updateScene(next, window: window)
    }

    /// Guest Auto allows device rotation rather than inheriting Home's
    /// portrait-only mask; explicit per-app locks override it.
    static func beginGuest(appKey: String, mask next: UIInterfaceOrientationMask, window: UIWindow?) {
        guard !appKey.isEmpty,
              next == .portrait || next == .landscape || next == .allButUpsideDown else { return }
        guestAppKey = appKey
        guestMask = next
        updateScene(next, window: window)
    }

    static func endGuest(appKey: String, window: UIWindow?) {
        guard guestAppKey == appKey else { return }
        guestMask = nil
        guestAppKey = nil
        updateScene(homeMask, window: window)
    }

    static func setLandscape(_ enabled: Bool, window: UIWindow?) {
        owner = nil
        apply(enabled ? .landscape : .allButUpsideDown, window: window)
    }
}

struct BloomBoxOrientationLock: UIViewRepresentable {
    let mask: UIInterfaceOrientationMask
    final class WindowObserver: UIView {
        let token = UUID()
        var requestedMask: UIInterfaceOrientationMask = .allButUpsideDown
        var applied = false
        func apply() {
            guard window != nil else { return }
            applied = true
            BloomBoxOrientation.owner = token
            BloomBoxOrientation.apply(requestedMask, window: window)
        }
        override func didMoveToWindow() { super.didMoveToWindow(); applied = false; apply() }
    }
    func makeUIView(context: Context) -> WindowObserver { WindowObserver() }
    func updateUIView(_ view: WindowObserver, context: Context) {
        if view.requestedMask != mask { view.applied = false }
        view.requestedMask = mask
        if !view.applied { DispatchQueue.main.async { [weak view] in view?.apply() } }
    }
    static func dismantleUIView(_ view: WindowObserver, coordinator: ()) {
        guard BloomBoxOrientation.owner == view.token else { return }
        BloomBoxOrientation.owner = nil
        BloomBoxOrientation.apply(.allButUpsideDown, window: view.window)
    }
}
struct BloomBoxLandscapeLock: View {
    let enabled: Bool
    var body: some View { BloomBoxOrientationLock(mask: enabled ? .landscape : .allButUpsideDown) }
}

// Compatibility only: existing host callers and saved names still resolve.
typealias LiveBoardOrientationLock = BloomBoxOrientationLock
typealias LiveBoardLandscapeLock = BloomBoxLandscapeLock
typealias LiveBoardOrientation = BloomBoxOrientation
