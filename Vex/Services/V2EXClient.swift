import Foundation
import SwiftSoup
import WebKit

/// V2EX API 客户端 — 基于 URLSession + SwiftSoup HTML 解析
@MainActor
final class V2EXClient: ObservableObject {
    static let shared = V2EXClient()

    static let baseURL = "https://www.v2ex.com"
    static let searchURL = "https://www.sov2ex.com"
    private let timeout: TimeInterval = 10
    private let userAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1 Vex/2.0"

    // ONCE token cache
    private var cachedOnce: String?
    private var onceTask: Task<String, any Error>?
    private var recentPaginationAnchor: Int?

    // Event callbacks
    @Published var unreadCount: Int = 0
    @Published var currentUsername: String?
    @Published var balanceBrief: BalanceBrief?
    @Published var shouldPrepareFetch = false

    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.default
        config.httpCookieStorage = .shared
        config.httpCookieAcceptPolicy = .always
        config.timeoutIntervalForRequest = timeout
        config.httpAdditionalHeaders = [
            "User-Agent": userAgent,
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8",
        ]
        return URLSession(configuration: config)
    }()

    // MARK: - Core Request

    func request(
        path: String,
        method: String = "GET",
        formData: [String: String]? = nil,
        headers: [String: String]? = nil,
        baseURL: String? = nil
    ) async throws -> (Data, HTTPURLResponse) {
        let base = baseURL ?? Self.baseURL
        guard let requestURL = URLComponents(string: base + path)?.url else {
            throw V2EXError.unexpectedResponse("Invalid URL: \(path)")
        }

        var request: URLRequest
        if method == "GET" {
            request = URLRequest(url: requestURL)
        } else {
            request = URLRequest(url: requestURL)
            request.httpMethod = method
            if let formData {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                var allowed = CharacterSet.urlQueryAllowed
                allowed.remove(charactersIn: "&=+")
                let body = formData.map {
                    let key = $0.key.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.key
                    let value = $0.value.addingPercentEncoding(withAllowedCharacters: allowed) ?? $0.value
                    return "\(key)=\(value)"
                }.joined(separator: "&")
                request.httpBody = body.data(using: .utf8)
            }
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw V2EXError.unexpectedResponse("Not HTTP response")
        }

        // Handle 403 (Cloudflare challenge)
        if httpResponse.statusCode == 403 {
            shouldPrepareFetch = true
            throw V2EXError.unexpectedResponse("访问被拒绝 (403)，可能需要完成 Cloudflare 验证")
        }

        // Handle other HTTP errors
        let statusCode = httpResponse.statusCode
        if statusCode >= 500 {
            throw V2EXError.unexpectedResponse("服务器错误 (\(statusCode))")
        }
        if statusCode == 404 {
            throw V2EXError.resourceNotFound
        }

        return (data, httpResponse)
    }

    /// Fetch HTML and parse to SwiftSoup Document, extract side-effect data
    func fetchHTML(path: String, method: String = "GET", formData: [String: String]? = nil) async throws -> Document {
        let (data, response) = try await request(path: path, method: method, formData: formData)

        // Check redirects
        let finalURL = response.url?.absoluteString ?? ""
        if finalURL.contains("/signin") && !path.contains("/signin") {
            throw V2EXError.authRequired
        }
        if finalURL.contains("/2fa") {
            let html = String(data: data, encoding: .utf8) ?? ""
            let doc = try HTMLParser.parseDocument(html)
            let once = try HTMLParser.parseOnceToken(doc) ?? ""
            let problems = try HTMLParser.parseFormProblems(doc)
            throw V2EXError.twoFactorRequired(once: once, problems: problems.isEmpty ? nil : problems)
        }
        if finalURL.contains("/restricted") {
            throw V2EXError.restricted
        }

        guard let html = String(data: data, encoding: .utf8), !html.isEmpty else {
            throw V2EXError.unexpectedResponse("无法解码响应内容")
        }
        let doc = try HTMLParser.parseDocument(html)

        // Side effects: extract once token, unread count, username, balance
        if let once = try HTMLParser.parseOnceToken(doc) {
            cachedOnce = once
        }
        if let count = try HTMLParser.parseUnreadCount(doc) {
            unreadCount = count
        }
        if let username = try HTMLParser.parseCurrentUsername(doc) {
            currentUsername = username
        }
        if let balance = try HTMLParser.parseBalanceBrief(doc) {
            balanceBrief = balance
        }

        return doc
    }

    /// Fetch JSON from API endpoint
    func fetchJSON<T: Decodable>(path: String, type: T.Type) async throws -> T {
        let (data, _) = try await request(path: path)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(T.self, from: data)
    }

    // MARK: - ONCE Token

    func getOnce() async throws -> String {
        if let cached = cachedOnce, !cached.isEmpty { return cached }
        // 复用正在进行的请求，避免并发重复请求
        if let existing = onceTask {
            return try await existing.value
        }
        let task = Task<String, any Error> {
            defer { onceTask = nil }
            let (data, _) = try await request(path: "/poll_once")
            let once = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !once.isEmpty else {
                throw V2EXError.unexpectedResponse("无法获取 ONCE token")
            }
            cachedOnce = once
            return once
        }
        onceTask = task
        return try await task.value
    }

    func invalidateOnce() {
        cachedOnce = nil
        onceTask = nil
    }

    // MARK: - Home & Feeds

    func getHomeTabs() async throws -> [HomeTabOption] {
        let doc = try await fetchHTML(path: "/")
        return try HTMLParser.parseHomeTabs(doc)
    }

    func getHomeFeeds(tab: String, page: Int = 1) async throws -> PaginatedResponse<HomeTopicFeed> {
        if tab == "recent" {
            return try await getRecentFeeds(page: page)
        }

        if tab == "hot" {
            return try await getHotFeeds(page: page)
        }

        let path = page > 1 ? "/?tab=\(tab)&p=\(page)" : "/?tab=\(tab)"
        let doc = try await fetchHTML(path: path)
        let result = try HTMLParser.parseHomeFeedsPage(doc, page: page)
        return PaginatedResponse(data: result.feeds, pagination: result.pagination)
    }

    private func getHotFeeds(page: Int) async throws -> PaginatedResponse<HomeTopicFeed> {
        guard page == 1 else {
            return PaginatedResponse(data: [], pagination: Pagination(current: 1, total: 1))
        }

        struct APIHotTopic: Decodable {
            let id: Int
            let title: String
            let replies: Int
            let member: APIMember
            let node: APINode

            struct APIMember: Decodable {
                let username: String
                let avatarMini: String?
                let avatarNormal: String?
                let avatarLarge: String?
            }

            struct APINode: Decodable {
                let name: String
                let title: String
            }
        }

        let topics: [APIHotTopic] = try await fetchJSON(path: "/api/topics/hot.json", type: [APIHotTopic].self)
        let feeds = topics.map { topic in
            HomeTopicFeed(
                topic: TopicBasic(id: topic.id, title: topic.title, replies: topic.replies),
                member: MemberBasic(
                    username: topic.member.username,
                    avatarMini: topic.member.avatarMini ?? "",
                    avatarNormal: topic.member.avatarNormal ?? "",
                    avatarLarge: topic.member.avatarLarge ?? ""
                ),
                lastReplyTime: nil,
                lastReplyBy: nil,
                node: NodeBasic(name: topic.node.name, title: topic.node.title)
            )
        }

        return PaginatedResponse(data: feeds, pagination: Pagination(current: 1, total: 1))
    }

    func getRecentFeeds(page: Int = 1) async throws -> PaginatedResponse<HomeTopicFeed> {
        if page <= 1 {
            recentPaginationAnchor = Int(Date().timeIntervalSince1970)
        }

        let anchor = recentPaginationAnchor ?? Int(Date().timeIntervalSince1970)
        recentPaginationAnchor = anchor

        let doc = try await fetchHTML(path: "/recent?p=\(page)&d=\(anchor)")
        let feeds = try HTMLParser.parseHomeFeeds(doc)
        let pagination = try HTMLParser.parsePagination(doc, page: page)
        return PaginatedResponse(
            data: feeds,
            pagination: pagination
        )
    }

    func getHotTopics() async throws -> [TopicDetail] {
        if let cached: [TopicDetail] = await CacheManager.shared.get("hot_topics", type: [TopicDetail].self, maxAge: 120) {
            return cached
        }

        // Use REST API for hot topics
        struct APITopic: Decodable {
            let id: Int
            let title: String
            let contentRendered: String
            let replies: Int
            let created: Int
            let member: APIMember
            let node: APINode

            struct APIMember: Decodable {
                let username: String
                let avatarMini: String?
                let avatarNormal: String?
                let avatarLarge: String?
            }
            struct APINode: Decodable {
                let name: String
                let title: String
            }
        }

        let topics: [APITopic] = try await fetchJSON(path: "/api/topics/hot.json", type: [APITopic].self)
        let parsedTopics = topics.map { t in
            TopicDetail(
                id: t.id,
                title: t.title,
                replies: t.replies,
                member: MemberBasic(
                    username: t.member.username,
                    avatarMini: t.member.avatarMini ?? "",
                    avatarNormal: t.member.avatarNormal ?? "",
                    avatarLarge: t.member.avatarLarge ?? ""
                ),
                contentRendered: t.contentRendered,
                createdTime: "",
                node: NodeBasic(name: t.node.name, title: t.node.title),
                subtles: [],
                collected: false, thanked: false, blocked: false, reported: false,
                clicks: 0, canAppend: false, canEdit: false, canMove: false
            )
        }
        await CacheManager.shared.set("hot_topics", value: parsedTopics)
        return parsedTopics
    }

    // MARK: - Topics

    func getTopicDetail(id: Int) async throws -> TopicDetail {
        let doc = try await fetchHTML(path: "/t/\(id)")
        if try HTMLParser.isHomePage(doc) {
            throw V2EXError.resourceNotFound
        }
        return try HTMLParser.parseTopicDetail(doc, id: id)
    }

    func getTopicReplies(id: Int, page: Int = 1) async throws -> (replies: [TopicReply], pagination: Pagination) {
        let doc = try await fetchHTML(path: "/t/\(id)?p=\(page)")
        if try HTMLParser.isHomePage(doc) {
            throw V2EXError.resourceNotFound
        }
        let replies = try HTMLParser.parseTopicReplies(doc)
        let pagination = try HTMLParser.parsePagination(doc, page: page)

        return (replies, pagination)
    }

    /// 一次请求同时获取帖子详情和第一页回复，避免重复请求同一页面
    func getTopicDetailWithReplies(id: Int) async throws -> (topic: TopicDetail, replies: [TopicReply], pagination: Pagination) {
        let doc = try await fetchHTML(path: "/t/\(id)")
        if try HTMLParser.isHomePage(doc) {
            throw V2EXError.resourceNotFound
        }
        let topic = try HTMLParser.parseTopicDetail(doc, id: id)
        let replies = try HTMLParser.parseTopicReplies(doc)
        let pagination = try HTMLParser.parsePagination(doc, page: 1)
        return (topic, replies, pagination)
    }

    func collectTopic(id: Int) async throws -> TopicDetail {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/favorite/topic/\(id)?once=\(once)")
        invalidateOnce()
        return try await getTopicDetail(id: id)
    }

    func uncollectTopic(id: Int) async throws -> TopicDetail {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/unfavorite/topic/\(id)?once=\(once)")
        invalidateOnce()
        return try await getTopicDetail(id: id)
    }

    func thankTopic(id: Int) async throws {
        let once = try await getOnce()
        let (data, _) = try await request(
            path: "/thank/topic/\(id)?once=\(once)",
            method: "POST",
            headers: [
                "X-Requested-With": "XMLHttpRequest",
                "Accept": "application/json",
            ]
        )
        invalidateOnce()
        // Parse JSON response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw V2EXError.unexpectedResponse("响应格式异常")
        }
        if let success = json["success"] as? Bool, !success {
            let message = json["message"] as? String ?? "操作失败"
            throw V2EXError.unexpectedResponse(message)
        }
    }

    func blockTopic(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/ignore/topic/\(id)?once=\(once)")
        invalidateOnce()
    }

    func unblockTopic(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/unignore/topic/\(id)?once=\(once)")
        invalidateOnce()
    }

    func reportTopic(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/report/topic/\(id)?once=\(once)")
        invalidateOnce()
    }

    func postReply(topicId: Int, content: String) async throws -> TopicReply? {
        let once = try await getOnce()
        let doc = try await fetchHTML(
            path: "/t/\(topicId)",
            method: "POST",
            formData: ["content": content, "once": once]
        )
        invalidateOnce()

        let problems = try HTMLParser.parseFormProblems(doc)
        if !problems.isEmpty {
            throw V2EXError.formProblems(problems)
        }

        // Get last reply
        let replies = try HTMLParser.parseTopicReplies(doc)
        return replies.last
    }

    func thankReply(id: Int) async throws {
        let once = try await getOnce()
        let (data, _) = try await request(
            path: "/thank/reply/\(id)?once=\(once)",
            method: "POST",
            headers: [
                "X-Requested-With": "XMLHttpRequest",
                "Accept": "application/json",
            ]
        )
        invalidateOnce()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw V2EXError.unexpectedResponse("响应格式异常")
        }
        if let success = json["success"] as? Bool, !success {
            let message = json["message"] as? String ?? "操作失败"
            throw V2EXError.unexpectedResponse(message)
        }
    }

    func createTopic(title: String, content: String?, nodeName: String, syntax: String = "default") async throws -> TopicDetail {
        let once = try await getOnce()
        var form: [String: String] = [
            "title": title,
            "node_name": nodeName,
            "syntax": syntax,
            "once": once,
        ]
        if let content { form["content"] = content }

        let (data, response) = try await request(path: "/write", method: "POST", formData: form)
        invalidateOnce()

        let html = String(data: data, encoding: .utf8) ?? ""
        let doc = try HTMLParser.parseDocument(html)

        let problems = try HTMLParser.parseFormProblems(doc)
        if !problems.isEmpty {
            throw V2EXError.formProblems(problems)
        }

        // 从重定向后的 URL 中提取帖子 ID
        var topicId = 0
        if let finalURL = response.url?.absoluteString,
           let match = finalURL.firstMatch(of: /\/t\/(\d+)/) {
            topicId = Int(match.1) ?? 0
        }
        if topicId == 0 {
            throw V2EXError.unexpectedResponse("无法获取新帖子 ID")
        }

        return try HTMLParser.parseTopicDetail(doc, id: topicId)
    }

    // MARK: - Nodes

    func getNodeGroups() async throws -> [NodeGroup] {
        if let cached: [NodeGroup] = await CacheManager.shared.get("node_groups", type: [NodeGroup].self, maxAge: 1800) {
            return cached
        }

        let doc = try await fetchHTML(path: "/planes")
        let groups = try HTMLParser.parseNodeGroups(doc)
        await CacheManager.shared.set("node_groups", value: groups)
        return groups
    }

    func getNodeDetail(name: String) async throws -> NodeDetail {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let doc = try await fetchHTML(path: "/go/\(encodedName)")
        return try HTMLParser.parseNodeDetail(doc, name: name)
    }

    func getNodeFeeds(name: String, page: Int = 1) async throws -> PaginatedResponse<NodeTopicFeed> {
        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
        let doc = try await fetchHTML(path: "/go/\(encodedName)?p=\(page)")
        let result = try HTMLParser.parseNodeFeeds(doc, page: page)
        return PaginatedResponse(data: result.feeds, pagination: result.pagination)
    }

    func collectNode(name: String) async throws {
        // Get node ID from API
        struct APINode: Decodable { let id: Int }
        let node: APINode = try await fetchJSON(path: "/api/nodes/show.json?name=\(name)", type: APINode.self)
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/favorite/node/\(node.id)", method: "POST", formData: ["once": once])
        invalidateOnce()
    }

    func uncollectNode(name: String) async throws {
        struct APINode: Decodable { let id: Int }
        let node: APINode = try await fetchJSON(path: "/api/nodes/show.json?name=\(name)", type: APINode.self)
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/unfavorite/node/\(node.id)", method: "POST", formData: ["once": once])
        invalidateOnce()
    }

    // MARK: - Members

    func getMemberDetail(username: String) async throws -> (detail: MemberDetail, meta: MemberMeta) {
        let encodedUsername = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        let detail: MemberDetail = try await fetchJSON(
            path: "/api/members/show.json?username=\(encodedUsername)",
            type: MemberDetail.self
        )
        let encodedPath = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let doc = try await fetchHTML(path: "/member/\(encodedPath)")
        let meta = try HTMLParser.parseUserMeta(doc)
        return (detail, meta)
    }

    func getMemberTopics(username: String, page: Int = 1) async throws -> PaginatedResponse<MemberTopicFeed> {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let doc = try await fetchHTML(path: "/member/\(encoded)/topics?p=\(page)")

        // Check locked
        if try !doc.select(".member-locked").isEmpty() {
            throw V2EXError.memberLocked
        }

        let cells = try doc.select(".cell")
        var feeds: [MemberTopicFeed] = []

        for cell in cells {
            guard try !cell.select("table").isEmpty() else { continue }

            guard let topicLink = try cell.select(".item_title a").first(),
                  let topic = try HTMLParser.topicFromLink(topicLink) else { continue }

            var node = NodeBasic(name: "", title: "")
            if let nodeLink = try cell.select("a.node").first() {
                node = try HTMLParser.nodeFromLink(nodeLink) ?? node
            }

            let metaText = try cell.select("span:last-child").text()
            let parts = metaText.split(separator: "•").map { $0.trimmingCharacters(in: .whitespaces) }

            feeds.append(MemberTopicFeed(
                topic: topic,
                node: node,
                lastReplyTime: parts.first,
                lastReplyBy: parts.count > 1 ? parts.last : nil
            ))
        }

        return PaginatedResponse(
            data: feeds,
            pagination: try HTMLParser.parsePagination(doc, page: page)
        )
    }

    func getMemberReplies(username: String, page: Int = 1) async throws -> PaginatedResponse<RepliedTopicFeed> {
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? username
        let doc = try await fetchHTML(path: "/member/\(encoded)/replies?p=\(page)")
        let result = try HTMLParser.parseMemberReplies(doc, page: page)
        return PaginatedResponse(data: result.replies, pagination: result.pagination)
    }

    func watchMember(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/follow/\(id)?once=\(once)")
        invalidateOnce()
    }

    func unwatchMember(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/unfollow/\(id)?once=\(once)")
        invalidateOnce()
    }

    func blockMember(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/block/\(id)?once=\(once)")
        invalidateOnce()
    }

    func unblockMember(id: Int) async throws {
        let once = try await getOnce()
        _ = try await fetchHTML(path: "/unblock/\(id)?once=\(once)")
        invalidateOnce()
    }

    // MARK: - Notifications & Account

    func getNotifications(page: Int = 1) async throws -> PaginatedResponse<V2EXNotification> {
        let doc = try await fetchHTML(path: "/notifications?p=\(page)")
        let result = try HTMLParser.parseNotifications(doc, page: page)
        return PaginatedResponse(data: result.notifications, pagination: result.pagination)
    }

    func getCollectedTopics(page: Int = 1) async throws -> PaginatedResponse<CollectedTopicFeed> {
        let doc = try await fetchHTML(path: "/my/topics?p=\(page)")
        let result = try HTMLParser.parseCollectedTopics(doc, page: page)
        return PaginatedResponse(data: result.topics, pagination: result.pagination)
    }

    func getCollectedNodes() async throws -> [NodeExtra] {
        let doc = try await fetchHTML(path: "/my/nodes")
        let favNodes = try doc.select("#my-nodes .fav-node")
        var nodes: [NodeExtra] = []

        for fav in favNodes {
            let name = try fav.select("img").attr("alt")
            let avatarLarge = HTMLParser.resolveURL(try fav.select("img").attr("src"))
            let title = try fav.select(".fav-node-name").text()
            let topicsText = try fav.select(".fade").text()
            let topics = Int(topicsText.trimmingCharacters(in: .whitespaces)) ?? 0

            nodes.append(NodeExtra(name: name, title: title, avatarLarge: avatarLarge, topics: topics))
        }
        return nodes
    }

    func checkDailySigninStatus() async throws -> Bool {
        let doc = try await fetchHTML(path: "/mission/daily")
        // 如果页面有 redeem 链接，说明还没签到；没有则已签到
        let redeemLink = try doc.select("input.super.normal.button")
        let buttonValue = redeemLink.isEmpty() ? "" : try redeemLink.val()
        return !buttonValue.contains("领取")
    }

    func dailySignin() async throws {
        let once = try await getOnce()
        let doc = try await fetchHTML(path: "/mission/daily/redeem?once=\(once)")
        invalidateOnce()

        let buttonValue = try doc.select("input.super.normal.button").val()
        if buttonValue != "查看我的账户余额" {
            let message = try doc.select(".message").text()
            if !message.isEmpty {
                throw V2EXError.dailySigned
            }
        }
    }

    func getBalanceRecords(page: Int = 1) async throws -> PaginatedResponse<BalanceRecord> {
        let doc = try await fetchHTML(path: "/balance?p=\(page)")
        let result = try HTMLParser.parseBalanceRecords(doc, page: page)
        return PaginatedResponse(data: result.records, pagination: result.pagination)
    }

    // MARK: - Auth

    func getCurrentUser() async throws -> MemberDetail? {
        // 请求首页以获取用户名和余额（/about 页面没有 balance_area）
        let doc = try await fetchHTML(path: "/")
        guard let username = try HTMLParser.parseCurrentUsername(doc) else { return nil }
        let encoded = username.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? username
        return try await fetchJSON(
            path: "/api/members/show.json?username=\(encoded)",
            type: MemberDetail.self
        )
    }

    func logout() async {
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies {
            for cookie in cookies where cookie.domain.contains("v2ex.com") || cookie.domain.contains("sov2ex.com") {
                storage.deleteCookie(cookie)
            }
        }

        let cookieStore = WKWebsiteDataStore.default().httpCookieStore
        let webCookies = await withCheckedContinuation { continuation in
            cookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
        for cookie in webCookies where cookie.domain.contains("v2ex.com") || cookie.domain.contains("sov2ex.com") {
            await withCheckedContinuation { continuation in
                cookieStore.delete(cookie) {
                    continuation.resume()
                }
            }
        }

        cachedOnce = nil
        currentUsername = nil
        unreadCount = 0
        balanceBrief = nil
    }

    // MARK: - Topic Edit

    func fetchTopicEditForm(id: Int) async throws -> (title: String, content: String, once: String) {
        let doc = try await fetchHTML(path: "/edit/topic/\(id)")
        let title = try doc.select("input[name=title]").val()
        let content = try doc.select("textarea[name=content]").text()
        let once = try HTMLParser.parseOnceToken(doc) ?? ""
        return (title, content, once)
    }

    func editTopic(id: Int, title: String, content: String, once: String) async throws {
        let doc = try await fetchHTML(
            path: "/edit/topic/\(id)",
            method: "POST",
            formData: [
                "title": title,
                "content": content,
                "once": once,
            ]
        )
        invalidateOnce()

        let problems = try HTMLParser.parseFormProblems(doc)
        if !problems.isEmpty {
            throw V2EXError.formProblems(problems)
        }
    }

    func appendTopic(id: Int, content: String) async throws {
        let once = try await getOnce()
        let doc = try await fetchHTML(
            path: "/append/topic/\(id)",
            method: "POST",
            formData: [
                "content": content,
                "once": once,
            ]
        )
        invalidateOnce()

        let problems = try HTMLParser.parseFormProblems(doc)
        if !problems.isEmpty {
            throw V2EXError.formProblems(problems)
        }
    }

    // MARK: - XNA

    func getXnaFeeds() async throws -> [XnaFeed] {
        if let cached: [XnaFeed] = await CacheManager.shared.get("xna_feeds", type: [XnaFeed].self, maxAge: 180) {
            return cached
        }

        let doc = try await fetchHTML(path: "/xna")
        let feeds = try HTMLParser.parseXnaFeeds(doc)
        await CacheManager.shared.set("xna_feeds", value: feeds)
        return feeds
    }

    // MARK: - Search

    func search(query: String, from: Int = 0, size: Int = 10) async throws -> [SearchHit] {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        let (data, _) = try await request(
            path: "/api/search?q=\(encoded)&from=\(from)&size=\(size)",
            baseURL: Self.searchURL
        )

        struct SearchResponse: Decodable {
            let hits: [SearchHit]
            let total: Int
            let took: Int
        }

        let decoder = JSONDecoder()
        let response = try decoder.decode(SearchResponse.self, from: data)
        return response.hits
    }
}
