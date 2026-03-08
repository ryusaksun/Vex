import Kingfisher
import SwiftUI

struct TopicRow: View {
    let feed: HomeTopicFeed

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            KFImage(URL(string: feed.member.avatarNormal))
                .downsampling(size: CGSize(width: 72, height: 72))
                .cacheOriginalImage()
                .fade(duration: 0.15)
                .resizable()
                .placeholder {
                    Circle().fill(.quaternary)
                }
                .aspectRatio(contentMode: .fill)
                .frame(width: 36, height: 36)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(feed.node.title)
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 4))

                    Text(feed.member.username)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }

                Text(feed.topic.title)
                    .font(.body)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                HStack(spacing: 4) {
                    if let time = feed.lastReplyTime {
                        Text(time)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let lastReplyBy = feed.lastReplyBy {
                        Text("·  最后回复来自 \(lastReplyBy)")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    Spacer()

                    if feed.topic.replies > 0 {
                        Text("\(feed.topic.replies)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary)
                            .clipShape(Capsule())
                    }
                }
                .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}
