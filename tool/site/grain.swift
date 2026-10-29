// The film grain tile of the landing page: 96x96 grey noise with a soft alpha, as PNG.
// Static and tiny on purpose: it is tiled under the section backgrounds, never animated.
//
//   swift tool/site/grain.swift <out.png>
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "grain.png")
let size = 96
var rng = SystemRandomNumberGenerator()
var pixels = [UInt8](repeating: 0, count: size * size * 4)
for i in 0..<(size * size) {
  // Two dice for a softer, roughly bell-shaped grain.
  let v = (Int.random(in: 0...255, using: &rng) + Int.random(in: 0...255, using: &rng)) / 2
  // Faint on purpose (at most ~9% opacity): it sits straight in the backgrounds, no extra layer.
  let alpha = UInt8(min(255, abs(v - 128) * 2) * 24 / 255)
  let c = v > 128 ? alpha : 0 // premultiplied: white specks and black specks
  pixels[i * 4] = c; pixels[i * 4 + 1] = c; pixels[i * 4 + 2] = c; pixels[i * 4 + 3] = alpha
}
let ctx = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                    space: CGColorSpace(name: CGColorSpace.sRGB)!,
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
let image = ctx.makeImage()!
let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(dest, image, nil)
CGImageDestinationFinalize(dest)
let bytes = (try? FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
print("\(out.lastPathComponent): \(size)x\(size), \(bytes) bytes")
