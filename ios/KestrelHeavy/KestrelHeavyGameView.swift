import SwiftUI
import WebKit

/// WKWebView shell for the packed Phaser 4 game.
/// Loads `Game/index.html` from the app bundle with directory read access
/// so ES modules, vendor/phaser.min.js, and audio/ resolve offline.
struct KestrelHeavyGameView: UIViewRepresentable {
    let indexURL: URL

    static func bundledIndexURL() -> URL? {
        if let url = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Game") {
            return url
        }
        let fallback = Bundle.main.bundleURL
            .appendingPathComponent("Game", isDirectory: true)
            .appendingPathComponent("index.html")
        return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.allowsAirPlayForMediaPlayback = false
        config.allowsPictureInPictureMediaPlayback = false
        config.suppressesIncrementalRendering = false
        config.dataDetectorTypes = []

        let page = WKWebpagePreferences()
        page.allowsContentJavaScript = true
        page.preferredContentMode = .mobile
        config.defaultWebpagePreferences = page

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: Self.bootScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        ))
        config.userContentController = controller

        let webView = ArcadeWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 5 / 255, green: 5 / 255, blue: 13 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.scrollView.bounces = false
        webView.scrollView.alwaysBounceVertical = false
        webView.scrollView.alwaysBounceHorizontal = false
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.showsVerticalScrollIndicator = false
        webView.scrollView.showsHorizontalScrollIndicator = false
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        let access = indexURL.deletingLastPathComponent()
        webView.loadFileURL(indexURL, allowingReadAccessTo: access)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.loadFileURL(indexURL, allowingReadAccessTo: indexURL.deletingLastPathComponent())
        }
    }

    private static let bootScript = """
    document.documentElement.classList.add('is-ios-app');
    document.documentElement.style.webkitUserSelect = 'none';
    document.documentElement.style.webkitTouchCallout = 'none';
    document.addEventListener('gesturestart', function (e) { e.preventDefault(); }, { passive: false });
    """

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }
            let scheme = url.scheme?.lowercased() ?? ""
            if url.isFileURL || scheme == "about" || scheme == "blob" {
                decisionHandler(.allow)
                return
            }
            decisionHandler(.cancel)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            webView.becomeFirstResponder()
        }

        func webView(
            _ webView: WKWebView,
            contextMenuConfigurationForElement elementInfo: WKContextMenuElementInfo,
            completionHandler: @escaping (UIContextMenuConfiguration?) -> Void
        ) {
            completionHandler(nil)
        }
    }
}

/// Keeps hardware-keyboard / iPad key events flowing into Phaser.
final class ArcadeWebView: WKWebView {
    override var canBecomeFirstResponder: Bool { true }
}
