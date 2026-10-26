import SwiftUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

/// Imports into app-owned storage; never holds a transient document-provider URL.
enum ManzanaWallpaperMedia {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("LiveBoard", isDirectory: true)
    }
    static func url(_ name: String) -> URL? {
        guard name.hasPrefix("motion-"), name == (name as NSString).lastPathComponent else { return nil }
        return directory.appendingPathComponent(name)
    }
    static func importFile(_ source: URL) throws -> String {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        let staging = directory.appendingPathComponent("motion-" + UUID().uuidString + "." + source.pathExtension.lowercased())
        do {
            var coordinationError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
                do {
                    let size = try readable.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                    guard size > 0, size <= 200 * 1024 * 1024 else { throw failure("Elige un archivo de hasta 200 MB.") }
                    try fm.copyItem(at: readable, to: staging)
                } catch { copyError = error }
            }
            if let coordinationError { throw coordinationError }
            if let copyError { throw copyError }
            if staging.pathExtension == "gif" {
                _ = try gifFrames(staging)
            } else {
                let asset = AVURLAsset(url: staging)
                guard asset.isPlayable, !asset.tracks(withMediaType: .video).isEmpty,
                      asset.duration.seconds.isFinite, asset.duration.seconds > 0 else {
                    throw failure("No se pudo reproducir ese video. Prueba un MP4 o MOV compatible con tu iPhone.")
                }
            }
            return staging.lastPathComponent
        } catch { try? fm.removeItem(at: staging); throw error }
    }
    static func failure(_ message: String) -> NSError { NSError(domain: "ManzanaWallpaper", code: 1, userInfo: [NSLocalizedDescriptionKey: message]) }
    static func gifFrames(_ url: URL) throws -> ([CGImage], [NSNumber], Double) {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              CGImageSourceGetType(source) as String? == UTType.gif.identifier else { throw failure("El GIF no es válido.") }
        let count = CGImageSourceGetCount(source)
        guard count > 0, count <= 500 else { throw failure("Este GIF tiene demasiados cuadros. Usa uno de hasta 500.") }
        // Conservative square bound: at most 48 MB of decoded frame pixels.
        let dimension = min(720, max(64, Int(sqrt(Double(48 * 1024 * 1024 / (count * 4))))))
        var frames: [CGImage] = []; var times: [Double] = []; var duration = 0.0
        for index in 0..<count {
            guard let frame = CGImageSourceCreateThumbnailAtIndex(source, index, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: dimension,
                kCGImageSourceCreateThumbnailWithTransform: true
            ] as CFDictionary) else { throw failure("No se pudo leer un cuadro del GIF.") }
            let props = CGImageSourceCopyPropertiesAtIndex(source, index, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            let delay = (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double)
                ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.1
            frames.append(frame); times.append(duration); duration += delay >= 0.02 ? delay : 0.1
        }
        return (frames, times.map { NSNumber(value: $0 / duration) }, duration)
    }
}

struct ManzanaAnimatedWallpaper: View {
    let url: URL
    let fit: Bool
    let paused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var visible = false
    var body: some View {
        ManzanaMotionSurface(url: url, fit: fit, playing: visible && scenePhase == .active && !paused && !reduceMotion)
            .onAppear { visible = true }.onDisappear { visible = false }
            .allowsHitTesting(false).accessibilityHidden(true)
    }
}

private struct ManzanaMotionSurface: UIViewRepresentable {
    let url: URL
    let fit: Bool
    let playing: Bool
    func makeUIView(context: Context) -> MotionView { MotionView() }
    func updateUIView(_ view: MotionView, context: Context) { view.configure(url: url, fit: fit, playing: playing) }
    static func dismantleUIView(_ view: MotionView, coordinator: ()) { view.stop() }

    final class MotionView: UIView {
        let videoLayer = AVPlayerLayer()
        let imageLayer = CALayer()
        var player: AVQueuePlayer?
        var looper: AVPlayerLooper?
        var loadedURL: URL?
        var animation: CAKeyframeAnimation?
        var wantsPlayback = false
        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true; backgroundColor = .black
            layer.addSublayer(videoLayer); layer.addSublayer(imageLayer)
        }
        required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
        override func layoutSubviews() {
            super.layoutSubviews()
            CATransaction.begin(); CATransaction.setDisableActions(true)
            videoLayer.frame = bounds; imageLayer.frame = bounds
            CATransaction.commit()
        }
        func configure(url: URL, fit: Bool, playing: Bool) {
            wantsPlayback = playing
            videoLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
            imageLayer.contentsGravity = fit ? .resizeAspect : .resizeAspectFill
            if loadedURL != url {
                stop(); loadedURL = url; wantsPlayback = playing
                if url.pathExtension.lowercased() == "gif" {
                    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                        guard let result = try? ManzanaWallpaperMedia.gifFrames(url) else { return }
                        DispatchQueue.main.async { [weak self] in
                            guard let self, self.loadedURL == url else { return }
                            self.imageLayer.contents = result.0.first
                            let animation = CAKeyframeAnimation(keyPath: "contents")
                            animation.values = result.0; animation.keyTimes = result.1
                            animation.duration = result.2; animation.calculationMode = .discrete
                            animation.repeatCount = .infinity
                            self.animation = animation; self.applyPlayback()
                        }
                    }
                } else {
                    let item = AVPlayerItem(url: url)
                    let queue = AVQueuePlayer(); queue.isMuted = true
                    queue.preventsDisplaySleepDuringVideoPlayback = false
                    looper = AVPlayerLooper(player: queue, templateItem: item)
                    player = queue; videoLayer.player = queue
                }
            }
            applyPlayback()
        }
        func applyPlayback() {
            if wantsPlayback { player?.play() } else { player?.pause() }
            if wantsPlayback, let animation {
                if imageLayer.animation(forKey: "loop") == nil { imageLayer.add(animation, forKey: "loop") }
            } else { imageLayer.removeAnimation(forKey: "loop") }
        }
        func stop() {
            player?.pause(); looper?.disableLooping(); player?.removeAllItems()
            videoLayer.player = nil; player = nil; looper = nil
            imageLayer.removeAllAnimations(); imageLayer.contents = nil
            animation = nil; loadedURL = nil
        }
        deinit { player?.pause() }
    }
}
