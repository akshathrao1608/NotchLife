import Foundation

// OpenAICompatibleClient.swift
// Many AI services copy OpenAI's "chat completions" format: Google Gemini, Groq, OpenRouter,
// DeepSeek and Ollama (which runs on YOUR Mac). One small client talks to all of them.
//  - Images are sent as image_url data. (The model you pick must be able to see images.)
//  - PDFs have their text read on your Mac and are sent as plain text.
//  - Web search is not available through this client.

struct OpenAICompatibleClient: AIClient {
    let baseURL: String
    /// Sent as a Bearer token. Ollama needs none.
    let sendsKey: Bool

    func complete(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        var messages: [[String: Any]] = [["role": "system", "content": request.system]]
        for turn in request.turns {
            switch turn.role {
            case .assistant:
                messages.append(["role": "assistant", "content": turn.text])
            case .user:
                messages.append(["role": "user", "content": userContent(for: turn)])
            }
        }

        let body: [String: Any] = [
            "model": request.model,
            "messages": messages,
            "max_tokens": request.maxTokens
        ]

        guard let url = URL(string: baseURL + "/chat/completions") else { throw AIError.badResponse }
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 240
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if sendsKey { urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization") }
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, status) = try await AIHTTP.send(urlRequest)
        guard status == 200 else {
            throw AIError.http(status: status, message: AIHTTP.errorMessage(from: data))
        }
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIError.badResponse
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.badResponse }
        return AIResponse(text: trimmed, sources: [])
    }

    private func userContent(for turn: AITurn) -> [[String: Any]] {
        var parts: [[String: Any]] = []
        for attachment in turn.attachments {
            switch attachment.kind {
            case .image:
                let imageURL: [String: Any] = ["url": "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"]
                parts.append(["type": "image_url", "image_url": imageURL])
            case .pdf:
                let text = AttachmentLoader.pdfText(attachment.data)
                parts.append(["type": "text", "text": "[Attached PDF: \(attachment.name), text read on this Mac]\n\(text)\n[End of PDF]"])
            case .text:
                parts.append(["type": "text", "text": AIHTTP.textBlock(for: attachment)])
            }
        }
        parts.append(["type": "text", "text": turn.text.isEmpty ? "(see attached)" : turn.text])
        return parts
    }
}

extension AIProviderKind {
    /// The client that talks to this provider.
    func makeClient() -> AIClient {
        switch self {
        case .anthropic: return AnthropicClient()
        case .openai: return OpenAIClient()
        default: return OpenAICompatibleClient(baseURL: compatibleBaseURL ?? "", sendsKey: needsKey)
        }
    }
}

/// One-off questions (used by Translate and Voice summaries). Uses your chosen provider.
enum AIOneShot {
    static func run(system: String, prompt: String, settings: AppSettings, maxTokens: Int = 1500) async throws -> String {
        let provider = settings.prefs.aiProvider
        guard let key = AIKeys.key(for: provider) else {
            throw AIError.http(status: 401, message: "No API key is saved for \(provider.title). Add one in Settings > AI.")
        }
        let request = AIRequest(system: system,
                                turns: [AITurn(role: .user, text: prompt)],
                                model: settings.prefs.modelName(for: provider),
                                useWebSearch: false,
                                maxTokens: maxTokens)
        let response = try await provider.makeClient().complete(request, apiKey: key)
        return response.text
    }
}
