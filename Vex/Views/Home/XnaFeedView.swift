import Kingfisher
import SwiftUI

struct XnaFeedView: View {
    @State private var feeds: [XnaFeed] = []
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        List {
            ForEach(feeds) { feed in
                Link(destination: URL(string: feed.url)!) {
                    XnaFeedRow(feed: feed)
                }
            }
        }
        .listStyle(.plain)
        .refreshable {
            await loadFeeds()
        }
        .overlay {
            if isLoading && feeds.isEmpty {
                ProgressView()
            }
            if let error, feeds.isEmpty {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await loadFeeds()
        }
    }

    private func loadFeeds() async {
        isLoading = true
        error = nil
        do {
            feeds = try await client.getXnaFeeds()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }
}

struct XnaFeedRow: View {
    let feed: XnaFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(feed.title)
                .font(.body)
                .foregroundStyle(.primary)
                .lineLimit(2)

            HStack(spacing: 8) {
                KFImage(URL(string: feed.member.avatarMini))
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(Circle())

                Text(feed.member.username)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("·")
                    .foregroundStyle(.tertiary)

                Text(feed.source.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text(feed.updatedAt)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}
