import Foundation

// ScoresModels.swift
// The shapes of the data behind the Scores tab (an "Apple Sports"-style hub):
// every sport and league LifeNotch knows, the games, their detailed stats, standings and team lists.

enum SportGroup: String, CaseIterable, Identifiable {
    case soccer, basketball, americanFootball, baseball, hockey, tennis, golf, racing, mma, aussieRules
    var id: String { rawValue }

    var title: String {
        switch self {
        case .soccer: return "Football (Soccer)"
        case .basketball: return "Basketball"
        case .americanFootball: return "American Football"
        case .baseball: return "Baseball"
        case .hockey: return "Hockey"
        case .tennis: return "Tennis"
        case .golf: return "Golf"
        case .racing: return "Motorsport"
        case .mma: return "MMA"
        case .aussieRules: return "Australian Football"
        }
    }

    var icon: String {
        switch self {
        case .soccer: return "soccerball"
        case .basketball: return "basketball.fill"
        case .americanFootball: return "football.fill"
        case .baseball: return "baseball.fill"
        case .hockey: return "hockey.puck.fill"
        case .tennis: return "tennisball.fill"
        case .golf: return "figure.golf"
        case .racing: return "flag.checkered"
        case .mma: return "figure.boxing"
        case .aussieRules: return "figure.australian.football"
        }
    }
}

/// How a league's games are shaped.
enum ScoreKind {
    case teams        // two teams (soccer, basketball, ...)
    case duel         // two people (tennis, MMA)
    case leaderboard  // many competitors in one event (golf, racing)
}

struct SportsLeague: Identifiable, Hashable {
    let path: String      // e.g. "soccer/eng.1"
    let title: String
    let group: SportGroup
    let kind: ScoreKind
    var id: String { path }
}

enum SportsCatalog {
    private static func make(_ group: SportGroup, _ kind: ScoreKind, _ items: [(String, String)]) -> [SportsLeague] {
        items.map { SportsLeague(path: $0.0, title: $0.1, group: group, kind: kind) }
    }

    static let leagues: [SportsLeague] = {
        var all: [SportsLeague] = []
        all += make(.soccer, .teams, [
            ("soccer/eng.1", "Premier League"), ("soccer/eng.2", "Championship"), ("soccer/eng.fa", "FA Cup"),
            ("soccer/esp.1", "La Liga"), ("soccer/ger.1", "Bundesliga"), ("soccer/ita.1", "Serie A"),
            ("soccer/fra.1", "Ligue 1"), ("soccer/ned.1", "Eredivisie"), ("soccer/por.1", "Liga Portugal"),
            ("soccer/sco.1", "Scottish Premiership"), ("soccer/usa.1", "MLS"), ("soccer/mex.1", "Liga MX"),
            ("soccer/bra.1", "Brasileirão"), ("soccer/arg.1", "Argentine Liga"),
            ("soccer/uefa.champions", "Champions League"), ("soccer/uefa.europa", "Europa League"),
            ("soccer/uefa.europa.conf", "Conference League"), ("soccer/conmebol.libertadores", "Copa Libertadores"),
            ("soccer/fifa.world", "FIFA World Cup")
        ])
        all += make(.basketball, .teams, [
            ("basketball/nba", "NBA"), ("basketball/wnba", "WNBA"),
            ("basketball/mens-college-basketball", "NCAA Men's"), ("basketball/womens-college-basketball", "NCAA Women's")
        ])
        all += make(.americanFootball, .teams, [("football/nfl", "NFL"), ("football/college-football", "College Football")])
        all += make(.baseball, .teams, [("baseball/mlb", "MLB")])
        all += make(.hockey, .teams, [("hockey/nhl", "NHL")])
        all += make(.aussieRules, .teams, [("australian-football/afl", "AFL")])
        all += make(.tennis, .duel, [("tennis/atp", "ATP Tour"), ("tennis/wta", "WTA Tour")])
        all += make(.mma, .duel, [("mma/ufc", "UFC")])
        all += make(.golf, .leaderboard, [("golf/pga", "PGA Tour"), ("golf/lpga", "LPGA Tour")])
        all += make(.racing, .leaderboard, [("racing/f1", "Formula 1"), ("racing/irl", "IndyCar"), ("racing/nascar-premier", "NASCAR Cup")])
        return all
    }()

    static func league(_ id: String) -> SportsLeague? { leagues.first { $0.id == id } }
    static func leagues(in group: SportGroup) -> [SportsLeague] { leagues.filter { $0.group == group } }
}

// MARK: - Games

enum GameState { case scheduled, live, final }

struct SSide: Equatable, Identifiable {
    var id: String
    var name: String
    var abbr: String
    var score: String
    var record: String
    var logo: URL?
    var colorHex: String
    var winner: Bool
    var lines: [String]     // quarter / set / period scores
}

struct LeaderRow: Identifiable, Equatable {
    let id = UUID()
    var position: Int
    var name: String
    var value: String
}

struct SGame: Identifiable, Equatable {
    let id: String
    let eventID: String
    let leagueID: String
    var title: String
    var note: String
    var start: Date?
    var state: GameState
    var statusText: String
    var venue: String
    var broadcast: String
    var odds: String
    var first: SSide?       // teams: away. duels: first competitor
    var second: SSide?      // teams: home. duels: second competitor
    var rows: [LeaderRow]   // leaderboards only

    func involves(teamID: String) -> Bool { first?.id == teamID || second?.id == teamID }
}

// MARK: - Detail of one game

struct StatRow: Identifiable, Equatable {
    let id = UUID()
    var label: String
    var first: String
    var second: String
}

struct PlayerTable: Identifiable, Equatable {
    let id = UUID()
    var team: String
    var title: String
    var labels: [String]
    var rows: [[String]]      // first column is the player's name
}

struct TimelineItem: Identifiable, Equatable {
    let id = UUID()
    var time: String
    var title: String
    var text: String
}

struct LeaderLine: Identifiable, Equatable {
    let id = UUID()
    var category: String
    var name: String
    var value: String
    var team: String
}

struct GameDetail: Equatable {
    var teamStats: [StatRow] = []
    var tables: [PlayerTable] = []
    var timeline: [TimelineItem] = []
    var leaders: [LeaderLine] = []
    var info: [String] = []
    var isEmpty: Bool { teamStats.isEmpty && tables.isEmpty && timeline.isEmpty && leaders.isEmpty && info.isEmpty }
}

// MARK: - Standings and team lists

struct StandingRow: Identifiable, Equatable {
    let id: String
    var rank: Int
    var name: String
    var abbr: String
    var values: [String]
}

struct StandingsGroup: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var columns: [String]
    var rows: [StandingRow]
}

struct TeamOption: Identifiable, Equatable {
    let id: String
    var name: String
    var abbr: String
    var logo: URL?
}

struct FollowedTeam: Identifiable, Codable, Equatable {
    var leagueID: String
    var teamID: String
    var name: String
    var abbr: String
    var logo: String
    var id: String { leagueID + "#" + teamID }
}

struct SportsFollows: Codable, Equatable {
    var leagues: [String] = []
    var teams: [FollowedTeam] = []
}
