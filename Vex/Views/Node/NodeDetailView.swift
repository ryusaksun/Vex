import Kingfisher
import SwiftUI

struct NodeDetailView: View {
    let nodeName: String
    var brief: NodeBasic?

    @Environment(AlertManager.self) private var alert

    @State private var node: NodeDetail?
    @State private var feeds: [NodeTopicFeed] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: String?

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
                    Color.clear
                        .frame(height: 1)
                        .onGeometryChange(for: Bool.self) { proxy in
                            proxy.frame(in: .global).minY < UIScreen.main.bounds.height + 120
                        } action: { isNearBottom in
                            guard isNearBottom else { return }
                            Task { await loadMore() }
                        }
                }

                if isLoadingMore {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .listRowSeparator(.hidden)
                }
            }
        }
        .listStyle(.plain)
        .navigationTitle(brief?.title ?? nodeName)
        .navigationBarTitleDisplayMode(.inline)
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
            await loadFeeds(page: 1)
        }
        .overlay {
            if isLoading && node == nil && feeds.isEmpty {
                LottieLoadingView()
            } else if let error, feeds.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadFeeds(page: 1)
        }
    }

    private func loadFeeds(page: Int) async {
        if page == 1 {
            isLoading = true
            error = nil
        }
        do {
            let response = try await client.getNodeFeeds(name: nodeName, page: page)
            if page == 1 {
                feeds = response.data
            } else {
                feeds.append(contentsOf: response.data)
            }
            currentPage = response.pagination.current
            totalPages = response.pagination.total

            // Load/refresh node detail
            if node == nil || page == 1 {
                node = try await client.getNodeDetail(name: nodeName)
            }
        } catch {
            self.error = error.localizedDescription
        }
        if page == 1 {
            isLoading = false
        }
    }

    private func loadMore() async {
        guard !isLoading, !isLoadingMore, currentPage < totalPages else { return }
        isLoadingMore = true
        await loadFeeds(page: currentPage + 1)
        isLoadingMore = false
    }

    private func toggleCollect() async {
        guard let currentNode = node else { return }
        do {
            if currentNode.collected {
                try await client.uncollectNode(name: nodeName)
            } else {
                try await client.collectNode(name: nodeName)
            }
            node?.collected.toggle()
            HapticManager.notification(.success)
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }
}

struct NodeTopicRow: View {
    @EnvironmentObject private var settings: AppSettingsManager
    let feed: NodeTopicFeed

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if settings.showAvatar {
                KFImage(URL(string: HTMLParser.resolveURL(feed.member.avatarNormal)))
                    .resizable()
                    .placeholder {
                        Circle().fill(.quaternary)
                    }
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }

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
