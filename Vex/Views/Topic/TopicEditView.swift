import SwiftUI

struct TopicEditView: View {
    let topicId: Int
    let originalTitle: String
    let originalContent: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AlertManager.self) private var alert

    @State private var title: String
    @State private var content: String
    @State private var isSubmitting = false

    private let client = V2EXClient.shared

    init(topicId: Int, originalTitle: String, originalContent: String) {
        self.topicId = topicId
        self.originalTitle = originalTitle
        self.originalContent = originalContent
        _title = State(initialValue: originalTitle)
        _content = State(initialValue: originalContent)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("主题标题", text: $title)
                }

                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)
                }
            }
            .navigationTitle("编辑主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        Task { await submit() }
                    }
                    .disabled(title.isEmpty || isSubmitting)
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submit() async {
        isSubmitting = true
        do {
            try await client.editTopic(id: topicId, title: title, content: content)
            HapticManager.notification(.success)
            alert.show(.success, "编辑成功")
            dismiss()
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isSubmitting = false
    }
}
