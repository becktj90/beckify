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
        config.userContentController.add(context.coordinator, name: "switchgearExport")
        config.userContentController.add(context.coordinator, name: "switchgearSave")
        if let saved = UserDefaults.standard.string(forKey: "beckify.switchgear.project"),
           let data = try? JSONEncoder().encode(saved),
           let literal = String(data: data, encoding: .utf8) {
            config.userContentController.addUserScript(WKUserScript(
                source: "window.beckifySwitchgearProject = \(literal);",
                injectionTime: .atDocumentStart, forMainFrameOnly: true
            ))
        }
        config.setURLSchemeHandler(context.coordinator.schemeHandler, forURLScheme: SwitchgearLogicLabOrigin.scheme)

        let page = WKWebpagePreferences()
        page.allowsContentJavaScript = true
        page.preferredContentMode = .mobile
        config.defaultWebpagePreferences = page

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        context.coordinator.webView = webView
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

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "switchgearExport")
        webView.configuration.userContentController.removeScriptMessageHandler(forName: "switchgearSave")
        webView.navigationDelegate = nil
        webView.uiDelegate = nil
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler {
        let schemeHandler = SwitchgearLogicLabSchemeHandler()
        weak var webView: WKWebView?
        private var exportURL: URL?

        private var presenter: UIViewController? {
            var controller = webView?.window?.rootViewController
            while let presented = controller?.presentedViewController { controller = presented }
            return controller
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.frameInfo.isMainFrame,
                  message.frameInfo.request.url?.scheme == SwitchgearLogicLabOrigin.scheme else { return }
            if message.name == "switchgearSave" {
                if let serialized = message.body as? String, serialized.utf8.count <= 2 * 1024 * 1024 {
                    UserDefaults.standard.set(serialized, forKey: "beckify.switchgear.project")
                }
                return
            }
            guard let payload = message.body as? [String: Any],
                  let filename = payload["filename"] as? String,
                  let content = payload["content"] as? String,
                  content.utf8.count <= 8 * 1024 * 1024,
                  let presenter else { return }
            let safeName = (filename as NSString).lastPathComponent
            guard !safeName.isEmpty, ["json", "html", "csv"].contains((safeName as NSString).pathExtension) else { return }
            do {
                let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(safeName)
                try content.write(to: url, atomically: true, encoding: .utf8)
                exportURL = url
                let sheet = UIActivityViewController(activityItems: [url], applicationActivities: nil)
                sheet.popoverPresentationController?.sourceView = webView
                sheet.popoverPresentationController?.sourceRect = webView?.bounds ?? .zero
                sheet.completionWithItemsHandler = { [weak self] _, _, _, _ in
                    try? FileManager.default.removeItem(at: directory)
                    self?.exportURL = nil
                }
                presenter.present(sheet, animated: true)
            } catch {
                let alert = UIAlertController(title: "Could not export", message: error.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                presenter.present(alert, animated: true)
            }
        }

        func webView(_ webView: WKWebView, runJavaScriptAlertPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping () -> Void) {
            guard let presenter else { completionHandler(); return }
            let alert = UIAlertController(title: "Switchgear Logic Lab", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, runJavaScriptConfirmPanelWithMessage message: String, initiatedByFrame frame: WKFrameInfo, completionHandler: @escaping (Bool) -> Void) {
            guard let presenter else { completionHandler(false); return }
            let alert = UIAlertController(title: "Switchgear Logic Lab", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in completionHandler(false) })
            alert.addAction(UIAlertAction(title: "Continue", style: .default) { _ in completionHandler(true) })
            presenter.present(alert, animated: true)
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            let url = navigationAction.request.url
            decisionHandler(url?.scheme == SwitchgearLogicLabOrigin.scheme && url?.host == SwitchgearLogicLabOrigin.host ? .allow : .cancel)
        }
    }
}

/// Catalog entry point: manual logic entry, one-line view, scripted
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
