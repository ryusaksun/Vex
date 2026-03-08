import SwiftUI

struct RepliedTopicsView: View {
    let username: String

    @State private var replies: [RepliedTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        List {
            ForEach(replies) { feed in
                NavigationLink(value: feed.topic) {
                    RepliedTopicRow(feed: feed)
                }
            }

            if currentPage < totalPages {
                Button("加载更多") {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .navigationTitle("回复的主题")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TopicBasic.self) { topic in
            TopicDetailView(topicId: topic.id, brief: topic)
        }
        .refreshable {
            currentPage = 1
            await loadReplies()
        }
        .overlay {
            if isLoading && replies.isEmpty {
                ProgressView()
            }
            if let error, replies.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
            if !isLoading && error == nil && replies.isEmpty {
                ContentUnavailableView(
                    "暂无回复",
                    systemImage: "arrowshape.turn.up.left",
                    description: Text("回复的主题会显示在这里")
                )
            }
        }
        .task {
            await loadReplies()
        }
    }

    private func loadReplies() async {
        isLoading = true
        error = nil
        do {
            let response = try await client.getMemberReplies(username: username, page: currentPage)
            if currentPage == 1 {
                replies = response.data
            } else {
                replies.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadReplies()
    }
}

struct RepliedTopicRow: View {
    let feed: RepliedTopicFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(feed.topic.title)
                .font(.body)
                .lineLimit(2)

            // Reply content preview
            HTMLContentView(html: feed.replyContentRendered)
                .frame(maxHeight: 60)
                .clipped()

            HStack {
                Text(feed.replyTime)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Spacer()
            }
        }
        .padding(.vertical, 2)
    }
}
