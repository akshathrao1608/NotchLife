import Foundation
import AppKit

// PluginManager.swift
// The LifeNotch "Plugin SDK". A plugin is ONE plain JSON file in
//   ~/Library/Application Support/LifeNotch/Plugins/
// It can only contain DATA: a name, an icon, a description and lists of links, snippets of text and
// AI prompts. Plugins never contain or run code, so installing one cannot harm your Mac. Links must be
// http(s) and always open in your default browser; AI prompts only pre-fill the AI tab (you press Send).
// See docs/PLUGINS.md for the format.

struct PluginLink: Codable, Equatable { var title: String; var url: String }
struct PluginSnippet: Codable, Equatable { var title: String; var text: String }
struct PluginPrompt: Codable, Equatable { var title: String; var prompt: String }

struct Plugin: Identifiable, Codable, Equatable {
    var name: String
    var icon: String?
    var description: String?
    var author: String?
    var links: [PluginLink]?
    var snippets: [PluginSnippet]?
    var prompts: [PluginPrompt]?
    var id: String { name }

    /// Only http(s) links are allowed.
    static func isSafe(url: String) -> URL? {
        guard let parsed = URL(string: url), let scheme = parsed.scheme?.lowercased(), scheme == "https" || scheme == "http" else { return nil }
        return parsed
    }
}

final class PluginManager: ObservableObject {
    @Published private(set) var plugins: [Plugin] = []
    @Published private(set) var problems: [String] = []

    static var folder: URL {
        LocalStore.directory.appendingPathComponent("Plugins", isDirectory: true)
    }

    func reload() {
        var loaded: [Plugin] = []
        var errors: [String] = []
        let files = (try? FileManager.default.contentsOfDirectory(at: Self.folder, includingPropertiesForKeys: nil)) ?? []
        for url in files.filter({ $0.pathExtension.lowercased() == "json" }).sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            guard let data = try? Data(contentsOf: url), data.count < 200_000 else { errors.append("\(url.lastPathComponent): too big or unreadable"); continue }
            do { loaded.append(try JSONDecoder().decode(Plugin.self, from: data)) }
            catch { errors.append("\(url.lastPathComponent): not a valid plugin file") }
        }
        plugins = loaded
        problems = errors
    }

    /// Opens the folder in Finder, creating it (with one example plugin) the first time.
    func revealFolder() {
        let fm = FileManager.default
        try? fm.createDirectory(at: Self.folder, withIntermediateDirectories: true)
        let example = Self.folder.appendingPathComponent("example.json")
        if !fm.fileExists(atPath: example.path) {
            try? Self.exampleJSON.write(to: example, atomically: true, encoding: .utf8)
        }
        NSWorkspace.shared.activateFileViewerSelecting([example])
        reload()
    }

    static let exampleJSON = """
    {
      "name": "Study toolkit",
      "icon": "graduationcap.fill",
      "description": "An example plugin: links, snippets and AI prompts.",
      "author": "You",
      "links": [
        { "title": "Khan Academy", "url": "https://www.khanacademy.org" },
        { "title": "Wolfram Alpha", "url": "https://www.wolframalpha.com" }
      ],
      "snippets": [
        { "title": "Email sign-off", "text": "Kind regards," }
      ],
      "prompts": [
        { "title": "Quiz me", "prompt": "Quiz me with 5 questions on this topic:" }
      ]
    }
    """
}
