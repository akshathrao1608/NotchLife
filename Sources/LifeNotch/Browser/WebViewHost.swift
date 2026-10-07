import SwiftUI
import WebKit

// WebViewHost.swift
// SwiftUI can't show a WKWebView directly, so this small wrapper "hosts" it.
// It also copes with the web view being swapped (that happens when you switch private mode).

final class WebContainerView: NSView {
    private weak var current: WKWebView?

    func host(_ web: WKWebView) {
        guard current !== web else { return }
        current?.removeFromSuperview()
        web.translatesAutoresizingMaskIntoConstraints = false
        addSubview(web)
        NSLayoutConstraint.activate([
            web.leadingAnchor.constraint(equalTo: leadingAnchor),
            web.trailingAnchor.constraint(equalTo: trailingAnchor),
            web.topAnchor.constraint(equalTo: topAnchor),
            web.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        current = web
    }
}

struct WebViewHost: NSViewRepresentable {
    @ObservedObject var model: BrowserModel

    func makeNSView(context: Context) -> WebContainerView {
        let view = WebContainerView()
        view.host(model.webView)
        return view
    }

    func updateNSView(_ nsView: WebContainerView, context: Context) {
        nsView.host(model.webView)
    }
}
