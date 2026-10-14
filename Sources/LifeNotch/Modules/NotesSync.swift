import Foundation
import AppKit

// NotesSync.swift
// Keeps your LifeNotch notes in step with a FOLDER YOU CHOOSE, as plain Markdown files. Pick a folder inside
// iCloud Drive, Dropbox or any synced folder and your notes follow you to other Macs, where LifeNotch
// (or any text editor) can read them. LifeNotch itself never talks to any cloud: your sync service does.
//  - New notes become "Title - abcd1234.md" files.
//  - Files you add or edit in that folder come back into LifeNotch.
//  - LifeNotch NEVER deletes files. (If you delete a note here, its file stays; remove it yourself in Finder.)

enum NotesSyncFormat {
    static func fileName(for note: StudyNote) -> String {
        let bad = CharacterSet(charactersIn: "/\\:*?\"<>|\n\r")
        let cleaned = note.title.components(separatedBy: bad).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        let title = String((cleaned.isEmpty ? "Note" : cleaned).prefix(60))
        return "\(title) - \(note.id.uuidString.prefix(8).lowercased()).md"
    }

    static func render(_ note: StudyNote) -> String {
        let stamp = ISO8601DateFormatter().string(from: note.createdAt)
        return "<!-- lifenotch id=\(note.id.uuidString) source=\(note.source.replacingOccurrences(of: " ", with: "_")) created=\(stamp) -->\n# \(note.title)\n\n\(note.body)\n"
    }

    /// Reads a file back into a note. Files without LifeNotch's header become new notes too.
    static func parse(_ text: String, fallbackTitle: String) -> StudyNote {
        var lines = text.components(separatedBy: "\n")
        var id = UUID()
        var source = "Synced file"
        var created = Date()
        if let first = lines.first, first.hasPrefix("<!-- lifenotch ") {
            lines.removeFirst()
            for part in first.replacingOccurrences(of: "<!--", with: "").replacingOccurrences(of: "-->", with: "").split(separator: " ") {
                let pair = part.split(separator: "=", maxSplits: 1).map(String.init)
                guard pair.count == 2 else { continue }
                switch pair[0] {
                case "id": if let u = UUID(uuidString: pair[1]) { id = u }
                case "source": source = pair[1].replacingOccurrences(of: "_", with: " ")
                case "created": if let d = ISO8601DateFormatter().date(from: pair[1]) { created = d }
                default: break
                }
            }
        }
        var title = fallbackTitle
        if let first = lines.first, first.hasPrefix("# ") {
            title = String(first.dropFirst(2))
            lines.removeFirst()
        }
        let body = lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        var note = StudyNote(title: title, body: body, source: source)
        note.id = id
        note.createdAt = created
        return note
    }
}

final class NotesSync: ObservableObject {
    @Published private(set) var status = ""
    @Published private(set) var isSyncing = false

    private let settings: AppSettings
    private let notes: NotesStore
    private static let stateFile = "notessync.json"

    private struct State: Codable { var syncedIDs: Set<UUID> = [] }

    init(settings: AppSettings, notes: NotesStore) {
        self.settings = settings
        self.notes = notes
    }

    var folder: URL? {
        let path = settings.prefs.notesSyncFolder
        return path.isEmpty ? nil : URL(fileURLWithPath: path, isDirectory: true)
    }

    func chooseFolder() {
        ModalHelper.bringToFront()
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.message = "Choose a folder for your synced notes (for example a folder inside iCloud Drive)."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.prefs.notesSyncFolder = url.path
        syncNow()
    }

    func stop() {
        settings.prefs.notesSyncFolder = ""
        status = ""
    }

    func syncNow() {
        guard let folder = folder, !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        let fm = FileManager.default
        var state = LocalStore.load(State.self, name: Self.stateFile) ?? State()
        var exported = 0, imported = 0, updated = 0
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)

            // 1. Read the folder.
            var filesByID: [UUID: (url: URL, note: StudyNote, modified: Date)] = [:]
            for url in (try fm.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.contentModificationDateKey]))
            where url.pathExtension.lowercased() == "md" {
                guard let text = try? String(contentsOf: url, encoding: .utf8), text.count < 500_000 else { continue }
                let parsed = NotesSyncFormat.parse(text, fallbackTitle: url.deletingPathExtension().lastPathComponent)
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? Date.distantPast
                filesByID[parsed.id] = (url, parsed, modified)
            }

            // 2. Bring in new or newer files.
            let currentIDs = Set(notes.notes.map { $0.id })
            let lastSync = settings.prefs.notesLastSync
            for (id, file) in filesByID {
                if let local = notes.notes.first(where: { $0.id == id }) {
                    if file.modified > lastSync, file.note.body != local.body || file.note.title != local.title {
                        var changed = local
                        changed.title = file.note.title
                        changed.body = file.note.body
                        notes.update(changed)
                        updated += 1
                    }
                } else if !state.syncedIDs.contains(id) || currentIDs.contains(id) {
                    notes.insertImported(file.note)
                    imported += 1
                }
                // (A note you deleted here stays out: its id is in syncedIDs but not in your notes.)
            }

            // 3. Write notes that are missing or changed.
            for note in notes.notes {
                let existing = filesByID[note.id]
                let target = existing?.url ?? folder.appendingPathComponent(NotesSyncFormat.fileName(for: note))
                let text = NotesSyncFormat.render(note)
                if let current = try? String(contentsOf: target, encoding: .utf8), current == text { continue }
                if let existing = existing, existing.modified > lastSync, existing.note.body != note.body { continue }   // the file is newer: keep it
                try text.write(to: target, atomically: true, encoding: .utf8)
                exported += 1
            }

            state.syncedIDs = Set(notes.notes.map { $0.id }).union(state.syncedIDs)
            LocalStore.save(state, name: Self.stateFile)
            settings.prefs.notesLastSync = Date()
            status = "Synced \(Date().formatted(date: .omitted, time: .shortened)): \(exported) written, \(imported) new, \(updated) updated."
        } catch {
            status = "Sync failed: \(error.localizedDescription)"
        }
    }
}
