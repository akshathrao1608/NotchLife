import Foundation

// FunContent.swift
// Built-in quotes, facts, quiz questions and coding challenges.
// These are written into the app (NOT fetched from the internet), so they are never "live".
// Add your own lines to any list.

struct FunQuote: Equatable {
    let text: String
    let author: String?
}

struct QuizQuestion: Equatable {
    let question: String
    let answer: String
}

enum RandomFunKind: Equatable {
    case quiz(QuizQuestion)
    case f1Fact(String)
    case footballFact(String)
    case codingChallenge(String)
    case miniGame(GameKind)

    var title: String {
        switch self {
        case .quiz: return "Quiz question"
        case .f1Fact: return "F1 fact"
        case .footballFact: return "Football fact"
        case .codingChallenge: return "Coding challenge"
        case .miniGame: return "Mini-game"
        }
    }
}

enum FunContent {
    static let quotes: [FunQuote] = [
        FunQuote(text: "Small steps every day beat big plans someday.", author: nil),
        FunQuote(text: "Mistakes are proof that you are trying.", author: nil),
        FunQuote(text: "A journey of a thousand miles begins with a single step.", author: "Lao Tzu"),
        FunQuote(text: "The only way to do great work is to love what you do.", author: "Steve Jobs"),
        FunQuote(text: "You don't have to be perfect to be good. You just have to start.", author: nil),
        FunQuote(text: "Focus on one thing for 25 minutes. That is how big things get done.", author: nil),
        FunQuote(text: "Hard things get easier when you do them regularly.", author: nil),
        FunQuote(text: "Ask questions. Curiosity is a study superpower.", author: nil),
        FunQuote(text: "Rest is part of the work. Take your breaks.", author: nil),
        FunQuote(text: "Progress, not perfection.", author: nil),
        FunQuote(text: "Future you will be glad you started today.", author: nil),
        FunQuote(text: "If it feels difficult, your brain is growing.", author: nil)
    ]

    static let f1Facts: [String] = [
        "The first Formula 1 World Championship season was in 1950. Its first race was the British Grand Prix at Silverstone.",
        "Michael Schumacher and Lewis Hamilton each won seven World Drivers' Championships (as of the end of 2024).",
        "The Monaco Grand Prix was first held in 1929.",
        "DRS (Drag Reduction System) lets a driver open a flap on the rear wing on certain straights to cut drag and help overtaking.",
        "A four-tyre F1 pit stop usually takes only about two to three seconds.",
        "Pole position is the first place on the starting grid. It goes to the driver with the fastest qualifying lap.",
        "The chequered flag is waved to show that a race is finished.",
        "Soft tyres are marked with a red sidewall, medium with yellow and hard with white."
    ]

    static let footballFacts: [String] = [
        "The first FIFA World Cup was held in Uruguay in 1930, and Uruguay won it.",
        "A football match has two halves of 45 minutes, plus added time.",
        "The Premier League began in the 1992–93 season.",
        "Pelé won three World Cups with Brazil: in 1958, 1962 and 1970.",
        "In international matches a pitch is 100–110 m long and 64–75 m wide.",
        "A goalkeeper may only use their hands inside their own penalty area.",
        "The penalty spot is 11 metres (12 yards) from the goal line.",
        "A player is offside if they are nearer to the opponents' goal line than both the ball and the second-last opponent when the ball is played to them."
    ]

    static let quiz: [QuizQuestion] = [
        QuizQuestion(question: "What is 7 × 8?", answer: "56"),
        QuizQuestion(question: "Which planet is known as the Red Planet?", answer: "Mars"),
        QuizQuestion(question: "Which gas do plants take in from the air for photosynthesis?", answer: "Carbon dioxide"),
        QuizQuestion(question: "What is the largest ocean on Earth?", answer: "The Pacific Ocean"),
        QuizQuestion(question: "What is the chemical formula for water?", answer: "H₂O"),
        QuizQuestion(question: "How many sides does a hexagon have?", answer: "6"),
        QuizQuestion(question: "Who wrote the play 'Romeo and Juliet'?", answer: "William Shakespeare"),
        QuizQuestion(question: "What is the capital city of Japan?", answer: "Tokyo"),
        QuizQuestion(question: "What is the square root of 144?", answer: "12"),
        QuizQuestion(question: "What do we call a word with the opposite meaning of another word?", answer: "An antonym"),
        QuizQuestion(question: "In computing, what does CPU stand for?", answer: "Central Processing Unit"),
        QuizQuestion(question: "How many minutes are there in 3 hours?", answer: "180"),
        QuizQuestion(question: "Which force pulls objects towards the Earth?", answer: "Gravity")
    ]

    static let codingChallenges: [String] = [
        "FizzBuzz: print the numbers 1 to 30. For multiples of 3 print Fizz, for multiples of 5 print Buzz, for both print FizzBuzz.",
        "Write a function that reverses a string without using a built-in reverse.",
        "Count how many vowels are in a sentence.",
        "Check whether a word is a palindrome (like \"level\").",
        "Find the largest number in a list without using max().",
        "Convert Celsius to Fahrenheit (F = C × 9/5 + 32) for 0 to 100 in steps of 10.",
        "Print the multiplication table for any number up to 12.",
        "Add up the digits of a number, for example 1234 gives 10."
    ]

    // MARK: Picking

    /// The same quote all day, a different one tomorrow.
    static func quoteOfTheDay(_ date: Date = Date()) -> FunQuote {
        quotes[dayIndex(date) % quotes.count]
    }

    static func f1FactOfTheDay(_ date: Date = Date()) -> String {
        f1Facts[(dayIndex(date) + 3) % f1Facts.count]
    }

    static func footballFactOfTheDay(_ date: Date = Date()) -> String {
        footballFacts[(dayIndex(date) + 5) % footballFacts.count]
    }

    private static func dayIndex(_ date: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .era, for: date) ?? 0
    }

    static func randomFun() -> RandomFunKind {
        switch Int.random(in: 0..<5) {
        case 0: return .quiz(quiz.randomElement() ?? quiz[0])
        case 1: return .f1Fact(f1Facts.randomElement() ?? f1Facts[0])
        case 2: return .footballFact(footballFacts.randomElement() ?? footballFacts[0])
        case 3: return .codingChallenge(codingChallenges.randomElement() ?? codingChallenges[0])
        default: return .miniGame(GameKind.allCases.randomElement() ?? .reaction)
        }
    }
}
