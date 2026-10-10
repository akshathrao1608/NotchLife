import Foundation
import AVFoundation
import Speech

// VoiceNotesModel.swift
// Record your voice, turn it into text ON THIS MAC, then delete the recording.
// Microphone and speech permissions are only asked when you press Record. The text notes are saved
// in LifeNotch's own folder. An AI summary is optional and only sent when you press Summarise.

struct VoiceNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var date = Date()
    var text: String
    var summary: String = ""
}

final class VoiceNotesModel: ObservableObject {
    @Published private(set) var notes: [VoiceNote]
    @Published private(set) var isRecording = false
    @Published private(set) var isWorking = false
    @Published var message = ""
    @Published private(set) var elapsed: TimeInterval = 0

    private static let fileName = "voicenotes.json"
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?
    private var timer: Timer?

    init() {
        notes = LocalStore.load([VoiceNote].self, name: Self.fileName) ?? []
    }

    // MARK: Recording

    @MainActor
    func start(settings: AppSettings) async {
        guard !isRecording else { return }
        guard ConsentGate.request(.voiceRecording, settings: settings,
                                  explanation: "LifeNotch will use the microphone only while Record is on. The sound is turned into text by your Mac, then the recording file is deleted. Nothing is uploaded.") else { return }
        guard await AVCaptureDevice.requestAccess(for: .audio) else {
            message = "Microphone access was not allowed. You can change this in System Settings > Privacy & Security > Microphone."
            return
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lifenotch-voice-\(UUID().uuidString).m4a")
        let options: [String: Any] = [AVFormatIDKey: Int(kAudioFormatMPEG4AAC), AVSampleRateKey: 16000,
                                      AVNumberOfChannelsKey: 1]
        do {
            let recorder = try AVAudioRecorder(url: url, settings: options)
            guard recorder.record() else { message = "Could not start recording."; return }
            self.recorder = recorder
            fileURL = url
            isRecording = true
            elapsed = 0
            message = ""
            timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self = self, let rec = self.recorder else { return }
                self.elapsed = rec.currentTime
                if rec.currentTime >= 300 { Task { await self.stop() } }   // 5 minute limit
            }
        } catch {
            message = error.localizedDescription
        }
    }

    @MainActor
    func stop() async {
        guard isRecording, let url = fileURL else { return }
        timer?.invalidate()
        recorder?.stop()
        recorder = nil
        isRecording = false
        isWorking = true
        defer {
            try? FileManager.default.removeItem(at: url)   // the recording never stays on disk
            fileURL = nil
            isWorking = false
        }
        do {
            let text = try await Self.transcribe(url)
            if text.isEmpty {
                message = "I couldn't hear any words."
            } else {
                notes.insert(VoiceNote(text: text), at: 0)
                save()
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private static func transcribe(_ url: URL) async throws -> String {
        let status = await withCheckedContinuation { (c: CheckedContinuation<SFSpeechRecognizerAuthorizationStatus, Never>) in
            SFSpeechRecognizer.requestAuthorization { c.resume(returning: $0) }
        }
        guard status == .authorized else { throw VoiceError.speechDenied }
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current) ?? SFSpeechRecognizer(), recognizer.isAvailable else {
            throw VoiceError.unavailable
        }
        let request = SFSpeechURLRecognitionRequest(url: url)
        if recognizer.supportsOnDeviceRecognition { request.requiresOnDeviceRecognition = true }
        return try await withCheckedThrowingContinuation { (c: CheckedContinuation<String, Error>) in
            var finished = false
            recognizer.recognitionTask(with: request) { result, error in
                guard !finished else { return }
                if let result = result, result.isFinal {
                    finished = true
                    c.resume(returning: result.bestTranscription.formattedString)
                } else if let error = error {
                    finished = true
                    c.resume(throwing: error)
                }
            }
        }
    }

    // MARK: Notes

    @MainActor
    func summarise(_ note: VoiceNote, settings: AppSettings) async {
        guard ConsentGate.request(.sendAttachmentsToAI, settings: settings,
                                  explanation: "The text of this one voice note will be sent to your AI provider to be summarised.") else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let summary = try await AIOneShot.run(system: "Summarise the user's voice note in 2 short bullet points, then list any tasks as a checklist. Be brief and plain.",
                                                  prompt: note.text, settings: settings, maxTokens: 400)
            if let i = notes.firstIndex(where: { $0.id == note.id }) { notes[i].summary = summary }
            save()
        } catch {
            message = error.localizedDescription
        }
    }

    func delete(_ note: VoiceNote) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    private func save() { LocalStore.save(notes, name: Self.fileName) }
}

enum VoiceError: LocalizedError {
    case speechDenied, unavailable
    var errorDescription: String? {
        switch self {
        case .speechDenied: return "Speech recognition was not allowed. You can change this in System Settings > Privacy & Security > Speech Recognition."
        case .unavailable: return "Speech recognition isn't available right now."
        }
    }
}
