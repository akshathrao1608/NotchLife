import SwiftUI

// AISearchView.swift
// The AI Search tab: pick a mode, type a question, read the answer.

struct AISearchView: View {
    @EnvironmentObject private var vm: AIViewModel
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var notch: NotchState
    @FocusState private var inputFocused: Bool

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
