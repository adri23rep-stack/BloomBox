import Foundation

/// Frame sizing for a guest scene. Work with the actual containing view size,
/// never transpose a frame that already matches the requested orientation.
enum BloomBoxGuestSceneGeometry {
    static func size(_ container: CGSize, landscape: Bool) -> CGSize {
        guard container.width > 0, container.height > 0 else { return container }
        let wide = max(container.width, container.height)
        let narrow = min(container.width, container.height)
        return CGSize(width: landscape ? wide : narrow,
                      height: landscape ? narrow : wide)
    }
}
