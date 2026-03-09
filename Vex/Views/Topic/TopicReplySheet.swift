import PhotosUI
import SwiftUI

struct TopicReplySheet: View {
    let topicId: Int
    var replyTo: TopicReply?
    let onSubmitted: (TopicReply?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(AlertManager.self) private var alert
    @EnvironmentObject private var settings: AppSettingsManager

    @State private var content = ""
    @State private var isSubmitting = false
    @State private var isUploading = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showImageConfigAlert = false
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

                    if isUploading {
                        ProgressView()
                            .controlSize(.small)
                        Text("上传中…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if settings.isImageUploadConfigured {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Label("插入图片", systemImage: "photo")
                                .font(.caption)
                        }
                    } else {
                        Button {
                            showImageConfigAlert = true
                        } label: {
                            Label("插入图片", systemImage: "photo")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
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
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSubmitting || isUploading)
                }
            }
        }
        .onAppear {
            if let replyTo {
                content = "@\(replyTo.member.username) #\(replyTo.num) "
            }
            isFocused = true
        }
        .interactiveDismissDisabled(isSubmitting || isUploading)
        .alert("未配置图床", isPresented: $showImageConfigAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请在 设置 → 偏好设置 → 图床 中配置 GitHub Token 和仓库后使用")
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task { await uploadImage(item: item) }
        }
    }

    private func uploadImage(item: PhotosPickerItem) async {
        isUploading = true
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                alert.show(.error, "无法读取图片")
                isUploading = false
                return
            }
            let url = try await ImageUploader.upload(image: image, config: settings.imageUploadConfig)
            content += (content.isEmpty ? "" : "\n") + url
            HapticManager.notification(.success)
        } catch {
            HapticManager.notification(.error)
            alert.show(.error, error.localizedDescription)
        }
        isUploading = false
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
