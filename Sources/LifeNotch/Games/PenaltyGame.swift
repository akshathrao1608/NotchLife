import SwiftUI

// PenaltyGame.swift
// Game 4: Football Penalty Shootout. Best of five. Pick left, centre or right.
// Keyboard: ← ↓ → (or A S D). The keeper dives to a random side.

struct PenaltyGame: View {
    @EnvironmentObject private var scores: GameScores

    @State private var shotsTaken = 0
    @State private var goals = 0
    @State private var results: [PenaltyOutcome] = []
    @State private var ballX: CGFloat = 0
    @State private var ballY: CGFloat = 78
    @State private var keeperX: CGFloat = 0
    @State private var keeperTilt: Double = 0
    @State private var message = "Pick where to shoot!"
    @State private var busy = false
    @State private var isBest = false

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                HStack {
                    Text("Goals: \(goals)").lnFont(13, .bold)
                    HStack(spacing: 5) {
                        ForEach(0..<5, id: \.self) { index in
                            Circle().fill(color(for: index)).frame(width: 12, height: 12)
                        }
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(shotsTaken) of 5 shots taken, \(goals) goals")
                    Spacer()
                    newBestBanner(isBest)
                    Text("Best: \(scores.data.penaltyBestGoals.map { "\($0)/5" } ?? "none yet")").lnFont(11).foregroundStyle(.secondary)
                }
                pitch.frame(maxHeight: .infinity)
                Text(message).lnFont(14, .bold, design: .rounded)
                if shotsTaken >= 5 {
                    Button("Play again") { reset() }.buttonStyle(LNButtonStyle(prominent: true))
                } else {
                    HStack(spacing: 10) {
                        ForEach(PenaltyDirection.allCases, id: \.rawValue) { direction in
                            Button { shoot(direction) } label: {
                                Label(direction.title, systemImage: icon(for: direction))
                            }
                            .buttonStyle(LNButtonStyle(prominent: true))
                            .disabled(busy)
                        }
                    }
                    Text("← ↓ → or A S D").lnFont(10).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var pitch: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(LinearGradient(colors: [Color(red: 0.05, green: 0.3, blue: 0.12), Color(red: 0.08, green: 0.4, blue: 0.16)],
                                     startPoint: .top, endPoint: .bottom))
            // The goal.
            ZStack {
                Rectangle().fill(Color.white.opacity(0.08))
                Rectangle().stroke(Color.white, lineWidth: 4)
                ForEach(0..<7, id: \.self) { i in
                    Rectangle().fill(Color.white.opacity(0.15)).frame(width: 1).offset(x: CGFloat(i - 3) * 30)
                }
            }
            .frame(width: 240, height: 90)
            .offset(y: -50)
            // The keeper.
            Image(systemName: "figure.arms.open")
                .font(.system(size: 46))
                .foregroundStyle(.yellow)
                .rotationEffect(.degrees(keeperTilt))
                .offset(x: keeperX, y: -42)
                .accessibilityHidden(true)
            // The ball.
            Image(systemName: "soccerball")
                .font(.system(size: 26))
                .foregroundStyle(.white)
                .offset(x: ballX, y: ballY)
                .accessibilityHidden(true)
        }
        .clipped()
    }

    private func icon(for direction: PenaltyDirection) -> String {
        switch direction {
        case .left: return "arrow.left"
        case .centre: return "arrow.up"
        case .right: return "arrow.right"
        }
    }

    private func color(for index: Int) -> Color {
        guard index < results.count else { return Color.primary.opacity(0.2) }
        switch results[index] {
        case .goal: return .green
        case .saved: return .red
        case .missed: return .orange
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        guard !busy, shotsTaken < 5 else {
            if shotsTaken >= 5, press.key == .return || press.key == .space { reset(); return .handled }
            return .ignored
        }
        switch press.key {
        case .leftArrow: shoot(.left)
        case .downArrow, .upArrow: shoot(.centre)
        case .rightArrow: shoot(.right)
        default:
            switch press.characters.lowercased() {
            case "a": shoot(.left)
            case "s": shoot(.centre)
            case "d": shoot(.right)
            default: return .ignored
            }
        }
        return .handled
    }

    private func shoot(_ direction: PenaltyDirection) {
        guard !busy, shotsTaken < 5 else { return }
        busy = true
        let keeperDirection = PenaltyDirection.allCases.randomElement() ?? .centre
        let wide = Int.random(in: 0..<10) == 0
        let outcome = Penalty.outcome(shot: direction, keeper: keeperDirection, wide: wide)
        SoundPlayer.play(.tap)

        withAnimation(.easeOut(duration: 0.45)) {
            ballX = direction.xOffset * (wide ? 1.5 : 1)
            ballY = wide ? -125 : -48
            keeperX = keeperDirection.xOffset
            keeperTilt = keeperDirection == .left ? -55 : (keeperDirection == .right ? 55 : 0)
        }

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 500_000_000)
            results.append(outcome)
            shotsTaken += 1
            switch outcome {
            case .goal:
                goals += 1
                message = "GOAL! ⚽️"
                SoundPlayer.play(.success)
            case .saved:
                message = "Saved by the keeper!"
                SoundPlayer.play(.fail)
            case .missed:
                message = "Wide! Off target."
                SoundPlayer.play(.fail)
            }
            if shotsTaken >= 5 {
                isBest = scores.submitPenalty(goals: goals)
                message += "  Final: \(goals)/5"
                SoundPlayer.play(goals >= 3 ? .win : .lose)
            }
            try? await Task.sleep(nanoseconds: 700_000_000)
            withAnimation(.easeInOut(duration: 0.3)) {
                ballX = 0; ballY = 78; keeperX = 0; keeperTilt = 0
            }
            if shotsTaken < 5 { message = "Pick where to shoot!" }
            busy = false
        }
    }

    private func reset() {
        shotsTaken = 0
        goals = 0
        results = []
        isBest = false
        message = "Pick where to shoot!"
    }
}
