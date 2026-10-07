import SwiftUI

// AIViewModel.swift
// Everything the AI Search tab remembers: what you typed, the chosen mode, attachments,
// the conversation, and the code that sends your question to the AI provider.

final class AIViewModel: ObservableObject {
    @Published var input = ""
    @Published var mode: AIMode = .explainSimply
    @Published var attachments: [AIAttachment] = []
    @Published var messages: [ChatMessage] = []
    @Published var isLoading = false
    @Published var showFullSolution = false
    @Published var useWebSearch: Bool
    @Published var notice: String?

    private let settings: AppSettings
    private var currentTask: Task<Void, Never>?
    private static let historyFile = "ai_chat.json"

    init(settings: AppSettings) {
        self.settings = settings
        useWebSearch = settings.prefs.aiWebSearchDefault
        if settings.prefs.aiRememberChat {
            messages = LocalStore.load([ChatMessage].self, name: Self.historyFile) ?? []
        }
    }

    var provider: AIProviderKind { settings.prefs.aiProvider }
    var hasKey: Bool { AIKeys.key(for: provider) != nil }

    private var modelName: String {
        let value = provider == .anthropic ? settings.prefs.anthropicModel : settings.prefs.openAIModel
        let trimmed = value.trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? provider.defaultModel : trimmed
    }

    // MARK: Other tabs can pre-fill a question (it is NEVER sent automatically)

    func prefill(text: String, mode newMode: AIMode? = nil, attachments newAttachments: [AIAttachment] = []) {
        input = text
        if let newMode = newMode { mode = newMode }
        attachments.append(contentsOf: newAttachments)
        notice = "Check the question, then press Send. Nothing has been sent yet."
    }

    // MARK: Attachments

    private static let maxAttachments = 5

    /// Adds files (from drag-and-drop or the file picker). Nothing is uploaded yet.
    func addFiles(_ urls: [URL]) {
        var problems: [String] = []
        for url in urls {
            guard attachments.count < Self.maxAttachments else {
                problems.append("You can attach up to \(Self.maxAttachments) items.")
                break
            }
            do {
                attachments.append(try AttachmentLoader.load(url: url))
            } catch {
                problems.append(error.localizedDescription)
            }
        }
        notice = problems.isEmpty ? nil : problems.joined(separator: " ")
    }

    func addImageData(_ data: Data, name: String) {
        guard attachments.count < Self.maxAttachments else { notice = "You can attach up to \(Self.maxAttachments) items."; return }
        do {
            attachments.append(try AttachmentLoader.imageAttachment(data: data, name: name))
            notice = nil
        } catch {
            notice = error.localizedDescription
        }
    }

    func remove(_ attachment: AIAttachment) {
        attachments.removeAll { $0.id == attachment.id }
    }

    /// Reads the text out of an attached image/PDF on this Mac and puts it in the question box.
    @MainActor
    func extractTextLocally(from attachment: AIAttachment) async {
        notice = "Reading text on your Mac…"
        do {
            let text: String
            switch attachment.kind {
            case .image: text = try await AttachmentLoader.recognizeText(imageData: attachment.data)
            case .pdf: text = AttachmentLoader.pdfText(attachment.data)
            case .text: text = attachment.textContent ?? ""
            }
            if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                notice = "No text found in \(attachment.name)."
            } else {
                input += (input.isEmpty ? "" : "\n\n") + text
                notice = "Text from \(attachment.name) was added to your question (read on your Mac, not sent anywhere)."
            }
        } catch {
            notice = error.localizedDescription
        }
    }

    func newChat() {
        cancel()
        messages = []
        attachments = []
        input = ""
        notice = nil
        LocalStore.remove(name: Self.historyFile)
    }

    func cancel() {
        currentTask?.cancel()
        currentTask = nil
        isLoading = false
    }

    func startSend() {
        guard !isLoading else { return }
        currentTask = Task { await send() }
    }

    // MARK: Sending

    @MainActor
    func send() async {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !attachments.isEmpty else { return }

        guard let apiKey = AIKeys.key(for: provider) else {
            append(.error, "No \(provider.title) API key is saved yet. AI is optional: open Settings > AI to add your own key.")
            return
        }

        if !attachments.isEmpty {
            let names = attachments.map { $0.name }.joined(separator: ", ")
            let allowed = ConsentGate.request(
                .sendAttachmentsToAI,
                settings: settings,
                explanation: "These items will be sent to \(provider.title) so it can read them: \(names).\n\nLifeNotch does not upload them anywhere else or keep a copy in the cloud. Check your provider's privacy policy for how they handle API data."
            )
            guard allowed else { return }
        }

        let sentAttachments = attachments
        let webSearch = useWebSearch || mode == .findSources

        var turns: [AITurn] = []
        for message in messages.suffix(12) {
            switch message.role {
            case .user: turns.append(AITurn(role: .user, text: message.text))
            case .assistant: turns.append(AITurn(role: .assistant, text: message.text))
            case .error: break
            }
        }
        turns.append(AITurn(role: .user, text: text, attachments: sentAttachments))

        let request = AIRequest(
            system: AIPrompts.system(mode: mode,
                                     showFullSolution: showFullSolution,
                                     translateTo: settings.prefs.aiTranslateTarget,
                                     webSearch: webSearch),
            turns: turns,
            model: modelName,
            useWebSearch: webSearch
        )

        messages.append(ChatMessage(role: .user,
                                    text: text.isEmpty ? "(attachment only)" : text,
                                    attachmentNames: sentAttachments.map { $0.name },
                                    modeTitle: mode.title))
        input = ""
        attachments = []
        notice = nil
        isLoading = true

        let client: AIClient = (provider == .anthropic) ? AnthropicClient() : OpenAIClient()
        do {
            let response = try await client.complete(request, apiKey: apiKey)
            messages.append(ChatMessage(role: .assistant,
                                        text: response.text,
                                        sources: response.sources,
                                        modeTitle: mode.title))
            if webSearch && response.sources.isEmpty {
                notice = "Web search was on, but no sources came back, so treat the facts as unverified."
            }
        } catch is CancellationError {
            // You pressed Stop: nothing to show.
        } catch {
            append(.error, error.localizedDescription)
        }
        isLoading = false
        saveHistoryIfEnabled()
    }

    private func append(_ role: ChatMessage.Role, _ text: String) {
        messages.append(ChatMessage(role: role, text: text, modeTitle: mode.title))
        saveHistoryIfEnabled()
    }

    private func saveHistoryIfEnabled() {
        guard settings.prefs.aiRememberChat else { return }
        LocalStore.save(Array(messages.suffix(100)), name: Self.historyFile)
    }
}
