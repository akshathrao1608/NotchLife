import SwiftUI

// AppEnvironment.swift
// One place that creates and holds every "model" (the objects that remember data).
// Each tab's screen gets the models it needs automatically through `injectEnvironment`.
// As we add features in later build steps, new models are added here.

final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let settings: AppSettings
    let notch = NotchState()
    let notes = NotesStore()
    let ai: AIViewModel
    let history: BrowsingHistory
    let browser: BrowserModel
    let streak: StreakStore
    let assignments: AssignmentStore
    let pomodoro: PomodoroModel
    let sports: SportsModel

    /// Set by the AppDelegate once the window exists.
    var panel: NotchPanelController?

    /// True when another app already owns the global shortcut.
    @Published var hotKeyRegistrationFailed = false

    private init() {
        // Models that need the settings are built from a local constant first.
        let settings = AppSettings()
        self.settings = settings
        ai = AIViewModel(settings: settings)
        let streak = StreakStore()
        self.streak = streak
        let history = BrowsingHistory()
        self.history = history
        browser = BrowserModel(settings: settings, history: history)
        assignments = AssignmentStore(settings: settings, streak: streak)
        pomodoro = PomodoroModel(settings: settings, streak: streak)
        sports = SportsModel(settings: settings)
    }

    /// Called once when the app launches.
    func start() {
        assignments.rescheduleReminders()
        sports.start()
    }
}

extension View {
    /// Hands every model to this view and everything inside it.
    func injectEnvironment(_ env: AppEnvironment) -> some View {
        self
            .environmentObject(env)
            .environmentObject(env.settings)
            .environmentObject(env.notch)
            .environmentObject(env.notes)
            .environmentObject(env.ai)
            .environmentObject(env.history)
            .environmentObject(env.browser)
            .environmentObject(env.streak)
            .environmentObject(env.assignments)
            .environmentObject(env.pomodoro)
            .environmentObject(env.sports)
    }
}
