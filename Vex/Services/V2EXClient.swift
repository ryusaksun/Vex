import Foundation
import SwiftSoup

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
    private var error403Count = 0

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
        guard var urlComponents = URLComponents(string: base + path) else {
            throw V2EXError.unexpectedResponse("Invalid URL: \(path)")
        }

        var request: URLRequest
        if method == "GET" {
            request = URLRequest(url: urlComponents.url!)
        } else {
            request = URLRequest(url: urlComponents.url!)
            request.httpMethod = method
            if let formData {
                request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                let body = formData.map { "\($0.key)=\($0.value.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? $0.value)" }.joined(separator: "&")
                request.httpBody = body.data(using: .utf8)
            }
        }

        headers?.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw V2EXError.unexpectedResponse("Not HTTP response")
        }

        // Handle 403
        if httpResponse.statusCode == 403 {
            error403Count += 1
            if error403Count >= 3 {
                shouldPrepareFetch = true
            }
        } else {
            error403Count = 0
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

        let html = String(data: data, encoding: .utf8) ?? ""
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
        if let cached = cachedOnce { return cached }
        let (data, _) = try await request(path: "/poll_once")
        let once = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        cachedOnce = once
        return once
    }

    func invalidateOnce() {
        cachedOnce = nil
    }

    // MARK: - Home & Feeds

    func getHomeTabs() async throws -> [HomeTabOption] {
        let doc = try await fetchHTML(path: "/")
        return try HTMLParser.parseHomeTabs(doc)
    }

    func getHomeFeeds(tab: String) async throws -> [HomeTopicFeed] {
        let doc = try await fetchHTML(path: "/?tab=\(tab)")
        return try HTMLParser.parseHomeFeeds(doc)
    }

    func getRecentFeeds(page: Int = 1) async throws -> PaginatedResponse<HomeTopicFeed> {
        let timestamp = Int(Date().timeIntervalSince1970)
        let doc = try await fetchHTML(path: "/recent?p=\(page)&d=\(timestamp)")
        let feeds = try HTMLParser.parseHomeFeeds(doc)
        let pageText = try doc.select(".page_current").text()
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        return PaginatedResponse(
            data: feeds,
            pagination: Pagination(current: Int(pageText) ?? page, total: total)
        )
    }

    func getHotTopics() async throws -> [TopicDetail] {
        // Use REST API for hot topics
        struct APITopic: Decodable {
            let id: Int
            let title: String
            let content_rendered: String
            let replies: Int
            let created: Int
            let member: APIMember
            let node: APINode

            struct APIMember: Decodable {
                let username: String
                let avatar_mini: String?
                let avatar_normal: String?
                let avatar_large: String?
            }
            struct APINode: Decodable {
                let name: String
                let title: String
            }
        }

        let topics: [APITopic] = try await fetchJSON(path: "/api/topics/hot.json", type: [APITopic].self)
        return topics.map { t in
            TopicDetail(
                id: t.id,
                title: t.title,
                replies: t.replies,
                member: MemberBasic(
                    username: t.member.username,
                    avatarMini: t.member.avatar_mini ?? "",
                    avatarNormal: t.member.avatar_normal ?? "",
                    avatarLarge: t.member.avatar_large ?? ""
                ),
                contentRendered: t.content_rendered,
                createdTime: "",
                node: NodeBasic(name: t.node.name, title: t.node.title),
                subtles: [],
                collected: false, thanked: false, blocked: false, reported: false,
                clicks: 0, canAppend: false, canEdit: false, canMove: false
            )
        }
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

        let pageText = try doc.select(".page_current").text()
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        let pagination = Pagination(current: Int(pageText) ?? page, total: max(total, Int(pageText) ?? 1))

        return (replies, pagination)
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
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool, !success {
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

        let doc = try await fetchHTML(path: "/write", method: "POST", formData: form)
        invalidateOnce()

        let problems = try HTMLParser.parseFormProblems(doc)
        if !problems.isEmpty {
            throw V2EXError.formProblems(problems)
        }

        // Should have redirected to /t/{id}
        // Try to parse topic detail from current page
        return try HTMLParser.parseTopicDetail(doc, id: 0) // ID will be extracted from page
    }

    // MARK: - Nodes

    func getNodeGroups() async throws -> [NodeGroup] {
        let doc = try await fetchHTML(path: "/planes")
        return try HTMLParser.parseNodeGroups(doc)
    }

    func getNodeDetail(name: String) async throws -> NodeDetail {
        let doc = try await fetchHTML(path: "/go/\(name)")
        return try HTMLParser.parseNodeDetail(doc, name: name)
    }

    func getNodeFeeds(name: String, page: Int = 1) async throws -> PaginatedResponse<NodeTopicFeed> {
        let doc = try await fetchHTML(path: "/go/\(name)?p=\(page)")
        let result = try HTMLParser.parseNodeFeeds(doc)
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
        let detail: MemberDetail = try await fetchJSON(
            path: "/api/members/show.json?username=\(username)",
            type: MemberDetail.self
        )
        let doc = try await fetchHTML(path: "/member/\(username)")
        let meta = try HTMLParser.parseUserMeta(doc)
        return (detail, meta)
    }

    func getMemberTopics(username: String, page: Int = 1) async throws -> PaginatedResponse<MemberTopicFeed> {
        let doc = try await fetchHTML(path: "/member/\(username)/topics?p=\(page)")

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

        let pageText = try doc.select(".page_current").text()
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        return PaginatedResponse(
            data: feeds,
            pagination: Pagination(current: Int(pageText) ?? page, total: total)
        )
    }

    func getMemberReplies(username: String, page: Int = 1) async throws -> PaginatedResponse<RepliedTopicFeed> {
        let doc = try await fetchHTML(path: "/member/\(username)/replies?p=\(page)")
        let result = try HTMLParser.parseMemberReplies(doc)
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
        let result = try HTMLParser.parseNotifications(doc)
        return PaginatedResponse(data: result.notifications, pagination: result.pagination)
    }

    func getCollectedTopics(page: Int = 1) async throws -> PaginatedResponse<CollectedTopicFeed> {
        let doc = try await fetchHTML(path: "/my/topics?p=\(page)")
        let result = try HTMLParser.parseCollectedTopics(doc)
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
        let result = try HTMLParser.parseBalanceRecords(doc)
        return PaginatedResponse(data: result.records, pagination: result.pagination)
    }

    // MARK: - Auth

    func getCurrentUser() async throws -> MemberDetail? {
        // 请求首页以获取用户名和余额（/about 页面没有 balance_area）
        let doc = try await fetchHTML(path: "/")
        guard let username = try HTMLParser.parseCurrentUsername(doc) else { return nil }
        return try await fetchJSON(
            path: "/api/members/show.json?username=\(username)",
            type: MemberDetail.self
        )
    }

    func logout() async {
        let storage = HTTPCookieStorage.shared
        if let cookies = storage.cookies(for: URL(string: Self.baseURL)!) {
            for cookie in cookies {
                storage.deleteCookie(cookie)
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

    func editTopic(id: Int, title: String, content: String) async throws {
        let once = try await getOnce()
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
        let doc = try await fetchHTML(path: "/xna")
        return try HTMLParser.parseXnaFeeds(doc)
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
