import Kingfisher
import SwiftUI
import WebKit

struct TopicDetailView: View {
    let topicId: Int
    var brief: TopicBasic?
    var scrollToReplyNum: Int?

    @Environment(ViewedTopicsManager.self) private var viewedTopics
    @Environment(AuthManager.self) private var auth
    @Environment(AlertManager.self) private var alert
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var topic: TopicDetail?
    @State private var replies: [TopicReply] = []
    @State private var currentPage = 1
    @State private var totalPages = 1
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var error: String?

    @State private var loadTask: Task<Void, Never>?
    @State private var didScrollToTarget = false

    // Sheets
    @State private var replyTarget: TopicReply?
    @State private var conversationReply: TopicReply?
    @State private var showShareSheet = false
    @State private var showEditSheet = false
    @State private var conversationReplyIds = Set<Int>()

    private let client = V2EXClient.shared

    var body: some View {
        ScrollViewReader { proxy in
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.fill.quaternary)
                    }

                    Divider()

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
                            hasConversation: conversationReplyIds.contains(reply.id),
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
                        .id(reply.num)
                        Divider()
                    }

                    // Load more
                    if currentPage < totalPages {
                        Button("加载更多回复") {
                            loadTask = Task { await loadMoreReplies() }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .disabled(isLoadingMore)
                    }
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if topic != nil {
                TopicBottomBar(
                    topicId: topicId,
                    replyTo: replyTarget,
                    onClearReplyTo: { replyTarget = nil },
                    onSubmitted: { newReply in
                        replyTarget = nil
                        if let newReply {
                            replies.append(newReply)
                            topic?.replies += 1
                            updateConversationIds()
                        } else {
                            Task { await loadTopic() }
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
                LottieLoadingView()
            } else if let error, topic == nil {
                ContentUnavailableView(
                    "加载失败",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .sheet(item: $conversationReply) { reply in
            ConversationSheet(reply: reply, allReplies: replies)
        }
        .sheet(isPresented: $showEditSheet) {
            TopicEditView(topicId: topicId) {
                Task { await loadTopic() }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let url = URL(string: "https://www.v2ex.com/t/\(topicId)") {
                ShareSheet(items: [url])
            }
        }
        // tab bar 隐藏由 ContentView NavigationStack 层统一控制
        .task {
            await loadTopic()
            // 加载完成后滚动到指定回复
            if let target = scrollToReplyNum, !didScrollToTarget, !replies.isEmpty {
                didScrollToTarget = true
                try? await Task.sleep(for: .milliseconds(300))
                withAnimation {
                    proxy.scrollTo(target, anchor: .top)
                }
            }
        }
        .onDisappear {
            loadTask?.cancel()
        }
        } // ScrollViewReader
    }


    private func topicMetaText(_ topic: TopicDetail) -> String {
        var parts: [String] = []
        if !topic.createdTime.isEmpty {
            parts.append(topic.createdTime)
        }
        if topic.clicks > 0 {
            parts.append("\(topic.clicks) 次点击")
        }
        return parts.joined(separator: " · ")
    }

    private func topicHeader(_ topic: TopicDetail) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Author info
            HStack(spacing: 10) {
                if settings.showAvatar {
                    NavigationLink(value: topic.member) {
                        KFImage(URL(string: HTMLParser.resolveURL(topic.member.avatarLarge)))
                            .resizable()
                            .frame(width: 40, height: 40)
                            .clipShape(Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(topic.member.username)
                        .font(.body)
                        .fontWeight(.semibold)
                    Text(verbatim: topicMetaText(topic))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
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

            GreedyTitleText(text: topic.title)
        }
        .padding()
    }

    // MARK: - Data Loading

    private func loadTopic() async {
        isLoading = true
        error = nil
        do {
            let result = try await client.getTopicDetailWithReplies(id: topicId)
            topic = result.topic
            replies = result.replies
            currentPage = result.pagination.current
            totalPages = result.pagination.total
            updateConversationIds()
            viewedTopics.markViewed(topic: result.topic)
        } catch {
            self.error = error.localizedDescription
        }
        isLoading = false
    }

    private func loadMoreReplies() async {
        guard !isLoadingMore, currentPage < totalPages else { return }

        isLoadingMore = true
        let nextPage = currentPage + 1
        do {
            let result = try await client.getTopicReplies(id: topicId, page: nextPage)
            replies.append(contentsOf: result.replies)
            currentPage = result.pagination.current
            totalPages = result.pagination.total
            updateConversationIds()
        } catch {
            alert.show(.error, "加载更多回复失败：\(error.localizedDescription)")
        }
        isLoadingMore = false
    }

    private func updateConversationIds() {
        var ids = Set<Int>()
        // 收集所有被提及的用户名
        var mentionedUsernames = Set<String>()
        for reply in replies {
            if !reply.membersMentioned.isEmpty {
                ids.insert(reply.id)
                mentionedUsernames.formUnion(reply.membersMentioned)
            }
        }
        // 被其他回复提及的用户的回复也算有会话
        for reply in replies {
            if mentionedUsernames.contains(reply.member.username) {
                ids.insert(reply.id)
            }
        }
        conversationReplyIds = ids
    }

    // MARK: - Actions

    private func toggleCollect() async {
        if auth.isDemoMode {
            topic?.collected.toggle()
            HapticManager.notification(.success)
            alert.show(.info, "Demo 模式：\(topic?.collected == true ? "收藏" : "取消收藏")演示")
            return
        }
        guard let t = topic else { return }
        do {
            if t.collected {
                topic = try await client.uncollectTopic(id: topicId)
            } else {
                topic = try await client.collectTopic(id: topicId)
            }
            HapticManager.notification(.success)
            alert.show(.success, topic?.collected == true ? "已收藏" : "已取消收藏")
        } catch {
            alert.show(.error, error.localizedDescription)
        }
    }

    private func thankTopic() async {
        if auth.isDemoMode {
            topic?.thanked = true
            HapticManager.notification(.success)
            alert.show(.info, "Demo 模式：感谢演示")
            return
        }
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
        if auth.isDemoMode {
            if let idx = replies.firstIndex(where: { $0.id == reply.id }) {
                replies[idx].thanksCount += 1
                replies[idx].thanked = true
            }
            HapticManager.notification(.success)
            alert.show(.info, "Demo 模式：感谢回复演示")
            return
        }
        guard !reply.thanked else { return }
        do {
            try await client.thankReply(id: reply.id)
            if let idx = replies.firstIndex(where: { $0.id == reply.id }) {
                replies[idx].thanksCount += 1
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

/// 禁用 iOS 平衡排版的标题，每行尽量填满再换行
private struct GreedyTitleText: UIViewRepresentable {
    let text: String

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakStrategy = []
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        label.adjustsFontForContentSizeCategory = true
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        label.text = text
        let size = UIFont.preferredFont(forTextStyle: .title2).pointSize
        label.font = UIFont.systemFont(ofSize: size, weight: .bold)
        label.textColor = .label
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        return uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
    }
}
