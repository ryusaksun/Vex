import Foundation
import Testing
@testable import Vex

@Test func parseMemberRepliesFromHTML() throws {
    // 模拟真实 V2EX /member/{username}/replies 页面结构
    let html = """
    <div id="Wrapper"><div class="content"><div id="Main"><div class="box">
    <div class="header"><a href="/">V2EX</a></div>
    <div class="cell ps_container">
        <table><tr><td><a href="?p=1" class="page_current">1</a> <a href="?p=2" class="page_normal">2</a> <a href="?p=3" class="page_normal">3</a></td></tr></table>
    </div>
    <div class="dock_area">
        <table cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
            <td><div class="fr"><span class="fade">3 小时前</span></div><span class="gray">回复了 <a href="/member/test">test</a> 创建的主题 <span class="chevron">›</span> <a href="/go/swift">Swift</a> <span class="chevron">›</span> <a href="/t/123#reply5">测试主题标题</a></span></td>
        </tr></table>
    </div>
    <div class="inner"><div class="reply_content">这是回复内容</div></div>
    <div class="dock_area">
        <table cellpadding="0" cellspacing="0" border="0" width="100%"><tr>
            <td><div class="fr"><span class="fade">5 小时前</span></div><span class="gray">回复了 <a href="/member/foo">foo</a> 创建的主题 <span class="chevron">›</span> <a href="/go/apple">Apple</a> <span class="chevron">›</span> <a href="/t/456#reply10">另一个主题</a></span></td>
        </tr></table>
    </div>
    <div class="inner"><div class="reply_content">另一条回复</div></div>
    <div class="cell ps_container">
        <table><tr><td><a href="?p=1" class="page_current">1</a> <a href="?p=2" class="page_normal">2</a> <a href="?p=3" class="page_normal">3</a></td></tr></table>
    </div>
    </div></div></div></div>
    """
    let doc = try HTMLParser.parseDocument(html)
    let result = try HTMLParser.parseMemberReplies(doc)
    #expect(result.replies.count == 2)
    #expect(result.replies[0].topic.id == 123)
    #expect(result.replies[0].topic.title == "测试主题标题")
    #expect(result.replies[0].replyTime == "3 小时前")
    #expect(result.replies[0].replyContentRendered.contains("这是回复内容"))
    #expect(result.replies[1].topic.id == 456)
    #expect(result.pagination.current == 1)
    #expect(result.pagination.total == 3)
}

@Test func htmlParserResolveURL() {
    #expect(HTMLParser.resolveURL("/t/123") == "https://www.v2ex.com/t/123")
    #expect(HTMLParser.resolveURL("https://example.com") == "https://example.com")
    #expect(HTMLParser.resolveURL(nil) == "")
}

@Test func cloudflareEmailDecode() {
    // Test XOR decryption
    let encoded = "3a5f5e4b0a5b4f"
    let decoded = HTMLParser.decodeEmail(encoded)
    #expect(!decoded.isEmpty)
}

@Test func paginationParsing() {
    let pagination = HTMLParser.paginationFromText("3/10")
    #expect(pagination.current == 3)
    #expect(pagination.total == 10)
}

@Test func recentMobilePaginationParsing() throws {
    let html = """
    <html>
    <head>
        <title>V2EX › 最近的主题 2/39926</title>
    </head>
    <body>
        <div class="box">
            <div class="cell item">mock feed</div>
            <div class="inner">
                <table cellpadding="0" cellspacing="0" border="0" width="100%">
                    <tr>
                        <td width="120" align="left"><input type="button" onclick="location.href = '/recent?p=1'" value="‹ 上一页" class="super normal button" /></td>
                        <td width="auto" align="center"><strong class="fade">2/39926</strong></td>
                        <td width="120" align="right"><input type="button" onclick="location.href = '/recent?p=3';" value="下一页 ›" class="super normal button" /></td>
                    </tr>
                </table>
            </div>
        </div>
    </body>
    </html>
    """

    let doc = try HTMLParser.parseDocument(html)
    let pagination = try HTMLParser.parsePagination(doc, page: 2)

    #expect(pagination.current == 2)
    #expect(pagination.total == 39926)
}

@Test func verboseTitlePaginationParsing() throws {
    let html = """
    <html>
    <head>
        <title>V2EX › Livid 的所有回复 › 第 2 页 / 共 1530 页</title>
    </head>
    <body></body>
    </html>
    """

    let doc = try HTMLParser.parseDocument(html)
    let pagination = try HTMLParser.parsePagination(doc, page: 2)

    #expect(pagination.current == 2)
    #expect(pagination.total == 1530)
}

@Test func memberAvatarSizeMapping() {
    let member = MemberBasic.avatarURLs(
        from: "https://cdn.v2ex.com/avatar/1234/test_normal.png",
        alt: "testuser"
    )
    #expect(member.username == "testuser")
    #expect(member.avatarMini.contains("_mini."))
    #expect(member.avatarLarge.contains("_large."))
}

@Test func deepLinkHandlerParsesCustomTopicURL() {
    let url = URL(string: "vex://t/123")!
    let link = DeepLinkHandler.parse(url: url)

    guard case .topic(let id)? = link else {
        Issue.record("未能解析 vex 主题链接")
        return
    }
    #expect(id == 123)
}

@Test func deepLinkHandlerParsesWebNodeAndMemberURL() {
    let nodeURL = URL(string: "https://www.v2ex.com/go/swift")!
    let memberURL = URL(string: "https://www.v2ex.com/member/testuser")!

    let nodeLink = DeepLinkHandler.parse(url: nodeURL)
    let memberLink = DeepLinkHandler.parse(url: memberURL)

    guard case .node(let nodeName)? = nodeLink else {
        Issue.record("未能解析节点链接")
        return
    }
    guard case .member(let username)? = memberLink else {
        Issue.record("未能解析用户链接")
        return
    }

    #expect(nodeName == "swift")
    #expect(username == "testuser")
}

@MainActor
@Test func htmlContentPreprocessorUnescapesEscapedImageTag() {
    let html = #"<p>&lt;img src=&quot;https://example.com/test.webp&quot; alt=&quot;示例图片&quot;&gt;</p>"#
    let normalized = HTMLContentPreprocessor.normalize(html)

    #expect(normalized.contains(#"<img src="https://example.com/test.webp" alt="示例图片">"#))
}

@MainActor
@Test func htmlContentParserRecognizesParagraphWrappedImage() {
    let kinds = HTMLContentParserTestSupport.blockKinds(
        for: #"<p><img src="/images/test.webp" alt="示例图片"></p>"#
    )

    #expect(kinds == ["image"])
}

@MainActor
@Test func htmlContentParserRecognizesEscapedImageTagAsImageBlock() {
    let kinds = HTMLContentParserTestSupport.blockKinds(
        for: #"<p>&lt;img src=&quot;https://example.com/test.webp&quot; alt=&quot;示例图片&quot;&gt;</p>"#
    )

    #expect(kinds == ["image"])
}

@MainActor
@Test func htmlContentPreprocessorRepairsOrphanedImageAttributes() {
    let html = #"https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" alt="微信图片_20260309163034_154.jpg">"#
    let normalized = HTMLContentPreprocessor.normalize(html)

    #expect(normalized == #"<img src="https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" alt="微信图片_20260309163034_154.jpg">"#)
}

@MainActor
@Test func htmlContentParserRecognizesOrphanedImageAttributesAsImageBlock() {
    let kinds = HTMLContentParserTestSupport.blockKinds(
        for: #"https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" alt="微信图片_20260309163034_154.jpg">"#
    )

    #expect(kinds == ["image"])
}

@MainActor
@Test func htmlContentPreprocessorRepairsMarkdownImageWrappedByAnchor() {
    let html = #"![微信图片_20260309163034_154.jpg]( <a target="_blank" href="https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" rel="nofollow noopener">https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp</a>)"#
    let normalized = HTMLContentPreprocessor.normalize(html)

    #expect(normalized == #"<img src="https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" alt="微信图片_20260309163034_154.jpg">"#)
}

@MainActor
@Test func htmlContentParserRecognizesMarkdownImageWrappedByAnchor() {
    let kinds = HTMLContentParserTestSupport.blockKinds(
        for: #"![微信图片_20260309163034_154.jpg]( <a target="_blank" href="https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp" rel="nofollow noopener">https://picui.ogmua.cn/s1/2026/03/09/69ae8531b9c45.webp</a>)"#
    )

    #expect(kinds == ["image"])
}

@Test func htmlImageLayoutKeepsSmallImagesNearNaturalSize() {
    let size = HTMLImageLayout.displaySize(
        for: CGSize(width: 360, height: 360),
        displayScale: 3,
        maxWidth: HTMLImageLayout.maxWidth,
        maxHeight: HTMLImageLayout.maxHeight
    )

    #expect(Int(size.width.rounded()) == 120)
    #expect(Int(size.height.rounded()) == 120)
}

@Test func htmlImageLayoutScalesLargeImagesDownToContentWidth() {
    let size = HTMLImageLayout.displaySize(
        for: CGSize(width: 1600, height: 900),
        displayScale: 2,
        maxWidth: HTMLImageLayout.maxWidth,
        maxHeight: HTMLImageLayout.maxHeight
    )

    #expect(Int(size.width.rounded()) == 320)
    #expect(Int(size.height.rounded()) == 180)
}

@MainActor
@Test func htmlContentParserTreatsEmbeddedReplyImagesAsInline() {
    let kinds = HTMLContentParserTestSupport.blockKinds(
        for: #"希望你这次真的是正缘啊 <a target="_blank" href="https://i.imgur.com/io2SM1h.png" rel="nofollow noopener"><img src="https://i.imgur.com/io2SM1h.png" class="embedded_image" rel="noreferrer"></a>"#
    )

    #expect(kinds == ["inline"])
}

@Test func htmlInlineImageLayoutAlignsToBodyTextHeight() {
    let size = HTMLInlineImageLayout.displaySize(
        for: CGSize(width: 512, height: 512),
        displayScale: 3
    )

    #expect(Int(size.height.rounded()) == Int(HTMLInlineImageLayout.targetHeight.rounded()))
    #expect(Int(size.width.rounded()) == Int(HTMLInlineImageLayout.targetHeight.rounded()))
}

@Test func parseMemberRepliesFromLiveHTML() throws {
    let fixtureURL = URL(filePath: #filePath)
        .deletingLastPathComponent()
        .appending(path: "replies_test.html")
    let html = try String(contentsOf: fixtureURL, encoding: .utf8)
    let doc = try HTMLParser.parseDocument(html)
    let result = try HTMLParser.parseMemberReplies(doc)
    #expect(result.replies.count > 0, "应该解析出至少 1 条回复")
    for reply in result.replies {
        #expect(!reply.topic.title.isEmpty)
        #expect(reply.topic.id > 0)
        #expect(!reply.replyTime.isEmpty)
        #expect(!reply.member.username.isEmpty)
    }
}

@Test func swiftSoupPreservesEmoji() throws {
    let html = "<p>🔗 传送门： <a href=\"https://example.com\">https://example.com</a></p>"
    let doc = try HTMLParser.parseDocument(html)
    let text = try doc.select("p").text()
    let containsEmoji = text.contains("🔗")
    let scalars = text.unicodeScalars.map { "U+\(String(format: "%04X", $0.value))" }.joined(separator: " ")
    #expect(containsEmoji, "SwiftSoup lost emoji. Text=[\(text)] Scalars=[\(scalars)]")
}

@MainActor
@Test func htmlContentParserPreservesEmoji() {
    let html = "<p>🔗 传送门</p>"
    let kinds = HTMLContentParserTestSupport.blockKinds(for: html)
    print("Block kinds: \(kinds)")
    #expect(kinds == ["text"])
}
