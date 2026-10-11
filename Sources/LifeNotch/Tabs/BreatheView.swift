import SwiftUI

// BreatheView.swift
// A calm circle that grows as you breathe in and shrinks as you breathe out (4s in, 6s out).
// Respects "Reduce motion": the circle stays still and the words still guide you.

struct BreatheView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var running = false
    @State private var inhale = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle().fill(settings.prefs.theme.accent.opacity(0.25))
                    .frame(width: 140, height: 140)
                    .scaleEffect(running && inhale && !settings.prefs.reduceMotion ? 1.0 : 0.55)
                Text(running ? (inhale ? "Breathe in…" : "Breathe out…") : "Ready?")
                    .lnFont(14, .semibold)
            }
            .frame(height: 150)
            .animation(settings.prefs.reduceMotion ? nil : .easeInOut(duration: inhale ? 4 : 6), value: inhale)
            Button(running ? "Stop" : "Start") { running.toggle() }
                .buttonStyle(LNButtonStyle(prominent: true))
        }
        .frame(maxWidth: .infinity)
        .task(id: running) {
            guard running else { inhale = false; return }
            while !Task.isCancelled {
                inhale = true
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if Task.isCancelled { break }
                inhale = false
                try? await Task.sleep(nanoseconds: 6_000_000_000)
            }
        }
    }
}
