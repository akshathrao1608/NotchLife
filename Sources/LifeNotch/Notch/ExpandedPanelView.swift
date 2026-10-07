import SwiftUI

// ExpandedPanelView.swift
// The full panel. The top row (the same height as the camera notch) holds the tab icons:
// four on the left of the notch, four on the right. Below it is the content of the chosen tab.
// The strip around the camera notch is ALWAYS black so it blends with the hardware.

struct ExpandedPanelView: View {
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.colorScheme) private var systemScheme

    var body: some View {
        let geometry = notch.geometry
        let bodyScheme = settings.forcedColorScheme ?? systemScheme

        VStack(spacing: 0) {
            header(geometry)
                .frame(height: geometry.notchHeight)
                .environment(\.colorScheme, .dark)

            ZStack {
                if bodyScheme == .light {
                    Color(white: 0.95)
                }
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(notch.selectedTab.title).lnFont(15, .bold)
                            .accessibilityAddTraits(.isHeader)
                        Spacer()
                        Text("⌘\(notch.selectedTab.number)").lnFont(10).foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                    }
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 26)
                .padding(.top, 8)
                .padding(.bottom, 20)
            }
            .environment(\.colorScheme, bodyScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Header

    private func header(_ geometry: NotchGeometry) -> some View {
        let tabs = NotchTab.allCases
        let half = tabs.count / 2
        return HStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Array(tabs.prefix(half))) { TabButton(tab: $0) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Color.clear.frame(width: geometry.notchWidth)

            HStack(spacing: 4) {
                ForEach(Array(tabs.suffix(from: half))) { TabButton(tab: $0) }
                Button { notch.collapse() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 26)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
                .accessibilityLabel("Close LifeNotch")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 26)
    }

    // MARK: Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch notch.selectedTab {
        case .ai:
            AISearchView()
        case .settings:
            SettingsView()
        default:
            PlaceholderTabView(tab: notch.selectedTab)
        }
    }
}

struct TabButton: View {
    let tab: NotchTab
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.lnAccent) private var accent

    var body: some View {
        let selected = notch.selectedTab == tab
        Button { notch.selectedTab = tab } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 13 * settings.textScale, weight: .semibold))
                .frame(width: 34, height: 26)
                .foregroundStyle(selected ? Color.black : Color.white.opacity(settings.prefs.highContrast ? 1.0 : 0.72))
                .background(Capsule().fill(selected ? accent : Color.clear))
        }
        .buttonStyle(.plain)
        .help("\(tab.title) (⌘\(tab.number))")
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// Shown for tabs that are not built yet (temporary during development).
struct PlaceholderTabView: View {
    let tab: NotchTab
    var body: some View {
        EmptyStateView(icon: tab.icon, title: tab.title, message: "This tab is coming in a later build step.")
    }
}
