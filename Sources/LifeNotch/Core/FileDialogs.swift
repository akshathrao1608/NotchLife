import AppKit
import UniformTypeIdentifiers

// FileDialogs.swift
// The standard macOS "Save" and "Open" windows. YOU choose the file and place, every time.
// LifeNotch can only touch the files you pick here.

enum FileDialogs {
    /// Shows a Save panel and writes `data` where you choose. Returns the saved location.
    @discardableResult
    static func save(data: Data, suggestedName: String, type: UTType) -> URL? {
        ModalHelper.bringToFront()
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = [type]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            ModalHelper.info(title: "Couldn't save the file", message: error.localizedDescription)
            return nil
        }
    }

    static func open(types: [UTType], message: String) -> URL? {
        ModalHelper.bringToFront()
        let panel = NSOpenPanel()
        panel.allowedContentTypes = types
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = message
        return panel.runModal() == .OK ? panel.url : nil
    }
}
