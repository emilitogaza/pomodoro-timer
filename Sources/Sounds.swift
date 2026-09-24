import AVFoundation

// Ringtones are synthesized, no audio files. Each one is a few sine/triangle
// notes with an envelope, rendered into a PCM buffer the first time it plays.
enum Sound: String, CaseIterable, Identifiable {
    case bell, brightBell, phoneRing, pulsingAlarm, chime
    var id: Self { self }

    var label: String {
        switch self {
        case .bell: "Bell"
        case .brightBell: "Bright Bell"
        case .phoneRing: "Telephone Ring"
        case .pulsingAlarm: "Pulsing Alarm"
        case .chime: "Chime"
        }
    }

    fileprivate var notes: [Note] {
        switch self {
        case .bell:
            [Note(freq: 880, start: 0, length: 1.8, gain: 0.5),
             Note(freq: 1108, start: 0.08, length: 1.8, gain: 0.25)]
        case .brightBell:
            [1568.0, 1976, 2637].enumerated().map { i, f in
                Note(freq: f, start: Double(i) * 0.05, length: 3, gain: i == 0 ? 0.8 : 0.45, wave: .triangle)
            }
        case .phoneRing:
            (0..<6).flatMap { c in
                [440.0, 480].map { Note(freq: $0, start: Double(c) * 0.6, length: 0.4, gain: 0.35, decays: false) }
            }
        case .pulsingAlarm:
            (0..<20).map { Note(freq: 1000, start: Double($0) * 0.25, length: 0.15, gain: 0.3, wave: .square, decays: false) }
        case .chime:
            // C5 E5 G5 C6, tiny pause, G5 C6
            [523.25, 659.25, 783.99, 1046.5, 783.99, 1046.5].enumerated().map { i, f in
                Note(freq: f, start: Double(i) * 0.18 + (i >= 4 ? 0.12 : 0), length: 1.2, gain: 0.4, wave: .triangle)
            }
        }
    }
}

private struct Note {
    enum Wave { case sine, triangle, square }
    var freq: Double, start: Double, length: Double, gain: Double
    var wave = Wave.sine
    // decays: bells fade out, rings/beeps hold flat with a quick attack/release
    var decays = true
}

@MainActor
final class SoundPlayer {
    private let engine = AVAudioEngine()
    private let node = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var cache: [Sound: AVAudioPCMBuffer] = [:]

    init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
    }

    func play(_ sound: Sound) {
        // If the engine won't start (output device changed etc), bail. node.play()
        // would throw an ObjC exception we can't catch and take the timer down with it.
        if !engine.isRunning { try? engine.start() }
        guard engine.isRunning else { return }
        let buffer = cache[sound] ?? render(sound.notes)
        cache[sound] = buffer
        node.scheduleBuffer(buffer, at: nil, options: .interrupts)
        node.play()
    }

    private func render(_ notes: [Note]) -> AVAudioPCMBuffer {
        let rate = format.sampleRate
        let frames = Int(notes.map { $0.start + $0.length }.max()! * rate)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let out = buffer.floatChannelData![0]
        out.initialize(repeating: 0, count: frames)
        for n in notes {
            let first = Int(n.start * rate)
            for j in 0..<min(Int(n.length * rate), frames - first) {
                let t = Double(j) / rate
                let p = (n.freq * t).truncatingRemainder(dividingBy: 1)
                let wave: Double = switch n.wave {
                case .sine: sin(2 * .pi * p)
                case .triangle: 1 - 4 * abs(p - 0.5)
                case .square: p < 0.5 ? 1 : -1
                }
                let env = n.decays
                    ? n.gain * pow(0.001 / n.gain, t / n.length)
                    : n.gain * min(1, t / 0.01, (n.length - t) / 0.02)
                out[first + j] += Float(wave * env * 0.6)
            }
        }
        for i in 0..<frames { out[i] = max(-1, min(1, out[i])) }
        return buffer
    }
}
