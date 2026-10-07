import Foundation
import UniformTypeIdentifiers

// AssignmentStore.swift
// Keeps your assignments, saves them on THIS Mac (assignments.json), sorts them, and can
// export/import backups. Nothing is synced or uploaded.

final class AssignmentStore: ObservableObject {
    @Published private(set) var items: [Assignment]
    /// Other tabs (like the browser) put a half-filled assignment here to open the editor.
    @Published var pendingDraft: Assignment?

    private let settings: AppSettings
    private let streak: StreakStore
    private static let fileName = "assignments.json"

    init(settings: AppSettings, streak: StreakStore) {
        self.settings = settings
        self.streak = streak
        items = LocalStore.load([Assignment].self, name: Self.fileName) ?? []
    }

    // MARK: Reading

    /// Not-yet-completed assignments, soonest first.
    var upcoming: [Assignment] {
        items.filter { !$0.isCompleted }.sorted { $0.due < $1.due }
    }

    var completed: [Assignment] {
        items.filter { $0.isCompleted }.sorted { ($0.completedAt ?? $0.due) > ($1.completedAt ?? $1.due) }
    }

    var nextDue: Assignment? { upcoming.first }

    func urgentCount(now: Date = Date()) -> Int {
        upcoming.filter { $0.isUrgent(now: now) }.count
    }

    // MARK: Changing

    func add(_ assignment: Assignment) {
        items.append(assignment)
        changed()
    }

    func update(_ assignment: Assignment) {
        guard let index = items.firstIndex(where: { $0.id == assignment.id }) else { return add(assignment) }
        let wasCompleted = items[index].isCompleted
        var updated = assignment
        if updated.isCompleted && updated.completedAt == nil { updated.completedAt = Date() }
        if !updated.isCompleted { updated.completedAt = nil }
        items[index] = updated
        if updated.isCompleted && !wasCompleted { celebrate() }
        changed()
    }

    func delete(_ assignment: Assignment) {
        items.removeAll { $0.id == assignment.id }
        changed()
    }

    func toggleComplete(_ assignment: Assignment) {
        guard var current = items.first(where: { $0.id == assignment.id }) else { return }
        if current.isCompleted {
            current.status = .notStarted
            current.completedAt = nil
        } else {
            current.status = .completed
            current.completedAt = Date()
        }
        update(current)
    }

    /// Adds text (like an AI answer) to the end of an assignment's notes.
    func appendNote(_ text: String, to assignmentID: UUID) {
        guard var current = items.first(where: { $0.id == assignmentID }) else { return }
        current.notes += (current.notes.isEmpty ? "" : "\n\n") + text
        update(current)
    }

    private func celebrate() {
        if settings.prefs.completionSounds { SoundPlayer.play(.complete) }
        streak.recordStudy()
    }

    private func changed() {
        LocalStore.save(items, name: Self.fileName)
        rescheduleReminders()
    }

    func reloadFromDisk() {
        items = LocalStore.load([Assignment].self, name: Self.fileName) ?? []
        rescheduleReminders()
    }

    // MARK: Reminders (only if you turned them on)

    func rescheduleReminders() {
        let notifications = NotificationManager.shared
        notifications.cancel(prefix: "assignment.")
        guard settings.prefs.assignmentReminders else { return }
        for assignment in upcoming {
            let subject = assignment.subject.isEmpty ? "Assignment" : assignment.subject
            notifications.schedule(id: "assignment.\(assignment.id).24h",
                                   title: "Due tomorrow: \(subject)",
                                   body: assignment.title,
                                   at: assignment.due.addingTimeInterval(-24 * 3600))
            notifications.schedule(id: "assignment.\(assignment.id).1h",
                                   title: "Due in 1 hour: \(subject)",
                                   body: assignment.title,
                                   at: assignment.due.addingTimeInterval(-3600))
        }
    }

    // MARK: Backup / export

    func exportJSON() -> Data {
        (try? LocalStore.encoder().encode(items)) ?? Data("[]".utf8)
    }

    func exportCSV() -> Data {
        let formatter = ISO8601DateFormatter()
        var lines = ["Subject,Title,Due,Priority,Status,Notes,Attachment"]
        for item in items.sorted(by: { $0.due < $1.due }) {
            let fields = [item.subject, item.title, formatter.string(from: item.due),
                          item.priority.title, item.status.title, item.notes, item.attachment]
            lines.append(fields.map(Self.csvEscape).joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    static func csvEscape(_ value: String) -> String {
        let needsQuotes = value.contains(",") || value.contains("\"") || value.contains("\n")
        let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
        return needsQuotes ? "\"\(escaped)\"" : escaped
    }

    /// Adds assignments from a JSON backup. Existing ones with the same id are kept as they are.
    @discardableResult
    func importJSON(_ data: Data) throws -> Int {
        let incoming = try LocalStore.decoder().decode([Assignment].self, from: data)
        let known = Set(items.map { $0.id })
        let fresh = incoming.filter { !known.contains($0.id) }
        items.append(contentsOf: fresh)
        changed()
        return fresh.count
    }
}
