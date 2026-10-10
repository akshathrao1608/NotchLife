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
                        if let index = settings.prefs.pinnedTabs.firstIndex(of: notch.selectedTab) {
                            Text("⌘\(index + 1)").lnFont(10).foregroundStyle(.secondary)
                                .accessibilityHidden(true)
                        }
                    }
                    tabContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
                .padding(.horizontal, 26)
                .padding(.top, 8)
                .padding(.bottom, 20)

                if notch.showPalette {
                    PaletteView()
                        .padding(.horizontal, 22)
                        .padding(.top, 6)
                        .padding(.bottom, 16)
                        .transition(.opacity)
                }
            }
            .environment(\.colorScheme, bodyScheme)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: Header

    private func header(_ geometry: NotchGeometry) -> some View {
        let tabs = settings.prefs.pinnedTabs
        let half = (tabs.count + 1) / 2
        return HStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(Array(tabs.prefix(half))) { TabButton(tab: $0) }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            Color.clear.frame(width: geometry.notchWidth)

            HStack(spacing: 2) {
                ForEach(Array(tabs.suffix(from: half))) { TabButton(tab: $0) }
                Button { notch.showPalette.toggle() } label: {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 30, height: 26)
                        .foregroundStyle(notch.showPalette ? Color.black : Color.white.opacity(0.8))
                        .background(Capsule().fill(notch.showPalette ? Color.white.opacity(0.9) : Color.clear))
                }
                .buttonStyle(.plain)
                .help("All modules and search (Control+Option+P)")
                .accessibilityLabel("All modules and command palette")
                Button { notch.collapse() } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 26, height: 26)
                        .foregroundStyle(Color.white.opacity(0.7))
                }
                .buttonStyle(.plain)
                .help("Close (Esc)")
                .accessibilityLabel("Close LifeNotch")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
    }

    // MARK: Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch notch.selectedTab {
        case .ai: AISearchView()
        case .browser: BrowserView()
        case .messages: MessagesView()
        case .assignments: AssignmentsView()
        case .sports: SportsView()
        case .games: GamesView()
        case .macFun: MacFunView()
        case .settings: SettingsView()
        case .home: HomeView()
        case .clipboard: ClipboardView()
        case .todo: TodoView()
        case .timer: TimerToolView()
        case .world: WorldClockView()
        case .tools: ToolsView()
        case .shelf: ShelfView()
        case .search: FileSearchView()
        case .snippets: SnippetsView()
        case .shortcuts: ShortcutsView()
        case .translate: TranslateView()
        }
    }
}

struct TabButton: View {
    let tab: NotchTab
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var messages: MessageHub
    @Environment(\.lnAccent) private var accent

    var body: some View {
        let selected = notch.selectedTab == tab
        let badge = (tab == .messages && settings.prefs.messagesEnabled) ? messages.unreadCount : 0
        Button { notch.selectedTab = tab } label: {
            Image(systemName: tab.icon)
                .font(.system(size: 13 * settings.textScale, weight: .semibold))
                .frame(width: 30, height: 26)
                .foregroundStyle(selected ? Color.black : Color.white.opacity(settings.prefs.highContrast ? 1.0 : 0.72))
                .background(Capsule().fill(selected ? accent : Color.clear))
                .overlay(alignment: .topTrailing) {
                    if badge > 0 {
                        Text("\(min(badge, 99))")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .background(Capsule().fill(Color.red))
                            .offset(x: 2, y: -2)
                    }
                }
        }
        .buttonStyle(.plain)
        .help(shortcutHelp)
        .accessibilityLabel(tab.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var shortcutHelp: String {
        if let index = settings.prefs.pinnedTabs.firstIndex(of: tab) { return "\(tab.title) (⌘\(index + 1))" }
        return tab.title
    }
}
