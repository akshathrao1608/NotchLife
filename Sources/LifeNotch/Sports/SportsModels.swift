import Foundation

// SportsModels.swift
// The shapes of sports data. Every data source (demo or real) must produce these.
// That is what makes the data provider easy to replace later: the screens only ever
// see these types, never the web API's own format.

struct F1Race: Equatable {
    let round: Int
    let name: String
    let circuit: String
    let locality: String
    let country: String
    let start: Date
}

struct F1Result: Identifiable, Equatable {
    let id = UUID()
    let position: Int
    let driver: String
    let team: String
    let timeOrStatus: String

    static func == (lhs: F1Result, rhs: F1Result) -> Bool { lhs.id == rhs.id }
}

struct F1RaceResult: Equatable {
    let raceName: String
    let date: Date
    let results: [F1Result]
    var podium: [F1Result] { Array(results.prefix(3)) }
}

struct F1Standing: Identifiable, Equatable {
    let id = UUID()
    let position: Int
    let driver: String
    let team: String
    let points: Double
    let wins: Int

    static func == (lhs: F1Standing, rhs: F1Standing) -> Bool { lhs.id == rhs.id }
}

struct FootballMatch: Identifiable, Equatable {
    enum Status { case scheduled, live, finished }

    let id: String
    let competition: String
    let home: String
    let away: String
    let homeShort: String
    let awayShort: String
    let kickoff: Date
    let status: Status
    let homeScore: Int?
    let awayScore: Int?
    var minute: String? = nil

    var scoreText: String {
        guard let h = homeScore, let a = awayScore else { return "–" }
        return "\(h) – \(a)"
    }
}

struct FootballStanding: Identifiable, Equatable {
    let id = UUID()
    let position: Int
    let team: String
    let shortName: String
    let played: Int
    let won: Int
    let drawn: Int
    let lost: Int
    let goalDifference: Int
    let points: Int

    static func == (lhs: FootballStanding, rhs: FootballStanding) -> Bool { lhs.id == rhs.id }
}

struct FootballLeague: Identifiable, Hashable {
    let code: String
    let name: String
    var id: String { code }

    static let all: [FootballLeague] = [
        FootballLeague(code: "PL", name: "Premier League"),
        FootballLeague(code: "PD", name: "La Liga"),
        FootballLeague(code: "BL1", name: "Bundesliga"),
        FootballLeague(code: "SA", name: "Serie A"),
        FootballLeague(code: "FL1", name: "Ligue 1"),
        FootballLeague(code: "CL", name: "Champions League")
    ]
}

enum SportsError: LocalizedError {
    case http(Int)
    case parse
    case network(String)

    var errorDescription: String? {
        switch self {
        case .http(let status):
            if status == 429 { return "The sports service says too many requests (429). Try again in a minute." }
            if status == 401 || status == 403 { return "The sports service rejected your key (\(status))." }
            return "The sports service returned an error (\(status))."
        case .parse: return "LifeNotch couldn't understand the sports data."
        case .network(let text): return "Couldn't reach the sports service: \(text)"
        }
    }
}

/// Does `favourite` (what you typed) refer to this team? "Arsenal" matches "Arsenal FC".
func teamMatches(favourite: String, name: String, short: String) -> Bool {
    let f = favourite.trimmingCharacters(in: .whitespaces).lowercased()
    guard !f.isEmpty else { return false }
    let n = name.lowercased()
    let s = short.lowercased()
    return n.contains(f) || f.contains(n) || (!s.isEmpty && (s.contains(f) || f.contains(s)))
}
