import SwiftUI

struct TopicReplySheet: View {
    let topicId: Int
    var replyTo: TopicReply?
    let onSubmitted: (TopicReply?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AlertManager.self) private var alert

    @State private var content = ""
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

    private let client = V2EXClient.shared

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let replyTo {
                    HStack {
                        Text("回复 @\(replyTo.member.username) #\(replyTo.num)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                }

                TextEditor(text: $content)
                    .focused($isFocused)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .frame(minHeight: 120)
                    .scrollContentBackground(.hidden)

                Divider()

                HStack {
                    Text("\(content.count) 字符")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .navigationTitle("回复")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发送") {
                        Task { await submitReply() }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting)
                }
            }
        }
        .onAppear {
            if let replyTo {
                content = "@\(replyTo.member.username) #\(replyTo.num) "
            }
            isFocused = true
        }
        .interactiveDismissDisabled(isSubmitting)
    }

    private func submitReply() async {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        isSubmitting = true
        do {
            let reply = try await client.postReply(topicId: topicId, content: trimmed)
            HapticManager.notification(.success)
            alert.show(.success, "回复成功")
            onSubmitted(reply)
            dismiss()
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isSubmitting = false
    }
}
