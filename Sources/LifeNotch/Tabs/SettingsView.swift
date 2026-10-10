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
                ModulesSettingsCard()
                AISettingsCard()
                BrowserSettingsCard()
                SportsSettingsCard()
                compactBarCard
                NotificationsSettingsCard()
                BackupSettingsCard()
                PrivacySettingsCard()
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
            if settings.prefs.hoverPreview {
                HStack {
                    Text("Wait before reacting").lnFont(12)
                    Slider(value: $settings.prefs.hoverDelaySeconds, in: 0...2, step: 0.1)
                        .frame(maxWidth: 200)
                        .accessibilityLabel("Hover delay in seconds")
                    Text(String(format: "%.1f s", settings.prefs.hoverDelaySeconds)).lnFont(11).monospacedDigit()
                }
                Text("Clicking the notch always opens it straight away.").lnFont(10.5).foregroundStyle(.secondary)
            }
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
            SectionTitle("Notch size")
            Text("If the bar covers menu-bar items, make it narrower here.").lnFont(10.5).foregroundStyle(.secondary)
            Picker("Bar size", selection: $settings.prefs.compactStyle) {
                ForEach(CompactStyle.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 360)
            Text(settings.prefs.compactStyle.detail).lnFont(10.5).foregroundStyle(.secondary)
            Toggle("Set an exact width instead", isOn: Binding(
                get: { settings.prefs.compactSideWidth > 0 },
                set: { settings.prefs.compactSideWidth = $0 ? 40 : 0 }
            ))
            if settings.prefs.compactSideWidth > 0 {
                HStack {
                    Text("Width on each side of the camera").lnFont(12)
                    Slider(value: $settings.prefs.compactSideWidth, in: 10...220, step: 2)
                        .frame(maxWidth: 200)
                        .accessibilityLabel("Bar width on each side of the camera notch")
                    Text("\(Int(settings.prefs.compactSideWidth)) pt").lnFont(11).monospacedDigit()
                }
            }
            Picker("Open panel size", selection: $settings.prefs.panelSize) {
                ForEach(PanelSize.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            Divider()
            SectionTitle("Compact bar (beside the camera notch)")
            Toggle("Next assignment due", isOn: $settings.prefs.showAssignmentChip)
            Toggle("Countdown to next race or match", isOn: $settings.prefs.showCountdownChip)
            if settings.prefs.showCountdownChip {
                Picker("Countdown for", selection: $settings.prefs.countdownSource) {
                    ForEach(CountdownSource.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 320)
            }
            Toggle("Unread message count (needs Messages hub turned on)", isOn: $settings.prefs.showMessagesChip)
            Toggle("Focus timer while it is running", isOn: $settings.prefs.showTimerChip)
            Toggle("Best mini-game score", isOn: $settings.prefs.showBestScoreChip)
            if settings.prefs.showBestScoreChip {
                Picker("Game to show", selection: $settings.prefs.compactGame) {
                    ForEach(GameKind.allCases) { Text($0.title).tag($0) }
                }
                .frame(maxWidth: 320)
            }
            Toggle("AI search icon", isOn: $settings.prefs.showAIChip)
            Toggle("Quick browser search icon", isOn: $settings.prefs.showBrowserChip)
            Divider()
            Text("Off until you turn them on:").lnFont(10.5).foregroundStyle(.secondary)
            Toggle("Battery", isOn: $settings.prefs.showBattery)
            Toggle("Wi-Fi", isOn: $settings.prefs.showWifi)
            Toggle("Time", isOn: $settings.prefs.showTime)
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
