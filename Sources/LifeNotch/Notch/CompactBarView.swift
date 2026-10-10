import SwiftUI

// CompactBarView.swift
// The slim bar beside the camera notch. Left side and right side show small "chips"
// (an icon, sometimes a few characters). The empty gap in the middle sits behind the real camera
// notch. How many chips show on each side depends on the "Bar size" in Settings:
//   Tiny = none, Small = one per side, Medium = all (icons), Large = all (with text).
// Hovering for a moment grows it a little ("preview"); clicking opens the full panel.

/// One small icon (+ optional text) item in the compact bar.
struct CompactChip: View {
    let icon: String
    let text: String
    var tint: Color = .white
    /// Keep the text even when the bar size shows icons only (used for the timer and unread count).
    var keepsText = false
    var label: String
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon).font(.system(size: 10, weight: .semibold))
            if !text.isEmpty && (keepsText || settings.prefs.compactStyle == .large) {
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
    @EnvironmentObject private var messages: MessageHub
    @EnvironmentObject private var toolTimer: ToolTimerModel

    var body: some View {
        let geometry = notch.geometry
        let prefs = settings.prefs
        let limit = prefs.compactStyle.maxChipsPerSide

        // Re-draw every 30 s so countdowns stay fresh.
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    row(leftItems(prefs), limit: limit)
                        .frame(width: notch.leftSide, alignment: .trailing)
                        .clipped()
                    Color.clear.frame(width: geometry.notchWidth)
                    row(rightItems(prefs), limit: limit)
                        .frame(width: notch.rightSide, alignment: .leading)
                        .clipped()
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

    /// Shows only as many chips as the chosen bar size allows (the most important come first).
    private func row(_ items: [AnyView], limit: Int) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(items.prefix(limit).enumerated()), id: \.offset) { _, item in
                item
            }
        }
    }

    // MARK: Left side (most important first)

    private func leftItems(_ prefs: Preferences) -> [AnyView] {
        var items: [AnyView] = []

        if prefs.showTimerChip, pomodoro.isActive {
            items.append(AnyView(
                CompactChip(icon: pomodoro.isRunning ? "timer" : "pause.fill",
                            text: Countdown.clock(pomodoro.remaining),
                            tint: pomodoro.phase == .focus ? prefs.theme.accent : .green,
                            keepsText: true,
                            label: "\(pomodoro.phase.title) timer, \(Countdown.clock(pomodoro.remaining)) left")
            ))
        }
        if prefs.showTimerChip, toolTimer.countdownActive {
            items.append(AnyView(
                CompactChip(icon: toolTimer.countdownRunning ? "hourglass" : "pause.fill",
                            text: Countdown.clock(toolTimer.remaining),
                            tint: .orange,
                            keepsText: true,
                            label: "Countdown, \(Countdown.clock(toolTimer.remaining)) left")
            ))
        }
        if prefs.showAssignmentChip, let next = assignments.nextDue {
            let urgent = next.isUrgent()
            let subject = next.subject.isEmpty ? "Task" : String(next.subject.prefix(4))
            let due = next.isOverdue() ? "overdue" : "due in " + Countdown.short(to: next.due)
            items.append(AnyView(
                CompactChip(icon: urgent ? "exclamationmark.triangle.fill" : "book.closed.fill",
                            text: "\(subject) \(next.dueSummary())",
                            tint: urgent ? .red : .white,
                            label: "Next assignment: \(next.title), \(due)")
            ))
        }
        if prefs.showCountdownChip, let info = sports.compactInfo() {
            items.append(AnyView(
                CompactChip(icon: info.icon, text: info.text,
                            tint: info.isDemo ? .orange : .white, label: info.label)
            ))
        }
        if prefs.notchAnimation != .none {
            items.append(AnyView(
                NotchAnimationView(kind: prefs.notchAnimation).frame(width: 26, height: 14)
            ))
        }
        return items
    }

    // MARK: Right side (most important first)

    private func rightItems(_ prefs: Preferences) -> [AnyView] {
        var items: [AnyView] = []

        if prefs.showMessagesChip && prefs.messagesEnabled {
            let unread = messages.unreadCount
            items.append(AnyView(
                CompactChip(icon: "message.fill",
                            text: unread > 0 ? "\(unread)" : "",
                            tint: unread > 0 ? .green : Color.white.opacity(0.55),
                            keepsText: true,
                            label: "\(unread) unread messages")
            ))
        }
        if prefs.showAIChip {
            items.append(AnyView(
                Button { notch.open(.ai) } label: {
                    Image(systemName: "sparkles").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("AI Search")
                .accessibilityLabel("Open AI Search")
            ))
        }
        if prefs.showBrowserChip {
            items.append(AnyView(
                Button { notch.open(.browser) } label: {
                    Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
                .help("Quick browser search")
                .accessibilityLabel("Open quick browser search")
            ))
        }
        if prefs.showBestScoreChip {
            let best = scores.bestText(for: prefs.compactGame)
            items.append(AnyView(
                CompactChip(icon: "trophy.fill", text: best ?? "–", tint: .yellow,
                            label: "Best \(prefs.compactGame.title) score: \(best ?? "none yet")")
            ))
        }
        if prefs.showBattery, let percent = stats.batteryPercent {
            items.append(AnyView(
                CompactChip(icon: stats.isCharging ? "battery.100.bolt" : "battery.75",
                            text: "\(percent)%",
                            tint: percent <= 15 && !stats.isCharging ? .red : .white,
                            label: "Battery \(percent) percent\(stats.isCharging ? ", charging" : "")")
            ))
        }
        if prefs.showWifi {
            items.append(AnyView(
                CompactChip(icon: stats.wifiConnected ? "wifi" : "wifi.slash", text: "",
                            tint: stats.wifiConnected ? .white : .orange,
                            label: stats.wifiConnected ? "Wi-Fi connected" : "Not connected to Wi-Fi")
            ))
        }
        if prefs.showTime {
            items.append(AnyView(
                Text(Date(), style: .time)
                    .lnFont(10.5, .medium)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .accessibilityLabel("Current time")
            ))
        }
        return items
    }
}

/// The extra row shown while you hover ("preview" mode). It shows everything the bar can't.
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
