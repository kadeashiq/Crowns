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
    func snapshot(of url: URL, attachedTo host: UIView?, timeout: TimeInterval = 14) async -> PageSnapshot? {
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

    private func read(_ web: WKWebView, started: Date, timeout: TimeInterval) async -> PageSnapshot? {
        // Most of a load is images and trackers the form doesn't need. A page
        // that has given a whole listing, the same one twice running, is done.
        var previous: ListingDraft?
        while !isLoaded, Date().timeIntervalSince(started) < timeout {
            await waitForLoad(limit: Self.probeInterval)
            if isLoaded { break }
            guard isCommitted, await mayHoldListing(web), let snapshot = await evaluate(in: web),
                  let draft = wholeListing(in: snapshot) else {
                previous = nil
                continue
            }
            if draft == previous { return snapshot }
            previous = draft
        }
        guard !Task.isCancelled else { return nil }

        // A page that was already giving a whole listing needs no more time.
        if previous != nil, let snapshot = await evaluate(in: web), wholeListing(in: snapshot) != nil {
            return snapshot
        }

        // Give client-rendered pages a moment, then retry once if the first
        // read found nothing product-like.
        try? await Task.sleep(for: .milliseconds(700))
        var result = await evaluate(in: web)
        let remaining = timeout - Date().timeIntervalSince(started)
        if remaining > 1.5, result.map({ !$0.hasStructuredData && ($0.images ?? []).isEmpty }) ?? true {
            try? await Task.sleep(for: .milliseconds(1500))
            result = await evaluate(in: web) ?? result
        }
        return result
    }

    /// The listing, if the page gives all of it.
    private func wholeListing(in snapshot: PageSnapshot) -> ListingDraft? {
        guard snapshot.hasStructuredData, !(snapshot.specs ?? []).isEmpty, !(snapshot.images ?? []).isEmpty else { return nil }
        let draft = ListingInterpreter.interpret(snapshot)
        return !draft.brand.isEmpty && !draft.model.isEmpty && draft.price != nil && !draft.imageURLs.isEmpty ? draft : nil
    }

    /// A cheap look before running the full extractor. A page without
    /// structured data can never finish early, so isn't worth reading yet.
    private func mayHoldListing(_ web: WKWebView) async -> Bool {
        let script = """
            return document.readyState !== "loading" && document.querySelector('script[type="application/ld+json"], meta[property$="price:amount"], meta[name$="price:amount"]') !== null;
            """
        let found = try? await web.callAsyncJavaScript(script, arguments: [:], in: nil, contentWorld: .defaultClient)
        return found as? Bool ?? false
    }

    private func evaluate(in web: WKWebView) async -> PageSnapshot? {
        // Opens spec dropdowns first: some sites only fill them in once opened.
        let body = ExtractorScript.source + """

            await new Promise(function (done) { CrownsExtractor.expand(done); });
            return CrownsExtractor.snapshot();
            """
        do {
            let value = try await web.callAsyncJavaScript(body, arguments: [:], in: nil, contentWorld: .defaultClient)
            return (value as? String).flatMap(PageSnapshot.decode)
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
