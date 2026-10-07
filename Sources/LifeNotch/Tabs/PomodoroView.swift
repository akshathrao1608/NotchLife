import SwiftUI

// PomodoroView.swift
// The focus timer and the study streak. Shown in Mac Fun > Focus (and opened by Option + T).

struct PomodoroView: View {
    @EnvironmentObject private var pomodoro: PomodoroModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var streak: StreakStore
    @Environment(\.lnAccent) private var accent

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            timerCard
            VStack(spacing: 10) {
                durationsCard
                streakCard
            }
        }
    }

    // MARK: Timer

    private var timerCard: some View {
        VStack(spacing: 10) {
            Text(pomodoro.phase.title).lnFont(13, .bold)
            ZStack {
                Circle().stroke(Color.primary.opacity(0.12), lineWidth: 9)
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.001, pomodoro.fractionDone)))
                    .stroke(pomodoro.phase == .focus ? accent : Color.green,
                            style: StrokeStyle(lineWidth: 9, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(Countdown.clock(pomodoro.remaining))
                    .font(.system(size: 34 * settings.textScale, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .frame(width: 150, height: 150)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(pomodoro.phase.title) timer")
            .accessibilityValue("\(Countdown.clock(pomodoro.remaining)) remaining")

            HStack(spacing: 8) {
                Button { pomodoro.toggle() } label: {
                    Label(pomodoro.isRunning ? "Pause" : "Start", systemImage: pomodoro.isRunning ? "pause.fill" : "play.fill")
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                .keyboardShortcut(.space, modifiers: [.option])
                Button { pomodoro.reset() } label: { Label("Reset", systemImage: "arrow.counterclockwise") }
                    .buttonStyle(LNButtonStyle())
                Button { pomodoro.skip() } label: { Label("Skip", systemImage: "forward.end.fill") }
                    .buttonStyle(LNButtonStyle())
            }
            Text("Finished this session: \(pomodoro.sessionsThisRun)").lnFont(10.5).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    // MARK: Durations

    private var durationsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Lengths")
            Stepper("Focus: \(settings.prefs.workMinutes) min", value: $settings.prefs.workMinutes, in: 1...120)
            Stepper("Short break: \(settings.prefs.shortBreakMinutes) min", value: $settings.prefs.shortBreakMinutes, in: 1...60)
            Stepper("Long break: \(settings.prefs.longBreakMinutes) min", value: $settings.prefs.longBreakMinutes, in: 1...90)
            Stepper("Long break every \(settings.prefs.sessionsBeforeLongBreak) sessions",
                    value: $settings.prefs.sessionsBeforeLongBreak, in: 2...8)
            Toggle("Notify me when a session ends", isOn: Binding(
                get: { settings.prefs.focusNotifications },
                set: { newValue in
                    if newValue {
                        NotificationManager.shared.requestAuthorization { granted in
                            settings.prefs.focusNotifications = granted
                            if !granted {
                                ModalHelper.info(title: "Notifications are off",
                                                 message: "macOS didn't allow notifications for LifeNotch (or the app isn't running from LifeNotch.app). You can allow them in System Settings > Notifications.")
                            }
                        }
                    } else {
                        settings.prefs.focusNotifications = false
                    }
                }
            ))
            Toggle("Play sounds", isOn: $settings.prefs.completionSounds)
        }
        .lnFont(11.5)
        .card()
        .onChange(of: settings.prefs.workMinutes) { _ in pomodoro.durationsChanged() }
        .onChange(of: settings.prefs.shortBreakMinutes) { _ in pomodoro.durationsChanged() }
        .onChange(of: settings.prefs.longBreakMinutes) { _ in pomodoro.durationsChanged() }
    }

    // MARK: Streak

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Study streak")
            HStack(spacing: 14) {
                Label("\(streak.currentStreak) day\(streak.currentStreak == 1 ? "" : "s")", systemImage: "flame.fill")
                    .foregroundStyle(.orange).lnFont(15, .bold)
                Text("Best: \(streak.longestStreak)").lnFont(11).foregroundStyle(.secondary)
            }
            HStack(spacing: 6) {
                ForEach(Array(streak.lastSevenDays().enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 2) {
                        Circle().fill(day.studied ? Color.orange : Color.primary.opacity(0.15)).frame(width: 12, height: 12)
                        Text(day.label).lnFont(9).foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Last seven days: \(streak.lastSevenDays().filter { $0.studied }.count) studied")
            Button("I studied today") { streak.recordStudy(); SoundPlayer.play(.success) }
                .buttonStyle(LNButtonStyle())
            Text("Counts when you finish a focus session, complete an assignment, or press this button.")
                .lnFont(10).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}
