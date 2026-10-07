import SwiftUI

// BrowserView.swift
// The Browser tab: an address/search bar on top, small controls, your pinned sites,
// and the web page underneath.

struct BrowserView: View {
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var ai: AIViewModel
    @EnvironmentObject private var notes: NotesStore
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var history: BrowsingHistory
    @FocusState private var addressFocused: Bool
    @State private var showHistory = false

    var body: some View {
        VStack(spacing: 6) {
            navigationRow
            toolRow
            ZStack(alignment: .top) {
                WebViewHost(model: browser)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                if browser.currentURL == nil {
                    homeView
                }
                if browser.isLoading {
                    ProgressView(value: browser.progress).progressViewStyle(.linear)
                        .padding(.horizontal, 2)
                }
                if let notice = browser.notice {
                    noticeBanner(notice)
                }
            }
            .frame(maxHeight: .infinity)
        }
        .onAppear { if browser.currentURL == nil { addressFocused = true } }
    }

    // MARK: Row 1: back / forward / reload / address

    private var navigationRow: some View {
        HStack(spacing: 6) {
            LNIconButton(systemName: "chevron.left", label: "Back") { browser.goBack() }
                .disabled(!browser.canGoBack)
            LNIconButton(systemName: "chevron.right", label: "Forward") { browser.goForward() }
                .disabled(!browser.canGoForward)
            if browser.isLoading {
                LNIconButton(systemName: "xmark", label: "Stop loading") { browser.stop() }
            } else {
                LNIconButton(systemName: "arrow.clockwise", label: "Reload") { browser.reload() }
                    .disabled(browser.currentURL == nil)
            }
            LNIconButton(systemName: "house", label: "Home (pinned sites)") { browser.goHome() }

            HStack(spacing: 6) {
                Image(systemName: lockIcon)
                    .foregroundStyle(browser.currentURL?.scheme == "http" ? Color.orange : Color.secondary)
                    .accessibilityLabel(browser.currentURL?.scheme == "http" ? "Not secure" : "Address")
                TextField("Search \(settings.prefs.searchEngine.title) or type a website", text: $browser.addressText)
                    .textFieldStyle(.plain)
                    .focused($addressFocused)
                    .onSubmit { browser.load(browser.addressText) }
                    .accessibilityLabel("Address or search")
                if browser.isPrivate {
                    Image(systemName: "eye.slash.fill").foregroundStyle(.purple)
                        .help("Private mode is on")
                        .accessibilityLabel("Private mode is on")
                }
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Color.primary.opacity(0.1)))

            Menu {
                ForEach(SearchEngine.allCases) { engine in
                    Button {
                        settings.prefs.searchEngine = engine
                    } label: {
                        if settings.prefs.searchEngine == engine {
                            Label(engine.title, systemImage: "checkmark")
                        } else {
                            Text(engine.title)
                        }
                    }
                }
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 26)
            .help("Search engine: \(settings.prefs.searchEngine.title)")
            .accessibilityLabel("Choose search engine")
        }
    }

    private var lockIcon: String {
        guard let url = browser.currentURL else { return "magnifyingglass" }
        return url.scheme == "https" ? "lock.fill" : "lock.open.fill"
    }

    // MARK: Row 2: pinned sites + tools

    private var toolRow: some View {
        HStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 5) {
                    ForEach(settings.prefs.pinnedSites) { site in
                        Button {
                            if let url = URL(string: site.url) { browser.open(url) }
                        } label: {
                            Text(site.title).lnFont(11, .medium).lineLimit(1)
                        }
                        .buttonStyle(LNButtonStyle())
                        .help(site.url)
                    }
                }
            }
            LNIconButton(systemName: browser.isCurrentPagePinned ? "pin.fill" : "pin",
                         label: browser.isCurrentPagePinned ? "Unpin this page" : "Pin this page",
                         isActive: browser.isCurrentPagePinned) { browser.togglePinCurrent() }
                .disabled(browser.currentURL == nil)
            LNIconButton(systemName: "doc.plaintext", label: "Focus Reader (distraction-free text)", isActive: browser.isReader) {
                Task { await browser.toggleReader() }
            }
            .disabled(browser.currentURL == nil)
            LNIconButton(systemName: "minus.magnifyingglass", label: "Zoom out") { browser.zoomOut() }
            LNIconButton(systemName: "plus.magnifyingglass", label: "Zoom in") { browser.zoomIn() }
            LNIconButton(systemName: "link", label: "Copy link") { browser.copyLink() }
                .disabled(browser.currentURL == nil)
            LNIconButton(systemName: "arrow.up.right.square", label: "Open in default browser") { browser.openInDefaultBrowser() }
                .disabled(browser.currentURL == nil)
            askAIMenu
            saveMenu
            LNIconButton(systemName: browser.isPrivate ? "eye.slash.fill" : "eye.slash",
                         label: browser.isPrivate ? "Turn private mode off" : "Turn private mode on",
                         isActive: browser.isPrivate) { browser.setPrivate(!browser.isPrivate) }
            LNIconButton(systemName: "clock", label: "Browsing history") { showHistory.toggle() }
                .popover(isPresented: $showHistory) { historyPopover }
        }
    }

    private var askAIMenu: some View {
        Menu {
            Button("Ask AI about the selected text") { Task { await browser.askAI(.selection, ai: ai, notch: notch) } }
            Button("Ask AI to summarise this page") { Task { await browser.askAI(.pageText, ai: ai, notch: notch) } }
            Button("Ask AI about a screenshot of this page") { Task { await browser.askAI(.screenshot, ai: ai, notch: notch) } }
        } label: {
            Image(systemName: "sparkles")
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.1)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .disabled(browser.currentURL == nil)
        .help("Ask AI about this page (nothing is sent until you press Send in the AI tab)")
        .accessibilityLabel("Ask AI about this page")
    }

    private var saveMenu: some View {
        Menu {
            Button("Save page as a study note") { Task { await browser.saveAsNote(to: notes) } }
            SaveToAssignmentsMenuItems()
        } label: {
            Image(systemName: "square.and.arrow.down")
                .frame(width: 26, height: 24)
                .background(RoundedRectangle(cornerRadius: 7, style: .continuous).fill(Color.primary.opacity(0.1)))
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .frame(width: 28)
        .disabled(browser.currentURL == nil)
        .help("Save to notes or assignments")
        .accessibilityLabel("Save this page")
    }

    // MARK: History popover

    private var historyPopover: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Browsing history").font(.headline)
            if !settings.prefs.browserHistoryEnabled {
                Text("History is OFF, so nothing is being recorded. Turn it on in Settings > Browser if you want it.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if history.entries.isEmpty {
                Text("Nothing here.").font(.caption).foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(history.entries.prefix(50)) { entry in
                            Button {
                                if let url = URL(string: entry.url) { browser.open(url) }
                                showHistory = false
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(entry.title).lineLimit(1)
                                    Text(entry.url).font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 200)
                Button("Clear history") { history.clear() }
            }
        }
        .padding()
        .frame(width: 320)
    }

    // MARK: Home and notices

    private var homeView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Type a website or a search above, or pick a pinned site.")
                    .lnFont(12, .medium)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                    ForEach(settings.prefs.pinnedSites) { site in
                        Button {
                            if let url = URL(string: site.url) { browser.open(url) }
                        } label: {
                            HStack {
                                Image(systemName: "globe")
                                Text(site.title).lnFont(12).lineLimit(1)
                                Spacer()
                            }
                            .card(padding: 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    Label(settings.prefs.browserHistoryEnabled ? "History is ON" : "History is OFF (nothing is recorded)",
                          systemImage: "clock")
                    Label(browser.isPrivate ? "Private mode is ON" : "Private mode is off",
                          systemImage: "eye.slash")
                    Label(settings.prefs.blockPopups ? "Pop-ups are blocked" : "Pop-ups are allowed",
                          systemImage: "rectangle.on.rectangle.slash")
                    Label("Camera, microphone and location requests from sites are always refused",
                          systemImage: "hand.raised")
                }
                .lnFont(10.5).foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.04)))
    }

    private func noticeBanner(_ text: String) -> some View {
        HStack {
            Image(systemName: "info.circle.fill")
            Text(text).lnFont(11).lineLimit(2)
            Spacer()
            Button { browser.notice = nil } label: { Image(systemName: "xmark") }
                .buttonStyle(.plain).accessibilityLabel("Dismiss message")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(.ultraThickMaterial))
        .padding(6)
        .frame(maxHeight: .infinity, alignment: .bottom)
    }
}

/// Placeholder until Step 5 adds assignments. It is replaced with real menu items then.
struct SaveToAssignmentsMenuItems: View {
    var body: some View { EmptyView() }
}
