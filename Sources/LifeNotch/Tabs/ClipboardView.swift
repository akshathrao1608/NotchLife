import SwiftUI

// ClipboardView.swift
// Your clipboard history (text and links you copied), with search, pin and filters.
// It is OFF until you turn it on and agree to the question. See ClipboardMonitor.swift.

struct ClipboardView: View {
    @EnvironmentObject private var clipboard: ClipboardMonitor
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var notch: NotchState

    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All", pinned = "Pinned", text = "Text", links = "Links"
        var id: String { rawValue }
    }

    @State private var filter: Filter = .all
    @State private var search = ""

    private var shown: [ClipboardItem] {
        clipboard.items.filter { item in
            switch filter {
            case .all: break
            case .pinned: if !item.pinned { return false }
            case .text: if item.isLink { return false }
            case .links: if !item.isLink { return false }
            }
            return search.isEmpty || item.text.localizedCaseInsensitiveContains(search)
        }
        .sorted { ($0.pinned ? 1 : 0, $0.date) > ($1.pinned ? 1 : 0, $1.date) }
    }

    var body: some View {
        if !settings.prefs.clipboardHistoryEnabled {
            VStack(spacing: 10) {
                EmptyStateView(icon: "doc.on.clipboard", title: "Clipboard history is off",
                               message: "Turn it on to keep the last 25 things you copied (text and links), search them, pin favourites and copy them again. It ignores items password managers mark as secret, and nothing is sent anywhere.")
                Button("Turn on…") {
                    let ok = ModalHelper.confirm(
                        title: "Turn on clipboard history?",
                        message: "LifeNotch will remember TEXT you copy (up to 25 items plus your pinned ones) so you can copy it again. It ignores secret items from password managers, keeps the list in memory only (unless you choose \"Keep after quitting\" in Mac Fun), and never sends it anywhere. You can pause and clear it any time.",
                        confirmTitle: "Turn on")
                    if ok { settings.prefs.clipboardHistoryEnabled = true }
                }
                .buttonStyle(LNButtonStyle(prominent: true))
            }
        } else {
            VStack(spacing: 8) {
                HStack {
                    Picker("Filter", selection: $filter) {
                        ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 260)
                    TextField("Search", text: $search).textFieldStyle(.roundedBorder)
                    Button("Clear unpinned") {
                        for item in clipboard.items where !item.pinned { clipboard.remove(item) }
                    }
                    .buttonStyle(LNButtonStyle())
                    Button("Turn off") { settings.prefs.clipboardHistoryEnabled = false }.buttonStyle(LNButtonStyle())
                }
                if shown.isEmpty {
                    EmptyStateView(icon: "doc.on.clipboard", title: "Nothing here yet", message: "Copy some text and it will appear.")
                }
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(shown) { item in
                            HStack(spacing: 8) {
                                Image(systemName: item.isLink ? "link" : "text.alignleft").frame(width: 20).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(item.text).lnFont(12).lineLimit(2)
                                    Text(item.date, style: .relative).lnFont(9.5).foregroundStyle(.secondary)
                                }
                                Spacer()
                                if item.isLink {
                                    Button {
                                        if let url = URL(string: item.text.trimmingCharacters(in: .whitespacesAndNewlines)) {
                                            browser.open(url)
                                            notch.selectedTab = .browser
                                        }
                                    } label: { Image(systemName: "safari") }
                                        .buttonStyle(.plain).help("Open in the notch browser").accessibilityLabel("Open link in notch browser")
                                }
                                Button { clipboard.copyAgain(item); SoundPlayer.play(.tap) } label: { Image(systemName: "doc.on.doc") }
                                    .buttonStyle(.plain).help("Copy again").accessibilityLabel("Copy again")
                                Button { clipboard.togglePin(item) } label: { Image(systemName: item.pinned ? "pin.fill" : "pin") }
                                    .buttonStyle(.plain).help(item.pinned ? "Unpin" : "Pin").accessibilityLabel(item.pinned ? "Unpin" : "Pin")
                                Button { clipboard.remove(item) } label: { Image(systemName: "xmark") }
                                    .buttonStyle(.plain).help("Remove").accessibilityLabel("Remove from list")
                            }
                            .card(padding: 8)
                        }
                    }
                    .padding(.trailing, 6)
                }
            }
        }
    }
}
