import SwiftUI

// MathsGame.swift
// Game 3: Quick Maths. Answer as many questions as you can in 30 seconds. Press Return to submit.

struct MathsGame: View {
    @EnvironmentObject private var scores: GameScores

    private enum Phase { case menu, playing, done }

    @State private var phase: Phase = .menu
    @State private var difficulty: MathsDifficulty = .easy
    @State private var question = MathQuestion.make(.easy)
    @State private var answer = ""
    @State private var score = 0
    @State private var wrong = 0
    @State private var timeLeft: Double = 30
    @State private var endDate = Date()
    @State private var flash: Color = .clear
    @State private var isBest = false
    @FocusState private var fieldFocused: Bool

    private let ticker = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    private let duration: Double = 30

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
            Text("Quick Maths").lnFont(22, .bold, design: .rounded)
            Text("Answer as many as you can in 30 seconds.").lnFont(12).foregroundStyle(.secondary)
            Picker("Difficulty", selection: $difficulty) {
                ForEach(MathsDifficulty.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented).frame(width: 260)
            Text("Best (\(difficulty.title)): \(scores.data.mathsBest[difficulty.rawValue].map(String.init) ?? "none yet")")
                .lnFont(12, .medium)
            Button("Start") { start() }
                .buttonStyle(LNButtonStyle(prominent: true))
                .keyboardShortcut(.defaultAction)
        }
    }

    private var playing: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Score: \(score)").lnFont(14, .bold)
                Spacer()
                Text(String(format: "%.1f s", max(0, timeLeft))).lnFont(14, .bold).monospacedDigit()
            }
            ProgressView(value: max(0, timeLeft), total: duration)
            Spacer()
            Text(question.text)
                .font(.system(size: 52, weight: .bold, design: .rounded))
                .padding(.horizontal, 30).padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(flash.opacity(0.35)))
                .accessibilityLabel("Question: \(question.text)")
            TextField("Answer", text: $answer)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold, design: .rounded))
                .frame(width: 160)
                .focused($fieldFocused)
                .onSubmit(submit)
                .accessibilityLabel("Your answer. Press Return to submit")
            Spacer()
        }
        .onAppear { fieldFocused = true }
    }

    private var done: some View {
        VStack(spacing: 10) {
            Text("Time's up!").lnFont(22, .bold, design: .rounded)
            Text("\(score) correct · \(wrong) wrong").lnFont(15, .semibold)
            newBestBanner(isBest)
            HStack {
                Button("Play again") { start() }.buttonStyle(LNButtonStyle(prominent: true))
                Button("Change difficulty") { phase = .menu }.buttonStyle(LNButtonStyle())
            }
        }
    }

    private func start() {
        score = 0
        wrong = 0
        isBest = false
        answer = ""
        question = MathQuestion.make(difficulty)
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
            isBest = scores.submitMaths(score: score, difficulty: difficulty)
            phase = .done
            SoundPlayer.play(isBest ? .win : .complete)
        }
    }

    private func submit() {
        guard phase == .playing, let value = Int(answer.trimmingCharacters(in: .whitespaces)) else {
            fieldFocused = true
            return
        }
        if value == question.answer {
            score += 1
            flash = .green
            SoundPlayer.play(.success)
        } else {
            wrong += 1
            flash = .red
            SoundPlayer.play(.fail)
        }
        answer = ""
        question = MathQuestion.make(difficulty)
        fieldFocused = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            flash = .clear
        }
    }
}
