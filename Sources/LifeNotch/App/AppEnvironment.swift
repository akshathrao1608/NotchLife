import SwiftUI
import Combine

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
    let scores = GameScores()
    let stats = SystemStatsModel()
    let cleanDesk = CleanDeskModel()
    let ambient: AmbientPlayer
    let clipboard: ClipboardMonitor
    private var cancellables = Set<AnyCancellable>()

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
        ambient = AmbientPlayer(settings: settings)
        clipboard = ClipboardMonitor(settings: settings)
    }

    /// Called once when the app launches.
    func start() {
        assignments.rescheduleReminders()
        sports.start()
        // Battery and Wi-Fi are only read in the background while the compact bar shows them.
        settings.$prefs
            .map { $0.showBattery || $0.showWifi }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] needed in
                if needed { self?.stats.startLightRefresh() } else { self?.stats.stopLightRefresh() }
            }
            .store(in: &cancellables)
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
            .environmentObject(env.scores)
            .environmentObject(env.stats)
            .environmentObject(env.cleanDesk)
            .environmentObject(env.ambient)
            .environmentObject(env.clipboard)
    }
}
