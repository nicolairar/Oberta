// Rasterises the landing site's official store badges (site/oberta/img/badges)
// into build/promo/badges/*.png at a size the promo can use, unmodified:
// the SVGs are drawn as vectors by AppKit, the Steam PNG is copied.
//   swift tool/promo/badges.swift
import AppKit

let src = "site/oberta/img/badges"
let out = "build/promo/badges"
try FileManager.default.createDirectory(atPath: out, withIntermediateDirectories: true)

func rasterise(_ name: String, height: CGFloat) throws {
  guard let image = NSImage(contentsOfFile: "\(src)/\(name).svg") else { fatalError("cannot read \(name).svg") }
  let size = image.size
  let w = Int((size.width / size.height * height).rounded()), h = Int(height)
  let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8, samplesPerPixel: 4,
                             hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
  image.draw(in: NSRect(x: 0, y: 0, width: w, height: h))
  NSGraphicsContext.restoreGraphicsState()
  try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name).png"))
  print("\(name).png \(w)×\(h)")
}

try rasterise("app-store-it", height: 240)
try rasterise("google-play-it", height: 240)
try? FileManager.default.removeItem(atPath: "\(out)/steam-logo-white.png")
try FileManager.default.copyItem(atPath: "\(src)/steam-logo-white.png", toPath: "\(out)/steam-logo-white.png")
