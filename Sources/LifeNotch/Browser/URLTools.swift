import Foundation

// URLTools.swift
// Two helpers for the browser:
//  1. BrowserURLResolver - decides if what you typed is a web address or a search.
//  2. URLSafety          - spots links that deserve a warning (downloads, look-alike names...).

enum BrowserURLResolver {
    /// "khanacademy.org" -> https://khanacademy.org
    /// "how do volcanoes form" -> a search on your chosen engine
    static func resolve(_ raw: String, engine: SearchEngine) -> URL? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let lower = text.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: text)
        }
        if looksLikeHost(text) {
            return URL(string: "https://" + text)
        }
        return engine.searchURL(for: text)
    }

    static func looksLikeHost(_ text: String) -> Bool {
        if text.contains(" ") { return false }
        let firstPart = text.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? text
        let host = firstPart.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: true).first.map(String.init) ?? firstPart
        if host.lowercased() == "localhost" { return true }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count >= 2, labels.allSatisfy({ !$0.isEmpty }), let tld = labels.last else { return false }
        if labels.allSatisfy({ Int($0) != nil }) { return true }   // like 192.168.0.1
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-."))
        return tld.count >= 2
            && tld.allSatisfy { $0.isLetter }
            && host.unicodeScalars.allSatisfy { allowed.contains($0) }
    }
}

struct URLRisk {
    var warnings: [String] = []
    var isDownload = false
    var notSecure = false
}

enum URLSafety {
    static let downloadExtensions: Set<String> = [
        "dmg", "pkg", "exe", "msi", "app", "command", "sh", "scpt", "jar", "bat", "iso",
        "apk", "zip", "rar", "7z", "tar", "gz", "dylib", "ipa", "mpkg", "workflow"
    ]

    static func assess(_ url: URL) -> URLRisk {
        var risk = URLRisk()
        guard let host = url.host?.lowercased() else { return risk }

        if url.scheme?.lowercased() == "http" { risk.notSecure = true }

        if host.hasPrefix("xn--") || host.contains(".xn--") {
            risk.warnings.append("The site name uses look-alike characters (punycode). Scammers use these to imitate real sites.")
        }
        if isIPAddress(host) {
            risk.warnings.append("The address is a number (an IP address) instead of a normal site name.")
        }
        if url.user != nil {
            risk.warnings.append("The link has a username before the site name. This trick is used to disguise the real site.")
        }
        if host.split(separator: ".").count > 5 {
            risk.warnings.append("The site name has an unusually long chain of parts.")
        }
        if downloadExtensions.contains(url.pathExtension.lowercased()) {
            risk.isDownload = true
        }
        return risk
    }

    static func isIPAddress(_ host: String) -> Bool {
        if host.contains(":") { return true } // IPv6
        let parts = host.split(separator: ".")
        return parts.count == 4 && parts.allSatisfy { Int($0) != nil }
    }
}
