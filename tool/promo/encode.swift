// Turns build/promo/frames/f_####.png (from promo_render_test.dart) into
// build/promo/oberta_short_15s.mp4: H.264 1080×1920 at 60 fps, with the
// music, the narrator and the hits mixed in AAC. Only AVFoundation:
//   swift tool/promo/encode.swift
// The cue times follow the edit in promo_render_test.dart (136.4 bpm).
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let fps: Int32 = 60
let length = 15.0
let width = 1080, height = 1920
let framesDir = "build/promo/frames"
let output = URL(fileURLWithPath: "build/promo/oberta_short_15s.mp4")
let beat = 60.0 / 136.4
func B(_ n: Double) -> Double { n * beat }

// ── the sound: (file, at seconds, volume, max length) ────────────────────
struct Cue { let file: String; let at: Double; let volume: Float; var max: Double = 99 }
let voice = "assets/voice/it/"
let cues: [Cue] = [
  Cue(file: "assets/sounds/punch.wav", at: B(2), volume: 1.0),
  Cue(file: "assets/sfx/fx_swish_1.m4a", at: B(4) - 0.06, volume: 0.6),
  Cue(file: voice + "27a0a00222e3ccdc.m4a", at: 1.95, volume: 1.0), // «Quando cala la notte»
  Cue(file: "assets/sfx/fx_impact_1.m4a", at: B(6), volume: 0.45),
  Cue(file: voice + "871b23e163499753.m4a", at: B(8) + 0.08, volume: 1.0), // «Tu! Dov'eri stanotte?»
  Cue(file: "assets/sfx/fx_gavel_1.m4a", at: B(14), volume: 0.8),
  Cue(file: "assets/meme/faaah.m4a", at: B(15) + 0.15, volume: 0.85, max: 1.55),
  Cue(file: "assets/sfx/fx_splash_1.m4a", at: B(17.6), volume: 0.35, max: 0.7),
  Cue(file: "assets/meme/vine_boom.m4a", at: B(19), volume: 1.0),
  Cue(file: voice + "8f3fc9e46c9b87b3.m4a", at: B(19) + 0.55, volume: 1.0), // «Il Picciotto»
  Cue(file: "assets/sfx/fx_cashreg_1.m4a", at: B(22), volume: 0.55, max: 0.8),
  Cue(file: "assets/meme/hee_hee.m4a", at: B(24), volume: 0.7, max: 0.9),
  Cue(file: "assets/sfx/fx_whoosh_1.m4a", at: B(26) - 0.1, volume: 0.35, max: 0.5),
  Cue(file: "assets/sounds/wood_heavy.wav", at: B(27), volume: 0.75),
  Cue(file: "assets/sounds/wood_heavy_2.wav", at: B(28), volume: 0.75),
  Cue(file: "assets/sounds/wood_heavy.wav", at: B(29), volume: 0.75),
  Cue(file: "assets/sfx/fx_bulb_1.m4a", at: B(30) + 0.05, volume: 0.5, max: 0.8),
  Cue(file: "assets/sfx/fx_spark_1.m4a", at: length - 0.30, volume: 0.6, max: 0.3),
]
// The music sits under the voice and the meme hits.
let music = "assets/music/day.m4a"
let musicFrom = 49.92 // the fullest stretch, starting on a beat
let musicLevel: Float = 0.8
let ducks: [(Double, Double)] = [(1.9, 5.2), (B(15) + 0.1, B(19) + 1.7), (B(24), B(24) + 0.9)]
let duckLevel: Float = 0.38

func time(_ s: Double) -> CMTime { CMTime(seconds: s, preferredTimescale: 48000) }

let composition = AVMutableComposition()
let mix = AVMutableAudioMix()
var params: [AVMutableAudioMixInputParameters] = []

func add(_ path: String, at: Double, from: Double = 0, duration: Double) async throws -> AVMutableCompositionTrack {
  let asset = AVURLAsset(url: URL(fileURLWithPath: path))
  guard let source = try await asset.loadTracks(withMediaType: .audio).first else { fatalError("no audio in \(path)") }
  let full = try await asset.load(.duration).seconds
  let take = min(duration, full - from, length - at)
  let track = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)!
  try track.insertTimeRange(CMTimeRange(start: time(from), duration: time(take)), of: source, at: time(at))
  return track
}

let musicTrack = try await add(music, at: 0, from: musicFrom, duration: length)
let musicParams = AVMutableAudioMixInputParameters(track: musicTrack)
musicParams.setVolume(musicLevel, at: .zero)
let ramp = 0.12
for (a, b) in ducks {
  musicParams.setVolumeRamp(fromStartVolume: musicLevel, toEndVolume: duckLevel, timeRange: CMTimeRange(start: time(a - ramp), duration: time(ramp)))
  musicParams.setVolumeRamp(fromStartVolume: duckLevel, toEndVolume: musicLevel, timeRange: CMTimeRange(start: time(b), duration: time(ramp * 2)))
}
musicParams.setVolumeRamp(fromStartVolume: musicLevel, toEndVolume: 0, timeRange: CMTimeRange(start: time(length - 0.7), duration: time(0.7)))
params.append(musicParams)

for cue in cues {
  let track = try await add(cue.file, at: cue.at, duration: cue.max)
  let p = AVMutableAudioMixInputParameters(track: track)
  p.setVolume(cue.volume, at: .zero)
  if cue.max < 99 {
    // A short tail instead of a hard stop.
    let end = min(cue.at + cue.max, length)
    p.setVolumeRamp(fromStartVolume: cue.volume, toEndVolume: 0, timeRange: CMTimeRange(start: time(end - 0.15), duration: time(0.15)))
  }
  params.append(p)
}
mix.inputParameters = params

// ── the writer ───────────────────────────────────────────────────────────
try? FileManager.default.removeItem(at: output)
let writer = try AVAssetWriter(outputURL: output, fileType: .mp4)
let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
  AVVideoCodecKey: AVVideoCodecType.h264,
  AVVideoWidthKey: width,
  AVVideoHeightKey: height,
  AVVideoCompressionPropertiesKey: [
    AVVideoAverageBitRateKey: 16_000_000,
    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
    AVVideoExpectedSourceFrameRateKey: fps,
    AVVideoMaxKeyFrameIntervalKey: fps,
  ] as [String: Any],
  AVVideoColorPropertiesKey: [
    AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2,
    AVVideoTransferFunctionKey: AVVideoTransferFunction_ITU_R_709_2,
    AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2,
  ],
])
videoInput.expectsMediaDataInRealTime = false
let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoInput, sourcePixelBufferAttributes: [
  kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
  kCVPixelBufferWidthKey as String: width,
  kCVPixelBufferHeightKey as String: height,
])
let audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
  AVFormatIDKey: kAudioFormatMPEG4AAC,
  AVSampleRateKey: 48000,
  AVNumberOfChannelsKey: 2,
  AVEncoderBitRateKey: 192_000,
])
audioInput.expectsMediaDataInRealTime = false
writer.add(videoInput)
writer.add(audioInput)

let reader = try AVAssetReader(asset: composition)
reader.timeRange = CMTimeRange(start: .zero, duration: time(length))
let audioTracks = try await composition.loadTracks(withMediaType: .audio)
let mixOutput = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [
  AVFormatIDKey: kAudioFormatLinearPCM,
  AVSampleRateKey: 48000,
  AVNumberOfChannelsKey: 2,
  AVLinearPCMBitDepthKey: 16,
  AVLinearPCMIsFloatKey: false,
  AVLinearPCMIsBigEndianKey: false,
  AVLinearPCMIsNonInterleaved: false,
])
mixOutput.audioMix = mix
reader.add(mixOutput)
guard reader.startReading() else { fatalError("reader: \(String(describing: reader.error))") }

writer.startWriting()
writer.startSession(atSourceTime: .zero)

let frames = (try FileManager.default.contentsOfDirectory(atPath: framesDir)).filter { $0.hasSuffix(".png") }.sorted()
guard frames.count == Int(length * Double(fps)) else { fatalError("expected \(Int(length * Double(fps))) frames, found \(frames.count)") }
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func pixelBuffer(_ path: String) -> CVPixelBuffer {
  let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil)!
  let image = CGImageSourceCreateImageAtIndex(src, 0, nil)!
  var buffer: CVPixelBuffer?
  CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer)
  let pb = buffer!
  CVPixelBufferLockBaseAddress(pb, [])
  let ctx = CGContext(
    data: CVPixelBufferGetBaseAddress(pb), width: width, height: height, bitsPerComponent: 8,
    bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: space,
    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
  ctx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
  CVPixelBufferUnlockBaseAddress(pb, [])
  return pb
}

let group = DispatchGroup()
group.enter()
var next = 0
videoInput.requestMediaDataWhenReady(on: DispatchQueue(label: "video")) {
  while videoInput.isReadyForMoreMediaData {
    if next >= frames.count {
      videoInput.markAsFinished()
      group.leave()
      return
    }
    let pb = pixelBuffer("\(framesDir)/\(frames[next])")
    adaptor.append(pb, withPresentationTime: CMTime(value: CMTimeValue(next), timescale: fps))
    next += 1
  }
}
group.enter()
audioInput.requestMediaDataWhenReady(on: DispatchQueue(label: "audio")) {
  while audioInput.isReadyForMoreMediaData {
    if let sample = mixOutput.copyNextSampleBuffer() {
      audioInput.append(sample)
    } else {
      audioInput.markAsFinished()
      group.leave()
      return
    }
  }
}
group.wait()
await writer.finishWriting()
guard writer.status == .completed else { fatalError("writer: \(String(describing: writer.error))") }

let made = AVURLAsset(url: output)
let duration = try await made.load(.duration).seconds
let size = (try FileManager.default.attributesOfItem(atPath: output.path)[.size] as? Int) ?? 0
print(String(format: "%@  %.2f s  %.1f MB", output.path, duration, Double(size) / 1_048_576))
