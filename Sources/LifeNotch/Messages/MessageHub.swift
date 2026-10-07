import AppKit
import Security

// MessageHub.swift
// A SAFE message hub. What it is and is not:
//
//  - It does NOT read the Messages app, its database, or any other app's notifications.
//    macOS does not allow that without invasive permissions, and LifeNotch never asks for them.
//  - It only shows "notices" that YOU choose to send to it, from a Shortcut/automation you set up
//    (see AppIntents.swift) or a link carrying your private token (see URLCommands.swift).
//  - Notices are kept in memory unless you tick "Remember after quitting".
//  - If previews are off, the preview text is never even stored.

struct MessageNotice: Identifiable, Codable, Equatable {
    var id = UUID()
    var source: String          // e.g. "Messages", "WhatsApp"
    var sender: String
    var preview: String
    var receivedAt = Date()
    var isRead = false
}

struct MessageFavourite: Identifiable, Codable, Equatable {
    var id = UUID()
    var name: String
    /// A phone number or Apple ID email. Only used to open the conversation in Messages.
    var handle: String
    /// "Messages" opens the Messages app; any other name opens that app from /Applications.
    var appName: String
}

final class MessageHub: ObservableObject {
    @Published private(set) var notices: [MessageNotice] = []
    @Published var favourites: [MessageFavourite]

    private let settings: AppSettings
    private static let noticesFile = "message_notices.json"
    private static let favouritesFile = "message_favourites.json"
    private static let tokenAccount = "messages.link.token"

    init(settings: AppSettings) {
        self.settings = settings
        favourites = LocalStore.load([MessageFavourite].self, name: Self.favouritesFile) ?? []
        if settings.prefs.messagesRemember {
            notices = LocalStore.load([MessageNotice].self, name: Self.noticesFile) ?? []
        }
    }

    var isEnabled: Bool { settings.prefs.messagesEnabled }
    var unreadCount: Int { notices.filter { !$0.isRead }.count }
    var previewsVisible: Bool { settings.prefs.messagesShowPreviews && !settings.prefs.messagesDoNotDisturb }

    // MARK: Receiving notices

    /// Returns false if the hub is switched off (the notice is then ignored).
    @discardableResult
    func addNotice(source: String, sender: String, preview: String?) -> Bool {
        guard isEnabled else { return false }
        let cleanSource = String(source.trimmingCharacters(in: .whitespacesAndNewlines).prefix(40))
        let cleanSender = String(sender.trimmingCharacters(in: .whitespacesAndNewlines).prefix(60))
        let text = settings.prefs.messagesShowPreviews
            ? String((preview ?? "").trimmingCharacters(in: .whitespacesAndNewlines).prefix(140))
            : ""
        notices.insert(MessageNotice(source: cleanSource.isEmpty ? "Messages" : cleanSource,
                                     sender: cleanSender.isEmpty ? "Someone" : cleanSender,
                                     preview: text), at: 0)
        if notices.count > 50 { notices.removeLast(notices.count - 50) }
        persistIfNeeded()
        return true
    }

    func markRead(_ notice: MessageNotice) {
        guard let index = notices.firstIndex(where: { $0.id == notice.id }) else { return }
        notices[index].isRead = true
        persistIfNeeded()
    }

    func markAllRead() {
        for index in notices.indices { notices[index].isRead = true }
        persistIfNeeded()
    }

    func clearAll() {
        notices = []
        persistIfNeeded()
    }

    func persistIfNeeded() {
        if settings.prefs.messagesRemember {
            LocalStore.save(notices, name: Self.noticesFile)
        } else {
            LocalStore.remove(name: Self.noticesFile)
        }
    }

    /// Removes everything the hub stored (used by "Reset app data").
    func wipe() {
        notices = []
        favourites = []
        LocalStore.remove(name: Self.noticesFile)
        LocalStore.remove(name: Self.favouritesFile)
        KeychainStore.delete(account: Self.tokenAccount)
    }

    // MARK: Favourites

    func addFavourite(_ favourite: MessageFavourite) {
        favourites.append(favourite)
        LocalStore.save(favourites, name: Self.favouritesFile)
    }

    func removeFavourite(_ favourite: MessageFavourite) {
        favourites.removeAll { $0.id == favourite.id }
        LocalStore.save(favourites, name: Self.favouritesFile)
    }

    // MARK: Opening the real apps

    func openMessagesApp() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.MobileSMS") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        }
    }

    func open(_ favourite: MessageFavourite) {
        let app = favourite.appName.trimmingCharacters(in: .whitespaces)
        if app.isEmpty || app.lowercased() == "messages" {
            let handle = favourite.handle.trimmingCharacters(in: .whitespaces)
            if !handle.isEmpty,
               let encoded = handle.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed),
               let url = URL(string: "imessage://\(encoded)") {
                NSWorkspace.shared.open(url)
            } else {
                openMessagesApp()
            }
        } else {
            openApp(named: app)
        }
    }

    func open(_ notice: MessageNotice) {
        if notice.source.lowercased().contains("message") { openMessagesApp() } else { openApp(named: notice.source) }
    }

    private func openApp(named name: String) {
        let url = URL(fileURLWithPath: "/Applications/\(name).app")
        if FileManager.default.fileExists(atPath: url.path) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
        } else {
            ModalHelper.info(title: "Can't find \(name)", message: "LifeNotch looked for \(name) in your Applications folder but didn't find it.")
        }
    }

    // MARK: Link token (keeps strangers' links from faking notices)

    /// A random secret stored in the Keychain. Links that add notices must contain it.
    var token: String {
        if let existing = KeychainStore.get(account: Self.tokenAccount), !existing.isEmpty { return existing }
        return regenerateToken()
    }

    @discardableResult
    func regenerateToken() -> String {
        var bytes = [UInt8](repeating: 0, count: 16)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        let value = bytes.map { String(format: "%02x", $0) }.joined()
        KeychainStore.set(value, account: Self.tokenAccount)
        objectWillChange.send()
        return value
    }

    var exampleLink: String {
        "lifenotch://notice?token=\(token)&source=WhatsApp&from=Alex&preview=Hello"
    }
}
