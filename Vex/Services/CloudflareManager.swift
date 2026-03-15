import Combine
import Foundation
import Observation
import SwiftUI
import WebKit

extension Notification.Name {
    static let cloudflareVerificationCompleted = Notification.Name("cloudflareVerificationCompleted")
}

@Observable
@MainActor
final class CloudflareManager {
    var needsVerification = false
    var isVerifying = false

    private let client = V2EXClient.shared
    private var cancellable: AnyCancellable?

    init() {
        cancellable = client.$shouldPrepareFetch.sink { [weak self] shouldPrepareFetch in
            guard let self else { return }
            if shouldPrepareFetch {
                self.needsVerification = true
            }
        }
    }

    func checkIfNeeded() {
        if client.shouldPrepareFetch {
            needsVerification = true
        }
    }

    func verificationCompleted() {
        let shouldNotify = needsVerification || isVerifying || client.shouldPrepareFetch
        needsVerification = false
        isVerifying = false
        client.shouldPrepareFetch = false
        if shouldNotify {
            NotificationCenter.default.post(name: .cloudflareVerificationCompleted, object: nil)
        }
    }

    func startVerification() {
        isVerifying = true
    }
}

/// WKWebView wrapper for Cloudflare verification
struct CloudflareWebView: UIViewRepresentable {
    let onCompleted: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if webView.url == nil {
            let url = URL(string: "https://www.v2ex.com/")!
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCompleted: onCompleted)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let onCompleted: () -> Void
        private var hasCompleted = false

        init(onCompleted: @escaping () -> Void) {
            self.onCompleted = onCompleted
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard !hasCompleted else { return }
            // Check if we passed Cloudflare challenge
            webView.evaluateJavaScript("document.title") { [weak self] title, _ in
                guard let self, !self.hasCompleted else { return }
                if let title = title as? String,
                   !title.lowercased().contains("just a moment") {
                    self.hasCompleted = true
                    // Sync cookies，确保完成后再回调
                    let completionHandler = self.onCompleted
                    WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                        for cookie in cookies {
                            HTTPCookieStorage.shared.setCookie(cookie)
                        }
                        DispatchQueue.main.async {
                            completionHandler()
                        }
                    }
                }
            }
        }
    }
}
