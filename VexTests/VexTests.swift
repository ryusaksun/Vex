import Foundation
import Testing
@testable import Vex

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
