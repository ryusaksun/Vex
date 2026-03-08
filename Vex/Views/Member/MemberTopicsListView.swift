import SwiftUI

struct MemberTopicsListView: View {
    let username: String

    @State private var topics: [MemberTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false

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
            }

            if isLoading {
                ProgressView()
                    .padding()
            }

            if !isLoading && topics.isEmpty {
                Text("暂无主题")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 40)
            }
        }
        .task {
            await loadTopics()
        }
    }

    private func loadTopics() async {
        isLoading = true
        do {
            let response = try await client.getMemberTopics(username: username, page: currentPage)
            if currentPage == 1 {
                topics = response.data
            } else {
                topics.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total
        } catch {}
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadTopics()
    }
}
