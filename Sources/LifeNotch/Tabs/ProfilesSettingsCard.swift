import SwiftUI

// ProfilesSettingsCard.swift
// Settings > Profiles.

struct ProfilesSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var store: ProfilesStore
    @State private var name = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Profiles")
            Text("Save how LifeNotch looks and behaves right now, then switch back with one click. Privacy answers and API keys are not part of a profile.")
                .lnFont(10.5).foregroundStyle(.secondary)
            HStack {
                TextField("Profile name, e.g. School", text: $name).textFieldStyle(.roundedBorder).frame(maxWidth: 220)
                Button("Save current settings") { store.save(name: name, from: settings.prefs); name = "" }
                    .buttonStyle(LNButtonStyle(prominent: true)).disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            ForEach(store.profiles) { profile in
                HStack {
                    Text(profile.name).lnFont(12, .semibold)
                    Spacer()
                    Button("Use") {
                        if let applied = ProfilesStore.applied(profile, over: settings.prefs) { settings.prefs = applied }
                    }
                    .buttonStyle(LNButtonStyle())
                    Button("Delete", role: .destructive) { store.delete(profile) }.buttonStyle(LNButtonStyle())
                }
            }
        }
        .card()
    }
}
