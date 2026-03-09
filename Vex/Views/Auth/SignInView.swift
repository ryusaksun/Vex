import SwiftUI
import WebKit

struct SignInView: View {
    @Environment(AuthManager.self) private var auth
    @Environment(\.dismiss) private var dismiss

    @State private var isLoading = true

    var body: some View {
        SignInWebView(
            isLoading: $isLoading,
            onSignInSuccess: {
                Task {
                    await auth.checkAuth(forceRefresh: true)
                    dismiss()
                }
            }
        )
        .navigationTitle("登录")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                LottieLoadingView()
            }
        }
    }
}

struct SignInWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    let onSignInSuccess: () -> Void

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        // 使用 Safari UA，避免 Google OAuth 拒绝嵌入式 WebView
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

        if let url = URL(string: "https://www.v2ex.com/signin") {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onSignInSuccess: onSignInSuccess)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        let onSignInSuccess: () -> Void

        init(isLoading: Binding<Bool>, onSignInSuccess: @escaping () -> Void) {
            _isLoading = isLoading
            self.onSignInSuccess = onSignInSuccess
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false

            // 登录成功：回到 v2ex.com 且不在 /signin 或 /2fa 页面
            guard let url = webView.url,
                  let host = url.host,
                  host.contains("v2ex.com"),
                  !url.path.contains("/signin"),
                  !url.path.contains("/2fa") else { return }

            // Sync cookies to shared storage
            WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                for cookie in cookies {
                    HTTPCookieStorage.shared.setCookie(cookie)
                }
                DispatchQueue.main.async {
                    self.onSignInSuccess()
                }
            }
        }
    }
}
