// Web copies of the promo shorts for the landing page, with nothing to install:
// AVFoundation re-encodes the video track only (no audio track at all), scaled
// down, H.264 High profile (CABAC, B-frames) at the given average bitrate, with the
// moov atom up front for streaming.
//
//   swift tool/site/web_video.swift clip <src.mp4> <out.mp4> [--start s] [--duration s] [--width px] [--kbps n] [--fps n]
//   swift tool/site/web_video.swift frame <src.mp4> <out.jpg> [--at s] [--width px] [--quality 0..1]
//
// The height follows the source aspect ratio (rounded to even pixels).
import AVFoundation
import CoreImage
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
  FileHandle.standardError.write((message + "\n").data(using: .utf8)!)
  exit(1)
}

var args = Array(CommandLine.arguments.dropFirst())
guard args.count >= 3 else { fail("usage: web_video.swift clip|frame <src> <out> [options]") }
let mode = args.removeFirst()
let src = URL(fileURLWithPath: args.removeFirst())
let out = URL(fileURLWithPath: args.removeFirst())
var opts: [String: Double] = [:]
while args.count >= 2 {
  let key = args.removeFirst().replacingOccurrences(of: "--", with: "")
  guard let value = Double(args.removeFirst()) else { fail("bad value for --\(key)") }
  opts[key] = value
}

let asset = AVURLAsset(url: src)
let sem = DispatchSemaphore(value: 0)

func even(_ v: Double) -> Int { Int((v / 2).rounded()) * 2 }

func videoTrack() async throws -> AVAssetTrack {
  guard let track = try await asset.loadTracks(withMediaType: .video).first else { fail("no video track") }
  return track
}

func size(of track: AVAssetTrack) async throws -> CGSize {
  let natural = try await track.load(.naturalSize)
  let t = try await track.load(.preferredTransform)
  let r = CGRect(origin: .zero, size: natural).applying(t)
  return CGSize(width: abs(r.width), height: abs(r.height))
}

func clip() async throws {
  let track = try await videoTrack()
  let source = try await size(of: track)
  let width = opts["width"] ?? 540
  let w = even(width), h = even(width * source.height / source.width)
  let duration = try await asset.load(.duration).seconds
  let start = opts["start"] ?? 0
  let length = min(opts["duration"] ?? duration - start, duration - start)
  let fps = opts["fps"] ?? 30
  let range = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600),
                          duration: CMTime(seconds: length, preferredTimescale: 600))

  // Scale (and orient) through a video composition so the reader hands out frames at the web size.
  let composition = AVMutableVideoComposition()
  composition.renderSize = CGSize(width: w, height: h)
  composition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
  let instruction = AVMutableVideoCompositionInstruction()
  instruction.timeRange = CMTimeRange(start: .zero, duration: try await asset.load(.duration))
  let layer = AVMutableVideoCompositionLayerInstruction(assetTrack: track)
  let transform = try await track.load(.preferredTransform)
  let scale = CGFloat(w) / source.width
  layer.setTransform(transform.concatenating(CGAffineTransform(scaleX: scale, y: scale)), at: .zero)
  instruction.layerInstructions = [layer]
  composition.instructions = [instruction]

  let reader = try AVAssetReader(asset: asset)
  reader.timeRange = range
  let output = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [
    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
  ])
  output.videoComposition = composition
  reader.add(output)

  try? FileManager.default.removeItem(at: out)
  let writer = try AVAssetWriter(outputURL: out, fileType: .mp4)
  writer.shouldOptimizeForNetworkUse = true
  let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
    AVVideoCodecKey: AVVideoCodecType.h264,
    AVVideoWidthKey: w,
    AVVideoHeightKey: h,
    AVVideoCompressionPropertiesKey: [
      AVVideoAverageBitRateKey: Int((opts["kbps"] ?? 900) * 1000),
      AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
      AVVideoMaxKeyFrameIntervalKey: Int(fps * 2),
      AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC,
      AVVideoAllowFrameReorderingKey: true,
      AVVideoExpectedSourceFrameRateKey: Int(fps),
    ],
  ])
  input.expectsMediaDataInRealTime = false
  writer.add(input)
  guard reader.startReading() else { fail("reader: \(reader.error?.localizedDescription ?? "?")") }
  writer.startWriting()
  writer.startSession(atSourceTime: range.start)

  let queue = DispatchQueue(label: "encode")
  await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
    input.requestMediaDataWhenReady(on: queue) {
      while input.isReadyForMoreMediaData {
        if let sample = output.copyNextSampleBuffer() {
          input.append(sample)
        } else {
          input.markAsFinished()
          done.resume()
          return
        }
      }
    }
  }
  await writer.finishWriting()
  if writer.status != .completed { fail("writer: \(writer.error?.localizedDescription ?? "?")") }
  let bytes = (try FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
  print("\(out.lastPathComponent): \(w)x\(h), \(String(format: "%.1f", length)) s, \(bytes / 1024) KB")
}

func frame() async throws {
  let generator = AVAssetImageGenerator(asset: asset)
  generator.appliesPreferredTrackTransform = true
  generator.requestedTimeToleranceBefore = .zero
  generator.requestedTimeToleranceAfter = .zero
  let width = opts["width"] ?? 540
  generator.maximumSize = CGSize(width: width, height: width * 4)
  let (image, _) = try await generator.image(at: CMTime(seconds: opts["at"] ?? 0, preferredTimescale: 600))
  guard let dest = CGImageDestinationCreateWithURL(out as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
    fail("cannot write \(out.path)")
  }
  CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: opts["quality"] ?? 0.7] as CFDictionary)
  CGImageDestinationFinalize(dest)
  let bytes = (try FileManager.default.attributesOfItem(atPath: out.path)[.size] as? Int) ?? 0
  print("\(out.lastPathComponent): \(image.width)x\(image.height), \(bytes / 1024) KB")
}

Task {
  do {
    switch mode {
    case "clip": try await clip()
    case "frame": try await frame()
    default: fail("unknown mode \(mode)")
    }
  } catch {
    fail("\(error)")
  }
  sem.signal()
}
sem.wait()
