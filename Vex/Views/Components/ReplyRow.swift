import Kingfisher
import SwiftUI

struct ReplyRow: View {
    @EnvironmentObject private var settings: AppSettingsManager
    let reply: TopicReply
    var hasConversation: Bool = false
    var onReply: (() -> Void)?
    var onThank: (() -> Void)?
    var onShowConversation: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            if settings.showAvatar {
                NavigationLink(value: reply.member) {
                    KFImage(URL(string: HTMLParser.resolveURL(reply.member.avatarNormal)))
                        .resizable()
                        .frame(width: 36, height: 36)
                        .clipShape(Circle())
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                // Header: username, badges, time, thanks, #num
                HStack(spacing: 0) {
                    HStack(spacing: 5) {
                        Text(reply.member.username)
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        if reply.memberIsOp {
                            Text("OP")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.blue.opacity(0.5), lineWidth: 0.5)
                                )
                        }

                        if reply.memberIsMod {
                            Text("MOD")
                                .font(.system(size: 10))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.orange.opacity(0.5), lineWidth: 0.5)
                                )
                        }

                        Text(reply.replyTime)
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)

                        if let device = reply.replyDevice, !device.isEmpty {
                            Text(device)
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }

                    }

                    Spacer()

                    Text("#\(reply.num)")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }

                // Content
                HTMLContentView(html: reply.contentRendered)

                // Action buttons
                HStack(spacing: 24) {
                    Button(action: { onReply?() }) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { onThank?() }) {
                        HStack(spacing: 3) {
                            Image(systemName: reply.thanked ? "heart.fill" : "heart")
                                .font(.system(size: 14))
                            if reply.thanksCount > 0 {
                                Text("\(reply.thanksCount)")
                                    .font(.subheadline)
                            }
                        }
                        .foregroundStyle(reply.thanked ? .red : .secondary)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if hasConversation {
                        Button(action: { onShowConversation?() }) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 0)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .contextMenu {
            Button {
                UIPasteboard.general.string = reply.content
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }
        }
    }
}
