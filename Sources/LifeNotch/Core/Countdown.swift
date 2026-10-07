import Foundation

// Countdown.swift
// Turns "a date in the future" into short text like "3d 4h", "2h 15m" or "12m".

enum Countdown {
    /// Short text for the compact bar.
    static func short(to date: Date, from now: Date = Date()) -> String {
        let total = Int(date.timeIntervalSince(now))
        if total <= 0 { return "now" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(minutes)m" }
        return "\(max(minutes, 1))m"
    }

    /// Longer text for the Sports tab, e.g. "3 days, 4 hours, 12 min".
    static func long(to date: Date, from now: Date = Date()) -> String {
        let total = Int(date.timeIntervalSince(now))
        if total <= 0 { return "Started" }
        let days = total / 86_400
        let hours = (total % 86_400) / 3_600
        let minutes = (total % 3_600) / 60
        var parts: [String] = []
        if days > 0 { parts.append("\(days) day\(days == 1 ? "" : "s")") }
        if hours > 0 { parts.append("\(hours) hour\(hours == 1 ? "" : "s")") }
        if days == 0 { parts.append("\(minutes) min") }
        return parts.joined(separator: ", ")
    }

    /// "mm:ss" for the focus timer.
    static func clock(_ seconds: TimeInterval) -> String {
        let s = max(0, Int(seconds.rounded(.up)))
        return String(format: "%02d:%02d", s / 60, s % 60)
    }
}
