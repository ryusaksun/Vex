import SwiftUI
import WebKit

struct AutoSizingWebView: UIViewRepresentable {
    let html: String
    var onLinkTapped: ((URL) -> Void)?
    var onImageTapped: ((URL) -> Void)?

    @Binding var contentHeight: CGFloat

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Add message handler for height updates
        let userContentController = WKUserContentController()
        userContentController.add(context.coordinator, name: "heightChanged")
        userContentController.add(context.coordinator, name: "imageTapped")
        config.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no">
        <style>
            * { margin: 0; padding: 0; box-sizing: border-box; }
            body {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                color: #1a1a1a;
                word-wrap: break-word;
                overflow-wrap: break-word;
                -webkit-text-size-adjust: 100%;
            }
            @media (prefers-color-scheme: dark) {
                body { color: #e5e5e5; }
                a { color: #58a6ff; }
                pre, code { background: #1e1e1e; }
                blockquote { border-color: #444; color: #999; }
            }
            a { color: #3b82f6; text-decoration: none; }
            img {
                max-width: 100%;
                height: auto;
                border-radius: 4px;
                cursor: pointer;
            }
            pre {
                background: #f5f5f5;
                padding: 12px;
                border-radius: 8px;
                overflow-x: auto;
                font-size: 14px;
            }
            code {
                background: #f5f5f5;
                padding: 2px 6px;
                border-radius: 4px;
                font-size: 14px;
            }
            pre code { background: none; padding: 0; }
            blockquote {
                border-left: 3px solid #d1d5db;
                padding-left: 12px;
                margin: 8px 0;
                color: #6b7280;
            }
            p { margin-bottom: 8px; }
            p:last-child { margin-bottom: 0; }
        </style>
        <script>
            function reportHeight() {
                const height = document.body.scrollHeight;
                window.webkit.messageHandlers.heightChanged.postMessage(height);
            }
            window.onload = function() {
                reportHeight();
                // Observe for dynamic changes
                new ResizeObserver(reportHeight).observe(document.body);
            };
            document.addEventListener('click', function(e) {
                if (e.target.tagName === 'IMG') {
                    e.preventDefault();
                    window.webkit.messageHandlers.imageTapped.postMessage(e.target.src);
                }
            });
        </script>
        </head>
        <body>\(html)</body>
        </html>
        """
        let currentHTML = context.coordinator.lastHTML
        if currentHTML != html {
            context.coordinator.lastHTML = html
            webView.loadHTMLString(styledHTML, baseURL: URL(string: "https://www.v2ex.com"))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let parent: AutoSizingWebView
        var lastHTML = ""

        init(parent: AutoSizingWebView) {
            self.parent = parent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "heightChanged", let height = message.body as? CGFloat {
                DispatchQueue.main.async {
                    self.parent.contentHeight = height
                }
            }
            if message.name == "imageTapped", let src = message.body as? String, let url = URL(string: src) {
                DispatchQueue.main.async {
                    self.parent.onImageTapped?(url)
                }
            }
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            if navigationAction.navigationType == .linkActivated {
                DispatchQueue.main.async {
                    self.parent.onLinkTapped?(url)
                }
                return .cancel
            }
            return .allow
        }
    }
}
