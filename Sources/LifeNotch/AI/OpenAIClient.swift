import Foundation

// OpenAIClient.swift
// Talks to the OpenAI "Responses" API (https://api.openai.com/v1/responses) using YOUR key.

struct OpenAIClient: AIClient {
    func complete(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        var input: [[String: Any]] = []
        for turn in request.turns {
            switch turn.role {
            case .assistant:
                input.append(["role": "assistant", "content": turn.text])
            case .user:
                input.append(["role": "user", "content": userContent(for: turn)])
            }
        }

        var body: [String: Any] = [
            "model": request.model,
            "instructions": request.system,
            "input": input,
            "max_output_tokens": request.maxTokens
        ]
        if request.useWebSearch {
            body["tools"] = [["type": "web_search"]]
        }

        var urlRequest = URLRequest(url: URL(string: "https://api.openai.com/v1/responses")!)
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = 180
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, status) = try await AIHTTP.send(urlRequest)
        guard status == 200 else {
            throw AIError.http(status: status, message: AIHTTP.errorMessage(from: data))
        }
        return try parse(data)
    }

    private func userContent(for turn: AITurn) -> [[String: Any]] {
        var parts: [[String: Any]] = []
        for attachment in turn.attachments {
            switch attachment.kind {
            case .image:
                parts.append(["type": "input_image",
                              "image_url": "data:\(attachment.mimeType);base64,\(attachment.data.base64EncodedString())"])
            case .pdf:
                parts.append(["type": "input_file",
                              "filename": attachment.name,
                              "file_data": "data:application/pdf;base64,\(attachment.data.base64EncodedString())"])
            case .text:
                parts.append(["type": "input_text", "text": AIHTTP.textBlock(for: attachment)])
            }
        }
        parts.append(["type": "input_text", "text": turn.text.isEmpty ? "(see attached)" : turn.text])
        return parts
    }

    private func parse(_ data: Data) throws -> AIResponse {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let output = json["output"] as? [[String: Any]] else {
            throw AIError.badResponse
        }
        var text = ""
        var sources: [AISource] = []
        for item in output where (item["type"] as? String) == "message" {
            for part in (item["content"] as? [[String: Any]]) ?? [] where (part["type"] as? String) == "output_text" {
                text += (part["text"] as? String) ?? ""
                for annotation in (part["annotations"] as? [[String: Any]]) ?? [] where (annotation["type"] as? String) == "url_citation" {
                    if let url = AIHTTP.webURL(annotation["url"] as? String) {
                        sources.append(AISource(title: (annotation["title"] as? String) ?? url.host ?? url.absoluteString, url: url))
                    }
                }
            }
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw AIError.badResponse }
        return AIResponse(text: trimmed, sources: AIHTTP.dedupe(sources))
    }
}
