import SwiftUI

// Game2048.swift
// 2048: slide the tiles with the arrow keys; equal tiles merge. Reach 2048!
// The rules live in `Board2048` (pure logic, easy to test). The screen is `Game2048View`.

struct Board2048: Equatable {
    enum Direction { case left, right, up, down }

    var cells: [[Int]] = Array(repeating: Array(repeating: 0, count: 4), count: 4)
    var score = 0

    /// Slides one line toward index 0 and merges equal neighbours once. Returns the new line and points gained.
    static func slide(_ line: [Int]) -> (line: [Int], gained: Int) {
        let tiles = line.filter { $0 != 0 }
        var result: [Int] = []
        var gained = 0
        var index = 0
        while index < tiles.count {
            if index + 1 < tiles.count && tiles[index] == tiles[index + 1] {
                let merged = tiles[index] * 2
                result.append(merged)
                gained += merged
                index += 2
            } else {
                result.append(tiles[index])
                index += 1
            }
        }
        while result.count < line.count { result.append(0) }
        return (result, gained)
    }

    private static func coordinate(line i: Int, position j: Int, _ d: Direction) -> (row: Int, col: Int) {
        switch d {
        case .left: return (i, j)
        case .right: return (i, 3 - j)
        case .up: return (j, i)
        case .down: return (3 - j, i)
        }
    }

    /// Moves every line. Returns true if anything changed.
    @discardableResult
    mutating func move(_ d: Direction) -> Bool {
        var changed = false
        for i in 0..<4 {
            let coords = (0..<4).map { Self.coordinate(line: i, position: $0, d) }
            let line = coords.map { cells[$0.row][$0.col] }
            let outcome = Self.slide(line)
            if outcome.line != line { changed = true }
            score += outcome.gained
            for (k, c) in coords.enumerated() { cells[c.row][c.col] = outcome.line[k] }
        }
        return changed
    }

    mutating func addRandomTile<G: RandomNumberGenerator>(using generator: inout G) {
        var empty: [(Int, Int)] = []
        for r in 0..<4 { for c in 0..<4 where cells[r][c] == 0 { empty.append((r, c)) } }
        guard let spot = empty.randomElement(using: &generator) else { return }
        cells[spot.0][spot.1] = Int.random(in: 0..<10, using: &generator) == 0 ? 4 : 2
    }

    var maxTile: Int { cells.flatMap { $0 }.max() ?? 0 }

    var hasMoves: Bool {
        for r in 0..<4 {
            for c in 0..<4 {
                if cells[r][c] == 0 { return true }
                if c < 3 && cells[r][c] == cells[r][c + 1] { return true }
                if r < 3 && cells[r][c] == cells[r + 1][c] { return true }
            }
        }
        return false
    }

    static func newGame() -> Board2048 {
        var board = Board2048()
        var generator = SystemRandomNumberGenerator()
        board.addRandomTile(using: &generator)
        board.addRandomTile(using: &generator)
        return board
    }
}

struct Game2048View: View {
    @EnvironmentObject private var scores: GameScores
    @State private var board = Board2048.newGame()
    @State private var reached2048 = false

    private var gameOver: Bool { !board.hasMoves }

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                HStack {
                    Text("Score: \(board.score)").lnFont(13, .bold)
                    Text("Best: \(scores.data.best2048.map(String.init) ?? "–")").lnFont(11).foregroundStyle(.secondary)
                    Spacer()
                    if gameOver { Text("Game over").lnFont(12, .bold).foregroundStyle(.red) }
                    else if board.maxTile >= 2048 { Text("You made 2048! 🎉").lnFont(12, .bold).foregroundStyle(.green) }
                    Button("New game") { restart() }.buttonStyle(LNButtonStyle())
                }
                grid.frame(maxHeight: .infinity)
                Text("Arrow keys (or W A S D) to slide").lnFont(10).foregroundStyle(.secondary)
            }
        }
        .onDisappear { scores.submit2048(score: board.score) }
    }

    private var grid: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let gap: CGFloat = 6
            let tile = (side - gap * 5) / 4
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.1))
                VStack(spacing: gap) {
                    ForEach(0..<4, id: \.self) { r in
                        HStack(spacing: gap) {
                            ForEach(0..<4, id: \.self) { c in
                                let value = board.cells[r][c]
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8, style: .continuous).fill(color(for: value))
                                    if value > 0 {
                                        Text("\(value)")
                                            .font(.system(size: tile * (value >= 1024 ? 0.3 : 0.4), weight: .bold, design: .rounded))
                                            .foregroundStyle(value <= 4 ? Color.primary : Color.white)
                                    }
                                }
                                .frame(width: tile, height: tile)
                                .accessibilityLabel(value == 0 ? "Empty" : "Tile \(value)")
                            }
                        }
                    }
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func color(for value: Int) -> Color {
        switch value {
        case 0: return Color.primary.opacity(0.06)
        case 2: return Color.primary.opacity(0.18)
        case 4: return Color.primary.opacity(0.28)
        case 8: return Color.orange.opacity(0.85)
        case 16: return Color.orange
        case 32: return Color.red.opacity(0.8)
        case 64: return Color.red
        case 128: return Color.yellow.opacity(0.85)
        case 256: return Color.yellow
        case 512: return Color.green.opacity(0.85)
        case 1024: return Color.teal
        default: return Color.purple
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .leftArrow: apply(.left)
        case .rightArrow: apply(.right)
        case .upArrow: apply(.up)
        case .downArrow: apply(.down)
        default:
            switch press.characters.lowercased() {
            case "a": apply(.left)
            case "d": apply(.right)
            case "w": apply(.up)
            case "s": apply(.down)
            default: return .ignored
            }
        }
        return .handled
    }

    private func apply(_ direction: Board2048.Direction) {
        guard !gameOver else { return }
        var next = board
        if next.move(direction) {
            var generator = SystemRandomNumberGenerator()
            next.addRandomTile(using: &generator)
            board = next
            SoundPlayer.play(.tap)
            if board.maxTile >= 2048 && !reached2048 { reached2048 = true; SoundPlayer.play(.win) }
            if gameOver { scores.submit2048(score: board.score); SoundPlayer.play(.lose) }
        }
    }

    private func restart() {
        scores.submit2048(score: board.score)
        board = Board2048.newGame()
        reached2048 = false
    }
}
