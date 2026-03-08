import Kingfisher
import SwiftUI
import WebKit

struct TopicDetailView: View {
    let topicId: Int
    var brief: TopicBasic?

    @Environment(ViewedTopicsManager.self) private var viewedTopics
    @Environment(AuthManager.self) private var auth
    @Environment(AlertManager.self) private var alert

    @State private var topic: TopicDetail?
    @State private var replies: [TopicReply] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var error: String?

    // Sheets
    @State private var replyTarget: TopicReply?
    @State private var conversationReply: TopicReply?
    @State private var showShareSheet = false
    @State private var showEditSheet = false
    @State private var barVisible = true

    private let client = V2EXClient.shared

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let topic {
                    // Header
                    topicHeader(topic)

                    // Content
                    if !topic.contentRendered.isEmpty {
                        HTMLContentView(html: topic.contentRendered)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                    }

                    // Subtles
                    ForEach(Array(topic.subtles.enumerated()), id: \.offset) { _, subtle in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(subtle.meta)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HTMLContentView(html: subtle.contentRendered)
                        }
                        .padding()
                        .background(.fill.quaternary)
                    }

                    // Reply count divider
                    HStack {
                        Text("\(topic.replies) 条回复")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding()
                    .background(.fill.quaternary)

                    // Replies
                    ForEach(replies) { reply in
                        ReplyRow(
                            reply: reply,
                            hasConversation: hasConversation(reply),
                            onReply: {
                                replyTarget = reply
                            },
                            onThank: {
                                Task { await thankReply(reply) }
                            },
                            onShowConversation: {
                                conversationReply = reply
                            }
                        )
                        Divider().padding(.leading, 50)
                    }

                    // Load more
                    if currentPage < totalPages {
                        Button("加载更多回复") {
                            Task { await loadMoreReplies() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                    }
                }
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geo in
            geo.contentOffset.y
        } action: { oldValue, newValue in
            let delta = newValue - oldValue
            guard abs(delta) > 3 else { return }
            let shouldShow = delta < 0 || newValue < 20
            if shouldShow != barVisible {
                barVisible = shouldShow
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if topic != nil {
                TopicBottomBar(
                    topicId: topicId,
                    replyTo: replyTarget,
                    visible: barVisible,
                    onClearReplyTo: { replyTarget = nil },
                    onSubmitted: { newReply in
                        if let newReply {
                            replies.append(newReply)
                            topic?.replies += 1
                        }
                    }
                )
            }
        }
        .navigationTitle(brief?.title ?? "主题")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let topic {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            Task { await toggleCollect() }
                        } label: {
                            Label(
                                topic.collected ? "取消收藏" : "收藏",
                                systemImage: topic.collected ? "star.fill" : "star"
                            )
                        }

                        Button {
                            Task { await thankTopic() }
                        } label: {
                            Label("感谢", systemImage: topic.thanked ? "heart.fill" : "heart")
                        }
                        .disabled(topic.thanked)

                        Button {
                            showShareSheet = true
                        } label: {
                            Label("分享", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        if topic.canEdit {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("编辑", systemImage: "pencil")
                            }
                        }

                        if !topic.blocked {
                            Button(role: .destructive) {
                                Task { await blockTopic() }
                            } label: {
                                Label("忽略", systemImage: "eye.slash")
                            }
                        } else {
                            Button {
                                Task { await unblockTopic() }
                            } label: {
                                Label("取消忽略", systemImage: "eye")
                            }
                        }

                        if !topic.reported {
                            Button(role: .destructive) {
                                Task { await reportTopic() }
                            } label: {
                                Label("举报", systemImage: "flag")
                            }
                        }

                        Divider()

                        Button {
                            if let url = URL(string: "https://www.v2ex.com/t/\(topicId)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            Label("在浏览器中打开", systemImage: "safari")
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                    }
                }
            }
        }
        .overlay {
            if isLoading && topic == nil {
                TopicDetailSkeleton()
            }
        }
        .navigationDestination(for: MemberBasic.self) { member in
            MemberDetailView(username: member.username)
        }
        .navigationDestination(for: NodeBasic.self) { node in
            NodeDetailView(nodeName: node.name, brief: node)
        }
        .sheet(item: $conversationReply) { reply in
            ConversationSheet(reply: reply, allReplies: replies)
        }
        .sheet(isPresented: $showEditSheet) {
            if let topic {
                TopicEditView(
                    topicId: topicId,
                    originalTitle: topic.title,
                    originalContent: ""
                )
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "https://www.v2ex.com/t/\(topicId)") {
                ShareSheet(items: [url])
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .task {
            await loadTopic()
        }
    }

    @ViewBuilder
    private func topicHeader(_ topic: TopicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 10) {
                NavigationLink(value: topic.member) {
                    KFImage(URL(string: topic.member.avatarLarge))
                        .resizable()
                        .frame(width: 32, height: 32)
                        .clipShape(Circle())
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.member.username)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    HStack(spacing: 4) {
                        Text(topic.createdTime)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if topic.clicks > 0 {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text("\(topic.clicks) 次点击")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                NavigationLink(value: topic.node) {
                    Text(topic.node.title)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }

            Text(topic.title)
                .font(.title3)
                .fontWeight(.semibold)
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadTopic() async {
        isLoading = true
        do {
            topic = try await client.getTopicDetail(id: topicId)
            if let topic {
                viewedTopics.markViewed(topic: topic)
            }
            let result = try await client.getTopicReplies(id: topicId, page: 1)
            replies = result.replies
            currentPage = result.pagination.current
            totalPages = result.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMoreReplies() async {
        let nextPage = currentPage + 1
        do {
            let result = try await client.getTopicReplies(id: topicId, page: nextPage)
            replies.append(contentsOf: result.replies)
            currentPage = result.pagination.current
            totalPages = result.pagination.total
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func hasConversation(_ reply: TopicReply) -> Bool {
        let username = reply.member.username
        return !reply.membersMentioned.isEmpty
            || replies.contains(where: { $0.membersMentioned.contains(username) })
    }

    // MARK: - Actions

    private func toggleCollect() async {
        guard topic != nil else { return }
        do {
            if topic!.collected {
                topic = try await client.uncollectTopic(id: topicId)
            } else {
                topic = try await client.collectTopic(id: topicId)
            }
            HapticManager.notification(.success)
            alert.show(.success, topic!.collected ? "已收藏" : "已取消收藏")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func thankTopic() async {
        guard let t = topic, !t.thanked else { return }
        do {
            try await client.thankTopic(id: topicId)
            topic?.thanked = true
            HapticManager.notification(.success)
            alert.show(.success, "已感谢")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func thankReply(_ reply: TopicReply) async {
        guard !reply.thanked else { return }
        do {
            try await client.thankReply(id: reply.id)
            if let idx = replies.firstIndex(where: { $0.id == reply.id }) {
                replies[idx].thanked = true
            }
            HapticManager.notification(.success)
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func blockTopic() async {
        do {
            try await client.blockTopic(id: topicId)
            topic?.blocked = true
            alert.show(.success, "已忽略")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func unblockTopic() async {
        do {
            try await client.unblockTopic(id: topicId)
            topic?.blocked = false
            alert.show(.success, "已取消忽略")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func reportTopic() async {
        do {
            try await client.reportTopic(id: topicId)
            topic?.reported = true
            alert.show(.success, "已举报")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
