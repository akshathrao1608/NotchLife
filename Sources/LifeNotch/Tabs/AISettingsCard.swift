import SwiftUI

// AISettingsCard.swift
// Settings > AI. Where you pick the AI provider and add your OPTIONAL API key.
// The key goes straight into the macOS Keychain. It is never shown again, never put in
// backups or exports, and only ever sent to the provider you chose.
// Ollama runs on your own Mac: no key, and nothing leaves your computer.

struct AISettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var keyDraft = ""
    @State private var hasKey = false
    @State private var message = ""

    private var provider: AIProviderKind { settings.prefs.aiProvider }

    private var modelBinding: Binding<String> {
        Binding(
            get: {
                switch provider {
                case .anthropic: return settings.prefs.anthropicModel
                case .openai: return settings.prefs.openAIModel
                default: return settings.prefs.aiModelByProvider[provider.rawValue] ?? provider.defaultModel
                }
            },
            set: { newValue in
                switch provider {
                case .anthropic: settings.prefs.anthropicModel = newValue
                case .openai: settings.prefs.openAIModel = newValue
                default: settings.prefs.aiModelByProvider[provider.rawValue] = newValue
                }
            }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("AI provider and API key (optional)")

            Picker("Provider", selection: $settings.prefs.aiProvider) {
                ForEach(AIProviderKind.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 360)
            .onChange(of: settings.prefs.aiProvider) { _ in refreshKeyState() }

            HStack {
                Text("Model").lnFont(12)
                TextField("Model name", text: modelBinding).textFieldStyle(.roundedBorder)
            }
            .frame(maxWidth: 380)
            Text("Model names change over time. If you get a \"model not found\" error, check your provider's list and type the current name here.")
                .lnFont(10).foregroundStyle(.secondary)

            if provider.needsKey {
                keySection
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Runs on this Mac. No key, no account, nothing sent online.", systemImage: "lock.shield")
                        .lnFont(11.5, .semibold)
                        .foregroundStyle(.green)
                    Text("Install Ollama from ollama.com, open it, then pull a model once in Terminal yourself, for example:  ollama pull gemma3:4b  (use a model that can read images if you want screenshots).")
                        .lnFont(11)
                        .foregroundStyle(.secondary)
                    Link("Get Ollama", destination: provider.keysPage).lnFont(11)
                }
            }

            Picker("AI personality", selection: $settings.prefs.aiPersona) {
                ForEach(AIPersona.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 320)

            Toggle("Let the AI search the web by default (Claude and ChatGPT only)", isOn: $settings.prefs.aiWebSearchDefault)
            Toggle("Remember my AI chat on this Mac (off = forgotten when you quit)", isOn: $settings.prefs.aiRememberChat)
            Text("LifeNotch has no cloud storage feature: screenshots and documents are only sent to your AI provider for the one question you ask, and are never saved by LifeNotch.")
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
        .onAppear { refreshKeyState() }
    }

    private var keySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SecureField(hasKey ? "A key is saved (hidden). Paste a new one to replace it." : "Paste your API key here",
                            text: $keyDraft)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 340)
                    .accessibilityLabel("API key")
                Button("Save key") {
                    let trimmed = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if KeychainStore.set(trimmed, account: provider.keychainAccount) {
                        message = "Saved in the macOS Keychain."
                    } else {
                        message = "Could not save to the Keychain."
                    }
                    keyDraft = ""
                    refreshKeyState()
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                .disabled(keyDraft.isEmpty)
                if hasKey {
                    Button("Remove key") {
                        KeychainStore.delete(account: provider.keychainAccount)
                        message = "Key removed."
                        refreshKeyState()
                    }
                    .buttonStyle(LNButtonStyle(destructive: true))
                }
            }

            HStack(spacing: 6) {
                Image(systemName: hasKey ? "checkmark.seal.fill" : "key")
                    .foregroundStyle(hasKey ? Color.green : Color.secondary)
                Text(hasKey ? "Key saved for \(provider.title)." : "No key saved for \(provider.title). AI features stay off.")
                    .lnFont(11)
                if !message.isEmpty { Text("· \(message)").lnFont(11).foregroundStyle(.secondary) }
            }

            DisclosureGroup("How do I get a key?") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("1. Open your provider's key page and sign in.")
                    Link("Open \(provider.title) key page", destination: provider.keysPage)
                    Text("2. Create a new key and copy it.")
                    Text("3. Paste it above and press Save key.")
                    Text("Free tiers (Gemini, Groq, OpenRouter) cost nothing but have daily limits. You pay the provider directly for paid use. LifeNotch has no servers and never sees your key or questions. You can delete the key here at any time.")
                        .foregroundStyle(.secondary)
                }
                .lnFont(11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func refreshKeyState() {
        hasKey = KeychainStore.has(account: provider.keychainAccount)
    }
}
