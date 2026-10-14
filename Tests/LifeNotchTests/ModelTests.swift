import XCTest
@testable import LifeNotch

final class ModelTests: XCTestCase {
    func testAssignmentUrgency() {
        let now = Date()
        var a = Assignment()
        a.due = now.addingTimeInterval(3 * 3600)
        XCTAssertTrue(a.isDueSoon(now: now))
        XCTAssertTrue(a.isUrgent(now: now))
        a.due = now.addingTimeInterval(3 * 86_400)
        XCTAssertFalse(a.isUrgent(now: now))
        a.due = now.addingTimeInterval(-60)
        XCTAssertTrue(a.isOverdue(now: now))
        a.status = .completed
        XCTAssertFalse(a.isUrgent(now: now), "completed work is never urgent")
    }

    func testCSVEscaping() {
        XCTAssertEqual(AssignmentStore.csvEscape("plain"), "plain")
        XCTAssertEqual(AssignmentStore.csvEscape("a,b"), "\"a,b\"")
        XCTAssertEqual(AssignmentStore.csvEscape("say \"hi\""), "\"say \"\"hi\"\"\"")
    }

    func testCountdownText() {
        let now = Date()
        XCTAssertEqual(Countdown.short(to: now.addingTimeInterval(3 * 86_400 + 4 * 3600 + 30), from: now), "3d 4h")
        XCTAssertEqual(Countdown.short(to: now.addingTimeInterval(2 * 3600 + 15 * 60 + 5), from: now), "2h 15m")
        XCTAssertEqual(Countdown.short(to: now.addingTimeInterval(12 * 60 + 5), from: now), "12m")
        XCTAssertEqual(Countdown.short(to: now.addingTimeInterval(-5), from: now), "now")
        XCTAssertEqual(Countdown.clock(125), "02:05")
    }

    func testStreaks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let today = calendar.date(from: DateComponents(year: 2026, month: 3, day: 10))!
        let days: Set<String> = ["2026-03-10", "2026-03-09", "2026-03-08", "2026-03-05"]
        XCTAssertEqual(StreakStore.currentStreak(days: days, today: today, calendar: calendar), 3)
        // Not studied yet today: yesterday's streak still counts.
        let noToday: Set<String> = ["2026-03-09", "2026-03-08"]
        XCTAssertEqual(StreakStore.currentStreak(days: noToday, today: today, calendar: calendar), 2)
        XCTAssertEqual(StreakStore.currentStreak(days: ["2026-03-01"], today: today, calendar: calendar), 0)
        XCTAssertEqual(StreakStore.longestStreak(days: days, calendar: calendar), 3)
    }

    func testTeamMatching() {
        XCTAssertTrue(teamMatches(favourite: "Arsenal", name: "Arsenal FC", short: "Arsenal"))
        XCTAssertTrue(teamMatches(favourite: "man city", name: "Manchester City FC", short: "Man City"))
        XCTAssertFalse(teamMatches(favourite: "Chelsea", name: "Arsenal FC", short: "Arsenal"))
        XCTAssertFalse(teamMatches(favourite: "", name: "Arsenal FC", short: "Arsenal"))
    }

    func testCoreTabsAreTheOriginalEight() {
        XCTAssertEqual(NotchTab.core.count, 8)
        XCTAssertEqual(Preferences().pinnedTabs, NotchTab.core)
        XCTAssertTrue(Set(NotchTab.core).isSubset(of: Set(NotchTab.allCases)))
    }

    func testEveryProviderHasAModelAndKeyRule() {
        for provider in AIProviderKind.allCases {
            XCTAssertFalse(provider.defaultModel.isEmpty)
            XCTAssertEqual(Preferences().modelName(for: provider), provider.defaultModel)
            if let base = provider.compatibleBaseURL { XCTAssertNotNil(URL(string: base)) }
        }
        XCTAssertFalse(AIProviderKind.ollama.needsKey)
        XCTAssertTrue(AIProviderKind.gemini.needsKey)
    }

    func testPreferencesRoundTripAndDefaults() throws {
        let defaults = Preferences()
        XCTAssertFalse(defaults.showBattery)
        XCTAssertFalse(defaults.showWifi)
        XCTAssertFalse(defaults.showTime)
        XCTAssertFalse(defaults.browserHistoryEnabled)
        XCTAssertFalse(defaults.messagesEnabled)
        XCTAssertFalse(defaults.clipboardHistoryEnabled)
        XCTAssertTrue(defaults.blockPopups)
        let data = try JSONEncoder().encode(defaults)
        XCTAssertEqual(try JSONDecoder().decode(Preferences.self, from: data), defaults)
    }
}

final class GameTests: XCTestCase {
    /// Evaluates the simple question formats (a + b, a × b + c, a ÷ b...) independently.
    private func evaluate(_ text: String) -> Int? {
        let parts = text.split(separator: " ").map(String.init)
        var numbers: [Int] = []
        var operators: [String] = []
        for (index, part) in parts.enumerated() {
            if index % 2 == 0 { guard let n = Int(part) else { return nil }; numbers.append(n) } else { operators.append(part) }
        }
        // multiply / divide first
        var i = 0
        while i < operators.count {
            if operators[i] == "×" || operators[i] == "÷" {
                let result = operators[i] == "×" ? numbers[i] * numbers[i + 1] : numbers[i] / numbers[i + 1]
                numbers.replaceSubrange(i...(i + 1), with: [result])
                operators.remove(at: i)
            } else { i += 1 }
        }
        var total = numbers[0]
        for (index, op) in operators.enumerated() {
            total = op == "+" ? total + numbers[index + 1] : total - numbers[index + 1]
        }
        return total
    }

    func testMathQuestionsAreCorrectAndNeverNegative() {
        for difficulty in MathsDifficulty.allCases {
            for _ in 0..<300 {
                let q = MathQuestion.make(difficulty)
                XCTAssertEqual(evaluate(q.text.replacingOccurrences(of: "−", with: "-")), q.answer, q.text)
                XCTAssertGreaterThanOrEqual(q.answer, 0, q.text)
            }
        }
    }

    func testCanMakeRespectsLetterCounts() {
        let letters = Array("planet")
        XCTAssertTrue(WordRush.canMake("plan", from: letters))
        XCTAssertTrue(WordRush.canMake("planet", from: letters))
        XCTAssertFalse(WordRush.canMake("plant s", from: letters))
        XCTAssertFalse(WordRush.canMake("pall", from: letters), "only one l")
    }

    func testWordPoints() {
        XCTAssertEqual(WordRush.points(for: "ab"), 0)
        XCTAssertEqual(WordRush.points(for: "cat"), 1)
        XCTAssertEqual(WordRush.points(for: "cats"), 2)
        XCTAssertEqual(WordRush.points(for: "plant"), 4)
        XCTAssertEqual(WordRush.points(for: "planet"), 7)
    }

    func testEverySeedIsInTheDictionaryAndRoundsAreFair() {
        for seed in WordList.seeds {
            XCTAssertTrue(WordList.words.contains(seed), seed)
            XCTAssertEqual(seed.count, 6, seed)
        }
        for _ in 0..<20 {
            let letters = WordRush.newRound()
            XCTAssertEqual(letters.count, 6)
            XCTAssertGreaterThanOrEqual(WordRush.possibleWords(from: letters).count, 12)
        }
    }

    func testPenaltyOutcomes() {
        XCTAssertEqual(Penalty.outcome(shot: .left, keeper: .left, wide: false), .saved)
        XCTAssertEqual(Penalty.outcome(shot: .left, keeper: .right, wide: false), .goal)
        XCTAssertEqual(Penalty.outcome(shot: .centre, keeper: .left, wide: true), .missed)
    }
}

final class ModuleTests: XCTestCase {
    func testCalculator() {
        XCTAssertEqual(Calculator.evaluate("(12.5 + 7) × 3"), 58.5)
        XCTAssertEqual(Calculator.evaluate("2^3^2"), 512)            // right-associative
        XCTAssertEqual(Calculator.evaluate("-3 + 5"), 2)
        XCTAssertEqual(Calculator.evaluate("-2^2"), -4)
        XCTAssertEqual(Calculator.evaluate("50%"), 0.5)
        XCTAssertEqual(Calculator.evaluate("sqrt(16) + abs(-2)"), 6)
        XCTAssertNil(Calculator.evaluate("1/0"))
        XCTAssertNil(Calculator.evaluate("2 +"))
        XCTAssertNil(Calculator.evaluate("hello"))
        XCTAssertNil(Calculator.evaluate("rm -rf /"))
        XCTAssertEqual(Calculator.format(4.0), "4")
        XCTAssertEqual(Calculator.format(0.5), "0.5")
    }

    func testUnitConversion() {
        let km = UnitCategory.length.units.first { $0.name == "Kilometres" }!.unit
        let m = UnitCategory.length.units.first { $0.name == "Metres" }!.unit
        XCTAssertEqual(UnitCategory.convert(2, from: km, to: m), 2000, accuracy: 0.001)
        let c = UnitCategory.temperature.units.first { $0.name == "Celsius" }!.unit
        let f = UnitCategory.temperature.units.first { $0.name == "Fahrenheit" }!.unit
        XCTAssertEqual(UnitCategory.convert(100, from: c, to: f), 212, accuracy: 0.001)
    }

    func testBoard2048() {
        XCTAssertEqual(Board2048.slide([2, 2, 2, 2]).line, [4, 4, 0, 0])
        XCTAssertEqual(Board2048.slide([2, 2, 4, 0]).line, [4, 4, 0, 0])
        XCTAssertEqual(Board2048.slide([0, 2, 0, 2]).line, [4, 0, 0, 0])
        XCTAssertEqual(Board2048.slide([4, 2, 2, 8]).gained, 4)
        var board = Board2048()
        board.cells[0] = [2, 0, 0, 2]
        XCTAssertTrue(board.move(.left))
        XCTAssertEqual(board.cells[0], [4, 0, 0, 0])
        XCTAssertEqual(board.score, 4)
        board.cells[0] = [2, 4, 8, 16]
        board.cells[1] = [4, 8, 16, 32]
        board.cells[2] = [8, 16, 32, 64]
        board.cells[3] = [16, 32, 64, 128]
        XCTAssertFalse(board.hasMoves)
    }

    func testSnake() {
        var generator = SystemRandomNumberGenerator()
        var state = SnakeState()
        state.food = GridPoint(x: 6, y: 6)
        state.step(using: &generator)                       // moves right, eats the food
        XCTAssertEqual(state.score, 1)
        XCTAssertEqual(state.body.count, 4)
        state.turn(to: GridPoint(x: -1, y: 0))              // U-turn is ignored
        XCTAssertEqual(state.queued, GridPoint(x: 1, y: 0))
        state.body = [GridPoint(x: 19, y: 0)]
        state.direction = GridPoint(x: 1, y: 0)
        state.queued = GridPoint(x: 1, y: 0)
        state.step(using: &generator)                       // hits the wall
        XCTAssertFalse(state.alive)
    }

    func testStopwatchText() {
        XCTAssertEqual(ToolTimerModel.stopwatchText(65.34), "01:05.3")
        XCTAssertEqual(ToolTimerModel.stopwatchText(3725.0), "1:02:05.0")
    }

    func testWeatherCodes() {
        XCTAssertEqual(WeatherModel.describe(code: 0, isDay: true).1, "Clear")
        XCTAssertEqual(WeatherModel.describe(code: 63, isDay: true).1, "Rain")
        XCTAssertEqual(WeatherModel.describe(code: 95, isDay: false).1, "Thunderstorm")
    }

    func testSnapZoneMaths() {
        let area = CGRect(x: 0, y: 25, width: 1000, height: 800)
        XCTAssertEqual(SnapZone.rightHalf.frame(in: area), CGRect(x: 500, y: 25, width: 500, height: 800))
        XCTAssertEqual(SnapZone.maximize.frame(in: area), area)
    }

    func testQuickAddParserKeepsTitleLetters() {
        let result = QuickAddParser.parse("Eat tomorrow at 5pm")
        XCTAssertNotNil(result.date)
        XCTAssertTrue(result.title.hasPrefix("Eat"))
        XCTAssertNil(QuickAddParser.parse("buy milk").date)
    }

    func testFlightBoxAndParse() {
        let box = FlightRadarModel.box(lat: 0, lon: 0, rangeKm: 111)
        XCTAssertEqual(box.maxLat, 1, accuracy: 0.001)
        let json = #"{"states":[["abc123","BAW1  ","UK",0,0,-0.5,51.5,10000.0,false,200.0,90.0]]}"#
        let planes = FlightRadarModel.parse(Data(json.utf8))
        XCTAssertEqual(planes.first?.callsign, "BAW1")
        XCTAssertEqual(planes.first?.altitudeText, "32,808 ft")
    }

    func testConvertNeverOverwrites() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let first = ConvertModel.freeURL(base: dir, name: "pic", ext: "png")
        try Data().write(to: first)
        XCTAssertEqual(ConvertModel.freeURL(base: dir, name: "pic", ext: "png").lastPathComponent, "pic 2.png")
    }

    func testHabitStreak() {
        var habit = Habit(name: "Read")
        let cal = Calendar.current
        let today = Date()
        for back in 0..<3 { habit.doneDays.insert(HabitStore.key(cal.date(byAdding: .day, value: -back, to: today)!)) }
        XCTAssertEqual(HabitStore.streak(habit), 3)
        habit.doneDays.remove(HabitStore.key(today))
        XCTAssertEqual(HabitStore.streak(habit), 2)   // streak survives until the day is over
    }

    func testDaysUntilText() {
        XCTAssertEqual(CountdownStore.text(days: 0), "Today")
        XCTAssertEqual(CountdownStore.text(days: 5), "5 days")
        XCTAssertEqual(CountdownStore.daysUntil(Date().addingTimeInterval(3 * 86400 + 60)), 3)
    }

    func testCarrierAndFlightNumber() {
        XCTAssertEqual(TrackingDetect.carrier(for: "1Z999AA10123456784"), .ups)
        XCTAssertEqual(TrackingDetect.carrier(for: "TBA123456789012"), .amazon)
        XCTAssertEqual(TrackingDetect.carrier(for: "hello"), .unknown)
        XCTAssertEqual(FlightNumber.callsign(from: "ba 117"), "BAW117")
        XCTAssertEqual(FlightNumber.callsign(from: "U2123"), "EZY123")
        XCTAssertEqual(FlightNumber.callsign(from: "BAW117"), "BAW117")
    }

    func testBluetoothParse() {
        let json = #"{"SPBluetoothDataType":[{"device_connected":[{"My AirPods":{"device_address":"AA:BB","device_minorType":"Headphones","device_batteryLevelLeft":"80%","device_batteryLevelCase":"55%"}}]}]}"#
        let gadgets = DevicesModel.parse(Data(json.utf8))
        XCTAssertEqual(gadgets.first?.name, "My AirPods")
        XCTAssertEqual(gadgets.first?.batteries.map { $0.percent }, [80, 55])
    }

    func testSkyFlight() {
        var state = SkyFlightState()
        state.objects = [SkyObject(kind: .ring, x: SkyFlightState.planeX, y: state.planeY)]
        var generator = SystemRandomNumberGenerator()
        state.step(dt: 0.01, using: &generator)
        XCTAssertEqual(state.score, 1)
        state.objects = [SkyObject(kind: .storm, x: SkyFlightState.planeX, y: state.planeY)]
        state.step(dt: 0.01, using: &generator)
        XCTAssertFalse(state.alive)
    }

    func testMarketsParseAndNormalise() {
        let csv = "Symbol,Date,Time,Open,High,Low,Close,Volume\nAAPL.US,2026-10-14,22:00:00,100,105,99,104,12345\n"
        let quotes = MarketsModel.parse(csv)
        XCTAssertEqual(quotes.first?.symbol, "aapl.us")
        XCTAssertEqual(quotes.first?.changePercent ?? 0, 4, accuracy: 0.001)
        XCTAssertEqual(MarketsModel.normalise("TSLA"), "tsla.us")
        XCTAssertEqual(MarketsModel.normalise("^spx"), "^spx")
        XCTAssertNil(MarketsModel.normalise("bad symbol!"))
    }

    func testTennisParse() {
        let json = #"{"events":[{"name":"Demo Open","competitions":[{"id":"1","competitors":[{"athlete":{"displayName":"A"},"linescores":[{"value":6.0},{"value":4.0}]},{"athlete":{"displayName":"B"},"linescores":[{"value":3.0},{"value":6.0}]}],"status":{"type":{"state":"in","shortDetail":"2nd set"}}}]}]}"#
        let matches = TennisModel.parse(Data(json.utf8))
        XCTAssertEqual(matches.first?.scoreText, "6-3  4-6")
        XCTAssertEqual(matches.first?.state, "in")
    }

    func testProfileKeepsPrivacyAnswers() throws {
        var saved = Preferences()
        saved.theme = .neon
        saved.grantedConsents = ["readClipboard"]
        let profile = SettingsProfile(name: "x", data: try JSONEncoder().encode(saved))
        var current = Preferences()
        current.grantedConsents = []
        let applied = ProfilesStore.applied(profile, over: current)
        XCTAssertEqual(applied?.theme, .neon)
        XCTAssertEqual(applied?.grantedConsents, [])
    }

    func testChatFramingRoundTrip() {
        let key = LANChatModel.key(for: "secret room")
        let message = LANMessage(handle: "Sam", text: "hello")
        var buffer = (try? LANChatModel.frame(message, key: key)) ?? Data()
        buffer.append(Data([0, 0]))      // a half-arrived next frame header
        let decoded = LANChatModel.unframe(&buffer, key: key)
        XCTAssertEqual(decoded.first?.text, "hello")
        XCTAssertEqual(buffer.count, 2)
        // A different room code cannot read it.
        var again = (try? LANChatModel.frame(message, key: key)) ?? Data()
        XCTAssertTrue(LANChatModel.unframe(&again, key: LANChatModel.key(for: "other")).isEmpty)
        XCTAssertEqual(LANChatModel.tag(for: "A"), LANChatModel.tag(for: "a"))
    }

    func testNotesSyncFormatRoundTrip() {
        var note = StudyNote(title: "Maths: limits?", body: "Line one\nLine two", source: "AI answer")
        note.createdAt = Date(timeIntervalSince1970: 1_700_000_000)
        XCTAssertFalse(NotesSyncFormat.fileName(for: note).contains(":"))
        let back = NotesSyncFormat.parse(NotesSyncFormat.render(note), fallbackTitle: "x")
        XCTAssertEqual(back.id, note.id)
        XCTAssertEqual(back.title, note.title)
        XCTAssertEqual(back.body, note.body)
        XCTAssertEqual(back.source, "AI answer")
        let plain = NotesSyncFormat.parse("Just text", fallbackTitle: "File name")
        XCTAssertEqual(plain.title, "File name")
        XCTAssertEqual(plain.body, "Just text")
    }

    func testAutomationDueRule() {
        let cal = Calendar.current
        let now = cal.date(bySettingHour: 9, minute: 0, second: 0, of: Date())!
        var item = Automation(name: "x", prompt: "p", hour: 8, minute: 30)
        XCTAssertTrue(AutomationsModel.isDue(item, now: now))
        item.lastRun = cal.date(bySettingHour: 8, minute: 31, second: 0, of: now)
        XCTAssertFalse(AutomationsModel.isDue(item, now: now))
        item.lastRun = nil
        item.hour = 10
        XCTAssertFalse(AutomationsModel.isDue(item, now: now))
    }

    func testLiveActivitiesLimitAndSafety() {
        let store = ActivityStore()
        XCTAssertTrue(store.upsert(id: "a", title: "A", progress: 2))
        XCTAssertTrue(store.upsert(id: "b", title: "B"))
        XCTAssertFalse(store.upsert(id: "c", title: "C"))
        XCTAssertTrue(store.upsert(id: "a", title: "A2", progress: 0.5))
        XCTAssertEqual(store.activities.first?.title, "A2")
        XCTAssertEqual(ActivityStore.safeSymbol("../evil"), "bolt.fill")
        store.prune(now: Date().addingTimeInterval(13 * 3600))
        XCTAssertTrue(store.activities.isEmpty)
    }

    func testScreenTimeAndPluginURLs() {
        var data = ScreenTimeData()
        ScreenTimeModel.add(seconds: 120, app: "Safari", day: Date(), to: &data)
        ScreenTimeModel.add(seconds: 60, app: "Safari", day: Date(), to: &data)
        XCTAssertEqual(data.days[ScreenTimeModel.dayKey(Date())]?["Safari"], 180)
        XCTAssertEqual(ScreenTimeModel.text(seconds: 3900), "1h 5m")
        XCTAssertNotNil(Plugin.isSafe(url: "https://example.com"))
        XCTAssertNil(Plugin.isSafe(url: "file:///etc/passwd"))
        XCTAssertNil(Plugin.isSafe(url: "javascript:alert(1)"))
    }

    func testVPNListParsing() {
        let output = """
        Available network connection services in the current set (*=enabled):
        * (Connected)      3F2A9C1E-1111-2222-3333-444455556666 VPN (com.example.vpn) "Work VPN"                  [VPN:com.example.vpn]
        * (Disconnected)   AAAAAAAA-1111-2222-3333-444455556666 VPN (com.apple.vpn) "Home, Wi-Fi"                  [VPN:com.apple.vpn]
        """
        let list = VPNModel.parse(output)
        XCTAssertEqual(list.map { $0.name }, ["Work VPN", "Home, Wi-Fi"])
        XCTAssertTrue(list[0].isConnected)
        XCTAssertFalse(list[1].isConnected)
    }

    func testScoresParsing() {
        XCTAssertNotNil(ScoresParser.date("2026-10-14T19:00Z"))
        XCTAssertEqual(Set(SportsCatalog.leagues.map { $0.id }).count, SportsCatalog.leagues.count)

        let league = SportsCatalog.league("basketball/nba")!
        let board = #"{"events":[{"id":"401","name":"Home at Away","date":"2026-10-14T19:00Z","competitions":[{"id":"401","date":"2026-10-14T19:00Z","venue":{"fullName":"Big Arena","address":{"city":"Boston"}},"broadcasts":[{"names":["ESPN"]}],"status":{"displayClock":"4:12","type":{"state":"in","shortDetail":"4:12 - 3rd"}},"competitors":[{"homeAway":"home","id":"1","score":"88","winner":false,"team":{"id":"1","displayName":"Home Team","abbreviation":"HOM","color":"ff0000"},"records":[{"summary":"3-1"}],"linescores":[{"value":20},{"value":25}]},{"homeAway":"away","id":"2","score":"90","team":{"id":"2","displayName":"Away Team","abbreviation":"AWY"}}]}]}]}"#
        let games = ScoresParser.games(from: Data(board.utf8), league: league)
        XCTAssertEqual(games.count, 1)
        XCTAssertEqual(games[0].first?.abbr, "AWY")          // away first
        XCTAssertEqual(games[0].second?.record, "3-1")
        XCTAssertEqual(games[0].second?.lines, ["20", "25"])
        XCTAssertEqual(games[0].state, .live)
        XCTAssertEqual(games[0].venue, "Big Arena, Boston")
        XCTAssertEqual(games[0].broadcast, "ESPN")
        XCTAssertTrue(games[0].involves(teamID: "2"))

        let summary = #"{"boxscore":{"teams":[{"homeAway":"home","team":{"displayName":"H"},"statistics":[{"name":"fg","label":"FG","displayValue":"40"}]},{"homeAway":"away","team":{"displayName":"A"},"statistics":[{"name":"fg","label":"FG","displayValue":"38"}]}],"players":[{"team":{"displayName":"A"},"statistics":[{"name":"stats","labels":["MIN","PTS"],"athletes":[{"athlete":{"displayName":"Ann"},"stats":["30","22"]}]}]}]},"gameInfo":{"attendance":1234,"venue":{"fullName":"Big Arena"}}}"#
        let detail = ScoresParser.detail(from: Data(summary.utf8))
        XCTAssertEqual(detail.teamStats.first?.first, "38")   // away on the left
        XCTAssertEqual(detail.teamStats.first?.second, "40")
        XCTAssertEqual(detail.tables.first?.rows.first, ["Ann", "30", "22"])
        XCTAssertTrue(detail.info.contains("Attendance: 1234"))

        let table = #"{"children":[{"name":"East","standings":{"entries":[{"team":{"id":"1","displayName":"H","abbreviation":"HOM"},"stats":[{"name":"wins","abbreviation":"W","displayValue":"10","value":10},{"name":"losses","abbreviation":"L","displayValue":"2","value":2},{"name":"rank","value":1}]}]}}]}"#
        let groups = ScoresParser.standings(from: Data(table.utf8))
        XCTAssertEqual(groups.first?.columns, ["W", "L"])
        XCTAssertEqual(groups.first?.rows.first?.values, ["10", "2"])

        let teams = #"{"sports":[{"leagues":[{"teams":[{"team":{"id":"9","displayName":"Zed FC","abbreviation":"ZED"}},{"team":{"id":"3","displayName":"Alpha FC"}}]}]}]}"#
        XCTAssertEqual(ScoresParser.teams(from: Data(teams.utf8)).map { $0.name }, ["Alpha FC", "Zed FC"])
    }
}
