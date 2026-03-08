import Kingfisher
import SwiftUI

struct ReplyRow: View {
    let reply: TopicReply
    var hasConversation: Bool = false
    var onReply: (() -> Void)?
    var onThank: (() -> Void)?
    var onShowConversation: (() -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            NavigationLink(value: reply.member) {
                KFImage(URL(string: HTMLParser.resolveURL(reply.member.avatarNormal)))
                    .resizable()
                    .frame(width: 24, height: 24)
                    .clipShape(Circle())
            }

            VStack(alignment: .leading, spacing: 4) {
                // Header: username, badges, time, thanks, #num
                HStack(spacing: 0) {
                    HStack(spacing: 4) {
                        Text(reply.member.username)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)

                        if reply.memberIsOp {
                            Text("OP")
                                .font(.system(size: 9))
                                .fontWeight(.bold)
                                .foregroundStyle(.blue)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.blue.opacity(0.5), lineWidth: 0.5)
                                )
                        }

                        if reply.memberIsMod {
                            Text("MOD")
                                .font(.system(size: 9))
                                .fontWeight(.bold)
                                .foregroundStyle(.orange)
                                .padding(.horizontal, 3)
                                .padding(.vertical, 1)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .strokeBorder(.orange.opacity(0.5), lineWidth: 0.5)
                                )
                        }

                        Text(reply.replyTime)
                            .font(.caption)
                            .foregroundStyle(.tertiary)

                        if let device = reply.replyDevice, !device.isEmpty {
                            Text(device)
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }

                        if reply.thanksCount > 0 {
                            Text("·")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 2) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9))
                                Text("\(reply.thanksCount)")
                                    .font(.caption)
                            }
                            .foregroundStyle(.red.opacity(0.7))
                        }
                    }

                    Spacer()

                    Text("#\(reply.num)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                // Content
                HTMLContentView(html: reply.contentRendered)

                // Action buttons
                HStack(spacing: 0) {
                    Button(action: { onReply?() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "arrowshape.turn.up.left")
                                .font(.system(size: 11))
                            Text("回复")
                                .font(.caption)
                        }
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button(action: { onThank?() }) {
                        HStack(spacing: 3) {
                            Image(systemName: reply.thanked ? "heart.fill" : "heart")
                                .font(.system(size: 11))
                            Text(reply.thanked ? "已感谢" : "感谢")
                                .font(.caption)
                        }
                        .foregroundStyle(reply.thanked ? .red : .secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(reply.thanked)

                    if hasConversation {
                        Button(action: { onShowConversation?() }) {
                            HStack(spacing: 3) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 11))
                                Text("会话")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(.top, 2)
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
