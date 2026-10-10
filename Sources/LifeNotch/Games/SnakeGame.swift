import SwiftUI

// SnakeGame.swift
// Snake: steer with the arrow keys, eat the food, don't hit the walls or yourself.
// The rules are in `SnakeState` (pure logic). The screen is `SnakeGameView`.

struct GridPoint: Equatable {
    var x: Int
    var y: Int
    static func + (a: GridPoint, b: GridPoint) -> GridPoint { GridPoint(x: a.x + b.x, y: a.y + b.y) }
    var opposite: GridPoint { GridPoint(x: -x, y: -y) }
}

struct SnakeState: Equatable {
    static let columns = 20
    static let rows = 12

    var body: [GridPoint] = [GridPoint(x: 5, y: 6), GridPoint(x: 4, y: 6), GridPoint(x: 3, y: 6)]   // head first
    var direction = GridPoint(x: 1, y: 0)
    var queued = GridPoint(x: 1, y: 0)
    var food = GridPoint(x: 14, y: 6)
    var alive = true
    var score = 0

    /// Asks to turn. A direct U-turn is ignored (the snake would hit its own neck).
    mutating func turn(to newDirection: GridPoint) {
        if newDirection != direction.opposite { queued = newDirection }
    }

    mutating func step<G: RandomNumberGenerator>(using generator: inout G) {
        guard alive else { return }
        direction = queued
        let newHead = body[0] + direction
        let inside = newHead.x >= 0 && newHead.x < Self.columns && newHead.y >= 0 && newHead.y < Self.rows
        let willEat = newHead == food
        // The tail moves away this step unless we eat, so it is not a collision.
        let obstacle = willEat ? body : Array(body.dropLast())
        if !inside || obstacle.contains(newHead) {
            alive = false
            return
        }
        body.insert(newHead, at: 0)
        if willEat {
            score += 1
            placeFood(using: &generator)
        } else {
            body.removeLast()
        }
    }

    mutating func placeFood<G: RandomNumberGenerator>(using generator: inout G) {
        var free: [GridPoint] = []
        for x in 0..<Self.columns {
            for y in 0..<Self.rows {
                let p = GridPoint(x: x, y: y)
                if !body.contains(p) { free.append(p) }
            }
        }
        if let spot = free.randomElement(using: &generator) { food = spot } else { alive = false }   // board full: you win
    }
}

struct SnakeGameView: View {
    @EnvironmentObject private var scores: GameScores
    @State private var state = SnakeState()
    @State private var running = false
    @State private var savedScore = false

    private let ticker = Timer.publish(every: 0.12, on: .main, in: .common).autoconnect()

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                HStack {
                    Text("Score: \(state.score)").lnFont(13, .bold)
                    Text("Best: \(scores.data.bestSnake.map(String.init) ?? "–")").lnFont(11).foregroundStyle(.secondary)
                    Spacer()
                    if !state.alive { Text("Game over").lnFont(12, .bold).foregroundStyle(.red) }
                    Button(running ? "Pause" : (state.alive ? "Start" : "Play again")) { startOrPause() }
                        .buttonStyle(LNButtonStyle(prominent: true))
                }
                board.frame(maxHeight: .infinity)
                Text("Arrow keys or W A S D · Space to start or pause").lnFont(10).foregroundStyle(.secondary)
            }
        }
        .onReceive(ticker) { _ in tick() }
        .onDisappear { running = false; saveIfNeeded() }
    }

    private var board: some View {
        GeometryReader { proxy in
            let cell = min(proxy.size.width / CGFloat(SnakeState.columns), proxy.size.height / CGFloat(SnakeState.rows))
            let width = cell * CGFloat(SnakeState.columns)
            let height = cell * CGFloat(SnakeState.rows)
            Canvas { context, _ in
                for p in state.body.indices {
                    let part = state.body[p]
                    let rect = CGRect(x: CGFloat(part.x) * cell + 1, y: CGFloat(part.y) * cell + 1, width: cell - 2, height: cell - 2)
                    context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(p == 0 ? .green : .green.opacity(0.7)))
                }
                let f = state.food
                let foodRect = CGRect(x: CGFloat(f.x) * cell + 2, y: CGFloat(f.y) * cell + 2, width: cell - 4, height: cell - 4)
                context.fill(Path(ellipseIn: foodRect), with: .color(.red))
            }
            .frame(width: width, height: height)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.08)))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Snake board. Score \(state.score)")
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .upArrow: state.turn(to: GridPoint(x: 0, y: -1))
        case .downArrow: state.turn(to: GridPoint(x: 0, y: 1))
        case .leftArrow: state.turn(to: GridPoint(x: -1, y: 0))
        case .rightArrow: state.turn(to: GridPoint(x: 1, y: 0))
        case .space: startOrPause()
        default:
            switch press.characters.lowercased() {
            case "w": state.turn(to: GridPoint(x: 0, y: -1))
            case "s": state.turn(to: GridPoint(x: 0, y: 1))
            case "a": state.turn(to: GridPoint(x: -1, y: 0))
            case "d": state.turn(to: GridPoint(x: 1, y: 0))
            default: return .ignored
            }
        }
        return .handled
    }

    private func startOrPause() {
        if !state.alive {
            state = SnakeState()
            savedScore = false
            running = true
        } else {
            running.toggle()
        }
    }

    private func tick() {
        guard running, state.alive else { return }
        var generator = SystemRandomNumberGenerator()
        let before = state.score
        state.step(using: &generator)
        if state.score > before { SoundPlayer.play(.tap) }
        if !state.alive {
            running = false
            SoundPlayer.play(.lose)
            saveIfNeeded()
        }
    }

    private func saveIfNeeded() {
        guard !savedScore else { return }
        savedScore = true
        scores.submitSnake(score: state.score)
    }
}
