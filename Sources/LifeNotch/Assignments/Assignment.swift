import SwiftUI

// Assignment.swift
// What one school assignment looks like.

enum Priority: String, Codable, CaseIterable, Identifiable {
    case low, medium, high
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }
}

enum AssignmentStatus: String, Codable, CaseIterable, Identifiable {
    case notStarted, inProgress, completed
    var id: String { rawValue }
    var title: String {
        switch self {
        case .notStarted: return "Not started"
        case .inProgress: return "In progress"
        case .completed: return "Completed"
        }
    }
}

struct Assignment: Identifiable, Codable, Equatable {
    var id = UUID()
    var subject = ""
    var title = ""
    var due = Date().addingTimeInterval(24 * 3600)
    var priority: Priority = .medium
    var notes = ""
    /// A web link OR the path of a file on this Mac.
    var attachment = ""
    var status: AssignmentStatus = .notStarted
    var createdAt = Date()
    var completedAt: Date?

    var isCompleted: Bool { status == .completed }

    func isOverdue(now: Date = Date()) -> Bool { !isCompleted && due < now }

    /// Due within the next 24 hours (and not already overdue).
    func isDueSoon(now: Date = Date()) -> Bool {
        !isCompleted && due >= now && due.timeIntervalSince(now) <= 24 * 3600
    }

    /// Show the red warning?
    func isUrgent(now: Date = Date()) -> Bool { isOverdue(now: now) || isDueSoon(now: now) }

    /// Short text for the compact bar and warnings.
    func dueSummary(now: Date = Date()) -> String {
        isOverdue(now: now) ? "Overdue" : Countdown.short(to: due, from: now)
    }
}
