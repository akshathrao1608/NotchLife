import SwiftUI

// GamesView.swift
// The Mini Games tab: pick one of six games. Best scores are saved on this Mac.

struct GamesView: View {
    @EnvironmentObject private var scores: GameScores
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var notch: NotchState
    @State private var selected: GameKind?

    var body: some View {
        content
            .onAppear(perform: takePendingGame)
            .onChange(of: notch.pendingGame) { _ in takePendingGame() }
    }

    private func takePendingGame() {
        if let game = notch.pendingGame {
            selected = game
            notch.pendingGame = nil
        }
    }

    @ViewBuilder
    private var content: some View {
        if let game = selected {
            VStack(spacing: 8) {
                HStack {
                    Button { selected = nil } label: { Label("All games", systemImage: "chevron.left") }
                        .buttonStyle(LNButtonStyle())
                    Text(game.title).lnFont(14, .bold)
                    Spacer()
                    muteButton
                }
                gameView(game)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Pick a game. Everything works with mouse or keyboard.").lnFont(11.5).foregroundStyle(.secondary)
                    Spacer()
                    muteButton
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 10)], spacing: 10) {
                    ForEach(GameKind.allCases) { game in
                        Button { selected = game } label: {
                            HStack(spacing: 10) {
                                Image(systemName: game.icon).font(.system(size: 22)).frame(width: 34)
                                    .foregroundStyle(settings.prefs.theme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(game.title).lnFont(13, .bold)
                                    Text(game.blurb).lnFont(10.5).foregroundStyle(.secondary).lineLimit(2)
                                    Text(scores.bestText(for: game).map { "Best: \($0)" } ?? "No score yet")
                                        .lnFont(10.5, .semibold)
                                }
                                Spacer(minLength: 0)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .card()
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(game.title). \(game.blurb)")
                    }
                }
                Spacer()
            }
        }
    }

    private var muteButton: some View {
        LNIconButton(systemName: settings.prefs.soundMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                     label: settings.prefs.soundMuted ? "Unmute sound effects" : "Mute sound effects",
                     isActive: settings.prefs.soundMuted) {
            settings.prefs.soundMuted.toggle()
        }
    }

    @ViewBuilder
    private func gameView(_ game: GameKind) -> some View {
        switch game {
        case .reaction: ReactionGame()
        case .memory: MemoryGame()
        case .maths: MathsGame()
        case .penalty: PenaltyGame()
        case .f1Lights: F1LightsGame()
        case .wordRush: WordRushGame()
        }
    }
}
