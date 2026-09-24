import SwiftUI

enum Phase {
    case focus, shortBreak, longBreak

    var label: String {
        switch self {
        case .focus: "Focus"
        case .shortBreak: "Short Break"
        case .longBreak: "Long Break"
        }
    }

    var symbol: String { self == .focus ? "timer" : "cup.and.heat.waves" }
}

@MainActor @Observable
final class Pomodoro {
    private static let defaults = UserDefaults.standard

    var focusMinutes = defaults.object(forKey: "focusMinutes") as? Int ?? 25 {
        didSet { Self.defaults.set(focusMinutes, forKey: "focusMinutes"); syncIdle() }
    }
    var shortBreakMinutes = defaults.object(forKey: "shortBreakMinutes") as? Int ?? 5 {
        didSet { Self.defaults.set(shortBreakMinutes, forKey: "shortBreakMinutes"); syncIdle() }
    }
    var longBreakMinutes = defaults.object(forKey: "longBreakMinutes") as? Int ?? 15 {
        didSet { Self.defaults.set(longBreakMinutes, forKey: "longBreakMinutes"); syncIdle() }
    }
    var longBreakInterval = defaults.object(forKey: "longBreakInterval") as? Int ?? 4 {
        didSet { Self.defaults.set(longBreakInterval, forKey: "longBreakInterval") }
    }
    var sound = Sound(rawValue: defaults.string(forKey: "sound") ?? "") ?? .bell {
        didSet { Self.defaults.set(sound.rawValue, forKey: "sound") }
    }
    var autoStart = defaults.bool(forKey: "autoStart") {
        didSet { Self.defaults.set(autoStart, forKey: "autoStart") }
    }

    private(set) var phase = Phase.focus
    private(set) var completedFocus = 0
    // Store the end time rather than counting ticks, so sleep/wake doesn't drift it.
    private(set) var endDate: Date?
    private var pausedRemaining: TimeInterval = 0
    private var now = Date()
    let player = SoundPlayer()

    var isRunning: Bool { endDate != nil }
    var remaining: TimeInterval { endDate.map { max(0, $0.timeIntervalSince(now)) } ?? pausedRemaining }
    var progress: Double { 1 - remaining / duration(phase) }
    // Focus sessions done so far in this long-break cycle.
    var cycleProgress: Int { completedFocus % longBreakInterval }

    var timeString: String {
        let s = Int(remaining.rounded(.up))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }

    init() {
        pausedRemaining = duration(.focus)
        let timer = Timer(timeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated { self.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
    }

    func duration(_ p: Phase) -> TimeInterval {
        switch p {
        case .focus: Double(focusMinutes * 60)
        case .shortBreak: Double(shortBreakMinutes * 60)
        case .longBreak: Double(longBreakMinutes * 60)
        }
    }

    func toggle() {
        if let endDate {
            pausedRemaining = max(0, endDate.timeIntervalSinceNow)
            self.endDate = nil
        } else {
            now = Date()
            endDate = now + pausedRemaining
        }
    }

    // Full reset: back to focus, session count to zero.
    func reset() {
        endDate = nil
        phase = .focus
        completedFocus = 0
        pausedRemaining = duration(.focus)
    }

    func skip() { advance(playSound: false) }

    private func tick() {
        guard let endDate else { return }
        now = Date()
        if now >= endDate { advance(playSound: true) }
    }

    private func advance(playSound: Bool) {
        let wasRunning = isRunning
        if phase == .focus {
            completedFocus += 1
            phase = completedFocus % longBreakInterval == 0 ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }
        endDate = nil
        pausedRemaining = duration(phase)
        if autoStart && (playSound || wasRunning) { toggle() }
        // Play last. If audio hiccups the timer state is already moved on.
        if playSound { player.play(sound) }
    }

    private func syncIdle() {
        if !isRunning { pausedRemaining = duration(phase) }
    }
}
