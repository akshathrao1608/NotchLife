import SwiftUI

// TimerToolView.swift
// Countdown timers (1 minute to 1 hour, or your own) and a stopwatch with laps.
// While a countdown runs, the time shows beside the notch.

struct TimerToolView: View {
    @EnvironmentObject private var timer: ToolTimerModel
    @State private var customMinutes = 10

    private struct Preset: Identifiable {
        let title: String
        let seconds: TimeInterval
        var id: String { title }
    }

    private let presets = [Preset(title: "1 min", seconds: 60), Preset(title: "5 min", seconds: 300),
                           Preset(title: "10 min", seconds: 600), Preset(title: "15 min", seconds: 900),
                           Preset(title: "30 min", seconds: 1800), Preset(title: "1 hour", seconds: 3600)]

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            countdownCard
            stopwatchCard
        }
    }

    private var countdownCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Countdown")
            Text(Countdown.clock(timer.remaining))
                .font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                .accessibilityLabel("Countdown \(Countdown.clock(timer.remaining))")
            if timer.total > 0 {
                ProgressView(value: timer.total - timer.remaining, total: timer.total)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 70), spacing: 6)], spacing: 6) {
                ForEach(presets) { preset in
                    Button(preset.title) { timer.startCountdown(seconds: preset.seconds) }.buttonStyle(LNButtonStyle())
                }
            }
            HStack {
                Stepper("Custom: \(customMinutes) min", value: $customMinutes, in: 1...240)
                Button("Start") { timer.startCountdown(seconds: TimeInterval(customMinutes * 60)) }
                    .buttonStyle(LNButtonStyle(prominent: true))
            }
            HStack {
                if timer.countdownRunning {
                    Button("Pause") { timer.pauseCountdown() }.buttonStyle(LNButtonStyle(prominent: true))
                } else if timer.remaining > 0 {
                    Button("Resume") { timer.resumeCountdown() }.buttonStyle(LNButtonStyle(prominent: true))
                }
                if timer.total > 0 { Button("Reset") { timer.resetCountdown() }.buttonStyle(LNButtonStyle()) }
            }
        }
        .lnFont(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var stopwatchCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Stopwatch")
            Text(ToolTimerModel.stopwatchText(timer.elapsed))
                .font(.system(size: 44, weight: .semibold, design: .rounded)).monospacedDigit()
                .accessibilityLabel("Stopwatch \(ToolTimerModel.stopwatchText(timer.elapsed))")
            HStack {
                Button(timer.stopwatchRunning ? "Pause" : "Start") {
                    timer.stopwatchRunning ? timer.pauseStopwatch() : timer.startStopwatch()
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                Button("Lap") { timer.lap() }.buttonStyle(LNButtonStyle()).disabled(!timer.stopwatchRunning)
                Button("Reset") { timer.resetStopwatch() }.buttonStyle(LNButtonStyle())
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(timer.laps.enumerated()), id: \.offset) { index, lap in
                        Text("Lap \(timer.laps.count - index)   \(ToolTimerModel.stopwatchText(lap))")
                            .lnFont(11).monospacedDigit()
                    }
                }
            }
            .frame(maxHeight: 120)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
