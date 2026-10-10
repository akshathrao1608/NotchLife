import SwiftUI
import AppKit

// FileSearchView.swift
// Type part of a file or app name. Press Return to open the first match, or use the buttons.

struct FileSearchView: View {
    @EnvironmentObject private var search: FileSearchModel
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search files and apps (at least 2 letters)", text: $search.query)
                    .textFieldStyle(.plain)
                    .focused($focused)
                    .onSubmit { if let first = search.results.first { NSWorkspace.shared.open(first.url) } }
                if search.isSearching { ProgressView().controlSize(.small) }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.1)))

            if search.results.isEmpty && search.query.count >= 2 && !search.isSearching {
                EmptyStateView(icon: "questionmark.folder", title: "No matches")
            }
            ScrollView {
                LazyVStack(spacing: 4) {
                    ForEach(search.results) { hit in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: hit.path)).resizable().frame(width: 24, height: 24)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(hit.name).lnFont(12, .medium).lineLimit(1)
                                Text(hit.folder).lnFont(9.5).foregroundStyle(.secondary).lineLimit(1)
                            }
                            Spacer()
                            Button("Show") { NSWorkspace.shared.activateFileViewerSelecting([hit.url]) }.buttonStyle(LNButtonStyle())
                            Button("Open") { NSWorkspace.shared.open(hit.url) }.buttonStyle(LNButtonStyle(prominent: true))
                        }
                        .padding(6)
                    }
                }
                .padding(.trailing, 6)
            }
            Text("Uses Spotlight on your Mac. Nothing is sent anywhere.").lnFont(9.5).foregroundStyle(.secondary)
        }
        .onAppear { focused = true }
    }
}
