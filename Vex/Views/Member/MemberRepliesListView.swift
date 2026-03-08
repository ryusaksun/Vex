import SwiftUI

struct MemberRepliesListView: View {
    let username: String

    @State private var replies: [RepliedTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false

    private let client = V2EXClient.shared

    var body: some View {
        LazyVStack(spacing: 0) {
            ForEach(replies) { feed in
                NavigationLink(value: feed.topic) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(feed.topic.title)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        HTMLContentView(html: feed.replyContentRendered)
                            .frame(maxHeight: 60)
                            .clipped()

                        Text(feed.replyTime)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
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

            if !isLoading && replies.isEmpty {
                Text("暂无回复")
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 40)
            }
        }
        .task {
            await loadReplies()
        }
    }

    private func loadReplies() async {
        isLoading = true
        do {
            let response = try await client.getMemberReplies(username: username, page: currentPage)
            if currentPage == 1 {
                replies = response.data
            } else {
                replies.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total
        } catch {}
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadReplies()
    }
}
