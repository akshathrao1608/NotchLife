import Foundation

// ActivityStore.swift
// "Live Activities": little status items (a build running, a download, a countdown to an event...) shown in the
// notch bar. Up to TWO at once. They come from you or your own automations through:
//   - a link:      lifenotch://activity?id=build&title=Build&progress=0.4&symbol=hammer.fill&detail=Compiling
//   - the Shortcuts actions "Start / End a LifeNotch Live Activity"
//   - Terminal:    open "lifenotch://activity?id=build&title=Build&progress=0.4"
// They only DISPLAY text and a progress bar. They never run anything, and they disappear after 12 hours.

struct LiveActivity: Identifiable, Equatable {
    var id: String
    var title: String
    var symbol: String
    var progress: Double?      // 0...1, nil = no bar
    var detail: String
    var updated: Date
}

final class ActivityStore: ObservableObject {
    @Published private(set) var activities: [LiveActivity] = []
    static let maxActivities = 2
    static let lifetime: TimeInterval = 12 * 3600

    /// Starts or updates an activity. Returns false if two others are already showing.
    @discardableResult
    func upsert(id: String, title: String, symbol: String = "bolt.fill", progress: Double? = nil, detail: String = "", now: Date = Date()) -> Bool {
        prune(now: now)
        let cleanID = String(id.prefix(40))
        let item = LiveActivity(id: cleanID,
                                title: String(title.prefix(24)),
                                symbol: Self.safeSymbol(symbol),
                                progress: progress.map { min(max($0, 0), 1) },
                                detail: String(detail.prefix(60)),
                                updated: now)
        if let index = activities.firstIndex(where: { $0.id == cleanID }) {
            activities[index] = item
            return true
        }
        guard activities.count < Self.maxActivities else { return false }
        activities.append(item)
        return true
    }

    func end(id: String) { activities.removeAll { $0.id == id } }
    func endAll() { activities = [] }

    func prune(now: Date = Date()) {
        activities.removeAll { now.timeIntervalSince($0.updated) > Self.lifetime }
    }

    /// Only plain SF Symbol names (letters, digits, dots) are used.
    static func safeSymbol(_ name: String) -> String {
        let ok = !name.isEmpty && name.count <= 40 && name.allSatisfy { $0.isLetter || $0.isNumber || $0 == "." }
        return ok ? name : "bolt.fill"
    }
}
