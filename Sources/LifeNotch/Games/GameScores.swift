import Foundation

// GameScores.swift
// Your best scores, saved only on this Mac (scores.json). The compact bar reads from here.

enum MathsDifficulty: String, CaseIterable, Identifiable, Codable {
    case easy, medium, hard
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct GameScoresData: Codable, Equatable {
    var reactionBestMs: Int?
    var memoryBestMoves: Int?
    var memoryBestSeconds: Int?
    var mathsBest: [String: Int] = [:]      // keyed by difficulty
    var penaltyBestGoals: Int?
    var f1BestMs: Int?
    var wordRushBest: Int?
    var best2048: Int?
    var bestSnake: Int?
}

final class GameScores: ObservableObject {
    @Published private(set) var data: GameScoresData
    private static let fileName = "scores.json"

    init() {
        data = LocalStore.load(GameScoresData.self, name: Self.fileName) ?? GameScoresData()
    }

    private func save() { LocalStore.save(data, name: Self.fileName) }

    func reloadFromDisk() {
        data = LocalStore.load(GameScoresData.self, name: Self.fileName) ?? GameScoresData()
    }

    // Each submit returns true when it is a NEW personal best.

    @discardableResult
    func submitReaction(ms: Int) -> Bool {
        guard data.reactionBestMs == nil || ms < data.reactionBestMs! else { return false }
        data.reactionBestMs = ms
        save()
        return true
    }

    @discardableResult
    func submitF1(ms: Int) -> Bool {
        guard data.f1BestMs == nil || ms < data.f1BestMs! else { return false }
        data.f1BestMs = ms
        save()
        return true
    }

    @discardableResult
    func submitMemory(moves: Int, seconds: Int) -> Bool {
        var isBest = false
        if data.memoryBestMoves == nil || moves < data.memoryBestMoves! {
            data.memoryBestMoves = moves
            isBest = true
        }
        if data.memoryBestSeconds == nil || seconds < data.memoryBestSeconds! {
            data.memoryBestSeconds = seconds
            isBest = true
        }
        if isBest { save() }
        return isBest
    }

    @discardableResult
    func submitMaths(score: Int, difficulty: MathsDifficulty) -> Bool {
        guard score > (data.mathsBest[difficulty.rawValue] ?? 0) else { return false }
        data.mathsBest[difficulty.rawValue] = score
        save()
        return true
    }

    @discardableResult
    func submitPenalty(goals: Int) -> Bool {
        guard goals > (data.penaltyBestGoals ?? 0) else { return false }
        data.penaltyBestGoals = goals
        save()
        return true
    }

    @discardableResult
    func submitWordRush(score: Int) -> Bool {
        guard score > (data.wordRushBest ?? 0) else { return false }
        data.wordRushBest = score
        save()
        return true
    }

    @discardableResult
    func submit2048(score: Int) -> Bool {
        guard score > (data.best2048 ?? 0) else { return false }
        data.best2048 = score
        save()
        return true
    }

    @discardableResult
    func submitSnake(score: Int) -> Bool {
        guard score > (data.bestSnake ?? 0) else { return false }
        data.bestSnake = score
        save()
        return true
    }

    /// Short text for the compact bar and the game cards. nil = no score yet.
    func bestText(for game: GameKind) -> String? {
        switch game {
        case .reaction: return data.reactionBestMs.map { "\($0) ms" }
        case .f1Lights: return data.f1BestMs.map { "\($0) ms" }
        case .memory: return data.memoryBestMoves.map { "\($0) moves" }
        case .penalty: return data.penaltyBestGoals.map { "\($0)/5" }
        case .wordRush: return data.wordRushBest.map { "\($0) pts" }
        case .game2048: return data.best2048.map { "\($0) pts" }
        case .snake: return data.bestSnake.map { "\($0) apples" }
        case .maths:
            guard let best = data.mathsBest.values.max() else { return nil }
            return "\(best) right"
        }
    }
}
