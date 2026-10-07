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
            if prefs.notchAnimation != .none {
                NotchAnimationView(kind: prefs.notchAnimation)
                    .frame(width: 26, height: 14)
            }
        }
    }

    @ViewBuilder
    private func rightChips(_ prefs: Preferences) -> some View {
        HStack(spacing: 8) {
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
    var body: some View {
        HStack {
            Image(systemName: "hand.tap").font(.system(size: 11))
            Text("Click to open LifeNotch").lnFont(11, .medium)
        }
        .foregroundStyle(.white.opacity(0.8))
        .frame(maxWidth: .infinity, minHeight: 40)
    }
}
