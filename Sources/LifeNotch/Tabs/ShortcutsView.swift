import SwiftUI
import AppKit

// ShortcutsView.swift
// Runs YOUR Apple Shortcuts. Type the exact name of a shortcut you made in the Shortcuts app and
// LifeNotch gets a button for it. LifeNotch can only run names you add here.

struct ShortcutsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var newName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("Exact name of one of your shortcuts", text: $newName)
                    .textFieldStyle(.roundedBorder).frame(maxWidth: 320)
                    .onSubmit(add)
                Button("Add", action: add).buttonStyle(LNButtonStyle(prominent: true)).disabled(newName.isEmpty)
                Button("Open Shortcuts app") {
                    if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.shortcuts") {
                        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) { _, _ in }
                    }
                }
                .buttonStyle(LNButtonStyle())
            }
            if settings.prefs.shortcutNames.isEmpty {
                EmptyStateView(icon: "bolt.fill", title: "No shortcuts added",
                               message: "Make a shortcut in the Shortcuts app, then add its name here to run it from the notch.")
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 8)], spacing: 8) {
                    ForEach(settings.prefs.shortcutNames, id: \.self) { name in
                        HStack {
                            Button { run(name) } label: {
                                Label(name, systemImage: "play.fill").lnFont(12, .medium).lineLimit(1)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            Button { settings.prefs.shortcutNames.removeAll { $0 == name } } label: { Image(systemName: "xmark") }
                                .buttonStyle(.plain).accessibilityLabel("Remove \(name)")
                        }
                        .card(padding: 9)
                        .accessibilityElement(children: .contain)
                    }
                }
                .padding(.trailing, 6)
            }
            Text("This opens the Shortcuts app's own \"run\" link. Shortcuts may ask before it does anything sensitive.")
                .lnFont(10).foregroundStyle(.secondary)
        }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !settings.prefs.shortcutNames.contains(name) else { return }
        settings.prefs.shortcutNames.append(name)
        newName = ""
    }

    private func run(_ name: String) {
        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [URLQueryItem(name: "name", value: name)]
        if let url = components.url { NSWorkspace.shared.open(url) }
    }
}
