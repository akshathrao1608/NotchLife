import Foundation

// TennisModel.swift
// Tennis scores. Two honest modes:
//  - Demo (default): made-up matches, always labelled "Demo Data".
//  - Live: ESPN's public scoreboard (site.api.espn.com), no account or key. It is an unofficial public feed,
//    so it can change or be missing; if it fails you see the error, never quietly swapped-in demo data.

struct TennisMatch: Identifiable, Equatable {
    let id: String
    let tournament: String
    let round: String
    let player1: String
    let player2: String
    let sets1: [Int]
    let sets2: [Int]
    let state: String      // "pre", "in" or "post"
    let detail: String
    let start: Date?

    var scoreText: String {
        guard !sets1.isEmpty else { return "" }
        return zip(sets1, sets2).map { "\($0)-\($1)" }.joined(separator: "  ")
    }
}

final class TennisModel: ObservableObject {
    @Published private(set) var matches: [TennisMatch] = []
    @Published private(set) var isDemo = true
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var updated: Date?

    @MainActor
    func refresh(tour: String, live: Bool) async {
        guard !isLoading else { return }
        isLoading = true
        error = nil
        defer { isLoading = false }
        if !live {
            matches = Self.demo()
            isDemo = true
            updated = Date()
            return
        }
        guard let url = URL(string: "https://site.api.espn.com/apis/site/v2/sports/tennis/\(tour == "wta" ? "wta" : "atp")/scoreboard") else { return }
        do {
            var request = URLRequest(url: url, timeoutInterval: 15)
            request.setValue("LifeNotch", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                error = "The score service answered with an error (\(http.statusCode))."
                return
            }
            matches = Self.parse(data)
            isDemo = false
            updated = Date()
            if matches.isEmpty { error = "No tennis matches are listed right now." }
        } catch {
            self.error = error.localizedDescription
        }
    }

    /// Reads ESPN's scoreboard JSON defensively (every field is optional).
    static func parse(_ data: Data) -> [TennisMatch] {
        guard let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let events = root["events"] as? [[String: Any]] else { return [] }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let isoPlain = ISO8601DateFormatter()
        var result: [TennisMatch] = []
        for event in events {
            let tournament = (event["name"] as? String) ?? "Tennis"
            var competitions = event["competitions"] as? [[String: Any]] ?? []
            for group in (event["groupings"] as? [[String: Any]] ?? []) {
                competitions += group["competitions"] as? [[String: Any]] ?? []
            }
            for comp in competitions {
                let competitors = comp["competitors"] as? [[String: Any]] ?? []
                guard competitors.count >= 2 else { continue }
                func name(_ c: [String: Any]) -> String {
                    ((c["athlete"] as? [String: Any])?["displayName"] as? String)
                        ?? ((c["team"] as? [String: Any])?["displayName"] as? String) ?? "Player"
                }
                func sets(_ c: [String: Any]) -> [Int] {
                    (c["linescores"] as? [[String: Any]] ?? []).compactMap { ($0["value"] as? Double).map(Int.init) }
                }
                let status = (comp["status"] as? [String: Any])?["type"] as? [String: Any]
                let startText = comp["date"] as? String ?? comp["startDate"] as? String
                let start = startText.flatMap { iso.date(from: $0) ?? isoPlain.date(from: $0) }
                let round = ((comp["round"] as? [String: Any])?["displayName"] as? String) ?? ""
                result.append(TennisMatch(id: (comp["id"] as? String) ?? UUID().uuidString,
                                          tournament: tournament, round: round,
                                          player1: name(competitors[0]), player2: name(competitors[1]),
                                          sets1: sets(competitors[0]), sets2: sets(competitors[1]),
                                          state: (status?["state"] as? String) ?? "pre",
                                          detail: (status?["shortDetail"] as? String) ?? (status?["description"] as? String) ?? "",
                                          start: start))
            }
        }
        let order = ["in": 0, "pre": 1, "post": 2]
        return result.sorted { (order[$0.state] ?? 3, $0.start ?? .distantFuture) < (order[$1.state] ?? 3, $1.start ?? .distantFuture) }
    }

    static func demo() -> [TennisMatch] {
        [
            TennisMatch(id: "d1", tournament: "Demo Open", round: "Final", player1: "A. Example", player2: "B. Sample",
                        sets1: [6, 4, 3], sets2: [3, 6, 2], state: "in", detail: "3rd set", start: nil),
            TennisMatch(id: "d2", tournament: "Demo Open", round: "Semi-final", player1: "C. Placeholder", player2: "D. Test",
                        sets1: [6, 7], sets2: [4, 5], state: "post", detail: "Final", start: nil),
            TennisMatch(id: "d3", tournament: "Demo Open", round: "Quarter-final", player1: "E. Mock", player2: "F. Dummy",
                        sets1: [], sets2: [], state: "pre", detail: "Starts later", start: Date().addingTimeInterval(3 * 3600))
        ]
    }
}
