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
    let messages: MessageHub
    let todos = TodoStore()
    let keepAwake = KeepAwakeModel()
    let shelf = ShelfStore()
    let fileSearch = FileSearchModel()
    let weather = WeatherModel()
    let toolTimer: ToolTimerModel
    let clipboard: ClipboardMonitor
    let nowPlaying = NowPlayingModel()
    let snapper = WindowSnapper()
    let calendar = CalendarModel()
    let voice = VoiceNotesModel()
    let convert = ConvertModel()
    let flights = FlightRadarModel()
    let habits = HabitStore()
    let devices = DevicesModel()
    let tracking = TrackingModel()
    let tennis = TennisModel()
    let markets = MarketsModel()
    let profiles = ProfilesStore()
    let audio = AudioModel()
    let screenTime = ScreenTimeModel()
    let chat = LANChatModel()
    let activities = ActivityStore()
    let plugins = PluginManager()
    let vpn = VPNModel()
    let scores: ScoresStore
    let automations: AutomationsModel
    let notesSync: NotesSync
    private let keyClick = KeyClickModel()
    let countdowns = CountdownStore()
    let capture: ScreenCaptureCoordinator
    private var extraHotKeys: ExtraHotKeys?
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
        messages = MessageHub(settings: settings)
        toolTimer = ToolTimerModel(settings: settings)
        automations = AutomationsModel(settings: settings)
        scores = ScoresStore(settings: settings)
        notesSync = NotesSync(settings: settings, notes: notes)
        capture = ScreenCaptureCoordinator(settings: settings, ai: ai, notch: notch)
    }

    /// Called once when the app launches.
    func start() {
        assignments.rescheduleReminders()
        sports.start()
        calendar.refreshIfAuthorized()
        extraHotKeys = ExtraHotKeys(env: self)
        automations.start()
        // Keep followed teams fresh for the notch bar even when the Scores tab is closed (only if you follow something).
        Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            guard let self = self, self.scores.hasFollows else { return }
            Task { await self.scores.refreshFollowed() }
        }
        if scores.hasFollows { Task { await scores.refreshFollowed() } }
        notesSync.syncNow()
        // Screen Time tracking follows its switch.
        settings.$prefs
            .map { $0.screenTimeEnabled }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] on in if on { self?.screenTime.start() } else { self?.screenTime.stop() } }
            .store(in: &cancellables)
        // Keyboard click sounds (only when you turned them on and macOS allowed it).
        settings.$prefs
            .map { [$0.keyClickEnabled ? "on" : "off", $0.keyClickSound, String($0.keyClickVolume)] }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.applyKeyClick() }
            .store(in: &cancellables)
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

extension AppEnvironment {
    fileprivate func applyKeyClick() {
        let prefs = settings.prefs
        if prefs.keyClickEnabled {
            if !keyClick.start(soundName: prefs.keyClickSound, volume: prefs.keyClickVolume) {
                settings.prefs.keyClickEnabled = false
                ModalHelper.info(title: "Allow Input Monitoring first",
                                 message: "Open System Settings > Privacy & Security > Input Monitoring, switch LifeNotch on, then turn \"Keyboard click sounds\" on again.")
            }
        } else {
            keyClick.stop()
        }
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
            .environmentObject(env.messages)
            .environmentObject(env.todos)
            .environmentObject(env.keepAwake)
            .environmentObject(env.shelf)
            .environmentObject(env.fileSearch)
            .environmentObject(env.weather)
            .environmentObject(env.toolTimer)
            .environmentObject(env.nowPlaying)
            .environmentObject(env.snapper)
            .environmentObject(env.calendar)
            .environmentObject(env.voice)
            .environmentObject(env.convert)
            .environmentObject(env.flights)
            .environmentObject(env.habits)
            .environmentObject(env.devices)
            .environmentObject(env.tracking)
            .environmentObject(env.tennis)
            .environmentObject(env.markets)
            .environmentObject(env.profiles)
            .environmentObject(env.audio)
            .environmentObject(env.screenTime)
            .environmentObject(env.chat)
            .environmentObject(env.activities)
            .environmentObject(env.plugins)
            .environmentObject(env.vpn)
            .environmentObject(env.scores)
            .environmentObject(env.automations)
            .environmentObject(env.notesSync)
            .environmentObject(env.countdowns)
            .environmentObject(env.capture)
    }
}
