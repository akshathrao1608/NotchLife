import Foundation

// GameLogic.swift
// The "rules" of the games, kept separate from the screens so they are easy to test.

// MARK: - Quick Maths

struct MathQuestion: Equatable {
    let text: String
    let answer: Int

    /// Makes a random question for a difficulty. `random` can be replaced in tests.
    static func make<G: RandomNumberGenerator>(_ difficulty: MathsDifficulty, using random: inout G) -> MathQuestion {
        switch difficulty {
        case .easy:
            let a = Int.random(in: 1...20, using: &random)
            let b = Int.random(in: 1...20, using: &random)
            if Bool.random(using: &random) {
                return MathQuestion(text: "\(a) + \(b)", answer: a + b)
            }
            let big = max(a, b), small = min(a, b)
            return MathQuestion(text: "\(big) − \(small)", answer: big - small)

        case .medium:
            switch Int.random(in: 0...2, using: &random) {
            case 0:
                let a = Int.random(in: 10...99, using: &random)
                let b = Int.random(in: 10...99, using: &random)
                return MathQuestion(text: "\(a) + \(b)", answer: a + b)
            case 1:
                let a = Int.random(in: 30...99, using: &random)
                let b = Int.random(in: 10...a, using: &random)
                return MathQuestion(text: "\(a) − \(b)", answer: a - b)
            default:
                let a = Int.random(in: 2...12, using: &random)
                let b = Int.random(in: 2...12, using: &random)
                return MathQuestion(text: "\(a) × \(b)", answer: a * b)
            }

        case .hard:
            switch Int.random(in: 0...2, using: &random) {
            case 0:
                let a = Int.random(in: 11...25, using: &random)
                let b = Int.random(in: 6...15, using: &random)
                return MathQuestion(text: "\(a) × \(b)", answer: a * b)
            case 1:
                let b = Int.random(in: 3...15, using: &random)
                let answer = Int.random(in: 3...25, using: &random)
                return MathQuestion(text: "\(b * answer) ÷ \(b)", answer: answer)
            default:
                let a = Int.random(in: 3...12, using: &random)
                let b = Int.random(in: 3...12, using: &random)
                let c = Int.random(in: 5...60, using: &random)
                return MathQuestion(text: "\(a) × \(b) + \(c)", answer: a * b + c)
            }
        }
    }

    static func make(_ difficulty: MathsDifficulty) -> MathQuestion {
        var generator = SystemRandomNumberGenerator()
        return make(difficulty, using: &generator)
    }
}

// MARK: - Word Rush

enum WordRush {
    /// True if `word` can be spelled using the given letters (each letter used at most as often as it appears).
    static func canMake(_ word: String, from letters: [Character]) -> Bool {
        var pool = letters
        for ch in word {
            guard let index = pool.firstIndex(of: ch) else { return false }
            pool.remove(at: index)
        }
        return true
    }

    static func points(for word: String) -> Int {
        switch word.count {
        case ..<3: return 0
        case 3: return 1
        case 4: return 2
        case 5: return 4
        default: return 7
        }
    }

    /// Every dictionary word (3+ letters) that can be made from the letters.
    static func possibleWords(from letters: [Character], dictionary: Set<String> = WordList.words) -> [String] {
        dictionary.filter { $0.count >= 3 && canMake($0, from: letters) }.sorted()
    }

    /// Picks a six-letter seed word with plenty of smaller words hidden in it, then shuffles it.
    static func newRound(dictionary: Set<String> = WordList.words, seeds: [String] = WordList.seeds) -> [Character] {
        let usable = seeds.shuffled().first { seed in
            possibleWords(from: Array(seed), dictionary: dictionary).count >= 12
        } ?? seeds.randomElement() ?? "planet"
        var letters = Array(usable)
        repeat { letters.shuffle() } while String(letters) == usable && letters.count > 1
        return letters
    }
}

// MARK: - Penalty shootout

enum PenaltyDirection: Int, CaseIterable {
    case left = 0, centre, right

    var title: String {
        switch self {
        case .left: return "Left"
        case .centre: return "Centre"
        case .right: return "Right"
        }
    }

    /// Horizontal position of the ball/keeper in the goal drawing.
    var xOffset: CGFloat {
        switch self {
        case .left: return -92
        case .centre: return 0
        case .right: return 92
        }
    }
}

enum PenaltyOutcome { case goal, saved, missed }

enum Penalty {
    /// You score unless the keeper guesses your side (or you blast it wide, about 1 time in 10).
    static func outcome(shot: PenaltyDirection, keeper: PenaltyDirection, wide: Bool) -> PenaltyOutcome {
        if wide { return .missed }
        return shot == keeper ? .saved : .goal
    }
}
