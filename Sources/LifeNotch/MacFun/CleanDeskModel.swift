import AppKit

// CleanDeskModel.swift
// "Clean Desk" is a gentle tidy-up helper. It can LOOK at your Desktop or Downloads folder
// (only after you press Scan and say yes) and tell you what is old or big.
// It NEVER deletes, moves or renames anything. You decide and do the tidying yourself.

struct CleanDeskFile: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let url: URL
    let bytes: Int64
    let modified: Date

    var ageDays: Int { max(0, Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? 0) }
}

struct CleanDeskReport: Equatable {
    let folderName: String
    let folderURL: URL
    let itemCount: Int
    let oldCount: Int
    let totalBytes: Int64
    let oldest: [CleanDeskFile]
}

final class CleanDeskModel: ObservableObject {
    @Published var reports: [String: CleanDeskReport] = [:]
    @Published var message: String?

    enum Folder: String, CaseIterable, Identifiable {
        case downloads = "Downloads"
        case desktop = "Desktop"
        var id: String { rawValue }

        var url: URL {
            let directory: FileManager.SearchPathDirectory = self == .downloads ? .downloadsDirectory : .desktopDirectory
            return FileManager.default.urls(for: directory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(rawValue)
        }
    }

    /// Looks inside the folder (read-only). Returns after you answer the question.
    func scan(_ folder: Folder, settings: AppSettings) {
        let allowed = ConsentGate.request(
            .scanFolders,
            settings: settings,
            explanation: "LifeNotch will list the files in your \(folder.rawValue) folder to count old and large items. It only READS names, sizes and dates. It never opens, changes, moves or deletes anything, and nothing leaves your Mac. macOS may also ask you to allow access to this folder."
        )
        guard allowed else { return }

        let keys: [URLResourceKey] = [.fileSizeKey, .contentModificationDateKey, .isDirectoryKey]
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: folder.url,
                                                                   includingPropertiesForKeys: keys,
                                                                   options: [.skipsHiddenFiles])
            var files: [CleanDeskFile] = []
            for url in urls {
                let values = try? url.resourceValues(forKeys: Set(keys))
                files.append(CleanDeskFile(name: url.lastPathComponent,
                                           url: url,
                                           bytes: Int64(values?.fileSize ?? 0),
                                           modified: values?.contentModificationDate ?? Date()))
            }
            let old = files.filter { $0.ageDays >= 30 }
            reports[folder.rawValue] = CleanDeskReport(
                folderName: folder.rawValue,
                folderURL: folder.url,
                itemCount: files.count,
                oldCount: old.count,
                totalBytes: files.reduce(0) { $0 + $1.bytes },
                oldest: Array(files.sorted { $0.modified < $1.modified }.prefix(8)))
            message = nil
        } catch {
            message = "Couldn't read \(folder.rawValue): \(error.localizedDescription). You may need to allow access in System Settings > Privacy & Security > Files and Folders."
        }
    }

    func reveal(_ file: CleanDeskFile) {
        NSWorkspace.shared.activateFileViewerSelecting([file.url])
    }

    func openFolder(_ report: CleanDeskReport) {
        NSWorkspace.shared.open(report.folderURL)
    }

    struct ChecklistItem: Identifiable {
        let id: String
        let text: String
    }

    static let checklist: [ChecklistItem] = [
        ChecklistItem(id: "downloads", text: "Look through Downloads and move the files worth keeping into proper folders"),
        ChecklistItem(id: "school", text: "Put finished school work into one folder for each subject"),
        ChecklistItem(id: "screenshots", text: "Check screenshots on the Desktop and keep only the useful ones"),
        ChecklistItem(id: "apps", text: "Think about apps you no longer use (you can drag them to the Trash yourself)"),
        ChecklistItem(id: "trash", text: "Empty the Trash yourself once you're sure"),
        ChecklistItem(id: "backup", text: "Back up your important files")
    ]
}
