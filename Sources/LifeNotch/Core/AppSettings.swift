import SwiftUI
import Combine

// AppSettings.swift
// The "settings object" that every screen can read and change.
// Whenever you change a setting, `prefs` is saved automatically and every screen updates.

final class AppSettings: ObservableObject {
    @Published var prefs: Preferences {
        didSet {
            Preferences.save(prefs)
            SoundPlayer.isMuted = prefs.soundMuted
        }
    }

    init() {
        let loaded = Preferences.load()
        prefs = loaded
        SoundPlayer.isMuted = loaded.soundMuted
    }

    // MARK: Accessibility helpers

    /// True if you turned on "Reduce motion" here OR in macOS System Settings.
    var reduceMotionEffective: Bool {
        prefs.reduceMotion || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    var textScale: CGFloat { CGFloat(prefs.textScale) }

    /// The spring used when the notch opens and closes.
    var notchAnimation: Animation {
        if reduceMotionEffective { return .easeInOut(duration: 0.12) }
        let speed = max(0.4, prefs.animationSpeed)
        return .spring(response: 0.45 / speed, dampingFraction: 0.78)
    }

    /// How long (seconds) the open/close animation takes to settle.
    var notchAnimationSettleTime: Double {
        reduceMotionEffective ? 0.2 : 0.7 / max(0.4, prefs.animationSpeed)
    }

    /// Light/dark choice for the body of the expanded panel. nil = follow macOS.
    var forcedColorScheme: ColorScheme? {
        switch prefs.appearance {
        case .auto: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    // MARK: Consent ("Always allow") bookkeeping

    func hasConsent(_ topic: ConsentTopic) -> Bool {
        prefs.grantedConsents.contains(topic.rawValue)
    }

    func grant(_ topic: ConsentTopic) {
        if !hasConsent(topic) { prefs.grantedConsents.append(topic.rawValue) }
    }

    func revoke(_ topic: ConsentTopic) {
        prefs.grantedConsents.removeAll { $0 == topic.rawValue }
    }

    func resetPreferences() {
        prefs = Preferences()
    }
}

// MARK: - Accessible fonts

/// Use `.lnFont(12)` instead of `.font(.system(size: 12))`.
/// It automatically follows the "Larger text" slider in Settings.
struct LNFontModifier: ViewModifier {
    @EnvironmentObject private var settings: AppSettings
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design

    func body(content: Content) -> some View {
        content.font(.system(size: size * settings.textScale, weight: weight, design: design))
    }
}

extension View {
    func lnFont(_ size: CGFloat = 12, _ weight: Font.Weight = .regular, design: Font.Design = .default) -> some View {
        modifier(LNFontModifier(size: size, weight: weight, design: design))
    }
}
