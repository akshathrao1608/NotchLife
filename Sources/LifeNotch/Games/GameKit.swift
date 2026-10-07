import SwiftUI

// GameKit.swift
// Small helpers shared by all six games.

/// Wraps a game so it receives key presses (Space, arrows, letters...).
/// The mouse always works too; the keyboard is a bonus.
struct KeyCatcher<Content: View>: View {
    let onKey: (KeyPress) -> KeyPress.Result
    @ViewBuilder var content: () -> Content
    @FocusState private var focused: Bool

    var body: some View {
        content()
            .focusable()
            .focused($focused)
            .focusEffectDisabled()
            .onKeyPress(phases: .down, action: onKey)
            .onAppear { focused = true }
    }
}

/// A big coloured rounded rectangle used by the reaction games.
struct BigPanel: View {
    let color: Color
    let title: String
    var subtitle: String = ""

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous).fill(color)
            VStack(spacing: 6) {
                Text(title).font(.system(size: 30, weight: .bold, design: .rounded)).foregroundStyle(.white)
                if !subtitle.isEmpty {
                    Text(subtitle).font(.system(size: 13, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                }
            }
            .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }
}

func newBestBanner(_ show: Bool) -> some View {
    Group {
        if show {
            Label("New best!", systemImage: "trophy.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.yellow)
        }
    }
}
