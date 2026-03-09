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
                .disabled(isLoading)
            }
        }
        .listStyle(.plain)
        .overlay {
            if isLoading && results.isEmpty {
                LottieLoadingView()
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
        .task(id: query) {
            from = 0
            results = []
            hasMore = true
            error = nil
            await search(query: query, from: 0, append: false)
        }
    }

    private func search(query: String, from requestedFrom: Int, append: Bool) async {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            isLoading = false
            return
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        do {
            let hits = try await client.search(query: trimmedQuery, from: requestedFrom, size: pageSize)
            guard !Task.isCancelled else { return }

            if append {
                results.append(contentsOf: hits)
            } else {
                results = hits
            }
            from = requestedFrom
            hasMore = hits.count >= pageSize
        } catch {
            guard !Task.isCancelled else { return }
            self.error = error.localizedDescription
        }
    }

    private func loadMore() async {
        guard !isLoading, hasMore else { return }
        await search(query: query, from: from + pageSize, append: true)
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
