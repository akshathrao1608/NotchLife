import Foundation

// AnthropicClient.swift
// Talks to the Claude API (https://api.anthropic.com/v1/messages) using YOUR API key.
// Nothing goes through any LifeNotch server: your Mac talks straight to Anthropic.

struct AnthropicClient: AIClient {
    func complete(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        var messages: [[String: Any]] = []
        for turn in request.turns {
            messages.append(["role": turn.role.rawValue, "content": content(for: turn)])
        }

        var body: [String: Any] = [
            "model": request.model,
            "max_tokens": request.maxTokens,
            "system": request.system,
            "messages": messages
        ]
        if request.useWebSearch {
            // Anthropic runs the search on its side and returns citations.
            body["tools"] = [["type": "web_search_20250305", "name": "web_search", "max_uses": 5]]
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, status) = try await AIHTTP.send(urlRequest)
        guard status == 200 else {
            throw AIError.http(status: status, message: AIHTTP.errorMessage(from: data))
        }
        return try parse(data)
    }

    private func content(for turn: AITurn) -> [[String: Any]] {
        var blocks: [[String: Any]] = []
        for attachment in turn.attachments {
            switch attachment.kind {
            case .image:
                blocks.append(["type": "image",
                               "source": ["type": "base64",
                                          "media_type": attachment.mimeType,
                                          "data": attachment.data.base64EncodedString()]])
            case .pdf:
                blocks.append(["type": "document",
                               "source": ["type": "base64",
                                          "media_type": "application/pdf",
                                          "data": attachment.data.base64EncodedString()]])
            case .text:
                blocks.append(["type": "text", "text": AIHTTP.textBlock(for: attachment)])
            }
        }
        let text = turn.text.isEmpty ? "(see attached)" : turn.text
        blocks.append(["type": "text", "text": text])
        return blocks
    }

    private func parse(_ data: Data) throws -> AIResponse {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let blocks = json["content"] as? [[String: Any]] else {
            throw AIError.badResponse
        }
        var text = ""
        var cited: [AISource] = []
        var found: [AISource] = []

        for block in blocks {
            let type = block["type"] as? String
            if type == "text" {
                text += (block["text"] as? String) ?? ""
                for citation in (block["citations"] as? [[String: Any]]) ?? [] {
                    if let url = AIHTTP.webURL(citation["url"] as? String) {
                        cited.append(AISource(title: (citation["title"] as? String) ?? url.host ?? url.absoluteString, url: url))
                    }
                }
            } else if type == "web_search_tool_result" {
                for result in (block["content"] as? [[String: Any]]) ?? [] {
                    if let url = AIHTTP.webURL(result["url"] as? String) {
                        found.append(AISource(title: (result["title"] as? String) ?? url.host ?? url.absoluteString, url: url))
                    }
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.badResponse }
        return AIResponse(text: trimmed, sources: AIHTTP.dedupe(cited + found))
    }
}
