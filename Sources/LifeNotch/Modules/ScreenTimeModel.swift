import AppKit
import Foundation

// ScreenTimeModel.swift
// Your OWN app-usage tracker. (Apple's real Screen Time data is private, so LifeNotch can't read it.)
// When you switch it on, LifeNotch notes which app is in front and for how long, using the public
// "an app became active" notification. It records app NAMES and seconds only: never window titles, never
// what you type or see. Saved only on this Mac (screentime.json), last 30 days. Off by default.

struct ScreenTimeData: Codable, Equatable {
    /// "yyyy-MM-dd" -> app name -> seconds
    var days: [String: [String: Double]] = [:]
}

final class ScreenTimeModel: ObservableObject {
    @Published private(set) var data: ScreenTimeData
    @Published private(set) var isTracking = false

    private static let fileName = "screentime.json"
    private var currentApp: String?
    private var since = Date()
    private var observers: [NSObjectProtocol] = []
    private var saveTimer: Timer?

    init() { data = LocalStore.load(ScreenTimeData.self, name: Self.fileName) ?? ScreenTimeData() }

    // MARK: Tracking

    func start() {
        guard !isTracking else { return }
        isTracking = true
        currentApp = NSWorkspace.shared.frontmostApplication?.localizedName
        since = Date()
        let center = NSWorkspace.shared.notificationCenter
        observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            self?.switched(to: app?.localizedName)
        })
        for name in [NSWorkspace.screensDidSleepNotification, NSWorkspace.willSleepNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in self?.switched(to: nil) })
        }
        for name in [NSWorkspace.screensDidWakeNotification, NSWorkspace.didWakeNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.switched(to: NSWorkspace.shared.frontmostApplication?.localizedName)
            })
        }
        saveTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in self?.flush() }
    }

    func stop() {
        guard isTracking else { return }
        flush()
        currentApp = nil
        isTracking = false
        let center = NSWorkspace.shared.notificationCenter
        observers.forEach { center.removeObserver($0) }
        observers = []
        saveTimer?.invalidate()
        saveTimer = nil
    }

    private func switched(to app: String?) {
        flush()
        currentApp = app
    }

    /// Adds the time since the last note to the app that was in front, then saves.
    private func flush() {
        let now = Date()
        if let app = currentApp, isTracking {
            Self.add(seconds: now.timeIntervalSince(since), app: app, day: now, to: &data)
        }
        since = now
        LocalStore.save(data, name: Self.fileName)
    }

    func eraseAll() {
        data = ScreenTimeData()
        LocalStore.save(data, name: Self.fileName)
    }

    // MARK: Pure helpers (easy to test)

    static func dayKey(_ date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func add(seconds: Double, app: String, day: Date, to data: inout ScreenTimeData) {
        guard seconds > 0, seconds < 6 * 3600 else { return }
        data.days[dayKey(day), default: [:]][app, default: 0] += seconds
        if data.days.count > 30 {
            for key in data.days.keys.sorted().prefix(data.days.count - 30) { data.days[key] = nil }
        }
    }

    struct UsageEntry: Identifiable {
        let app: String
        let seconds: Double
        var id: String { app }
    }

    struct DayTotal: Identifiable {
        let day: Date
        let seconds: Double
        var id: Date { day }
    }

    func today() -> [UsageEntry] {
        (data.days[Self.dayKey(Date())] ?? [:]).map { UsageEntry(app: $0.key, seconds: $0.value) }.sorted { $0.seconds > $1.seconds }
    }

    func totals(lastDays: Int, now: Date = Date()) -> [DayTotal] {
        (0..<lastDays).reversed().compactMap { back in
            guard let date = Calendar.current.date(byAdding: .day, value: -back, to: now) else { return nil }
            return DayTotal(day: date, seconds: (data.days[Self.dayKey(date)] ?? [:]).values.reduce(0, +))
        }
    }

    static func text(seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(max(minutes, 0))m"
    }
}
