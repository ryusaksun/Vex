import PhotosUI
import SwiftUI

struct TopicBottomBar: View {
    let topicId: Int
    var replyTo: TopicReply?
    let onClearReplyTo: () -> Void
    let onSubmitted: (TopicReply?) -> Void

    @Environment(AuthManager.self) private var auth
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
        VStack(spacing: 6) {
            // Reply target hint
            if let replyTo {
                Button {
                    onClearReplyTo()
                    content = ""
                } label: {
                    HStack(spacing: 6) {
                        Text("回复 @\(replyTo.member.username) #\(replyTo.num)")
                            .font(.subheadline)
                            .foregroundStyle(.tint)
                        Image(systemName: "xmark.circle.fill")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("说点儿什么...", text: $content, axis: .vertical)
                    .focused($isFocused)
                    .lineLimit(1...5)

                if isFocused {
                    // 图片上传按钮（始终显示）
                    if isUploading {
                        ProgressView()
                            .frame(width: 28, height: 28)
                    } else if settings.isImageUploadConfigured {
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Button {
                            showImageConfigAlert = true
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }

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
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
        .modifier(GlassEffectModifier())
        .padding(.horizontal, 24)
        .animation(.easeInOut(duration: 0.15), value: isFocused)
        .onChange(of: replyTo?.id) {
            if let replyTo {
                content = "@\(replyTo.member.username) #\(replyTo.num) "
                isFocused = true
            }
        }
        .onChange(of: selectedPhoto) {
            guard let item = selectedPhoto else { return }
            selectedPhoto = nil
            Task { await uploadImage(item: item) }
        }
        .alert("未配置图床", isPresented: $showImageConfigAlert) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text("请在 设置 → 偏好设置 → 图床 中配置 Imgur Client-ID 后使用")
        }
    }

    private var canSend: Bool {
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSubmitting && !isUploading
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

        if auth.isDemoMode {
            HapticManager.notification(.success)
            alert.show(.info, "Demo 模式：回复功能演示")
            content = ""
            isFocused = false
            return
        }

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

private struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect()
        } else {
            content.background(.ultraThinMaterial)
        }
    }
}
