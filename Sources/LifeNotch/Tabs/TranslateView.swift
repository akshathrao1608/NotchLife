import SwiftUI
import AVFoundation

// TranslateView.swift
// Translate text with your chosen AI provider, then have it read aloud (the Mac's own voices,
// on-device). The text you type is sent to the provider only when you press Translate.

struct Language: Identifiable, Hashable {
    let name: String
    let code: String   // used to pick a voice
    var id: String { name }

    static let all: [Language] = [
        Language(name: "Spanish", code: "es-ES"), Language(name: "French", code: "fr-FR"),
        Language(name: "German", code: "de-DE"), Language(name: "Italian", code: "it-IT"),
        Language(name: "Portuguese", code: "pt-BR"), Language(name: "Hindi", code: "hi-IN"),
        Language(name: "Arabic", code: "ar-SA"), Language(name: "Mandarin Chinese", code: "zh-CN"),
        Language(name: "Japanese", code: "ja-JP"), Language(name: "Korean", code: "ko-KR"),
        Language(name: "Russian", code: "ru-RU"), Language(name: "English", code: "en-US")
    ]
}

final class SpeechHelper: ObservableObject {
    private let synthesizer = AVSpeechSynthesizer()

    func speak(_ text: String, languageCode: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: languageCode)
        synthesizer.speak(utterance)
    }

    func stop() { synthesizer.stopSpeaking(at: .immediate) }
}

struct TranslateView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var speech = SpeechHelper()
    @State private var input = ""
    @State private var output = ""
    @State private var target = Language.all[0]
    @State private var isLoading = false
    @State private var errorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Translate to", selection: $target) {
                    ForEach(Language.all) { Text($0.name).tag($0) }
                }
                .frame(width: 260)
                Button { translate() } label: { Label("Translate", systemImage: "character.bubble") }
                    .buttonStyle(LNButtonStyle(prominent: true))
                    .disabled(input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                if isLoading { ProgressView().controlSize(.small) }
                Spacer()
                Text("Uses \(settings.prefs.aiProvider.title)").lnFont(10).foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading) {
                    SectionTitle("Your text")
                    TextEditor(text: $input)
                        .font(.system(size: 13))
                        .padding(4)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.08)))
                        .accessibilityLabel("Text to translate")
                }
                VStack(alignment: .leading) {
                    SectionTitle(target.name)
                    ScrollView {
                        Text(output.isEmpty ? "The translation appears here." : output)
                            .lnFont(14, .medium)
                            .foregroundStyle(output.isEmpty ? Color.secondary : Color.primary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.05)))
                    HStack {
                        Button { speech.speak(output, languageCode: target.code) } label: { Label("Read aloud", systemImage: "speaker.wave.2.fill") }
                            .buttonStyle(LNButtonStyle()).disabled(output.isEmpty)
                        Button("Copy") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(output, forType: .string)
                        }
                        .buttonStyle(LNButtonStyle()).disabled(output.isEmpty)
                        AIBadge()
                    }
                }
            }
            if let errorText = errorText {
                Label(errorText, systemImage: "exclamationmark.triangle.fill").lnFont(11).foregroundStyle(.orange)
            }
        }
        .onDisappear { speech.stop() }
    }

    private func translate() {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isLoading = true
        errorText = nil
        let language = target.name
        Task { @MainActor in
            do {
                let system = "You are a translator. Translate the user's text into \(language). Reply with ONLY the translation, with no quotes or commentary. If the text is not in a Latin alphabet script in the target language, add one extra line in the form: Pronunciation: <romanised pronunciation>."
                output = try await AIOneShot.run(system: system, prompt: text, settings: settings)
            } catch {
                errorText = error.localizedDescription
            }
            isLoading = false
        }
    }
}
