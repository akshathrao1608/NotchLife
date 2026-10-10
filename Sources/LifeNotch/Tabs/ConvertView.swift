import SwiftUI
import UniformTypeIdentifiers

// ConvertView.swift
// Pick or drop a file, choose what to turn it into, press Convert. The original is never changed.

struct ConvertView: View {
    @EnvironmentObject private var model: ConvertModel
    @State private var dropping = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 8) {
                Image(systemName: "arrow.down.doc").font(.system(size: 28)).foregroundStyle(.secondary)
                Text(model.source?.lastPathComponent ?? "Drop a file here").lnFont(12, .semibold).lineLimit(2)
                Button("Choose file…") { model.choose() }.buttonStyle(LNButtonStyle(prominent: false))
            }
            .frame(maxWidth: .infinity, minHeight: 130)
            .card()
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(dropping ? Color.accentColor : Color.clear, lineWidth: 2))
            .onDrop(of: [UTType.fileURL], isTargeted: $dropping) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    if let url = url { DispatchQueue.main.async { model.set(url) } }
                }
                return true
            }

            VStack(alignment: .leading, spacing: 8) {
                SectionTitle("Convert to")
                let options = model.kind.targets
                if options.isEmpty {
                    Text("Pictures, PDFs, videos and audio files work.").lnFont(11).foregroundStyle(.secondary)
                } else {
                    Picker("", selection: $model.target) {
                        ForEach(options) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                    Button(model.isWorking ? "Working…" : "Convert") { Task { await model.convert() } }
                        .buttonStyle(LNButtonStyle(prominent: true))
                        .disabled(model.isWorking || model.source == nil)
                }
                if !model.message.isEmpty { Text(model.message).lnFont(11).foregroundStyle(.secondary) }
                if !model.lastOutputs.isEmpty {
                    Button("Show in Finder") { model.reveal() }.buttonStyle(LNButtonStyle(prominent: false))
                }
                Text("Saved next to the original with a new name. Nothing is overwritten or uploaded.")
                    .lnFont(9.5).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(width: 220, alignment: .topLeading)
            .card()
        }
    }
}
