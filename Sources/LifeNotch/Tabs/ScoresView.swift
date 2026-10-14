import SwiftUI

// ScoresView.swift
// The Scores tab, in the spirit of Apple Sports: choose the sports, leagues and teams YOU follow, then see
// their live scores, results and fixtures, tap a match for detailed stats, and browse any league's table.

enum ScoresPage: String, CaseIterable, Identifiable {
    case mine = "My Sports", browse = "Browse", table = "Tables"
    var id: String { rawValue }
}

struct ScoresView: View {
    @EnvironmentObject private var store: ScoresStore
    @EnvironmentObject private var settings: AppSettings
    @State private var page: ScoresPage = .mine
    @State private var selectedGame: SGame?
    @State private var showPicker = false

    var body: some View {
        Group {
            if let game = selectedGame {
                GameDetailView(game: game) { selectedGame = nil }
            } else if showPicker {
                FollowPickerView { showPicker = false }
            } else {
                VStack(spacing: 8) {
                    header
                    switch page {
                    case .mine: MySportsView(select: { selectedGame = $0 }, manage: { showPicker = true })
                    case .browse: BrowseView(select: { selectedGame = $0 })
                    case .table: TablesView()
                    }
                }
            }
        }
        .task {
            // Refresh now, then every 30 s while something is live (otherwise every 2 minutes), only while this tab is open.
            while !Task.isCancelled {
                await store.refreshFollowed()
                try? await Task.sleep(nanoseconds: (store.hasLiveGames ? 30 : 120) * 1_000_000_000)
            }
        }
    }

    private var header: some View {
        HStack {
            Picker("", selection: $page) {
                ForEach(ScoresPage.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 270).labelsHidden()
            Spacer()
            if store.isLoading { ProgressView().controlSize(.small) }
            if let updated = store.updated {
                Text("Updated \(updated.formatted(date: .omitted, time: .shortened))").lnFont(10).foregroundStyle(.secondary)
            }
            LNIconButton(systemName: "arrow.clockwise", label: "Refresh scores") { Task { await store.refreshFollowed() } }
            LNIconButton(systemName: "star.circle.fill", label: "Choose sports and teams") { showPicker = true }
        }
    }
}

// MARK: - My Sports

struct MySportsView: View {
    @EnvironmentObject private var store: ScoresStore
    @EnvironmentObject private var settings: AppSettings
    let select: (SGame) -> Void
    let manage: () -> Void

    var body: some View {
        if !store.hasFollows {
            VStack(spacing: 10) {
                EmptyStateView(icon: "star.circle", title: "Pick what you follow",
                               message: "Choose sports, leagues and teams. Their live scores, results and fixtures show up here, and your next match appears in the notch bar.")
                Button("Choose sports and teams") { manage() }.buttonStyle(LNButtonStyle(prominent: true))
            }
            .frame(maxWidth: .infinity)
        } else {
            let games = store.myGames
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = store.error { Text(error).lnFont(10.5).foregroundStyle(.orange) }
                    section("Live", games.filter { $0.state == .live })
                    section("Coming up", games.filter { $0.state == .scheduled })
                    section("Results", Array(games.filter { $0.state == .final }.prefix(12)))
                    if games.isEmpty && !store.isLoading {
                        Text("No matches in the last 2 days or the next 7 for what you follow.").lnFont(11).foregroundStyle(.secondary)
                    }
                    Toggle("Remind me 15 minutes before my teams play", isOn: reminderBinding).lnFont(10.5)
                    Text("Scores from ESPN's public feed (unofficial). Times and scores can lag a little behind the real match.")
                        .lnFont(9.5).foregroundStyle(.secondary)
                }
                .padding(.trailing, 6)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String, _ games: [SGame]) -> some View {
        if !games.isEmpty {
            Text(title.uppercased()).lnFont(10, .bold).foregroundStyle(title == "Live" ? Color.red : Color.secondary)
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                ForEach(games) { game in
                    Button { select(game) } label: { GameCard(game: game, followed: store.isFollowedTeamGame(game)) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var reminderBinding: Binding<Bool> {
        Binding(
            get: { settings.prefs.scoresNotifications },
            set: { on in
                if on {
                    NotificationManager.shared.requestAuthorization { granted in
                        settings.prefs.scoresNotifications = granted
                        if granted { Task { await store.refreshFollowed() } }
                    }
                } else {
                    settings.prefs.scoresNotifications = false
                    Task { await store.refreshFollowed() }
                }
            })
    }
}

// MARK: - Cards

struct TeamBadge: View {
    let side: SSide
    var size: CGFloat = 26

    var body: some View {
        ZStack {
            Circle().fill(ScoreColor.color(hex: side.colorHex).opacity(0.35))
            if let logo = side.logo {
                AsyncImage(url: logo) { image in
                    image.resizable().scaledToFit().padding(3)
                } placeholder: {
                    Text(side.abbr.prefix(3)).font(.system(size: size * 0.32, weight: .bold))
                }
            } else {
                Text(side.abbr.prefix(3)).font(.system(size: size * 0.32, weight: .bold))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

enum ScoreColor {
    static func color(hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return Color.gray }
        return Color(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

struct GameCard: View {
    let game: SGame
    var followed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                statusLabel
                Spacer()
                Text(SportsCatalog.league(game.leagueID)?.title ?? "").lnFont(9.5).foregroundStyle(.secondary).lineLimit(1)
            }
            if game.first != nil || game.second != nil {
                if let first = game.first { row(first, game: game) }
                if let second = game.second { row(second, game: game) }
            } else {
                Text(game.title).lnFont(12.5, .semibold).lineLimit(2)
                ForEach(game.rows.prefix(3)) { row in
                    HStack {
                        Text("\(row.position)").lnFont(11, .bold).frame(width: 18)
                        Text(row.name).lnFont(11.5).lineLimit(1)
                        Spacer()
                        Text(row.value).lnFont(11, .semibold).monospacedDigit()
                    }
                }
            }
            let extra = [game.note, game.broadcast].filter { !$0.isEmpty }.joined(separator: " · ")
            if !extra.isEmpty { Text(extra).lnFont(9.5).foregroundStyle(.secondary).lineLimit(1) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 9)
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(followed ? Color.accentColor.opacity(0.6) : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var statusLabel: some View {
        switch game.state {
        case .live:
            Label(game.statusText.isEmpty ? "LIVE" : game.statusText, systemImage: "circle.fill")
                .lnFont(10.5, .bold).foregroundStyle(.red).labelStyle(CompactLiveLabel())
        case .scheduled:
            Text(game.start.map { $0.formatted(date: .abbreviated, time: .shortened) } ?? game.statusText).lnFont(10.5, .semibold).foregroundStyle(.secondary)
        case .final:
            Text(game.statusText.isEmpty ? "Final" : game.statusText).lnFont(10.5, .semibold).foregroundStyle(.secondary)
        }
    }

    private func row(_ side: SSide, game: SGame) -> some View {
        let dim = game.state == .final && !side.winner && (game.first?.winner == true || game.second?.winner == true)
        return HStack(spacing: 8) {
            TeamBadge(side: side)
            VStack(alignment: .leading, spacing: 0) {
                Text(side.name).lnFont(12, side.winner ? .bold : .semibold).lineLimit(1)
                if !side.record.isEmpty { Text(side.record).lnFont(9).foregroundStyle(.secondary) }
            }
            Spacer()
            if !side.lines.isEmpty && game.state != .scheduled {
                Text(side.lines.joined(separator: " ")).lnFont(9.5).foregroundStyle(.secondary).monospacedDigit().lineLimit(1)
            }
            Text(game.state == .scheduled ? "" : side.score).lnFont(15, .bold).monospacedDigit().frame(minWidth: 22, alignment: .trailing)
        }
        .opacity(dim ? 0.55 : 1)
    }
}

struct CompactLiveLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 3) {
            configuration.icon.font(.system(size: 6))
            configuration.title
        }
    }
}

// MARK: - Browse any league

struct BrowseView: View {
    @EnvironmentObject private var store: ScoresStore
    @EnvironmentObject private var settings: AppSettings
    let select: (SGame) -> Void
    @State private var day = Date()

    private var league: SportsLeague {
        SportsCatalog.league(settings.prefs.scoresBrowseLeague) ?? SportsCatalog.leagues[0]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("League", selection: $settings.prefs.scoresBrowseLeague) {
                    ForEach(SportGroup.allCases) { group in
                        Section(group.title) {
                            ForEach(SportsCatalog.leagues(in: group)) { Text($0.title).tag($0.id) }
                        }
                    }
                }
                .frame(width: 220)
                Spacer()
                if league.kind == .teams {
                    LNIconButton(systemName: "chevron.left", label: "Previous day") { shift(-1) }
                    Text(Calendar.current.isDateInToday(day) ? "Today" : day.formatted(date: .abbreviated, time: .omitted)).lnFont(11, .semibold).frame(minWidth: 80)
                    LNIconButton(systemName: "chevron.right", label: "Next day") { shift(1) }
                }
                if store.browseLoading { ProgressView().controlSize(.small) }
            }
            if let error = store.browseError { Text(error).lnFont(10.5).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            ScrollView {
                if store.browseGames.isEmpty && !store.browseLoading && store.browseError == nil {
                    Text("No matches listed for this day.").lnFont(11).foregroundStyle(.secondary)
                }
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    ForEach(store.browseGames) { game in
                        Button { select(game) } label: { GameCard(game: game, followed: store.isFollowedTeamGame(game)) }.buttonStyle(.plain)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .task(id: settings.prefs.scoresBrowseLeague + day.formatted(date: .numeric, time: .omitted)) {
            await store.loadBrowse(league: league, day: day)
        }
    }

    private func shift(_ days: Int) {
        day = Calendar.current.date(byAdding: .day, value: days, to: day) ?? day
    }
}

// MARK: - Tables

struct TablesView: View {
    @EnvironmentObject private var store: ScoresStore
    @EnvironmentObject private var settings: AppSettings

    private var league: SportsLeague {
        let teamLeagues = SportsCatalog.leagues.filter { $0.kind == .teams }
        return teamLeagues.first { $0.id == settings.prefs.scoresTableLeague } ?? teamLeagues[0]
    }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("League", selection: $settings.prefs.scoresTableLeague) {
                    ForEach(SportsCatalog.leagues.filter { $0.kind == .teams }) { Text($0.title).tag($0.id) }
                }
                .frame(width: 220)
                Spacer()
                if store.standingsLoading { ProgressView().controlSize(.small) }
            }
            if let error = store.standingsError { Text(error).lnFont(10.5).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(store.standings) { group in
                        VStack(alignment: .leading, spacing: 3) {
                            if !group.name.isEmpty { Text(group.name).lnFont(11, .bold) }
                            HStack {
                                Text("#").frame(width: 22, alignment: .leading)
                                Text("Team").frame(maxWidth: .infinity, alignment: .leading)
                                ForEach(Array(group.columns.enumerated()), id: \.offset) { _, column in
                                    Text(column).frame(width: 42, alignment: .trailing)
                                }
                            }
                            .lnFont(9.5, .bold).foregroundStyle(.secondary)
                            ForEach(group.rows) { row in
                                let followed = store.follows.teams.contains { $0.leagueID == league.id && $0.teamID == row.id }
                                HStack {
                                    Text("\(row.rank)").frame(width: 22, alignment: .leading)
                                    Text(row.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                    ForEach(Array(row.values.enumerated()), id: \.offset) { _, value in
                                        Text(value).monospacedDigit().frame(width: 42, alignment: .trailing)
                                    }
                                }
                                .lnFont(11, followed ? .bold : .regular)
                                .foregroundStyle(followed ? Color.accentColor : Color.primary)
                            }
                        }
                        .card(padding: 8)
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .task(id: settings.prefs.scoresTableLeague) { await store.loadStandings(league: league) }
    }
}

// MARK: - Choose what to follow

struct FollowPickerView: View {
    @EnvironmentObject private var store: ScoresStore
    @State private var selectedID = SportsCatalog.leagues[0].id
    let close: () -> Void

    private var selected: SportsLeague { SportsCatalog.league(selectedID) ?? SportsCatalog.leagues[0] }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Choose what you follow").lnFont(13, .bold)
                Spacer()
                Button("Done") { close() }.buttonStyle(LNButtonStyle(prominent: true))
            }
            HStack(alignment: .top, spacing: 10) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(SportGroup.allCases) { group in
                            Label(group.title, systemImage: group.icon).lnFont(10.5, .bold).foregroundStyle(.secondary).padding(.top, 4)
                            ForEach(SportsCatalog.leagues(in: group)) { league in
                                HStack {
                                    Button { selectedID = league.id } label: {
                                        Text(league.title).lnFont(11.5, selectedID == league.id ? .bold : .regular)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .buttonStyle(.plain)
                                    Button { store.toggle(league: league.id) } label: {
                                        Image(systemName: store.isFollowing(league: league.id) ? "star.fill" : "star")
                                            .foregroundStyle(store.isFollowing(league: league.id) ? Color.yellow : Color.secondary)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("\(store.isFollowing(league: league.id) ? "Unfollow" : "Follow") \(league.title)")
                                }
                            }
                        }
                    }
                    .padding(.trailing, 6)
                }
                .frame(width: 230)
                .card(padding: 8)

                VStack(alignment: .leading, spacing: 6) {
                    Text(selected.title).lnFont(12.5, .bold)
                    if selected.kind != .teams {
                        Text("Follow the star to see every \(selected.title) event. (Individual players aren't followable here.)")
                            .lnFont(10.5).foregroundStyle(.secondary)
                    } else if store.teamsLoading {
                        ProgressView().controlSize(.small)
                    } else if store.teamOptions.isEmpty {
                        Text("Couldn't load the teams. Check your connection.").lnFont(10.5).foregroundStyle(.orange)
                    } else {
                        Text("Tap the star to follow a team.").lnFont(10).foregroundStyle(.secondary)
                        ScrollView {
                            VStack(spacing: 3) {
                                ForEach(store.teamOptions) { team in
                                    Button { store.toggle(team: team, in: selected.id) } label: {
                                        HStack {
                                            TeamBadge(side: SSide(id: team.id, name: team.name, abbr: team.abbr, score: "", record: "", logo: team.logo, colorHex: "", winner: false, lines: []), size: 22)
                                            Text(team.name).lnFont(11.5)
                                            Spacer()
                                            Image(systemName: store.isFollowing(team: team, in: selected.id) ? "star.fill" : "star")
                                                .foregroundStyle(store.isFollowing(team: team, in: selected.id) ? Color.yellow : Color.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
                .card(padding: 8)
            }
        }
        .task(id: selectedID) { await store.loadTeams(league: selected) }
    }
}

// MARK: - Match detail

enum DetailTab: String, CaseIterable, Identifiable {
    case stats = "Stats", players = "Players", timeline = "Timeline", info = "Info"
    var id: String { rawValue }
}

struct GameDetailView: View {
    @EnvironmentObject private var store: ScoresStore
    let game: SGame
    let back: () -> Void
    @State private var tab: DetailTab = .stats

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Button { back() } label: { Label("Back", systemImage: "chevron.left") }.buttonStyle(LNButtonStyle())
                Spacer()
                if store.detailLoading { ProgressView().controlSize(.small) }
                Button { Task { await store.loadDetail(for: game) } } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
            }
            GameCard(game: currentGame)
            if game.first != nil || game.second != nil {
                Picker("", selection: $tab) {
                    ForEach(DetailTab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).labelsHidden().frame(width: 320)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if let error = store.detailError { Text(error).lnFont(11).foregroundStyle(.secondary) }
                    if currentGame.first == nil && currentGame.second == nil {
                        leaderboard
                    } else if let detail = store.detail {
                        switch tab {
                        case .stats: stats(detail)
                        case .players: players(detail)
                        case .timeline: timeline(detail)
                        case .info: info(detail)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
        }
        .task { await store.loadDetail(for: game) }
    }

    /// The freshest copy of this game (scores keep updating while the page is open).
    private var currentGame: SGame {
        for games in store.gamesByLeague.values { if let found = games.first(where: { $0.id == game.id }) { return found } }
        return store.browseGames.first(where: { $0.id == game.id }) ?? game
    }

    private var leaderboard: some View {
        VStack(spacing: 3) {
            ForEach(currentGame.rows) { row in
                HStack {
                    Text("\(row.position)").lnFont(11, .bold).frame(width: 24, alignment: .leading)
                    Text(row.name).lnFont(12)
                    Spacer()
                    Text(row.value).lnFont(12, .semibold).monospacedDigit()
                }
            }
        }
        .card(padding: 8)
    }

    private func stats(_ detail: GameDetail) -> some View {
        VStack(spacing: 6) {
            if detail.teamStats.isEmpty && detail.leaders.isEmpty { Text("No team stats for this match.").lnFont(11).foregroundStyle(.secondary) }
            if !detail.teamStats.isEmpty {
                VStack(spacing: 4) {
                    HStack {
                        Text(currentGame.first?.abbr ?? "").lnFont(10.5, .bold)
                        Spacer()
                        Text(currentGame.second?.abbr ?? "").lnFont(10.5, .bold)
                    }
                    ForEach(detail.teamStats) { row in
                        HStack {
                            Text(row.first).lnFont(11.5, .semibold).monospacedDigit().frame(width: 70, alignment: .leading)
                            Spacer()
                            Text(row.label).lnFont(10.5).foregroundStyle(.secondary)
                            Spacer()
                            Text(row.second).lnFont(11.5, .semibold).monospacedDigit().frame(width: 70, alignment: .trailing)
                        }
                    }
                }
                .card(padding: 8)
            }
            if !detail.leaders.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Top performers").lnFont(11, .bold)
                    ForEach(detail.leaders) { leader in
                        HStack {
                            Text(leader.category).lnFont(10).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
                            Text(leader.name).lnFont(11.5)
                            Spacer()
                            Text(leader.value).lnFont(11.5, .bold).monospacedDigit()
                        }
                    }
                }
                .card(padding: 8)
            }
        }
    }

    private func players(_ detail: GameDetail) -> some View {
        VStack(spacing: 8) {
            if detail.tables.isEmpty { Text("No player stats for this match.").lnFont(11).foregroundStyle(.secondary) }
            ForEach(detail.tables) { table in
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(table.team) · \(table.title)").lnFont(11, .bold)
                    if !table.labels.isEmpty {
                        HStack(spacing: 6) {
                            Text("").frame(width: 120, alignment: .leading)
                            ForEach(Array(table.labels.enumerated()), id: \.offset) { _, label in
                                Text(label).frame(minWidth: 28, alignment: .trailing)
                            }
                        }
                        .lnFont(9, .bold).foregroundStyle(.secondary)
                    }
                    ForEach(Array(table.rows.enumerated()), id: \.offset) { _, row in
                        HStack(spacing: 6) {
                            Text(row.first ?? "").lineLimit(1).frame(width: 120, alignment: .leading)
                            ForEach(Array(row.dropFirst().enumerated()), id: \.offset) { _, value in
                                Text(value).monospacedDigit().frame(minWidth: 28, alignment: .trailing)
                            }
                        }
                        .lnFont(10.5)
                    }
                }
                .card(padding: 8)
            }
        }
    }

    private func timeline(_ detail: GameDetail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if detail.timeline.isEmpty { Text("No key events yet.").lnFont(11).foregroundStyle(.secondary) }
            ForEach(detail.timeline) { item in
                HStack(alignment: .top) {
                    Text(item.time).lnFont(10.5, .bold).monospacedDigit().frame(width: 56, alignment: .leading)
                    VStack(alignment: .leading, spacing: 1) {
                        if !item.title.isEmpty { Text(item.title).lnFont(10.5, .semibold) }
                        if !item.text.isEmpty { Text(item.text).lnFont(11) }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 8)
    }

    private func info(_ detail: GameDetail) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            let g = currentGame
            if !g.venue.isEmpty { Text("Venue: \(g.venue)").lnFont(11) }
            if !g.broadcast.isEmpty { Text("TV: \(g.broadcast)").lnFont(11) }
            if !g.odds.isEmpty { Text("Odds: \(g.odds) (information only)").lnFont(11) }
            ForEach(detail.info, id: \.self) { Text($0).lnFont(11) }
            Text("Source: ESPN public feed (unofficial).").lnFont(9.5).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card(padding: 8)
    }
}
