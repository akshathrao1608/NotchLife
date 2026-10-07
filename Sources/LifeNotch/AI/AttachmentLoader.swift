import AppKit
import PDFKit
import Vision
import UniformTypeIdentifiers

// AttachmentLoader.swift
// Turns a dropped/picked file into something the AI can read, with safety limits.
//  - Images are shrunk and re-saved. That also removes hidden photo data (like GPS location).
//  - PDFs are sent as-is (max ~20 MB).
//  - Text files are truncated to a sensible length.
// OCR (reading text out of a screenshot) runs ON YOUR MAC with Apple's Vision framework:
// nothing is sent anywhere for that.

enum AttachmentError: LocalizedError {
    case unsupported(String)
    case tooLarge(String)
    case unreadable(String)

    var errorDescription: String? {
        switch self {
        case .unsupported(let name): return "\"\(name)\" isn't a supported type. Use an image, PDF or text file."
        case .tooLarge(let name): return "\"\(name)\" is too large to send."
        case .unreadable(let name): return "LifeNotch couldn't read \"\(name)\"."
        }
    }
}

enum AttachmentLoader {
    static let maxPDFBytes = 20_000_000
    static let maxTextCharacters = 60_000
    static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "heic", "tiff", "tif", "bmp"]
    static let textExtensions: Set<String> = ["txt", "md", "markdown", "csv", "json", "text", "swift", "py", "js", "html", "css", "java", "c", "cpp", "tex"]

    static func load(url: URL) throws -> AIAttachment {
        let name = url.lastPathComponent
        let ext = url.pathExtension.lowercased()
        guard let data = try? Data(contentsOf: url) else { throw AttachmentError.unreadable(name) }

        if imageExtensions.contains(ext) {
            return try imageAttachment(data: data, name: name)
        }
        if ext == "pdf" {
            guard data.count <= maxPDFBytes else { throw AttachmentError.tooLarge(name) }
            guard PDFDocument(data: data) != nil else { throw AttachmentError.unreadable(name) }
            return AIAttachment(name: name, kind: .pdf, data: data, mimeType: "application/pdf")
        }
        if textExtensions.contains(ext) {
            return try textAttachment(data: data, name: name)
        }
        throw AttachmentError.unsupported(name)
    }

    static func imageAttachment(data: Data, name: String) throws -> AIAttachment {
        guard let prepared = prepareImage(data) else { throw AttachmentError.unreadable(name) }
        return AIAttachment(name: name, kind: .image, data: prepared.data, mimeType: prepared.mime)
    }

    static func textAttachment(data: Data, name: String) throws -> AIAttachment {
        guard var text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            throw AttachmentError.unreadable(name)
        }
        if text.count > maxTextCharacters {
            text = String(text.prefix(maxTextCharacters)) + "\n[…truncated by LifeNotch]"
        }
        return AIAttachment(name: name, kind: .text, data: Data(text.utf8), mimeType: "text/plain")
    }

    /// Shrinks to at most 1568 px on the long side and re-encodes. Re-encoding drops EXIF metadata.
    static func prepareImage(_ data: Data) -> (data: Data, mime: String)? {
        guard let image = NSImage(data: data),
              let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let width = CGFloat(cg.width)
        let height = CGFloat(cg.height)
        guard width > 0, height > 0 else { return nil }
        let scale = min(1, 1568 / max(width, height))
        let newWidth = max(1, Int(width * scale))
        let newHeight = max(1, Int(height * scale))
        guard let context = CGContext(data: nil,
                                      width: newWidth,
                                      height: newHeight,
                                      bitsPerComponent: 8,
                                      bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        guard let resized = context.makeImage() else { return nil }
        let rep = NSBitmapImageRep(cgImage: resized)
        guard let png = rep.representation(using: .png, properties: [:]) else { return nil }
        if png.count > 4_500_000,
           let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
            return (jpeg, "image/jpeg")
        }
        return (png, "image/png")
    }

    // MARK: On-device text reading

    /// Reads text from an image, entirely on this Mac.
    static func recognizeText(imageData: Data) async throws -> String {
        try await Task.detached(priority: .userInitiated) { () throws -> String in
            guard let image = NSImage(data: imageData),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                throw AttachmentError.unreadable("image")
            }
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            try VNImageRequestHandler(cgImage: cg, options: [:]).perform([request])
            let observations = (request.results as? [VNRecognizedTextObservation]) ?? []
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            return lines.joined(separator: "\n")
        }.value
    }

    /// Reads the text layer of a PDF (no OCR), entirely on this Mac.
    static func pdfText(_ data: Data) -> String {
        let text = PDFDocument(data: data)?.string ?? ""
        return String(text.prefix(maxTextCharacters))
    }
}
