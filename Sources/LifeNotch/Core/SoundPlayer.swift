import AppKit

// SoundPlayer.swift
// Plays the short built-in macOS sounds (the same ones as System Settings > Sound).
// No sound files are bundled. The mute switch in Settings / Mini Games turns all of them off.

enum SoundEffect {
    case tap, success, fail, start, complete, win, lose, tick

    var systemSoundName: String {
        switch self {
        case .tap: return "Tink"
        case .success: return "Glass"
        case .fail: return "Basso"
        case .start: return "Hero"
        case .complete: return "Funk"
        case .win: return "Hero"
        case .lose: return "Sosumi"
        case .tick: return "Pop"
        }
    }
}

enum SoundPlayer {
    /// Kept in sync with the "Mute" setting.
    static var isMuted = false
    private static var playing: [NSSound] = []

    static func play(_ effect: SoundEffect) {
        guard !isMuted else { return }
        guard let base = NSSound(named: NSSound.Name(effect.systemSoundName)),
              let sound = base.copy() as? NSSound else { return }
        sound.volume = 0.5
        playing.append(sound)
        if playing.count > 8 { playing.removeFirst(playing.count - 8) }
        sound.play()
    }
}
