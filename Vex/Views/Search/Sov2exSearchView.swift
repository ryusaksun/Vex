import SwiftUI

struct Sov2exSearchView: View {
    let query: String

    @State private var results: [SearchHit] = []
    @State private var isLoading = false
    @State private var error: String?
    @State private var from = 0
    @State private var hasMore = true

    private let pageSize = 10
    private let client = V2EXClient.shared

    var body: some View {
        List {
            ForEach(results) { hit in
                NavigationLink(value: TopicBasic(
                    id: hit._source.id,
                    title: hit._source.title,
                    replies: hit._source.replies
                )) {
                    SearchResultRow(hit: hit)
                }
            }

            if hasMore && !results.isEmpty {
                Button("加载更多") {
                    Task { await loadMore() }
                }
                .frame(maxWidth: .infinity)
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: TopicBasic.self) { topic in
            TopicDetailView(topicId: topic.id, brief: topic)
        }
        .overlay {
            if isLoading && results.isEmpty {
                ProgressView()
            }
            if let error, results.isEmpty {
                ContentUnavailableView(
                    "搜索失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
            if !isLoading && error == nil && results.isEmpty && !query.isEmpty {
                ContentUnavailableView(
                    "无搜索结果",
                    systemImage: "magnifyingglass",
                    description: Text("未找到与「\(query)」相关的内容")
                )
            }
        }
        .onChange(of: query) {
            from = 0
            results = []
            hasMore = true
            Task { await search() }
        }
        .task {
            await search()
        }
    }

    private func search() async {
        guard !query.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            let hits = try await client.search(query: query, from: from, size: pageSize)
            if from == 0 {
                results = hits
            } else {
                results.append(contentsOf: hits)
            }
            hasMore = hits.count >= pageSize
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        from += pageSize
        await search()
    }
}

struct SearchResultRow: View {
    let hit: SearchHit

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Title
            Text(hit._source.title)
                .font(.body)
                .lineLimit(2)

            // Content preview
            if let highlights = hit.highlight?.content, let first = highlights.first {
                Text(stripHTML(first))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            } else if !hit._source.content.isEmpty {
                Text(hit._source.content.prefix(200))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }

            HStack(spacing: 8) {
                Text(hit._source.member)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(hit._source.created)
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Spacer()

                if hit._source.replies > 0 {
                    Text("\(hit._source.replies)")
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

    private func stripHTML(_ html: String) -> String {
        html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
    }
}
