import SwiftUI

// UIComponents.swift
// Small reusable pieces so every tab looks and behaves the same:
// cards, buttons, badges and the theme/animation pickers.

// MARK: - Accent colour passed down through the whole app

private struct LNAccentKey: EnvironmentKey {
    static let defaultValue: Color = .blue
}

extension EnvironmentValues {
    var lnAccent: Color {
        get { self[LNAccentKey.self] }
        set { self[LNAccentKey.self] = newValue }
    }
}

// MARK: - Card / buttons

extension View {
    /// A soft rounded box that adapts to light and dark.
    func card(padding: CGFloat = 10) -> some View {
        self
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.07)))
    }
}

struct LNButtonStyle: ButtonStyle {
    var prominent = false
    var destructive = false
    @Environment(\.lnAccent) private var accent
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let fill: Color = destructive ? Color.red.opacity(0.85) : (prominent ? accent : Color.primary.opacity(0.12))
        configuration.label
            .font(.system(size: 12, weight: .semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Capsule().fill(fill))
            .foregroundStyle((prominent || destructive) ? Color.black : Color.primary)
            .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.4)
    }
}

/// A round icon-only button. ALWAYS give it a label: VoiceOver reads it aloud.
struct LNIconButton: View {
    let systemName: String
    let label: String
    var isActive = false
    let action: () -> Void
    @Environment(\.lnAccent) private var accent

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 26, height: 24)
                .foregroundStyle(isActive ? Color.black : Color.primary)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isActive ? accent : Color.primary.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .help(label)
        .accessibilityLabel(label)
    }
}

// MARK: - Labels

struct DemoBadge: View {
    var text = "Demo Data"
    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.orange.opacity(0.25)))
            .foregroundStyle(Color.orange)
            .accessibilityLabel("Demo data, not live")
    }
}

struct AIBadge: View {
    var body: some View {
        Label("AI-generated", systemImage: "sparkles")
            .font(.system(size: 10, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(Color.purple.opacity(0.25)))
            .foregroundStyle(Color.purple)
            .accessibilityLabel("AI-generated answer, may contain mistakes")
    }
}

struct SectionTitle: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text)
            .lnFont(11, .bold)
            .textCase(.uppercase)
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String = ""
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 26)).foregroundStyle(.secondary)
            Text(title).lnFont(13, .semibold)
            if !message.isEmpty {
                Text(message).lnFont(11).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Theme and animation pickers (used in Mac Fun > Style and in Settings)

struct ThemePicker: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
            ForEach(NotchTheme.allCases) { theme in
                Button {
                    settings.prefs.theme = theme
                } label: {
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(LinearGradient(colors: theme.gradient, startPoint: .top, endPoint: .bottom))
                            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .stroke(theme.accent, lineWidth: settings.prefs.theme == theme ? 2.5 : 1))
                            .frame(height: 34)
                        Text(theme.title).lnFont(10.5, .medium)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(theme.title) theme")
                .accessibilityAddTraits(settings.prefs.theme == theme ? .isSelected : [])
            }
        }
    }
}

struct AnimationPicker: View {
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        HStack {
            Picker("Notch animation", selection: $settings.prefs.notchAnimation) {
                ForEach(NotchAnimationKind.allCases) { kind in
                    Text(kind.title).tag(kind)
                }
            }
            .pickerStyle(.menu)
            .frame(maxWidth: 240)
            NotchAnimationView(kind: settings.prefs.notchAnimation, forcePlay: true)
                .frame(width: 36, height: 18)
        }
    }
}
