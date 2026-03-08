import Kingfisher
import SwiftSoup
import SwiftUI

/// 原生 HTML 渲染器 — 使用 SwiftUI Text + AttributedString 替代 WKWebView，彻底消除滚动卡顿
struct HTMLContentView: View {
    let html: String

    var body: some View {
        let blocks = HTMLBlockParser.parse(html)
        if blocks.isEmpty {
            EmptyView()
        } else if blocks.count == 1, case .text(let attr) = blocks[0] {
            // 快速路径：单文本块（回复的常见情况）
            Text(attr)
                .font(.subheadline)
                .lineSpacing(2)
                .tint(.accentColor)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
        }
    }

    @ViewBuilder
    private func blockView(_ block: HTMLBlock) -> some View {
        switch block {
        case .text(let attr):
            Text(attr)
                .font(.subheadline)
                .lineSpacing(2)
                .tint(.accentColor)

        case .image(let url):
            KFImage(URL(string: url))
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 4))

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

/// Blockquote 单独作为 struct 避免递归类型推断问题
private struct HTMLBlockquoteView: View {
    let blocks: [HTMLBlock]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                switch block {
                case .text(let attr):
                    Text(attr)
                        .font(.subheadline)
                        .lineSpacing(2)
                        .tint(.accentColor)
                case .image(let url):
                    KFImage(URL(string: url))
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: 4))
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

// MARK: - Block Types

private enum HTMLBlock {
    case text(AttributedString)
    case image(String)
    case codeBlock(String)
    case blockquote([HTMLBlock])
}

// MARK: - Parser

private enum HTMLBlockParser {

    static func parse(_ html: String) -> [HTMLBlock] {
        guard !html.isEmpty,
              let doc = try? SwiftSoup.parseBodyFragment(html),
              let body = doc.body()
        else {
            return []
        }
        return parseChildren(of: body)
    }

    // MARK: Block-level

    private static func parseChildren(of parent: Node) -> [HTMLBlock] {
        var blocks: [HTMLBlock] = []
        var runs: [InlineRun] = []

        func flush() {
            guard !runs.isEmpty else { return }
            let attr = buildAttributedString(from: runs)
            if !attr.characters.isEmpty {
                blocks.append(.text(attr))
            }
            runs = []
        }

        for node in parent.getChildNodes() {
            guard let el = node as? Element else {
                // TextNode — 折叠空白（HTML 规范：连续空白合并为单个空格）
                if let tn = node as? TextNode {
                    let text = tn.getWholeText()
                        .replacingOccurrences(of: "[\\s\\n]+", with: " ", options: .regularExpression)
                    if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        runs.append(.text(text, .init()))
                    }
                }
                continue
            }

            switch el.tagName().lowercased() {

            // Block elements
            case "p", "div":
                if !runs.isEmpty { runs.append(.lineBreak) }
                runs.append(contentsOf: extractInline(from: el))
                runs.append(.lineBreak)

            case "br":
                runs.append(.lineBreak)

            case "pre":
                flush()
                blocks.append(.codeBlock((try? el.text()) ?? ""))

            case "blockquote":
                flush()
                let inner = parseChildren(of: el)
                if !inner.isEmpty { blocks.append(.blockquote(inner)) }

            case "img":
                let src = (try? el.attr("src")) ?? ""
                if !src.isEmpty {
                    flush()
                    blocks.append(.image(HTMLParser.resolveURL(src)))
                }

            case "ul", "ol":
                flush()
                let ordered = el.tagName().lowercased() == "ol"
                var idx = 0
                for child in el.children() {
                    guard child.tagName().lowercased() == "li" else { continue }
                    idx += 1
                    let prefix = ordered ? "\(idx). " : "• "
                    var liRuns: [InlineRun] = [.text(prefix, .init())]
                    liRuns.append(contentsOf: extractInline(from: child))
                    let attr = buildAttributedString(from: liRuns)
                    if !attr.characters.isEmpty {
                        blocks.append(.text(attr))
                    }
                }

            // <a> at block level — apply link style
            case "a":
                var s = InlineStyle()
                let href = (try? el.attr("href")) ?? ""
                if !href.isEmpty { s.link = URL(string: HTMLParser.resolveURL(href)) }
                runs.append(contentsOf: extractInline(from: el, style: s))

            // Other inline elements — accumulate
            default:
                runs.append(contentsOf: extractInline(from: el))
            }
        }
        flush()
        return blocks
    }

    // MARK: Inline-level

    private struct InlineStyle {
        var isBold = false
        var isItalic = false
        var isCode = false
        var link: URL?
    }

    private enum InlineRun {
        case text(String, InlineStyle)
        case lineBreak
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
                    // 跳过内联图片（已在 block 层处理）
                    break
                default:
                    runs.append(contentsOf: extractInline(from: el, style: style))
                }
            }
        }
        return runs
    }

    // MARK: Build AttributedString

    private static func buildAttributedString(from runs: [InlineRun]) -> AttributedString {
        var result = AttributedString()
        for run in runs {
            switch run {
            case .text(let content, let style):
                var attr = AttributedString(content)
                var intent: InlinePresentationIntent = []
                if style.isBold { intent.insert(.stronglyEmphasized) }
                if style.isItalic { intent.insert(.emphasized) }
                if style.isCode { intent.insert(.code) }
                if !intent.isEmpty { attr.inlinePresentationIntent = intent }
                if let link = style.link { attr.link = link }
                result.append(attr)
            case .lineBreak:
                result.append(AttributedString("\n"))
            }
        }
        // 清理首尾换行
        while result.characters.last == "\n" { result.characters.removeLast() }
        while result.characters.first == "\n" { result.characters.removeFirst() }
        return result
    }
}
