import Foundation

// ShelfStore.swift
// The File Shelf remembers WHERE files are (their paths). It never copies, moves or deletes your
// files. Drag a file in to park it, drag it back out when you need it. Removing an item from the
// shelf only forgets the shortcut.

struct ShelfItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var path: String
    var added = Date()

    var url: URL { URL(fileURLWithPath: path) }
    var name: String { url.lastPathComponent }
}

final class ShelfStore: ObservableObject {
    @Published private(set) var items: [ShelfItem]
    private static let fileName = "shelf.json"

    init() {
        let saved = LocalStore.load([ShelfItem].self, name: Self.fileName) ?? []
        // Forget shortcuts to files that no longer exist.
        items = saved.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    func add(_ urls: [URL]) {
        for url in urls where url.isFileURL {
            if !items.contains(where: { $0.path == url.path }) {
                items.insert(ShelfItem(path: url.path), at: 0)
            }
        }
        if items.count > 60 { items.removeLast(items.count - 60) }
        save()
    }

    func remove(_ item: ShelfItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() { LocalStore.save(items, name: Self.fileName) }
}
