import AppIntents
import Foundation

// AppIntents.swift
// "Actions" that appear in the macOS Shortcuts app so YOU can connect things together.
//
// NOTE: Shortcuts only discovers App Intents when the app is built with Xcode (it extracts the
// intents at build time). If you build with Scripts/build_app.sh the app still works, but these
// actions won't be listed: use the lifenotch:// links instead (see README).

extension NotchTab: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "LifeNotch tab"
    static let caseDisplayRepresentations: [NotchTab: DisplayRepresentation] = [
        .ai: "AI Search", .browser: "Browser", .messages: "Messages", .assignments: "Assignments",
        .sports: "Sports", .games: "Mini Games", .macFun: "Mac Fun", .settings: "Settings",
        .home: "Home", .clipboard: "Clipboard", .todo: "To-Do", .timer: "Timer", .world: "World Clock",
        .tools: "Tools", .shelf: "File Shelf", .search: "File Search", .snippets: "Snippets",
        .shortcuts: "Shortcuts", .translate: "Translate", .nowPlaying: "Now Playing", .windows: "Windows",
        .quickAdd: "Quick Add", .voice: "Voice Notes", .convert: "Convert", .flights: "Flight Radar"
    ]
}

struct OpenLifeNotchTabIntent: AppIntent {
    static let title: LocalizedStringResource = "Open a LifeNotch Tab"
    static let description = IntentDescription("Opens the notch on the tab you pick.")

    @Parameter(title: "Tab") var tab: NotchTab

    func perform() async throws -> some IntentResult {
        await MainActor.run { AppEnvironment.shared.notch.open(tab) }
        return .result()
    }
}

struct StartFocusTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start LifeNotch Focus Timer"
    static let description = IntentDescription("Starts the Pomodoro focus timer using your chosen lengths.")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            let timer = AppEnvironment.shared.pomodoro
            if !timer.isRunning { timer.start() }
        }
        return .result()
    }
}

struct AddAssignmentIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a LifeNotch Assignment"
    static let description = IntentDescription("Adds an assignment to LifeNotch (stored only on this Mac).")

    @Parameter(title: "Subject") var subject: String
    @Parameter(title: "Title") var assignmentTitle: String
    @Parameter(title: "Due date") var due: Date

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            var assignment = Assignment()
            assignment.subject = subject
            assignment.title = assignmentTitle
            assignment.due = due
            AppEnvironment.shared.assignments.add(assignment)
        }
        return .result()
    }
}

struct AddMessageNoticeIntent: AppIntent {
    static let title: LocalizedStringResource = "Add a Message Notice to LifeNotch"
    static let description = IntentDescription("Adds a notice to LifeNotch's Messages hub. LifeNotch never reads your messages: it only shows what your Shortcut passes in. Ignored unless you turned the Messages hub on.")

    @Parameter(title: "App name") var source: String
    @Parameter(title: "Sender") var sender: String
    @Parameter(title: "Preview (optional)") var preview: String?

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            AppEnvironment.shared.messages.addNotice(source: source, sender: sender, preview: preview)
        }
        return .result()
    }
}
