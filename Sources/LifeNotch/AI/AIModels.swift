import AppKit

// AIModels.swift
// The simple "shapes of data" used by the AI feature.

/// A file/image/text snippet the user attached to a question.
struct AIAttachment: Identifiable, Equatable {
    enum Kind { case image, pdf, text }

    let id = UUID()
    let name: String
    let kind: Kind
    let data: Data
    let mimeType: String

    static func == (lhs: AIAttachment, rhs: AIAttachment) -> Bool { lhs.id == rhs.id }

    var textContent: String? {
        kind == .text ? String(data: data, encoding: .utf8) : nil
    }

    var icon: String {
        switch kind {
        case .image: return "photo"
        case .pdf: return "doc.richtext"
        case .text: return "doc.text"
        }
    }
}

/// A web page the AI used. Shown as a clickable link under the answer.
struct AISource: Identifiable, Equatable, Codable {
    var id = UUID()
    let title: String
    let url: URL
}

/// One turn of the conversation sent to the AI provider.
struct AITurn {
    enum Role: String { case user, assistant }
    var role: Role
    var text: String
    var attachments: [AIAttachment] = []
}

struct AIRequest {
    var system: String
    var turns: [AITurn]
    var model: String
    var useWebSearch: Bool
    var maxTokens = 2500
}

struct AIResponse {
    var text: String
    var sources: [AISource]
}

enum AIError: LocalizedError {
    case badResponse
    case http(status: Int, message: String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .badResponse:
            return "The AI service sent back something LifeNotch couldn't read."
        case .http(let status, let message):
            switch status {
            case 401, 403: return "The provider rejected your API key (\(status)). Check it in Settings > AI. \(message)"
            case 429: return "Too many requests or no credit left on your account (429). \(message)"
            default: return "The AI service returned an error (\(status)). \(message)"
            }
        case .network(let text):
            return "Couldn't reach the AI service: \(text)"
        }
    }
}

/// Anything that can answer a question. Anthropic and OpenAI each have one.
protocol AIClient {
    func complete(_ request: AIRequest, apiKey: String) async throws -> AIResponse
}

/// A message shown in the AI tab.
struct ChatMessage: Identifiable, Codable, Equatable {
    enum Role: String, Codable { case user, assistant, error }

    var id = UUID()
    var role: Role
    var text: String
    var sources: [AISource] = []
    var attachmentNames: [String] = []
    var modeTitle: String = ""
    var date = Date()
}

enum AIKeys {
    static func key(for provider: AIProviderKind) -> String? {
        // Ollama runs on this Mac and needs no key.
        if !provider.needsKey { return "local" }
        let value = KeychainStore.get(account: provider.keychainAccount)
        return (value?.isEmpty == false) ? value : nil
    }
}

/// Shared helpers for both clients.
enum AIHTTP {
    static func send(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            return (data, status)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw AIError.network(error.localizedDescription)
        }
    }

    /// Pulls the human-readable message out of an error body (never includes your key).
    static func errorMessage(from data: Data) -> String {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else { return "" }
        if let err = json["error"] as? [String: Any], let message = err["message"] as? String { return message }
        if let message = json["message"] as? String { return message }
        return ""
    }

    static func webURL(_ string: String?) -> URL? {
        guard let string = string, let url = URL(string: string),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    static func dedupe(_ sources: [AISource], limit: Int = 8) -> [AISource] {
        var seen = Set<String>()
        var result: [AISource] = []
        for source in sources where !seen.contains(source.url.absoluteString) {
            seen.insert(source.url.absoluteString)
            result.append(source)
            if result.count >= limit { break }
        }
        return result
    }

    /// Text files are sent as plain text inside the question.
    static func textBlock(for attachment: AIAttachment) -> String {
        "[Attached file: \(attachment.name)]\n\(attachment.textContent ?? "")\n[End of file]"
    }
}
