import SwiftUI
import WebKit

// BrowserModel.swift
// Owns the WKWebView (Apple's built-in web page viewer) and everything around it:
// loading addresses, back/forward, reader mode, zoom, pop-up blocking, download warnings,
// private mode and "ask AI about this page".
//
// Privacy facts:
//  - Normal mode keeps cookies like Safari so you stay logged in to Google Classroom etc.
//  - Private mode uses a throw-away data store: cookies, cache and form data vanish when you
//    leave private mode or quit.
//  - Camera, microphone and location requests from web pages are always refused.

final class BrowserModel: NSObject, ObservableObject, WKNavigationDelegate, WKUIDelegate {
    enum AskKind { case selection, pageText, screenshot }

    @Published var addressText = ""
    @Published var currentURL: URL?
    @Published var pageTitle = ""
    @Published var isLoading = false
    @Published var progress: Double = 0
    @Published var canGoBack = false
    @Published var canGoForward = false
    @Published var isReader = false
    @Published var blockedPopupCount = 0
    @Published var notice: String?
    @Published var zoom: Double = 1.0 {
        didSet { webView.pageZoom = CGFloat(zoom) }
    }

    private(set) var webView: WKWebView
    private let settings: AppSettings
    private let history: BrowsingHistory
    private var observers: [NSKeyValueObservation] = []
    private var confirmedHosts = Set<String>()
    private var readerOriginalURL: URL?
    private var isLoadingReader = false

    init(settings: AppSettings, history: BrowsingHistory) {
        self.settings = settings
        self.history = history
        webView = BrowserModel.makeWebView(isPrivate: settings.prefs.browserPrivateMode)
        super.init()
        attach(webView)
    }

    var isPrivate: Bool { settings.prefs.browserPrivateMode }

    // MARK: Creating the web view

    private static func makeWebView(isPrivate: Bool) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = isPrivate ? WKWebsiteDataStore.nonPersistent() : WKWebsiteDataStore.default()
        config.preferences.javaScriptCanOpenWindowsAutomatically = false
        config.mediaTypesRequiringUserActionForPlayback = .all     // no autoplay
        config.applicationNameForUserAgent = "Version/17.0 Safari/605.1.15"
        let view = WKWebView(frame: .zero, configuration: config)
        view.allowsBackForwardNavigationGestures = true
        return view
    }

    private func attach(_ view: WKWebView) {
        view.navigationDelegate = self
        view.uiDelegate = self
        view.pageZoom = CGFloat(zoom)
        observers = [
            view.observe(\.url) { [weak self] _, _ in self?.syncState() },
            view.observe(\.title) { [weak self] _, _ in self?.syncState() },
            view.observe(\.isLoading) { [weak self] _, _ in self?.syncState() },
            view.observe(\.canGoBack) { [weak self] _, _ in self?.syncState() },
            view.observe(\.canGoForward) { [weak self] _, _ in self?.syncState() },
            view.observe(\.estimatedProgress) { [weak self] _, _ in self?.syncState() }
        ]
    }

    private func syncState() {
        DispatchQueue.main.async {
            let view = self.webView
            self.currentURL = view.url
            self.pageTitle = view.title ?? ""
            self.isLoading = view.isLoading
            self.progress = view.estimatedProgress
            self.canGoBack = view.canGoBack
            self.canGoForward = view.canGoForward
        }
    }

    /// Switches private mode on/off. This starts a fresh web view (the old one is discarded).
    func setPrivate(_ on: Bool) {
        settings.prefs.browserPrivateMode = on
        observers.removeAll()
        webView.stopLoading()
        webView = BrowserModel.makeWebView(isPrivate: on)
        attach(webView)
        currentURL = nil
        pageTitle = ""
        addressText = ""
        isReader = false
        confirmedHosts.removeAll()
        objectWillChange.send()
        notice = on ? "Private mode: no history, and cookies/form data are thrown away when you leave." : nil
    }

    // MARK: Loading

    /// Called when you press Return in the address bar.
    func load(_ input: String) {
        guard let url = BrowserURLResolver.resolve(input, engine: settings.prefs.searchEngine) else { return }
        open(url)
    }

    func open(_ url: URL) {
        notice = nil
        isReader = false
        addressText = url.absoluteString
        webView.load(URLRequest(url: url))
    }

    func goBack() { webView.goBack() }
    func goForward() { webView.goForward() }
    func reload() {
        if isReader, let original = readerOriginalURL { open(original) } else { webView.reload() }
    }
    func stop() { webView.stopLoading() }
    func zoomIn() { zoom = min(3.0, zoom + 0.1) }
    func zoomOut() { zoom = max(0.5, zoom - 0.1) }
    func zoomReset() { zoom = 1.0 }

    func openInDefaultBrowser() {
        guard let url = currentURL else { return }
        NSWorkspace.shared.open(url)
    }

    func copyLink() {
        guard let url = currentURL else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url.absoluteString, forType: .string)
        notice = "Link copied."
    }

    func goHome() {
        webView.stopLoading()
        webView.loadHTMLString("", baseURL: nil)
        currentURL = nil
        addressText = ""
        isReader = false
    }

    // MARK: JavaScript helpers

    @MainActor
    private func runJS(_ script: String) async -> Any? {
        await withCheckedContinuation { continuation in
            webView.evaluateJavaScript(script) { result, _ in
                continuation.resume(returning: result)
            }
        }
    }

    @MainActor
    private func snapshotPNG() async -> Data? {
        await withCheckedContinuation { continuation in
            webView.takeSnapshot(with: nil) { image, _ in
                guard let image = image,
                      let tiff = image.tiffRepresentation,
                      let rep = NSBitmapImageRep(data: tiff),
                      let png = rep.representation(using: .png, properties: [:]) else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: png)
            }
        }
    }

    // MARK: Focus Reader (distraction-free text)

    private static let readerScript = #"""
    (function () {
      function len(e) { return ((e.innerText || '').trim()).length; }
      var best = null, bestLen = 0;
      document.querySelectorAll('article, main, [role=main], #content, .post, .article, .entry-content, .post-content')
        .forEach(function (c) { var l = len(c); if (l > bestLen) { best = c; bestLen = l; } });
      if (!best || bestLen < 400) {
        var map = new Map();
        document.querySelectorAll('p').forEach(function (p) {
          var par = p.parentElement; if (!par) return;
          map.set(par, (map.get(par) || 0) + len(p));
        });
        map.forEach(function (v, k) { if (v > bestLen) { best = k; bestLen = v; } });
      }
      if (!best) return null;
      var parts = [];
      best.querySelectorAll('h1,h2,h3,p,li,blockquote,pre').forEach(function (el) {
        var t = (el.innerText || '').trim();
        if (t.length > 0) parts.push({ tag: el.tagName.toLowerCase(), text: t });
      });
      return JSON.stringify({ title: document.title, parts: parts });
    })()
    """#

    @MainActor
    func toggleReader() async {
        if isReader {
            if let original = readerOriginalURL { open(original) }
            return
        }
        guard let url = currentURL else { notice = "Open a page first."; return }
        guard let json = await runJS(Self.readerScript) as? String,
              let data = json.data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let rawParts = object["parts"] as? [[String: Any]], !rawParts.isEmpty else {
            notice = "Focus Reader couldn't find a main article on this page."
            return
        }
        let title = (object["title"] as? String) ?? ""
        var parts: [(tag: String, text: String)] = []
        for item in rawParts {
            if let tag = item["tag"] as? String, let text = item["text"] as? String { parts.append((tag, text)) }
        }
        readerOriginalURL = url
        isLoadingReader = true
        webView.loadHTMLString(Self.readerHTML(title: title, parts: parts), baseURL: url)
    }

    private static func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func readerHTML(title: String, parts: [(tag: String, text: String)]) -> String {
        var body = "<h1>\(escape(title))</h1>"
        for part in parts {
            switch part.tag {
            case "h1", "h2", "h3": body += "<\(part.tag)>\(escape(part.text))</\(part.tag)>"
            case "li": body += "<p class='li'>• \(escape(part.text))</p>"
            case "blockquote": body += "<blockquote>\(escape(part.text))</blockquote>"
            case "pre": body += "<pre>\(escape(part.text))</pre>"
            default: body += "<p>\(escape(part.text))</p>"
            }
        }
        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <style>
        :root { color-scheme: light dark; }
        body { max-width: 640px; margin: 24px auto; padding: 0 18px; font: 17px/1.65 -apple-system, Helvetica, sans-serif; }
        h1 { font-size: 1.5em; line-height: 1.25; } h2, h3 { margin-top: 1.6em; }
        p.li { margin: 0.3em 0 0.3em 0.8em; }
        blockquote { border-left: 3px solid #888; margin-left: 0; padding-left: 14px; color: #888; }
        pre { white-space: pre-wrap; background: rgba(128,128,128,.15); padding: 10px; border-radius: 8px; }
        </style></head><body>\(body)</body></html>
        """
    }

    // MARK: Ask AI / save

    @MainActor
    func askAI(_ kind: AskKind, ai: AIViewModel, notch: NotchState) async {
        guard let url = currentURL else { notice = "Open a page first."; return }
        let header = "About this web page: \(pageTitle.isEmpty ? url.host ?? "" : pageTitle) (\(url.absoluteString))"
        switch kind {
        case .selection:
            let selection = ((await runJS("window.getSelection().toString()")) as? String) ?? ""
            let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { notice = "Select some text on the page first."; return }
            ai.prefill(text: "\(header)\n\nSelected text:\n\(String(trimmed.prefix(8000)))\n\nExplain this simply.", mode: .explainSimply)
        case .pageText:
            let text = ((await runJS("document.body ? document.body.innerText : ''")) as? String) ?? ""
            ai.prefill(text: "\(header)\n\nPage text:\n\(String(text.prefix(15000)))\n\nSummarise this page.", mode: .summarise)
        case .screenshot:
            guard let png = await snapshotPNG(),
                  let attachment = try? AttachmentLoader.imageAttachment(data: png, name: "Page screenshot.png") else {
                notice = "Couldn't take a screenshot of the page."
                return
            }
            ai.prefill(text: "\(header)\n\nWhat does this screenshot show? Identify any questions, diagrams or charts.",
                       mode: .summarise, attachments: [attachment])
        }
        notch.selectedTab = .ai
    }

    @MainActor
    func saveAsNote(to notes: NotesStore) async {
        guard let url = currentURL else { notice = "Open a page first."; return }
        let selection = ((await runJS("window.getSelection().toString()")) as? String) ?? ""
        var body = url.absoluteString
        let trimmed = selection.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { body += "\n\n" + trimmed }
        notes.add(title: pageTitle.isEmpty ? (url.host ?? "Web page") : pageTitle, body: body, source: "Web page")
        notice = "Saved to your study notes."
        SoundPlayer.play(.success)
    }

    /// The selected text on the page (empty if none). Used for "Add as assignment".
    @MainActor
    func selectedText() async -> String {
        (((await runJS("window.getSelection().toString()")) as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: Pins

    var isCurrentPagePinned: Bool {
        guard let url = currentURL else { return false }
        return settings.prefs.pinnedSites.contains { $0.url == url.absoluteString }
    }

    func togglePinCurrent() {
        guard let url = currentURL else { return }
        if let index = settings.prefs.pinnedSites.firstIndex(where: { $0.url == url.absoluteString }) {
            settings.prefs.pinnedSites.remove(at: index)
        } else {
            settings.prefs.pinnedSites.append(PinnedSite(title: pageTitle.isEmpty ? (url.host ?? "Site") : pageTitle,
                                                         url: url.absoluteString))
        }
    }

    // MARK: Safety prompts

    private func offerExternalOpen(_ url: URL, reason: String) {
        DispatchQueue.main.async {
            let host = url.host ?? "this site"
            let proceed = ModalHelper.confirm(
                title: "This link wants to download a file",
                message: "\(url.lastPathComponent) from \(host)\n\nFiles from unknown sites can contain harmful software. LifeNotch never downloads files itself. If you trust this site you can open the link in your default browser, which has its own download protections.",
                confirmTitle: "Open in default browser"
            )
            if proceed { NSWorkspace.shared.open(url) }
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else { decisionHandler(.cancel); return }
        let isMainFrame = navigationAction.targetFrame?.isMainFrame ?? true

        if isMainFrame {
            let scheme = url.scheme?.lowercased() ?? ""
            if !["http", "https", "about"].contains(scheme) {
                decisionHandler(.cancel)
                notice = "Blocked a link that tried to open \"\(scheme):\" (not a normal web page)."
                return
            }
            if navigationAction.shouldPerformDownload {
                decisionHandler(.cancel)
                offerExternalOpen(url, reason: "download")
                return
            }
            let risk = URLSafety.assess(url)
            if risk.isDownload {
                decisionHandler(.cancel)
                offerExternalOpen(url, reason: "download")
                return
            }
            if settings.prefs.warnOnRiskyLinks, !risk.warnings.isEmpty,
               let host = url.host, !confirmedHosts.contains(host) {
                decisionHandler(.cancel)
                DispatchQueue.main.async {
                    let proceed = ModalHelper.confirm(
                        title: "This link looks suspicious",
                        message: risk.warnings.joined(separator: "\n\n") + "\n\n\(url.absoluteString)",
                        confirmTitle: "Open anyway"
                    )
                    if proceed {
                        self.confirmedHosts.insert(host)
                        self.webView.load(URLRequest(url: url))
                    }
                }
                return
            }
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationResponse: WKNavigationResponse,
                 decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        let disposition = (navigationResponse.response as? HTTPURLResponse)?
            .value(forHTTPHeaderField: "Content-Disposition")?.lowercased() ?? ""
        if navigationResponse.isForMainFrame, (!navigationResponse.canShowMIMEType || disposition.contains("attachment")) {
            decisionHandler(.cancel)
            if let url = navigationResponse.response.url { offerExternalOpen(url, reason: "download") }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if isLoadingReader {
            isLoadingReader = false
            isReader = true
        } else {
            isReader = false
            if let url = webView.url, url.scheme != "about" { addressText = url.absoluteString }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard settings.prefs.browserHistoryEnabled, !isPrivate, !isReader,
              let url = webView.url, url.scheme == "http" || url.scheme == "https" else { return }
        history.record(title: webView.title ?? "", url: url)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        reportLoadError(error)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        reportLoadError(error)
    }

    private func reportLoadError(_ error: Error) {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled { return }
        notice = "Couldn't load the page: \(nsError.localizedDescription)"
    }

    // MARK: WKUIDelegate

    /// Pop-ups and target=_blank links. Pop-ups are blocked; real link clicks open in this same view.
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.navigationType == .linkActivated {
            webView.load(navigationAction.request)
        } else if settings.prefs.blockPopups {
            blockedPopupCount += 1
            notice = "Pop-up blocked (\(blockedPopupCount) so far)."
        } else {
            webView.load(navigationAction.request)
        }
        return nil
    }

    /// Web pages asking for the camera or microphone are always refused.
    func webView(_ webView: WKWebView,
                 requestMediaCapturePermissionFor origin: WKSecurityOrigin,
                 initiatedByFrame frame: WKFrameInfo,
                 type: WKMediaCaptureType,
                 decisionHandler: @escaping (WKPermissionDecision) -> Void) {
        decisionHandler(.deny)
    }
}
