import SwiftUI

// ActivitiesView.swift
// The Live Activities that are showing, and how to start your own.

struct ActivitiesView: View {
    @EnvironmentObject private var store: ActivityStore
    @EnvironmentObject private var settings: AppSettings

    private let example = "open \"lifenotch://activity?id=build&title=Build&progress=0.4&symbol=hammer.fill&detail=Compiling\""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Showing now (up to \(ActivityStore.maxActivities))")
                if store.activities.isEmpty {
                    Text("Nothing yet. Start one with a link, a Shortcut or Terminal (see right).").lnFont(11).foregroundStyle(.secondary)
                }
                ForEach(store.activities) { activity in
                    HStack {
                        Image(systemName: activity.symbol).frame(width: 22)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(activity.title).lnFont(12.5, .semibold)
                            if !activity.detail.isEmpty { Text(activity.detail).lnFont(10).foregroundStyle(.secondary) }
                            if let progress = activity.progress { ProgressView(value: progress) }
                        }
                        Spacer()
                        Button("End") { store.end(id: activity.id) }.buttonStyle(LNButtonStyle())
                    }
                    .card(padding: 8)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Start your own")
                Text("Run this in Terminal (or from any script or Shortcut). It only shows text and a bar; it never runs anything.")
                    .lnFont(10).foregroundStyle(.secondary)
                Text(example).font(.system(size: 10, design: .monospaced)).textSelection(.enabled)
                    .padding(6).background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
                Text("End it with  lifenotch://activity?id=build&action=end").lnFont(10).foregroundStyle(.secondary)
                Toggle("Allow links and Shortcuts to start activities", isOn: $settings.prefs.allowScriptLinks)
                Spacer(minLength: 0)
            }
            .frame(width: 280, alignment: .topLeading)
            .card()
        }
    }
}
