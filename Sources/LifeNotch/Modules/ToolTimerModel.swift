import Foundation

// ToolTimerModel.swift
// A countdown timer and a stopwatch with laps (separate from the Pomodoro focus timer).
// Both work from real clock times, so they stay accurate.

final class ToolTimerModel: ObservableObject {
    // Countdown
    @Published private(set) var remaining: TimeInterval = 0
    @Published private(set) var total: TimeInterval = 0
    @Published private(set) var countdownRunning = false
    // Stopwatch
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var stopwatchRunning = false
    @Published private(set) var laps: [TimeInterval] = []

    private let settings: AppSettings
    private var endDate: Date?
    private var stopwatchStart: Date?
    private var stopwatchBase: TimeInterval = 0
    private var timer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    /// Show a countdown in the compact bar while it is running or paused part-way.
    var countdownActive: Bool { countdownRunning || (remaining > 0 && remaining < total) }

    // MARK: Countdown

    func startCountdown(seconds: TimeInterval) {
        total = seconds
        remaining = seconds
        resumeCountdown()
    }

    func resumeCountdown() {
        guard remaining > 0 else { return }
        endDate = Date().addingTimeInterval(remaining)
        countdownRunning = true
        ensureTimer()
    }

    func pauseCountdown() {
        tick()
        countdownRunning = false
        endDate = nil
        stopTimerIfIdle()
    }

    func resetCountdown() {
        countdownRunning = false
        endDate = nil
        remaining = 0
        total = 0
        stopTimerIfIdle()
    }

    // MARK: Stopwatch

    func startStopwatch() {
        stopwatchStart = Date()
        stopwatchRunning = true
        ensureTimer()
    }

    func pauseStopwatch() {
        tick()
        stopwatchBase = elapsed
        stopwatchStart = nil
        stopwatchRunning = false
        stopTimerIfIdle()
    }

    func lap() {
        if stopwatchRunning { laps.insert(elapsed, at: 0) }
    }

    func resetStopwatch() {
        stopwatchRunning = false
        stopwatchStart = nil
        stopwatchBase = 0
        elapsed = 0
        laps = []
        stopTimerIfIdle()
    }

    // MARK: Ticking

    private func ensureTimer() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in self?.tick() }
    }

    private func stopTimerIfIdle() {
        if !countdownRunning && !stopwatchRunning {
            timer?.invalidate()
            timer = nil
        }
    }

    private func tick() {
        if countdownRunning, let end = endDate {
            remaining = max(0, end.timeIntervalSinceNow)
            if remaining <= 0 {
                countdownRunning = false
                endDate = nil
                if settings.prefs.completionSounds { SoundPlayer.play(.complete) }
                if settings.prefs.focusNotifications {
                    NotificationManager.shared.notifyNow(id: "timer.done.\(Date().timeIntervalSince1970)",
                                                         title: "Timer finished", body: "Your countdown reached zero.")
                }
            }
        }
        if stopwatchRunning, let start = stopwatchStart {
            elapsed = stopwatchBase + Date().timeIntervalSince(start)
        }
        stopTimerIfIdle()
    }

    /// "1:05:09.3" or "05:09.3"
    static func stopwatchText(_ t: TimeInterval) -> String {
        let tenths = Int((t * 10).rounded(.down)) % 10
        let whole = Int(t)
        let h = whole / 3600, m = (whole % 3600) / 60, s = whole % 60
        return h > 0 ? String(format: "%d:%02d:%02d.%d", h, m, s, tenths) : String(format: "%02d:%02d.%d", m, s, tenths)
    }
}
