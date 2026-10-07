import SwiftUI

// CompactBarView.swift
// The slim bar beside the camera notch. Left side and right side show small "chips"
// (icon + a few characters). The empty gap in the middle sits behind the real camera notch.
// Hovering grows it a little ("preview"); clicking opens the full panel.

/// One small icon + text item in the compact bar.
struct CompactChip: View {
    let icon: String
    let text: String
    var tint: Color = .white
    var label: String

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            if !text.isEmpty {
                Text(text).lnFont(10.5, .medium).monospacedDigit()
            }
        }
        .foregroundStyle(tint)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
    }
}

struct CompactBarView: View {
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var assignments: AssignmentStore
    @EnvironmentObject private var pomodoro: PomodoroModel
    @EnvironmentObject private var sports: SportsModel
    @EnvironmentObject private var scores: GameScores
    @EnvironmentObject private var stats: SystemStatsModel

    var body: some View {
        let geometry = notch.geometry
        let prefs = settings.prefs

        // Re-draw every 30 s so countdowns stay fresh.
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    leftChips(prefs)
                        .frame(width: notch.leftSide, alignment: .trailing)
                    Color.clear.frame(width: geometry.notchWidth)
                    rightChips(prefs)
                        .frame(width: notch.rightSide, alignment: .leading)
                }
                .frame(height: geometry.notchHeight)

                if notch.mode == .preview {
                    PreviewPeekRow()
                        .padding(.horizontal, 20)
                        .transition(.opacity)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { notch.request(.expanded) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("LifeNotch compact bar")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Open LifeNotch") { notch.request(.expanded) }
    }

    @ViewBuilder
    private func leftChips(_ prefs: Preferences) -> some View {
        HStack(spacing: 8) {
            if prefs.showAssignmentChip, let next = assignments.nextDue {
                let urgent = next.isUrgent()
                let subject = next.subject.isEmpty ? "Task" : String(next.subject.prefix(4))
                CompactChip(icon: urgent ? "exclamationmark.triangle.fill" : "book.closed.fill",
                            text: "\(subject) \(next.dueSummary())",
                            tint: urgent ? .red : .white,
                            label: "Next assignment: \(next.title), \(next.isOverdue() ? "overdue" : "due in " + Countdown.short(to: next.due))")
            }
            if prefs.showCountdownChip, let info = sports.compactInfo() {
                CompactChip(icon: info.icon, text: info.text,
                            tint: info.isDemo ? .orange : .white, label: info.label)
            }
            if prefs.showTimerChip, pomodoro.isActive {
                CompactChip(icon: pomodoro.isRunning ? "timer" : "pause.fill",
                            text: Countdown.clock(pomodoro.remaining),
                            tint: pomodoro.phase == .focus ? settings.prefs.theme.accent : .green,
                            label: "\(pomodoro.phase.title) timer, \(Countdown.clock(pomodoro.remaining)) left")
            }
            if prefs.notchAnimation != .none {
                NotchAnimationView(kind: prefs.notchAnimation)
                    .frame(width: 26, height: 14)
            }
        }
    }

    @ViewBuilder
    private func rightChips(_ prefs: Preferences) -> some View {
        HStack(spacing: 8) {
            if prefs.showBestScoreChip {
                CompactChip(icon: "trophy.fill",
                            text: scores.bestText(for: prefs.compactGame) ?? "–",
                            tint: .yellow,
                            label: "Best \(prefs.compactGame.title) score: \(scores.bestText(for: prefs.compactGame) ?? "none yet")")
            }
            if prefs.showBattery, let percent = stats.batteryPercent {
                CompactChip(icon: stats.isCharging ? "battery.100.bolt" : "battery.75",
                            text: "\(percent)%",
                            tint: percent <= 15 && !stats.isCharging ? .red : .white,
                            label: "Battery \(percent) percent\(stats.isCharging ? ", charging" : "")")
            }
            if prefs.showWifi {
                CompactChip(icon: stats.wifiConnected ? "wifi" : "wifi.slash", text: "",
                            tint: stats.wifiConnected ? .white : .orange,
                            label: stats.wifiConnected ? "Wi-Fi connected" : "Not connected to Wi-Fi")
            }
            if prefs.showTime {
                Text(Date(), style: .time)
                    .lnFont(10.5, .medium)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityLabel("Current time")
            }
            if prefs.showAIChip {
                Button { notch.open(.ai) } label: {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("AI Search")
                .accessibilityLabel("Open AI Search")
            }
            if prefs.showBrowserChip {
                Button { notch.open(.browser) } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Quick browser search")
                .accessibilityLabel("Open quick browser search")
            }
        }
    }
}

/// The extra row shown while you hover ("preview" mode).
struct PreviewPeekRow: View {
    @EnvironmentObject private var assignments: AssignmentStore
    @EnvironmentObject private var pomodoro: PomodoroModel
    @EnvironmentObject private var sports: SportsModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 14) {
            if let next = assignments.nextDue {
                Label("\(next.title) · \(next.dueSummary())", systemImage: "checklist")
                    .foregroundStyle(next.isUrgent() ? Color.red : Color.white)
                    .lineLimit(1)
            }
            if pomodoro.isActive {
                Label("\(pomodoro.phase.title) \(Countdown.clock(pomodoro.remaining))", systemImage: "timer")
                    .lineLimit(1)
            }
            if settings.prefs.showCountdownChip, let info = sports.compactInfo() {
                Label(info.text + (info.isDemo ? " (demo)" : ""), systemImage: info.icon)
                    .foregroundStyle(info.isDemo ? Color.orange : Color.white)
                    .lineLimit(1)
            }
            if assignments.nextDue == nil && !pomodoro.isActive && sports.compactInfo() == nil {
                Label("Click to open LifeNotch", systemImage: "hand.tap")
            }
        }
        .lnFont(11, .medium)
        .foregroundStyle(.white.opacity(0.85))
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}
