import SwiftUI

// BrowserSettingsCard.swift
// Settings > Browser: search engine, history, private mode, pop-ups, pinned sites.

struct BrowserSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var history: BrowsingHistory
    @EnvironmentObject private var browser: BrowserModel
    @State private var newTitle = ""
    @State private var newURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Browser")
            Picker("Default search engine", selection: $settings.prefs.searchEngine) {
                ForEach(SearchEngine.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 340)

            Toggle("Keep browsing history (off = nothing is recorded)", isOn: $settings.prefs.browserHistoryEnabled)
            if !history.entries.isEmpty {
                Button("Clear saved history (\(history.entries.count))") { history.clear() }
                    .buttonStyle(LNButtonStyle())
            }
            Toggle("Private mode (no history; cookies and form data are discarded)", isOn: Binding(
                get: { settings.prefs.browserPrivateMode },
                set: { browser.setPrivate($0) }
            ))
            Toggle("Block pop-ups", isOn: $settings.prefs.blockPopups)
            Toggle("Warn me about suspicious links", isOn: $settings.prefs.warnOnRiskyLinks)
            Text("Download links are never downloaded by LifeNotch. You are always asked first and can open them in your default browser.")
                .lnFont(10.5).foregroundStyle(.secondary)

            SectionTitle("Pinned websites")
            ForEach(settings.prefs.pinnedSites) { site in
                HStack {
                    Text(site.title).lnFont(12)
                    Text(site.url).lnFont(10.5).foregroundStyle(.secondary).lineLimit(1)
                    Spacer()
                    Button {
                        settings.prefs.pinnedSites.removeAll { $0.id == site.id }
                    } label: { Image(systemName: "trash") }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove \(site.title)")
                }
            }
            HStack {
                TextField("Name", text: $newTitle).textFieldStyle(.roundedBorder).frame(width: 130)
                TextField("https://…", text: $newURL).textFieldStyle(.roundedBorder)
                Button("Add") {
                    var address = newURL.trimmingCharacters(in: .whitespaces)
                    if !address.lowercased().hasPrefix("http") { address = "https://" + address }
                    guard URL(string: address)?.host != nil else { return }
                    let title = newTitle.trimmingCharacters(in: .whitespaces)
                    settings.prefs.pinnedSites.append(PinnedSite(title: title.isEmpty ? address : title, url: address))
                    newTitle = ""
                    newURL = ""
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                .disabled(newURL.isEmpty)
            }
        }
        .card()
    }
}
