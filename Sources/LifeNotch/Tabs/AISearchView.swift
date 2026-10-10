import SwiftUI
import UniformTypeIdentifiers

// AISearchView.swift
// The AI Search tab: pick a mode, type a question, read the answer.

struct AISearchView: View {
    @EnvironmentObject private var vm: AIViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var notch: NotchState
    @EnvironmentObject private var capture: ScreenCaptureCoordinator
    @FocusState private var inputFocused: Bool
    @State private var isDropTargeted = false

    var body: some View {
        VStack(spacing: 8) {
            modeBar
            if !vm.hasKey { keyBanner }
            conversation
            if let notice = vm.notice {
                Label(notice, systemImage: "info.circle")
                    .lnFont(10.5)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            inputBar
        }
        .onAppear { inputFocused = true }
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(settings.prefs.theme.accent, style: StrokeStyle(lineWidth: 2, dash: [6]))
                .opacity(isDropTargeted ? 1 : 0)
                .allowsHitTesting(false)
        )
        // Drag files (screenshots, images, PDFs, text files) onto the panel.
        .dropDestination(for: URL.self) { urls, _ in
            let files = urls.filter { $0.isFileURL }
            let links = urls.filter { !$0.isFileURL }
            if !files.isEmpty { vm.addFiles(files) }
            for link in links { vm.input += (vm.input.isEmpty ? "" : "\n") + link.absoluteString }
            return !urls.isEmpty
        } isTargeted: { isDropTargeted = $0 }
        // Drag selected text onto the panel.
        .dropDestination(for: String.self) { strings, _ in
            vm.input += (vm.input.isEmpty ? "" : "\n") + strings.joined(separator: "\n")
            return !strings.isEmpty
        }
    }

    // MARK: Attachments

    private var attachmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(vm.attachments) { attachment in
                    HStack(spacing: 5) {
                        if attachment.kind == .image, let image = NSImage(data: attachment.data) {
                            Image(nsImage: image).resizable().scaledToFill()
                                .frame(width: 22, height: 22).clipShape(RoundedRectangle(cornerRadius: 4))
                                .accessibilityHidden(true)
                        } else {
                            Image(systemName: attachment.icon)
                        }
                        Text(attachment.name).lnFont(11).lineLimit(1).frame(maxWidth: 140)
                        Button {
                            Task { await vm.extractTextLocally(from: attachment) }
                        } label: { Image(systemName: "text.viewfinder") }
                            .buttonStyle(.plain)
                            .help("Read the text on your Mac (nothing is sent)")
                            .accessibilityLabel("Extract text from \(attachment.name) on this Mac")
                        Button { vm.remove(attachment) } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Remove \(attachment.name)")
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color.primary.opacity(0.1)))
                }
            }
        }
    }

    private func pickFiles() {
        ModalHelper.bringToFront()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.message = "Choose images, PDFs or text files to attach. Nothing is sent until you press Send."
        panel.allowedContentTypes = [.image, .pdf, .text, .json, .commaSeparatedText]
        if panel.runModal() == .OK { vm.addFiles(panel.urls) }
    }

    private func pasteFromClipboard() {
        let allowed = ConsentGate.request(
            .readClipboard,
            settings: settings,
            explanation: "LifeNotch will look at your clipboard ONCE, right now, to attach what is on it to your question. It never watches the clipboard in the background."
        )
        guard allowed else { return }
        let board = NSPasteboard.general
        if let urls = board.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL], !urls.isEmpty {
            vm.addFiles(urls)
        } else if let data = board.data(forType: .png) ?? board.data(forType: .tiff) {
            vm.addImageData(data, name: "Pasted image.png")
        } else if let text = board.string(forType: .string), !text.isEmpty {
            vm.input += (vm.input.isEmpty ? "" : "\n") + text
        } else {
            vm.notice = "The clipboard has nothing LifeNotch can attach."
        }
    }

    // MARK: Modes

    private var modeBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(AIMode.allCases) { mode in
                    Button { vm.mode = mode } label: {
                        Label(mode.title, systemImage: mode.icon).lnFont(11, .medium)
                    }
                    .buttonStyle(LNButtonStyle(prominent: vm.mode == mode))
                    .accessibilityAddTraits(vm.mode == mode ? .isSelected : [])
                }
            }
        }
    }

    private var keyBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "key.fill").foregroundStyle(.orange)
            Text("AI needs your own API key (optional). It is stored in the macOS Keychain.")
                .lnFont(11)
            Spacer()
            Button("Add key") { notch.open(.settings) }
                .buttonStyle(LNButtonStyle(prominent: true))
        }
        .card(padding: 8)
    }

    // MARK: Conversation

    private var conversation: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if vm.messages.isEmpty {
                    introView
                } else {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.messages) { message in
                            ChatBubble(message: message).id(message.id)
                        }
                        if vm.isLoading {
                            HStack(spacing: 6) {
                                ProgressView().controlSize(.small)
                                Text("Thinking…").lnFont(11).foregroundStyle(.secondary)
                            }
                            .id("loading")
                        }
                    }
                    .padding(.trailing, 6)
                }
            }
            .onChange(of: vm.messages.count) { _ in
                if let last = vm.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .top) } }
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var introView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Ask a question, paste a school problem, or drop in a screenshot or PDF.")
                .lnFont(12, .medium)
            Text("""
                 • Answers start short, then explain. Homework mode teaches the method first.
                 • Facts are split into "Verified" and "Not verified". The AI is told to say when it can't check something.
                 • Turn on the globe to let the AI search the web; sources appear as links.
                 • Nothing is sent until you press Send.
                 """)
                .lnFont(11)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 4)
    }

    // MARK: Input

    private var inputBar: some View {
        VStack(spacing: 6) {
            if !vm.attachments.isEmpty { attachmentRow }
            HStack(spacing: 8) {
                if vm.mode == .homework {
                    Toggle(isOn: $vm.showFullSolution) {
                        Text("Show full solution").lnFont(11)
                    }
                    .toggleStyle(.checkbox)
                    .help("Off: the AI teaches the method and leaves the last step to you.")
                }
                if vm.mode == .translate {
                    TextField("Translate to…", text: $settings.prefs.aiTranslateTarget)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 130)
                        .accessibilityLabel("Target language")
                }
                Spacer()
                LNIconButton(systemName: "paperclip", label: "Attach an image, PDF or text file") { pickFiles() }
                LNIconButton(systemName: "viewfinder", label: "Capture part of the screen (asks first)") { Task { await capture.askAI() } }
                    .help("Drag a box around part of your screen. It is added here; nothing is sent until you press Send. Shortcut: Control + Option + S")
                LNIconButton(systemName: "doc.on.clipboard", label: "Paste from clipboard (asks first)") { pasteFromClipboard() }
                    .help("Tip: press Command-Control-Shift-4 to copy a screenshot area, then press this button.")
                LNIconButton(systemName: "globe", label: "Search the web for sources", isActive: vm.useWebSearch || vm.mode == .findSources) {
                    vm.useWebSearch.toggle()
                }
                LNIconButton(systemName: "arrow.counterclockwise", label: "Start a new chat") {
                    vm.newChat()
                }
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField(vm.mode.placeholder, text: $vm.input, axis: .vertical)
                    .lineLimit(1...4)
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.1)))
                    .focused($inputFocused)
                    .onSubmit { vm.startSend() }
                    .accessibilityLabel("Question for the AI")

                if vm.isLoading {
                    LNIconButton(systemName: "stop.fill", label: "Stop") { vm.cancel() }
                } else {
                    Button { vm.startSend() } label: {
                        Image(systemName: "arrow.up.circle.fill").font(.system(size: 24))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(settings.prefs.theme.accent)
                    .disabled(vm.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && vm.attachments.isEmpty)
                    .accessibilityLabel("Send question")
                    .help("Send (Return)")
                }
            }
        }
    }
}

// MARK: - One message

struct ChatBubble: View {
    let message: ChatMessage
    @EnvironmentObject private var notes: NotesStore
    @EnvironmentObject private var assignments: AssignmentStore

    var body: some View {
        switch message.role {
        case .user: userBubble
        case .assistant: assistantBubble
        case .error: errorBubble
        }
    }

    private var userBubble: some View {
        VStack(alignment: .trailing, spacing: 3) {
            Text(message.text)
                .lnFont(12)
                .textSelection(.enabled)
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.accentColor.opacity(0.35)))
            if !message.attachmentNames.isEmpty {
                Label(message.attachmentNames.joined(separator: ", "), systemImage: "paperclip")
                    .lnFont(10).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private var errorBubble: some View {
        Label(message.text, systemImage: "exclamationmark.triangle.fill")
            .lnFont(11)
            .foregroundStyle(.orange)
            .card(padding: 8)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var assistantBubble: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                AIBadge()
                if !message.modeTitle.isEmpty {
                    Text(message.modeTitle).lnFont(10).foregroundStyle(.secondary)
                }
            }
            Text(Self.markdown(message.text))
                .lnFont(12)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)

            if !message.sources.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    SectionTitle("Sources")
                    ForEach(message.sources) { source in
                        Link(destination: source.url) {
                            Label(source.title, systemImage: "link").lnFont(11).lineLimit(1)
                        }
                        .help(source.url.absoluteString)
                    }
                }
            }

            HStack(spacing: 6) {
                Button { Self.copy(message.text) } label: { Label("Copy", systemImage: "doc.on.doc") }
                    .buttonStyle(LNButtonStyle())
                Button {
                    notes.add(title: String(message.text.prefix(40)), body: message.text, source: "AI answer")
                    SoundPlayer.play(.success)
                } label: { Label("Save to notes", systemImage: "note.text.badge.plus") }
                    .buttonStyle(LNButtonStyle())
                Menu {
                    if assignments.upcoming.isEmpty {
                        Text("No assignments yet")
                    }
                    ForEach(assignments.upcoming) { assignment in
                        Button("\(assignment.subject.isEmpty ? "" : assignment.subject + ": ")\(assignment.title)") {
                            assignments.appendNote(message.text, to: assignment.id)
                            SoundPlayer.play(.success)
                        }
                    }
                } label: {
                    Label("Add to assignment", systemImage: "checklist")
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                ShareLink(item: message.text) {
                    Label("Share / Apple Notes", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(LNButtonStyle())
            }
            .lnFont(11)
        }
        .card()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    static func markdown(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }

    static func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
