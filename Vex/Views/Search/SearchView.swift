import SwiftUI
import WebKit

struct SearchView: View {
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
                    isLoading: $isSearching
                )
            }
        }
        .searchable(text: $searchText, prompt: "搜索 V2EX")
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: MemberBasic.self) { member in
            MemberDetailView(username: member.username)
        }
    }
}

struct GoogleSearchWebView: UIViewRepresentable {
    let query: String
    @Binding var isLoading: Bool

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let searchQuery = "site:v2ex.com/t \(query)"
        if let encoded = searchQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
           let url = URL(string: "https://google.com/search?q=\(encoded)") {
            if webView.url?.absoluteString.contains(encoded) != true {
                webView.load(URLRequest(url: url))
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(isLoading: $isLoading)
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        @Binding var isLoading: Bool

        init(isLoading: Binding<Bool>) {
            _isLoading = isLoading
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            isLoading = true
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isLoading = false
        }

        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            guard let url = navigationAction.request.url else { return .allow }

            // Intercept V2EX links
            if url.host?.contains("v2ex.com") == true,
               navigationAction.navigationType == .linkActivated {
                return .cancel
            }
            return .allow
        }
    }
}
