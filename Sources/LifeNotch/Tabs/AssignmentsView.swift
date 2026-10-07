import SwiftUI
import UniformTypeIdentifiers

// AssignmentsView.swift
// The Assignments tab: your list (soonest first), a red warning when something is due within
// 24 hours, a simple editor, and buttons that pre-fill a question for the AI tab.

/// The AI helpers. Each one only PRE-FILLS the AI tab; you press Send yourself.
enum AssignmentAIHelp: String, CaseIterable, Identifiable {
    case steps, explain, revision, practice, checkDraft
    var id: String { rawValue }

    var title: String {
        switch self {
        case .steps: return "Break into smaller steps"
        case .explain: return "Explain the topic"
        case .revision: return "Make a revision plan"
        case .practice: return "Create practice questions"
        case .checkDraft: return "Check my draft"
        }
    }

    var icon: String {
        switch self {
        case .steps: return "list.number"
        case .explain: return "lightbulb"
        case .revision: return "calendar"
        case .practice: return "questionmark.circle"
        case .checkDraft: return "checkmark.seal"
        }
    }

    func prompt(for a: Assignment) -> (text: String, mode: AIMode) {
        let context = "Subject: \(a.subject.isEmpty ? "not set" : a.subject)\nAssignment: \(a.title)\nDue: \(a.due.formatted(date: .abbreviated, time: .shortened))"
            + (a.notes.isEmpty ? "" : "\nMy notes: \(a.notes)")
        switch self {
        case .steps:
            return ("\(context)\n\nBreak this assignment into small, ordered steps I can tick off. Estimate the time for each step and fit them before the due date.", .explainSimply)
        case .explain:
            return ("\(context)\n\nExplain the main topic I need to understand for this assignment, simply, with an example.", .explainSimply)
        case .revision:
            return ("\(context)\n\nMake a day-by-day revision plan from today until the due date, with short study blocks and breaks.", .explainSimply)
        case .practice:
            return ("\(context)\n\nCreate 8 practice questions of increasing difficulty on this topic. Do NOT give the answers until I ask.", .explainSimply)
        case .checkDraft:
            return ("\(context)\n\nHere is my draft:\n\n[paste your draft here]\n\nMy answer: (the draft above). Tell me what is good and what to improve, without rewriting it for me.", .checkAnswer)
        }
    }
}

struct AssignmentsView: View {
    @EnvironmentObject private var store: AssignmentStore
    @EnvironmentObject private var ai: AIViewModel
    @EnvironmentObject private var notch: NotchState

    @State private var editing: Assignment?
    @State private var showCompleted = false

    var body: some View {
        Group {
            if editing != nil {
                AssignmentEditor(draft: Binding(get: { editing ?? Assignment() }, set: { editing = $0 }),
                                 isNew: store.items.first(where: { $0.id == editing?.id }) == nil,
                                 onClose: { editing = nil })
            } else {
                listView
            }
        }
        .onAppear(perform: takePendingDraft)
        .onChange(of: store.pendingDraft) { _ in takePendingDraft() }
    }

    private func takePendingDraft() {
        if let draft = store.pendingDraft {
            editing = draft
            store.pendingDraft = nil
        }
    }

    // MARK: List

    private var listView: some View {
        VStack(spacing: 8) {
            HStack {
                let urgent = store.urgentCount()
                Text("\(store.upcoming.count) to do")
                    .lnFont(12, .medium)
                if urgent > 0 {
                    Label("\(urgent) due within 24 hours", systemImage: "exclamationmark.triangle.fill")
                        .lnFont(11, .semibold)
                        .foregroundStyle(.red)
                }
                Spacer()
                Toggle("Show completed", isOn: $showCompleted).toggleStyle(.checkbox).lnFont(11)
                Button { editing = Assignment() } label: { Label("Add", systemImage: "plus") }
                    .buttonStyle(LNButtonStyle(prominent: true))
                    .keyboardShortcut("n", modifiers: .command)
            }

            ScrollView {
                LazyVStack(spacing: 6) {
                    if store.upcoming.isEmpty && !showCompleted {
                        EmptyStateView(icon: "checkmark.circle", title: "All clear",
                                       message: "Add an assignment to see it here and in the notch bar.")
                            .frame(height: 160)
                    }
                    ForEach(store.upcoming) { row($0) }
                    if showCompleted {
                        ForEach(store.completed) { row($0) }
                    }
                }
                .padding(.trailing, 6)
            }
        }
    }

    private func row(_ a: Assignment) -> some View {
        let urgent = a.isUrgent()
        return HStack(spacing: 8) {
            Button { store.toggleComplete(a) } label: {
                Image(systemName: a.isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(a.isCompleted ? Color.green : Color.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(a.isCompleted ? "Mark \(a.title) as not done" : "Mark \(a.title) as complete")

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if !a.subject.isEmpty { Text(a.subject).lnFont(10.5, .bold).foregroundStyle(a.priority.color) }
                    Text(a.priority.title).lnFont(9.5).foregroundStyle(.secondary)
                    if a.status == .inProgress { Text("In progress").lnFont(9.5).foregroundStyle(.blue) }
                }
                Text(a.title.isEmpty ? "Untitled" : a.title)
                    .lnFont(12.5, .medium)
                    .strikethrough(a.isCompleted)
                    .lineLimit(1)
            }
            Spacer()

            if urgent {
                Label(a.isOverdue() ? "Overdue" : "Due in \(Countdown.short(to: a.due))",
                      systemImage: "exclamationmark.triangle.fill")
                    .lnFont(10.5, .bold)
                    .foregroundStyle(.red)
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.18)))
            } else {
                Text(a.due.formatted(date: .abbreviated, time: .shortened))
                    .lnFont(10.5).foregroundStyle(.secondary)
            }

            Menu {
                ForEach(AssignmentAIHelp.allCases) { help in
                    Button { askAI(help, a) } label: { Label(help.title, systemImage: help.icon) }
                }
            } label: { Image(systemName: "sparkles") }
                .menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 24)
                .accessibilityLabel("Ask AI to help with \(a.title)")
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(urgent ? Color.red.opacity(0.12) : Color.primary.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .stroke(urgent ? Color.red.opacity(0.7) : Color.clear, lineWidth: 1))
        .contentShape(Rectangle())
        .onTapGesture { editing = a }
        .contextMenu {
            Button("Edit") { editing = a }
            Button(a.isCompleted ? "Mark not done" : "Mark complete") { store.toggleComplete(a) }
            Button("Delete", role: .destructive) { store.delete(a) }
        }
    }

    private func askAI(_ help: AssignmentAIHelp, _ a: Assignment) {
        let prompt = help.prompt(for: a)
        ai.prefill(text: prompt.text, mode: prompt.mode)
        notch.selectedTab = .ai
    }
}

// MARK: - Editor

struct AssignmentEditor: View {
    @Binding var draft: Assignment
    let isNew: Bool
    let onClose: () -> Void

    @EnvironmentObject private var store: AssignmentStore
    @EnvironmentObject private var ai: AIViewModel
    @EnvironmentObject private var notch: NotchState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Subject (e.g. Maths)", text: $draft.subject).textFieldStyle(.roundedBorder).frame(width: 190)
                    TextField("Title", text: $draft.title).textFieldStyle(.roundedBorder)
                }
                HStack {
                    DatePicker("Due", selection: $draft.due, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(.field)
                        .frame(maxWidth: 300)
                    Picker("Priority", selection: $draft.priority) {
                        ForEach(Priority.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.segmented).frame(maxWidth: 240)
                }
                Picker("Status", selection: $draft.status) {
                    ForEach(AssignmentStatus.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented).frame(maxWidth: 380)

                SectionTitle("Notes")
                TextEditor(text: $draft.notes)
                    .font(.system(size: 12))
                    .frame(height: 70)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.08)))
                    .accessibilityLabel("Notes")

                SectionTitle("Attachment or link")
                HStack {
                    TextField("https://… or a file on your Mac", text: $draft.attachment).textFieldStyle(.roundedBorder)
                    Button("Choose file…") {
                        if let url = FileDialogs.open(types: [.item], message: "Pick a file to link to this assignment. LifeNotch only remembers its location.") {
                            draft.attachment = url.path
                        }
                    }
                    .buttonStyle(LNButtonStyle())
                    Button("Open") { openAttachment() }
                        .buttonStyle(LNButtonStyle())
                        .disabled(draft.attachment.isEmpty)
                }

                if !isNew {
                    SectionTitle("Ask the AI (fills the AI tab; you press Send)")
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(AssignmentAIHelp.allCases) { help in
                                Button {
                                    let prompt = help.prompt(for: draft)
                                    ai.prefill(text: prompt.text, mode: prompt.mode)
                                    store.update(draft)
                                    onClose()
                                    notch.selectedTab = .ai
                                } label: { Label(help.title, systemImage: help.icon).lnFont(11) }
                                    .buttonStyle(LNButtonStyle())
                            }
                        }
                    }
                }

                HStack {
                    Button("Cancel") { onClose() }
                        .buttonStyle(LNButtonStyle())
                        .keyboardShortcut(.cancelAction)
                    if !isNew {
                        Button("Delete") { store.delete(draft); onClose() }
                            .buttonStyle(LNButtonStyle(destructive: true))
                    }
                    Spacer()
                    Button(isNew ? "Add assignment" : "Save") {
                        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty { draft.title = "Untitled" }
                        if isNew { store.add(draft) } else { store.update(draft) }
                        onClose()
                    }
                    .buttonStyle(LNButtonStyle(prominent: true))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(.trailing, 6)
        }
    }

    private func openAttachment() {
        let text = draft.attachment.trimmingCharacters(in: .whitespaces)
        if text.lowercased().hasPrefix("http"), let url = URL(string: text) {
            NSWorkspace.shared.open(url)
        } else if FileManager.default.fileExists(atPath: text) {
            NSWorkspace.shared.open(URL(fileURLWithPath: text))
        } else {
            ModalHelper.info(title: "Can't find that", message: "\"\(text)\" isn't a web address or a file that exists on this Mac.")
        }
    }
}

// MARK: - "Save to assignments" menu items (used by the browser)

struct SaveToAssignmentsMenuItems: View {
    @EnvironmentObject private var browser: BrowserModel
    @EnvironmentObject private var store: AssignmentStore
    @EnvironmentObject private var notch: NotchState

    var body: some View {
        Button("Add page as a new assignment") {
            Task {
                let selection = await browser.selectedText()
                var draft = Assignment()
                draft.title = browser.pageTitle
                draft.attachment = browser.currentURL?.absoluteString ?? ""
                draft.notes = selection
                store.pendingDraft = draft
                notch.selectedTab = .assignments
            }
        }
    }
}
