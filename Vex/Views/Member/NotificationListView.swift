import Kingfisher
import SwiftUI

struct NotificationListView: View {
    @Environment(AuthManager.self) private var auth

    @State private var notifications: [V2EXNotification] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    private let client = V2EXClient.shared

    var body: some View {
        Group {
            if auth.isAuthed {
                LottieRefreshableScrollView {
                    if !auth.isDemoMode { await loadNotifications(page: 1) }
                } content: {
                    LazyVStack(spacing: 0) {
                        ForEach(notifications) { notification in
                            NavigationLink {
                                TopicDetailView(
                                    topicId: notification.topic.id,
                                    brief: notification.topic,
                                    scrollToReplyNum: notification.topic.replies > 0 ? notification.topic.replies : nil
                                )
                            } label: {
                                NotificationRow(notification: notification)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .onAppear {
                                if notification.id == notifications.last?.id, currentPage < totalPages {
                                    Task { await loadMore() }
                                }
                            }
                            Divider()
                        }

                        if isLoading && !notifications.isEmpty {
                            ProgressView()
                                .padding(.vertical, 16)
                        }
                    }
                }
                .overlay {
                    if isLoading && notifications.isEmpty {
                        LottieLoadingView()
                    } else if let error, notifications.isEmpty {
                        ContentUnavailableView(
                            "加载失败",
                            systemImage: "exclamationmark.triangle",
                            description: Text(error)
                        )
                    }
                }
                .task {
                    if auth.isDemoMode {
                        notifications = Self.demoNotifications
                    } else {
                        await loadNotifications(page: 1)
                    }
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

    private func loadNotifications(page: Int) async {
        isLoading = true
        if page == 1 {
            error = nil
        }
        do {
            let response = try await client.getNotifications(page: page)
            if page == 1 {
                notifications = response.data
            } else {
                notifications.append(contentsOf: response.data)
            }
            currentPage = response.pagination.current
            totalPages = response.pagination.total
            auth.refreshUnreadCount()
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMore() async {
        guard !isLoading, currentPage < totalPages else { return }
        await loadNotifications(page: currentPage + 1)
    }

    static let demoNotifications: [V2EXNotification] = [
        V2EXNotification(
            id: "demo-1",
            member: MemberBasic(username: "livid", avatarMini: "", avatarNormal: "https://cdn.v2ex.com/gravatar/?s=48&d=retro", avatarLarge: ""),
            topic: TopicBasic(id: 999001, title: "Welcome to V2EX Community", replies: 42),
            action: .reply,
            contentRendered: "<p>Great to see new members joining the community!</p>",
            time: "2 小时前"
        ),
        V2EXNotification(
            id: "demo-2",
            member: MemberBasic(username: "developer", avatarMini: "", avatarNormal: "https://cdn.v2ex.com/gravatar/?s=48&d=identicon", avatarLarge: ""),
            topic: TopicBasic(id: 999002, title: "SwiftUI 开发经验分享", replies: 18),
            action: .thank,
            contentRendered: "",
            time: "5 小时前"
        ),
        V2EXNotification(
            id: "demo-3",
            member: MemberBasic(username: "designer", avatarMini: "", avatarNormal: "https://cdn.v2ex.com/gravatar/?s=48&d=monsterid", avatarLarge: ""),
            topic: TopicBasic(id: 999003, title: "iOS 18 新特性讨论", replies: 67),
            action: .reply,
            contentRendered: "<p>非常赞同你的观点，期待更多分享</p>",
            time: "昨天"
        ),
    ]
}

struct NotificationRow: View {
    @EnvironmentObject private var settings: AppSettingsManager
    let notification: V2EXNotification

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if settings.showAvatar {
                KFImage(URL(string: HTMLParser.resolveURL(notification.member.avatarNormal)))
                    .resizable()
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            }

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
            .frame(maxWidth: .infinity, alignment: .leading)
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
