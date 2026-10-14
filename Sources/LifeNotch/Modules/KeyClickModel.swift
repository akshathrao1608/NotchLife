import AppKit
import CoreGraphics

// KeyClickModel.swift
// "Klick"-style keyboard sounds: a soft click each time you press a key, in any app.
// To notice key presses in other apps, macOS requires the "Input Monitoring" permission, so this is OFF until you
// turn it on, LifeNotch explains first, and macOS asks as well.
// Privacy: LifeNotch only hears THAT a key was pressed. It never looks at which key, never stores or sends anything.

final class KeyClickModel {
    static let sounds = ["Tink", "Pop", "Morse", "Bottle", "Purr", "Funk"]

    private var monitor: Any?
    private var lastPlayed = Date.distantPast
    private var volume: Float = 0.3
    private var soundName = "Tink"
    private var pool: [NSSound] = []
    private var poolIndex = 0

    var isRunning: Bool { monitor != nil }

    /// Returns false if macOS has not (yet) given permission.
    @discardableResult
    func start(soundName: String, volume: Double) -> Bool {
        configure(soundName: soundName, volume: volume)
        guard monitor == nil else { return true }
        guard CGPreflightListenEventAccess() else {
            _ = CGRequestListenEventAccess()
            return false
        }
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard !event.isARepeat else { return }
            self?.click()
        }
        return monitor != nil
    }

    func stop() {
        if let monitor = monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    func configure(soundName: String, volume: Double) {
        self.volume = Float(min(max(volume, 0), 1))
        if soundName != self.soundName || pool.isEmpty {
            self.soundName = soundName
            pool = (0..<6).compactMap { _ in NSSound(named: NSSound.Name(soundName))?.copy() as? NSSound }
        }
        pool.forEach { $0.volume = self.volume }
    }

    func preview() {
        guard !pool.isEmpty else { return }
        click()
    }

    private func click() {
        guard !pool.isEmpty, !SoundPlayer.isMuted else { return }
        let now = Date()
        guard now.timeIntervalSince(lastPlayed) > 0.025 else { return }
        lastPlayed = now
        let sound = pool[poolIndex % pool.count]
        poolIndex += 1
        sound.stop()
        sound.play()
    }
}
