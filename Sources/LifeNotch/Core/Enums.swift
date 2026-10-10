import SwiftUI

// Enums.swift
// A "enum" is a fixed list of choices (like the 8 tabs or the 7 themes).
// Keeping them all in one file makes it easy to see everything you can pick in LifeNotch.

// MARK: - Tabs

enum NotchTab: String, CaseIterable, Identifiable, Codable {
    // The original eight
    case ai, browser, messages, assignments, sports, games, macFun, settings
    // More modules (open them from the grid button or the command palette)
    case home, clipboard, todo, timer, world, tools, shelf, search, snippets, shortcuts, translate

    var id: String { rawValue }

    /// The first eight: shown in the top bar by default.
    static let core: [NotchTab] = [.ai, .browser, .messages, .assignments, .sports, .games, .macFun, .settings]

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
        case .home: return "Home"
        case .clipboard: return "Clipboard"
        case .todo: return "To-Do"
        case .timer: return "Timer"
        case .world: return "World Clock"
        case .tools: return "Tools"
        case .shelf: return "File Shelf"
        case .search: return "File Search"
        case .snippets: return "Snippets"
        case .shortcuts: return "Shortcuts"
        case .translate: return "Translate"
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
        case .home: return "house.fill"
        case .clipboard: return "doc.on.clipboard"
        case .todo: return "list.bullet.rectangle"
        case .timer: return "stopwatch"
        case .world: return "globe.europe.africa.fill"
        case .tools: return "wrench.and.screwdriver.fill"
        case .shelf: return "tray.full.fill"
        case .search: return "magnifyingglass"
        case .snippets: return "text.quote"
        case .shortcuts: return "bolt.fill"
        case .translate: return "character.bubble"
        }
    }

    /// One line shown in the module grid and the command palette.
    var blurb: String {
        switch self {
        case .ai: return "Ask questions, solve, explain, translate"
        case .browser: return "A small browser inside the notch"
        case .messages: return "Notices you choose to send here"
        case .assignments: return "Homework with due dates and AI help"
        case .sports: return "F1 and football"
        case .games: return "Reaction, memory, maths, 2048, Snake…"
        case .macFun: return "Focus timer, facts, system info, sounds"
        case .settings: return "Look, privacy, AI keys"
        case .home: return "Weather, battery, next up"
        case .clipboard: return "Search, pin and re-copy what you copied"
        case .todo: return "A quick to-do list"
        case .timer: return "Countdown timers and a stopwatch"
        case .world: return "Time in other cities"
        case .tools: return "Calculator, converter, keep awake, colour picker"
        case .shelf: return "Park files here, drag them out later"
        case .search: return "Find files and apps with Spotlight"
        case .snippets: return "Saved text, one click to copy"
        case .shortcuts: return "Run your Apple Shortcuts"
        case .translate: return "Translate text and read it aloud"
        }
    }
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
    case ocean, sunset, forest, rose, mint, gold, ice, crimson, graphite
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
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .forest: return "Forest"
        case .rose: return "Rose"
        case .mint: return "Mint"
        case .gold: return "Gold"
        case .ice: return "Ice"
        case .crimson: return "Crimson"
        case .graphite: return "Graphite"
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
        case .ocean: return Color(red: 0.22, green: 0.74, blue: 0.97)
        case .sunset: return Color(red: 0.98, green: 0.57, blue: 0.24)
        case .forest: return Color(red: 0.29, green: 0.87, blue: 0.5)
        case .rose: return Color(red: 0.96, green: 0.45, blue: 0.71)
        case .mint: return Color(red: 0.43, green: 0.91, blue: 0.78)
        case .gold: return Color(red: 0.98, green: 0.8, blue: 0.2)
        case .ice: return Color(red: 0.7, green: 0.88, blue: 1.0)
        case .crimson: return Color(red: 0.9, green: 0.15, blue: 0.3)
        case .graphite: return Color(white: 0.7)
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
        case .ocean: return [.black, Color(red: 0.0, green: 0.12, blue: 0.24)]
        case .sunset: return [.black, Color(red: 0.26, green: 0.08, blue: 0.1)]
        case .forest: return [.black, Color(red: 0.03, green: 0.15, blue: 0.06)]
        case .rose: return [.black, Color(red: 0.25, green: 0.04, blue: 0.14)]
        case .mint: return [.black, Color(red: 0.02, green: 0.18, blue: 0.15)]
        case .gold: return [.black, Color(red: 0.2, green: 0.15, blue: 0.02)]
        case .ice: return [.black, Color(red: 0.05, green: 0.12, blue: 0.2)]
        case .crimson: return [.black, Color(red: 0.2, green: 0.0, blue: 0.05)]
        case .graphite: return [.black, Color(white: 0.14)]
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
    case reaction, memory, maths, penalty, f1Lights, wordRush, game2048, snake
    var id: String { rawValue }

    var title: String {
        switch self {
        case .reaction: return "Reaction Time"
        case .memory: return "Memory Match"
        case .maths: return "Quick Maths"
        case .penalty: return "Penalty Shootout"
        case .f1Lights: return "F1 Reaction Lights"
        case .wordRush: return "Word Rush"
        case .game2048: return "2048"
        case .snake: return "Snake"
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
        case .game2048: return "square.grid.2x2.fill"
        case .snake: return "scribble.variable"
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
        case .game2048: return "Slide and merge tiles to reach 2048. Arrow keys."
        case .snake: return "Eat, grow, don't hit the walls or yourself."
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
    case anthropic, openai, gemini, groq, openRouter, deepSeek, ollama
    var id: String { rawValue }

    var title: String {
        switch self {
        case .anthropic: return "Anthropic (Claude)"
        case .openai: return "OpenAI (ChatGPT)"
        case .gemini: return "Google Gemini (free tier)"
        case .groq: return "Groq (free tier)"
        case .openRouter: return "OpenRouter (free models)"
        case .deepSeek: return "DeepSeek"
        case .ollama: return "Ollama (on this Mac, no key)"
        }
    }

    var keysPage: URL {
        switch self {
        case .anthropic: return URL(string: "https://console.anthropic.com/settings/keys")!
        case .openai: return URL(string: "https://platform.openai.com/api-keys")!
        case .gemini: return URL(string: "https://aistudio.google.com/app/apikey")!
        case .groq: return URL(string: "https://console.groq.com/keys")!
        case .openRouter: return URL(string: "https://openrouter.ai/keys")!
        case .deepSeek: return URL(string: "https://platform.deepseek.com/api_keys")!
        case .ollama: return URL(string: "https://ollama.com/download")!
        }
    }

    /// Model names change often. These are only starting points: edit them in Settings > AI.
    var defaultModel: String {
        switch self {
        case .anthropic: return "claude-sonnet-5-5"
        case .openai: return "gpt-4.1"
        case .gemini: return "gemini-2.0-flash"
        case .groq: return "llama-3.3-70b-versatile"
        case .openRouter: return "google/gemini-2.0-flash-exp:free"
        case .deepSeek: return "deepseek-chat"
        case .ollama: return "gemma3:4b"
        }
    }

    /// Providers that speak the common "OpenAI chat completions" format.
    var compatibleBaseURL: String? {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta/openai"
        case .groq: return "https://api.groq.com/openai/v1"
        case .openRouter: return "https://openrouter.ai/api/v1"
        case .deepSeek: return "https://api.deepseek.com/v1"
        case .ollama: return "http://localhost:11434/v1"
        case .anthropic, .openai: return nil
        }
    }

    var needsKey: Bool { self != .ollama }
    /// Web search through the provider is only wired up for these two.
    var supportsWebSearch: Bool { self == .anthropic || self == .openai }
    var isLocal: Bool { self == .ollama }

    var keychainAccount: String { "apikey.\(rawValue)" }
}

enum AIPersona: String, CaseIterable, Identifiable, Codable {
    case standard, tutor, concise, coder, friendly
    var id: String { rawValue }

    var title: String {
        switch self {
        case .standard: return "Standard"
        case .tutor: return "Patient tutor"
        case .concise: return "Very concise"
        case .coder: return "Senior engineer"
        case .friendly: return "Friendly coach"
        }
    }

    /// Extra instruction added to the AI's hidden instructions.
    var instruction: String {
        switch self {
        case .standard: return ""
        case .tutor: return "Persona: a patient tutor. Ask the student a guiding question when it helps them learn, and encourage them."
        case .concise: return "Persona: extremely concise. Use as few words as possible while staying correct."
        case .coder: return "Persona: a careful senior software engineer. Prefer precise technical language and small, correct code examples."
        case .friendly: return "Persona: a warm, upbeat study coach. Keep a positive tone without being childish."
        }
    }
}

enum AIMode: String, CaseIterable, Identifiable, Codable {
    case solve, explain, explainSimply, hint, homework, summarise, findSources, checkAnswer, translate, rewrite, code, quiz
    var id: String { rawValue }

    var title: String {
        switch self {
        case .solve: return "Solve"
        case .explain: return "Explain"
        case .hint: return "Hint"
        case .rewrite: return "Rewrite"
        case .code: return "Code"
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
        case .solve: return "function"
        case .explain: return "book"
        case .hint: return "questionmark.lightbulb"
        case .rewrite: return "pencil.line"
        case .code: return "chevron.left.forwardslash.chevron.right"
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
        case .solve: return "Type or paste a problem to solve…"
        case .explain: return "What do you want explained?"
        case .hint: return "Paste the problem. I'll give hints, not the answer…"
        case .rewrite: return "Paste text to rewrite…"
        case .code: return "Paste code or an error message…"
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
