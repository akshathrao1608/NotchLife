import Foundation

// TodoStore.swift
// A quick to-do list, stored on this Mac (todos.json). Highest priority first, finished items last.

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var priority: Priority = .medium
    var done = false
    var createdAt = Date()
}

final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem]
    private static let fileName = "todos.json"

    init() {
        items = LocalStore.load([TodoItem].self, name: Self.fileName) ?? []
    }

    private static func weight(_ p: Priority) -> Int {
        switch p {
        case .high: return 0
        case .medium: return 1
        case .low: return 2
        }
    }

    var sorted: [TodoItem] {
        items.sorted { a, b in
            if a.done != b.done { return !a.done }
            if Self.weight(a.priority) != Self.weight(b.priority) { return Self.weight(a.priority) < Self.weight(b.priority) }
            return a.createdAt < b.createdAt
        }
    }

    var openCount: Int { items.filter { !$0.done }.count }

    func add(_ title: String, priority: Priority = .medium) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        items.append(TodoItem(title: clean, priority: priority))
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].done.toggle()
        save()
    }

    func setPriority(_ item: TodoItem, _ priority: Priority) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].priority = priority
        save()
    }

    func delete(_ item: TodoItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func clearDone() {
        items.removeAll { $0.done }
        save()
    }

    func reloadFromDisk() {
        items = LocalStore.load([TodoItem].self, name: Self.fileName) ?? []
    }

    private func save() { LocalStore.save(items, name: Self.fileName) }
}
