import UIKit
import SwiftUI

@Observable
@MainActor
final class ClipboardWatcher {
    var detectedURL: V2EXLink?
    private var lastCheckedContent: String?

    enum V2EXLink: Equatable {
        case topic(Int)
        case node(String)
        case member(String)

        var description: String {
            switch self {
            case .topic(let id): return "话题 #\(id)"
            case .node(let name): return "节点 \(name)"
            case .member(let username): return "用户 @\(username)"
            }
        }
    }

    func checkClipboard() {
        guard UIPasteboard.general.hasStrings,
              let content = UIPasteboard.general.string,
              content != lastCheckedContent else { return }

        lastCheckedContent = content

        if let link = parseV2EXLink(content) {
            detectedURL = link
        }
    }

    func dismiss() {
        detectedURL = nil
    }

    private func parseV2EXLink(_ text: String) -> V2EXLink? {
        // Match /t/{id} or v2ex.com/t/{id}
        if let match = text.firstMatch(of: /v2ex\.com\/t\/(\d+)/) {
            if let id = Int(match.1) {
                return .topic(id)
            }
        }
        // Match vex://t/{id}
        if let match = text.firstMatch(of: /vex:\/\/t\/(\d+)/) {
            if let id = Int(match.1) {
                return .topic(id)
            }
        }
        // Match /go/{name} (节点名可能包含连字符)
        if let match = text.firstMatch(of: /v2ex\.com\/go\/([\w-]+)/) {
            return .node(String(match.1))
        }
        // Match /member/{username} (用户名可能包含连字符)
        if let match = text.firstMatch(of: /v2ex\.com\/member\/([\w-]+)/) {
            return .member(String(match.1))
        }
        return nil
    }
}
