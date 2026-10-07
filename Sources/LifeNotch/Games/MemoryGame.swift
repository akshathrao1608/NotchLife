import SwiftUI

// MemoryGame.swift
// Game 2: Memory Match. Flip two cards; matching pairs stay open. Fewer moves = better.
// Keyboard: arrow keys move, Space/Return flips, R restarts.

struct MemoryGame: View {
    @EnvironmentObject private var scores: GameScores

    private struct Card: Identifiable {
        let id: Int
        let symbol: String
        var isFaceUp = false
        var isMatched = false
    }

    // Sports, school and tech icons.
    private static let symbols = [
        "soccerball", "basketball.fill", "tennisball.fill", "trophy.fill", "flag.checkered", "figure.run",
        "pencil", "book.fill", "graduationcap.fill", "ruler.fill", "backpack.fill", "globe.europe.africa.fill",
        "laptopcomputer", "cpu", "keyboard", "wifi", "antenna.radiowaves.left.and.right", "gamecontroller.fill"
    ]

    @State private var cards: [Card] = []
    @State private var cursor = 0
    @State private var moves = 0
    @State private var startTime: Date?
    @State private var finishedSeconds: Int?
    @State private var isBest = false
    @State private var lockInput = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                HStack {
                    Text("Moves: \(moves)").lnFont(12, .semibold)
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        Text("Time: \(elapsedText)").lnFont(12, .semibold).monospacedDigit()
                    }
                    Spacer()
                    newBestBanner(isBest)
                    Text("Best: \(scores.data.memoryBestMoves.map { "\($0) moves" } ?? "none yet")").lnFont(11).foregroundStyle(.secondary)
                    Button("New game") { newGame() }.buttonStyle(LNButtonStyle())
                }
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(cards.enumerated()), id: \.element.id) { index, card in
                        cardView(card, isCursor: index == cursor)
                            .onTapGesture { cursor = index; flip(index) }
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .onAppear { if cards.isEmpty { newGame() } }
    }

    private var elapsedText: String {
        if let done = finishedSeconds { return Countdown.clock(TimeInterval(done)) }
        guard let start = startTime else { return "00:00" }
        return Countdown.clock(Date().timeIntervalSince(start))
    }

    private func cardView(_ card: Card, isCursor: Bool) -> some View {
        let open = card.isFaceUp || card.isMatched
        return ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(open ? (card.isMatched ? Color.green.opacity(0.35) : Color.blue.opacity(0.35)) : Color.primary.opacity(0.14))
            if open {
                Image(systemName: card.symbol).font(.system(size: 26, weight: .semibold))
            } else {
                Image(systemName: "questionmark").font(.system(size: 18, weight: .bold)).foregroundStyle(.secondary)
            }
        }
        .frame(height: 62)
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(Color.accentColor, lineWidth: isCursor ? 2.5 : 0))
        .accessibilityLabel(open ? card.symbol.replacingOccurrences(of: ".", with: " ") : "Hidden card")
        .accessibilityAddTraits(.isButton)
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !cards.isEmpty else { return .ignored }
        switch press.key {
        case .leftArrow: cursor = (cursor + cards.count - 1) % cards.count
        case .rightArrow: cursor = (cursor + 1) % cards.count
        case .upArrow: cursor = (cursor + cards.count - 4) % cards.count
        case .downArrow: cursor = (cursor + 4) % cards.count
        case .space, .return: flip(cursor)
        default:
            if press.characters.lowercased() == "r" { newGame(); return .handled }
            return .ignored
        }
        return .handled
    }

    private func newGame() {
        let chosen = Array(Self.symbols.shuffled().prefix(8))
        cards = (chosen + chosen).shuffled().enumerated().map { Card(id: $0.offset, symbol: $0.element) }
        cursor = 0
        moves = 0
        startTime = nil
        finishedSeconds = nil
        isBest = false
        lockInput = false
    }

    private func flip(_ index: Int) {
        guard !lockInput, cards.indices.contains(index), !cards[index].isFaceUp, !cards[index].isMatched else { return }
        if startTime == nil { startTime = Date() }
        cards[index].isFaceUp = true
        SoundPlayer.play(.tap)

        let open = cards.indices.filter { cards[$0].isFaceUp && !cards[$0].isMatched }
        guard open.count == 2 else { return }
        moves += 1
        let first = open[0], second = open[1]
        if cards[first].symbol == cards[second].symbol {
            cards[first].isMatched = true
            cards[second].isMatched = true
            SoundPlayer.play(.success)
            if cards.allSatisfy({ $0.isMatched }) { finish() }
        } else {
            lockInput = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 700_000_000)
                if cards.indices.contains(first) { cards[first].isFaceUp = false }
                if cards.indices.contains(second) { cards[second].isFaceUp = false }
                lockInput = false
            }
        }
    }

    private func finish() {
        let seconds = Int(Date().timeIntervalSince(startTime ?? Date()))
        finishedSeconds = seconds
        isBest = scores.submitMemory(moves: moves, seconds: seconds)
        SoundPlayer.play(.win)
    }
}
