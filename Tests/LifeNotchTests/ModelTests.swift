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

    func testTabNumbersAreOneToEight() {
        XCTAssertEqual(NotchTab.allCases.map { $0.number }, Array(1...8))
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
