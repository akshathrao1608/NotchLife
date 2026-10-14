import Foundation

// URLCommands.swift
// What happens when something opens a link that starts with lifenotch://
// Links can come from a web page, so every command is checked:
//
//   lifenotch://notice?token=…&source=…&from=…&preview=…
//        adds a message notice. Needs the Messages hub switched on AND your private token.
//   lifenotch://ask?text=…&title=…&url=…
//        pre-fills the AI tab (used by the optional Safari extension). Needs "Allow the Safari
//        extension" in Settings > Privacy. It NEVER sends anything: you still press Send.
//   lifenotch://open?tab=ai|browser|messages|assignments|sports|games|macFun|settings|... (any tab id)
//        just opens that tab.
//   lifenotch://activity?id=…&title=…&progress=0.4&symbol=…&detail=…   (or action=end)
//   lifenotch://timer?minutes=10      lifenotch://todo?title=Buy%20milk
//        scripting links. They only show or add harmless local items and can be switched off in
//        Live Activities > "Allow links and Shortcuts to start activities".

enum URLCommands {
    static func handle(_ url: URL, env: AppEnvironment) {
        guard url.scheme?.lowercased() == "lifenotch", let host = url.host?.lowercased() else { return }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> String? { items.first { $0.name == name }?.value }

        switch host {
        case "notice":
            guard env.messages.isEnabled, let token = value("token"), token == env.messages.token else { return }
            env.messages.addNotice(source: value("source") ?? "Messages",
                                   sender: value("from") ?? "",
                                   preview: value("preview"))

        case "ask":
            guard env.settings.prefs.allowSafariExtension else { return }
            var text = ""
            if let title = value("title"), !title.isEmpty { text += "About this web page: \(String(title.prefix(200)))\n" }
            if let page = value("url"), !page.isEmpty { text += "\(String(page.prefix(500)))\n\n" }
            if let selection = value("text"), !selection.isEmpty {
                text += "Selected text:\n\(String(selection.prefix(8000)))\n\nExplain this simply."
            }
            env.ai.prefill(text: text, mode: .explainSimply)
            env.notch.open(.ai)

        case "activity":
            guard env.settings.prefs.allowScriptLinks, let id = value("id"), !id.isEmpty else { return }
            if value("action") == "end" { env.activities.end(id: id); return }
            env.activities.upsert(id: id, title: value("title") ?? id, symbol: value("symbol") ?? "bolt.fill",
                                  progress: value("progress").flatMap(Double.init), detail: value("detail") ?? "")

        case "timer":
            guard env.settings.prefs.allowScriptLinks, let minutes = value("minutes").flatMap(Double.init), minutes > 0, minutes <= 600 else { return }
            env.toolTimer.startCountdown(seconds: minutes * 60)

        case "todo":
            guard env.settings.prefs.allowScriptLinks, let title = value("title"), !title.isEmpty else { return }
            env.todos.add(String(title.prefix(200)))

        case "open":
            if let name = value("tab"), let tab = NotchTab(rawValue: name) { env.notch.open(tab) }

        default:
            break
        }
    }
}
