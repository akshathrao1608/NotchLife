import Foundation

// StreakStore.swift
// The study streak: how many days in a row you did something that counts as studying
// (finished a focus session, completed an assignment, or pressed "I studied today").
// Stored only on this Mac.

struct StreakData: Codable, Equatable {
    /// "2026-03-14" -> number of things you finished that day
    var studyDays: [String: Int] = [:]
}

final class StreakStore: ObservableObject {
    @Published private(set) var data: StreakData
    private static let fileName = "streak.json"

    init() {
        data = LocalStore.load(StreakData.self, name: Self.fileName) ?? StreakData()
    }

    // MARK: Recording

    func recordStudy(on date: Date = Date()) {
        let key = Self.dayKey(date)
        data.studyDays[key, default: 0] += 1
        LocalStore.save(data, name: Self.fileName)
    }

    func reloadFromDisk() {
        data = LocalStore.load(StreakData.self, name: Self.fileName) ?? StreakData()
    }

    // MARK: Reading

    var studiedToday: Bool { data.studyDays[Self.dayKey(Date())] != nil }
    var todayCount: Int { data.studyDays[Self.dayKey(Date())] ?? 0 }

    var currentStreak: Int {
        Self.currentStreak(days: Set(data.studyDays.keys), today: Date())
    }

    var longestStreak: Int {
        Self.longestStreak(days: Set(data.studyDays.keys))
    }

    /// The last 7 days, oldest first, for the little dots.
    func lastSevenDays(today: Date = Date()) -> [(label: String, studied: Bool)] {
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEEE"
        return (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            return (formatter.string(from: day), data.studyDays[Self.dayKey(day)] != nil)
        }
    }

    // MARK: Pure helpers (also used by the tests)

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    /// Consecutive days ending today. If you haven't studied yet today, yesterday still counts
    /// so your streak isn't lost until the day is over.
    static func currentStreak(days: Set<String>, today: Date, calendar: Calendar = .current) -> Int {
        var cursor = today
        if !days.contains(dayKey(cursor, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: cursor) else { return 0 }
            cursor = yesterday
        }
        var count = 0
        while days.contains(dayKey(cursor, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = previous
        }
        return count
    }

    static func longestStreak(days: Set<String>, calendar: Calendar = .current) -> Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = calendar
        formatter.timeZone = calendar.timeZone
        let dates = days.compactMap { formatter.date(from: $0) }.sorted()
        var best = 0
        var run = 0
        var previous: Date?
        for date in dates {
            if let prev = previous, let next = calendar.date(byAdding: .day, value: 1, to: prev),
               calendar.isDate(next, inSameDayAs: date) {
                run += 1
            } else {
                run = 1
            }
            best = max(best, run)
            previous = date
        }
        return best
    }
}
