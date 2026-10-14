import Foundation

// ScoresStore.swift
// The brain of the Scores tab. It remembers which leagues and teams YOU follow (saved on this Mac),
// fetches only those, and keeps the latest games for the tab, the notch bar and optional reminders.
//
// Data source: ESPN's public scoreboard / summary / standings feeds (no account or key). They are unofficial
// but cover nearly every major sport with very detailed stats (team stats, player box scores, key events,
// leaders, line-ups, standings). Official data from Sportradar, Opta or similar needs paid keys. If a feed fails
// you see the error; nothing is made up.

struct ScoresCompact {
    let icon: String
    let text: String
    let isLive: Bool
    let label: String
}

final class ScoresStore: ObservableObject {
    @Published private(set) var follows: SportsFollows
    @Published private(set) var gamesByLeague: [String: [SGame]] = [:]
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    // Browse / detail / standings / team picker
    @Published private(set) var browseGames: [SGame] = []
    @Published private(set) var browseLoading = false
    @Published private(set) var browseError: String?
    @Published private(set) var detail: GameDetail?
    @Published private(set) var detailLoading = false
    @Published private(set) var detailError: String?
    @Published private(set) var standings: [StandingsGroup] = []
    @Published private(set) var standingsLoading = false
    @Published private(set) var standingsError: String?
    @Published private(set) var teamOptions: [TeamOption] = []
    @Published private(set) var teamsLoading = false

    private let settings: AppSettings
    private static let fileName = "sportsfollow.json"

    init(settings: AppSettings) {
        self.settings = settings
        follows = LocalStore.load(SportsFollows.self, name: Self.fileName) ?? SportsFollows()
    }

    // MARK: Following

    var hasFollows: Bool { !follows.leagues.isEmpty || !follows.teams.isEmpty }

    /// Every league we need to fetch: followed leagues plus the leagues of followed teams.
    var activeLeagueIDs: [String] {
        var ids = follows.leagues
        for team in follows.teams where !ids.contains(team.leagueID) { ids.append(team.leagueID) }
        return ids
    }

    func isFollowing(league id: String) -> Bool { follows.leagues.contains(id) }
    func isFollowing(team: TeamOption, in leagueID: String) -> Bool {
        follows.teams.contains { $0.leagueID == leagueID && $0.teamID == team.id }
    }

    func toggle(league id: String) {
        if let index = follows.leagues.firstIndex(of: id) { follows.leagues.remove(at: index) } else { follows.leagues.append(id) }
        save()
        Task { await refreshFollowed() }
    }

    func toggle(team: TeamOption, in leagueID: String) {
        if let index = follows.teams.firstIndex(where: { $0.leagueID == leagueID && $0.teamID == team.id }) {
            follows.teams.remove(at: index)
        } else {
            follows.teams.append(FollowedTeam(leagueID: leagueID, teamID: team.id, name: team.name, abbr: team.abbr, logo: team.logo?.absoluteString ?? ""))
        }
        save()
        Task { await refreshFollowed() }
    }

    func unfollow(_ team: FollowedTeam) {
        follows.teams.removeAll { $0.id == team.id }
        save()
        Task { await refreshFollowed() }
    }

    private func save() { LocalStore.save(follows, name: Self.fileName) }

    // MARK: What to show

    func isFollowedTeamGame(_ game: SGame) -> Bool {
        follows.teams.contains { $0.leagueID == game.leagueID && game.involves(teamID: $0.teamID) }
    }

    /// All games for the teams and leagues you follow. Live first, then coming up, then recent results.
    var myGames: [SGame] {
        var all: [SGame] = []
        for id in activeLeagueIDs {
            let games = gamesByLeague[id] ?? []
            let teamsInLeague = follows.teams.filter { $0.leagueID == id }
            if follows.leagues.contains(id) || teamsInLeague.isEmpty {
                all += games
            } else {
                all += games.filter { game in teamsInLeague.contains { game.involves(teamID: $0.teamID) } }
            }
        }
        return Self.sorted(all)
    }

    static func sorted(_ games: [SGame]) -> [SGame] {
        func rank(_ s: GameState) -> Int { s == .live ? 0 : (s == .scheduled ? 1 : 2) }
        return games.sorted { a, b in
            if rank(a.state) != rank(b.state) { return rank(a.state) < rank(b.state) }
            let da = a.start ?? .distantFuture, db = b.start ?? .distantFuture
            return a.state == .final ? da > db : da < db     // recent results newest first
        }
    }

    // MARK: Fetching

    private static func url(_ path: String, _ tail: String, version: String = "site/v2") -> URL? {
        URL(string: "https://site.api.espn.com/apis/\(version)/sports/\(path)/\(tail)")
    }

    private static func get(_ url: URL?) async -> Data? {
        guard let url = url else { return nil }
        var request = URLRequest(url: url, timeoutInterval: 15)
        request.setValue("LifeNotch", forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else { return nil }
        return data
    }

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyyMMdd"
        return f.string(from: date)
    }

    nonisolated static func scoreboard(_ league: SportsLeague, from: Date? = nil, to: Date? = nil) async -> [SGame]? {
        var tail = "scoreboard?limit=300"
        if let from = from, league.kind == .teams {
            tail += "&dates=\(dateString(from))" + (to.map { "-\(dateString($0))" } ?? "")
        }
        guard let data = await get(url(league.path, tail)) else { return nil }
        return ScoresParser.games(from: data, league: league)
    }

    @MainActor
    func refreshFollowed() async {
        let leagues = activeLeagueIDs.compactMap { SportsCatalog.league($0) }
        guard !leagues.isEmpty else {
            gamesByLeague = [:]
            return
        }
        isLoading = true
        defer { isLoading = false }
        let now = Date()
        let from = Calendar.current.date(byAdding: .day, value: -2, to: now)
        let to = Calendar.current.date(byAdding: .day, value: 7, to: now)
        var fresh: [String: [SGame]] = [:]
        var failed = 0
        await withTaskGroup(of: (String, [SGame]?).self) { group in
            for league in leagues {
                group.addTask { (league.id, await Self.scoreboard(league, from: from, to: to)) }
            }
            for await (id, games) in group {
                if let games = games { fresh[id] = games } else { failed += 1 }
            }
        }
        for (id, games) in fresh { gamesByLeague[id] = games }
        gamesByLeague = gamesByLeague.filter { activeLeagueIDs.contains($0.key) }
        error = failed == 0 ? nil : "Couldn't reach the score feed for \(failed) of \(leagues.count) league(s). Check your connection and try again."
        updated = Date()
        scheduleReminders()
    }

    var hasLiveGames: Bool { gamesByLeague.values.contains { $0.contains { $0.state == .live } } }

    @MainActor
    func loadBrowse(league: SportsLeague, day: Date) async {
        browseLoading = true
        browseError = nil
        defer { browseLoading = false }
        guard let games = await Self.scoreboard(league, from: day, to: day) else {
            browseGames = []
            browseError = "Couldn't load \(league.title). Check your connection."
            return
        }
        browseGames = Self.sorted(games)
    }

    @MainActor
    func loadDetail(for game: SGame) async {
        detail = nil
        detailError = nil
        detailLoading = true
        defer { detailLoading = false }
        guard let league = SportsCatalog.league(game.leagueID),
              let data = await Self.get(Self.url(league.path, "summary?event=\(game.eventID)")) else {
            detailError = "Couldn't load the match details."
            return
        }
        let parsed = ScoresParser.detail(from: data)
        detail = parsed
        if parsed.isEmpty { detailError = "No detailed stats are published for this match yet." }
    }

    @MainActor
    func loadStandings(league: SportsLeague) async {
        standings = []
        standingsError = nil
        standingsLoading = true
        defer { standingsLoading = false }
        guard let data = await Self.get(Self.url(league.path, "standings", version: "v2")) else {
            standingsError = "Couldn't load the table."
            return
        }
        standings = ScoresParser.standings(from: data)
        if standings.isEmpty { standingsError = "No table is published for \(league.title) right now." }
    }

    @MainActor
    func loadTeams(league: SportsLeague) async {
        teamOptions = []
        teamsLoading = true
        defer { teamsLoading = false }
        if let data = await Self.get(Self.url(league.path, "teams?limit=200")) {
            teamOptions = ScoresParser.teams(from: data)
        }
    }

    // MARK: Notch bar chip and reminders

    /// The most interesting thing for the compact bar: a live game of a team you follow, else the next kick-off.
    func compactInfo() -> ScoresCompact? {
        let mine = myGames.filter { isFollowedTeamGame($0) && $0.first != nil && $0.second != nil }
        if let live = mine.first(where: { $0.state == .live }), let a = live.first, let b = live.second {
            return ScoresCompact(icon: "circle.fill", text: "\(a.abbr) \(a.score)-\(b.score) \(b.abbr)", isLive: true,
                                 label: "Live: \(a.name) \(a.score), \(b.name) \(b.score). \(live.statusText)")
        }
        if let next = mine.filter({ $0.state == .scheduled && ($0.start ?? .distantPast) > Date() })
            .min(by: { ($0.start ?? .distantFuture) < ($1.start ?? .distantFuture) }),
           let a = next.first, let b = next.second, let start = next.start, start.timeIntervalSinceNow < 24 * 3600 {
            let when = start.formatted(date: .omitted, time: .shortened)
            return ScoresCompact(icon: "sportscourt", text: "\(a.abbr) v \(b.abbr) \(when)", isLive: false,
                                 label: "Next: \(a.name) versus \(b.name) at \(when)")
        }
        return nil
    }

    /// Optional kick-off reminders for games of followed teams (only if you switched them on).
    private func scheduleReminders() {
        var reminders: [NotificationManager.Reminder] = []
        if settings.prefs.scoresNotifications {
            for game in myGames where isFollowedTeamGame(game) && game.state == .scheduled {
                guard let start = game.start, let a = game.first, let b = game.second else { continue }
                reminders.append(.init(id: "scores.\(game.id)", title: "\(a.name) v \(b.name)",
                                       body: "Starts in 15 minutes", date: start.addingTimeInterval(-15 * 60)))
            }
        }
        NotificationManager.shared.replaceAll(prefix: "scores.", with: Array(reminders.prefix(40)))
    }
}
