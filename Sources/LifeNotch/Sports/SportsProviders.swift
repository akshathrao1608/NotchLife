import Foundation

// SportsProviders.swift
// WHERE the sports data comes from.
//
//  To use a different sports data provider later:
//   1. Make a new struct that conforms to F1DataProvider and/or FootballDataProviding.
//   2. Return the model types from SportsModels.swift.
//   3. Pick it in SportsModel.makeF1Provider() / makeFootballProvider().
//  Nothing else in the app needs to change.

protocol F1DataProvider {
    var name: String { get }
    var isDemo: Bool { get }
    func nextRace() async throws -> F1Race?
    func latestResult() async throws -> F1RaceResult?
    func driverStandings() async throws -> [F1Standing]
}

protocol FootballDataProviding {
    var name: String { get }
    var isDemo: Bool { get }
    func matches(league: String) async throws -> [FootballMatch]
    func standings(league: String) async throws -> [FootballStanding]
}

/// Shared by the live providers: do the request, turn problems into friendly errors.
enum SportsHTTP {
    static func data(for request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else { throw SportsError.http(status) }
            return data
        } catch let error as SportsError {
            throw error
        } catch {
            throw SportsError.network(error.localizedDescription)
        }
    }
}

// MARK: - Demo data (clearly labelled in the UI, never presented as live)

struct DemoF1Provider: F1DataProvider {
    let name = "Demo Data"
    let isDemo = true

    static let drivers: [(String, String)] = [
        ("Lando Norris", "McLaren"), ("Oscar Piastri", "McLaren"), ("Max Verstappen", "Red Bull"),
        ("Charles Leclerc", "Ferrari"), ("Lewis Hamilton", "Ferrari"), ("George Russell", "Mercedes"),
        ("Fernando Alonso", "Aston Martin"), ("Carlos Sainz", "Williams"), ("Pierre Gasly", "Alpine"),
        ("Alexander Albon", "Williams")
    ]

    func nextRace() async throws -> F1Race? {
        let start = Calendar.current.nextDate(after: Date().addingTimeInterval(36 * 3600),
                                              matching: DateComponents(hour: 14, minute: 0, weekday: 1),
                                              matchingPolicy: .nextTime) ?? Date().addingTimeInterval(5 * 86_400)
        return F1Race(round: 0, name: "Sample Grand Prix", circuit: "Sample Circuit", locality: "Sampletown",
                      country: "Demo Land", start: start)
    }

    func latestResult() async throws -> F1RaceResult? {
        let results = Self.drivers.enumerated().map { index, entry in
            F1Result(position: index + 1, driver: entry.0, team: entry.1,
                     timeOrStatus: index == 0 ? "1:31:44.200" : "+\(String(format: "%.3f", Double(index) * 4.7))s")
        }
        return F1RaceResult(raceName: "Previous Sample Grand Prix", date: Date().addingTimeInterval(-7 * 86_400), results: results)
    }

    func driverStandings() async throws -> [F1Standing] {
        Self.drivers.enumerated().map { index, entry in
            F1Standing(position: index + 1, driver: entry.0, team: entry.1,
                       points: Double(210 - index * 19), wins: max(0, 4 - index))
        }
    }
}

struct DemoFootballProvider: FootballDataProviding {
    let name = "Demo Data"
    let isDemo = true

    static let teams = ["Arsenal", "Aston Villa", "Chelsea", "Liverpool", "Manchester City",
                        "Manchester United", "Newcastle United", "Tottenham Hotspur", "Brighton", "West Ham United"]

    func standings(league: String) async throws -> [FootballStanding] {
        Self.teams.enumerated().map { index, team in
            let played = 20
            let won = 14 - index
            let drawn = 3 + index % 3
            let lost = played - won - drawn
            return FootballStanding(position: index + 1, team: team, shortName: team,
                                    played: played, won: won, drawn: drawn, lost: lost,
                                    goalDifference: 22 - index * 4, points: won * 3 + drawn)
        }
    }

    func matches(league: String) async throws -> [FootballMatch] {
        let now = Date()
        let day: TimeInterval = 86_400
        let t = Self.teams
        func make(_ i: Int, _ h: Int, _ a: Int, _ offset: TimeInterval, _ status: FootballMatch.Status,
                  _ hs: Int?, _ aws: Int?, minute: String? = nil) -> FootballMatch {
            FootballMatch(id: "demo-\(i)", competition: "Demo League", home: t[h], away: t[a],
                          homeShort: t[h], awayShort: t[a], kickoff: now.addingTimeInterval(offset),
                          status: status, homeScore: hs, awayScore: aws, minute: minute)
        }
        return [
            make(1, 0, 1, -2 * day, .finished, 2, 1),
            make(2, 2, 3, -1 * day, .finished, 0, 0),
            make(3, 4, 5, -52 * 60, .live, 1, 1, minute: "52'"),
            make(4, 6, 0, 2 * day, .scheduled, nil, nil),
            make(5, 3, 4, 3 * day, .scheduled, nil, nil),
            make(6, 0, 2, 6 * day, .scheduled, nil, nil),
            make(7, 1, 7, 7 * day, .scheduled, nil, nil),
            make(8, 5, 8, 9 * day, .scheduled, nil, nil)
        ]
    }
}

// MARK: - Live F1 (Jolpica, a free community Ergast-compatible API; no key)

struct JolpicaF1Provider: F1DataProvider {
    let name = "Jolpica F1 API"
    let isDemo = false
    private let base = "https://api.jolpi.ca/ergast/f1/current"

    // The JSON from the API (names match the API's own field names).
    private enum DTO {
        struct Root: Decodable { let MRData: MRData }
        struct MRData: Decodable { let RaceTable: RaceTable?; let StandingsTable: StandingsTable? }
        struct RaceTable: Decodable { let Races: [Race] }
        struct Race: Decodable {
            let round: String
            let raceName: String
            let Circuit: Circuit
            let date: String
            let time: String?
            let Results: [Result]?
        }
        struct Circuit: Decodable { let circuitName: String; let Location: Location }
        struct Location: Decodable { let locality: String; let country: String }
        struct Result: Decodable {
            let position: String
            let Driver: Driver
            let Constructor: Constructor
            let Time: TimeValue?
            let status: String?
        }
        struct Driver: Decodable { let givenName: String; let familyName: String }
        struct Constructor: Decodable { let name: String }
        struct TimeValue: Decodable { let time: String }
        struct StandingsTable: Decodable { let StandingsLists: [StandingsList] }
        struct StandingsList: Decodable { let DriverStandings: [DriverStanding] }
        struct DriverStanding: Decodable {
            let position: String?
            let points: String
            let wins: String?
            let Driver: Driver
            let Constructors: [Constructor]
        }
    }

    private func fetch(_ path: String) async throws -> DTO.MRData {
        guard let url = URL(string: base + path) else { throw SportsError.parse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        let data = try await SportsHTTP.data(for: request)
        guard let root = try? JSONDecoder().decode(DTO.Root.self, from: data) else { throw SportsError.parse }
        return root.MRData
    }

    private static func date(_ day: String, _ time: String?) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        if let time = time, let d = formatter.date(from: "\(day)T\(time)") { return d }
        formatter.formatOptions = [.withFullDate]
        return formatter.date(from: day).map { $0.addingTimeInterval(13 * 3600) }
    }

    func nextRace() async throws -> F1Race? {
        let mr = try await fetch("/next.json")
        guard let race = mr.RaceTable?.Races.first, let start = Self.date(race.date, race.time) else { return nil }
        return F1Race(round: Int(race.round) ?? 0, name: race.raceName, circuit: race.Circuit.circuitName,
                      locality: race.Circuit.Location.locality, country: race.Circuit.Location.country, start: start)
    }

    func latestResult() async throws -> F1RaceResult? {
        let mr = try await fetch("/last/results.json")
        guard let race = mr.RaceTable?.Races.first, let results = race.Results else { return nil }
        let mapped = results.map { r in
            F1Result(position: Int(r.position) ?? 0,
                     driver: "\(r.Driver.givenName) \(r.Driver.familyName)",
                     team: r.Constructor.name,
                     timeOrStatus: r.Time?.time ?? (r.status ?? ""))
        }
        return F1RaceResult(raceName: race.raceName, date: Self.date(race.date, race.time) ?? Date(), results: mapped)
    }

    func driverStandings() async throws -> [F1Standing] {
        let mr = try await fetch("/driverStandings.json")
        let list = mr.StandingsTable?.StandingsLists.first?.DriverStandings ?? []
        return list.enumerated().map { index, s in
            F1Standing(position: Int(s.position ?? "") ?? index + 1,
                       driver: "\(s.Driver.givenName) \(s.Driver.familyName)",
                       team: s.Constructors.first?.name ?? "",
                       points: Double(s.points) ?? 0,
                       wins: Int(s.wins ?? "") ?? 0)
        }
    }
}

// MARK: - Live football (football-data.org, free key)

struct FootballDataOrgProvider: FootballDataProviding {
    let name = "football-data.org"
    let isDemo = false
    let apiKey: String

    private func get(_ path: String) async throws -> [String: Any] {
        guard let url = URL(string: "https://api.football-data.org/v4" + path) else { throw SportsError.parse }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue(apiKey, forHTTPHeaderField: "X-Auth-Token")
        let data = try await SportsHTTP.data(for: request)
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { throw SportsError.parse }
        return json
    }

    func matches(league: String) async throws -> [FootballMatch] {
        let json = try await get("/competitions/\(league)/matches")
        let competition = ((json["competition"] as? [String: Any])?["name"] as? String) ?? league
        let formatter = ISO8601DateFormatter()
        let now = Date()
        var result: [FootballMatch] = []
        for item in (json["matches"] as? [[String: Any]]) ?? [] {
            guard let dateText = item["utcDate"] as? String, let kickoff = formatter.date(from: dateText),
                  kickoff > now.addingTimeInterval(-8 * 86_400), kickoff < now.addingTimeInterval(30 * 86_400),
                  let home = item["homeTeam"] as? [String: Any], let away = item["awayTeam"] as? [String: Any] else { continue }
            let statusText = (item["status"] as? String) ?? ""
            let status: FootballMatch.Status
            switch statusText {
            case "IN_PLAY", "PAUSED": status = .live
            case "FINISHED": status = .finished
            default: status = .scheduled
            }
            let full = ((item["score"] as? [String: Any])?["fullTime"] as? [String: Any]) ?? [:]
            result.append(FootballMatch(
                id: String(describing: item["id"] ?? UUID().uuidString),
                competition: competition,
                home: (home["name"] as? String) ?? "?",
                away: (away["name"] as? String) ?? "?",
                homeShort: (home["shortName"] as? String) ?? "",
                awayShort: (away["shortName"] as? String) ?? "",
                kickoff: kickoff,
                status: status,
                homeScore: full["home"] as? Int,
                awayScore: full["away"] as? Int))
        }
        return result.sorted { $0.kickoff < $1.kickoff }
    }

    func standings(league: String) async throws -> [FootballStanding] {
        let json = try await get("/competitions/\(league)/standings")
        let groups = (json["standings"] as? [[String: Any]]) ?? []
        guard let total = groups.first(where: { ($0["type"] as? String) == "TOTAL" }) ?? groups.first,
              let table = total["table"] as? [[String: Any]] else { return [] }
        return table.map { row in
            let team = (row["team"] as? [String: Any]) ?? [:]
            return FootballStanding(position: (row["position"] as? Int) ?? 0,
                                    team: (team["name"] as? String) ?? "?",
                                    shortName: (team["shortName"] as? String) ?? "",
                                    played: (row["playedGames"] as? Int) ?? 0,
                                    won: (row["won"] as? Int) ?? 0,
                                    drawn: (row["draw"] as? Int) ?? 0,
                                    lost: (row["lost"] as? Int) ?? 0,
                                    goalDifference: (row["goalDifference"] as? Int) ?? 0,
                                    points: (row["points"] as? Int) ?? 0)
        }
    }
}
