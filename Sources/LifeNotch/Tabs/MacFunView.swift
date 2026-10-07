import SwiftUI
import UniformTypeIdentifiers

// MacFunView.swift
// The Mac Fun tab: focus timer, daily quote/fact, quick launch, notes + clipboard,
// system dashboard + Clean Desk, sounds, and notch style. Pick a section along the top.

struct MacFunView: View {
    @EnvironmentObject private var notch: NotchState

    var body: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(MacFunSection.allCases) { section in
                        Button { notch.macFunSection = section } label: {
                            Label(section.title, systemImage: section.icon).lnFont(11, .medium)
                        }
                        .buttonStyle(LNButtonStyle(prominent: notch.macFunSection == section))
                        .accessibilityAddTraits(notch.macFunSection == section ? .isSelected : [])
                    }
                }
            }
            ScrollView {
                Group {
                    switch notch.macFunSection {
                    case .focus: PomodoroView()
                    case .daily: DailyView()
                    case .launch: QuickLaunchView()
                    case .notes: NotesAndClipboardView()
                    case .system: SystemView()
                    case .sounds: SoundsView()
                    case .style: StyleView()
                    }
                }
                .padding(.trailing, 6)
            }
        }
    }
}

// MARK: - Daily

struct DailyView: View {
    @EnvironmentObject private var notch: NotchState
    @State private var fun: RandomFunKind?
    @State private var showAnswer = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                SectionTitle("Today's quote")
                let quote = FunContent.quoteOfTheDay()
                Text("“\(quote.text)”").lnFont(14, .medium)
                if let author = quote.author { Text("— \(author)").lnFont(11).foregroundStyle(.secondary) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .card()

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle("F1 fact of the day")
                    Text(FunContent.f1FactOfTheDay()).lnFont(12)
                }
                .frame(maxWidth: .infinity, alignment: .leading).card()
                VStack(alignment: .leading, spacing: 4) {
                    SectionTitle("Football fact of the day")
                    Text(FunContent.footballFactOfTheDay()).lnFont(12)
                }
                .frame(maxWidth: .infinity, alignment: .leading).card()
            }
            Text("These are built into LifeNotch (not fetched live).").lnFont(10).foregroundStyle(.secondary)

            HStack {
                Button { fun = FunContent.randomFun(); showAnswer = false; SoundPlayer.play(.tap) } label: {
                    Label("Random Fun", systemImage: "dice")
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                Text("A quiz question, F1 fact, football fact, coding challenge or a mini-game.")
                    .lnFont(10.5).foregroundStyle(.secondary)
            }
            if let fun = fun { funCard(fun) }
        }
    }

    @ViewBuilder
    private func funCard(_ fun: RandomFunKind) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(fun.title)
            switch fun {
            case .quiz(let q):
                Text(q.question).lnFont(13, .semibold)
                if showAnswer {
                    Text("Answer: \(q.answer)").lnFont(13).foregroundStyle(.green)
                } else {
                    Button("Show answer") { showAnswer = true }.buttonStyle(LNButtonStyle())
                }
            case .f1Fact(let text), .footballFact(let text), .codingChallenge(let text):
                Text(text).lnFont(13)
            case .miniGame(let game):
                Label(game.title, systemImage: game.icon).lnFont(13, .semibold)
                Text(game.blurb).lnFont(11).foregroundStyle(.secondary)
                Button("Play it") { notch.pendingGame = game; notch.selectedTab = .games }
                    .buttonStyle(LNButtonStyle(prominent: true))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

// MARK: - Quick launch

struct QuickLaunchView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var notch: NotchState
    @State private var siteName = ""
    @State private var siteURL = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Quick launch")
            if settings.prefs.quickLaunch.isEmpty {
                Text("Add favourite apps and websites. Buttons open them with one click.")
                    .lnFont(11).foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                ForEach(settings.prefs.quickLaunch) { item in
                    Button { launch(item) } label: {
                        HStack {
                            if item.kind == .app {
                                Image(nsImage: NSWorkspace.shared.icon(forFile: item.target)).resizable().frame(width: 22, height: 22)
                            } else {
                                Image(systemName: "globe").frame(width: 22)
                            }
                            Text(item.title).lnFont(12, .medium).lineLimit(1)
                            Spacer()
                        }
                        .card(padding: 8)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if item.kind == .website {
                            Button("Open in default browser") { if let url = URL(string: item.target) { NSWorkspace.shared.open(url) } }
                        }
                        Button("Remove", role: .destructive) {
                            settings.prefs.quickLaunch.removeAll { $0.id == item.id }
                        }
                    }
                    .accessibilityLabel("Open \(item.title)")
                }
            }
            HStack {
                Button { addApp() } label: { Label("Add an app…", systemImage: "plus.app") }
                    .buttonStyle(LNButtonStyle())
                TextField("Site name", text: $siteName).textFieldStyle(.roundedBorder).frame(width: 120)
                TextField("https://…", text: $siteURL).textFieldStyle(.roundedBorder).frame(width: 180)
                Button("Add site") { addSite() }.buttonStyle(LNButtonStyle(prominent: true)).disabled(siteURL.isEmpty)
            }
            Text("Websites open in the notch browser (right-click for your default browser). Apps open normally. LifeNotch only launches what you add here.")
                .lnFont(10).foregroundStyle(.secondary)
        }
    }

    private func launch(_ item: QuickLaunchItem) {
        switch item.kind {
        case .app:
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: item.target),
                                               configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        case .website:
            if let url = URL(string: item.target) {
                browser.open(url)
                notch.selectedTab = .browser
            }
        }
    }

    private func addApp() {
        ModalHelper.bringToFront()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = false
        panel.message = "Choose an app to add to Quick Launch."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        settings.prefs.quickLaunch.append(QuickLaunchItem(kind: .app, title: name, target: url.path))
    }

    private func addSite() {
        var address = siteURL.trimmingCharacters(in: .whitespaces)
        if !address.lowercased().hasPrefix("http") { address = "https://" + address }
        guard let url = URL(string: address), url.host != nil else { return }
        let name = siteName.trimmingCharacters(in: .whitespaces)
        settings.prefs.quickLaunch.append(QuickLaunchItem(kind: .website, title: name.isEmpty ? (url.host ?? address) : name, target: address))
        siteName = ""
        siteURL = ""
    }
}

// MARK: - Notes and clipboard

struct NotesAndClipboardView: View {
    @EnvironmentObject private var notes: NotesStore
    @EnvironmentObject private var clipboard: ClipboardMonitor
    @EnvironmentObject private var settings: AppSettings
    @State private var draftTitle = ""
    @State private var draftBody = ""

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            notesColumn
            clipboardColumn
        }
    }

    private var notesColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Quick notes (stored on this Mac)")
            TextField("Title", text: $draftTitle).textFieldStyle(.roundedBorder)
            TextEditor(text: $draftBody)
                .font(.system(size: 12))
                .frame(height: 60)
                .padding(4)
                .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.08)))
                .accessibilityLabel("Note text")
            Button("Save note") {
                guard !draftBody.isEmpty || !draftTitle.isEmpty else { return }
                notes.add(title: draftTitle.isEmpty ? String(draftBody.prefix(30)) : draftTitle, body: draftBody, source: "Quick note")
                draftTitle = ""; draftBody = ""
            }
            .buttonStyle(LNButtonStyle(prominent: true))
            ForEach(notes.notes.prefix(30)) { note in
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(note.title).lnFont(12, .semibold).lineLimit(1)
                        Spacer()
                        Text(note.source).lnFont(9.5).foregroundStyle(.secondary)
                        ShareLink(item: note.body.isEmpty ? note.title : note.body) { Image(systemName: "square.and.arrow.up") }
                            .buttonStyle(.plain).accessibilityLabel("Share note")
                        Button { notes.delete(note) } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain).accessibilityLabel("Delete note")
                    }
                    Text(note.body).lnFont(11).foregroundStyle(.secondary).lineLimit(3)
                }
                .card(padding: 8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var clipboardColumn: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Clipboard history (optional)")
            Toggle("Keep a list of text I copy", isOn: Binding(
                get: { settings.prefs.clipboardHistoryEnabled },
                set: { newValue in
                    if newValue {
                        let ok = ModalHelper.confirm(
                            title: "Turn on clipboard history?",
                            message: "LifeNotch will remember TEXT you copy (up to 25 items) so you can copy it again. It ignores items that password managers mark as secret, keeps the list in memory only (unless you tick \"Keep after quitting\"), and never sends it anywhere. You can pause and clear it any time.",
                            confirmTitle: "Turn on")
                        settings.prefs.clipboardHistoryEnabled = ok
                    } else {
                        settings.prefs.clipboardHistoryEnabled = false
                    }
                }
            ))
            Toggle("Keep the list after quitting", isOn: Binding(
                get: { settings.prefs.clipboardKeepAfterQuit },
                set: { settings.prefs.clipboardKeepAfterQuit = $0; clipboard.persistIfNeeded() }
            ))
            .disabled(!settings.prefs.clipboardHistoryEnabled)
            if settings.prefs.clipboardHistoryEnabled {
                Button("Clear list") { clipboard.clear() }.buttonStyle(LNButtonStyle(destructive: true))
                if clipboard.items.isEmpty { Text("Copy some text and it will appear here.").lnFont(11).foregroundStyle(.secondary) }
                ForEach(clipboard.items.prefix(12)) { item in
                    HStack {
                        Text(item.text).lnFont(11).lineLimit(2)
                        Spacer()
                        Button { clipboard.copyAgain(item) } label: { Image(systemName: "doc.on.doc") }
                            .buttonStyle(.plain).accessibilityLabel("Copy again")
                        Button { clipboard.remove(item) } label: { Image(systemName: "xmark") }
                            .buttonStyle(.plain).accessibilityLabel("Remove from list")
                    }
                    .card(padding: 7)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

// MARK: - System dashboard + Clean Desk

struct SystemView: View {
    @EnvironmentObject private var stats: SystemStatsModel
    @EnvironmentObject private var clean: CleanDeskModel
    @EnvironmentObject private var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            dashboard
            cleanDesk
        }
        .onAppear { stats.startFullRefresh() }
        .onDisappear { stats.stopFullRefresh() }
    }

    private func meter(_ title: String, icon: String, value: Double, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: icon).lnFont(11, .semibold)
            ProgressView(value: min(max(value, 0), 1))
            Text(detail).lnFont(10.5).foregroundStyle(.secondary).monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .accessibilityElement(children: .combine)
    }

    private var dashboard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("System dashboard (read from macOS, always live)")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
                if let percent = stats.batteryPercent {
                    meter("Battery", icon: stats.isCharging ? "battery.100.bolt" : "battery.75",
                          value: Double(percent) / 100,
                          detail: "\(percent)% · \(stats.isCharging ? "charging" : (stats.onACPower ? "on power" : "on battery"))")
                } else {
                    meter("Battery", icon: "powerplug", value: 1, detail: "No battery (plugged-in Mac)")
                }
                meter("Wi-Fi", icon: stats.wifiConnected ? "wifi" : "wifi.slash",
                      value: stats.wifiConnected ? 1 : 0, detail: stats.networkDescription)
                meter("Storage", icon: "internaldrive",
                      value: stats.storageTotalGB > 0 ? 1 - stats.storageFreeGB / stats.storageTotalGB : 0,
                      detail: String(format: "%.0f GB free of %.0f GB", stats.storageFreeGB, stats.storageTotalGB))
                meter("CPU", icon: "cpu", value: stats.cpuUsage,
                      detail: String(format: "%.0f%% in use", stats.cpuUsage * 100))
                meter("Memory", icon: "memorychip",
                      value: stats.memoryTotalGB > 0 ? stats.memoryUsedGB / stats.memoryTotalGB : 0,
                      detail: String(format: "%.1f GB of %.0f GB used", stats.memoryUsedGB, stats.memoryTotalGB))
            }
        }
    }

    private var cleanDesk: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle("Clean Desk checklist")
            Text("LifeNotch only SUGGESTS. It never deletes, moves or renames anything.").lnFont(10.5).foregroundStyle(.secondary)
            ForEach(CleanDeskModel.checklist) { item in
                Toggle(item.text, isOn: Binding(
                    get: { settings.prefs.cleanDeskChecked.contains(item.id) },
                    set: { checked in
                        settings.prefs.cleanDeskChecked.removeAll { $0 == item.id }
                        if checked { settings.prefs.cleanDeskChecked.append(item.id) }
                    }
                ))
                .lnFont(11.5)
            }
            HStack {
                ForEach(CleanDeskModel.Folder.allCases) { folder in
                    Button("Scan \(folder.rawValue)…") { clean.scan(folder, settings: settings) }
                        .buttonStyle(LNButtonStyle())
                }
                Button("Reset checklist") { settings.prefs.cleanDeskChecked = [] }.buttonStyle(LNButtonStyle())
            }
            if let message = clean.message { Text(message).lnFont(10.5).foregroundStyle(.orange) }
            ForEach(CleanDeskModel.Folder.allCases) { folder in
                if let report = clean.reports[folder.rawValue] {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(report.folderName).lnFont(12, .bold)
                            Text("\(report.itemCount) items · \(report.oldCount) older than 30 days · \(ByteCountFormatter.string(fromByteCount: report.totalBytes, countStyle: .file))")
                                .lnFont(10.5).foregroundStyle(.secondary)
                            Spacer()
                            Button("Open folder") { clean.openFolder(report) }.buttonStyle(LNButtonStyle())
                        }
                        ForEach(report.oldest) { file in
                            HStack {
                                Text(file.name).lnFont(11).lineLimit(1)
                                Spacer()
                                Text("\(file.ageDays) days old · \(ByteCountFormatter.string(fromByteCount: file.bytes, countStyle: .file))")
                                    .lnFont(10).foregroundStyle(.secondary)
                                Button("Show in Finder") { clean.reveal(file) }
                                    .buttonStyle(.plain).lnFont(10).foregroundStyle(settings.prefs.theme.accent)
                            }
                        }
                    }
                    .card(padding: 8)
                }
            }
        }
        .card()
    }
}

// MARK: - Sounds

struct SoundsView: View {
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var ambient: AmbientPlayer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Sound effects")
                Toggle("Mute ALL LifeNotch sounds", isOn: $settings.prefs.soundMuted)
                Toggle("Sounds for finishing assignments, focus sessions and winning games", isOn: $settings.prefs.completionSounds)
                Button("Test sound") { SoundPlayer.play(.win) }.buttonStyle(LNButtonStyle())
            }
            .card()

            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("Ambient sounds")
                HStack {
                    ForEach(AmbientSound.allCases) { sound in
                        Button { ambient.toggle(sound) } label: {
                            Label(sound.title, systemImage: sound.icon)
                        }
                        .buttonStyle(LNButtonStyle(prominent: ambient.current == sound))
                        .accessibilityAddTraits(ambient.current == sound ? .isSelected : [])
                    }
                    if ambient.current != nil {
                        Button("Stop") { ambient.stop() }.buttonStyle(LNButtonStyle(destructive: true))
                    }
                }
                HStack {
                    Image(systemName: "speaker.fill")
                    Slider(value: $ambient.volume, in: 0...1).frame(maxWidth: 220).accessibilityLabel("Ambient volume")
                    Image(systemName: "speaker.wave.3.fill")
                }
                Text("These sounds are generated by LifeNotch (no audio files), so they are simple impressions of rain, a café and racing rather than recordings. They only play sound; the microphone is never used.")
                    .lnFont(10).foregroundStyle(.secondary)
            }
            .card()
        }
    }
}

// MARK: - Style

struct StyleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Notch theme")
                ThemePicker()
            }
            .card()
            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Notch animation")
                AnimationPicker()
                Text("The animation shows in the compact bar. It stays still if Reduce Motion is on.")
                    .lnFont(10).foregroundStyle(.secondary)
            }
            .card()
        }
    }
}
