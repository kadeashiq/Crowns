import Foundation
import UIKit
import WebKit
import os

/// Loads a URL in an invisible WKWebView and runs the same extractor Safari
/// runs, for shares that arrive as a bare URL and for links pasted in the app.
/// A real browser engine gets through where a plain fetch is blocked, and
/// sees content rendered by JavaScript.
@MainActor
final class WebPageReader: NSObject, WKNavigationDelegate {
    private static let log = Logger(subsystem: "Crowns", category: "reader")
    private var webView: WKWebView?
    private var loadWaiter: CheckedContinuation<Void, Never>?

    /// - Parameter host: a view to attach the web view to. WebKit throttles
    ///   pages that aren't in a window, so pass the visible sheet's view.
    func snapshot(of url: URL, attachedTo host: UIView?, timeout: TimeInterval = 14) async -> (snapshot: PageSnapshot, json: String)? {
        guard !ExtractorScript.source.isEmpty else { return nil }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .nonPersistent()
        config.mediaTypesRequiringUserActionForPlayback = .all
        config.allowsInlineMediaPlayback = false
        let web = WKWebView(frame: CGRect(x: 0, y: 0, width: 390, height: 844), configuration: config)
        web.customUserAgent = UserAgent.mobileSafari
        web.navigationDelegate = self
        web.alpha = 0.011
        web.isUserInteractionEnabled = false
        host?.insertSubview(web, at: 0)
        webView = web
        defer {
            web.stopLoading()
            web.navigationDelegate = nil
            web.removeFromSuperview()
            webView = nil
        }

        let started = Date()
        web.load(URLRequest(url: url, timeoutInterval: timeout))
        await waitForLoad(timeout: timeout)

        // Give client-rendered pages a moment, then retry once if the first
        // read found nothing product-like.
        try? await Task.sleep(for: .milliseconds(700))
        var result = await evaluate(in: web)
        let remaining = timeout - Date().timeIntervalSince(started)
        if remaining > 1.5, result.map({ !$0.snapshot.hasStructuredData && ($0.snapshot.images ?? []).isEmpty }) ?? true {
            try? await Task.sleep(for: .milliseconds(1500))
            result = await evaluate(in: web) ?? result
        }
        return result
    }

    private func evaluate(in web: WKWebView) async -> (snapshot: PageSnapshot, json: String)? {
        let body = ExtractorScript.source + "\nreturn CrownsExtractor.snapshot();"
        do {
            let value = try await web.callAsyncJavaScript(body, arguments: [:], in: nil, contentWorld: .defaultClient)
            guard let json = value as? String, let snapshot = PageSnapshot.decode(json) else { return nil }
            return (snapshot, json)
        } catch {
            Self.log.error("Extractor failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func waitForLoad(timeout: TimeInterval) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadWaiter = continuation
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(timeout))
                self?.finishLoading()
            }
        }
    }

    private func finishLoading() {
        loadWaiter?.resume()
        loadWaiter = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        finishLoading()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        finishLoading()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        Self.log.error("Load failed: \(error.localizedDescription, privacy: .public)")
        finishLoading()
    }
}

enum UserAgent {
    static let mobileSafari = "Mozilla/5.0 (iPhone; CPU iPhone OS 26_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Mobile/15E148 Safari/604.1"
}
