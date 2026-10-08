import SwiftUI

// Enums.swift
// A "enum" is a fixed list of choices (like the 8 tabs or the 7 themes).
// Keeping them all in one file makes it easy to see everything you can pick in LifeNotch.

// MARK: - Tabs

enum NotchTab: String, CaseIterable, Identifiable, Codable {
    case ai, browser, messages, assignments, sports, games, macFun, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ai: return "AI Search"
        case .browser: return "Browser"
        case .messages: return "Messages"
        case .assignments: return "Assignments"
        case .sports: return "Sports"
        case .games: return "Mini Games"
        case .macFun: return "Mac Fun"
        case .settings: return "Settings"
        }
    }

    /// SF Symbols icon name (Apple's built-in icon set).
    var icon: String {
        switch self {
        case .ai: return "sparkles"
        case .browser: return "safari"
        case .messages: return "message.fill"
        case .assignments: return "checklist"
        case .sports: return "flag.checkered"
        case .games: return "gamecontroller.fill"
        case .macFun: return "wand.and.stars"
        case .settings: return "gearshape.fill"
        }
    }

    /// 1...8, used for the Command+number shortcuts.
    var number: Int { (NotchTab.allCases.firstIndex(of: self) ?? 0) + 1 }
}

enum MacFunSection: String, CaseIterable, Identifiable, Codable {
    case focus, daily, launch, notes, system, sounds, style

    var id: String { rawValue }

    var title: String {
        switch self {
        case .focus: return "Focus"
        case .daily: return "Daily"
        case .launch: return "Launch"
        case .notes: return "Notes"
        case .system: return "System"
        case .sounds: return "Sounds"
        case .style: return "Style"
        }
    }

    var icon: String {
        switch self {
        case .focus: return "timer"
        case .daily: return "quote.bubble"
        case .launch: return "rocket"
        case .notes: return "note.text"
        case .system: return "cpu"
        case .sounds: return "speaker.wave.2"
        case .style: return "paintpalette"
        }
    }
}

// MARK: - Look and feel

/// How big the slim bar around the camera notch is (when the panel is closed).
enum CompactStyle: String, CaseIterable, Identifiable, Codable {
    case tiny, small, medium, large
    var id: String { rawValue }

    var title: String {
        switch self {
        case .tiny: return "Tiny"
        case .small: return "Small"
        case .medium: return "Medium"
        case .large: return "Large"
        }
    }

    var detail: String {
        switch self {
        case .tiny: return "Just a thin black edge around the camera. No icons (hover to see info)."
        case .small: return "One icon on each side."
        case .medium: return "All your icons, no text."
        case .large: return "All your icons with text."
        }
    }

    /// How many icons may show on EACH side of the camera notch.
    var maxChipsPerSide: Int {
        switch self {
        case .tiny: return 0
        case .small: return 1
        case .medium, .large: return Int.max
        }
    }

    /// Width of each side for the fixed-size styles. nil = fit to the icons.
    var fixedSideWidth: CGFloat? {
        switch self {
        case .tiny: return 14
        case .small: return 56
        case .medium, .large: return nil
        }
    }
}

/// How big the OPEN panel is.
enum PanelSize: String, CaseIterable, Identifiable, Codable {
    case small, normal, large
    var id: String { rawValue }
    var title: String {
        switch self {
        case .small: return "Small"
        case .normal: return "Normal"
        case .large: return "Large"
        }
    }
    var size: CGSize {
        switch self {
        case .small: return CGSize(width: 660, height: 440)
        case .normal: return CGSize(width: 740, height: 480)
        case .large: return CGSize(width: 860, height: 540)
        }
    }
}

enum Appearance: String, CaseIterable, Identifiable, Codable {
    case auto, dark, light
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: return "Automatic"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

enum NotchTheme: String, CaseIterable, Identifiable, Codable {
    case black, transparent, glow, minimal, racing, football, space
    var id: String { rawValue }

    var title: String {
        switch self {
        case .black: return "Black"
        case .transparent: return "Transparent"
        case .glow: return "Coloured glow"
        case .minimal: return "Minimal"
        case .racing: return "Racing"
        case .football: return "Football"
        case .space: return "Space"
        }
    }

    /// The main accent colour of the theme (buttons, highlights).
    var accent: Color {
        switch self {
        case .black: return Color(red: 0.36, green: 0.62, blue: 1.0)
        case .transparent: return Color(red: 0.45, green: 0.85, blue: 0.95)
        case .glow: return Color(red: 0.85, green: 0.35, blue: 1.0)
        case .minimal: return Color(white: 0.85)
        case .racing: return Color(red: 1.0, green: 0.22, blue: 0.2)
        case .football: return Color(red: 0.25, green: 0.85, blue: 0.4)
        case .space: return Color(red: 0.62, green: 0.5, blue: 1.0)
        }
    }

    /// Top-to-bottom colours of the panel. The top is always (nearly) black so it
    /// blends into the real hardware notch.
    var gradient: [Color] {
        switch self {
        case .black, .glow, .minimal: return [.black, .black]
        case .transparent: return [Color.black.opacity(0.92), Color.black.opacity(0.55)]
        case .racing: return [.black, Color(red: 0.24, green: 0.03, blue: 0.03)]
        case .football: return [.black, Color(red: 0.02, green: 0.2, blue: 0.08)]
        case .space: return [.black, Color(red: 0.09, green: 0.05, blue: 0.22)]
        }
    }

    var hasGlow: Bool { self == .glow }
}

enum NotchAnimationKind: String, CaseIterable, Identifiable, Codable {
    case none, pulse, racingLights, footballBounce, waveform
    var id: String { rawValue }
    var title: String {
        switch self {
        case .none: return "None"
        case .pulse: return "Pulse"
        case .racingLights: return "Racing lights"
        case .footballBounce: return "Football bounce"
        case .waveform: return "Waveform"
        }
    }
}

// MARK: - Browser

enum SearchEngine: String, CaseIterable, Identifiable, Codable {
    case google, duckDuckGo, bing, brave
    var id: String { rawValue }

    var title: String {
        switch self {
        case .google: return "Google"
        case .duckDuckGo: return "DuckDuckGo"
        case .bing: return "Bing"
        case .brave: return "Brave Search"
        }
    }

    private var base: String {
        switch self {
        case .google: return "https://www.google.com/search"
        case .duckDuckGo: return "https://duckduckgo.com/"
        case .bing: return "https://www.bing.com/search"
        case .brave: return "https://search.brave.com/search"
        }
    }

    func searchURL(for query: String) -> URL? {
        guard var comps = URLComponents(string: base) else { return nil }
        comps.queryItems = [URLQueryItem(name: "q", value: query)]
        return comps.url
    }
}

// MARK: - Compact bar / sports / games

enum CountdownSource: String, CaseIterable, Identifiable, Codable {
    case off, f1, football
    var id: String { rawValue }
    var title: String {
        switch self {
        case .off: return "Off"
        case .f1: return "Next F1 race"
        case .football: return "Next football match"
        }
    }
}

enum GameKind: String, CaseIterable, Identifiable, Codable {
    case reaction, memory, maths, penalty, f1Lights, wordRush
    var id: String { rawValue }

    var title: String {
        switch self {
        case .reaction: return "Reaction Time"
        case .memory: return "Memory Match"
        case .maths: return "Quick Maths"
        case .penalty: return "Penalty Shootout"
        case .f1Lights: return "F1 Reaction Lights"
        case .wordRush: return "Word Rush"
        }
    }

    var icon: String {
        switch self {
        case .reaction: return "bolt.fill"
        case .memory: return "square.grid.3x3.fill"
        case .maths: return "plus.forwardslash.minus"
        case .penalty: return "soccerball"
        case .f1Lights: return "circle.grid.3x3.fill"
        case .wordRush: return "textformat.abc"
        }
    }

    var blurb: String {
        switch self {
        case .reaction: return "Click or press Space when the colour changes."
        case .memory: return "Match the pairs in as few moves as you can."
        case .maths: return "As many answers as possible in 30 seconds."
        case .penalty: return "Pick left, centre or right. Best of five."
        case .f1Lights: return "Wait for the five lights to go out, then go!"
        case .wordRush: return "Make words from six letters in 60 seconds."
        }
    }
}

enum F1SourceChoice: String, CaseIterable, Identifiable, Codable {
    case demo, live
    var id: String { rawValue }
    var title: String {
        switch self {
        case .demo: return "Demo Data (no internet)"
        case .live: return "Live (Jolpica F1 API, no key needed)"
        }
    }
}

enum FootballSourceChoice: String, CaseIterable, Identifiable, Codable {
    case demo, footballData
    var id: String { rawValue }
    var title: String {
        switch self {
        case .demo: return "Demo Data (no internet)"
        case .footballData: return "Live (football-data.org, needs free key)"
        }
    }
}

// MARK: - AI

enum AIProviderKind: String, CaseIterable, Identifiable, Codable {
    case anthropic, openai
    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI"
        }
    }

    var keysPage: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        }
    }

    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-sonnet-5-5"
        case .openai: return "gpt-4.1"
        }
    }

    var keychainAccount: String { "apikey.\(rawValue)" }
}

enum AIMode: String, CaseIterable, Identifiable, Codable {
    case explainSimply, homework, summarise, findSources, checkAnswer, translate, quiz
    var id: String { rawValue }

    var title: String {
        switch self {
        case .explainSimply: return "Explain simply"
        case .homework: return "Homework help"
        case .summarise: return "Summarise"
        case .findSources: return "Find sources"
        case .checkAnswer: return "Check my answer"
        case .translate: return "Translate"
        case .quiz: return "Quiz me"
        }
    }

    var icon: String {
        switch self {
        case .explainSimply: return "lightbulb"
        case .homework: return "pencil.and.list.clipboard"
        case .summarise: return "text.alignleft"
        case .findSources: return "link"
        case .checkAnswer: return "checkmark.seal"
        case .translate: return "globe"
        case .quiz: return "questionmark.bubble"
        }
    }

    var placeholder: String {
        switch self {
        case .explainSimply: return "What do you want explained?"
        case .homework: return "Paste or type the school question…"
        case .summarise: return "Paste text, a link, or drop a PDF/screenshot…"
        case .findSources: return "What should I find sources for?"
        case .checkAnswer: return "Write the question, then \"My answer: …\""
        case .translate: return "Text to translate…"
        case .quiz: return "Which topic should I quiz you on?"
        }
    }
}
