import Foundation
import EventKit

// CalendarModel.swift
// Reads your next calendar events and adds events or reminders you type in Quick Add.
// It never touches Calendar or Reminders until you press the "Connect" button and say yes
// to both LifeNotch's question and macOS's own permission question.

struct CalendarEntry: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let calendar: String
}

final class CalendarModel: ObservableObject {
    @Published private(set) var upcoming: [CalendarEntry] = []
    @Published private(set) var connected = false
    @Published var message = ""

    private let store = EKEventStore()

    var nextEvent: CalendarEntry? { upcoming.first { $0.end > Date() } }

    @MainActor
    func connect(settings: AppSettings) async {
        guard ConsentGate.request(.calendarAccess, settings: settings,
                                  explanation: "LifeNotch will read your upcoming events (to show \"Up next\") and add events or reminders only when you press Add in Quick Add. Event details stay on this Mac.") else { return }
        do {
            connected = try await store.requestFullAccessToEvents()
            message = connected ? "" : "Calendar access was not allowed. You can change this in System Settings > Privacy & Security > Calendars."
            if connected { refresh() }
        } catch {
            message = error.localizedDescription
        }
    }

    /// Only refreshes if access was already granted (never triggers a permission question).
    func refreshIfAuthorized() {
        if EKEventStore.authorizationStatus(for: .event) == .fullAccess {
            connected = true
            refresh()
        }
    }

    func refresh() {
        guard connected else { return }
        let now = Date()
        let end = Calendar.current.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 86400)
        let predicate = store.predicateForEvents(withStart: now, end: end, calendars: nil)
        upcoming = store.events(matching: predicate)
            .sorted { $0.startDate < $1.startDate }
            .prefix(20)
            .map { CalendarEntry(id: $0.eventIdentifier ?? UUID().uuidString, title: $0.title ?? "Event",
                                 start: $0.startDate, end: $0.endDate, isAllDay: $0.isAllDay,
                                 calendar: $0.calendar?.title ?? "") }
    }

    // MARK: Adding

    @MainActor
    func addEvent(title: String, start: Date, minutes: Int = 60) throws {
        guard connected else { throw QuickAddError.notConnected }
        let event = EKEvent(eventStore: store)
        event.title = title
        event.startDate = start
        event.endDate = start.addingTimeInterval(TimeInterval(minutes * 60))
        event.calendar = store.defaultCalendarForNewEvents
        try store.save(event, span: .thisEvent)
        refresh()
    }

    @MainActor
    func addReminder(title: String, due: Date?, settings: AppSettings) async throws {
        guard ConsentGate.request(.calendarAccess, settings: settings,
                                  explanation: "LifeNotch will add one item to your Reminders app.") else { throw QuickAddError.declined }
        guard try await store.requestFullAccessToReminders() else { throw QuickAddError.remindersDenied }
        let reminder = EKReminder(eventStore: store)
        reminder.title = title
        reminder.calendar = store.defaultCalendarForNewReminders()
        if let due = due {
            reminder.dueDateComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: due)
            reminder.addAlarm(EKAlarm(absoluteDate: due))
        }
        try store.save(reminder, commit: true)
    }
}

enum QuickAddError: LocalizedError {
    case notConnected, declined, remindersDenied
    var errorDescription: String? {
        switch self {
        case .notConnected: return "Connect your calendar first."
        case .declined: return "Cancelled."
        case .remindersDenied: return "Reminders access was not allowed. You can change this in System Settings > Privacy & Security > Reminders."
        }
    }
}

// MARK: - Understanding "lunch with Sam tomorrow 1pm"

struct QuickAddParse: Equatable {
    var title: String
    var date: Date?
}

enum QuickAddParser {
    /// Finds a date/time phrase in plain English and removes it from the title.
    static func parse(_ text: String, now: Date = Date()) -> QuickAddParse {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return QuickAddParse(title: "", date: nil) }
        guard let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.date.rawValue) else {
            return QuickAddParse(title: trimmed, date: nil)
        }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let match = detector.matches(in: trimmed, options: [], range: range).first
        guard let found = match, let date = found.date, let swiftRange = Range(found.range, in: trimmed) else {
            return QuickAddParse(title: trimmed, date: nil)
        }
        var title = trimmed
        title.removeSubrange(swiftRange)
        title = title.replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: CharacterSet(charactersIn: ",-–").union(.whitespaces))
        for tail in [" at", " on", " by"] where title.lowercased().hasSuffix(tail) { title = String(title.dropLast(tail.count)) }
        if title.isEmpty { title = trimmed }
        return QuickAddParse(title: title, date: date)
    }
}
