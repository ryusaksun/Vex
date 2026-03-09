import SwiftUI

struct NewTopicView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AlertManager.self) private var alert
    @Environment(Router.self) private var router

    @State private var title = ""
    @State private var content = ""
    @State private var selectedNode: NodeBasic?
    @State private var syntax = "default"
    @State private var showNodeSelector = false
    @State private var isSubmitting = false

    private let client = V2EXClient.shared

    var body: some View {
        NavigationStack {
            Form {
                Section("标题") {
                    TextField("主题标题", text: $title)
                }

                Section("节点") {
                    Button {
                        showNodeSelector = true
                    } label: {
                        HStack {
                            Text(selectedNode?.title ?? "选择节点")
                                .foregroundStyle(selectedNode == nil ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("内容") {
                    TextEditor(text: $content)
                        .frame(minHeight: 200)

                    Picker("语法", selection: $syntax) {
                        Text("默认").tag("default")
                        Text("Markdown").tag("markdown")
                    }
                }
            }
            .navigationTitle("发布主题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") {
                        Task { await submit() }
                    }
                    .disabled(title.isEmpty || selectedNode == nil || isSubmitting)
                }
            }
            .sheet(isPresented: $showNodeSelector) {
                NodeSelectSheet(selectedNode: $selectedNode)
            }
            .interactiveDismissDisabled(isSubmitting)
        }
    }

    private func submit() async {
        guard let node = selectedNode else { return }
        isSubmitting = true
        do {
            let topic = try await client.createTopic(
                title: title,
                content: content.isEmpty ? nil : content,
                nodeName: node.name,
                syntax: syntax
            )
            HapticManager.notification(.success)
            alert.show(.success, "发布成功")
            let topicId = topic.id
            dismiss()
            // 延迟导航，等待 sheet dismiss 动画完成
            try? await Task.sleep(for: .milliseconds(500))
            router.navigateToTopic(id: topicId)
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isSubmitting = false
    }
}
