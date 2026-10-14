import SwiftUI

// NotesSyncSettingsCard.swift
// Settings > Notes sync.

struct NotesSyncSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sync: NotesSync

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Notes sync")
            Text("Keep your notes as plain Markdown files in a folder you choose. Pick a folder in iCloud Drive (or Dropbox) and your notes follow you to other Macs. LifeNotch never connects to any cloud itself and never deletes files.")
                .lnFont(10.5).foregroundStyle(.secondary)
            if settings.prefs.notesSyncFolder.isEmpty {
                Button("Choose a folder…") { sync.chooseFolder() }.buttonStyle(LNButtonStyle(prominent: true))
            } else {
                Text(settings.prefs.notesSyncFolder).lnFont(10.5).textSelection(.enabled).lineLimit(2)
                HStack {
                    Button("Sync now") { sync.syncNow() }.buttonStyle(LNButtonStyle(prominent: true)).disabled(sync.isSyncing)
                    Button("Change folder…") { sync.chooseFolder() }.buttonStyle(LNButtonStyle())
                    Button("Turn off") { sync.stop() }.buttonStyle(LNButtonStyle())
                }
            }
            if !sync.status.isEmpty { Text(sync.status).lnFont(10.5).foregroundStyle(.secondary) }
        }
        .card()
    }
}
