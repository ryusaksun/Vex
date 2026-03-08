import SwiftUI

struct ConversationSheet: View {
    let reply: TopicReply
    let allReplies: [TopicReply]

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                let thread = conversationThread
                if thread.isEmpty {
                    ContentUnavailableView(
                        "无相关对话",
                        systemImage: "bubble.left.and.bubble.right"
                    )
                    .padding(.top, 60)
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(thread) { r in
                            ReplyRow(reply: r)
                                .background(r.id == reply.id ? Color.accentColor.opacity(0.08) : .clear)
                            Divider().padding(.leading, 50)
                        }
                    }
                }
            }
            .navigationTitle("对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }

    /// Build conversation thread by tracing mentions and repliedTo
    private var conversationThread: [TopicReply] {
        var thread: [TopicReply] = []
        var visited = Set<Int>()

        // Walk up: find all ancestors
        func traceUp(_ r: TopicReply) {
            guard !visited.contains(r.id) else { return }
            visited.insert(r.id)

            // Find who this reply is responding to
            if let repliedTo = r.repliedTo {
                for num in repliedTo {
                    if let parent = allReplies.first(where: { $0.num == num }) {
                        traceUp(parent)
                    }
                }
            } else if !r.membersMentioned.isEmpty {
                // Fall back to mention-based threading
                for mentioned in r.membersMentioned {
                    // Find the latest reply by mentioned user before this reply
                    if let parent = allReplies.last(where: {
                        $0.member.username == mentioned && $0.num < r.num
                    }) {
                        traceUp(parent)
                    }
                }
            }

            thread.append(r)
        }

        // Walk down: find all descendants
        func traceDown(_ r: TopicReply) {
            for candidate in allReplies {
                guard !visited.contains(candidate.id) else { continue }
                let isChild = candidate.repliedTo?.contains(r.num) == true
                    || candidate.membersMentioned.contains(r.member.username) && candidate.num > r.num
                if isChild {
                    visited.insert(candidate.id)
                    thread.append(candidate)
                    traceDown(candidate)
                }
            }
        }

        traceUp(reply)
        traceDown(reply)

        // Sort by reply number
        thread.sort { $0.num < $1.num }

        // Deduplicate
        var seen = Set<Int>()
        return thread.filter { seen.insert($0.id).inserted }
    }
}
