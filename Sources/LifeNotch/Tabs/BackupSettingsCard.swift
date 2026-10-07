import SwiftUI
import UniformTypeIdentifiers

// BackupSettingsCard.swift
// Settings > Backup. You choose where files are saved, every time. API keys are never included.

struct BackupSettingsCard: View {
    @EnvironmentObject private var assignments: AssignmentStore
    @State private var message = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Local backup and export")
            HStack {
                Button("Export assignments (JSON)") {
                    if FileDialogs.save(data: assignments.exportJSON(), suggestedName: "LifeNotch-assignments.json", type: .json) != nil {
                        message = "Assignments exported."
                    }
                }
                Button("Export assignments (CSV)") {
                    if FileDialogs.save(data: assignments.exportCSV(), suggestedName: "LifeNotch-assignments.csv", type: .commaSeparatedText) != nil {
                        message = "Assignments exported."
                    }
                }
                Button("Import assignments (JSON)…") { importAssignments() }
            }
            .buttonStyle(LNButtonStyle())
            if !message.isEmpty { Text(message).lnFont(11).foregroundStyle(.secondary) }
            Text("Exports contain only what you see in the app. They never contain your API key.")
                .lnFont(10.5).foregroundStyle(.secondary)
        }
        .card()
    }

    private func importAssignments() {
        guard let url = FileDialogs.open(types: [.json], message: "Choose a LifeNotch assignments JSON file."),
              let data = try? Data(contentsOf: url) else { return }
        do {
            let added = try assignments.importJSON(data)
            message = "Imported \(added) new assignment\(added == 1 ? "" : "s")."
        } catch {
            message = "That file isn't a LifeNotch assignments backup."
        }
    }
}
