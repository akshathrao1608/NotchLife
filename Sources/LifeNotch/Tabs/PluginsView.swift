import SwiftUI
import AppKit

// PluginsView.swift
// Shows your plugins (plain JSON files, no code). See docs/PLUGINS.md.

struct PluginsView: View {
    @EnvironmentObject private var manager: PluginManager
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var ai: AIViewModel
    @EnvironmentObject private var notch: NotchState
    @State private var copied: String?

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Plugins are plain JSON files: links, text snippets and AI prompts. They can't run code.").lnFont(10.5).foregroundStyle(.secondary)
                Spacer()
                Button("Open plugins folder") { manager.revealFolder() }.buttonStyle(LNButtonStyle(prominent: true))
                Button("Reload") { manager.reload() }.buttonStyle(LNButtonStyle())
            }
            ForEach(manager.problems, id: \.self) { Text($0).lnFont(10.5).foregroundStyle(.orange).frame(maxWidth: .infinity, alignment: .leading) }
            if manager.plugins.isEmpty {
                EmptyStateView(icon: "puzzlepiece.extension.fill", title: "No plugins yet",
                               message: "Press \"Open plugins folder\" to create one with an example you can edit.")
            }
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(manager.plugins) { plugin in
                        VStack(alignment: .leading, spacing: 5) {
                            Label(plugin.name, systemImage: ActivityStore.safeSymbol(plugin.icon ?? "puzzlepiece.extension.fill")).lnFont(13, .bold)
                            if let text = plugin.description { Text(text).lnFont(10.5).foregroundStyle(.secondary) }
                            ForEach(plugin.links ?? [], id: \.title) { link in
                                if let url = Plugin.isSafe(url: link.url) {
                                    Button { NSWorkspace.shared.open(url) } label: { Label(link.title, systemImage: "link") }
                                        .buttonStyle(.plain).lnFont(11.5)
                                }
                            }
                            ForEach(plugin.snippets ?? [], id: \.title) { snippet in
                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(snippet.text, forType: .string)
                                    copied = snippet.title
                                } label: { Label(copied == snippet.title ? "Copied" : snippet.title, systemImage: "doc.on.doc") }
                                    .buttonStyle(.plain).lnFont(11.5)
                            }
                            ForEach(plugin.prompts ?? [], id: \.title) { item in
                                Button {
                                    ai.prefill(text: item.prompt)
                                    notch.open(.ai)
                                } label: { Label(item.title, systemImage: "sparkles") }
                                    .buttonStyle(.plain).lnFont(11.5)
                            }
                            if let author = plugin.author { Text("by \(author)").lnFont(9).foregroundStyle(.secondary) }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .card()
                    }
                }
            }
        }
        .onAppear { manager.reload() }
    }
}
