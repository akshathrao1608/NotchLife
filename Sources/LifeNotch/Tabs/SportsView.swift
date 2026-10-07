import SwiftUI

// SportsView.swift
// The Sports tab. Switch between Formula 1 and football at the top.

struct SportsView: View {
    @EnvironmentObject private var sports: SportsModel
    @EnvironmentObject private var settings: AppSettings

    private var isF1: Bool { settings.prefs.sportsPage != "football" }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Sport", selection: $settings.prefs.sportsPage) {
                    Label("Formula 1", systemImage: "flag.checkered").tag("f1")
                    Label("Football", systemImage: "soccerball").tag("football")
                }
                .pickerStyle(.segmented)
                .frame(width: 260)
                .labelsHidden()
                .accessibilityLabel("Choose sport")
                Spacer()
                if sports.isLoadingF1 || sports.isLoadingFootball { ProgressView().controlSize(.small) }
                if let updated = sports.lastUpdated {
                    Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
                        .lnFont(10).foregroundStyle(.secondary)
                }
                LNIconButton(systemName: "arrow.clockwise", label: "Refresh sports data") {
                    Task { await sports.refresh() }
                }
            }
            ScrollView {
                if isF1 { F1PageView() } else { FootballPageView() }
            }
        }
        .onAppear { Task { await sports.refreshIfStale() } }
    }
}

// MARK: - Formula 1

struct F1PageView: View {
    @EnvironmentObject private var sports: SportsModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let error = sports.f1Error {
                Label(error, systemImage: "exclamationmark.triangle.fill").lnFont(11).foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    nextRaceCard
                    latestCard
                }
                standingsCard
            }
        }
        .padding(.trailing, 6)
    }

    private var sourceBadge: some View {
        Group {
            if sports.f1IsDemo { DemoBadge() }
            else { Text(sports.f1ProviderName).lnFont(9.5).foregroundStyle(.secondary) }
        }
    }

    private var nextRaceCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { SectionTitle("Next race"); Spacer(); sourceBadge }
            if let race = sports.nextRace {
                Text(race.name).lnFont(15, .bold)
                Text("\(race.circuit) · \(race.locality), \(race.country)").lnFont(11).foregroundStyle(.secondary)
                Text(race.start.formatted(date: .complete, time: .shortened)).lnFont(11.5)
                TimelineView(.periodic(from: .now, by: 30)) { _ in
                    Text(Countdown.long(to: race.start))
                        .lnFont(17, .bold, design: .rounded)
                        .foregroundStyle(settings.prefs.theme.accent)
                }
            } else {
                Text("No upcoming race found.").lnFont(11).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var latestCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack { SectionTitle("Latest result"); Spacer(); sourceBadge }
            if let result = sports.latestResult {
                Text(result.raceName).lnFont(12, .semibold)
                ForEach(result.podium) { row in
                    HStack {
                        Text(["🥇", "🥈", "🥉"][min(max(row.position - 1, 0), 2)])
                        Text(row.driver).lnFont(12, .medium)
                        Text(row.team).lnFont(10.5).foregroundStyle(.secondary)
                        Spacer()
                        Text(row.timeOrStatus).lnFont(10.5).monospacedDigit().foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("No result yet.").lnFont(11).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var standingsCard: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack { SectionTitle("Drivers' championship"); Spacer(); sourceBadge }
            if sports.driverStandings.isEmpty {
                Text("Standings aren't available.").lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(sports.driverStandings.prefix(12)) { s in
                let favourite = s.driver == settings.prefs.favouriteDriver
                    || s.team.localizedCaseInsensitiveContains(settings.prefs.favouriteF1Team)
                HStack(spacing: 6) {
                    Text("\(s.position)").lnFont(11, .bold).frame(width: 20, alignment: .trailing)
                    Text(s.driver).lnFont(11.5, favourite ? .bold : .regular).lineLimit(1)
                    if s.driver == settings.prefs.favouriteDriver {
                        Image(systemName: "star.fill").foregroundStyle(.yellow).font(.system(size: 9))
                            .accessibilityLabel("Your favourite driver")
                    }
                    Spacer()
                    Text(s.team).lnFont(9.5).foregroundStyle(.secondary).lineLimit(1)
                    Text(String(format: "%g", s.points)).lnFont(11, .semibold).monospacedDigit().frame(width: 38, alignment: .trailing)
                }
                .padding(.vertical, 1)
                .background(favourite ? settings.prefs.theme.accent.opacity(0.15) : Color.clear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .card()
    }
}

// MARK: - Football

struct FootballPageView: View {
    @EnvironmentObject private var sports: SportsModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Picker("League", selection: $settings.prefs.footballLeague) {
                    ForEach(FootballLeague.all) { Text($0.name).tag($0.code) }
                }
                .frame(width: 230)
                .onChange(of: settings.prefs.footballLeague) { _ in Task { await sports.refreshFootball() } }
                if sports.footballIsDemo { DemoBadge() }
            }
            if let notice = sports.footballNotice {
                Label(notice, systemImage: "info.circle").lnFont(10.5).foregroundStyle(.orange)
            }
            if let error = sports.footballError {
                Label(error, systemImage: "exclamationmark.triangle.fill").lnFont(11).foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(spacing: 10) {
                    liveCard
                    fixturesCard
                    resultsCard
                }
                tableCard
            }
        }
        .padding(.trailing, 6)
    }

    private func matchRow(_ match: FootballMatch, showDate: Bool) -> some View {
        HStack(spacing: 6) {
            Text(match.home).lnFont(11.5, .medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .trailing)
            Text(match.status == .scheduled ? "vs" : match.scoreText)
                .lnFont(11.5, .bold).monospacedDigit().frame(width: 44)
            Text(match.away).lnFont(11.5, .medium).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            if showDate {
                Text(match.kickoff.formatted(date: .abbreviated, time: .shortened))
                    .lnFont(9.5).foregroundStyle(.secondary).frame(width: 96, alignment: .trailing)
            }
        }
    }

    private var liveCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Live now")
            if sports.liveMatches.isEmpty {
                Text("No matches in play.").lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(sports.liveMatches) { match in
                HStack {
                    Circle().fill(Color.red).frame(width: 7, height: 7).accessibilityHidden(true)
                    matchRow(match, showDate: false)
                    Text(match.minute ?? "LIVE").lnFont(10, .bold).foregroundStyle(.red)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var fixturesCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Next fixtures for your teams")
            if settings.prefs.favouriteFootballTeams.isEmpty {
                Text("Add favourite teams in Settings > Sports.").lnFont(11).foregroundStyle(.secondary)
            } else if sports.favouriteUpcoming.isEmpty {
                Text("No upcoming fixtures found for \(settings.prefs.favouriteFootballTeams.joined(separator: ", ")).")
                    .lnFont(11).foregroundStyle(.secondary)
            }
            ForEach(sports.favouriteUpcoming.prefix(5)) { match in
                matchRow(match, showDate: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var resultsCard: some View {
        VStack(alignment: .leading, spacing: 4) {
            SectionTitle("Recent results")
            ForEach(sports.recentResults.prefix(5)) { match in
                matchRow(match, showDate: true)
            }
            if sports.recentResults.isEmpty {
                Text("No recent results.").lnFont(11).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }

    private var tableCard: some View {
        VStack(alignment: .leading, spacing: 2) {
            SectionTitle("League table")
            HStack(spacing: 4) {
                Text("#").frame(width: 18, alignment: .trailing)
                Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                Text("P").frame(width: 22); Text("GD").frame(width: 28); Text("Pts").frame(width: 28)
            }
            .lnFont(9.5, .bold).foregroundStyle(.secondary)
            ForEach(sports.table.prefix(20)) { row in
                let favourite = sports.isFavouriteTeam(row.team, short: row.shortName)
                HStack(spacing: 4) {
                    Text("\(row.position)").frame(width: 18, alignment: .trailing)
                    Text(row.shortName.isEmpty ? row.team : row.shortName)
                        .lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                    Text("\(row.played)").frame(width: 22)
                    Text("\(row.goalDifference)").frame(width: 28)
                    Text("\(row.points)").frame(width: 28).fontWeight(.bold)
                }
                .lnFont(11, favourite ? .bold : .regular).monospacedDigit()
                .background(favourite ? settings.prefs.theme.accent.opacity(0.15) : Color.clear)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .card()
    }
}
