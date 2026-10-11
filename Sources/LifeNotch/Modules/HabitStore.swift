import Foundation

// HabitStore.swift
// Daily habits you tick off, with a streak counter. Saved only on this Mac (habits.json).

struct Habit: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// Days you did it, as "yyyy-MM-dd" text so time zones never confuse it.
    var doneDays: Set<String> = []
}

final class HabitStore: ObservableObject {
    @Published private(set) var habits: [Habit]
    private static let fileName = "habits.json"

    init() { habits = LocalStore.load([Habit].self, name: Self.fileName) ?? [] }

    static func key(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func isDone(_ habit: Habit, on date: Date = Date()) -> Bool { habit.doneDays.contains(Self.key(date)) }

    /// Days in a row ending today (or yesterday, so a streak isn't lost before you've ticked today).
    static func streak(_ habit: Habit, today: Date = Date(), calendar: Calendar = .current) -> Int {
        var day = today
        if !habit.doneDays.contains(key(day, calendar: calendar)) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = yesterday
        }
        var count = 0
        while habit.doneDays.contains(key(day, calendar: calendar)) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    func add(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        habits.append(Habit(name: trimmed))
        save()
    }

    func toggleToday(_ habit: Habit) {
        guard let i = habits.firstIndex(where: { $0.id == habit.id }) else { return }
        let k = Self.key(Date())
        if habits[i].doneDays.contains(k) { habits[i].doneDays.remove(k) } else { habits[i].doneDays.insert(k) }
        save()
    }

    func delete(_ habit: Habit) {
        habits.removeAll { $0.id == habit.id }
        save()
    }

    private func save() { LocalStore.save(habits, name: Self.fileName) }
}
