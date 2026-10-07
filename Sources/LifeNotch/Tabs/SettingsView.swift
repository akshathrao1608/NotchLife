import SwiftUI

// SettingsView.swift
// The Settings tab. Each group of settings is a "card". Later build steps add more cards
// (AI key, privacy, sports, backup...). Everything is stored on this Mac only.

struct SettingsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                appearanceCard
                behaviourCard
                compactBarCard
                accessibilityCard
            }
            .padding(.trailing, 6)
        }
    }

    // MARK: Appearance

    private var appearanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Appearance")
            Picker("Appearance", selection: $settings.prefs.appearance) {
                ForEach(Appearance.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            Text("The strip around the camera notch always stays black so it blends in. This changes the panel body.")
                .lnFont(10.5).foregroundStyle(.secondary)

            SectionTitle("Notch theme")
            ThemePicker()

            SectionTitle("Notch animation")
            AnimationPicker()

            HStack {
                Text("Animation speed").lnFont(12)
                Slider(value: $settings.prefs.animationSpeed, in: 0.5...2.0)
                    .frame(maxWidth: 200)
                    .accessibilityLabel("Animation speed")
                Text(String(format: "%.1fx", settings.prefs.animationSpeed)).lnFont(11).monospacedDigit()
            }
        }
        .card()
    }

    // MARK: Behaviour

    private var behaviourCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Behaviour and shortcuts")
            Toggle("Hover to preview", isOn: $settings.prefs.hoverPreview)
            Toggle("Close when I click outside the panel", isOn: $settings.prefs.collapseOnOutsideClick)
            Toggle("Global shortcut to open/close the notch", isOn: $settings.prefs.globalHotKeyEnabled)
            if settings.prefs.globalHotKeyEnabled {
                Picker("Shortcut", selection: $settings.prefs.hotKey) {
                    ForEach(HotKeyChoice.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 300)
                if env.hotKeyRegistrationFailed {
                    Label("Another app is already using this shortcut. Pick a different one.",
                          systemImage: "exclamationmark.triangle.fill")
                        .lnFont(11).foregroundStyle(.orange)
                }
            }
            Toggle("Tab shortcuts while the notch is open", isOn: $settings.prefs.tabShortcutsEnabled)
            Text("""
                 Esc closes the panel. Option+A AI · Option+B Browser · Option+S Sports · \
                 Option+G Games · Option+T Focus timer · ⌘1–⌘8 switch tabs.
                 """)
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
    }

    // MARK: Compact bar

    private var compactBarCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Compact bar (beside the camera notch)")
            Toggle("AI search icon", isOn: $settings.prefs.showAIChip)
            Toggle("Quick browser search icon", isOn: $settings.prefs.showBrowserChip)
            Toggle("Battery (only if you turn it on)", isOn: $settings.prefs.showBattery)
            Toggle("Wi-Fi (only if you turn it on)", isOn: $settings.prefs.showWifi)
            Toggle("Time (only if you turn it on)", isOn: $settings.prefs.showTime)
        }
        .card()
    }

    // MARK: Accessibility

    private var accessibilityCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Accessibility")
            HStack {
                Text("Text size").lnFont(12)
                Slider(value: $settings.prefs.textScale, in: 1.0...1.5, step: 0.05)
                    .frame(maxWidth: 200)
                    .accessibilityLabel("Text size")
                Text(String(format: "%.0f%%", settings.prefs.textScale * 100)).lnFont(11).monospacedDigit()
            }
            Toggle("High contrast", isOn: $settings.prefs.highContrast)
            Toggle("Reduce motion (also follows macOS setting)", isOn: $settings.prefs.reduceMotion)
            Text("Every icon has a VoiceOver label. Tab / Shift-Tab move between controls; Space presses a button.")
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
    }
}
