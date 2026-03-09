import SwiftUI

struct TopicEditView: View {
    let topicId: Int
    var onSaved: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @Environment(AlertManager.self) private var alert

    @State private var title = ""
    @State private var content = ""
    @State private var once = ""
    @State private var isLoading = true
    @State private var isSubmitting = false
    @State private var loadError: String?

    private let client = V2EXClient.shared

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
            .disabled(isLoading || loadError != nil)
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
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading || isSubmitting || once.isEmpty)
                }
            }
            .overlay {
                if isLoading {
                    LottieLoadingView()
                } else if let loadError {
                    ContentUnavailableView(
                        "加载失败",
                        systemImage: "exclamationmark.triangle",
                        description: Text(loadError)
                    )
                }
            }
            .interactiveDismissDisabled(isSubmitting)
        }
        .task {
            await loadForm()
        }
    }

    private func loadForm() async {
        guard !isSubmitting else { return }

        isLoading = true
        loadError = nil
        do {
            let form = try await client.fetchTopicEditForm(id: topicId)
            title = form.title
            content = form.content
            once = form.once
        } catch {
            loadError = error.localizedDescription
        }
        isLoading = false
    }

    private func submit() async {
        isSubmitting = true
        do {
            try await client.editTopic(id: topicId, title: title, content: content, once: once)
            HapticManager.notification(.success)
            alert.show(.success, "编辑成功")
            onSaved?()
            dismiss()
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isSubmitting = false
    }
}
