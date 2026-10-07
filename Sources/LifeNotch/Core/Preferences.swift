import Foundation

// Preferences.swift
// ALL of your settings live in this one struct (one box with many labelled slots).
// It is saved as a small JSON blob in the app's own preferences (UserDefaults).
// No settings are ever sent anywhere. API keys are NOT stored here; they go in the Keychain.

struct PinnedSite: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var url: String
}

struct QuickLaunchItem: Codable, Identifiable, Equatable {
    enum Kind: String, Codable { case app, website }
    var id = UUID()
    var kind: Kind
    var title: String
    /// For an app: its file path. For a website: its address.
    var target: String
}

struct Preferences: Codable, Equatable {
    // MARK: Look and feel
    var appearance: Appearance = .auto
    var theme: NotchTheme = .black
    var notchAnimation: NotchAnimationKind = .pulse
    var animationSpeed: Double = 1.0
    var reduceMotion = false
    var textScale: Double = 1.0
    var highContrast = false

    // MARK: Notch behaviour
    var hoverPreview = true
    var collapseOnOutsideClick = true
    var globalHotKeyEnabled = true
    var hotKey: HotKeyChoice = .optionSpace
    var tabShortcutsEnabled = true
    var lastTab: NotchTab = .ai
    var lastMacFunSection: MacFunSection = .focus

    // MARK: Compact bar (what shows beside the notch)
    var showAssignmentChip = true
    var showCountdownChip = true
    var countdownSource: CountdownSource = .f1
    var showMessagesChip = true
    var showTimerChip = true
    var showAIChip = true
    var showBrowserChip = true
    var showBestScoreChip = true
    var compactGame: GameKind = .reaction
    /// Width of the bar on EACH side of the camera notch, in points. 0 = fit the icons automatically.
    var compactSideWidth: Double = 0
    /// Show only icons in the bar (no text). Keeps the bar narrow so it doesn't cover menu-bar items.
    var compactIconsOnly = true
    /// Size of the open panel.
    var panelSize: PanelSize = .normal
    var showBattery = false      // off until you turn it on
    var showWifi = false         // off until you turn it on
    var showTime = false         // off until you turn it on

    // MARK: Browser
    var searchEngine: SearchEngine = .duckDuckGo
    var browserHistoryEnabled = false   // off: no history is kept
    var browserPrivateMode = false
    var blockPopups = true
    var warnOnRiskyLinks = true
    var pinnedSites: [PinnedSite] = [
        PinnedSite(title: "Google Classroom", url: "https://classroom.google.com"),
        PinnedSite(title: "Khan Academy", url: "https://www.khanacademy.org"),
        PinnedSite(title: "GitHub", url: "https://github.com"),
        PinnedSite(title: "YouTube", url: "https://www.youtube.com"),
        PinnedSite(title: "Wikipedia", url: "https://www.wikipedia.org"),
        PinnedSite(title: "Formula 1", url: "https://www.formula1.com"),
        PinnedSite(title: "BBC Football", url: "https://www.bbc.co.uk/sport/football")
    ]

    // MARK: AI
    var aiProvider: AIProviderKind = .anthropic
    var anthropicModel = AIProviderKind.anthropic.defaultModel
    var openAIModel = AIProviderKind.openai.defaultModel
    var aiWebSearchDefault = false
    var aiRememberChat = false          // off: chats vanish when you quit
    var aiTranslateTarget = "Spanish"
    var storeAttachmentsLocally = false // off: attachments are never saved by LifeNotch

    // MARK: Privacy
    /// Permission "yes, always" answers you gave (see ConsentGate). You can revoke them in Settings.
    var grantedConsents: [String] = []
    var allowSafariExtension = false
    var clipboardHistoryEnabled = false
    var clipboardKeepAfterQuit = false
    var messagesEnabled = false
    var messagesShowPreviews = false
    var messagesDoNotDisturb = false
    var messagesRemember = false
    var assignmentReminders = false

    // MARK: Sports
    var f1Source: F1SourceChoice = .demo
    var footballSource: FootballSourceChoice = .demo
    var favouriteDriver = "Lando Norris"
    var favouriteF1Team = "McLaren"
    var favouriteFootballTeams: [String] = ["Arsenal"]
    var footballLeague = "PL"
    var sportsPage = "f1"            // "f1" or "football": the last page you looked at
    var sportsNotificationsEnabled = false
    var sportsNotifyMinutesBefore = 30

    // MARK: Games & sound
    var soundMuted = false

    // MARK: Focus timer
    var workMinutes = 25
    var shortBreakMinutes = 5
    var longBreakMinutes = 15
    var sessionsBeforeLongBreak = 4
    var focusNotifications = false   // off: no notification when a session ends

    // MARK: Mac Fun
    var ambientVolume = 0.4
    var quickLaunch: [QuickLaunchItem] = []
    var completionSounds = true
    var cleanDeskChecked: [String] = []

    // MARK: Loading / saving

    private static let key = "lifenotch.preferences.v1"

    /// Loads saved settings. If a newer version of the app added new settings, they
    /// get their default values instead of making the load fail.
    static func load() -> Preferences {
        let defaults = Preferences()
        guard let stored = UserDefaults.standard.data(forKey: key),
              let baseData = try? JSONEncoder().encode(defaults),
              var base = (try? JSONSerialization.jsonObject(with: baseData)) as? [String: Any],
              let overlay = (try? JSONSerialization.jsonObject(with: stored)) as? [String: Any]
        else { return defaults }
        for (k, v) in overlay { base[k] = v }
        guard let merged = try? JSONSerialization.data(withJSONObject: base),
              let prefs = try? JSONDecoder().decode(Preferences.self, from: merged)
        else { return defaults }
        return prefs
    }

    static func save(_ prefs: Preferences) {
        if let data = try? JSONEncoder().encode(prefs) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func erase() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
