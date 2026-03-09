import SwiftUI

struct MemberTopicsListView: View {
    let username: String

    @State private var topics: [MemberTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(topics) { feed in
                NavigationLink(value: feed.topic) {
                    MemberTopicRow(feed: feed)
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                Divider().padding(.leading, 16)
            }

            if currentPage < totalPages {
                Button("加载更多") {
                    Task { await loadMore() }
                }
                .padding()
                .disabled(isLoading)
            }

            if isLoading {
                LottieLoadingView()
                    .padding()
            }

            if !isLoading && topics.isEmpty {
                if let error {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.vertical, 40)
                } else {
                    Text("暂无主题")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                }
            }
        }
        .task {
            await loadTopics(page: 1)
        }
    }

    private func loadTopics(page: Int) async {
        isLoading = true
        if page == 1 {
            error = nil
        }
        do {
            let response = try await client.getMemberTopics(username: username, page: page)
            if page == 1 {
                topics = response.data
            } else {
                topics.append(contentsOf: response.data)
            }
            currentPage = response.pagination.current
            totalPages = response.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, currentPage < totalPages else { return }
        await loadTopics(page: currentPage + 1)
    }
}
