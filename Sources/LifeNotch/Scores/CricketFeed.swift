import Foundation

// CricketFeed.swift
// Cricket scores from CricAPI (cricketdata.org), a documented cricket API with a FREE tier (about 100 requests a day).
// It needs your own free key, which LifeNotch keeps in the macOS Keychain (the key is optional: without it, cricket is
// simply not shown). To stay inside the free allowance LifeNotch asks for the match list at most every 15 minutes
// and caches scorecards for 5 minutes.
// Get a key: https://www.cricapi.com  (sign up, copy the "API key" from your dashboard).

enum CricketFeed {
    static let keyAccount = "apikey.cricapi"
    static let leagueID = "cricket/live"

    static func url(_ endpoint: String, key: String, extra: String = "") -> URL? {
        guard let encoded = key.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://api.cricapi.com/v1/\(endpoint)?apikey=\(encoded)\(extra)")
    }

    /// CricAPI answers HTTP 200 even for problems; the reason is inside the JSON.
    static func failureReason(_ data: Data) -> String? {
        guard let root = ScoresParser.json(data) as? [String: Any], ScoresParser.string(root["status"]) == "failure" else { return nil }
        return ScoresParser.string(root["reason"]) ?? "CricAPI refused the request."
    }

    private static func dicts(_ any: Any?) -> [[String: Any]] { any as? [[String: Any]] ?? [] }

    // MARK: Match list

    static func games(from data: Data) -> [SGame] {
        guard let root = ScoresParser.json(data) as? [String: Any] else { return [] }
        var result: [SGame] = []
        for match in dicts(root["data"]) {
            guard let id = ScoresParser.string(match["id"]) else { continue }
            let names = (match["teams"] as? [String]) ?? []
            guard names.count >= 2 else { continue }
            let info = dicts(match["teamInfo"])
            let scores = dicts(match["score"])
            let status = ScoresParser.string(match["status"]) ?? ""
            let started = (match["matchStarted"] as? Bool) ?? false
            let ended = (match["matchEnded"] as? Bool) ?? false
            let state: GameState = ended ? .final : (started ? .live : .scheduled)

            func side(_ name: String) -> SSide {
                let teamInfo = info.first { ScoresParser.string($0["name"])?.lowercased() == name.lowercased() }
                let innings = scores.filter { (ScoresParser.string($0["inning"]) ?? "").lowercased().contains(name.lowercased()) }
                let text = innings.map { inning -> String in
                    let runs = ScoresParser.string(inning["r"]) ?? "0"
                    let wickets = ScoresParser.string(inning["w"]) ?? "0"
                    let overs = ScoresParser.string(inning["o"]) ?? ""
                    return "\(runs)/\(wickets)" + (overs.isEmpty ? "" : " (\(overs))")
                }.joined(separator: " & ")
                return SSide(id: name.lowercased(), name: name,
                             abbr: ScoresParser.string(teamInfo?["shortname"]) ?? String(name.prefix(3)).uppercased(),
                             score: text, record: "",
                             logo: ScoresParser.string(teamInfo?["img"]).flatMap { URL(string: $0) },
                             colorHex: "", winner: ended && status.lowercased().hasPrefix(name.lowercased() + " won"), lines: [])
            }

            result.append(SGame(id: "cricket#" + id, eventID: id, leagueID: leagueID,
                                title: ScoresParser.string(match["name"]) ?? "\(names[0]) v \(names[1])",
                                note: (ScoresParser.string(match["matchType"]) ?? "").uppercased(),
                                start: ScoresParser.date(ScoresParser.string(match["dateTimeGMT"])),
                                state: state, statusText: status,
                                venue: ScoresParser.string(match["venue"]) ?? "", broadcast: "", odds: "",
                                first: side(names[0]), second: side(names[1]), rows: []))
        }
        return result
    }

    // MARK: Scorecard

    static func detail(from data: Data) -> GameDetail {
        guard let root = ScoresParser.json(data) as? [String: Any], let match = root["data"] as? [String: Any] else { return GameDetail() }
        var detail = GameDetail()
        for innings in dicts(match["scorecard"]) {
            let name = ScoresParser.string(innings["inning"]) ?? "Innings"
            let batting: [[String]] = dicts(innings["batting"]).compactMap { row in
                guard let batter = ScoresParser.string((row["batsman"] as? [String: Any])?["name"]) ?? ScoresParser.string(row["batsman"]) else { return nil }
                let out = ScoresParser.string(row["dismissal-text"]) ?? ScoresParser.string(row["dismissal"]) ?? ""
                return [out.isEmpty ? batter : "\(batter) (\(out))",
                        ScoresParser.string(row["r"]) ?? "", ScoresParser.string(row["b"]) ?? "",
                        ScoresParser.string(row["4s"]) ?? "", ScoresParser.string(row["6s"]) ?? "", ScoresParser.string(row["sr"]) ?? ""]
            }
            if !batting.isEmpty {
                detail.tables.append(PlayerTable(team: name, title: "Batting", labels: ["R", "B", "4s", "6s", "SR"], rows: batting))
            }
            let bowling: [[String]] = dicts(innings["bowling"]).compactMap { row in
                guard let bowler = ScoresParser.string((row["bowler"] as? [String: Any])?["name"]) ?? ScoresParser.string(row["bowler"]) else { return nil }
                return [bowler, ScoresParser.string(row["o"]) ?? "", ScoresParser.string(row["m"]) ?? "", ScoresParser.string(row["r"]) ?? "",
                        ScoresParser.string(row["w"]) ?? "", ScoresParser.string(row["eco"]) ?? ""]
            }
            if !bowling.isEmpty {
                detail.tables.append(PlayerTable(team: name, title: "Bowling", labels: ["O", "M", "R", "W", "Econ"], rows: bowling))
            }
        }
        if let venue = ScoresParser.string(match["venue"]) { detail.info.append("Venue: \(venue)") }
        if let toss = ScoresParser.string(match["tossWinner"]) {
            detail.info.append("Toss: \(toss)" + (ScoresParser.string(match["tossChoice"]).map { " chose to \($0)" } ?? ""))
        }
        if let status = ScoresParser.string(match["status"]) { detail.info.append("Result: \(status)") }
        if let series = ScoresParser.string(match["series"]) ?? ScoresParser.string(match["series_id"]) { detail.info.append("Series: \(series)") }
        return detail
    }
}
