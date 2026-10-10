import AppKit

// NowPlayingModel.swift
// Shows what is playing in Apple Music or Spotify and lets you play/pause/skip.
// It asks those two apps directly with AppleScript (public and documented). macOS shows its own
// "LifeNotch wants to control Music" question the first time. It only talks to an app that is
// ALREADY running (it never launches Music or Spotify), and it only checks while the Now Playing tab is open.

final class NowPlayingModel: ObservableObject {
    enum Source: String {
        case music = "Music"
        case spotify = "Spotify"

        var bundleID: String { self == .music ? "com.apple.Music" : "com.spotify.client" }
    }

    struct Track: Equatable {
        var title: String
        var artist: String
        var album: String
        var isPlaying: Bool
        var duration: Double      // seconds
        var position: Double      // seconds
        var artworkURL: URL?
        var source: Source
    }

    @Published private(set) var track: Track?
    @Published private(set) var message = ""

    private var timer: Timer?

    // MARK: Polling (only while the tab is on screen)

    func start() {
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func running(_ source: Source) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == source.bundleID }
    }

    func refresh() {
        var found: Track?
        for source in [Source.spotify, Source.music] where running(source) {
            if let t = read(source) {
                // Prefer whichever one is actually playing.
                if found == nil || t.isPlaying { found = t }
            }
        }
        if found == nil && message.isEmpty && !running(.music) && !running(.spotify) {
            message = "Open Music or Spotify and play something."
        }
        if found != nil { message = "" }
        track = found
    }

    func command(_ action: String) {
        guard let source = track?.source else { return }
        _ = run("tell application \"\(source.rawValue)\" to \(action)")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in self?.refresh() }
    }

    // MARK: AppleScript

    private func read(_ source: Source) -> Track? {
        let separator = "|||"
        let body: String
        switch source {
        case .music:
            body = """
            tell application "Music"
                if player state is stopped then return ""
                set t to current track
                return (name of t) & "\(separator)" & (artist of t) & "\(separator)" & (album of t) & "\(separator)" & (player state as text) & "\(separator)" & (duration of t as text) & "\(separator)" & (player position as text)
            end tell
            """
        case .spotify:
            body = """
            tell application "Spotify"
                if player state is stopped then return ""
                set t to current track
                return (name of t) & "\(separator)" & (artist of t) & "\(separator)" & (album of t) & "\(separator)" & (player state as text) & "\(separator)" & ((duration of t) / 1000 as text) & "\(separator)" & (player position as text) & "\(separator)" & (artwork url of t)
            end tell
            """
        }
        guard let text = run(body), !text.isEmpty else { return nil }
        let parts = text.components(separatedBy: separator)
        guard parts.count >= 6 else { return nil }
        func number(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        return Track(title: parts[0], artist: parts[1], album: parts[2],
                     isPlaying: parts[3].lowercased().contains("playing"),
                     duration: number(parts[4]), position: number(parts[5]),
                     artworkURL: parts.count > 6 ? URL(string: parts[6]) : nil,
                     source: source)
    }

    /// Runs a small AppleScript. Returns the text result, or nil if macOS refused or it failed.
    private func run(_ source: String) -> String? {
        var error: NSDictionary?
        guard let script = NSAppleScript(source: source) else { return nil }
        let result = script.executeAndReturnError(&error)
        if let error = error {
            let code = (error[NSAppleScript.errorNumber] as? Int) ?? 0
            if code == -1743 {
                message = "macOS blocked it. Allow LifeNotch under System Settings > Privacy & Security > Automation."
            }
            return nil
        }
        return result.stringValue
    }

    static func timeText(_ seconds: Double) -> String {
        let s = max(0, Int(seconds))
        return String(format: "%d:%02d", s / 60, s % 60)
    }
}
