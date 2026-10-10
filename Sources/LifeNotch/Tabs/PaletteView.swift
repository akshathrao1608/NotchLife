import SwiftUI
import AppKit

// PaletteView.swift
// The command palette (Control + Option + P, or the grid button). Type to find any tab or
// action, do a quick calculation, search the web, ask the AI, find a file, run a shortcut or
// copy a snippet. Up/Down to choose, Return to run, Esc to close the palette.

struct PaletteItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let run: () -> Void
}

struct PaletteView: View {
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var ai: AIViewModel
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var pomodoro: PomodoroModel
    @EnvironmentObject private var timer: ToolTimerModel
    @EnvironmentObject private var keepAwake: KeepAwakeModel
    @EnvironmentObject private var fileSearch: FileSearchModel

    @State private var query = ""
    @State private var selection = 0
    @FocusState private var focused: Bool

    var body: some View {
        let list = items
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "command").foregroundStyle(.secondary)
                TextField("Type to find a tab or action…", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15 * settings.textScale))
                    .focused($focused)
                    .onSubmit { run(list) }
                    .onKeyPress(.downArrow) { selection = min(selection + 1, max(list.count - 1, 0)); return .handled }
                    .onKeyPress(.upArrow) { selection = max(selection - 1, 0); return .handled }
                    .accessibilityLabel("Command palette search")
                Button { notch.showPalette = false } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).accessibilityLabel("Close palette")
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.primary.opacity(0.1)))

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(list.enumerated()), id: \.element.id) { index, item in
                            HStack(spacing: 10) {
                                Image(systemName: item.icon).frame(width: 22).foregroundStyle(settings.prefs.theme.accent)
                                VStack(alignment: .leading, spacing: 0) {
                                    Text(item.title).lnFont(13, .medium).lineLimit(1)
                                    Text(item.subtitle).lnFont(10.5).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                if index == selection { Text("↩").lnFont(11).foregroundStyle(.secondary) }
                            }
                            .padding(.horizontal, 10).padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(index == selection ? settings.prefs.theme.accent.opacity(0.25) : Color.clear))
                            .contentShape(Rectangle())
                            .onTapGesture { selection = index; run(list) }
                            .id(item.id)
                        }
                    }
                }
                .onChange(of: selection) { _ in
                    if list.indices.contains(selection) { proxy.scrollTo(list[selection].id) }
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.regularMaterial))
        .onAppear { focused = true; selection = 0 }
        .onChange(of: query) { _ in selection = 0 }
    }

    private func run(_ list: [PaletteItem]) {
        guard list.indices.contains(selection) else { return }
        list[selection].run()
    }

    private func close() { notch.showPalette = false }

    // MARK: What can be found

    private var items: [PaletteItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        var result: [PaletteItem] = []

        // Dynamic items that depend on what you typed.
        if !q.isEmpty {
            if let value = Calculator.evaluate(q), q.rangeOfCharacter(from: CharacterSet(charactersIn: "+-*/^%()×÷")) != nil {
                let text = Calculator.format(value)
                result.append(PaletteItem(id: "calc", title: "= \(text)", subtitle: "Calculator. Press Return to copy the answer", icon: "plusminus.circle") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    close()
                })
            }
            for name in settings.prefs.shortcutNames where name.localizedCaseInsensitiveContains(q) {
                result.append(PaletteItem(id: "sc-\(name)", title: "Run shortcut: \(name)", subtitle: "Apple Shortcuts", icon: "bolt.fill") {
                    var comps = URLComponents()
                    comps.scheme = "shortcuts"; comps.host = "run-shortcut"
                    comps.queryItems = [URLQueryItem(name: "name", value: name)]
                    if let url = comps.url { NSWorkspace.shared.open(url) }
                    close()
                })
            }
            for snippet in settings.prefs.snippets where snippet.title.localizedCaseInsensitiveContains(q) {
                result.append(PaletteItem(id: "sn-\(snippet.id)", title: "Copy snippet: \(snippet.title)", subtitle: String(snippet.text.prefix(60)), icon: "text.quote") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(snippet.text, forType: .string)
                    close()
                })
            }
        }

        // Tabs and actions (filtered by what you typed).
        var fixed: [PaletteItem] = NotchTab.allCases.map { tab in
            PaletteItem(id: "tab-\(tab.rawValue)", title: tab.title, subtitle: tab.blurb, icon: tab.icon) {
                notch.selectedTab = tab
                close()
            }
        }
        fixed.append(PaletteItem(id: "act-focus", title: "Start or pause the focus timer", subtitle: "Pomodoro", icon: "timer") {
            pomodoro.toggle(); close()
        })
        fixed.append(PaletteItem(id: "act-5min", title: "Start a 5 minute timer", subtitle: "Countdown", icon: "hourglass") {
            timer.startCountdown(seconds: 300); close()
        })
        fixed.append(PaletteItem(id: "act-awake", title: keepAwake.isOn ? "Stop keeping the Mac awake" : "Keep the Mac awake for 1 hour", subtitle: "Keep Awake", icon: "cup.and.saucer.fill") {
            keepAwake.isOn ? keepAwake.stop() : keepAwake.start(minutes: 60); close()
        })
        fixed.append(PaletteItem(id: "act-newchat", title: "New AI chat", subtitle: "Clears the current conversation", icon: "square.and.pencil") {
            ai.newChat(); notch.selectedTab = .ai; close()
        })
        fixed.append(PaletteItem(id: "act-mute", title: settings.prefs.soundMuted ? "Unmute sounds" : "Mute all sounds", subtitle: "Sound effects", icon: "speaker.slash") {
            settings.prefs.soundMuted.toggle(); close()
        })
        fixed.append(PaletteItem(id: "act-close", title: "Close LifeNotch", subtitle: "Same as pressing Esc", icon: "chevron.up") {
            notch.collapse()
        })
        result.append(contentsOf: q.isEmpty ? fixed : fixed.filter {
            $0.title.localizedCaseInsensitiveContains(q) || $0.subtitle.localizedCaseInsensitiveContains(q)
        })

        // "Do something with what I typed" fall-backs at the end.
        if !q.isEmpty {
            result.append(PaletteItem(id: "ask", title: "Ask the AI: “\(q)”", subtitle: "Fills the AI tab (nothing is sent until you press Send)", icon: "sparkles") {
                ai.prefill(text: q); notch.selectedTab = .ai; close()
            })
            result.append(PaletteItem(id: "web", title: "Search the web for “\(q)”", subtitle: "Opens the notch browser", icon: "safari") {
                browser.load(q); notch.selectedTab = .browser; close()
            })
            result.append(PaletteItem(id: "files", title: "Find files named “\(q)”", subtitle: "Spotlight, on this Mac", icon: "magnifyingglass") {
                fileSearch.query = q; notch.selectedTab = .search; close()
            })
        }
        return result
    }
}
