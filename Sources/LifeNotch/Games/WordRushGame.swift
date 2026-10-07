import SwiftUI

// WordRushGame.swift
// Game 6: Word Rush. Make as many words as you can from six letters in 60 seconds.
// Type a word and press Return, or click the letter tiles. Longer words score more.

struct WordRushGame: View {
    @EnvironmentObject private var scores: GameScores

    private enum Phase { case menu, playing, done }

    @State private var phase: Phase = .menu
    @State private var letters: [Character] = []
    @State private var typed = ""
    @State private var found: [String] = []
    @State private var score = 0
    @State private var message = ""
    @State private var timeLeft: Double = 60
    @State private var endDate = Date()
    @State private var possible: [String] = []
    @State private var isBest = false
    @FocusState private var fieldFocused: Bool

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let duration: Double = 60

    var body: some View {
        VStack(spacing: 10) {
            switch phase {
            case .menu: menu
            case .playing: playing
            case .done: done
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(ticker) { _ in tick() }
    }

    private var menu: some View {
        VStack(spacing: 12) {
            Text("Word Rush").lnFont(22, .bold, design: .rounded)
            Text("Make words (3+ letters) from six letters in 60 seconds. Longer words score more.")
                .lnFont(12).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Text("Best: \(scores.data.wordRushBest.map { "\($0) pts" } ?? "none yet")").lnFont(12, .medium)
            Button("Start") { start() }.buttonStyle(LNButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
        }
    }

    private var playing: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Score: \(score)").lnFont(14, .bold)
                Spacer()
                Text(String(format: "%.0f s", max(0, timeLeft))).lnFont(14, .bold).monospacedDigit()
            }
            ProgressView(value: max(0, timeLeft), total: duration)
            HStack(spacing: 8) {
                ForEach(Array(letters.enumerated()), id: \.offset) { _, letter in
                    Button { typed.append(letter); fieldFocused = true } label: {
                        Text(String(letter).uppercased())
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                            .frame(width: 46, height: 46)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.14)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Letter \(String(letter))")
                }
                LNIconButton(systemName: "shuffle", label: "Shuffle the letters") { letters.shuffle() }
            }
            HStack {
                TextField("Type a word and press Return", text: $typed)
                    .textFieldStyle(.roundedBorder)
                    .focused($fieldFocused)
                    .onSubmit(submit)
                    .frame(maxWidth: 280)
                    .accessibilityLabel("Your word")
                Button("Add") { submit() }.buttonStyle(LNButtonStyle(prominent: true))
            }
            Text(message).lnFont(11.5, .medium).foregroundStyle(.secondary).frame(height: 16)
            ScrollView {
                Text(found.isEmpty ? "Your words will appear here." : found.joined(separator: "  ·  "))
                    .lnFont(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear { fieldFocused = true }
    }

    private var done: some View {
        VStack(spacing: 8) {
            Text("Time's up!").lnFont(22, .bold, design: .rounded)
            Text("\(score) points · \(found.count) of \(possible.count) possible words").lnFont(14, .semibold)
            newBestBanner(isBest)
            let missed = possible.filter { !found.contains($0) }.sorted { $0.count > $1.count }
            if !missed.isEmpty {
                Text("You missed: " + missed.prefix(12).joined(separator: ", ") + (missed.count > 12 ? "…" : ""))
                    .lnFont(11).foregroundStyle(.secondary).multilineTextAlignment(.center)
            }
            HStack {
                Button("Play again") { start() }.buttonStyle(LNButtonStyle(prominent: true))
            }
        }
    }

    private func start() {
        letters = WordRush.newRound()
        possible = WordRush.possibleWords(from: letters)
        found = []
        score = 0
        typed = ""
        message = ""
        isBest = false
        endDate = Date().addingTimeInterval(duration)
        timeLeft = duration
        phase = .playing
        fieldFocused = true
        SoundPlayer.play(.start)
    }

    private func tick() {
        guard phase == .playing else { return }
        timeLeft = endDate.timeIntervalSinceNow
        if timeLeft <= 0 {
            timeLeft = 0
            isBest = scores.submitWordRush(score: score)
            phase = .done
            SoundPlayer.play(isBest ? .win : .complete)
        }
    }

    private func submit() {
        let word = typed.lowercased().trimmingCharacters(in: .whitespaces)
        typed = ""
        fieldFocused = true
        guard !word.isEmpty else { return }
        if word.count < 3 {
            message = "Words need 3 or more letters."
        } else if found.contains(word) {
            message = "You already found \"\(word)\"."
        } else if !WordRush.canMake(word, from: letters) {
            message = "\"\(word)\" uses letters you don't have."
            SoundPlayer.play(.fail)
        } else if !WordList.words.contains(word) {
            message = "\"\(word)\" isn't in the word list."
            SoundPlayer.play(.fail)
        } else {
            found.insert(word, at: 0)
            let points = WordRush.points(for: word)
            score += points
            message = "+\(points) for \"\(word)\""
            SoundPlayer.play(.success)
        }
    }
}
