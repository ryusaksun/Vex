import Foundation
import Kingfisher
import SwiftSoup
import SwiftUI

/// 原生 HTML 渲染器 — 使用 SwiftUI Text + AttributedString 替代 WKWebView，彻底消除滚动卡顿
struct HTMLContentView: View {
    let html: String

    @State private var selectedImageURL: String?

    var body: some View {
        let blocks = HTMLBlockParser.parse(html)
        let imageURLs = HTMLBlockParser.imageURLs(for: html)

        Group {
            if blocks.isEmpty {
                EmptyView()
            } else if blocks.count == 1, case .text(let runs) = blocks[0] {
                // 快速路径：单文本块（回复的常见情况）
                HTMLBlockParser.buildText(from: runs)
                    .font(.body)
                    .lineSpacing(3)
                    .tint(.accentColor)
            } else if blocks.count == 1, case .inline(let fragments) = blocks[0] {
                HTMLInlineFragmentsView(fragments: fragments, onImageTapped: { selectedImageURL = $0 })
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                        blockView(block)
                    }
                }
            }
        }
        .fullScreenCover(item: Binding(
            get: { selectedImageURL.flatMap { ImageID(url: $0) } },
            set: { selectedImageURL = $0?.url }
        )) { item in
            let urls = imageURLs.compactMap { URL(string: $0) }
            let index = urls.firstIndex(where: { $0.absoluteString == item.url }) ?? 0
            ImageGalleryView(imageURLs: urls, selectedIndex: index)
        }
    }

    @ViewBuilder
    private func blockView(_ block: HTMLBlock) -> some View {
        switch block {
        case .text(let runs):
            HTMLBlockParser.buildText(from: runs)
                .font(.body)
                .lineSpacing(3)
                .tint(.accentColor)

        case .image(let url):
            HTMLImageBlockView(url: url)
                .onTapGesture { selectedImageURL = url }

        case .inline(let fragments):
            HTMLInlineFragmentsView(fragments: fragments, onImageTapped: { selectedImageURL = $0 })

        case .codeBlock(let code):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: 13, design: .monospaced))
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 6))

        case .blockquote(let inner):
            HTMLBlockquoteView(blocks: inner)
        }
    }

}

private struct ImageID: Identifiable {
    let url: String
    var id: String { url }
}

/// Blockquote 单独作为 struct 避免递归类型推断问题
private struct HTMLBlockquoteView: View {
    let blocks: [HTMLBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let runs):
                    HTMLBlockParser.buildText(from: runs)
                        .font(.subheadline)
                        .lineSpacing(2)
                        .tint(.accentColor)
                case .image(let url):
                    HTMLImageBlockView(url: url)
                case .inline(let fragments):
                    HTMLInlineFragmentsView(fragments: fragments, font: .subheadline)
                case .codeBlock(let code):
                    Text(code)
                        .font(.system(size: 13, design: .monospaced))
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                case .blockquote:
                    EmptyView()
                }
            }
        }
        .foregroundStyle(.secondary)
        .padding(.leading, 10)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(.tertiary)
                .frame(width: 3)
        }
    }
}

private struct HTMLInlineFragmentsView: View {
    let fragments: [HTMLInlineFragment]
    var font: Font = .body
    var onImageTapped: ((String) -> Void)?

    @State private var loadedImages: [String: UIImage] = [:]

    var body: some View {
        builtText
            .font(font)
            .lineSpacing(3)
            .tint(.accentColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task { await loadAllImages() }
    }

    private var builtText: Text {
        var result = Text("")
        for fragment in fragments {
            switch fragment {
            case .text(let runs):
                result = result + HTMLBlockParser.buildText(from: runs)
            case .image(let url):
                if let uiImage = loadedImages[url] {
                    // 缩略图已在 loadAllImages 中预计算
                    result = result + Text(Image(uiImage: uiImage))
                } else {
                    result = result + Text("⬜")
                }
            }
        }
        return result
    }

    private func loadAllImages() async {
        let scale = UIScreen.main.scale
        var urlsToLoad: [String] = []
        for fragment in fragments {
            guard case .image(let url) = fragment,
                  loadedImages[url] == nil else { continue }
            urlsToLoad.append(url)
        }
        guard !urlsToLoad.isEmpty else { return }

        // 加载所有图片并预计算缩略图，最后批量更新（减少渲染次数）
        var newImages: [String: UIImage] = [:]
        for url in urlsToLoad {
            guard let imageURL = URL(string: url) else { continue }
            do {
                let result = try await KingfisherManager.shared.retrieveImage(with: imageURL)
                let image = result.image
                // 预计算缩略图，避免在 builtText 中同步生成
                let targetH = HTMLInlineImageLayout.targetHeight
                let aspect = image.size.width / max(image.size.height, 1)
                let w = min(HTMLInlineImageLayout.maxWidth, targetH * aspect)
                let pixelSize = CGSize(width: w * scale, height: targetH * scale)
                if let thumb = image.preparingThumbnail(of: pixelSize),
                   let cg = thumb.cgImage {
                    newImages[url] = UIImage(cgImage: cg, scale: scale, orientation: .up)
                } else {
                    newImages[url] = image
                }
            } catch {}
        }
        // 批量更新：一次性触发渲染，而非每张图片触发一次
        if !newImages.isEmpty {
            loadedImages.merge(newImages) { _, new in new }
        }
    }
}

private struct HTMLImageBlockView: View {
    let url: String

    @Environment(\.displayScale) private var displayScale
    @State private var pixelSize: CGSize?

    var body: some View {
        KFImage(URL(string: url))
            .onSuccess { result in
                pixelSize = result.image.size
            }
            .placeholder {
                ProgressView()
                    .frame(width: 32, height: 32)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .resizable()
            .scaledToFit()
            .frame(width: displaySize.width, height: displaySize.height, alignment: .leading)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var displaySize: CGSize {
        guard let pixelSize else {
            return CGSize(width: HTMLImageLayout.maxWidth, height: HTMLImageLayout.placeholderHeight)
        }
        return HTMLImageLayout.displaySize(
            for: pixelSize,
            displayScale: displayScale,
            maxWidth: HTMLImageLayout.maxWidth,
            maxHeight: HTMLImageLayout.maxHeight
        )
    }
}

private struct HTMLInlineImageView: View {
    let url: String

    @Environment(\.displayScale) private var displayScale
    @State private var pixelSize: CGSize?

    var body: some View {
        KFImage(URL(string: url))
            .onSuccess { result in
                pixelSize = result.image.size
            }
            .resizable()
            .scaledToFit()
            .frame(width: displaySize.width, height: displaySize.height)
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .alignmentGuide(.firstTextBaseline) { dimensions in
                dimensions[.bottom]
            }
    }

    private var displaySize: CGSize {
        HTMLInlineImageLayout.displaySize(for: pixelSize, displayScale: displayScale)
    }
}

enum HTMLImageLayout {
    static let maxWidth: CGFloat = 320
    static let maxHeight: CGFloat = 360
    static let placeholderHeight: CGFloat = 180

    /// 小图（如表情）的最小显示尺寸，避免 web 1x 图片在 3x 设备上缩得太小
    static let minHeight: CGFloat = 24

    static func displaySize(
        for pixelSize: CGSize,
        displayScale: CGFloat,
        maxWidth: CGFloat,
        maxHeight: CGFloat
    ) -> CGSize {
        guard pixelSize.width > 0, pixelSize.height > 0 else {
            return CGSize(width: maxWidth, height: placeholderHeight)
        }

        let scale = max(displayScale, 1)
        var w = pixelSize.width / scale
        var h = pixelSize.height / scale

        // 小图按最小尺寸兜底，保持宽高比
        if h < minHeight {
            let ratio = minHeight / h
            w *= ratio
            h = minHeight
        }

        let resizeRatio = min(1, maxWidth / w, maxHeight / h)
        return CGSize(width: w * resizeRatio, height: h * resizeRatio)
    }
}

enum HTMLInlineImageLayout {
    static let targetHeight: CGFloat = 24
    static let maxWidth: CGFloat = 32

    static func displaySize(for pixelSize: CGSize?, displayScale: CGFloat) -> CGSize {
        guard let pixelSize, pixelSize.width > 0, pixelSize.height > 0 else {
            return CGSize(width: targetHeight, height: targetHeight)
        }

        let aspectRatio = pixelSize.width / pixelSize.height
        let width = min(maxWidth, max(targetHeight * 0.9, targetHeight * aspectRatio))
        return CGSize(width: width, height: targetHeight)
    }
}

// MARK: - Block Types

private enum HTMLBlock {
    case text([HTMLBlockParser.InlineRun])
    case image(String)
    case inline([HTMLInlineFragment])
    case codeBlock(String)
    case blockquote([HTMLBlock])
}

private enum HTMLInlineFragment {
    case text([HTMLBlockParser.InlineRun])
    case image(String)
}

// MARK: - Parser

@MainActor
private enum HTMLBlockParser {

    static func parse(_ html: String) -> [HTMLBlock] {
        if let cached = HTMLBlockCache.get(html) {
            return cached.blocks
        }

        let preprocessed = HTMLContentPreprocessor.normalize(html)

        guard !preprocessed.isEmpty,
              let doc = try? SwiftSoup.parseBodyFragment(preprocessed),
              let body = doc.body()
        else {
            return []
        }
        let blocks = parseChildren(of: body)
        let imageURLs = collectImageURLs(from: blocks)
        HTMLBlockCache.store(blocks: blocks, imageURLs: imageURLs, for: html)
        return blocks
    }

    static func imageURLs(for html: String) -> [String] {
        HTMLBlockCache.get(html)?.imageURLs ?? []
    }

    private static func collectImageURLs(from blocks: [HTMLBlock]) -> [String] {
        var urls: [String] = []
        for block in blocks {
            switch block {
            case .image(let url):
                urls.append(url)
            case .inline(let fragments):
                for fragment in fragments {
                    if case .image(let url) = fragment {
                        urls.append(url)
                    }
                }
            case .blockquote(let inner):
                urls.append(contentsOf: collectImageURLs(from: inner))
            default:
                break
            }
        }
        return urls
    }

    // MARK: Block-level

    private static func parseChildren(of parent: Node) -> [HTMLBlock] {
        var blocks: [HTMLBlock] = []
        var runs: [InlineRun] = []
        parseNodes(parent.getChildNodes(), into: &blocks, runs: &runs, style: .init())
        flush(&runs, into: &blocks)
        return blocks
    }

    // MARK: Inline-level

    struct InlineStyle {
        var isBold = false
        var isItalic = false
        var isCode = false
        var link: URL?
    }

    enum InlineRun {
        case text(String, InlineStyle)
        case inlineImage(String)
        case lineBreak
    }

    private static func parseNodes(
        _ nodes: [Node],
        into blocks: inout [HTMLBlock],
        runs: inout [InlineRun],
        style: InlineStyle
    ) {
        for node in nodes {
            if let textNode = node as? TextNode {
                append(textNode, style: style, into: &runs)
                continue
            }

            guard let el = node as? Element else { continue }

            switch el.tagName().lowercased() {
            case "p", "div":
                flush(&runs, into: &blocks)
                parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: style)
                flush(&runs, into: &blocks)

            case "br":
                runs.append(.lineBreak)

            case "pre":
                flush(&runs, into: &blocks)
                blocks.append(.codeBlock((try? el.text()) ?? ""))

            case "blockquote":
                flush(&runs, into: &blocks)
                let inner = parseChildren(of: el)
                if !inner.isEmpty {
                    blocks.append(.blockquote(inner))
                }

            case "img":
                let src = (try? el.attr("src")) ?? ""
                if !src.isEmpty {
                    let resolvedURL = HTMLParser.resolveURL(src)
                    if hasInlineImageClass(el) {
                        runs.append(.inlineImage(resolvedURL))
                    } else {
                        flush(&runs, into: &blocks)
                        blocks.append(.image(resolvedURL))
                    }
                }

            case "ul", "ol":
                flush(&runs, into: &blocks)
                appendList(from: el, into: &blocks)

            case "a":
                let href = (try? el.attr("href")) ?? ""
                let resolvedHref = HTMLParser.resolveURL(href)
                // <a> 链接指向图片且内容仅为 URL 文本时，渲染为图片
                if !href.isEmpty, isImageURL(resolvedHref),
                   isLinkTextOnlyURL(el) {
                    flush(&runs, into: &blocks)
                    blocks.append(.image(resolvedHref))
                } else {
                    var nextStyle = style
                    if !href.isEmpty {
                        nextStyle.link = URL(string: resolvedHref)
                    }
                    parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: nextStyle)
                }

            case "strong", "b":
                var nextStyle = style
                nextStyle.isBold = true
                parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: nextStyle)

            case "em", "i":
                var nextStyle = style
                nextStyle.isItalic = true
                parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: nextStyle)

            case "code":
                if el.parent()?.tagName().lowercased() == "pre" {
                    parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: style)
                } else {
                    var nextStyle = style
                    nextStyle.isCode = true
                    parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: nextStyle)
                }

            default:
                parseNodes(el.getChildNodes(), into: &blocks, runs: &runs, style: style)
            }
        }
    }

    private static func flush(_ runs: inout [InlineRun], into blocks: inout [HTMLBlock]) {
        guard !runs.isEmpty else { return }
        appendBlocks(from: runs, into: &blocks)
        runs = []
    }

    private static func append(_ textNode: TextNode, style: InlineStyle, into runs: inout [InlineRun]) {
        let text = textNode.getWholeText()
            .replacingOccurrences(of: "[\\s\\n]+", with: " ", options: .regularExpression)
        if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            runs.append(.text(text, style))
        }
    }

    private static func appendList(from element: Element, into blocks: inout [HTMLBlock]) {
        let ordered = element.tagName().lowercased() == "ol"
        var idx = 0
        for child in element.children() {
            guard child.tagName().lowercased() == "li" else { continue }
            idx += 1
            let prefix = ordered ? "\(idx). " : "• "
            var liRuns: [InlineRun] = [.text(prefix, .init())]
            liRuns.append(contentsOf: extractInline(from: child))
            if !liRuns.isEmpty {
                blocks.append(.text(liRuns))
            }
        }
    }

    private static func extractInline(from element: Element, style: InlineStyle = .init()) -> [InlineRun] {
        var runs: [InlineRun] = []
        for node in element.getChildNodes() {
            if let tn = node as? TextNode {
                let text = tn.getWholeText()
                    .replacingOccurrences(of: "[\\s\\n]+", with: " ", options: .regularExpression)
                if !text.isEmpty {
                    runs.append(.text(text, style))
                }
            } else if let el = node as? Element {
                switch el.tagName().lowercased() {
                case "br":
                    runs.append(.lineBreak)
                case "a":
                    var s = style
                    let href = (try? el.attr("href")) ?? ""
                    if !href.isEmpty { s.link = URL(string: HTMLParser.resolveURL(href)) }
                    runs.append(contentsOf: extractInline(from: el, style: s))
                case "strong", "b":
                    var s = style; s.isBold = true
                    runs.append(contentsOf: extractInline(from: el, style: s))
                case "em", "i":
                    var s = style; s.isItalic = true
                    runs.append(contentsOf: extractInline(from: el, style: s))
                case "code":
                    if el.parent()?.tagName().lowercased() == "pre" {
                        runs.append(contentsOf: extractInline(from: el, style: style))
                    } else {
                        var s = style; s.isCode = true
                        runs.append(contentsOf: extractInline(from: el, style: s))
                    }
                case "img":
                    let src = (try? el.attr("src")) ?? ""
                    if !src.isEmpty, hasInlineImageClass(el) {
                        runs.append(.inlineImage(HTMLParser.resolveURL(src)))
                    }
                default:
                    runs.append(contentsOf: extractInline(from: el, style: style))
                }
            }
        }
        return runs
    }

    private static func appendBlocks(from runs: [InlineRun], into blocks: inout [HTMLBlock]) {
        var segment: [InlineRun] = []

        func flushSegment() {
            guard !segment.isEmpty else { return }
            let hasImages = segment.contains { if case .inlineImage = $0 { return true }; return false }
            let hasText = segment.contains { if case .text = $0 { return true }; return false }

            if hasImages && !hasText {
                // 纯图片段（截图独占一行）→ block 图片
                for run in segment {
                    if case .inlineImage(let url) = run {
                        blocks.append(.image(url))
                    }
                }
            } else if hasImages {
                // 图文混排（表情嵌在文字中）→ inline
                let fragments = buildInlineFragments(from: segment)
                if !fragments.isEmpty {
                    blocks.append(.inline(fragments))
                }
            } else if !segment.isEmpty {
                blocks.append(.text(segment))
            }
            segment = []
        }

        for run in runs {
            if case .lineBreak = run {
                flushSegment()
            } else {
                segment.append(run)
            }
        }

        flushSegment()
    }

    private static func buildInlineFragments(from runs: [InlineRun]) -> [HTMLInlineFragment] {
        var fragments: [HTMLInlineFragment] = []
        var textBuffer: [InlineRun] = []

        func flushTextBuffer() {
            guard !textBuffer.isEmpty else { return }
            fragments.append(.text(textBuffer))
            textBuffer = []
        }

        for run in runs {
            switch run {
            case .text:
                textBuffer.append(run)
            case .inlineImage(let url):
                flushTextBuffer()
                fragments.append(.image(url))
            case .lineBreak:
                break
            }
        }

        flushTextBuffer()
        return fragments
    }

    private static func hasInlineImageClass(_ element: Element) -> Bool {
        (try? element.hasClass("embedded_image")) ?? false
    }

    private static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "webp", "avif", "bmp", "svg"]

    /// URL 是否指向图片（按扩展名判断）
    private static func isImageURL(_ url: String) -> Bool {
        // 取路径部分（去掉 query/fragment），再取扩展名
        guard let urlObj = URL(string: url) else { return false }
        return imageExtensions.contains(urlObj.pathExtension.lowercased())
    }

    /// <a> 标签的子节点是否仅包含 URL 文本（没有其他元素如 <img>）
    private static func isLinkTextOnlyURL(_ element: Element) -> Bool {
        let children = element.getChildNodes()
        // 只有一个文本节点
        guard children.count == 1, children[0] is TextNode else { return false }
        return true
    }

    // MARK: Build AttributedString

    /// 用 Text 拼接替代 AttributedString，确保 emoji 等 supplementary plane 字符正确渲染
    static func buildText(from runs: [InlineRun]) -> Text {
        var result = Text("")
        var hasContent = false
        for run in runs {
            switch run {
            case .text(let content, let style):
                if style.link != nil {
                    // 链接必须用 AttributedString 才能点击
                    var attr = AttributedString(content)
                    attr.link = style.link
                    if style.isBold { attr.inlinePresentationIntent = .stronglyEmphasized }
                    result = result + Text(attr)
                } else {
                    var t = Text(verbatim: content)
                    if style.isCode { t = t.font(.system(size: 15, design: .monospaced)) }
                    if style.isBold { t = t.bold() }
                    if style.isItalic { t = t.italic() }
                    result = result + t
                }
                hasContent = true
            case .inlineImage:
                continue
            case .lineBreak:
                if hasContent { result = result + Text("\n") }
            }
        }
        return result
    }
}

enum HTMLContentPreprocessor {
    static func normalize(_ html: String) -> String {
        let linkedMarkdownImageNormalized = html.replacingOccurrences(
            of: #"!\[([^\]]*)\]\(\s*<a[^>]*href="([^"]+)"[^>]*>[^<]*</a>\s*\)"#,
            with: #"<img src="$2" alt="$1">"#,
            options: [.regularExpression]
        )

        let markdownNormalized = linkedMarkdownImageNormalized.replacingOccurrences(
            of: "!\\[([^\\]]*)\\]\\(([^)]+)\\)",
            with: "<img src=\"$2\" alt=\"$1\">",
            options: .regularExpression
        )

        let escapedImageNormalized = replace(
            pattern: #"&lt;\s*img\b.*?&gt;"#,
            in: markdownNormalized,
            options: [.caseInsensitive, .dotMatchesLineSeparators]
        ) { decodeEscapedImageTag($0) }

        return escapedImageNormalized.replacingOccurrences(
            of: #"(?<!src=")(?<![<\w])(https?://[^\s"'>]+(?:png|jpe?g|gif|webp|avif))"\s*alt="([^"]*)">"#,
            with: #"<img src="$1" alt="$2">"#,
            options: [.regularExpression]
        )
    }

    private static func replace(
        pattern: String,
        in text: String,
        options: NSRegularExpression.Options = [],
        transform: (String) -> String
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return text
        }

        let nsText = text as NSString
        let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
        guard !matches.isEmpty else { return text }

        var result = text
        for match in matches.reversed() {
            let range = match.range
            guard let swiftRange = Range(range, in: result) else { continue }
            let raw = (result as NSString).substring(with: range)
            result.replaceSubrange(swiftRange, with: transform(raw))
        }
        return result
    }

    private static func decodeEscapedImageTag(_ raw: String) -> String {
        raw
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#34;", with: "\"")
            .replacingOccurrences(of: "&apos;", with: "'")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }
}

enum HTMLContentParserTestSupport {
    @MainActor
    static func blockKinds(for html: String) -> [String] {
        HTMLBlockParser.parse(html).map { block in
            switch block {
            case .text:
                "text"
            case .image:
                "image"
            case .inline:
                "inline"
            case .codeBlock:
                "code"
            case .blockquote:
                "blockquote"
            }
        }
    }
}

@MainActor
private enum HTMLBlockCache {
    private struct Entry {
        let blocks: [HTMLBlock]
        let imageURLs: [String]
        var lastAccess: UInt64
    }

    private static var storage: [String: Entry] = [:]
    private static let maxEntries = 256
    private static var accessCounter: UInt64 = 0

    static func get(_ html: String) -> (blocks: [HTMLBlock], imageURLs: [String])? {
        guard storage[html] != nil else { return nil }
        accessCounter += 1
        storage[html]!.lastAccess = accessCounter
        let entry = storage[html]!
        return (entry.blocks, entry.imageURLs)
    }

    static func store(blocks: [HTMLBlock], imageURLs: [String], for html: String) {
        if storage.count >= maxEntries {
            // LRU：淘汰最久未访问的一半
            let sorted = storage.sorted { $0.value.lastAccess < $1.value.lastAccess }
            for (key, _) in sorted.prefix(maxEntries / 2) {
                storage.removeValue(forKey: key)
            }
        }
        accessCounter += 1
        storage[html] = Entry(blocks: blocks, imageURLs: imageURLs, lastAccess: accessCounter)
    }
}
