import Foundation

// BrowsingHistory.swift
// A list of pages you visited. It stays EMPTY unless you switch "Keep browsing history" on in
// Settings, and it is never recorded in private mode. Stored only on this Mac.

struct HistoryEntry: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var url: String
    var date = Date()
}

final class BrowsingHistory: ObservableObject {
    @Published private(set) var entries: [HistoryEntry]
    private static let fileName = "history.json"

    init() {
        entries = LocalStore.load([HistoryEntry].self, name: Self.fileName) ?? []
    }

    func record(title: String, url: URL) {
        let address = url.absoluteString
        if entries.first?.url == address { return }
        entries.insert(HistoryEntry(title: title.isEmpty ? (url.host ?? address) : title, url: address), at: 0)
        if entries.count > 200 { entries.removeLast(entries.count - 200) }
        LocalStore.save(entries, name: Self.fileName)
    }

    func clear() {
        entries = []
        LocalStore.remove(name: Self.fileName)
    }
}
