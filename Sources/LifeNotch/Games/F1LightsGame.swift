import SwiftUI

// F1LightsGame.swift
// Game 5: F1 Reaction Lights. Five red lights come on one by one. When they ALL go out, react!

struct F1LightsGame: View {
    @EnvironmentObject private var scores: GameScores

    private enum Phase { case idle, lighting, holding, go, jumpStart, result }

    @State private var phase: Phase = .idle
    @State private var lights = 0
    @State private var goTime = Date()
    @State private var resultMs = 0
    @State private var isBest = false
    @State private var task: Task<Void, Never>?

    var body: some View {
        KeyCatcher(onKey: handleKey) {
            VStack(spacing: 10) {
                Button(action: tap) {
                    VStack(spacing: 14) {
                        HStack(spacing: 14) {
                            ForEach(0..<5, id: \.self) { index in
                                VStack(spacing: 6) {
                                    Circle().fill(index < lights ? Color.red : Color(white: 0.18)).frame(width: 46, height: 46)
                                        .shadow(color: index < lights ? .red.opacity(0.8) : .clear, radius: 10)
                                    Circle().fill(index < lights ? Color.red : Color(white: 0.18)).frame(width: 46, height: 46)
                                        .shadow(color: index < lights ? .red.opacity(0.8) : .clear, radius: 10)
                                }
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.black))
                            }
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(lights) of 5 lights on")
                        Text(message).font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(subMessage).lnFont(11).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                HStack {
                    Text("Best: \(scores.data.f1BestMs.map { "\($0) ms" } ?? "none yet")").lnFont(12, .medium)
                    Spacer()
                    newBestBanner(isBest && phase == .result)
                    Text("Space or click").lnFont(10.5).foregroundStyle(.secondary)
                }
            }
        }
        .onDisappear { task?.cancel() }
    }

    private var message: String {
        switch phase {
        case .idle: return "Ready to race?"
        case .lighting, .holding: return "Hold…"
        case .go: return "GO!"
        case .jumpStart: return "Jump start!"
        case .result: return "\(resultMs) ms"
        }
    }

    private var subMessage: String {
        switch phase {
        case .idle: return "Press Space or click to start the lights"
        case .lighting, .holding: return "Wait for ALL the lights to go out"
        case .go: return "React now!"
        case .jumpStart: return "You moved before the lights went out. Click to retry"
        case .result: return "Click to race again"
        }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .space || press.key == .return { tap(); return .handled }
        return .ignored
    }

    private func tap() {
        switch phase {
        case .idle, .jumpStart, .result:
            start()
        case .lighting, .holding:
            task?.cancel()
            phase = .jumpStart
            lights = 0
            SoundPlayer.play(.fail)
        case .go:
            resultMs = max(1, Int(Date().timeIntervalSince(goTime) * 1000))
            isBest = scores.submitF1(ms: resultMs)
            phase = .result
            SoundPlayer.play(isBest ? .win : .success)
        }
    }

    private func start() {
        task?.cancel()
        isBest = false
        lights = 0
        phase = .lighting
        task = Task { @MainActor in
            for number in 1...5 {
                try? await Task.sleep(nanoseconds: 800_000_000)
                guard !Task.isCancelled else { return }
                lights = number
                SoundPlayer.play(.tick)
            }
            phase = .holding
            let hold = UInt64(Double.random(in: 0.3...3.0) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: hold)
            guard !Task.isCancelled else { return }
            lights = 0
            goTime = Date()
            phase = .go
        }
    }
}
