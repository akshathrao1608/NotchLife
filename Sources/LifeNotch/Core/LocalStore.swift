import Foundation

// LocalStore.swift
// Saves small JSON files in your own user folder:
//   ~/Library/Application Support/LifeNotch/
// Nothing here is uploaded or synced anywhere. "Reset app data" in Settings wipes this folder
// (only this folder, nothing else on your Mac).

enum LocalStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("LifeNotch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func encoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }

    static func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }

    static func load<T: Decodable>(_ type: T.Type, name: String) -> T? {
        let url = directory.appendingPathComponent(name)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, name: String) {
        let url = directory.appendingPathComponent(name)
        if let data = try? encoder().encode(value) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func remove(name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    /// Deletes ONLY the files LifeNotch itself created inside its own folder.
    static func wipeAll() {
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return }
        for item in items where item.pathExtension == "json" {
            try? fm.removeItem(at: item)
        }
    }
}
