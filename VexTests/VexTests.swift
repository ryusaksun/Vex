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
