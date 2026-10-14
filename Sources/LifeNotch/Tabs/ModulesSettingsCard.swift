import SwiftUI

// ModulesSettingsCard.swift
// Settings > Top bar. LifeNotch has many modules. Choose up to 8 to keep in the top bar; every module
// is always available from the grid button (or Control + Option + P) too.

struct ModulesSettingsCard: View {
    @EnvironmentObject private var settings: AppSettings

    private let maxPinned = 8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Top bar tabs (pick up to \(maxPinned))")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 4) {
                ForEach(NotchTab.allCases) { tab in
                    Toggle(isOn: binding(for: tab)) {
                        Label(tab.title, systemImage: tab.icon).lnFont(12)
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!isPinned(tab) && settings.prefs.pinnedTabs.count >= maxPinned)
                }
            }
            HStack {
                Button("Reset to the original 8") { settings.prefs.pinnedTabs = NotchTab.core }.buttonStyle(LNButtonStyle())
                Toggle("Control + Option + P opens the command palette", isOn: $settings.prefs.paletteHotKeyEnabled)
            }
            Toggle("Control + Option + S asks AI about part of the screen; Control + Option + X copies its text", isOn: $settings.prefs.captureHotKeysEnabled)
            Toggle("Control + Option + arrows / Return / C snap the front window (needs Accessibility; LifeNotch asks first)", isOn: $settings.prefs.windowHotKeysEnabled)
            keyboardSoundsRow
            Text("⌘1, ⌘2… switch to the tabs in the top bar, in order.").lnFont(10).foregroundStyle(.secondary)
        }
        .card()
    }

    @ViewBuilder
    private var keyboardSoundsRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Keyboard click sounds in every app (needs Input Monitoring; asks first)", isOn: Binding(
                get: { settings.prefs.keyClickEnabled },
                set: { on in
                    if on {
                        let ok = ConsentGate.request(.keyboardSounds, settings: settings,
                            explanation: "LifeNotch will play a soft click whenever you press a key in any app. macOS makes this need the \"Input Monitoring\" permission. LifeNotch only hears THAT a key was pressed: it never looks at which key, and never stores or sends anything.")
                        settings.prefs.keyClickEnabled = ok
                    } else {
                        settings.prefs.keyClickEnabled = false
                    }
                }))
            if settings.prefs.keyClickEnabled {
                HStack {
                    Picker("Sound", selection: $settings.prefs.keyClickSound) {
                        ForEach(KeyClickModel.sounds, id: \.self) { Text($0).tag($0) }
                    }
                    .frame(width: 180)
                    Slider(value: $settings.prefs.keyClickVolume, in: 0.05...1).frame(width: 120)
                    Text("Volume").lnFont(10).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func isPinned(_ tab: NotchTab) -> Bool { settings.prefs.pinnedTabs.contains(tab) }

    private func binding(for tab: NotchTab) -> Binding<Bool> {
        Binding(
            get: { isPinned(tab) },
            set: { on in
                var current = settings.prefs.pinnedTabs
                if on {
                    if !current.contains(tab), current.count < maxPinned { current.append(tab) }
                } else if current.count > 1 {
                    current.removeAll { $0 == tab }
                }
                // Keep them in the app's natural order so the layout stays predictable.
                settings.prefs.pinnedTabs = NotchTab.allCases.filter { current.contains($0) }
            }
        )
    }
}
