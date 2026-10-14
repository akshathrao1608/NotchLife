import Foundation

// ProfilesStore.swift
// Profiles: save your current look and behaviour settings under a name ("School", "Gaming", "Work")
// and switch between them in one click. Only settings are stored (never API keys, which stay in the
// Keychain), and your privacy "Always allow" answers are NOT changed by switching profiles.

struct SettingsProfile: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var data: Data
}

final class ProfilesStore: ObservableObject {
    @Published private(set) var profiles: [SettingsProfile]
    private static let fileName = "profiles.json"

    init() { profiles = LocalStore.load([SettingsProfile].self, name: Self.fileName) ?? [] }

    func save(name: String, from prefs: Preferences) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, let data = try? JSONEncoder().encode(prefs) else { return }
        if let index = profiles.firstIndex(where: { $0.name.lowercased() == trimmed.lowercased() }) {
            profiles[index].data = data
        } else {
            profiles.append(SettingsProfile(name: trimmed, data: data))
        }
        persist()
    }

    /// The preferences a profile would apply, with the CURRENT privacy answers kept.
    static func applied(_ profile: SettingsProfile, over current: Preferences) -> Preferences? {
        guard var loaded = try? JSONDecoder().decode(Preferences.self, from: profile.data) else { return nil }
        loaded.grantedConsents = current.grantedConsents
        return loaded
    }

    func delete(_ profile: SettingsProfile) {
        profiles.removeAll { $0.id == profile.id }
        persist()
    }

    private func persist() { LocalStore.save(profiles, name: Self.fileName) }
}
