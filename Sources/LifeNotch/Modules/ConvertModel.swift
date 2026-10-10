import Foundation
import AppKit
import ImageIO
import PDFKit
import AVFoundation
import UniformTypeIdentifiers

// ConvertModel.swift
// Converts a file you pick: pictures to other picture types or a PDF, PDF pages to pictures,
// video to MP4 or audio-only, audio to M4A. Everything happens on this Mac. The result is saved NEXT to
// the original with a new name. Your original is never changed, moved, or overwritten.

enum ConvertTarget: String, CaseIterable, Identifiable {
    case png, jpeg, heic, tiff, pdf, mp4, m4a
    var id: String { rawValue }
    var title: String {
        switch self {
        case .png: return "PNG picture"
        case .jpeg: return "JPEG picture"
        case .heic: return "HEIC picture"
        case .tiff: return "TIFF picture"
        case .pdf: return "PDF"
        case .mp4: return "MP4 video"
        case .m4a: return "M4A audio"
        }
    }
    var fileExtension: String { self == .jpeg ? "jpg" : rawValue }
    var utType: CFString? {
        switch self {
        case .png: return UTType.png.identifier as CFString
        case .jpeg: return UTType.jpeg.identifier as CFString
        case .heic: return UTType.heic.identifier as CFString
        case .tiff: return UTType.tiff.identifier as CFString
        default: return nil
        }
    }
}

enum ConvertKind {
    case image, pdf, movie, audio, unknown

    static func of(_ url: URL) -> ConvertKind {
        guard let type = UTType(filenameExtension: url.pathExtension.lowercased()) else { return .unknown }
        if type.conforms(to: .pdf) { return .pdf }
        if type.conforms(to: .image) { return .image }
        if type.conforms(to: .movie) || type.conforms(to: .video) { return .movie }
        if type.conforms(to: .audio) { return .audio }
        return .unknown
    }

    var targets: [ConvertTarget] {
        switch self {
        case .image: return [.png, .jpeg, .heic, .tiff, .pdf]
        case .pdf: return [.png, .jpeg]
        case .movie: return [.mp4, .m4a]
        case .audio: return [.m4a]
        case .unknown: return []
        }
    }
}

final class ConvertModel: ObservableObject {
    @Published var source: URL?
    @Published var target: ConvertTarget = .png
    @Published private(set) var isWorking = false
    @Published var message = ""
    @Published private(set) var lastOutputs: [URL] = []

    var kind: ConvertKind { source.map(ConvertKind.of) ?? .unknown }

    func choose() {
        ModalHelper.bringToFront()
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.message = "Choose a picture, PDF, video or audio file to convert."
        guard panel.runModal() == .OK, let url = panel.url else { return }
        set(url)
    }

    func set(_ url: URL) {
        source = url
        lastOutputs = []
        message = ""
        if let first = ConvertKind.of(url).targets.first { target = first }
        if ConvertKind.of(url).targets.isEmpty { message = "LifeNotch can't convert this kind of file." }
    }

    /// A file name that doesn't exist yet: "photo.png", then "photo 2.png", "photo 3.png"...
    static func freeURL(base: URL, name: String, ext: String) -> URL {
        var candidate = base.appendingPathComponent(name).appendingPathExtension(ext)
        var n = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = base.appendingPathComponent("\(name) \(n)").appendingPathExtension(ext)
            n += 1
        }
        return candidate
    }

    @MainActor
    func convert() async {
        guard let source = source, !isWorking, kind.targets.contains(target) else { return }
        isWorking = true
        message = ""
        defer { isWorking = false }
        let folder = source.deletingLastPathComponent()
        let name = source.deletingPathExtension().lastPathComponent
        do {
            var outputs: [URL] = []
            switch (kind, target) {
            case (.image, .pdf):
                outputs = [try Self.imageToPDF(source, folder: folder, name: name)]
            case (.image, _):
                outputs = [try Self.imageToImage(source, to: target, folder: folder, name: name)]
            case (.pdf, _):
                outputs = try Self.pdfToImages(source, to: target, folder: folder, name: name)
            case (.movie, .mp4), (.movie, .m4a), (.audio, .m4a):
                outputs = [try await Self.export(source, to: target, folder: folder, name: name)]
            default:
                throw ConvertError.unsupported
            }
            lastOutputs = outputs
            message = outputs.count == 1 ? "Saved \(outputs[0].lastPathComponent) next to the original."
                                         : "Saved \(outputs.count) files next to the original."
        } catch {
            message = error.localizedDescription
        }
    }

    func reveal() {
        if !lastOutputs.isEmpty { NSWorkspace.shared.activateFileViewerSelecting(lastOutputs) }
    }

    // MARK: Pictures

    private static func imageToImage(_ url: URL, to target: ConvertTarget, folder: URL, name: String) throws -> URL {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil), let type = target.utType else { throw ConvertError.unreadable }
        let out = freeURL(base: folder, name: name, ext: target.fileExtension)
        guard let dest = CGImageDestinationCreateWithURL(out as CFURL, type, 1, nil) else { throw ConvertError.unsupported }
        CGImageDestinationAddImageFromSource(dest, src, 0, nil)
        guard CGImageDestinationFinalize(dest) else { throw ConvertError.failed }
        return out
    }

    private static func imageToPDF(_ url: URL, folder: URL, name: String) throws -> URL {
        guard let image = NSImage(contentsOf: url), let page = PDFPage(image: image) else { throw ConvertError.unreadable }
        let document = PDFDocument()
        document.insert(page, at: 0)
        let out = freeURL(base: folder, name: name, ext: "pdf")
        guard document.write(to: out) else { throw ConvertError.failed }
        return out
    }

    private static func pdfToImages(_ url: URL, to target: ConvertTarget, folder: URL, name: String) throws -> [URL] {
        guard let document = PDFDocument(url: url), document.pageCount > 0, let type = target.utType else { throw ConvertError.unreadable }
        let count = min(document.pageCount, 50)
        var outputs: [URL] = []
        for index in 0..<count {
            guard let page = document.page(at: index) else { continue }
            let box = page.bounds(for: .mediaBox)
            let scale: CGFloat = 2
            let image = page.thumbnail(of: CGSize(width: box.width * scale, height: box.height * scale), for: .mediaBox)
            guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { continue }
            let out = freeURL(base: folder, name: "\(name) page \(index + 1)", ext: target.fileExtension)
            guard let dest = CGImageDestinationCreateWithURL(out as CFURL, type, 1, nil) else { continue }
            CGImageDestinationAddImage(dest, cg, nil)
            if CGImageDestinationFinalize(dest) { outputs.append(out) }
        }
        if outputs.isEmpty { throw ConvertError.failed }
        return outputs
    }

    // MARK: Video and audio

    private static func export(_ url: URL, to target: ConvertTarget, folder: URL, name: String) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let preset = target == .mp4 ? AVAssetExportPresetHighestQuality : AVAssetExportPresetAppleM4A
        guard let session = AVAssetExportSession(asset: asset, presetName: preset) else { throw ConvertError.unsupported }
        let out = freeURL(base: folder, name: name, ext: target.fileExtension)
        session.outputURL = out
        session.outputFileType = target == .mp4 ? .mp4 : .m4a
        await session.export()
        guard session.status == .completed else {
            try? FileManager.default.removeItem(at: out)
            throw session.error ?? ConvertError.failed
        }
        return out
    }
}

enum ConvertError: LocalizedError {
    case unsupported, unreadable, failed
    var errorDescription: String? {
        switch self {
        case .unsupported: return "That conversion isn't supported."
        case .unreadable: return "LifeNotch couldn't read that file."
        case .failed: return "The conversion didn't work."
        }
    }
}
