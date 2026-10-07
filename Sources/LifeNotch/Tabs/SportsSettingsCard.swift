import SwiftUI

// SportsSettingsCard.swift
// Settings > Sports: pick your favourites and where the data comes from.

struct SportsSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var sports: SportsModel
    @State private var keyDraft = ""
    @State private var hasKey = false
    @State private var newTeam = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Sports")

            Picker("F1 data", selection: $settings.prefs.f1Source) {
                ForEach(F1SourceChoice.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 420)
            .onChange(of: settings.prefs.f1Source) { _ in Task { await sports.refreshF1() } }

            Picker("Football data", selection: $settings.prefs.footballSource) {
                ForEach(FootballSourceChoice.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 420)
            .onChange(of: settings.prefs.footballSource) { _ in Task { await sports.refreshFootball() } }

            if settings.prefs.footballSource == .footballData {
                HStack {
                    SecureField(hasKey ? "A football-data.org key is saved (hidden)" : "Paste your football-data.org key",
                                text: $keyDraft)
                        .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                    Button("Save key") {
                        let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !trimmed.isEmpty { KeychainStore.set(trimmed, account: SportsModel.footballKeyAccount) }
                        keyDraft = ""
                        hasKey = KeychainStore.has(account: SportsModel.footballKeyAccount)
                        Task { await sports.refreshFootball() }
                    }
                    .buttonStyle(LNButtonStyle(prominent: true)).disabled(keyDraft.isEmpty)
                    if hasKey {
                        Button("Remove key") {
                            KeychainStore.delete(account: SportsModel.footballKeyAccount)
                            hasKey = false
                        }
                        .buttonStyle(LNButtonStyle(destructive: true))
                    }
                }
                Link("Get a free key at football-data.org", destination: URL(string: "https://www.football-data.org/client/register")!)
                    .lnFont(11)
            }
            Text("Demo Data is made-up sample data and is always labelled. Live F1 sends a plain request to api.jolpi.ca (no personal data). Live football sends your key to football-data.org.")
                .lnFont(10.5).foregroundStyle(.secondary)

            SectionTitle("Favourites")
            HStack {
                Text("F1 driver").lnFont(12).frame(width: 80, alignment: .leading)
                Picker("F1 driver", selection: $settings.prefs.favouriteDriver) {
                    ForEach(driverChoices, id: \.self) { Text($0).tag($0) }
                }
                .labelsHidden().frame(maxWidth: 220)
            }
            HStack {
                Text("F1 team").lnFont(12).frame(width: 80, alignment: .leading)
                TextField("e.g. McLaren", text: $settings.prefs.favouriteF1Team)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 220)
            }
            Text("Football teams").lnFont(12)
            WrappingChips(items: settings.prefs.favouriteFootballTeams) { team in
                settings.prefs.favouriteFootballTeams.removeAll { $0 == team }
            }
            HStack {
                TextField("Add a team, e.g. Arsenal", text: $newTeam)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 240)
                    .onSubmit(addTeam)
                Button("Add", action: addTeam).buttonStyle(LNButtonStyle(prominent: true)).disabled(newTeam.isEmpty)
            }
            Picker("League", selection: $settings.prefs.footballLeague) {
                ForEach(FootballLeague.all) { Text($0.name).tag($0.code) }
            }
            .frame(maxWidth: 300)

            SectionTitle("Reminders")
            Toggle("Notify me before a race or match starts (live data only)", isOn: Binding(
                get: { settings.prefs.sportsNotificationsEnabled },
                set: { newValue in
                    if newValue {
                        NotificationManager.shared.requestAuthorization { granted in
                            settings.prefs.sportsNotificationsEnabled = granted
                            sports.rescheduleNotifications()
                        }
                    } else {
                        settings.prefs.sportsNotificationsEnabled = false
                        sports.rescheduleNotifications()
                    }
                }
            ))
            Stepper("Remind me \(settings.prefs.sportsNotifyMinutesBefore) minutes before",
                    value: $settings.prefs.sportsNotifyMinutesBefore, in: 5...180, step: 5)
                .onChange(of: settings.prefs.sportsNotifyMinutesBefore) { _ in sports.rescheduleNotifications() }
            Text("Reminders are never created for Demo Data, so you won't get alerts for made-up events.")
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
        .onAppear { hasKey = KeychainStore.has(account: SportsModel.footballKeyAccount) }
    }

    private var driverChoices: [String] {
        var names = sports.driverStandings.map { $0.driver }
        if names.isEmpty { names = DemoF1Provider.drivers.map { $0.0 } }
        if !names.contains(settings.prefs.favouriteDriver) { names.insert(settings.prefs.favouriteDriver, at: 0) }
        return names
    }

    private func addTeam() {
        let name = newTeam.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty, !settings.prefs.favouriteFootballTeams.contains(name) else { return }
        settings.prefs.favouriteFootballTeams.append(name)
        newTeam = ""
    }
}

/// A row of removable "chips" (little labelled pills).
struct WrappingChips: View {
    let items: [String]
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack {
                ForEach(items, id: \.self) { item in
                    HStack(spacing: 4) {
                        Text(item).lnFont(11)
                        Button { onRemove(item) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(item)")
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.primary.opacity(0.12)))
                }
            }
        }
    }
}
