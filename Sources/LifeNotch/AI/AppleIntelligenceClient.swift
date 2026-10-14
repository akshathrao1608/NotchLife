import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

// AppleIntelligenceClient.swift
// Uses the language model built into macOS 26+ (Apple's public "Foundation Models" framework).
// It runs entirely on this Mac: no key, no account, nothing is sent online. Text only.
// If your Xcode / macOS is older, or Apple Intelligence is off, you get a plain explanation instead.

struct AppleIntelligenceClient: AIClient {
    func complete(_ request: AIRequest, apiKey: String) async throws -> AIResponse {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let model = SystemLanguageModel.default
            guard case .available = model.availability else {
                throw AIError.network("Apple Intelligence isn't ready on this Mac. Turn it on in System Settings > Apple Intelligence & Siri, wait for it to finish downloading, then try again.")
            }
            let session = LanguageModelSession(instructions: request.system)
            let prompt: String
            if request.turns.count <= 1 {
                prompt = request.turns.first?.text ?? ""
            } else {
                prompt = request.turns.map { ($0.role == .user ? "User: " : "Assistant: ") + $0.text }.joined(separator: "\n\n") + "\n\nAssistant:"
            }
            let response = try await session.respond(to: prompt)
            return AIResponse(text: response.content, sources: [])
        }
        #endif
        throw AIError.network("Apple Intelligence needs macOS 26 or newer and LifeNotch built with Xcode 26. Pick another AI provider in Settings > AI, or Ollama for a free on-Mac model.")
    }
}
