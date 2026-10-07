import SwiftUI
import AppKit
import UniformTypeIdentifiers

// PrivacySettingsCard.swift
// Settings > Privacy and data: see exactly what is stored, change permissions you gave, and reset.

struct PrivacySettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var env: AppEnvironment
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Privacy and data")

            Text("What LifeNotch stores on this Mac (nothing is synced or uploaded):")
                .lnFont(11, .semibold)
            Text("""
                 • Settings, assignments, study notes, streak and game scores.
                 • Browsing history: only if you turn it on (Settings > Browser).
                 • AI chat: only if you turn on "Remember my AI chat".
                 • Clipboard list and message notices: only if you opt in to keep them after quitting.
                 • API keys: in the macOS Keychain, never in files or backups.
                 Screenshots and documents you give the AI are never saved by LifeNotch.
                 """)
                .lnFont(10.5).foregroundStyle(.secondary)

            Toggle("Allow the optional Safari extension to pre-fill the AI tab", isOn: $settings.prefs.allowSafariExtension)
            Text("It only fills in the question box; nothing is sent until you press Send.").lnFont(10).foregroundStyle(.secondary)

            SectionTitle("Permissions you said \"Always allow\" to")
            if settings.prefs.grantedConsents.isEmpty {
                Text("None. LifeNotch asks each time.").lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(ConsentTopic.allCases.filter { settings.hasConsent($0) }) { topic in
                HStack {
                    Text(topic.title).lnFont(11.5)
                    Spacer()
                    Button("Ask me again") { settings.revoke(topic) }.buttonStyle(LNButtonStyle())
                }
            }

            HStack {
                Button("Show data folder in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([LocalStore.directory])
                }
                .buttonStyle(LNButtonStyle())
                Button("Remove all saved API keys") {
                    if ModalHelper.confirm(title: "Remove all saved API keys?",
                                           message: "This removes your AI and football-data keys from the macOS Keychain. The rest of your data stays.",
                                           confirmTitle: "Remove keys", destructive: true) {
                        for provider in AIProviderKind.allCases { KeychainStore.delete(account: provider.keychainAccount) }
                        KeychainStore.delete(account: SportsModel.footballKeyAccount)
                        message = "Keys removed."
                    }
                }
                .buttonStyle(LNButtonStyle())
            }

            SectionTitle("Backup everything")
            HStack {
                Button("Export all my data…") {
                    if let data = DataManagement.makeBackup(env: env),
                       FileDialogs.save(data: data, suggestedName: "LifeNotch-backup.json", type: .json) != nil {
                        message = "Backup saved."
                    }
                }
                .buttonStyle(LNButtonStyle())
                Button("Restore from a backup…") {
                    guard let url = FileDialogs.open(types: [.json], message: "Choose a LifeNotch backup file."),
                          let data = try? Data(contentsOf: url) else { return }
                    if ModalHelper.confirm(title: "Replace your current data?",
                                           message: "Restoring replaces your settings, assignments, notes, streak and scores with the backup.",
                                           confirmTitle: "Restore", destructive: true) {
                        message = DataManagement.restore(data, env: env) ? "Backup restored." : "That file isn't a LifeNotch backup."
                    }
                }
                .buttonStyle(LNButtonStyle())
            }

            SectionTitle("Reset")
            Button("Reset app data…") {
                let first = ModalHelper.confirm(
                    title: "Reset ALL LifeNotch data?",
                    message: "This deletes LifeNotch's own saved settings, assignments, notes, streak, scores, history and message notices. It does not touch any other files on your Mac. This cannot be undone.",
                    confirmTitle: "Reset everything", destructive: true)
                guard first else { return }
                let removeKeys = ModalHelper.confirm(
                    title: "Also remove your saved API keys?",
                    message: "Choose \"Keep keys\" to leave your AI key in the Keychain.",
                    confirmTitle: "Remove keys too", destructive: true)
                DataManagement.resetAll(env: env, alsoRemoveKeys: removeKeys)
                message = "All LifeNotch data was reset."
            }
            .buttonStyle(LNButtonStyle(destructive: true))
            if !message.isEmpty { Text(message).lnFont(11).foregroundStyle(.secondary) }
        }
        .card()
    }
}
