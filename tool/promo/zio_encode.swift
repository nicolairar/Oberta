// Turns build/promo/zio_frames/f_####.png (from zio_render_test.dart) into
// build/promo/oberta_short_zio.mp4: H.264 1080×1920 at 60 fps, with the
// music and the hits mixed in AAC, under 30 MB so it travels by chat.
// No narrator: subtitles only. Only AVFoundation:
//   swift tool/promo/zio_encode.swift
// The cue times follow the edit in zio_scenes.dart (day_2.m4a, 139.5 bpm).
import AVFoundation
import CoreGraphics
import Foundation
import ImageIO

let fps: Int32 = 60
let beat = 60.0 / 139.5
func B(_ n: Double) -> Double { n * beat }
let length = B(104)
// PREVIEW=1: a light 720×1280 copy for phones.
let preview = ProcessInfo.processInfo.environment["PREVIEW"] != nil
let width = preview ? 720 : 1080, height = preview ? 1280 : 1920
let framesDir = "build/promo/zio_frames"
let output = URL(fileURLWithPath: preview ? "build/promo/oberta_short_zio_720p.mp4" : "build/promo/oberta_short_zio.mp4")

// ── the sound: (file, at seconds, volume, max length) ────────────────────
// The pier film (zio_scenes.dart `film`) reaches the push at 0.66 here.
let faaah = 31.98
struct Cue { let file: String; let at: Double; let volume: Float; var max: Double = 99 }
let sounds = "assets/sounds/", sfx = "assets/sfx/", meme = "assets/meme/"
func swish(_ n: Int, _ at: Double, _ v: Float = 0.45) -> Cue { Cue(file: sfx + "fx_swish_\(n).m4a", at: at - 0.06, volume: v, max: 0.45) }
var cues: [Cue] = [
  // 1 · the hook: the hit on «FAMIGLIA.»
  Cue(file: sounds + "punch.wav", at: B(2), volume: 1.0),
  // 2 · football: a stadium cheer, low
  swish(1, B(6)),
  Cue(file: sfx + "fx_cheer_1.m4a", at: B(6.1), volume: 0.35, max: 1.9),
  // 3 · Obertà: the strike, the hit
  Cue(file: sfx + "fx_bulb_1.m4a", at: B(11), volume: 0.6, max: 0.8),
  Cue(file: sounds + "punch_2.wav", at: B(11.5), volume: 0.9),
  // 4 · Vito, «SBAGLIATA.»
  swish(2, B(15)),
  Cue(file: sfx + "fx_cigar_1.m4a", at: B(15.3), volume: 0.45, max: 1.2),
  Cue(file: sfx + "fx_impact_2.m4a", at: B(19), volume: 0.8, max: 0.9),
  // 5 · the pick on Nonna
  swish(3, B(22)),
  Cue(file: sounds + "ui_confirm.wav", at: B(25.2) - 0.05, volume: 0.8),
  Cue(file: sfx + "fx_gasp_1.m4a", at: B(25.2), volume: 0.6, max: 0.8),
  // 6 · the Doctor: the dawn line, the save
  swish(4, B(29)),
  Cue(file: sfx + "fx_syringe_1.m4a", at: B(30), volume: 0.6, max: 0.8),
  Cue(file: sfx + "fx_tada_1.m4a", at: B(31), volume: 0.45, max: 1.0),
  // 7 · the second night
  swish(1, B(34)),
  Cue(file: sfx + "fx_owl_1.m4a", at: B(34.3), volume: 0.4, max: 1.2),
  // 8 · the Prostituta: hee hee, a kiss
  swish(2, B(39)),
  Cue(file: meme + "hee_hee.m4a", at: B(40), volume: 0.85, max: 0.93),
  Cue(file: sfx + "fx_kiss_1.m4a", at: B(40.6), volume: 0.6, max: 0.6),
  // 9 · the cell: the bars, two bubbles, the church bells
  swish(3, B(43)),
  Cue(file: sounds + "metal_heavy.wav", at: B(44.5), volume: 0.9),
  Cue(file: sfx + "fx_chain_1.m4a", at: B(44.55), volume: 0.5, max: 0.8),
  Cue(file: sounds + "pizzi_07.wav", at: B(47), volume: 0.7),
  Cue(file: sounds + "pizzi_07.wav", at: B(50), volume: 0.7),
  Cue(file: sfx + "fx_church_1.m4a", at: B(50.1), volume: 0.5, max: 1.6),
  // 10 · he shouted: the push-to-talk, a shout
  swish(4, B(53)),
  Cue(file: sounds + "ui_toggle.wav", at: B(53.35), volume: 0.7),
  Cue(file: sfx + "fx_scream_1.m4a", at: B(53.6), volume: 0.4, max: 0.9),
  // 11 · nobody believed me: a tap per bubble
  swish(1, B(58)),
  Cue(file: sounds + "pizzi_07.wav", at: B(59), volume: 0.7),
  Cue(file: sounds + "pizzi_07.wav", at: B(60.5), volume: 0.7),
  // 12 · the votes: a chip per vote, then the stamp
  swish(2, B(63)),
]
let voteSounds = ["chips_1.wav", "chips_2.wav", "chips_3.wav", "chips_1.wav", "chips_2.wav", "chips_3.wav"]
for i in 0..<6 {
  cues.append(Cue(file: sounds + voteSounds[i], at: B(63.75 + Double(i)), volume: 0.6 + Float(i) * 0.06))
}
cues += [
  Cue(file: sfx + "fx_gavel_1.m4a", at: B(69.25), volume: 0.85, max: 0.8),
  // 13 · the river: faaah on the push, the splash (times printed by the render)
  swish(3, B(70)),
  Cue(file: meme + "faaah.m4a", at: faaah, volume: 0.9, max: 1.2),
  Cue(file: sfx + "fx_splash_1.m4a", at: 32.68, volume: 0.6, max: 0.6),
  // 14 · straight into the card: swish, flip, vine boom
  swish(4, B(77), 0.55),
  Cue(file: sounds + "flip.wav", at: B(77.9), volume: 0.9),
  Cue(file: meme + "vine_boom.m4a", at: B(78.5), volume: 1.0),
  // 15 · worth it
  Cue(file: sounds + "punch_2.wav", at: B(86), volume: 0.8),
  // 16 · the wardrobe: the till, a swish per outfit
  Cue(file: sfx + "fx_cashreg_1.m4a", at: B(88), volume: 0.55, max: 0.8),
]
for i in 89..<95 {
  cues.append(Cue(file: sfx + "fx_swish_\((i % 4) + 1).m4a", at: B(Double(i)) - 0.05, volume: 0.32, max: 0.35))
}
// 17 · the neon (neon_end.dart): the strike, the B buzzing out while the
// ghost M stutters (OMERTÀ), the B back, the short before the loop.
let endAt = B(95)
cues += [
  Cue(file: sfx + "fx_bulb_1.m4a", at: endAt + 0.05, volume: 0.5, max: 0.8),
  Cue(file: sfx + "fx_spark_2.m4a", at: endAt + 0.8, volume: 0.35, max: 0.5),
  Cue(file: sfx + "fx_spark_3.m4a", at: endAt + 1.55, volume: 0.3, max: 0.4),
  Cue(file: sfx + "fx_bulb_2.m4a", at: endAt + 2.45, volume: 0.4, max: 0.6),
  Cue(file: sfx + "fx_spark_1.m4a", at: length - 0.32, volume: 0.6, max: 0.3),
]
let music = "assets/music/day_2.m4a"
let musicFrom = 0.14 + 46 * beat // a beat, in the full stretch
let musicLevel: Float = 0.8
let duckLevel: Float = 0.38
// The music sits under the meme hits.
let ducks: [(Double, Double)] = [(B(40), B(40) + 0.95), (faaah, faaah + 1.2), (B(78.5), B(78.5) + 1.0)]
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
for (a, b) in ducks {
  ramp(musicLevel, duckLevel, a - 0.06, 0.06)
  ramp(duckLevel, musicLevel, b, 0.25)
}
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
    AVVideoAverageBitRateKey: preview ? 3_000_000 : 4_700_000,
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
