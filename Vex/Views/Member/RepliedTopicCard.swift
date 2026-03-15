import SwiftUI

struct RepliedTopicCard: View {
    let feed: RepliedTopicFeed

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // 主题标题
            Text(feed.topic.title)
                .font(.body.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            // 回复内容预览
            HStack(alignment: .top, spacing: 0) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(.tint.opacity(0.5))
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text(replyPreview)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .padding(.leading, 10)
            }

            // 时间
            Text(feed.replyTime)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    private var replyPreview: String {
        let text = feed.replyContentRendered
            .replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "!\\[[^\\]]*\\]\\([^)]+\\)", with: "[图片]", options: .regularExpression)
            .replacingOccurrences(of: "https?://\\S+", with: "[链接]", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return text.isEmpty ? "[图片或格式化内容]" : text
    }
}
