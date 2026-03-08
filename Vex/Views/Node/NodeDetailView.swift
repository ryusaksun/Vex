import Kingfisher
import SwiftUI

struct NodeDetailView: View {
    let nodeName: String
    var brief: NodeBasic?

    @State private var node: NodeDetail?
    @State private var feeds: [NodeTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false

    private let client = V2EXClient.shared

    var body: some View {
        List {
            // Node header
            if let node {
                Section {
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            if !node.avatarLarge.isEmpty {
                                KFImage(URL(string: HTMLParser.resolveURL(node.avatarLarge)))
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 48, height: 48)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(node.title)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                Text("\(node.topics) 个主题")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }

                        if !node.header.isEmpty {
                            HTMLContentView(html: node.header)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowSeparator(.hidden)
            }

            // Topic list
            Section {
                ForEach(feeds) { feed in
                    NavigationLink(value: feed.topic) {
                        NodeTopicRow(feed: feed)
                    }
                }

                if currentPage < totalPages {
                    Button("加载更多") {
                        Task { await loadMore() }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(brief?.title ?? nodeName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: TopicBasic.self) { topic in
            TopicDetailView(topicId: topic.id, brief: topic)
        }
        .navigationDestination(for: MemberBasic.self) { member in
            MemberDetailView(username: member.username)
        }
        .toolbar {
            if let node {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await toggleCollect() }
                    } label: {
                        Image(systemName: node.collected ? "star.fill" : "star")
                    }
                }
            }
        }
        .refreshable {
            currentPage = 1
            await loadFeeds()
        }
        .task {
            await loadFeeds()
        }
    }

    private func loadFeeds() async {
        isLoading = true
        do {
            let response = try await client.getNodeFeeds(name: nodeName, page: currentPage)
            if currentPage == 1 {
                feeds = response.data
            } else {
                feeds.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total

            // Also load node detail
            if node == nil {
                node = try await client.getNodeDetail(name: nodeName)
            }
        } catch {}
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadFeeds()
    }

    private func toggleCollect() async {
        guard var n = node else { return }
        do {
            if n.collected {
                try await client.uncollectNode(name: nodeName)
            } else {
                try await client.collectNode(name: nodeName)
            }
            node?.collected.toggle()
        } catch {}
    }
}

struct NodeTopicRow: View {
    let feed: NodeTopicFeed

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            KFImage(URL(string: HTMLParser.resolveURL(feed.member.avatarNormal)))
                .resizable()
                .placeholder {
                    Circle().fill(.quaternary)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 24, height: 24)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                Text(feed.topic.title)
                    .font(.body)
                    .lineLimit(2)

                HStack(spacing: 6) {
                    Text(feed.member.username)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if feed.topic.replies > 0 {
                        Spacer()
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
        }
        .padding(.vertical, 2)
    }
}
