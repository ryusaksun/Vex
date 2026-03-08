import SwiftUI
import WebKit

struct InAppBrowserView: View {
    let url: URL
    var title: String?

    @Environment(\.dismiss) private var dismiss
    @State private var pageTitle = ""
    @State private var progress: Double = 0
    @State private var canGoBack = false
    @State private var canGoForward = false
    @State private var currentURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Progress bar
            if progress > 0 && progress < 1 {
                ProgressView(value: progress)
                    .tint(.accentColor)
            }

            BrowserWebView(
                url: url,
                pageTitle: $pageTitle,
                progress: $progress,
                canGoBack: $canGoBack,
                canGoForward: $canGoForward,
                currentURL: $currentURL
            )
        }
        .navigationTitle(title ?? pageTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                Button {
                    NotificationCenter.default.post(name: .browserGoBack, object: nil)
                } label: {
                    Image(systemName: "chevron.left")
                }
                .disabled(!canGoBack)

                Button {
                    NotificationCenter.default.post(name: .browserGoForward, object: nil)
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(!canGoForward)

                Spacer()

                ShareLink(item: currentURL ?? url)

                Button {
                    UIApplication.shared.open(currentURL ?? url)
                } label: {
                    Image(systemName: "safari")
                }
            }
        }
    }
}

extension Notification.Name {
    static let browserGoBack = Notification.Name("browserGoBack")
    static let browserGoForward = Notification.Name("browserGoForward")
}

struct BrowserWebView: UIViewRepresentable {
    let url: URL
    @Binding var pageTitle: String
    @Binding var progress: Double
    @Binding var canGoBack: Bool
    @Binding var canGoForward: Bool
    @Binding var currentURL: URL?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Observe progress
        context.coordinator.progressObserver = webView.observe(\.estimatedProgress) { webView, _ in
            DispatchQueue.main.async {
                self.progress = webView.estimatedProgress
            }
        }
        context.coordinator.titleObserver = webView.observe(\.title) { webView, _ in
            DispatchQueue.main.async {
                self.pageTitle = webView.title ?? ""
            }
        }
        context.coordinator.canGoBackObserver = webView.observe(\.canGoBack) { webView, _ in
            DispatchQueue.main.async {
                self.canGoBack = webView.canGoBack
            }
        }
        context.coordinator.canGoForwardObserver = webView.observe(\.canGoForward) { webView, _ in
            DispatchQueue.main.async {
                self.canGoForward = webView.canGoForward
            }
        }
        context.coordinator.urlObserver = webView.observe(\.url) { webView, _ in
            DispatchQueue.main.async {
                self.currentURL = webView.url
            }
        }

        // Navigation notifications
        context.coordinator.backObserver = NotificationCenter.default.addObserver(
            forName: .browserGoBack, object: nil, queue: .main
        ) { _ in webView.goBack() }

        context.coordinator.forwardObserver = NotificationCenter.default.addObserver(
            forName: .browserGoForward, object: nil, queue: .main
        ) { _ in webView.goForward() }

        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, WKNavigationDelegate, @unchecked Sendable {
        var progressObserver: NSKeyValueObservation?
        var titleObserver: NSKeyValueObservation?
        var canGoBackObserver: NSKeyValueObservation?
        var canGoForwardObserver: NSKeyValueObservation?
        var urlObserver: NSKeyValueObservation?
        nonisolated(unsafe) var backObserver: Any?
        nonisolated(unsafe) var forwardObserver: Any?

        deinit {
            if let backObserver { NotificationCenter.default.removeObserver(backObserver) }
            if let forwardObserver { NotificationCenter.default.removeObserver(forwardObserver) }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            .allow
        }
    }
}
