// Finds the tempo and the loudest 15-second window of a track, so the promo
// cuts land on the beat:
//   swift tool/promo/beats.swift assets/music/day.m4a [window=15]
import AVFoundation
import Foundation

let args = CommandLine.arguments
guard args.count > 1 else { print("usage: beats.swift <file> [window]"); exit(1) }
let window = args.count > 2 ? Double(args[2])! : 15
let file = try AVAudioFile(forReading: URL(fileURLWithPath: args[1]))
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: file.fileFormat.sampleRate, channels: 1, interleaved: false)!
let rate = file.fileFormat.sampleRate
let frames = AVAudioFrameCount(file.length)
let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: frames)!
try file.read(into: buffer)
let channels = Int(buffer.format.channelCount)
let n = Int(buffer.frameLength)
var mono = [Float](repeating: 0, count: n)
for c in 0..<channels {
  let p = buffer.floatChannelData![c]
  for i in 0..<n { mono[i] += p[i] / Float(channels) }
}
_ = format

// Energy every 10 ms, then the positive flux (onsets).
let hop = Int(rate / 100)
var energy: [Float] = []
var i = 0
while i + hop < n {
  var s: Float = 0
  for j in i..<(i + hop) { s += mono[j] * mono[j] }
  energy.append(sqrt(s / Float(hop)))
  i += hop
}
var flux = [Float](repeating: 0, count: energy.count)
for k in 1..<energy.count { flux[k] = max(0, energy[k] - energy[k - 1]) }

func tempo(_ from: Int, _ to: Int) -> (bpm: Double, phase: Double) {
  var best = (score: Float(0), lag: 50)
  for lag in 30...100 { // 60..200 bpm
    var s: Float = 0
    for k in from..<(to - lag) { s += flux[k] * flux[k + lag] }
    if s > best.score { best = (s, lag) }
  }
  // Phase: the offset whose comb sums the most flux.
  var phase = (score: Float(0), off: 0)
  for off in 0..<best.lag {
    var s: Float = 0
    var k = from + off
    while k < to { s += flux[k]; k += best.lag }
    if s > phase.score { phase = (s, off) }
  }
  return (6000 / Double(best.lag), Double(phase.off) / 100)
}

let w = Int(window * 100)
var loud = (score: Float(0), start: 0)
var start = 0
while start + w < energy.count {
  let s = energy[start..<(start + w)].reduce(0, +)
  if s > loud.score { loud = (s, start) }
  start += 50
}
let t = tempo(loud.start, loud.start + w)
let overall = energy.reduce(0, +) / Float(energy.count)
print(String(format: "duration %.1fs  mean %.4f", Double(n) / rate, overall))
print(String(format: "loudest %.0fs window starts at %.2fs (mean %.4f)", window, Double(loud.start) / 100, loud.score / Float(w)))
print(String(format: "tempo there %.1f bpm, first beat at +%.2fs", t.bpm, t.phase))
let t0 = tempo(0, min(w, energy.count - 1))
print(String(format: "tempo at start %.1f bpm, first beat at %.2fs", t0.bpm, t0.phase))
// Energy profile every second over the first 40 s.
var line = ""
for s in 0..<min(40, energy.count / 100) {
  let e = energy[(s * 100)..<(s * 100 + 100)].reduce(0, +) / 100
  line += String(format: "%d:%.3f ", s, e)
}
print(line)
