import SwiftUI
import AppKit

// SnippetsView.swift
// Saved pieces of text (an email signature, a link, a code line). Click one to copy it,
// then press ⌘V wherever you want it. Snippets are stored only on this Mac.

struct SnippetsView: View {
    @EnvironmentObject private var settings: AppSettings
    @State private var title = ""
    @State private var text = ""
    @State private var copiedID: UUID?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                SectionTitle("New snippet")
                TextField("Name", text: $title).textFieldStyle(.roundedBorder)
                TextEditor(text: $text)
                    .font(.system(size: 12))
                    .frame(height: 90)
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color.primary.opacity(0.08)))
                    .accessibilityLabel("Snippet text")
                Button("Save snippet") {
                    guard !text.isEmpty else { return }
                    settings.prefs.snippets.append(Snippet(title: title.isEmpty ? String(text.prefix(24)) : title, text: text))
                    title = ""; text = ""
                }
                .buttonStyle(LNButtonStyle(prominent: true))
                Text("Click a snippet to copy it, then press ⌘V.").lnFont(10).foregroundStyle(.secondary)
            }
            .frame(width: 260, alignment: .leading)

            ScrollView {
                LazyVStack(spacing: 6) {
                    if settings.prefs.snippets.isEmpty {
                        EmptyStateView(icon: "text.quote", title: "No snippets yet")
                    }
                    ForEach(settings.prefs.snippets) { snippet in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(snippet.title).lnFont(12, .semibold)
                                Text(snippet.text).lnFont(10.5).foregroundStyle(.secondary).lineLimit(2)
                            }
                            Spacer()
                            if copiedID == snippet.id { Label("Copied", systemImage: "checkmark").lnFont(10.5).foregroundStyle(.green) }
                            Button {
                                settings.prefs.snippets.removeAll { $0.id == snippet.id }
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(.plain).accessibilityLabel("Delete \(snippet.title)")
                        }
                        .card(padding: 8)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(snippet.text, forType: .string)
                            copiedID = snippet.id
                            SoundPlayer.play(.tap)
                        }
                    }
                }
                .padding(.trailing, 6)
            }
        }
    }
}
