import Foundation

// ScoresParser.swift
// Turns ESPN's public JSON into the plain structs in ScoresModels.swift. Every field is treated as optional
// (the feed is unofficial and varies by sport), and anything missing is simply left out.

enum ScoresParser {
    // MARK: Small helpers

    static func json(_ data: Data) -> Any? { try? JSONSerialization.jsonObject(with: data) }

    /// Strings, numbers and {displayValue / value} dictionaries all become text.
    static func string(_ any: Any?) -> String? {
        switch any {
        case let s as String: return s.isEmpty ? nil : s
        case let n as NSNumber:
            let d = n.doubleValue
            return d == d.rounded() ? String(Int(d)) : String(d)
        case let dict as [String: Any]:
            return string(dict["displayValue"]) ?? string(dict["value"])
        default: return nil
        }
    }

    /// ESPN dates look like "2026-10-14T19:00Z" (no seconds), so ISO8601DateFormatter can't read them.
    static func date(_ text: String?) -> Date? {
        guard let text = text else { return nil }
        for format in ["yyyy-MM-dd'T'HH:mm'Z'", "yyyy-MM-dd'T'HH:mm:ss'Z'", "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"] {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(identifier: "UTC")
            formatter.dateFormat = format
            if let date = formatter.date(from: text) { return date }
        }
        return nil
    }

    private static func dicts(_ any: Any?) -> [[String: Any]] { any as? [[String: Any]] ?? [] }

    // MARK: Scoreboard

    static func games(from data: Data, league: SportsLeague) -> [SGame] {
        guard let root = json(data) as? [String: Any] else { return [] }
        var result: [SGame] = []
        for event in dicts(root["events"]) {
            let eventID = string(event["id"]) ?? UUID().uuidString
            let eventName = string(event["name"]) ?? string(event["shortName"]) ?? ""
            var competitions = dicts(event["competitions"])
            for group in dicts(event["groupings"]) { competitions += dicts(group["competitions"]) }
            guard !competitions.isEmpty else { continue }

            switch league.kind {
            case .leaderboard:
                // Golf has one competition; racing has several sessions, so prefer the race itself.
                let race = competitions.first { string(($0["type"] as? [String: Any])?["abbreviation"]) == "Race" } ?? competitions.last!
                result.append(game(event: event, competition: race, eventID: eventID, eventName: eventName, league: league))
            case .teams, .duel:
                for competition in competitions {
                    result.append(game(event: event, competition: competition, eventID: eventID, eventName: eventName, league: league))
                }
            }
        }
        return result
    }

    private static func game(event: [String: Any], competition comp: [String: Any], eventID: String, eventName: String, league: SportsLeague) -> SGame {
        let statusDict = (comp["status"] as? [String: Any]) ?? (event["status"] as? [String: Any]) ?? [:]
        let type = statusDict["type"] as? [String: Any] ?? [:]
        let stateText = string(type["state"]) ?? "pre"
        let state: GameState = stateText == "in" ? .live : (stateText == "post" ? .final : .scheduled)
        var statusText = string(type["shortDetail"]) ?? string(type["detail"]) ?? string(type["description"]) ?? ""
        if state == .live, let clock = string(statusDict["displayClock"]), league.kind == .teams, statusText.isEmpty { statusText = clock }

        let venueDict = comp["venue"] as? [String: Any]
        let city = string((venueDict?["address"] as? [String: Any])?["city"])
        let venue = [string(venueDict?["fullName"]), city].compactMap { $0 }.joined(separator: ", ")

        var broadcast = dicts(comp["broadcasts"]).flatMap { ($0["names"] as? [String]) ?? [] }.joined(separator: ", ")
        if broadcast.isEmpty {
            broadcast = dicts(comp["geoBroadcasts"]).compactMap { string(($0["media"] as? [String: Any])?["shortName"]) }.joined(separator: ", ")
        }
        let oddsDict = dicts(comp["odds"]).first
        var odds = string(oddsDict?["details"]) ?? ""
        if let total = string(oddsDict?["overUnder"]), !odds.isEmpty { odds += " · O/U \(total)" }

        let note = string(dicts(comp["notes"]).first?["headline"]) ?? string(((comp["round"]) as? [String: Any])?["displayName"]) ?? ""
        let start = date(string(comp["date"]) ?? string(comp["startDate"]) ?? string(event["date"]))

        var competitors = dicts(comp["competitors"])
        var first: SSide?
        var second: SSide?
        var rows: [LeaderRow] = []

        switch league.kind {
        case .leaderboard:
            competitors.sort { (Int(string($0["order"]) ?? "") ?? 999) < (Int(string($1["order"]) ?? "") ?? 999) }
            rows = competitors.prefix(25).enumerated().map { index, c in
                let athlete = c["athlete"] as? [String: Any]
                let name = string(athlete?["displayName"]) ?? string(athlete?["fullName"]) ?? string((c["team"] as? [String: Any])?["displayName"]) ?? "–"
                return LeaderRow(position: Int(string(c["order"]) ?? "") ?? index + 1, name: name,
                                 value: string(c["score"]) ?? string(statValue(c, names: ["scoreToPar", "position"])) ?? "")
            }
        case .teams:
            // Away first, home second (like Apple Sports).
            competitors.sort { string($0["homeAway"]) == "away" && string($1["homeAway"]) != "away" }
            first = competitors.indices.contains(0) ? side(competitors[0]) : nil
            second = competitors.indices.contains(1) ? side(competitors[1]) : nil
        case .duel:
            first = competitors.indices.contains(0) ? side(competitors[0]) : nil
            second = competitors.indices.contains(1) ? side(competitors[1]) : nil
        }

        let compID = string(comp["id"]) ?? eventID
        return SGame(id: eventID + "#" + compID, eventID: eventID, leagueID: league.id,
                     title: eventName, note: note, start: start, state: state, statusText: statusText,
                     venue: venue, broadcast: broadcast, odds: odds, first: first, second: second, rows: rows)
    }

    private static func statValue(_ competitor: [String: Any], names: [String]) -> String? {
        for stat in dicts(competitor["statistics"]) {
            if let name = string(stat["name"]), names.contains(name), let value = string(stat["displayValue"]) { return value }
        }
        return nil
    }

    private static func side(_ c: [String: Any]) -> SSide {
        let team = c["team"] as? [String: Any]
        let athlete = c["athlete"] as? [String: Any]
        let name = string(team?["displayName"]) ?? string(athlete?["displayName"]) ?? string(athlete?["fullName"]) ?? string(c["name"]) ?? "–"
        let abbr = string(team?["abbreviation"]) ?? string(athlete?["shortName"]) ?? String(name.prefix(3)).uppercased()
        var logoText = string(team?["logo"]) ?? string(dicts(team?["logos"]).first?["href"])
        if logoText == nil { logoText = string((athlete?["flag"] as? [String: Any])?["href"]) }
        let record = string(dicts(c["records"]).first?["summary"]) ?? string(c["record"]) ?? ""
        let lines = dicts(c["linescores"]).compactMap { string($0["displayValue"]) ?? string($0["value"]) }
        return SSide(id: string(team?["id"]) ?? string(athlete?["id"]) ?? string(c["id"]) ?? name,
                     name: name, abbr: abbr, score: string(c["score"]) ?? "",
                     record: record, logo: logoText.flatMap { URL(string: $0) },
                     colorHex: string(team?["color"]) ?? "", winner: (c["winner"] as? Bool) ?? false, lines: lines)
    }

    // MARK: Game summary (the detailed stats)

    static func detail(from data: Data) -> GameDetail {
        guard let root = json(data) as? [String: Any] else { return GameDetail() }
        var detail = GameDetail()

        // Team stats side by side (away on the left, home on the right).
        let box = root["boxscore"] as? [String: Any] ?? [:]
        var teams = dicts(box["teams"])
        teams.sort { string($0["homeAway"]) == "away" && string($1["homeAway"]) != "away" }
        if teams.count >= 2 {
            let secondStats = dicts(teams[1]["statistics"])
            for stat in dicts(teams[0]["statistics"]) {
                guard let label = string(stat["label"]) ?? string(stat["name"]), let value = string(stat["displayValue"]) else { continue }
                let match = secondStats.first { string($0["name"]) == string(stat["name"]) }
                detail.teamStats.append(StatRow(label: label, first: value, second: string(match?["displayValue"]) ?? "–"))
            }
        }

        // Player tables (basketball, football, baseball, hockey...).
        for entry in dicts(box["players"]) {
            let teamName = string((entry["team"] as? [String: Any])?["displayName"]) ?? ""
            for group in dicts(entry["statistics"]) {
                let labels = (group["labels"] as? [String]) ?? []
                let rows: [[String]] = dicts(group["athletes"]).prefix(10).compactMap { item in
                    guard let name = string((item["athlete"] as? [String: Any])?["displayName"]) else { return nil }
                    return [name] + ((item["stats"] as? [String]) ?? [])
                }
                guard !rows.isEmpty else { continue }
                let title = string(group["text"]) ?? string(group["name"])?.capitalized ?? "Players"
                detail.tables.append(PlayerTable(team: teamName, title: title, labels: labels, rows: rows))
            }
        }

        // Soccer line-ups with each player's notable stats.
        for roster in dicts(root["rosters"]) {
            let teamName = string((roster["team"] as? [String: Any])?["displayName"]) ?? ""
            var rows: [[String]] = []
            for player in dicts(roster["roster"]) {
                guard let name = string((player["athlete"] as? [String: Any])?["displayName"]) else { continue }
                let position = string((player["position"] as? [String: Any])?["abbreviation"]) ?? ""
                let notable = dicts(player["stats"]).compactMap { stat -> String? in
                    guard let value = string(stat["displayValue"]), value != "0", value != "0.0",
                          let label = string(stat["shortDisplayName"]) ?? string(stat["abbreviation"]) else { return nil }
                    return "\(label) \(value)"
                }.prefix(4).joined(separator: " · ")
                rows.append([name, position, notable])
            }
            if !rows.isEmpty {
                detail.tables.append(PlayerTable(team: teamName, title: "Line-up", labels: ["Pos", "Notable"], rows: rows))
            }
        }

        // Timeline: soccer key events, or scoring plays for other sports.
        for event in dicts(root["keyEvents"]) {
            let kind = string((event["type"] as? [String: Any])?["text"]) ?? ""
            let text = string(event["shortText"]) ?? string(event["text"]) ?? ""
            guard !(kind.isEmpty && text.isEmpty) else { continue }
            detail.timeline.append(TimelineItem(time: string((event["clock"] as? [String: Any])?["displayValue"]) ?? "", title: kind, text: text))
        }
        if detail.timeline.isEmpty {
            for play in dicts(root["scoringPlays"]) {
                let period = string((play["period"] as? [String: Any])?["number"]).map { "P\($0) " } ?? ""
                let clock = string((play["clock"] as? [String: Any])?["displayValue"]) ?? ""
                let score = [string(play["awayScore"]), string(play["homeScore"])].compactMap { $0 }.joined(separator: "–")
                detail.timeline.append(TimelineItem(time: period + clock,
                                                    title: string((play["team"] as? [String: Any])?["displayName"]) ?? "",
                                                    text: [string(play["text"]), score.isEmpty ? nil : "(\(score))"].compactMap { $0 }.joined(separator: " ")))
            }
        }

        // Leaders: best player in each category.
        for teamLeaders in dicts(root["leaders"]) {
            let teamName = string((teamLeaders["team"] as? [String: Any])?["displayName"]) ?? ""
            for category in dicts(teamLeaders["leaders"]) {
                guard let top = dicts(category["leaders"]).first,
                      let name = string((top["athlete"] as? [String: Any])?["displayName"]) else { continue }
                detail.leaders.append(LeaderLine(category: string(category["displayName"]) ?? string(category["name"]) ?? "",
                                                 name: name, value: string(top["displayValue"]) ?? "", team: teamName))
            }
        }

        // Match info.
        let info = root["gameInfo"] as? [String: Any] ?? [:]
        if let venue = string((info["venue"] as? [String: Any])?["fullName"]) { detail.info.append("Venue: \(venue)") }
        if let attendance = string(info["attendance"]), attendance != "0" { detail.info.append("Attendance: \(attendance)") }
        for official in dicts(info["officials"]).prefix(4) {
            if let name = string(official["displayName"]) {
                detail.info.append("\(string((official["position"] as? [String: Any])?["displayName"]) ?? "Official"): \(name)")
            }
        }
        if let weather = string((info["weather"] as? [String: Any])?["displayValue"]) { detail.info.append("Weather: \(weather)") }
        return detail
    }

    // MARK: Standings

    private static let preferredStats = ["gamesPlayed", "wins", "ties", "losses", "otLosses", "winPercent", "gamesBehind",
                                         "pointDifferential", "pointsFor", "pointsAgainst", "points", "streak"]

    static func standings(from data: Data) -> [StandingsGroup] {
        guard let root = json(data) as? [String: Any] else { return [] }
        var containers = dicts(root["children"])
        if containers.isEmpty, root["standings"] != nil { containers = [root] }
        var result: [StandingsGroup] = []
        for container in containers {
            let entries = dicts((container["standings"] as? [String: Any])?["entries"])
            guard !entries.isEmpty else { continue }
            // Pick the columns this sport has, in a sensible order.
            let names = Set(entries.flatMap { dicts($0["stats"]).compactMap { string($0["name"]) } })
            var chosen = preferredStats.filter { names.contains($0) }
            if chosen.count > 6 { chosen = Array(chosen.prefix(6)) }
            if chosen.isEmpty { chosen = Array(dicts(entries[0]["stats"]).compactMap { string($0["name"]) }.prefix(6)) }

            var columns: [String] = []
            let firstStats = dicts(entries[0]["stats"])
            for name in chosen {
                let stat = firstStats.first { string($0["name"]) == name }
                columns.append(string(stat?["abbreviation"]) ?? string(stat?["shortDisplayName"]) ?? name)
            }
            var rows: [StandingRow] = entries.enumerated().map { index, entry in
                let team = entry["team"] as? [String: Any]
                let stats = dicts(entry["stats"])
                let values = chosen.map { name in string(stats.first { string($0["name"]) == name }?["displayValue"]) ?? "–" }
                let rank = Int(string(stats.first { string($0["name"]) == "rank" || string($0["name"]) == "playoffSeed" }?["value"]) ?? "") ?? index + 1
                return StandingRow(id: string(team?["id"]) ?? "\(index)", rank: rank,
                                   name: string(team?["displayName"]) ?? "–", abbr: string(team?["abbreviation"]) ?? "", values: values)
            }
            rows.sort { $0.rank < $1.rank }
            result.append(StandingsGroup(name: string(container["name"]) ?? "", columns: columns, rows: rows))
        }
        return result
    }

    // MARK: Teams (for following)

    static func teams(from data: Data) -> [TeamOption] {
        guard let root = json(data) as? [String: Any] else { return [] }
        var result: [TeamOption] = []
        for sport in dicts(root["sports"]) {
            for league in dicts(sport["leagues"]) {
                for item in dicts(league["teams"]) {
                    guard let team = item["team"] as? [String: Any], let id = string(team["id"]), let name = string(team["displayName"]) else { continue }
                    let logo = string(dicts(team["logos"]).first?["href"]) ?? string(team["logo"])
                    result.append(TeamOption(id: id, name: name, abbr: string(team["abbreviation"]) ?? String(name.prefix(3)).uppercased(),
                                             logo: logo.flatMap { URL(string: $0) }))
                }
            }
        }
        return result.sorted { $0.name < $1.name }
    }
}
