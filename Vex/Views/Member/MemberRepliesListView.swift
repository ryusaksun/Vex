import SwiftUI

struct MemberRepliesListView: View {
    let username: String

    @State private var replies: [RepliedTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

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
                .disabled(isLoading)
            }

            if isLoading {
                LottieLoadingView()
                    .padding()
            }

            if !isLoading && replies.isEmpty {
                if let error {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                    .padding(.vertical, 40)
                } else {
                    Text("暂无回复")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 40)
                }
            }
        }
        .task {
            await loadReplies(page: 1)
        }
    }

    private func loadReplies(page: Int) async {
        isLoading = true
        if page == 1 {
            error = nil
        }
        do {
            let response = try await client.getMemberReplies(username: username, page: page)
            if page == 1 {
                replies = response.data
            } else {
                replies.append(contentsOf: response.data)
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
        await loadReplies(page: currentPage + 1)
    }
}
