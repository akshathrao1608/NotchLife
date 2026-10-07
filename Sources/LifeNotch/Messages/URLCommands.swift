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
//   lifenotch://open?tab=ai|browser|messages|assignments|sports|games|macFun|settings
//        just opens that tab.

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

        case "open":
            if let name = value("tab"), let tab = NotchTab(rawValue: name) { env.notch.open(tab) }

        default:
            break
        }
    }
}
