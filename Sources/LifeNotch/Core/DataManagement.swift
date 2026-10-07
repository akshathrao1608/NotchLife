import Foundation

// DataManagement.swift
// Backing up everything, and resetting everything. Both only ever touch LifeNotch's own data.

struct BackupBundle: Codable {
    var version = 1
    var exportedAt = Date()
    var preferences: Preferences
    var assignments: [Assignment]
    var notes: [StudyNote]
    var streak: StreakData
    var scores: GameScoresData
}

enum DataManagement {
    /// Everything LifeNotch stores, EXCEPT secrets (API keys, link token), browsing history,
    /// clipboard history, AI chats and message notices.
    static func makeBackup(env: AppEnvironment) -> Data? {
        let bundle = BackupBundle(preferences: env.settings.prefs,
                                  assignments: env.assignments.items,
                                  notes: env.notes.notes,
                                  streak: env.streak.data,
                                  scores: env.scores.data)
        return try? LocalStore.encoder().encode(bundle)
    }

    /// Replaces the current data with a backup file. Returns false if the file isn't a backup.
    static func restore(_ data: Data, env: AppEnvironment) -> Bool {
        guard let bundle = try? LocalStore.decoder().decode(BackupBundle.self, from: data) else { return false }
        LocalStore.save(bundle.assignments, name: "assignments.json")
        LocalStore.save(bundle.notes, name: "notes.json")
        LocalStore.save(bundle.streak, name: "streak.json")
        LocalStore.save(bundle.scores, name: "scores.json")
        env.assignments.reloadFromDisk()
        env.notes.reloadFromDisk()
        env.streak.reloadFromDisk()
        env.scores.reloadFromDisk()
        env.settings.prefs = bundle.preferences
        return true
    }

    /// Deletes LifeNotch's own saved data and settings. Other files on your Mac are never touched.
    static func resetAll(env: AppEnvironment, alsoRemoveKeys: Bool) {
        env.ambient.stop()
        env.ai.newChat()
        LocalStore.wipeAll()
        Preferences.erase()
        env.settings.resetPreferences()
        env.assignments.reloadFromDisk()
        env.notes.reloadFromDisk()
        env.streak.reloadFromDisk()
        env.scores.reloadFromDisk()
        env.history.clear()
        env.clipboard.clear()
        env.messages.wipe()
        NotificationManager.shared.replaceAll(prefix: "assignment.", with: [])
        NotificationManager.shared.replaceAll(prefix: "sports.", with: [])
        if alsoRemoveKeys {
            for provider in AIProviderKind.allCases { KeychainStore.delete(account: provider.keychainAccount) }
            KeychainStore.delete(account: SportsModel.footballKeyAccount)
        }
    }
}
