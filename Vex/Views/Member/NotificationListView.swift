import Kingfisher
import SwiftUI

struct NotificationListView: View {
    @Environment(AuthManager.self) private var auth

    @State private var notifications: [V2EXNotification] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false

    private let client = V2EXClient.shared

    var body: some View {
        Group {
            if auth.isAuthed {
                List {
                    ForEach(notifications) { notification in
                        NavigationLink(value: notification.topic) {
                            NotificationRow(notification: notification)
                        }
                    }

                    if currentPage < totalPages {
                        Button("加载更多") {
                            Task { await loadMore() }
                        }
                    }
                }
                .listStyle(.plain)
                .navigationDestination(for: TopicBasic.self) { topic in
                    TopicDetailView(topicId: topic.id, brief: topic)
                }
                .refreshable {
                    currentPage = 1
                    await loadNotifications()
                }
                .overlay {
                    if isLoading && notifications.isEmpty {
                        ProgressView()
                    }
                }
                .task {
                    await loadNotifications()
                }
            } else {
                ContentUnavailableView(
                    "需要登录",
                    systemImage: "bell.slash",
                    description: Text("登录后可查看消息通知")
                )
            }
        }
        .navigationTitle("消息")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func loadNotifications() async {
        isLoading = true
        do {
            let response = try await client.getNotifications(page: currentPage)
            if currentPage == 1 {
                notifications = response.data
            } else {
                notifications.append(contentsOf: response.data)
            }
            totalPages = response.pagination.total
        } catch {}
        isLoading = false
    }

    private func loadMore() async {
        currentPage += 1
        await loadNotifications()
    }
}

struct NotificationRow: View {
    let notification: V2EXNotification

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            KFImage(URL(string: HTMLParser.resolveURL(notification.member.avatarNormal)))
                .resizable()
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(notification.member.username)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(actionText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(notification.topic.title)
                    .font(.subheadline)
                    .lineLimit(2)

                if !notification.contentRendered.isEmpty {
                    HTMLContentView(html: notification.contentRendered)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(notification.time)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    private var actionText: String {
        switch notification.action {
        case .reply: return "回复了"
        case .collect: return "收藏了"
        case .thank: return "感谢了"
        case .thankReply: return "感谢了回复"
        }
    }
}
