import UIKit
import CoreImage

/// Remove the baked-in contour of pre-rounded PNGs before applying the launcher mask.
@MainActor enum LiveBoardIconEdges {
    private static let context = CIContext(options: [.cacheIntermediates: false])
    static func clean(_ image: UIImage) -> UIImage {
        guard let cg = image.cgImage, cg.width > 32, cg.height > 32 else { return image }
        var pixels = [UInt8](repeating: 0, count: cg.width * cg.height * 4)
        guard let sample = CGContext(data: &pixels, width: cg.width, height: cg.height, bitsPerComponent: 8, bytesPerRow: cg.width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return image }
        sample.draw(cg, in: CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        let corners = [0, cg.width - 1, cg.width * (cg.height - 1), cg.width * cg.height - 1]
        guard corners.contains(where: { pixels[$0 * 4 + 3] < 240 }) else { return image }
        let input = CIImage(cgImage: cg)
        let alpha = input.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 1),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBiasVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])
        let inset = max(1, CGFloat(min(cg.width, cg.height)) * 0.02)
        let eroded = alpha.applyingFilter("CIMorphologyMinimum", parameters: [kCIInputRadiusKey: inset])
        let output = input.applyingFilter("CIBlendWithMask", parameters: [kCIInputBackgroundImageKey: CIImage(color: .clear), kCIInputMaskImageKey: eroded])
        guard let cleaned = context.createCGImage(output, from: input.extent.insetBy(dx: inset, dy: inset)) else { return image }
        return UIImage(cgImage: cleaned, scale: image.scale, orientation: image.imageOrientation)
    }
}
