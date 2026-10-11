import Foundation

// CountdownStore.swift
// "Days until" things: exams, trips, birthdays. Saved only on this Mac (countdowns.json).

struct CountdownItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var date: Date
}

final class CountdownStore: ObservableObject {
    @Published private(set) var items: [CountdownItem]
    private static let fileName = "countdowns.json"

    init() { items = LocalStore.load([CountdownItem].self, name: Self.fileName) ?? [] }

    var sorted: [CountdownItem] { items.sorted { $0.date < $1.date } }

    /// Whole calendar days from `now` to `date` (0 = today, negative = past).
    static func daysUntil(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: now)
        let b = calendar.startOfDay(for: date)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    static func text(days: Int) -> String {
        switch days {
        case 0: return "Today"
        case 1: return "Tomorrow"
        case -1: return "Yesterday"
        case ..<0: return "\(-days) days ago"
        default: return "\(days) days"
        }
    }

    func add(title: String, date: Date) {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        items.append(CountdownItem(title: trimmed, date: date))
        save()
    }

    func delete(_ item: CountdownItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    private func save() { LocalStore.save(items, name: Self.fileName) }
}
