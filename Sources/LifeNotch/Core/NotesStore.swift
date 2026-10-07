import Foundation

// NotesStore.swift
// LifeNotch's own little notebook ("Study notes"). Used by "Save to notes" in the AI tab,
// the browser, and Quick Notes in Mac Fun. Stored only on this Mac (notes.json).
// Want it in Apple Notes? Use the Share button: it uses the normal macOS share sheet,
// so LifeNotch never needs permission to touch the Notes app.

struct StudyNote: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var body: String
    var source: String          // e.g. "AI answer", "Web page", "Quick note"
    var createdAt = Date()
}

final class NotesStore: ObservableObject {
    @Published private(set) var notes: [StudyNote]
    private static let fileName = "notes.json"

    init() {
        notes = LocalStore.load([StudyNote].self, name: Self.fileName) ?? []
    }

    func add(title: String, body: String, source: String) {
        let clean = title.trimmingCharacters(in: .whitespacesAndNewlines)
        notes.insert(StudyNote(title: clean.isEmpty ? "Untitled note" : clean, body: body, source: source), at: 0)
        save()
    }

    func update(_ note: StudyNote) {
        guard let index = notes.firstIndex(where: { $0.id == note.id }) else { return }
        notes[index] = note
        save()
    }

    func delete(_ note: StudyNote) {
        notes.removeAll { $0.id == note.id }
        save()
    }

    func reloadFromDisk() {
        notes = LocalStore.load([StudyNote].self, name: Self.fileName) ?? []
    }

    private func save() {
        LocalStore.save(notes, name: Self.fileName)
    }
}
