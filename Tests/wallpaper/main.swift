import Foundation
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

let fm = FileManager.default
let temp = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try fm.createDirectory(at: temp, withIntermediateDirectories: true)
defer { try? fm.removeItem(at: temp) }
let gif = temp.appendingPathComponent("sample.gif")
let context = CGContext(data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 32,
                        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let output = CGImageDestinationCreateWithURL(gif as CFURL, UTType.gif.identifier as CFString, 2, nil)!
for (delay, value) in [(0.05, 0.2), (0.2, 0.8)] {
    context.setFillColor(CGColor(gray: value, alpha: 1)); context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
    CGImageDestinationAddImage(output, context.makeImage()!,
        [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: delay]] as CFDictionary)
}
assert(CGImageDestinationFinalize(output))
let frames = try BloomBoxMotionMedia.gifFrames(gif)
assert(frames.0.count == 2)
assert(abs(frames.2 - 0.25) < 0.01)
assert(abs(frames.1[1].doubleValue - 0.2) < 0.01)
let imported = try BloomBoxMotionMedia.importFile(gif)
let owned = BloomBoxMotionMedia.url(imported)!
defer { try? fm.removeItem(at: owned) }
assert(fm.fileExists(atPath: owned.path))
assert(fm.fileExists(atPath: gif.path))
assert(BloomBoxMotionMedia.url("../outside.mov") == nil)
let broken = temp.appendingPathComponent("broken.gif")
try Data("not a gif".utf8).write(to: broken)
do { _ = try BloomBoxMotionMedia.importFile(broken); fatalError("Corrupt GIF accepted") } catch {}
assert(fm.fileExists(atPath: owned.path))
print("GIF import, timing, corruption and persistence checks passed")

let current = temp.appendingPathComponent("BloomBox")
let legacy = temp.appendingPathComponent("LiveBoard")
try fm.createDirectory(at: legacy, withIntermediateDirectories: true)
let previousName = "motion-01234567-89AB-CDEF-0123-456789ABCDEF.gif"
let previous = legacy.appendingPathComponent(previousName)
try fm.copyItem(at: gif, to: previous)
assert(BloomBoxMotionMedia.resolve(previousName, current: current, legacy: legacy) == previous)
try fm.createDirectory(at: current, withIntermediateDirectories: true)
let preferred = current.appendingPathComponent(previousName)
try fm.copyItem(at: gif, to: preferred)
assert(BloomBoxMotionMedia.resolve(previousName, current: current, legacy: legacy) == preferred)
assert(BloomBoxMotionMedia.resolve("motion-../../steal.gif", current: current, legacy: legacy) == nil)
assert(BloomBoxMotionMedia.resolve("motion-evil.exe", current: current, legacy: legacy) == nil)
let unsupported = temp.appendingPathComponent("invalid.txt")
try Data("garbage".utf8).write(to: unsupported)
do { _ = try BloomBoxMotionMedia.importFile(unsupported); fatalError("Accepted invalid format") } catch {}
print("BloomBox motion migration and strict filename checks passed")
