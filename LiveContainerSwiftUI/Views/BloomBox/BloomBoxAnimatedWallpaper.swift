import SwiftUI
import AVFoundation
import QuartzCore

/// One BloomBox playback view for wallpapers, GIF widgets and news cards.
/// Playback suspends in background and when Reduce Motion is requested.
struct BloomBoxAnimatedWallpaper: View {
    let url: URL
    let fit: Bool
    let paused: Bool
    var clearBackground = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    var body: some View {
        BloomBoxMotionPlayer(
            url: url,
            fit: fit,
            playing: appeared && scenePhase == .active && !paused && !reduceMotion,
            transparentGIF: clearBackground
        )
        .onAppear { appeared = true }
        .onDisappear { appeared = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct BloomBoxMotionPlayer: UIViewRepresentable {
    let url: URL
    let fit: Bool
    let playing: Bool
    let transparentGIF: Bool

    func makeUIView(context: Context) -> BloomBoxMotionSurface {
        BloomBoxMotionSurface()
    }

    func updateUIView(_ surface: BloomBoxMotionSurface, context: Context) {
        surface.configure(url: url, fit: fit, playing: playing,
                          transparentGIF: transparentGIF)
    }

    static func dismantleUIView(_ surface: BloomBoxMotionSurface, coordinator: ()) {
        surface.releasePlayback()
    }
}

private final class BloomBoxMotionSurface: UIView {
    private let movieLayer = AVPlayerLayer()
    private let gifLayer = CALayer()
    private var player: AVQueuePlayer?
    private var looper: AVPlayerLooper?
    private var framesAnimation: CAKeyframeAnimation?
    private var currentURL: URL?
    private var generation = UUID()
    private var shouldPlay = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        clipsToBounds = true
        layer.addSublayer(movieLayer)
        layer.addSublayer(gifLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        clipsToBounds = true
        layer.addSublayer(movieLayer)
        layer.addSublayer(gifLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        movieLayer.frame = bounds
        gifLayer.frame = bounds
        CATransaction.commit()
    }

    func configure(url: URL, fit: Bool, playing: Bool, transparentGIF: Bool) {
        let isGIF = url.pathExtension.lowercased() == "gif"
        shouldPlay = playing
        backgroundColor = isGIF && transparentGIF ? .clear : .black
        movieLayer.videoGravity = fit ? .resizeAspect : .resizeAspectFill
        gifLayer.contentsGravity = fit ? .resizeAspect : .resizeAspectFill

        if currentURL != url {
            releasePlayback()
            currentURL = url
            shouldPlay = playing
            if isGIF { prepareGIF(url) } else { prepareVideo(url) }
        }
        updatePlayback()
    }

    private func prepareVideo(_ url: URL) {
        let queue = AVQueuePlayer()
        queue.isMuted = true
        queue.preventsDisplaySleepDuringVideoPlayback = false
        looper = AVPlayerLooper(player: queue, templateItem: AVPlayerItem(url: url))
        movieLayer.player = queue
        player = queue
    }

    private func prepareGIF(_ url: URL) {
        let expectedGeneration = generation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let frames = try? BloomBoxMotionMedia.gifFrames(url)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expectedGeneration,
                      self.currentURL == url, let frames else { return }
                self.gifLayer.contents = frames.0.first
                let animation = CAKeyframeAnimation(keyPath: "contents")
                animation.values = frames.0
                animation.keyTimes = frames.1
                animation.duration = frames.2
                animation.calculationMode = .discrete
                animation.repeatCount = .infinity
                self.framesAnimation = animation
                self.updatePlayback()
            }
        }
    }

    private func updatePlayback() {
        if shouldPlay { player?.play() } else { player?.pause() }
        if shouldPlay, let framesAnimation {
            if gifLayer.animation(forKey: "BloomBoxGIF") == nil {
                gifLayer.add(framesAnimation, forKey: "BloomBoxGIF")
            }
        } else {
            gifLayer.removeAnimation(forKey: "BloomBoxGIF")
        }
    }

    func releasePlayback() {
        generation = UUID()
        player?.pause()
        looper?.disableLooping()
        player?.removeAllItems()
        movieLayer.player = nil
        player = nil
        looper = nil
        gifLayer.removeAllAnimations()
        gifLayer.contents = nil
        framesAnimation = nil
        currentURL = nil
    }

    deinit { player?.pause() }
}
