import SwiftUI
import WebKit

struct SearchView: View {
    @Environment(Router.self) private var router
    @State private var searchText = ""
    @State private var isSearching = false
    @State private var searchMode = 0 // 0: Sov2ex, 1: Google

    var body: some View {
        VStack(spacing: 0) {
            // Segment picker
            Picker("搜索方式", selection: $searchMode) {
                Text("Sov2ex").tag(0)
                Text("Google").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            if searchText.isEmpty {
                ContentUnavailableView(
                    "搜索 V2EX",
                    systemImage: "magnifyingglass",
                    description: Text("输入关键词搜索主题和内容")
                )
            } else if searchMode == 0 {
                Sov2exSearchView(query: searchText)
            } else {
                GoogleSearchWebView(
                    query: searchText,
                    isLoading: $isSearching,
                    onV2EXLink: { url in
                        handleV2EXLink(url)
                    }
                )
            }
        }
        .searchable(text: $searchText, prompt: "搜索 V2EX")
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func handleV2EXLink(_ url: URL) {
        let path = url.path
        if let match = path.firstMatch(of: /\/t\/(\d+)/),
           let id = Int(match.1) {
            router.navigateToTopic(id: id)
        } else if let match = path.firstMatch(of: /\/go\/(.+)/) {
            router.navigateToNode(name: String(match.1))
        } else if let match = path.firstMatch(of: /\/member\/(.+)/) {
            router.navigateToMember(username: String(match.1))
        }
    }
}

struct GoogleSearchWebView: UIViewRepresentable {
    let query: String
    @Binding var isLoading: Bool
    var onV2EXLink: ((URL) -> Void)?

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.onV2EXLink = onV2EXLink
        let searchQuery = "site:v2ex.com/t \(query)"
        if let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://google.com/search?q=\(encoded)") {
            if webView.url?.absoluteString.contains(encoded) != true {
                webView.load(URLRequest(url: url))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading, onV2EXLink: onV2EXLink)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool
        var onV2EXLink: ((URL) -> Void)?

        init(isLoading: Binding<Bool>, onV2EXLink: ((URL) -> Void)?) {
            _isLoading = isLoading
            self.onV2EXLink = onV2EXLink
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            // 拦截 V2EX 链接并导航到应用内页面
            if url.host?.contains("v2ex.com") == true,
               navigationAction.navigationType == .linkActivated {
                DispatchQueue.main.async {
                    self.onV2EXLink?(url)
                }
                return .cancel
            }
            return .allow
        }
    }
}
