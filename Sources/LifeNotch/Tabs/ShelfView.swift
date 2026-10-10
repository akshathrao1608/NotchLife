import SwiftUI
import AppKit
import UniformTypeIdentifiers

// ShelfView.swift
// The File Shelf: drop files here to park them, drag them out later, or send them with AirDrop.
// LifeNotch only remembers where each file is. It never copies, moves or deletes your files.

struct ShelfView: View {
    @EnvironmentObject private var shelf: ShelfStore
    @State private var targeted = false

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Drop files or folders here").lnFont(11.5).foregroundStyle(.secondary)
                Spacer()
                if !shelf.items.isEmpty {
                    Button { airDropAll() } label: { Label("AirDrop all", systemImage: "airplayaudio") }
                        .buttonStyle(LNButtonStyle())
                    Button("Clear shelf") {
                        if ModalHelper.confirm(title: "Clear the shelf?",
                                               message: "This only forgets the shortcuts. Your files stay exactly where they are.",
                                               confirmTitle: "Clear shelf") { shelf.clear() }
                    }
                    .buttonStyle(LNButtonStyle())
                }
            }
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [7]))
                    .foregroundStyle(targeted ? Color.accentColor : Color.secondary.opacity(0.5))
                if shelf.items.isEmpty {
                    EmptyStateView(icon: "tray.and.arrow.down", title: "The shelf is empty",
                                   message: "Drag files here from Finder or your desktop.")
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 10)], spacing: 10) {
                            ForEach(shelf.items) { item in
                                VStack(spacing: 4) {
                                    Image(nsImage: NSWorkspace.shared.icon(forFile: item.path)).resizable().frame(width: 44, height: 44)
                                    Text(item.name).lnFont(10.5).lineLimit(2).multilineTextAlignment(.center)
                                }
                                .frame(width: 90)
                                .padding(6)
                                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.primary.opacity(0.07)))
                                .onDrag { NSItemProvider(contentsOf: item.url) ?? NSItemProvider() }
                                .contextMenu {
                                    Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([item.url]) }
                                    Button("Open") { NSWorkspace.shared.open(item.url) }
                                    Button("AirDrop") { airDrop([item.url]) }
                                    Button("Remove from shelf") { shelf.remove(item) }
                                }
                                .accessibilityLabel(item.name)
                                .accessibilityHint("Drag to move this file out. Right-click for more.")
                            }
                        }
                        .padding(12)
                    }
                }
            }
            .dropDestination(for: URL.self) { urls, _ in
                shelf.add(urls.filter { $0.isFileURL })
                SoundPlayer.play(.tap)
                return true
            } isTargeted: { targeted = $0 }
        }
    }

    private func airDropAll() { airDrop(shelf.items.map { $0.url }) }

    private func airDrop(_ urls: [URL]) {
        guard let service = NSSharingService(named: .sendViaAirDrop), service.canPerform(withItems: urls) else {
            ModalHelper.info(title: "AirDrop isn't available", message: "Turn on Wi-Fi and Bluetooth and set AirDrop in Finder to \"Contacts Only\" or \"Everyone\".")
            return
        }
        service.perform(withItems: urls)
    }
}
