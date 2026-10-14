import SwiftUI

// TennisView.swift
// Tennis scores (ATP / WTA). Demo Data unless you switch to Live.

struct TennisView: View {
    @EnvironmentObject private var model: TennisModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Tour", selection: $settings.prefs.tennisTour) {
                    Text("ATP").tag("atp"); Text("WTA").tag("wta")
                }
                .pickerStyle(.segmented).frame(width: 130).labelsHidden()
                Toggle("Live scores", isOn: $settings.prefs.tennisLive).toggleStyle(.switch)
                if model.isDemo { DemoBadge() }
                Spacer()
                if model.isLoading { ProgressView().controlSize(.small) }
                LNIconButton(systemName: "arrow.clockwise", label: "Refresh tennis scores") { reload() }
            }
            if settings.prefs.tennisLive {
                Text("Live mode asks ESPN's public scoreboard (no account). It is an unofficial feed and can change.")
                    .lnFont(9.5).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error = model.error { Text(error).lnFont(11).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(model.matches) { match in
                        VStack(alignment: .leading, spacing: 3) {
                            Text([match.tournament, match.round].filter { !$0.isEmpty }.joined(separator: " · "))
                                .lnFont(10).foregroundStyle(.secondary)
                            HStack {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(match.player1).lnFont(12.5, .semibold)
                                    Text(match.player2).lnFont(12.5, .semibold)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(match.scoreText).lnFont(12, .bold).monospacedDigit()
                                    Text(match.state == "in" ? "● LIVE \(match.detail)" : (match.state == "pre" ? timeText(match) : match.detail))
                                        .lnFont(10).foregroundStyle(match.state == "in" ? Color.green : Color.secondary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card(padding: 8)
                    }
                }
            }
        }
        .task(id: settings.prefs.tennisTour + String(settings.prefs.tennisLive)) { reload() }
    }

    private func timeText(_ match: TennisMatch) -> String {
        match.start.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? match.detail
    }

    private func reload() {
        Task { await model.refresh(tour: settings.prefs.tennisTour, live: settings.prefs.tennisLive) }
    }
}
