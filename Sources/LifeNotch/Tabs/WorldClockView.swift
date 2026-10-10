import SwiftUI

// WorldClockView.swift
// Time in other cities, with day or night and the difference from your own time.

struct WorldClockView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var search = ""

    private var matches: [String] {
        guard search.count >= 2 else { return [] }
        return TimeZone.knownTimeZoneIdentifiers
            .filter { $0.replacingOccurrences(of: "_", with: " ").localizedCaseInsensitiveContains(search) }
            .prefix(8).map { $0 }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 10)], spacing: 10) {
                    ForEach(settings.prefs.worldClocks, id: \.self) { id in
                        if let zone = TimeZone(identifier: id) { clockCard(id: id, zone: zone, now: context.date) }
                    }
                }
            }
            HStack {
                TextField("Add a city (type a place, like Tokyo)", text: $search).textFieldStyle(.roundedBorder).frame(maxWidth: 300)
            }
            ForEach(matches, id: \.self) { id in
                Button {
                    if !settings.prefs.worldClocks.contains(id) { settings.prefs.worldClocks.append(id) }
                    search = ""
                } label: {
                    Label(id.replacingOccurrences(of: "_", with: " "), systemImage: "plus.circle").lnFont(12)
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
    }

    private func clockCard(id: String, zone: TimeZone, now: Date) -> some View {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let hour = calendar.component(.hour, from: now)
        let isDay = hour >= 7 && hour < 19
        let diffHours = Double(zone.secondsFromGMT(for: now) - TimeZone.current.secondsFromGMT(for: now)) / 3600
        let diffText = diffHours == 0 ? "same time" : String(format: "%+g h", diffHours)
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.timeStyle = .short
        return VStack(alignment: .leading, spacing: 2) {
            HStack {
                Image(systemName: isDay ? "sun.max.fill" : "moon.stars.fill").foregroundStyle(isDay ? Color.yellow : Color.indigo)
                Text((id.split(separator: "/").last.map(String.init) ?? id).replacingOccurrences(of: "_", with: " ")).lnFont(12, .semibold)
                Spacer()
                Button {
                    settings.prefs.worldClocks.removeAll { $0 == id }
                } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("Remove")
            }
            Text(formatter.string(from: now)).font(.system(size: 28, weight: .semibold, design: .rounded)).monospacedDigit()
            Text(diffText).lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
        .accessibilityElement(children: .combine)
    }
}
