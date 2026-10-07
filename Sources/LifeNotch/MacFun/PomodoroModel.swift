import SwiftUI

// PomodoroModel.swift
// The focus timer: work for N minutes, short break, repeat, long break every few sessions.
// It works from an END TIME (not by counting ticks), so it stays accurate even if your Mac
// is busy. Durations come from Settings.

final class PomodoroModel: ObservableObject {
    enum Phase: String {
        case focus, shortBreak, longBreak

        var title: String {
            switch self {
            case .focus: return "Focus"
            case .shortBreak: return "Short break"
            case .longBreak: return "Long break"
            }
        }
    }

    @Published var phase: Phase = .focus
    @Published var remaining: TimeInterval
    @Published var isRunning = false
    /// Focus sessions finished since you launched LifeNotch (decides when the long break comes).
    @Published var sessionsThisRun = 0

    private let settings: AppSettings
    private let streak: StreakStore
    private var endDate: Date?
    private var timer: Timer?

    init(settings: AppSettings, streak: StreakStore) {
        self.settings = settings
        self.streak = streak
        remaining = TimeInterval(settings.prefs.workMinutes * 60)
    }

    // MARK: Lengths

    func duration(for phase: Phase) -> TimeInterval {
        let p = settings.prefs
        switch phase {
        case .focus: return TimeInterval(max(1, p.workMinutes) * 60)
        case .shortBreak: return TimeInterval(max(1, p.shortBreakMinutes) * 60)
        case .longBreak: return TimeInterval(max(1, p.longBreakMinutes) * 60)
        }
    }

    var total: TimeInterval { duration(for: phase) }
    var fractionDone: Double { total > 0 ? 1 - remaining / total : 0 }

    /// Running, or paused part-way (so the compact bar keeps showing it).
    var isActive: Bool { isRunning || (remaining > 0 && remaining < total) }

    // MARK: Controls

    func start() {
        if remaining <= 0 { remaining = total }
        endDate = Date().addingTimeInterval(remaining)
        isRunning = true
        if phase == .focus && settings.prefs.completionSounds { SoundPlayer.play(.start) }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in self?.tick() }
    }

    func pause() {
        tick()
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    func toggle() { isRunning ? pause() : start() }

    func reset() {
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
        remaining = total
    }

    /// Jump to the next phase without counting it as a finished session.
    func skip() {
        advance(countSession: false)
    }

    /// Call after changing durations in Settings so an idle timer shows the new length.
    func durationsChanged() {
        if !isRunning && !isActive {
            remaining = total
        }
    }

    // MARK: Ticking

    private func tick() {
        guard let end = endDate else { return }
        remaining = max(0, end.timeIntervalSinceNow)
        if remaining <= 0 { finish() }
    }

    private func finish() {
        let finishedPhase = phase
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
        if settings.prefs.completionSounds { SoundPlayer.play(.complete) }
        if settings.prefs.focusNotifications {
            NotificationManager.shared.notifyNow(
                id: "focus.done.\(Date().timeIntervalSince1970)",
                title: finishedPhase == .focus ? "Focus session finished" : "Break is over",
                body: finishedPhase == .focus ? "Nice work. Time for a break." : "Ready for the next focus session?")
        }
        advance(countSession: finishedPhase == .focus)
    }

    private func advance(countSession: Bool) {
        isRunning = false
        timer?.invalidate()
        timer = nil
        endDate = nil
        if phase == .focus {
            if countSession {
                sessionsThisRun += 1
                streak.recordStudy()
            }
            let every = max(1, settings.prefs.sessionsBeforeLongBreak)
            phase = (countSession && sessionsThisRun % every == 0) ? .longBreak : .shortBreak
        } else {
            phase = .focus
        }
        remaining = total
    }
}
