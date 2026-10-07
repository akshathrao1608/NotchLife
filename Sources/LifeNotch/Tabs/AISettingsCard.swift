import SwiftUI

// AISettingsCard.swift
// Settings > AI. Where you add your OPTIONAL API key.
// The key goes straight into the macOS Keychain. It is never shown again, never put in
// backups or exports, and only ever sent to the provider you chose.

struct AISettingsCard: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var keyDraft = ""
    @State private var hasKey = false
    @State private var message = ""

    private var provider: AIProviderKind { settings.prefs.aiProvider }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("AI provider and API key (optional)")

            Picker("Provider", selection: $settings.prefs.aiProvider) {
                ForEach(AIProviderKind.allCases) { Text($0.title).tag($0) }
            }
            .frame(maxWidth: 320)
            .onChange(of: settings.prefs.aiProvider) { _ in refreshKeyState() }

            HStack {
                Text("Model").lnFont(12)
                if provider == .anthropic {
                    TextField("Model name", text: $settings.prefs.anthropicModel).textFieldStyle(.roundedBorder)
                } else {
                    TextField("Model name", text: $settings.prefs.openAIModel).textFieldStyle(.roundedBorder)
                }
            }
            .frame(maxWidth: 360)

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
                    Text("You pay the provider directly for what you use. LifeNotch has no servers and never sees your key or questions. You can delete the key here at any time.")
                        .foregroundStyle(.secondary)
                }
                .lnFont(11)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Toggle("Let the AI search the web by default", isOn: $settings.prefs.aiWebSearchDefault)
            Toggle("Remember my AI chat on this Mac (off = forgotten when you quit)", isOn: $settings.prefs.aiRememberChat)
            Text("LifeNotch has no cloud storage feature: screenshots and documents are only sent to your AI provider for the one question you ask, and are never saved by LifeNotch.")
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
        .onAppear { refreshKeyState() }
    }

    private func refreshKeyState() {
        hasKey = KeychainStore.has(account: provider.keychainAccount)
    }
}
