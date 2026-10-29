// Turns build/promo/frames/f_####.png (from promo_render_test.dart) into
// build/promo/oberta_short_pov.mp4: H.264 1080×1920 at 60 fps, with the
// music and the hits mixed in AAC. No narrator: subtitles only.
// Only AVFoundation:
//   swift tool/promo/encode.swift
// The cue times follow the edit in promo_render_test.dart (136.4 bpm).
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let fps: Int32 = 60
let beat = 60.0 / 136.4
func B(_ n: Double) -> Double { n * beat }
let length = B(65)
// PREVIEW=1: a light 720×1280 copy (avconvert's 720p preset fits a vertical
// video in 404×720, too small to judge on a phone).
let preview = ProcessInfo.processInfo.environment["PREVIEW"] != nil
let width = preview ? 720 : 1080, height = preview ? 1280 : 1920
let framesDir = "build/promo/frames"
let output = URL(fileURLWithPath: preview ? "build/promo/oberta_short_pov_720p.mp4" : "build/promo/oberta_short_pov.mp4")

// ── the sound: (file, at seconds, volume, max length) ────────────────────
struct Cue { let file: String; let at: Double; let volume: Float; var max: Double = 99 }
let sounds = "assets/sounds/", sfx = "assets/sfx/", meme = "assets/meme/"
let voteSounds = ["chips_1.wav", "chips_2.wav", "chips_3.wav", "chips_1.wav", "chips_2.wav", "chips_3.wav"]
var cues: [Cue] = [
  // 1 · POV: the hit on «MAFIOSO.»
  Cue(file: sounds + "punch.wav", at: B(2.6), volume: 1.0),
  // 2 · the table: a whoosh in, a tap for every bubble
  Cue(file: sfx + "fx_swish_1.m4a", at: B(6) - 0.06, volume: 0.55, max: 0.5),
  Cue(file: sounds + "pizzi_07.wav", at: B(7.5), volume: 0.7),
  Cue(file: sounds + "pizzi_07.wav", at: B(9), volume: 0.7),
  Cue(file: sounds + "pizzi_07.wav", at: B(10.5), volume: 0.7),
  // 3 · the votes: one tick per vote, then the stamp
  Cue(file: sfx + "fx_swish_2.m4a", at: B(13) - 0.06, volume: 0.45, max: 0.5),
]
for i in 0..<6 {
  cues.append(Cue(file: sounds + voteSounds[i], at: B(16 + Double(i)), volume: 0.6 + Float(i) * 0.06))
}
cues += [
  Cue(file: sfx + "fx_impact_2.m4a", at: B(22), volume: 0.9, max: 0.9),
  // 4 · lynched: the gavel on the word, faaah on the push, the splash
  Cue(file: sfx + "fx_gavel_1.m4a", at: B(26), volume: 0.8, max: 0.8),
  Cue(file: meme + "faaah.m4a", at: 13.05, volume: 0.9, max: 1.45),
  Cue(file: sfx + "fx_splash_1.m4a", at: 14.0, volume: 0.55, max: 0.5),
  // 5 · a third of a second of black, on a low hit; the card turns, vine boom
  Cue(file: sounds + "body_fall.wav", at: B(33), volume: 0.9),
  Cue(file: sfx + "fx_heartbeat_1.m4a", at: B(33) + 0.02, volume: 0.6, max: 0.35),
  Cue(file: sfx + "fx_swish_3.m4a", at: B(33.75) - 0.04, volume: 0.5, max: 0.5),
  Cue(file: sounds + "flip.wav", at: B(34.2), volume: 0.9),
  Cue(file: meme + "vine_boom.m4a", at: B(35), volume: 1.0),
  // 6 · the payoff: the zoom hit on the last word
  Cue(file: sounds + "punch_2.wav", at: B(44), volume: 0.8),
  Cue(file: meme + "hee_hee.m4a", at: B(44) + 0.12, volume: 0.75, max: 0.9),
  // 7 · the wardrobe: the till on the first outfit, a swish on each next one
  Cue(file: sfx + "fx_cashreg_1.m4a", at: B(48), volume: 0.55, max: 0.8),
]
for i in 49..<56 {
  cues.append(Cue(file: sfx + "fx_swish_\((i % 4) + 1).m4a", at: B(Double(i)) - 0.05, volume: 0.32, max: 0.35))
}
cues += [
  // 8 · the neon: the strike, and the short before the loop
  Cue(file: sfx + "fx_bulb_1.m4a", at: B(56) + 0.05, volume: 0.5, max: 0.8),
  Cue(file: sfx + "fx_spark_1.m4a", at: length - 0.32, volume: 0.6, max: 0.3),
]
// The music sits under the meme hits, and drops out for the beat of black.
let music = "assets/music/day.m4a"
let musicFrom = 49.92 // the fullest stretch, starting on a beat
let musicLevel: Float = 0.8
let duckLevel: Float = 0.38
let ducks: [(Double, Double)] = [(13.0, B(33))] // faaah, then straight into the silence
let silence = (B(33), B(33.75)) // the black pause → back with the card
let boom = (B(35), B(35) + 1.0)
let hee = (B(44), B(44) + 0.9)

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
func ramp(_ from: Float, _ to: Float, _ at: Double, _ d: Double) {
  musicParams.setVolumeRamp(fromStartVolume: from, toEndVolume: to, timeRange: CMTimeRange(start: time(at), duration: time(d)))
}
for (a, _) in ducks { ramp(musicLevel, duckLevel, a - 0.12, 0.12) }
ramp(duckLevel, 0, silence.0 - 0.08, 0.08)
ramp(0, musicLevel, silence.1, 0.03)
ramp(musicLevel, duckLevel, boom.0 - 0.05, 0.05)
ramp(duckLevel, musicLevel, boom.1, 0.25)
ramp(musicLevel, duckLevel, hee.0, 0.08)
ramp(duckLevel, musicLevel, hee.1, 0.25)
ramp(musicLevel, 0, length - 0.7, 0.7)
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
    AVVideoAverageBitRateKey: preview ? 5_000_000 : 16_000_000,
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
guard frames.count == Int((length * Double(fps)).rounded()) else { fatalError("expected \(Int((length * Double(fps)).rounded())) frames, found \(frames.count)") }
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
  ctx.interpolationQuality = .high
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
