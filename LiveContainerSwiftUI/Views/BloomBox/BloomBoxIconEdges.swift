import UIKit
import CoreImage

/// Processes icon transparency before BloomBox applies its own icon outline.
/// Callers keep the legacy public type alias so saved icon selections work.
@MainActor enum BloomBoxIconEdges {
    private static let renderer = CIContext(options: [.cacheIntermediates: false])

    static func clean(_ original: UIImage) -> UIImage {
        guard let bitmap = original.cgImage,
              min(bitmap.width, bitmap.height) > 32,
              cornersNeedTrimming(bitmap) else { return original }

        let source = CIImage(cgImage: bitmap)
        let margin = max(1, CGFloat(min(bitmap.width, bitmap.height)) * 0.02)
        let alphaAsGray = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        let inside = alphaAsGray.applyingFilter(
            "CIMorphologyMinimum", parameters: [kCIInputRadiusKey: margin])
        let corrected = source.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputMaskImageKey: inside,
            kCIInputBackgroundImageKey: CIImage(color: .clear)
        ])
        let crop = source.extent.insetBy(dx: margin, dy: margin)
        guard let cg = renderer.createCGImage(corrected, from: crop) else { return original }
        return UIImage(cgImage: cg, scale: original.scale, orientation: original.imageOrientation)
    }

    private static func cornersNeedTrimming(_ bitmap: CGImage) -> Bool {
        let width = bitmap.width, height = bitmap.height
        // Large user-supplied artwork is rendered by the standard icon mask.
        guard width <= 4096, height <= 4096 else { return false }
        let stride = width * 4
        var rgba = [UInt8](repeating: 0, count: stride * height)
        guard let canvas = CGContext(
            data: &rgba, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        canvas.draw(bitmap, in: CGRect(x: 0, y: 0, width: width, height: height))

        let offsets = [0, width - 1, width * (height - 1), width * height - 1]
        return offsets.contains { rgba[$0 * 4 + 3] < 240 }
    }
}

// Compatibility alias: previously saved icon shapes keep their visual treatment.
typealias LiveBoardIconEdges = BloomBoxIconEdges
