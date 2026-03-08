import SwiftUI

struct TopicBottomBar: View {
    let topicId: Int
    var replyTo: TopicReply?
    let visible: Bool
    let onClearReplyTo: () -> Void
    let onSubmitted: (TopicReply?) -> Void

    @Environment(AlertManager.self) private var alert

    @State private var content = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private let client = V2EXClient.shared

    var body: some View {
        VStack(spacing: 6) {
            // Reply target hint
            if let replyTo, isFocused {
                HStack(spacing: 4) {
                    Text("回复 @\(replyTo.member.username) #\(replyTo.num)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        onClearReplyTo()
                        content = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }

            HStack(spacing: 8) {
                TextField("", text: $content, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...5)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())

                if isFocused {
                    Button {
                        Task { await submitReply() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(canSend ? Color.accentColor : .secondary)
                    }
                    .disabled(!canSend)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
        .offset(y: visible || isFocused ? 0 : 80)
        .animation(.easeInOut(duration: 0.2), value: visible)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .onChange(of: replyTo?.id) {
            if let replyTo {
                content = "@\(replyTo.member.username) #\(replyTo.num) "
                isFocused = true
            }
        }
    }

    private var canSend: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting
    }

    private func submitReply() async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        do {
            let reply = try await client.postReply(topicId: topicId, content: trimmed)
            HapticManager.notification(.success)
            alert.show(.success, "回复成功")
            content = ""
            isFocused = false
            onSubmitted(reply)
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isSubmitting = false
    }
}
