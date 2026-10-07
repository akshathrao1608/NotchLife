import SwiftUI

// NotchAnimationView.swift
// The little animated decoration in the compact bar (pulse, racing lights, football bounce,
// waveform). If "Reduce motion" is on (here or in macOS), it shows a still picture instead.

struct NotchAnimationView: View {
    let kind: NotchAnimationKind
    /// Used by the preview in Settings so you can see it even when the notch is closed.
    var forcePlay = false

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.lnAccent) private var accent

    var body: some View {
        if kind == .none {
            EmptyView()
        } else if settings.reduceMotionEffective {
            still
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
                animated(t: context.date.timeIntervalSinceReferenceDate)
            }
        }
    }

    private var still: some View {
        Image(systemName: staticSymbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(accent)
            .accessibilityHidden(true)
    }

    private var staticSymbol: String {
        switch kind {
        case .none: return "circle"
        case .pulse: return "circle.fill"
        case .racingLights: return "circle.grid.3x3.fill"
        case .footballBounce: return "soccerball"
        case .waveform: return "waveform"
        }
    }

    @ViewBuilder
    private func animated(t: TimeInterval) -> some View {
        switch kind {
        case .none:
            EmptyView()

        case .pulse:
            let s = 0.75 + 0.25 * sin(t * 3)
            Circle().fill(accent)
                .frame(width: 8, height: 8)
                .scaleEffect(s)
                .opacity(0.6 + 0.4 * s)
                .accessibilityHidden(true)

        case .racingLights:
            // Five lights switching on one by one, like a grid start.
            let step = Int(t * 2.2) % 7
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(i < step ? Color.red : Color.red.opacity(0.18))
                        .frame(width: 4.5, height: 4.5)
                }
            }
            .accessibilityHidden(true)

        case .footballBounce:
            let y = abs(sin(t * 4)) * 6
            Image(systemName: "soccerball")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .offset(y: -y + 3)
                .accessibilityHidden(true)

        case .waveform:
            HStack(spacing: 1.5) {
                ForEach(0..<5, id: \.self) { i in
                    let h = 3 + 8 * abs(sin(t * 3 + Double(i) * 0.9))
                    Capsule().fill(accent).frame(width: 2, height: h)
                }
            }
            .accessibilityHidden(true)
        }
    }
}
