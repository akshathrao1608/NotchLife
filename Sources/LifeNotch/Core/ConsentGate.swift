import AppKit
import UserNotifications

// ConsentGate.swift
// "Ask first" for everything sensitive. Before LifeNotch does something that touches
// your data (send a file to the AI, read the clipboard, look in a folder...), it shows a
// plain-language question. You can answer "Allow once", "Always allow" or "Don't allow".
// "Always allow" answers can be taken back any time in Settings > Privacy.

enum ConsentTopic: String, CaseIterable, Identifiable {
    case sendAttachmentsToAI
    case readClipboard
    case scanFolders

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sendAttachmentsToAI: return "Send files and images to your AI provider"
        case .readClipboard: return "Read the clipboard when I press Paste"
        case .scanFolders: return "Look inside Desktop / Downloads when I press Scan"
        }
    }
}

enum ConsentGate {
    /// Returns true if you said yes (once or always).
    static func request(_ topic: ConsentTopic, settings: AppSettings, explanation: String) -> Bool {
        if settings.hasConsent(topic) { return true }
        ModalHelper.bringToFront()
        let alert = NSAlert()
        alert.messageText = topic.title + "?"
        alert.informativeText = explanation
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Allow once")
        alert.addButton(withTitle: "Always allow")
        alert.addButton(withTitle: "Don't allow")
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return true
        case .alertSecondButtonReturn:
            settings.grant(topic)
            return true
        default:
            return false
        }
    }
}

enum ModalHelper {
    /// Dialogs and file pickers need the app to be "active" to receive clicks properly.
    static func bringToFront() {
        NSApp.activate(ignoringOtherApps: true)
    }

    static func confirm(title: String, message: String, confirmTitle: String, destructive: Bool = false) -> Bool {
        bringToFront()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.alertStyle = destructive ? .warning : .informational
        // The SAFE choice is the first (default) button.
        alert.addButton(withTitle: "Cancel")
        let confirmButton = alert.addButton(withTitle: confirmTitle)
        if destructive { confirmButton.hasDestructiveAction = true }
        return alert.runModal() == .alertSecondButtonReturn
    }

    static func info(title: String, message: String) {
        bringToFront()
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

// MARK: - Notifications

/// Wraps macOS notifications. Permission is only requested when you switch on a feature
/// that needs it (assignment reminders, sports reminders, focus-timer alerts).
final class NotificationManager {
    static let shared = NotificationManager()

    /// Notifications only work from a real .app bundle (not from `swift run`).
    var isAvailable: Bool { Bundle.main.bundleURL.pathExtension == "app" }

    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard isAvailable else { completion(false); return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    func schedule(id: String, title: String, body: String, at date: Date) {
        guard isAvailable, date > Date() else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    func notifyNow(id: String, title: String, body: String) {
        guard isAvailable else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: id, content: content, trigger: nil))
    }

    /// Removes every pending notification whose id starts with the prefix.
    func cancel(prefix: String) {
        guard isAvailable else { return }
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.map { $0.identifier }.filter { $0.hasPrefix(prefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}
