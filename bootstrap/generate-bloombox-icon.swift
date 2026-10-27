import AppKit
import CoreGraphics
import Foundation

// BloomBox: a blooming flower rising out of a geometric box.
// Deterministic, original vector artwork. Used to populate standard icon
// asset catalog slots and legacy PNGs before the Xcode build.
let size: CGFloat = 1024
func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
}
func drawIcon(in rect: NSRect) {
    let scale = rect.width / size
    NSGraphicsContext.current?.saveGraphicsState()
    let transform = AffineTransform(scale: scale)
    transform.concat()

    let canvas = NSRect(x: 0, y: 0, width: 1024, height: 1024)
    let bg = NSBezierPath(roundedRect: canvas.insetBy(dx: 8, dy: 8), xRadius: 215, yRadius: 215)
    NSGradient(colors: [
        rgb(0.11, 0.10, 0.31),
        rgb(0.20, 0.11, 0.40),
        rgb(0.08, 0.28, 0.40),
    ])!.draw(in: bg, angle: 130)

    let glow = NSBezierPath(ovalIn: NSRect(x: 190, y: 280, width: 640, height: 640))
    rgb(0.37, 0.90, 0.76, 0.12).setFill()
    glow.fill()

    let cx: CGFloat = 512
    let cy: CGFloat = 650
    let petalColor = rgb(0.48, 0.94, 0.77)
    for i in 0..<6 {
        let angle = CGFloat(i) * (.pi / 3)
        let dx = cos(angle) * 112
        let dy = sin(angle) * 112
        let petal = NSBezierPath(ovalIn: NSRect(x: cx + dx - 66, y: cy + dy - 92, width: 132, height: 184))
        petalColor.withAlphaComponent(0.93).setFill()
        petal.fill()
    }

    let center = NSBezierPath(ovalIn: NSRect(x: cx - 66, y: cy - 66, width: 132, height: 132))
    rgb(0.95, 0.84, 0.53).setFill()
    center.fill()

    // Angular BloomBox container, distinct from Manzana's apple-shaped icon.
    let back = NSBezierPath()
    back.move(to: NSPoint(x: 512, y: 464))
    back.line(to: NSPoint(x: 764, y: 378))
    back.line(to: NSPoint(x: 512, y: 265))
    back.line(to: NSPoint(x: 260, y: 378))
    back.close()
    rgb(0.65, 0.53, 0.99).setFill()
    back.fill()

    let left = NSBezierPath()
    left.move(to: NSPoint(x: 260, y: 378))
    left.line(to: NSPoint(x: 512, y: 265))
    left.line(to: NSPoint(x: 512, y: 125))
    left.line(to: NSPoint(x: 260, y: 244))
    left.close()
    rgb(0.34, 0.69, 0.88).setFill()
    left.fill()

    let right = NSBezierPath()
    right.move(to: NSPoint(x: 512, y: 265))
    right.line(to: NSPoint(x: 764, y: 378))
    right.line(to: NSPoint(x: 764, y: 244))
    right.line(to: NSPoint(x: 512, y: 125))
    right.close()
    rgb(0.27, 0.40, 0.75).setFill()
    right.fill()

    // A thin bright fold line visually ties the box and flower together.
    let fold = NSBezierPath()
    fold.move(to: NSPoint(x: 263, y: 378))
    fold.line(to: NSPoint(x: 512, y: 266))
    fold.line(to: NSPoint(x: 761, y: 378))
    fold.lineWidth = 10
    fold.lineCapStyle = .round
    rgb(0.89, 0.99, 0.95, 0.65).setStroke()
    fold.stroke()

    NSGraphicsContext.current?.restoreGraphicsState()
}

func save(_ file: String, width: Int, height: Int) throws {
    guard let bmp = NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
        isPlanar: false, colorSpaceName: .deviceRGB,
        bytesPerRow: width * 4, bitsPerPixel: 32
    ) else { fatalError("Cannot allocate icon bitmap") }

    guard let context = NSGraphicsContext(bitmapImageRep: bmp) else {
        fatalError("Cannot construct image context")
    }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    drawIcon(in: NSRect(x: 0, y: 0, width: width, height: height))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bmp.representation(using: .png, properties: [:]) else {
        fatalError("Cannot encode PNG")
    }
    let dest = URL(fileURLWithPath: file)
    try FileManager.default.createDirectory(
        at: dest.deletingLastPathComponent(), withIntermediateDirectories: true
    )
    try data.write(to: dest)
}

do {
    let catalog = "Resources/Assets.xcassets/AppIcon.appiconset"
    for name in ["AppIcon1024.png", "AppIconDark1024.png", "AppIconDark1024 1.png"] {
        try save("\(catalog)/\(name)", width: 1024, height: 1024)
    }
    try save("Resources/Branding/AppIcon60x60@2x.png", width: 120, height: 120)
    try save("Resources/Branding/AppIcon76x76@2x~ipad.png", width: 152, height: 152)
    try save("Resources/Branding/BloomBox1024.png", width: 1024, height: 1024)
    print("Generated BloomBox original blooming-flower and box icon (1024px, 120px, 152px).")
} catch {
    fputs("BloomBox icon generation failed: \(error)\n", stderr)
    exit(1)
}
