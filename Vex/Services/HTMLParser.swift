import Foundation
import SwiftSoup

/// V2EX HTML 解析器 — 对应 RN 版的 cheerio helpers
enum HTMLParser {
    static let baseURL = "https://www.v2ex.com"

    // MARK: - URL Helpers

    static func resolveURL(_ url: String?) -> String {
        guard let url, !url.isEmpty else { return "" }
        if url.starts(with: "//") {
            return "https:" + url
        }
        if url.starts(with: "/") {
            return baseURL + url
        }
        return url
    }

    // MARK: - Cloudflare Email Decode

    static func decodeEmail(_ encoded: String) -> String {
        guard encoded.count >= 2 else { return encoded }
        let hex = encoded.replacingOccurrences(of: "#", with: "")
        let bytes = stride(from: 0, to: hex.count, by: 2).compactMap { i -> UInt8? in
            let start = hex.index(hex.startIndex, offsetBy: i)
            let end = hex.index(start, offsetBy: 2, limitedBy: hex.endIndex) ?? hex.endIndex
            return UInt8(String(hex[start..<end]), radix: 16)
        }
        guard bytes.count > 1 else { return encoded }
        let key = bytes[0]
        let decoded = bytes.dropFirst().map { Character(UnicodeScalar($0 ^ key)) }
        return String(decoded)
    }

    static func processCloudflareEmails(_ doc: Document) throws {
        // Decode email-protected links
        for el in try doc.select("a[href^=/cdn-cgi/l/email-protection]") {
            let href = try el.attr("href")
            if let hashIndex = href.firstIndex(of: "#") {
                let encoded = String(href[href.index(after: hashIndex)...])
                let decoded = decodeEmail(encoded)
                try el.attr("href", "mailto:\(decoded)")
                try el.text(decoded)
            }
        }
        // Decode inline email elements
        for el in try doc.select(".__cf_email__") {
            let encoded = try el.attr("data-cfemail")
            let decoded = decodeEmail(encoded)
            try el.text(decoded)
            try el.removeAttr("class")
            try el.removeAttr("data-cfemail")
        }
    }

    // MARK: - Parse Document

    static func parseDocument(_ html: String) throws -> Document {
        let doc = try SwiftSoup.parse(html)
        try processCloudflareEmails(doc)
        return doc
    }

    // MARK: - Extract Topic from Link

    static func topicFromLink(_ el: Element) throws -> TopicBasic? {
        let href = try el.attr("href")
        guard href.contains("/t/") else { return nil }

        // Extract numbers from href: /t/{id}#reply{count}
        let numbers = href.matches(of: /\d+/).compactMap { Int(String($0.output)) }
        guard let topicId = numbers.first else { return nil }

        let replies = numbers.count > 1 ? numbers[1] : 0
        let title = try el.text()

        return TopicBasic(id: topicId, title: title, replies: replies)
    }

    // MARK: - Extract Node from Link

    static func nodeFromLink(_ el: Element) throws -> NodeBasic? {
        let href = try el.attr("href")
        guard href.contains("/go/") else { return nil }

        var name = href.replacingOccurrences(of: "/go/", with: "")
        // 移除查询参数（如 ?p=1）
        if let queryIndex = name.firstIndex(of: "?") {
            name = String(name[..<queryIndex])
        }
        let title = try el.text()
        return NodeBasic(name: name, title: title)
    }

    // MARK: - Extract Member from Avatar Image

    static func memberFromImage(_ el: Element) throws -> MemberBasic? {
        let alt = try el.attr("alt")
        let src = try el.attr("src")
        guard !alt.isEmpty else { return nil }
        return MemberBasic.avatarURLs(from: resolveURL(src), alt: alt)
    }

    // MARK: - Parse Pagination

    static func paginationFromText(_ text: String) -> Pagination {
        let parts = text.split(separator: "/")
        guard parts.count == 2,
              let current = Int(parts[0].trimmingCharacters(in: .whitespaces)),
              let total = Int(parts[1].trimmingCharacters(in: .whitespaces))
        else {
            return Pagination(current: 1, total: 1)
        }
        return Pagination(current: current, total: total)
    }

    // MARK: - Detect Home Page (error detection)

    static func isHomePage(_ doc: Document) throws -> Bool {
        let tabs = try doc.select("#Wrapper .content a[class^=tab]")
        return !tabs.isEmpty()
    }

    // MARK: - Parse Home Tabs

    static func parseHomeTabs(_ doc: Document) throws -> [HomeTabOption] {
        let links = try doc.select("#Wrapper .content a[class^=tab]")
        var tabs: [HomeTabOption] = []
        for link in links {
            let href = try link.attr("href")
            let label = try link.text()
            var value: String
            var type: HomeTabOption.TabType = .home

            if href.contains("?tab=") {
                value = href.components(separatedBy: "?tab=").last ?? ""
            } else if href.contains("/go/") {
                value = href.replacingOccurrences(of: "/go/", with: "")
                type = .node
            } else if href.contains("/xna") {
                value = "xna"
                type = .xna
            } else {
                value = href
            }

            tabs.append(HomeTabOption(value: value, label: label, type: type))
        }
        return tabs
    }

    // MARK: - Parse Home Feeds

    static func parseHomeFeeds(_ doc: Document) throws -> [HomeTopicFeed] {
        let cells = try doc.select("#Wrapper .content .cell.item")
        var feeds: [HomeTopicFeed] = []

        for cell in cells {
            // Member avatar
            guard let avatarImg = try cell.select("td:first-child img").first(),
                  let member = try memberFromImage(avatarImg) else { continue }

            // Node
            guard let nodeLink = try cell.select("a.node").first(),
                  let node = try nodeFromLink(nodeLink) else { continue }

            // Topic
            guard let topicLink = try cell.select(".item_title a").first(),
                  let topic = try topicFromLink(topicLink) else { continue }

            // Last reply info
            let metaSpan = try cell.select("td:nth-child(3) span:last-child")
            var lastReplyTime: String?
            var lastReplyBy: String?
            if let span = metaSpan.first() {
                let text = try span.text()
                let parts = text.split(separator: "•").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count >= 2 {
                    lastReplyTime = parts[0]
                    lastReplyBy = parts.last
                }
            }

            feeds.append(HomeTopicFeed(
                topic: topic,
                member: member,
                lastReplyTime: lastReplyTime,
                lastReplyBy: lastReplyBy,
                node: node
            ))
        }
        return feeds
    }

    // MARK: - Parse Topic Detail

    static func parseTopicDetail(_ doc: Document, id: Int) throws -> TopicDetail {
        let wrapper = try doc.select("#Wrapper")

        // Member
        guard let avatarImg = try wrapper.select(".header a[href^=/member] img").first(),
              let member = try memberFromImage(avatarImg) else {
            throw V2EXError.unexpectedResponse("Cannot parse topic member")
        }

        // Node
        guard let nodeLink = try wrapper.select(".header a[href^=/go]").first(),
              let node = try nodeFromLink(nodeLink) else {
            throw V2EXError.unexpectedResponse("Cannot parse topic node")
        }

        // Title
        let title = try wrapper.select(".header h1").text()

        // Content
        let contentRendered = try wrapper.select(".cell .topic_content").html()

        // Created time & clicks
        let metaText = try wrapper.select(".header > small.gray").text()
        var createdTime = ""
        var clicks = 0
        let metaParts = metaText.split(separator: "·").map { $0.trimmingCharacters(in: .whitespaces) }
        if let clickMatch = metaText.firstMatch(of: /(\d+)\s*次点击/) {
            clicks = Int(clickMatch.1) ?? 0
        }
        // 匹配时间：包含"前"（如 "5 小时前"）或日期格式（如 "2024-01-01"）
        for part in metaParts {
            if part.contains("前") || part.contains("-") && part.first?.isNumber == true {
                // 处理 "By xxx at 8 小时前" 格式，只取 "at " 之后的时间
                if let atRange = part.range(of: " at ") {
                    createdTime = String(part[atRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                } else {
                    createdTime = part
                }
                break
            }
        }

        // Replies count
        let repliesCountText = try wrapper.select(".box .cell:has(.gray)").text()
        var replies = 0
        if let match = repliesCountText.firstMatch(of: /(\d+)\s*条回复/) {
            replies = Int(match.1) ?? 0
        }

        // Subtles
        var subtles: [TopicSubtle] = []
        for subtle in try wrapper.select(".content .subtle") {
            let meta = try subtle.select(".fade").text()
            let content = try subtle.select(".topic_content").html()
            subtles.append(TopicSubtle(meta: meta, contentRendered: content))
        }

        // Status flags
        let collected = try !wrapper.select("a.op[href^=/unfavorite]").isEmpty()
        let thanked = try !wrapper.select("#topic_thank .topic_thanked").isEmpty()
        let canAppend = try !wrapper.select("a[href^=/append/topic]").isEmpty()
        let canEdit = try !wrapper.select("a[href^=/edit/topic]").isEmpty()
        let canMove = try !wrapper.select("a[href^=/move/topic]").isEmpty()

        // Blocked
        var blocked = false
        for tb in try wrapper.select("a.tb") {
            if try tb.text().contains("取消忽略") {
                blocked = true
                break
            }
        }

        return TopicDetail(
            id: id,
            title: title,
            replies: replies,
            member: member,
            contentRendered: contentRendered,
            createdTime: createdTime,
            node: node,
            subtles: subtles,
            collected: collected,
            thanked: thanked,
            blocked: blocked,
            reported: false,
            clicks: clicks,
            canAppend: canAppend,
            canEdit: canEdit,
            canMove: canMove
        )
    }

    // MARK: - Parse Topic Replies

    static func parseTopicReplies(_ doc: Document) throws -> [TopicReply] {
        let cells = try doc.select("#Wrapper .content .box div[id^=r_]")
        var replies: [TopicReply] = []

        for cell in cells {
            guard let reply = try parseReplyCell(cell, doc: doc) else { continue }
            replies.append(reply)
        }
        return replies
    }

    static func parseReplyCell(_ el: Element, doc: Document) throws -> TopicReply? {
        // ID
        let idStr = try el.attr("id").replacingOccurrences(of: "r_", with: "")
        guard let id = Int(idStr) else { return nil }

        // Member
        guard let avatarImg = try el.select("img.avatar").first(),
              let member = try memberFromImage(avatarImg) else { return nil }

        // Content
        let contentRendered = try el.select(".reply_content").html()

        // Reply time & device — 只取第一个 span.fade.small（时间），排除 thank_area 里的
        let timeSpans = try el.select("td:nth-child(3) > span.fade.small")
        let metaText = try timeSpans.first()?.text() ?? ""
        let metaParts = metaText.split(separator: " via ", maxSplits: 1)
        let replyTime = metaParts.first.map(String.init) ?? ""
        let replyDevice = metaParts.count > 1 ? String(metaParts[1]) : nil

        // Thanks — 通过 thank_area 定位，避免匹配到时间文本
        var thanksCount = 0
        if let thankText = try el.select("[id^=thank_area] span").first()?.text(),
           let match = thankText.firstMatch(of: /(\d+)/) {
            thanksCount = Int(match.1) ?? 0
        }
        let thanked = try !el.select(".thanked").isEmpty()

        // Reply number
        let numText = try el.select(".no").text()
        let num = Int(numText) ?? 0

        // Badges
        let memberIsOp = try !el.select(".badge.op").isEmpty()
        let memberIsMod = try !el.select(".badge.mod").isEmpty()

        // Mentioned members
        var membersMentioned: [String] = []
        for link in try el.select(".reply_content a[href^=/member/]") {
            let href = try link.attr("href")
            let username = href.replacingOccurrences(of: "/member/", with: "")
            membersMentioned.append(username)
        }

        // Replied-to numbers
        var repliedTo: [Int] = []
        let replyPattern = /<\/a>\s#(\d+)/
        for match in contentRendered.matches(of: replyPattern) {
            if let n = Int(String(match.1)) {
                repliedTo.append(n)
            }
        }

        // Content as markdown (simplified)
        let content = try el.select(".reply_content").text()

        return TopicReply(
            id: id,
            num: num,
            content: content,
            contentRendered: contentRendered,
            replyTime: replyTime,
            replyDevice: replyDevice,
            thanksCount: thanksCount,
            member: member,
            memberIsOp: memberIsOp,
            memberIsMod: memberIsMod,
            membersMentioned: membersMentioned,
            repliedTo: repliedTo.isEmpty ? nil : repliedTo,
            thanked: thanked
        )
    }

    // MARK: - Parse Node Groups

    static func parseNodeGroups(_ doc: Document) throws -> [NodeGroup] {
        let boxes = try doc.select("#Wrapper .content > .box")
        var groups: [NodeGroup] = []

        for box in boxes {
            let header = try box.select(".header")
            guard !header.isEmpty() else { continue }

            let title = try header.select(":first-child").text()
            let name = try header.select(".fr").text().replacingOccurrences(of: " • ", with: "")

            var nodes: [NodeBasic] = []
            for nodeLink in try box.select(".inner a.item_node") {
                if let node = try nodeFromLink(nodeLink) {
                    nodes.append(node)
                }
            }

            guard !nodes.isEmpty else { continue }
            groups.append(NodeGroup(title: title, name: name, nodes: nodes))
        }
        return groups
    }

    // MARK: - Parse Node Detail

    static func parseNodeDetail(_ doc: Document, name: String) throws -> NodeDetail {
        let avatarLarge = try doc.select(".page-content-header img").attr("src")
        let breadcrumb = try doc.select(".node-breadcrumb").text()
        // breadcrumb 格式："V2EX › 节点标题"，用 "›" 分隔取最后部分
        let title: String
        if let separatorRange = breadcrumb.range(of: "›") {
            title = breadcrumb[separatorRange.upperBound...].trimmingCharacters(in: .whitespaces)
        } else {
            title = breadcrumb.isEmpty ? name : breadcrumb
        }
        let header = try doc.select(".intro").html()
        let topicsText = try doc.select(".topic-count strong").text()
        let topics = Int(topicsText) ?? 0
        let collected = try !doc.select("a[href^=/unfavorite/node]").isEmpty()

        return NodeDetail(
            name: name,
            title: title,
            header: header,
            avatarLarge: resolveURL(avatarLarge),
            topics: topics,
            collected: collected
        )
    }

    // MARK: - Parse Node Feeds

    static func parseNodeFeeds(_ doc: Document) throws -> (feeds: [NodeTopicFeed], pagination: Pagination) {
        let cells = try doc.select("#Wrapper .content > .box:nth-child(2) .cell")
        var feeds: [NodeTopicFeed] = []

        for cell in cells {
            guard try !cell.select("table").isEmpty() else { continue }

            guard let avatarImg = try cell.select("img.avatar").first(),
                  let member = try memberFromImage(avatarImg) else { continue }

            guard let topicLink = try cell.select(".topic-link, .item_title a").first(),
                  let topic = try topicFromLink(topicLink) else { continue }

            let smallText = try cell.select("td:nth-child(3) .small").text()
            let numbers = smallText.split(separator: "•").compactMap {
                Int($0.trimmingCharacters(in: .whitespaces))
            }
            let characters = numbers.count > 0 ? numbers[0] : 0
            let clicks = numbers.count > 1 ? numbers[1] : 0

            feeds.append(NodeTopicFeed(
                topic: topic, member: member, characters: characters, clicks: clicks
            ))
        }

        // Pagination
        let pageText = try doc.select(".page_current").text()
        var pagination = Pagination(current: 1, total: 1)
        if !pageText.isEmpty {
            let current = Int(pageText) ?? 1
            let normalPages = try doc.select(".page_normal")
            let total = normalPages.isEmpty() ? 1 : (Int(try normalPages.last()?.text() ?? "1") ?? 1)
            pagination = Pagination(current: current, total: max(total, current))
        }

        return (feeds, pagination)
    }

    // MARK: - Parse Notifications

    static func parseNotifications(_ doc: Document) throws -> (notifications: [V2EXNotification], pagination: Pagination) {
        let cells = try doc.select("#notifications .cell")
        var notifications: [V2EXNotification] = []

        for cell in cells {
            guard let avatarImg = try cell.select("img.avatar").first(),
                  let member = try memberFromImage(avatarImg) else { continue }

            guard let topicLink = try cell.select("a[href^=/t/]").first(),
                  let topic = try topicFromLink(topicLink) else { continue }

            let fadeText = try cell.select("[valign=middle] .fade").text()
            let action: V2EXNotification.NotificationAction
            if fadeText.contains("收藏了你发布的主题") {
                action = .collect
            } else if fadeText.contains("感谢了你发布的主题") {
                action = .thank
            } else if fadeText.contains("感谢了你在主题") {
                action = .thankReply
            } else {
                action = .reply
            }

            let notificationId = try cell.attr("id")
            let contentRendered = try cell.select(".payload").html()
            let time = try cell.select(".snow").text()

            notifications.append(V2EXNotification(
                id: notificationId,
                member: member,
                topic: topic,
                action: action,
                contentRendered: contentRendered,
                time: time
            ))
        }

        let pageText = try doc.select(".page_current").text()
        let pagination: Pagination
        if !pageText.isEmpty {
            let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
            pagination = Pagination(current: Int(pageText) ?? 1, total: max(total, Int(pageText) ?? 1))
        } else {
            pagination = Pagination(current: 1, total: 1)
        }

        return (notifications, pagination)
    }

    // MARK: - Parse User Meta

    static func parseUserMeta(_ doc: Document) throws -> MemberMeta {
        let blocked = try !doc.select(".button[value=Unblock]").isEmpty()
        let watched = try !doc.select(".inverse[value=取消特别关注]").isEmpty()
        return MemberMeta(blocked: blocked, watched: watched)
    }

    // MARK: - Parse ONCE Token

    static func parseOnceToken(_ doc: Document) throws -> String? {
        // From settings night toggle link
        if let link = try doc.select("a[href^=/settings/night/toggle?once=]").first() {
            let href = try link.attr("href")
            return href.components(separatedBy: "once=").last
        }
        // From form input
        if let input = try doc.select("input[name=once]").first() {
            return try input.val()
        }
        return nil
    }

    // MARK: - Parse Unread Count

    static func parseUnreadCount(_ doc: Document) throws -> Int? {
        guard let button = try doc.select("input.special.super.button").first() else { return nil }
        let value = try button.val()
        if let match = value.firstMatch(of: /(\d+)/) {
            return Int(match.1)
        }
        return nil
    }

    // MARK: - Parse Balance

    static func parseBalanceBrief(_ doc: Document) throws -> BalanceBrief? {
        guard let area = try doc.select(".balance_area").first() else { return nil }
        // 与原版 RN 一致：用 html() 获取内容，替换 img 标签为文字标签，再用正则提取数字
        var html = try area.html()
        html = html.replacingOccurrences(of: "<img[^>]*gold[^>]*>", with: " gold ", options: .regularExpression)
        html = html.replacingOccurrences(of: "<img[^>]*silver[^>]*>", with: " silver ", options: .regularExpression)
        html = html.replacingOccurrences(of: "<img[^>]*bronze[^>]*>", with: " bronze ", options: .regularExpression)
        // 去除剩余 HTML 标签
        html = html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        let gold = html.firstMatch(of: /(\d+)\s*gold/).flatMap { Int($0.1) } ?? 0
        let silver = html.firstMatch(of: /(\d+)\s*silver/).flatMap { Int($0.1) } ?? 0
        let bronze = html.firstMatch(of: /(\d+)\s*bronze/).flatMap { Int($0.1) } ?? 0

        return BalanceBrief(gold: gold, silver: silver, bronze: bronze)
    }

    // MARK: - Parse Current Username

    static func parseCurrentUsername(_ doc: Document) throws -> String? {
        guard let avatar = try doc.select("#menu-entry img.avatar").first() else { return nil }
        return try avatar.attr("alt")
    }

    // MARK: - Parse Collected Topics

    static func parseCollectedTopics(_ doc: Document) throws -> (topics: [CollectedTopicFeed], pagination: Pagination) {
        let cells = try doc.select("#Wrapper .box .cell.item")
        var topics: [CollectedTopicFeed] = []

        for cell in cells {
            guard let avatarImg = try cell.select("img.avatar").first(),
                  let member = try memberFromImage(avatarImg) else { continue }

            guard let topicLink = try cell.select(".item_title a").first(),
                  let topic = try topicFromLink(topicLink) else { continue }

            let votesText = try cell.select(".votes").text()
            let votes = Int(votesText)

            var node = NodeBasic(name: "", title: "")
            if let nodeLink = try cell.select("a.node").first() {
                node = try nodeFromLink(nodeLink) ?? node
            }

            let infoText = try cell.select(".topic_info").text()
            let parts = infoText.split(separator: "•").map { $0.trimmingCharacters(in: .whitespaces) }

            topics.append(CollectedTopicFeed(
                topic: topic,
                votes: votes,
                member: member,
                node: node,
                lastReplyTime: parts.count > 2 ? parts[2] : nil,
                lastReplyBy: parts.count > 1 ? parts.last : nil
            ))
        }

        let pageText = try doc.select(".page_current").text()
        let current = Int(pageText) ?? 1
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        let pagination = Pagination(current: current, total: max(total, current))

        return (topics, pagination)
    }

    // MARK: - Parse Member Replies

    static func parseMemberReplies(_ doc: Document) throws -> (replies: [RepliedTopicFeed], pagination: Pagination) {
        let docks = try doc.select("#Wrapper .content .box .dock_area")
        var replies: [RepliedTopicFeed] = []

        for dock in docks {
            let headerText = try dock.select("table td span.gray").text()
            let timeText = try dock.select("table td span.fade").text()

            guard let topicLink = try dock.select("a[href^=/t/]").first(),
                  let topic = try topicFromLink(topicLink) else { continue }

            // Get reply content from next sibling
            guard let nextEl = try dock.nextElementSibling() else { continue }
            let replyContent = try nextEl.html()

            // Extract member from header
            guard let memberLink = try dock.select("a[href^=/member/]").first() else { continue }
            let username = try memberLink.attr("href").replacingOccurrences(of: "/member/", with: "")
            let member = MemberBasic(username: username, avatarMini: "", avatarNormal: "", avatarLarge: "")

            replies.append(RepliedTopicFeed(
                topic: topic,
                member: member,
                replyContentRendered: replyContent,
                replyTime: timeText
            ))
        }

        let pageText = try doc.select(".page_current").text()
        let current = Int(pageText) ?? 1
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        let pagination = Pagination(current: current, total: max(total, current))

        return (replies, pagination)
    }

    // MARK: - Parse Balance Records

    static func parseBalanceRecords(_ doc: Document) throws -> (records: [BalanceRecord], pagination: Pagination) {
        let tables = try doc.select("#Wrapper table")
        guard tables.size() >= 2 else { return ([], Pagination(current: 1, total: 1)) }

        let table = tables.get(1)
        let rows = try table.select("tr")
        var records: [BalanceRecord] = []

        for (index, row) in rows.enumerated() {
            guard index > 0 else { continue } // skip header
            let cols = try row.select("td")
            guard cols.size() >= 4 else { continue }

            let typeAndTime = try cols.get(0).text()
            let time = try cols.get(0).select(".gray").text()
            let type = typeAndTime.replacingOccurrences(of: time, with: "").trimmingCharacters(in: .whitespaces)

            records.append(BalanceRecord(
                type: type,
                time: time,
                amount: try cols.get(1).text(),
                balance: try cols.get(2).text(),
                description: try cols.get(3).text()
            ))
        }

        let pageText = try doc.select(".page_current").text()
        let current = Int(pageText) ?? 1
        let total = Int(try doc.select(".page_normal").last()?.text() ?? "1") ?? 1
        let pagination = Pagination(current: current, total: max(total, current))

        return (records, pagination)
    }

    // MARK: - Parse XNA Feeds

    static func parseXnaFeeds(_ doc: Document) throws -> [XnaFeed] {
        let items = try doc.select("#Wrapper .content .box .cell")
        var feeds: [XnaFeed] = []

        for item in items {
            guard try !item.select("table").isEmpty() else { continue }

            guard let avatarImg = try item.select("img.avatar").first(),
                  let member = try memberFromImage(avatarImg) else { continue }

            guard let titleLink = try item.select(".item_title a").first() else { continue }
            let title = try titleLink.text()
            let url = try titleLink.attr("href")

            let metaText = try item.select("td:nth-child(3) span.small").text()
            let sourceLink = try item.select("td:nth-child(3) a.node").first()
            let sourceName = try sourceLink?.text() ?? ""
            let sourceURL = try sourceLink?.attr("href") ?? ""

            let timeText = try item.select("td:nth-child(3) span.fade").text()

            feeds.append(XnaFeed(
                title: title,
                member: member,
                source: XnaFeed.XnaSource(name: sourceName, link: sourceURL),
                url: resolveURL(url),
                updatedAt: timeText
            ))
        }
        return feeds
    }

    // MARK: - Parse Form Problems

    static func parseFormProblems(_ doc: Document) throws -> [String] {
        try doc.select(".problem ul li").map { try $0.text() }
    }
}
