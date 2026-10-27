import SwiftUI
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

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
