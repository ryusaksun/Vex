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
                NavigationLink {
                    TopicDetailView(topicId: feed.topic.id, brief: feed.topic)
                } label: {
                    RepliedTopicCard(feed: feed)
                }
                .onAppear {
                    if feed.id == replies.last?.id, currentPage < totalPages {
                        Task { await loadMore() }
                    }
                }
            }

            if isLoading && !replies.isEmpty {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .listRowSeparator(.hidden)
            }
        }
        .listStyle(.plain)
        .navigationTitle("回复的主题")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable {
            await loadReplies(page: 1)
        }
        .overlay {
            if isLoading && replies.isEmpty {
                LottieLoadingView()
            } else if let error, replies.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            } else if !isLoading && replies.isEmpty {
                ContentUnavailableView(
                    "暂无回复",
                    systemImage: "arrowshape.turn.up.left",
                    description: Text("回复的主题会显示在这里")
                )
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
