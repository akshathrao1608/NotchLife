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
}
