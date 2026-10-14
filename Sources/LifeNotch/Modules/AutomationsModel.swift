import Foundation

// AutomationsModel.swift
// AI automations on a schedule: "every morning at 8, give me a 3-line summary of my day", for example.
// IMPORTANT: they only run while LifeNotch is running, only send the prompt text YOU wrote to YOUR chosen AI
// provider, and each one is switched on by you (after a confirmation). Results are shown here and in a
// notification. Nothing else is read or sent.

struct Automation: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    var prompt: String
    var hour: Int
    var minute: Int
    var enabled = true
    var lastRun: Date?
    var lastResult = ""
}

final class AutomationsModel: ObservableObject {
    @Published private(set) var items: [Automation]
    @Published private(set) var runningID: UUID?
    @Published var message = ""

    static let maxItems = 5
    private static let fileName = "automations.json"
    private var timer: Timer?
    private let settings: AppSettings

    init(settings: AppSettings) {
        self.settings = settings
        items = LocalStore.load([Automation].self, name: Self.fileName) ?? []
    }

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in self?.checkDue() }
    }

    // MARK: Editing

    func add(name: String, prompt: String, hour: Int, minute: Int) -> Bool {
        guard items.count < Self.maxItems else { message = "You can have up to \(Self.maxItems) automations."; return false }
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanPrompt.isEmpty else { return false }
        // Asked every time (there is no "always allow" for scheduled sending).
        guard ModalHelper.confirm(title: "Send this prompt every day?",
                                  message: "This prompt will be sent to \(settings.prefs.aiProvider.title) every day at \(String(format: "%02d:%02d", hour, minute)) while LifeNotch is running:\n\n\"\(String(cleanPrompt.prefix(200)))\"\n\nNothing else is sent. You can switch it off or delete it any time.",
                                  confirmTitle: "Allow") else { return false }
        items.append(Automation(name: name.isEmpty ? "Automation" : String(name.prefix(40)), prompt: String(cleanPrompt.prefix(1000)), hour: hour, minute: minute))
        save()
        return true
    }

    func toggle(_ item: Automation) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i].enabled.toggle()
        save()
    }

    func delete(_ item: Automation) {
        items.removeAll { $0.id == item.id }
        save()
    }

    // MARK: Running

    /// Pure rule (easy to test): is it past today's time and not yet run today?
    static func isDue(_ item: Automation, now: Date, calendar: Calendar = .current) -> Bool {
        guard item.enabled else { return false }
        guard let scheduled = calendar.date(bySettingHour: item.hour, minute: item.minute, second: 0, of: now), now >= scheduled else { return false }
        if let last = item.lastRun, last >= scheduled { return false }
        return true
    }

    private func checkDue() {
        let now = Date()
        for item in items where Self.isDue(item, now: now) && runningID == nil {
            Task { await run(item) }
            break
        }
    }

    @MainActor
    func run(_ item: Automation) async {
        guard runningID == nil else { return }
        runningID = item.id
        message = ""
        defer { runningID = nil }
        // Mark it as run first so a failure doesn't retry every 30 seconds.
        update(item.id) { $0.lastRun = Date() }
        do {
            let text = try await AIOneShot.run(system: "You are a concise assistant. Answer in at most 6 short lines.",
                                               prompt: item.prompt, settings: settings, maxTokens: 500)
            update(item.id) { $0.lastResult = text }
            NotificationManager.shared.notifyNow(id: "automation.\(item.id)", title: item.name, body: String(text.prefix(140)))
        } catch {
            update(item.id) { $0.lastResult = "Couldn't run: \(error.localizedDescription)" }
            message = error.localizedDescription
        }
    }

    private func update(_ id: UUID, _ change: (inout Automation) -> Void) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        change(&items[i])
        save()
    }

    private func save() { LocalStore.save(items, name: Self.fileName) }
}
