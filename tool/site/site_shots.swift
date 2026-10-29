// Screenshots of the landing page in a real WebKit view, plus a scroll smoothness probe.
// Nothing to install: macOS WebKit through Swift.
//
//   swift tool/site/site_shots.swift <page.html> <out-dir> [WIDTHxHEIGHT ...]
//
// For every size it saves the first screen (<w>x<h>_0.png) and then one screen per
// viewport height down the page (_1, _2, ...), and prints a scroll probe: the page is
// scrolled at a steady speed while requestAnimationFrame records the frame times, so
// dropped frames and long gaps (> 50 ms) show up. Widths under 600 get an iPhone UA.
import AppKit
import WebKit

let args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 2 else {
  FileHandle.standardError.write("usage: site_shots.swift <page.html> <out-dir> [WxH ...]\n".data(using: .utf8)!)
  exit(1)
}
let page = URL(fileURLWithPath: args[0]).standardizedFileURL
let outDir = URL(fileURLWithPath: args[1], isDirectory: true)
let sizes: [CGSize] = (args.count > 2 ? Array(args[2...]) : ["1440x900", "1920x1080", "390x844"]).map {
  let p = $0.split(separator: "x").compactMap { Double($0) }
  return CGSize(width: p[0], height: p[1])
}
let maxScreens = Int(ProcessInfo.processInfo.environment["SCREENS"] ?? "12") ?? 12
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

final class Shooter: NSObject, WKNavigationDelegate {
  var loaded: CheckedContinuation<Void, Never>?
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) { done() }
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { print("load failed: \(error)"); done() }
  func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { print("load failed: \(error)"); done() }
  func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { print("web content process terminated"); done() }
  func done() { loaded?.resume(); loaded = nil }
}

@MainActor
func pause(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1e9)) }

@MainActor
func save(_ view: WKWebView, _ name: String) async {
  let config = WKSnapshotConfiguration()
  config.afterScreenUpdates = true
  guard let image = try? await view.takeSnapshot(configuration: config),
        let tiff = image.tiffRepresentation,
        let rep = NSBitmapImageRep(data: tiff),
        let png = rep.representation(using: .png, properties: [:]) else { print("snapshot failed: \(name)"); return }
  try? png.write(to: outDir.appendingPathComponent(name))
  print("saved \(outDir.appendingPathComponent(name).path)")
}

let probe = """
new Promise((resolve) => {
  const el = document.scrollingElement, total = el.scrollHeight - innerHeight;
  const speed = 1800; // px per second, a brisk flick
  const frames = []; let start = null, last = null, maxPlaying = 0;
  const playing = () => [...document.querySelectorAll('video')].filter((v) => !v.paused).length;
  const step = (t) => {
    if (start === null) { start = t; last = t; }
    frames.push(t - last); last = t;
    maxPlaying = Math.max(maxPlaying, playing());
    const y = Math.min(total, (t - start) / 1000 * speed);
    el.scrollTop = y;
    if (y < total) requestAnimationFrame(step); else {
      frames.shift();
      const sum = frames.reduce((a, b) => a + b, 0);
      resolve(JSON.stringify({
        seconds: +(sum / 1000).toFixed(2), frames: frames.length,
        fps: +(frames.length / (sum / 1000)).toFixed(1),
        over20ms: frames.filter((f) => f > 20).length,
        over50ms: frames.filter((f) => f > 50).length,
        worstMs: +Math.max(...frames).toFixed(1),
        maxVideosPlayingAtOnce: maxPlaying,
        videosLoaded: [...document.querySelectorAll('video')].filter((v) => v.currentSrc).map((v) => v.currentSrc.split('/').pop()),
      }));
      el.scrollTop = 0;
    }
  };
  requestAnimationFrame(step);
})
"""

@MainActor
func run() async {
  let shooter = Shooter()
  for size in sizes {
    let config = WKWebViewConfiguration()
    config.mediaTypesRequiringUserActionForPlayback = []
    let view = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
    view.navigationDelegate = shooter
    // The window sits off screen; without this WebKit treats it as hidden and stops
    // animations, requestAnimationFrame and video.
    let occlusion = NSSelectorFromString("_setWindowOcclusionDetectionEnabled:")
    if view.responds(to: occlusion) {
      typealias Setter = @convention(c) (AnyObject, Selector, Bool) -> Void
      unsafeBitCast(view.method(for: occlusion), to: Setter.self)(view, occlusion, false)
    }
    if size.width < 600 {
      view.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
    }
    let window = NSWindow(contentRect: CGRect(x: -20000, y: 0, width: size.width, height: size.height),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = view
    window.orderFront(nil)
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
      shooter.loaded = c
      DispatchQueue.main.asyncAfter(deadline: .now() + 20) { if shooter.loaded != nil { print("load timed out"); shooter.done() } }
      view.loadFileURL(page, allowingReadAccessTo: page.deletingLastPathComponent())
    }
    await pause(3.5)
    let tag = "\(Int(size.width))x\(Int(size.height))"
    await save(view, "\(tag)_0.png")
    let height = (try? await view.evaluateJavaScript("document.scrollingElement.scrollHeight") as? Double) ?? size.height
    let screens = min(maxScreens, Int((height / size.height).rounded(.up)))
    if screens > 1 {
      for i in 1..<screens {
        _ = try? await view.evaluateJavaScript("window.scrollTo(0, \(Double(i) * size.height))")
        await pause(1.6)
        await save(view, "\(tag)_\(i).png")
      }
      _ = try? await view.evaluateJavaScript("window.scrollTo(0, 0)")
      await pause(1.0)
    }
    if let result = try? await view.callAsyncJavaScript("return await \(probe)", contentWorld: .page) {
      print("\(tag) page \(Int(height)) px, scroll probe: \(result)")
    }
    window.orderOut(nil)
  }
}

setvbuf(stdout, nil, _IOLBF, 0)
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
Task { @MainActor in
  await run()
  exit(0)
}
app.run()
