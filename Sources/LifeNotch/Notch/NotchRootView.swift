import SwiftUI

// NotchRootView.swift
// The top-level SwiftUI screen: draws the black shape and switches between the slim
// compact bar and the full expanded panel.

struct ThemeFill: View {
    let theme: NotchTheme

    var body: some View {
        ZStack {
            LinearGradient(colors: theme.gradient, startPoint: .top, endPoint: .bottom)
            if theme == .space { StarField() }
        }
    }
}

/// A few fixed "stars" for the Space theme (always the same pattern, so it never flickers).
struct StarField: View {
    var body: some View {
        Canvas { context, size in
            var seed: UInt64 = 42
            func next() -> Double {
                seed = seed &* 6364136223846793005 &+ 1442695040888963407
                return Double(seed >> 33) / Double(UInt64(1) << 31)
            }
            for _ in 0..<70 {
                let x = next() * size.width
                let y = next() * size.height
                let r = 0.5 + next() * 1.1
                let a = 0.2 + next() * 0.5
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: r, height: r)),
                             with: .color(Color.white.opacity(a)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct NotchRootView: View {
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        let mode = notch.mode
        let expanded = mode == .expanded
        let size = notch.size(for: mode)
        let prefs = settings.prefs
        let shape = NotchShape(topRadius: expanded ? 22 : 8, bottomRadius: expanded ? 30 : 12)

        ZStack(alignment: .top) {
            ThemeFill(theme: prefs.theme)
            if expanded {
                ExpandedPanelView().transition(.opacity)
            } else {
                CompactBarView().transition(.opacity)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipShape(shape)
        .overlay(
            shape.stroke(prefs.highContrast ? Color.white.opacity(0.9)
                         : (prefs.theme.hasGlow ? prefs.theme.accent.opacity(0.9) : Color.clear),
                         lineWidth: prefs.highContrast ? 1.5 : 1)
        )
        .shadow(color: (expanded && prefs.theme.hasGlow) ? prefs.theme.accent.opacity(0.7) : Color.clear,
                radius: 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(settings.notchAnimation, value: mode)
        .tint(prefs.theme.accent)
        .environment(\.lnAccent, prefs.theme.accent)
    }
}
