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
    private var waitTimer: Task<Void, Never>?
    private var isCommitted = false
    private var isLoaded = false

    private static let probeInterval: TimeInterval = 0.4

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
        return await withTaskCancellationHandler {
            await read(web, started: started, timeout: timeout)
        } onCancel: {
            Task { @MainActor [weak self] in self?.finishLoading() }
        }
    }

    private func read(_ web: WKWebView, started: Date, timeout: TimeInterval) async -> (snapshot: PageSnapshot, json: String)? {
        // Most of a load is images and trackers the form doesn't need. A page
        // that has given a whole listing, the same one twice running, is done.
        var previous: ListingDraft?
        while !isLoaded, Date().timeIntervalSince(started) < timeout {
            await waitForLoad(limit: Self.probeInterval)
            guard !isLoaded, isCommitted, await isInteractive(web),
                  let result = await evaluate(in: web), isWholeListing(result.snapshot) else {
                previous = nil
                continue
            }
            let draft = ListingInterpreter.interpret(result.snapshot)
            if draft == previous { return result }
            previous = draft
        }
        guard !Task.isCancelled else { return nil }

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

    private func isWholeListing(_ snapshot: PageSnapshot) -> Bool {
        guard snapshot.hasStructuredData, !(snapshot.specs ?? []).isEmpty, !(snapshot.images ?? []).isEmpty else { return false }
        let draft = ListingInterpreter.interpret(snapshot)
        return !draft.brand.isEmpty && !draft.model.isEmpty && draft.price != nil && !draft.imageURLs.isEmpty
    }

    private func isInteractive(_ web: WKWebView) async -> Bool {
        let state = try? await web.callAsyncJavaScript("return document.readyState;", arguments: [:], in: nil, contentWorld: .defaultClient)
        return (state as? String).map { $0 != "loading" } ?? false
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

    /// Waits for the page to finish loading, for `limit` seconds at most.
    private func waitForLoad(limit: TimeInterval) async {
        guard !isLoaded else { return }
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            loadWaiter = continuation
            waitTimer = Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(limit))
                guard !Task.isCancelled else { return }
                self?.resumeWaiter()
            }
        }
        waitTimer?.cancel()
    }

    private func resumeWaiter() {
        loadWaiter?.resume()
        loadWaiter = nil
    }

    private func finishLoading() {
        isLoaded = true
        resumeWaiter()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        isCommitted = true
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
