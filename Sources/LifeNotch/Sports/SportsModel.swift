import SwiftUI

// SportsModel.swift
// Fetches sports data from whichever provider you chose and keeps the latest results for
// the Sports tab and the compact bar countdown.
//
// Honesty rules built in:
//  - Demo data is always flagged (isDemo = true) and the screens show a "Demo Data" badge.
//  - If you choose a live source but it fails, you see the error. We do NOT quietly swap in demo data.
//  - If you choose football live but have no key, demo data is shown AND labelled as such.

final class SportsModel: ObservableObject {
    static let footballKeyAccount = "apikey.footballdata"

    @Published var nextRace: F1Race?
    @Published var latestResult: F1RaceResult?
    @Published var driverStandings: [F1Standing] = []
    @Published var f1IsDemo = true
    @Published var f1ProviderName = ""
    @Published var f1Error: String?
    @Published var isLoadingF1 = false

    @Published var matches: [FootballMatch] = []
    @Published var table: [FootballStanding] = []
    @Published var footballIsDemo = true
    @Published var footballProviderName = ""
    @Published var footballError: String?
    @Published var footballNotice: String?
    @Published var isLoadingFootball = false

    @Published var lastUpdated: Date?

    private let settings: AppSettings
    private var timer: Timer?

    init(settings: AppSettings) {
        self.settings = settings
    }

    // MARK: Providers

    private func makeF1Provider() -> F1DataProvider {
        settings.prefs.f1Source == .live ? JolpicaF1Provider() : DemoF1Provider()
    }

    private func makeFootballProvider() -> (provider: FootballDataProviding, notice: String?) {
        if settings.prefs.footballSource == .footballData {
            if let key = KeychainStore.get(account: Self.footballKeyAccount), !key.isEmpty {
                return (FootballDataOrgProvider(apiKey: key), nil)
            }
            return (DemoFootballProvider(), "No football-data.org key is saved, so this is Demo Data. Add a key in Settings > Sports.")
        }
        return (DemoFootballProvider(), nil)
    }

    // MARK: Refreshing

    func start() {
        Task { await refresh() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 20 * 60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            // Only talk to the internet if you chose a live source.
            if self.settings.prefs.f1Source == .live || self.settings.prefs.footballSource == .footballData {
                Task { await self.refresh() }
            }
        }
    }

    @MainActor
    func refreshIfStale() async {
        if let last = lastUpdated, Date().timeIntervalSince(last) < 300 { return }
        await refresh()
    }

    @MainActor
    func refresh() async {
        await refreshF1()
        await refreshFootball()
        lastUpdated = Date()
        rescheduleNotifications()
    }

    @MainActor
    func refreshF1() async {
        let provider = makeF1Provider()
        isLoadingF1 = true
        f1Error = nil
        do {
            nextRace = try await provider.nextRace()
            latestResult = try await provider.latestResult()
            driverStandings = try await provider.driverStandings()
            f1IsDemo = provider.isDemo
            f1ProviderName = provider.name
        } catch {
            f1Error = error.localizedDescription
        }
        isLoadingF1 = false
    }

    @MainActor
    func refreshFootball() async {
        let (provider, notice) = makeFootballProvider()
        isLoadingFootball = true
        footballError = nil
        footballNotice = notice
        let league = settings.prefs.footballLeague
        do {
            matches = try await provider.matches(league: league)
            table = try await provider.standings(league: league)
            footballIsDemo = provider.isDemo
            footballProviderName = provider.name
        } catch {
            footballError = error.localizedDescription
        }
        isLoadingFootball = false
    }

    // MARK: Favourites

    private func isFavourite(_ match: FootballMatch) -> Bool {
        settings.prefs.favouriteFootballTeams.contains { fav in
            teamMatches(favourite: fav, name: match.home, short: match.homeShort)
                || teamMatches(favourite: fav, name: match.away, short: match.awayShort)
        }
    }

    func isFavouriteTeam(_ name: String, short: String) -> Bool {
        settings.prefs.favouriteFootballTeams.contains { teamMatches(favourite: $0, name: name, short: short) }
    }

    var liveMatches: [FootballMatch] { matches.filter { $0.status == .live } }

    /// Upcoming matches for your favourite teams, soonest first.
    var favouriteUpcoming: [FootballMatch] {
        matches.filter { $0.status == .scheduled && $0.kickoff > Date() && isFavourite($0) }
            .sorted { $0.kickoff < $1.kickoff }
    }

    /// Most recent finished results (favourites first), newest first.
    var recentResults: [FootballMatch] {
        let finished = matches.filter { $0.status == .finished }.sorted { $0.kickoff > $1.kickoff }
        return finished.filter { isFavourite($0) } + finished.filter { !isFavourite($0) }
    }

    // MARK: Compact bar

    struct CompactInfo {
        let icon: String
        let text: String
        let isDemo: Bool
        let label: String
    }

    func compactInfo() -> CompactInfo? {
        switch settings.prefs.countdownSource {
        case .off:
            return nil
        case .f1:
            guard let race = nextRace, race.start > Date() else { return nil }
            let countdown = Countdown.short(to: race.start)
            return CompactInfo(icon: "flag.checkered", text: "F1 \(countdown)", isDemo: f1IsDemo,
                               label: "Next F1 race \(race.name) in \(countdown)\(f1IsDemo ? ", demo data" : "")")
        case .football:
            guard let match = favouriteUpcoming.first else { return nil }
            let countdown = Countdown.short(to: match.kickoff)
            let short = match.homeShort.isEmpty ? match.home : match.homeShort
            return CompactInfo(icon: "soccerball", text: "\(String(short.prefix(3)).uppercased()) \(countdown)",
                               isDemo: footballIsDemo,
                               label: "Next match \(match.home) versus \(match.away) in \(countdown)\(footballIsDemo ? ", demo data" : "")")
        }
    }

    // MARK: Notifications (live data only; never for demo data)

    func rescheduleNotifications() {
        let notifications = NotificationManager.shared
        notifications.cancel(prefix: "sports.")
        guard settings.prefs.sportsNotificationsEnabled else { return }
        let lead = TimeInterval(settings.prefs.sportsNotifyMinutesBefore * 60)

        if !f1IsDemo, let race = nextRace {
            notifications.schedule(id: "sports.f1.\(race.round)",
                                   title: "\(race.name) starts soon",
                                   body: "\(race.circuit), \(race.country)",
                                   at: race.start.addingTimeInterval(-lead))
        }
        if !footballIsDemo {
            for match in favouriteUpcoming.prefix(5) {
                notifications.schedule(id: "sports.football.\(match.id)",
                                       title: "\(match.home) vs \(match.away)",
                                       body: match.competition,
                                       at: match.kickoff.addingTimeInterval(-lead))
            }
        }
    }
}
