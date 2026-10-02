import SwiftUI
import UIKit
import WebKit

/// WKWebView shell for the bundled Switchgear Logic Lab tool. Loads
/// `switchgear-logic-lab://app/index.html` through
/// `SwitchgearLogicLabSchemeHandler` so the shared JS engine — the same
/// files served at beckify.com/toolbox/switchgear-logic-lab.html — runs
/// unmodified, offline, with no network calls.
struct SwitchgearLogicLabWebView: UIViewRepresentable {
    static func packAvailable() -> Bool {
        SwitchgearLogicLabOrigin.packRoot() != nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(context.coordinator.schemeHandler, forURLScheme: SwitchgearLogicLabOrigin.scheme)

        let page = WKWebpagePreferences()
        page.allowsContentJavaScript = true
        page.preferredContentMode = .mobile
        config.defaultWebpagePreferences = page

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = true
        webView.backgroundColor = UIColor(red: 5 / 255, green: 6 / 255, blue: 15 / 255, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.allowsBackForwardNavigationGestures = false
        webView.allowsLinkPreview = false
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        webView.load(URLRequest(url: SwitchgearLogicLabOrigin.index))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            webView.load(URLRequest(url: SwitchgearLogicLabOrigin.index))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let schemeHandler = SwitchgearLogicLabSchemeHandler()
    }
}

/// Catalog entry point. Phase 1: manual logic entry, one-line view, scripted
/// scenarios, timing chart, static lint, settled-state enumeration, and a
/// printable review export — the same screens as the web tool, since both
/// run from the one shared `/js/switchgear` engine bundled into this app.
struct SwitchgearLogicLabView: View {
    var body: some View {
        ToolScaffold(toolID: .switchgearLogicLab, immersivePlay: true) {
            if SwitchgearLogicLabWebView.packAvailable() {
                SwitchgearLogicLabWebView()
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ContentUnavailableView(
                    "Switchgear Logic Lab unavailable",
                    systemImage: "exclamationmark.triangle",
                    description: Text("The bundled web tool is missing from this build.")
                )
            }
        }
    }
}
