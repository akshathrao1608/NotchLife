import AppKit
import Foundation

// ScreenCapture.swift
// Lets you drag a box around part of your screen. It uses macOS's own built-in "screencapture" tool
// (the same one behind Command + Shift + 4), so YOU pick exactly what is captured, and macOS handles
// the screen permission. The picture is kept in memory only; the temporary file is deleted at once.
// "Text Grab" reads the words in the picture on this Mac (nothing is sent anywhere).

enum ScreenCapture {
    /// Shows the crosshair, waits for you to drag a box, returns PNG data (nil if you pressed Esc).
    static func captureRegion() async -> Data? {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("lifenotch-capture-\(UUID().uuidString).png")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", file.path]   // -i choose a region, -x no camera sound
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            process.terminationHandler = { _ in continuation.resume() }
            do { try process.run() } catch { continuation.resume() }
        }
        defer { try? FileManager.default.removeItem(at: file) }
        return try? Data(contentsOf: file)
    }
}

/// Connects the capture shortcuts and buttons to the AI tab and the clipboard.
final class ScreenCaptureCoordinator: ObservableObject {
    @Published var message = ""
    @Published var isBusy = false

    private let settings: AppSettings
    private let ai: AIViewModel
    private let notch: NotchState

    init(settings: AppSettings, ai: AIViewModel, notch: NotchState) {
        self.settings = settings
        self.ai = ai
        self.notch = notch
    }

    private func allowed() -> Bool {
        ConsentGate.request(.screenCapture, settings: settings,
                            explanation: "You will drag a box around part of your screen. Only that box is captured, it stays in memory, and nothing is sent anywhere until you press Send in AI Search. macOS may ask for Screen Recording permission the first time.")
    }

    /// Capture a region and put it in the AI tab (not sent until you press Send).
    @MainActor
    func askAI() async {
        guard !isBusy, allowed() else { return }
        isBusy = true
        defer { isBusy = false }
        notch.collapse()
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard let data = await ScreenCapture.captureRegion() else { message = "Capture cancelled."; return }
        ai.addImageData(data, name: "Screen capture.png")
        ai.input = ai.input.isEmpty ? "What is on my screen? Explain it simply." : ai.input
        ai.notice = "Screen picture added. Check it, then press Send. Nothing has been sent yet."
        notch.open(.ai)
    }

    /// Capture a region and copy the words in it to the clipboard.
    @MainActor
    func textGrab() async {
        guard !isBusy, allowed() else { return }
        isBusy = true
        defer { isBusy = false }
        notch.collapse()
        try? await Task.sleep(nanoseconds: 300_000_000)
        guard let data = await ScreenCapture.captureRegion() else { message = "Capture cancelled."; return }
        do {
            let text = try await AttachmentLoader.recognizeText(imageData: data)
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                message = "No text found in that area."
            } else {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(text, forType: .string)
                message = "Copied \(text.count) characters to the clipboard."
                NotificationManager.shared.notifyNow(id: "textgrab", title: "Text copied", body: String(text.prefix(80)))
            }
        } catch {
            message = error.localizedDescription
        }
    }
}
