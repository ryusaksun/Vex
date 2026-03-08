import SwiftUI

struct CollectedTopicsView: View {
    @State private var topics: [CollectedTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        List {
            ForEach(topics) { feed in
                NavigationLink(value: feed.topic) {
                    CollectedTopicRow(feed: feed)
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
        .navigationTitle("收藏的主题")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TopicBasic.self) { topic in
            TopicDetailView(topicId: topic.id, brief: topic)
        }
        .refreshable {
            currentPage = 1
            await loadTopics()
        }
        .overlay {
            if isLoading && topics.isEmpty {
                ProgressView()
            }
            if let error, topics.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
            if !isLoading && error == nil && topics.isEmpty {
                ContentUnavailableView(
                    "暂无收藏",
                    systemImage: "star",
                    description: Text("收藏的主题会显示在这里")
                )
            }
        }
        .task {
            await loadTopics()
        }
    }

    private func loadTopics() async {
        isLoading = true
        error = nil
        do {
            let response = try await client.getCollectedTopics(page: currentPage)
            if currentPage == 1 {
                topics = response.data
            } else {
                topics.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadTopics()
    }
}

struct CollectedTopicRow: View {
    let feed: CollectedTopicFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(feed.topic.title)
                .font(.body)
                .lineLimit(2)

            HStack(spacing: 6) {
                Text(feed.node.title)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                Text(feed.member.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                if feed.topic.replies > 0 {
                    Text("\(feed.topic.replies)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.secondary)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 2)
    }
}
