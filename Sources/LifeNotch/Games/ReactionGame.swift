import SwiftUI

// ReactionGame.swift
// Game 1: Reaction Time Test. Wait for the colour to turn green, then click or press Space.

struct ReactionGame: View {
    @EnvironmentObject private var scores: GameScores

    private enum Phase { case idle, waiting, go, early, result }

    @State private var phase: Phase = .idle
    @State private var goTime = Date()
    @State private var resultMs = 0
    @State private var isBest = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 8) {
                Button(action: tap) { panel }
                    .buttonStyle(.plain)
                    .frame(maxHeight: .infinity)
                    .accessibilityLabel("Reaction test area")
                    .accessibilityHint("Press to start, then press again when the colour turns green")
                HStack {
                    Text("Best: \(scores.data.reactionBestMs.map { "\($0) ms" } ?? "none yet")").lnFont(12, .medium)
                    Spacer()
                    newBestBanner(isBest && phase == .result)
                    Text("Space or click").lnFont(10.5).foregroundStyle(.secondary)
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    @ViewBuilder
    private var panel: some View {
        switch phase {
        case .idle: BigPanel(color: .blue, title: "Reaction Test", subtitle: "Click or press Space to start")
        case .waiting: BigPanel(color: .red, title: "Wait for green…", subtitle: "Don't click yet!")
        case .go: BigPanel(color: .green, title: "NOW!", subtitle: "Click!")
        case .early: BigPanel(color: .orange, title: "Too soon!", subtitle: "Click to try again")
        case .result: BigPanel(color: .blue, title: "\(resultMs) ms", subtitle: "Click to play again")
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .space || press.key == .return { tap(); return .handled }
        return .ignored
    }

    private func tap() {
        switch phase {
        case .idle, .early, .result:
            start()
        case .waiting:
            task?.cancel()
            phase = .early
            SoundPlayer.play(.fail)
        case .go:
            resultMs = max(1, Int(Date().timeIntervalSince(goTime) * 1000))
            isBest = scores.submitReaction(ms: resultMs)
            phase = .result
            SoundPlayer.play(isBest ? .win : .success)
        }
    }

    private func start() {
        phase = .waiting
        isBest = false
        task?.cancel()
        task = Task { @MainActor in
            let delay = UInt64(Double.random(in: 1.2...4.0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: delay)
            guard !Task.isCancelled else { return }
            goTime = Date()
            phase = .go
            SoundPlayer.play(.tick)
        }
    }
}
