import SwiftUI
import AVFoundation
import QuartzCore
import ImageIO

/// One BloomBox playback view for wallpapers, GIF widgets and news cards.
/// Playback suspends in background and when Reduce Motion is requested.
struct BloomBoxAnimatedWallpaper: View {
    let url: URL
    let fit: Bool
    let paused: Bool
    var clearBackground = false

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject private var performanceBudget = BloomBoxPerformanceBudget.shared
    @State private var appeared = false

    var body: some View {
        BloomBoxMotionPlayer(
            url: url,
            fit: fit,
            playing: appeared && scenePhase == .active && !paused && !reduceMotion && !performanceBudget.constrained,
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
    private var preparingGIF = false

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
            if isGIF {
                // Do not decode an entire GIF for an offscreen tile or Low Power Mode.
                if playing { prepareGIF(url) } else { prepareGIFPreview(url) }
            } else { prepareVideo(url) }
        } else if isGIF && playing && framesAnimation == nil && !preparingGIF {
            prepareGIF(url)
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

    private func prepareGIFPreview(_ url: URL) {
        let expectedGeneration = generation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let source = CGImageSourceCreateWithURL(url as CFURL, nil)
            let first = source.flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expectedGeneration,
                      self.currentURL == url, self.framesAnimation == nil else { return }
                self.gifLayer.contents = first
            }
        }
    }

    private func prepareGIF(_ url: URL) {
        guard !preparingGIF else { return }
        preparingGIF = true
        let expectedGeneration = generation
        DispatchQueue.global(qos: .utility).async { [weak self] in
            let frames = try? BloomBoxMotionMedia.gifFrames(url)
            DispatchQueue.main.async { [weak self] in
                guard let self, self.generation == expectedGeneration,
                      self.currentURL == url else { return }
                self.preparingGIF = false
                guard let frames else { return }
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
        preparingGIF = false
        currentURL = nil
    }

    deinit { player?.pause() }
}
